"""Persistent BM25Okapi lexical index with Nepali/Nepglish tokenization and atomic storage."""

from __future__ import annotations

import json
import os
import pickle
import threading
from pathlib import Path
from typing import Any, Sequence

from rank_bm25 import BM25Okapi

from app.config import Settings, get_settings
from app.rag.tokenizer import (
    expand_query_tokens,
    extract_section_numbers,
    normalize_nepali_digits,
    tokenize_legal_text,
)
from app.schemas import SearchFilter


def _enum_str(value: Any) -> str:
    return str(getattr(value, "value", value))


def _matches_filter(chunk: dict[str, Any], sf: SearchFilter | None) -> bool:
    if sf is None:
        return True

    allowed_categories: list[str] = []
    if sf.category is not None:
        allowed_categories.append(_enum_str(sf.category))
    if sf.categories:
        allowed_categories.extend(_enum_str(c) for c in sf.categories)
    if allowed_categories:
        chunk_cat = _enum_str(chunk.get("category") or "")
        if chunk_cat not in allowed_categories:
            return False

    if sf.act_name:
        if (chunk.get("act_name") or "").strip().lower() != sf.act_name.strip().lower():
            return False

    if sf.doc_id:
        if (chunk.get("doc_id") or "") != sf.doc_id:
            return False

    if sf.language:
        if (chunk.get("language") or "").strip().upper() != sf.language.strip().upper():
            return False

    if sf.section_num:
        target_sec = normalize_nepali_digits(sf.section_num).strip()
        chunk_sec = normalize_nepali_digits(str(chunk.get("section_num") or "")).strip()
        if chunk_sec != target_sec:
            return False

    return True


def _chunk_index_text(chunk: dict[str, Any]) -> str:
    parts = [
        str(chunk.get("act_name") or ""),
        str(chunk.get("section_title") or ""),
        str(chunk.get("citation_label") or ""),
        f"section {chunk['section_num']}" if chunk.get("section_num") else "",
        str(chunk.get("text") or ""),
    ]
    return " ".join(p for p in parts if p)


class BM25Store:
    """Persistent BM25 lexical store supporting atomic JSON/pickle persistence and metadata filters."""

    def __init__(
        self,
        settings: Settings | None = None,
        *,
        index_path: Path | str | None = None,
    ) -> None:
        self.settings = settings or get_settings()
        self.index_path = Path(index_path) if index_path is not None else self.settings.bm25_path
        self.index_path.parent.mkdir(parents=True, exist_ok=True)

        self._lock = threading.RLock()
        self._chunks: list[dict[str, Any]] = []
        self._chunk_pos: dict[str, int] = {}
        self._tokenized_corpus: list[list[str]] = []
        self._bm25: BM25Okapi | None = None

        self.load()

    def _rebuild_model(self) -> None:
        self._chunk_pos = {
            str(chunk.get("chunk_id")): idx for idx, chunk in enumerate(self._chunks)
        }
        if self._tokenized_corpus:
            # Ensure at least one token per doc to avoid ZeroDivisionError in rank_bm25
            safe_corpus = [tokens if tokens else ["_empty_"] for tokens in self._tokenized_corpus]
            self._bm25 = BM25Okapi(safe_corpus)
        else:
            self._bm25 = None

    def load(self) -> None:
        """Load BM25 chunks and tokenized corpus from disk if present."""
        with self._lock:
            if not self.index_path.exists():
                self._chunks = []
                self._tokenized_corpus = []
                self._rebuild_model()
                return

            if self.index_path.suffix.lower() == ".pkl":
                with self.index_path.open("rb") as fh:
                    payload = pickle.load(fh)
            else:
                with self.index_path.open("r", encoding="utf-8") as fh:
                    payload = json.load(fh)

            self._chunks = [dict(c) for c in payload.get("chunks", [])]
            stored_tokens = payload.get("tokenized_corpus")
            if isinstance(stored_tokens, list) and len(stored_tokens) == len(self._chunks):
                self._tokenized_corpus = [list(t) for t in stored_tokens]
            else:
                self._tokenized_corpus = [
                    tokenize_legal_text(_chunk_index_text(c), remove_stopwords=True)
                    for c in self._chunks
                ]
            self._rebuild_model()

    def save(self) -> None:
        """Atomically persist BM25 chunks and tokens to disk via temp file + `os.replace`."""
        with self._lock:
            self.index_path.parent.mkdir(parents=True, exist_ok=True)
            tmp_path = self.index_path.with_name(f".{self.index_path.name}.tmp.{os.getpid()}")
            payload = {
                "version": 1,
                "chunks": self._chunks,
                "tokenized_corpus": self._tokenized_corpus,
            }
            if self.index_path.suffix.lower() == ".pkl":
                with tmp_path.open("wb") as fh:
                    pickle.dump(payload, fh, protocol=pickle.HIGHEST_PROTOCOL)
            else:
                with tmp_path.open("w", encoding="utf-8") as fh:
                    json.dump(payload, fh, ensure_ascii=False)
            os.replace(tmp_path, self.index_path)

    def upsert_chunks(self, chunks: Sequence[dict[str, Any]]) -> int:
        """Idempotently upsert chunks into the BM25 index and persist atomically."""
        if not chunks:
            return 0

        with self._lock:
            for raw_chunk in chunks:
                chunk = dict(raw_chunk)
                if "category" in chunk and chunk["category"] is not None:
                    chunk["category"] = _enum_str(chunk["category"])
                if chunk.get("section_num"):
                    chunk["section_num"] = normalize_nepali_digits(str(chunk["section_num"])).strip()

                chunk_id = str(chunk["chunk_id"])
                tokens = tokenize_legal_text(_chunk_index_text(chunk), remove_stopwords=True)

                if chunk_id in self._chunk_pos:
                    idx = self._chunk_pos[chunk_id]
                    self._chunks[idx] = chunk
                    self._tokenized_corpus[idx] = tokens
                else:
                    self._chunk_pos[chunk_id] = len(self._chunks)
                    self._chunks.append(chunk)
                    self._tokenized_corpus.append(tokens)

            self._rebuild_model()
            self.save()
            return len(chunks)

    def delete_by_doc_id(self, doc_id: str) -> int:
        """Remove all chunks matching `doc_id`, rebuild BM25, and persist."""
        if not doc_id:
            return 0

        with self._lock:
            before = len(self._chunks)
            kept_chunks: list[dict[str, Any]] = []
            kept_tokens: list[list[str]] = []

            for chunk, tokens in zip(self._chunks, self._tokenized_corpus):
                if chunk.get("doc_id") != doc_id:
                    kept_chunks.append(chunk)
                    kept_tokens.append(tokens)

            removed = before - len(kept_chunks)
            if removed == 0:
                return 0

            self._chunks = kept_chunks
            self._tokenized_corpus = kept_tokens
            self._rebuild_model()
            self.save()
            return removed

    def count_docs(self) -> int:
        """Return number of indexed chunks in the BM25 store."""
        with self._lock:
            return len(self._chunks)

    def list_doc_chunks(self, doc_id: str) -> list[dict[str, Any]]:
        """Return all stored chunks for `doc_id` ordered by `chunk_index`."""
        with self._lock:
            matches = [dict(c) for c in self._chunks if c.get("doc_id") == doc_id]
        matches.sort(key=lambda item: int(item.get("chunk_index", 0)))
        return matches

    def search_bm25(
        self,
        query: str,
        limit: int = 10,
        filters: SearchFilter | dict[str, Any] | None = None,
    ) -> list[dict[str, Any]]:
        """Execute Nepglish-expanded BM25 lexical search with exact section-number boosting."""
        if limit <= 0:
            return []

        sf = (
            filters
            if (filters is None or isinstance(filters, SearchFilter))
            else SearchFilter.model_validate(filters)
        )
        query_tokens = expand_query_tokens(query)
        if not query_tokens and not (sf and sf.section_num):
            return []

        query_sections = set(extract_section_numbers(query))
        if sf and sf.section_num:
            query_sections.add(normalize_nepali_digits(sf.section_num).strip())
        query_token_set = set(query_tokens)

        with self._lock:
            if not self._chunks or self._bm25 is None:
                return []

            raw_scores = self._bm25.get_scores(query_tokens) if query_tokens else [0.0] * len(self._chunks)
            scored: list[tuple[float, dict[str, Any]]] = []

            for idx, (chunk, doc_tokens) in enumerate(zip(self._chunks, self._tokenized_corpus)):
                if not _matches_filter(chunk, sf):
                    continue

                base_score = float(raw_scores[idx])
                overlap = len(query_token_set.intersection(doc_tokens))
                # Guard against BM25 IDF <= 0 on tiny 1-2 doc corpora when terms legitimately overlap
                if base_score <= 0.0 and overlap > 0:
                    base_score = 0.25 * overlap

                chunk_sec = normalize_nepali_digits(str(chunk.get("section_num") or "")).strip()
                section_exact = bool(chunk_sec and chunk_sec in query_sections)
                total_score = base_score + (5.0 if section_exact else 0.0)

                if total_score <= 0.0:
                    continue

                hit = dict(chunk)
                hit["bm25_score"] = total_score
                hit["section_exact"] = section_exact
                scored.append((total_score, hit))

        scored.sort(key=lambda pair: pair[0], reverse=True)
        return [hit for _, hit in scored[:limit]]
