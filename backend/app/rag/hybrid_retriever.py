"""Hybrid RAG retriever combining Qdrant dense vector search, BM25 lexical search, and RRF."""

from __future__ import annotations

import logging
import time
from typing import Any, Sequence

from pydantic import BaseModel

from app.config import Settings, get_settings
from app.rag.bm25_store import BM25Store
from app.rag.embeddings import EmbeddingProvider, create_embedding_provider
from app.rag.qdrant_store import QdrantVectorStore
from app.rag.tokenizer import (
    expand_query_tokens,
    extract_section_numbers,
    normalize_nepali_digits,
)
from app.schemas import CategoryEnum, RAGSearchResponse, RetrievedChunk, SearchFilter

logger = logging.getLogger(__name__)


def _to_chunk_dict(chunk: dict[str, Any] | BaseModel) -> dict[str, Any]:
    if isinstance(chunk, BaseModel):
        data = chunk.model_dump(mode="python")
    else:
        data = dict(chunk)

    cat = data.get("category", CategoryEnum.OTHER)
    if hasattr(cat, "value"):
        cat = cat.value
    data["category"] = str(cat or CategoryEnum.OTHER.value)

    if data.get("section_num") is not None:
        sec = normalize_nepali_digits(str(data["section_num"])).strip()
        data["section_num"] = sec or None

    data.setdefault("act_name", "")
    data.setdefault("language", "EN")
    data.setdefault("citation_label", "")
    data.setdefault("chunk_index", 0)
    data.setdefault("metadata", {})
    return data


def _to_retrieved_chunk(
    payload: dict[str, Any],
    *,
    score: float,
    dense_score: float | None,
    bm25_score: float | None,
    retrieval_sources: list[str],
) -> RetrievedChunk:
    raw_cat = payload.get("category", CategoryEnum.OTHER.value)
    try:
        category = raw_cat if isinstance(raw_cat, CategoryEnum) else CategoryEnum(str(raw_cat))
    except ValueError:
        category = CategoryEnum.OTHER

    return RetrievedChunk(
        chunk_id=str(payload["chunk_id"]),
        doc_id=str(payload["doc_id"]),
        text=str(payload["text"]),
        act_name=str(payload.get("act_name") or ""),
        category=category,
        language=str(payload.get("language") or "EN"),
        section_num=payload.get("section_num"),
        section_title=payload.get("section_title"),
        citation_label=str(payload.get("citation_label") or ""),
        page_start=payload.get("page_start"),
        page_end=payload.get("page_end"),
        chunk_index=int(payload.get("chunk_index") or 0),
        source_path=payload.get("source_path"),
        source_url=payload.get("source_url"),
        score=round(float(score), 6),
        dense_score=round(float(dense_score), 6) if dense_score is not None else None,
        bm25_score=round(float(bm25_score), 6) if bm25_score is not None else None,
        retrieval_sources=retrieval_sources,
        metadata=dict(payload.get("metadata") or {}),
    )


class HybridRetriever:
    """Coordinates dense Qdrant embeddings, BM25 lexical search, and Reciprocal Rank Fusion (RRF)."""

    def __init__(
        self,
        settings: Settings | None = None,
        *,
        embedding_provider: EmbeddingProvider | None = None,
        qdrant_store: QdrantVectorStore | None = None,
        bm25_store: BM25Store | None = None,
        rrf_k: int = 60,
        dense_weight: float = 1.0,
        bm25_weight: float = 1.0,
        section_boost: float = 0.025,
    ) -> None:
        self.settings = settings or get_settings()
        self.settings.ensure_data_dirs()

        self.embedding_provider = embedding_provider or create_embedding_provider(self.settings)
        self.qdrant_store = qdrant_store or QdrantVectorStore(
            self.settings,
            embedding_provider=self.embedding_provider.provider_name,
            dimension=self.embedding_provider.dimension,
        )
        self.bm25_store = bm25_store or BM25Store(self.settings)

        self.rrf_k = int(rrf_k)
        self.dense_weight = float(dense_weight)
        self.bm25_weight = float(bm25_weight)
        self.section_boost = float(section_boost)

    async def index_chunks(self, chunks: Sequence[dict[str, Any] | BaseModel]) -> int:
        """Index statutory chunks into both Qdrant (dense) and BM25 (lexical) stores."""
        if not chunks:
            return 0

        normalized = [_to_chunk_dict(c) for c in chunks]
        texts = [c["text"] for c in normalized]

        vectors = await self.embedding_provider.embed_documents(texts)
        if vectors and len(vectors[0]) != self.qdrant_store.dimension:
            self.qdrant_store.ensure_collection(dimension=len(vectors[0]))

        self.qdrant_store.upsert_chunks(normalized, vectors)
        self.bm25_store.upsert_chunks(normalized)
        return len(normalized)

    async def delete_document(self, doc_id: str) -> dict[str, Any]:
        """Delete all chunks for `doc_id` from both Qdrant and BM25."""
        qdrant_deleted = self.qdrant_store.delete_by_doc_id(doc_id)
        bm25_deleted = self.bm25_store.delete_by_doc_id(doc_id)
        return {
            "doc_id": doc_id,
            "qdrant_deleted": qdrant_deleted,
            "bm25_deleted": bm25_deleted,
            "deleted": (qdrant_deleted > 0 or bm25_deleted > 0),
        }

    async def search(
        self,
        query: str,
        top_k: int | None = None,
        filters: SearchFilter | dict[str, Any] | None = None,
        use_dense: bool = True,
        use_bm25: bool = True,
        min_score: float | None = None,
    ) -> RAGSearchResponse:
        """Run Hybrid RAG search (dense Qdrant + BM25) fused with Reciprocal Rank Fusion (k=60)."""
        started = time.perf_counter()
        limit = int(top_k or self.settings.default_top_k)
        sf = (
            filters
            if (filters is None or isinstance(filters, SearchFilter))
            else SearchFilter.model_validate(filters)
        )
        expanded_tokens = expand_query_tokens(query)
        candidate_limit = max(limit * 3, 20)

        dense_hits: list[dict[str, Any]] = []
        if use_dense and self.qdrant_store.count_points() > 0:
            try:
                query_vec = await self.embedding_provider.embed_query(query)
                dense_hits = self.qdrant_store.search_dense(
                    query_vec=query_vec,
                    limit=candidate_limit,
                    filters=sf,
                )
            except Exception as exc:
                logger.warning("Dense retrieval failed; continuing with BM25: %s", exc)

        bm25_hits: list[dict[str, Any]] = []
        if use_bm25 and self.bm25_store.count_docs() > 0:
            bm25_hits = self.bm25_store.search_bm25(
                query=query,
                limit=candidate_limit,
                filters=sf,
            )

        query_sections = set(extract_section_numbers(query))
        if sf and sf.section_num:
            query_sections.add(normalize_nepali_digits(sf.section_num).strip())

        fused: dict[str, dict[str, Any]] = {}

        for rank, hit in enumerate(dense_hits, start=1):
            cid = str(hit["chunk_id"])
            entry = fused.setdefault(
                cid,
                {
                    "payload": hit,
                    "rrf": 0.0,
                    "dense_score": None,
                    "bm25_score": None,
                    "sources": [],
                },
            )
            entry["rrf"] += self.dense_weight / (self.rrf_k + rank)
            entry["dense_score"] = hit.get("dense_score")
            if "dense" not in entry["sources"]:
                entry["sources"].append("dense")

        for rank, hit in enumerate(bm25_hits, start=1):
            cid = str(hit["chunk_id"])
            entry = fused.setdefault(
                cid,
                {
                    "payload": hit,
                    "rrf": 0.0,
                    "dense_score": None,
                    "bm25_score": None,
                    "sources": [],
                },
            )
            entry["rrf"] += self.bm25_weight / (self.rrf_k + rank)
            entry["bm25_score"] = hit.get("bm25_score")
            if "bm25" not in entry["sources"]:
                entry["sources"].append("bm25")

        # Apply explicit section-number boost uniformly across all candidate hits
        for entry in fused.values():
            sec = normalize_nepali_digits(str(entry["payload"].get("section_num") or "")).strip()
            if sec and sec in query_sections:
                entry["rrf"] += self.section_boost
                if "section_exact" not in entry["sources"]:
                    entry["sources"].append("section_exact")

        ranked = sorted(
            fused.values(),
            key=lambda item: (
                item["rrf"],
                item["dense_score"] or 0.0,
                item["bm25_score"] or 0.0,
            ),
            reverse=True,
        )

        # Deduplicate near-identical text within the same doc/section if chunk_ids somehow differed
        results: list[RetrievedChunk] = []
        seen_text_keys: set[tuple[str, str]] = set()
        for entry in ranked:
            if min_score is not None and entry["rrf"] < min_score:
                continue
            payload = entry["payload"]
            dedupe_key = (str(payload.get("doc_id") or ""), str(payload.get("text") or "").strip())
            if dedupe_key in seen_text_keys:
                continue
            seen_text_keys.add(dedupe_key)
            results.append(
                _to_retrieved_chunk(
                    payload,
                    score=entry["rrf"],
                    dense_score=entry["dense_score"],
                    bm25_score=entry["bm25_score"],
                    retrieval_sources=entry["sources"],
                )
            )
            if len(results) >= limit:
                break

        latency_ms = round((time.perf_counter() - started) * 1000.0, 2)
        return RAGSearchResponse(
            query=query,
            expanded_tokens=expanded_tokens,
            results=results,
            total_results=len(results),
            embedding_provider=self.embedding_provider.provider_name,
            latency_ms=latency_ms,
        )

    def get_stats(self) -> dict[str, Any]:
        """Return health & index statistics for Qdrant, BM25, and active embeddings."""
        return {
            "qdrant_connected": True,
            "qdrant_mode": self.qdrant_store.mode,
            "qdrant_collection": self.qdrant_store.collection_name,
            "qdrant_points": self.qdrant_store.count_points(),
            "bm25_docs": self.bm25_store.count_docs(),
            "embedding_provider": self.embedding_provider.provider_name,
            "embedding_model": self.embedding_provider.model_name,
            "embedding_dim": self.embedding_provider.dimension,
            "embedding_is_fallback": self.embedding_provider.is_fallback,
        }

    def count(self) -> int:
        """Return the active indexed chunk count (max of Qdrant and BM25 counts)."""
        return max(self.qdrant_store.count_points(), self.bm25_store.count_docs())

    def close(self) -> None:
        """Close Qdrant store cleanly."""
        self.qdrant_store.close()

    async def aclose(self) -> None:
        """Async close wrapper for FastAPI lifespan shutdown."""
        self.close()
