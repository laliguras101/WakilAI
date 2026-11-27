"""End-to-end statutory ingestion pipeline with atomic manifest persistence and SHA-256 deduplication."""

from __future__ import annotations

import asyncio
import hashlib
import inspect
import json
import logging
import os
import re
import tempfile
from pathlib import Path
from typing import Any, Optional, Protocol, Sequence

from app.config import Settings, get_settings
from app.ingestion.chunker import StatutoryChunk, chunk_document
from app.ingestion.extractors import (
    DocumentExtractionError,
    ExtractedDocument,
    extract_bytes,
    extract_url,
)
from app.ingestion.nepal_sources import (
    CORE_NEPAL_SOURCES,
    DEFAULT_LOCAL_CORPUS_DIR,
    discover_local_corpus_files,
    download_verified_source,
    infer_act_name_from_path,
    infer_category_from_path_or_name,
)
from app.schemas import CategoryEnum, CorpusDocumentMeta, IngestResponse

logger = logging.getLogger(__name__)


class RetrieverProtocol(Protocol):
    """Minimal indexer protocol required by `IngestionPipeline` (prevents circular imports)."""

    def index_chunks(self, chunks: Sequence[dict[str, Any] | Any]) -> Any: ...

    def delete_document(self, doc_id: str) -> Any: ...


async def _maybe_await(value: Any) -> Any:
    if inspect.isawaitable(value):
        return await value
    return value


def _compute_sha256(content: bytes) -> str:
    return hashlib.sha256(content).hexdigest()


def _safe_filename(file_name: str) -> str:
    base = Path(file_name).name or "document.txt"
    cleaned = re.sub(r"[^\w.\-\u0900-\u097F]+", "_", base).strip("_")
    return cleaned or "document.txt"


class IngestionPipeline:
    """Coordinates extraction, statutory chunking, manifest persistence, and hybrid index updates."""

    def __init__(
        self,
        settings: Optional[Settings] = None,
        retriever: Optional[RetrieverProtocol] = None,
    ) -> None:
        self.settings = settings or get_settings()
        self.settings.ensure_data_dirs()
        self.retriever = retriever
        self._manifest_lock = asyncio.Lock()

    @property
    def manifest_path(self) -> Path:
        return self.settings.manifest_path

    def _load_manifest_unlocked(self) -> dict[str, CorpusDocumentMeta]:
        if not self.manifest_path.exists():
            return {}
        try:
            raw = json.loads(self.manifest_path.read_text(encoding="utf-8"))
        except Exception as exc:
            logger.warning("Failed reading manifest %s: %s", self.manifest_path, exc)
            return {}

        items = raw.get("documents", raw) if isinstance(raw, dict) else {}
        if not isinstance(items, dict):
            return {}

        docs: dict[str, CorpusDocumentMeta] = {}
        for doc_id, payload in items.items():
            try:
                docs[str(doc_id)] = CorpusDocumentMeta.model_validate(payload)
            except Exception as exc:
                logger.warning("Skipping invalid manifest entry %s: %s", doc_id, exc)
        return docs

    def _save_manifest_unlocked(self, docs: dict[str, CorpusDocumentMeta]) -> None:
        self.manifest_path.parent.mkdir(parents=True, exist_ok=True)
        payload = {
            "version": 1,
            "documents": {doc_id: meta.model_dump(mode="json") for doc_id, meta in docs.items()},
        }
        serialized = json.dumps(payload, indent=2, ensure_ascii=False)
        with tempfile.NamedTemporaryFile(
            mode="w",
            encoding="utf-8",
            dir=str(self.manifest_path.parent),
            prefix=".manifest_",
            suffix=".tmp",
            delete=False,
        ) as tmp:
            tmp.write(serialized)
            tmp_path = Path(tmp.name)
        os.replace(tmp_path, self.manifest_path)

    def list_documents(self) -> list[CorpusDocumentMeta]:
        """Return all tracked corpus documents sorted newest-first."""
        docs = self._load_manifest_unlocked()
        return sorted(docs.values(), key=lambda d: d.ingested_at, reverse=True)

    def get_document(self, doc_id: str) -> Optional[CorpusDocumentMeta]:
        """Return a single document record from the manifest if present."""
        return self._load_manifest_unlocked().get(doc_id)

    async def ingest_bytes(
        self,
        content: bytes,
        file_name: str,
        *,
        category: CategoryEnum | str = CategoryEnum.OTHER,
        act_name: Optional[str] = None,
        language: Optional[str] = None,
        title: Optional[str] = None,
        source_path: Optional[str] = None,
        source_url: Optional[str] = None,
        force_reindex: bool = False,
        save_raw: bool = True,
        extra_metadata: Optional[dict[str, Any]] = None,
    ) -> IngestResponse:
        """Extract, chunk, deduplicate via SHA-256, and index raw document bytes."""
        if not content:
            raise DocumentExtractionError(f"Cannot ingest empty file `{file_name}`.")

        sha256 = _compute_sha256(content)
        doc_id = f"doc-{sha256[:16]}"
        cat_enum = category if isinstance(category, CategoryEnum) else CategoryEnum(str(category))

        async with self._manifest_lock:
            manifest = self._load_manifest_unlocked()
            existing_by_hash = next((d for d in manifest.values() if d.sha256 == sha256), None)
            if existing_by_hash is not None and not force_reindex:
                return IngestResponse(
                    status="skipped_duplicate",
                    doc_id=existing_by_hash.doc_id,
                    title=existing_by_hash.title,
                    chunks_indexed=0,
                    deduplicated=True,
                    document=existing_by_hash,
                    message=f"Skipped duplicate `{file_name}` (matches existing `{existing_by_hash.doc_id}`).",
                )

        # Persist uploaded bytes into raw_data_dir when no filesystem path was provided
        persisted_path = source_path
        if persisted_path is None and save_raw:
            self.settings.raw_data_dir.mkdir(parents=True, exist_ok=True)
            raw_target = self.settings.raw_data_dir / f"{doc_id}_{_safe_filename(file_name)}"
            with tempfile.NamedTemporaryFile(
                mode="wb",
                dir=str(self.settings.raw_data_dir),
                prefix=f".{doc_id}_",
                suffix=".tmp",
                delete=False,
            ) as tmp:
                tmp.write(content)
                tmp_path = Path(tmp.name)
            os.replace(tmp_path, raw_target)
            persisted_path = str(raw_target.resolve())

        extracted: ExtractedDocument = extract_bytes(
            content,
            file_name,
            source_path=persisted_path,
            source_url=source_url,
            title=title,
        )

        resolved_title = title or extracted.title or Path(file_name).stem
        resolved_act = act_name or resolved_title
        resolved_lang = language or extracted.language

        chunks: list[StatutoryChunk] = chunk_document(
            extracted,
            doc_id=doc_id,
            act_name=resolved_act,
            category=cat_enum,
            language=resolved_lang,
            max_chars=self.settings.chunk_size,
            chunk_overlap=self.settings.chunk_overlap,
        )
        if not chunks:
            raise DocumentExtractionError(f"No usable statutory chunks produced from `{file_name}`.")

        if self.retriever is not None:
            if force_reindex:
                await _maybe_await(self.retriever.delete_document(doc_id))
            await _maybe_await(self.retriever.index_chunks([c.model_dump(mode="python") for c in chunks]))

        doc_meta = CorpusDocumentMeta(
            doc_id=doc_id,
            title=resolved_title,
            act_name=resolved_act,
            category=cat_enum,
            language=resolved_lang,
            file_name=Path(file_name).name,
            source_path=persisted_path,
            source_url=source_url,
            sha256=sha256,
            file_size_bytes=len(content),
            page_count=extracted.page_count,
            chunks_count=len(chunks),
            status="INDEXED",
            metadata={**extracted.metadata, **(extra_metadata or {})},
        )

        async with self._manifest_lock:
            manifest = self._load_manifest_unlocked()
            manifest[doc_id] = doc_meta
            self._save_manifest_unlocked(manifest)

        return IngestResponse(
            status="indexed",
            doc_id=doc_id,
            title=resolved_title,
            chunks_indexed=len(chunks),
            deduplicated=False,
            document=doc_meta,
            message=f"Indexed `{resolved_title}` into {len(chunks)} chunks.",
        )

    async def ingest_file(
        self,
        path: str | Path,
        *,
        category: CategoryEnum | str | None = None,
        act_name: Optional[str] = None,
        language: Optional[str] = None,
        title: Optional[str] = None,
        source_url: Optional[str] = None,
        force_reindex: bool = False,
    ) -> IngestResponse:
        """Read and ingest a local statutory file."""
        file_path = Path(path)
        if not file_path.exists():
            raise FileNotFoundError(f"File not found: {file_path}")
        if not file_path.is_file():
            raise DocumentExtractionError(f"Path is not a regular file: {file_path}")

        resolved_category = (
            category
            if category is not None
            else infer_category_from_path_or_name(file_path)
        )
        resolved_act = act_name or infer_act_name_from_path(file_path)
        return await self.ingest_bytes(
            file_path.read_bytes(),
            file_path.name,
            category=resolved_category,
            act_name=resolved_act,
            language=language,
            title=title,
            source_path=str(file_path.resolve()),
            source_url=source_url,
            force_reindex=force_reindex,
            save_raw=False,
        )

    async def ingest_directory(
        self,
        path: str | Path,
        *,
        category: CategoryEnum | str | None = None,
        act_name: Optional[str] = None,
        language: Optional[str] = None,
        recursive: bool = True,
        force_reindex: bool = False,
        extensions: Optional[set[str]] = None,
    ) -> IngestResponse:
        """Ingest all supported statutory documents in a local directory."""
        dir_path = Path(path)
        if not dir_path.exists():
            raise FileNotFoundError(f"Directory not found: {dir_path}")
        if not dir_path.is_dir():
            raise DocumentExtractionError(f"Path is not a directory: {dir_path}")

        allowed = extensions or {".pdf", ".docx", ".txt", ".md", ".markdown", ".json", ".html", ".htm"}
        iterator = dir_path.rglob("*") if recursive else dir_path.glob("*")
        files = sorted(fp for fp in iterator if fp.is_file() and fp.suffix.lower() in allowed)

        docs: list[CorpusDocumentMeta] = []
        errors: list[str] = []
        total_chunks = 0

        for fp in files:
            try:
                res = await self.ingest_file(
                    fp,
                    category=category if category not in (None, CategoryEnum.OTHER) else None,
                    act_name=act_name,
                    language=language,
                    force_reindex=force_reindex,
                )
                if res.document is not None:
                    docs.append(res.document)
                total_chunks += res.chunks_indexed
            except Exception as exc:
                errors.append(f"{fp.name}: {exc}")
                logger.warning("Failed ingesting %s: %s", fp, exc)

        return IngestResponse(
            status="ok" if docs or not errors else "error",
            chunks_indexed=total_chunks,
            documents=docs,
            message=f"Processed {len(files)} files from `{dir_path}` ({len(docs)} tracked, {total_chunks} chunks indexed).",
            errors=errors,
        )

    async def ingest_url(
        self,
        url: str,
        *,
        title: Optional[str] = None,
        act_name: Optional[str] = None,
        category: CategoryEnum | str = CategoryEnum.OTHER,
        language: Optional[str] = None,
        force_reindex: bool = False,
    ) -> IngestResponse:
        """Fetch a remote URL (PDF, HTML, or text statute) and ingest it."""
        doc, raw_bytes, file_name = await extract_url(url, title=title)
        resolved_title = title or doc.title or file_name
        return await self.ingest_bytes(
            raw_bytes,
            file_name,
            category=category,
            act_name=act_name or resolved_title,
            language=language or doc.language,
            title=resolved_title,
            source_url=doc.source_url or url,
            force_reindex=force_reindex,
            save_raw=True,
        )

    async def delete_document(self, doc_id: str) -> IngestResponse:
        """Delete a document from the retriever stores and corpus manifest."""
        async with self._manifest_lock:
            manifest = self._load_manifest_unlocked()
            removed = manifest.pop(doc_id, None)
            if removed is not None:
                self._save_manifest_unlocked(manifest)

        retriever_deleted = False
        if self.retriever is not None:
            outcome = await _maybe_await(self.retriever.delete_document(doc_id))
            if isinstance(outcome, dict):
                retriever_deleted = bool(outcome.get("deleted", False))
            else:
                retriever_deleted = bool(outcome)

        if removed is None and not retriever_deleted:
            return IngestResponse(
                status="not_found",
                doc_id=doc_id,
                message=f"Document `{doc_id}` not found in corpus manifest or vector stores.",
            )

        return IngestResponse(
            status="deleted",
            doc_id=doc_id,
            title=removed.title if removed else None,
            document=removed,
            message=f"Deleted document `{doc_id}` from corpus manifest and indexes.",
        )

    async def reindex_all(self, force_reindex: bool = True) -> IngestResponse:
        """Rebuild Qdrant and BM25 indexes from all tracked source files/URLs in the manifest."""
        docs = self.list_documents()
        if not docs:
            return IngestResponse(
                status="ok",
                chunks_indexed=0,
                message="Corpus manifest is empty; nothing to reindex.",
            )

        reindexed_docs: list[CorpusDocumentMeta] = []
        errors: list[str] = []
        total_chunks = 0

        for meta in docs:
            try:
                if meta.source_path and Path(meta.source_path).is_file():
                    res = await self.ingest_file(
                        meta.source_path,
                        category=meta.category,
                        act_name=meta.act_name,
                        language=meta.language,
                        title=meta.title,
                        source_url=meta.source_url,
                        force_reindex=force_reindex,
                    )
                elif meta.source_url:
                    res = await self.ingest_url(
                        meta.source_url,
                        title=meta.title,
                        act_name=meta.act_name,
                        category=meta.category,
                        language=meta.language,
                        force_reindex=force_reindex,
                    )
                else:
                    errors.append(f"{meta.doc_id}: missing source_path and source_url")
                    continue

                if res.document is not None:
                    reindexed_docs.append(res.document)
                total_chunks += res.chunks_indexed
            except Exception as exc:
                errors.append(f"{meta.doc_id}: {exc}")

        return IngestResponse(
            status="ok" if reindexed_docs or not errors else "error",
            chunks_indexed=total_chunks,
            documents=reindexed_docs,
            message=f"Reindexed {len(reindexed_docs)} documents ({total_chunks} chunks).",
            errors=errors,
        )

    async def bootstrap_nepal_corpus(
        self,
        retriever: Optional[RetrieverProtocol] = None,
        *,
        source: Optional[str | Path] = None,
        source_dir: Optional[str | Path] = None,
        include_all: bool = False,
        download_public: bool = True,
        force_reindex: bool = False,
    ) -> IngestResponse:
        """Acquire and index real Nepalese statutory documents from local corpus and/or verified public URLs."""
        if retriever is not None:
            self.retriever = retriever

        explicit_source = source or source_dir
        if explicit_source is not None:
            local_root: Optional[Path] = Path(explicit_source)
            if not local_root.exists():
                raise FileNotFoundError(f"Requested corpus source path does not exist: {local_root}")
        elif DEFAULT_LOCAL_CORPUS_DIR.exists():
            local_root = DEFAULT_LOCAL_CORPUS_DIR
        else:
            local_root = None

        docs: list[CorpusDocumentMeta] = []
        errors: list[str] = []
        total_chunks = 0
        seen_keys_or_acts: set[str] = set()

        if local_root is not None:
            local_items = discover_local_corpus_files(local_root, include_all=include_all)
            for fp, act_name, cat, lang_override in local_items:
                try:
                    res = await self.ingest_file(
                        fp,
                        category=cat,
                        act_name=act_name,
                        language=lang_override,
                        force_reindex=force_reindex,
                    )
                    if res.document is not None:
                        docs.append(res.document)
                        seen_keys_or_acts.add(act_name.lower())
                    total_chunks += res.chunks_indexed
                except Exception as exc:
                    errors.append(f"{fp.name}: {exc}")
                    logger.warning("Local bootstrap error for %s: %s", fp, exc)

        # Download & index verified public statutory PDFs when no local root OR to fill missing core public acts
        if download_public and not include_all:
            for spec in CORE_NEPAL_SOURCES:
                if not spec.urls:
                    continue
                if spec.act_name.lower() in seen_keys_or_acts and local_root is not None:
                    # Still ensure official English/Unicode supplements like Civil Code EN or Penal EN or ETA EN get indexed
                    has_local = bool(
                        (spec.local_md_relpath and ((local_root / "law_commission_md" / spec.local_md_relpath).exists() or (local_root / spec.local_md_relpath).exists()))
                        or (spec.local_pdf_relpath and ((local_root / "law_commission_pdfs" / spec.local_pdf_relpath).exists() or (local_root / spec.local_pdf_relpath).exists()))
                    )
                    if has_local:
                        continue
                try:
                    downloaded = await download_verified_source(spec, self.settings.raw_data_dir)
                    if downloaded is None:
                        if local_root is None:
                            errors.append(f"{spec.key}: failed downloading from all fallback URLs")
                        continue
                    local_pdf, resolved_url = downloaded
                    res = await self.ingest_file(
                        local_pdf,
                        category=spec.category,
                        act_name=spec.act_name,
                        language=spec.language,
                        title=spec.title,
                        source_url=resolved_url,
                        force_reindex=force_reindex,
                    )
                    if res.document is not None:
                        docs.append(res.document)
                    total_chunks += res.chunks_indexed
                except Exception as exc:
                    errors.append(f"{spec.key}: {exc}")
                    logger.warning("Public source bootstrap error for %s: %s", spec.key, exc)

        return IngestResponse(
            status="ok" if docs else "error",
            chunks_indexed=total_chunks,
            documents=docs,
            message=f"Bootstrapped {len(docs)} Nepalese statutory documents ({total_chunks} chunks indexed).",
            errors=errors,
        )


async def bootstrap_nepal_corpus(
    retriever: RetrieverProtocol,
    *,
    settings: Optional[Settings] = None,
    source: Optional[str | Path] = None,
    include_all: bool = False,
    download_public: bool = True,
    force_reindex: bool = False,
) -> IngestResponse:
    """Module-level convenience wrapper accepting any `RetrieverProtocol` instance."""
    pipeline = IngestionPipeline(settings=settings, retriever=retriever)
    return await pipeline.bootstrap_nepal_corpus(
        retriever=retriever,
        source=source,
        include_all=include_all,
        download_public=download_public,
        force_reindex=force_reindex,
    )
