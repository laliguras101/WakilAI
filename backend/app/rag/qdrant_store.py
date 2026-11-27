"""Qdrant vector store wrapper supporting local embedded persistence and remote servers."""

from __future__ import annotations

import logging
import re
import uuid
import warnings
from pathlib import Path
from typing import Any, Sequence

from qdrant_client import QdrantClient, models

from app.config import Settings, get_settings
from app.rag.tokenizer import normalize_nepali_digits
from app.schemas import SearchFilter

logger = logging.getLogger(__name__)

_PAYLOAD_INDEX_FIELDS: tuple[str, ...] = (
    "doc_id",
    "category",
    "act_name",
    "language",
    "section_num",
)


def _sanitize_name_part(value: str) -> str:
    cleaned = re.sub(r"[^a-zA-Z0-9_]+", "_", value.strip().lower()).strip("_")
    return cleaned or "default"


def build_collection_name(prefix: str, provider_name: str, dimension: int) -> str:
    """Construct a dimension-safe Qdrant collection name `{prefix}_{provider}_{dim}`."""
    return f"{_sanitize_name_part(prefix)}_{_sanitize_name_part(provider_name)}_{int(dimension)}"


def _to_qdrant_point_id(chunk_id: str) -> str:
    try:
        return str(uuid.UUID(str(chunk_id)))
    except ValueError:
        return str(uuid.uuid5(uuid.NAMESPACE_URL, f"wakil-point:{chunk_id}"))


def _enum_str(value: Any) -> str:
    return str(getattr(value, "value", value))


def build_qdrant_filter(filters: SearchFilter | dict[str, Any] | None) -> models.Filter | None:
    """Translate `SearchFilter` into a Qdrant `models.Filter`."""
    if filters is None:
        return None
    sf = filters if isinstance(filters, SearchFilter) else SearchFilter.model_validate(filters)
    conditions: list[models.Condition] = []

    allowed_categories: list[str] = []
    if sf.category is not None:
        allowed_categories.append(_enum_str(sf.category))
    if sf.categories:
        for cat in sf.categories:
            val = _enum_str(cat)
            if val not in allowed_categories:
                allowed_categories.append(val)

    if len(allowed_categories) == 1:
        conditions.append(
            models.FieldCondition(key="category", match=models.MatchValue(value=allowed_categories[0]))
        )
    elif len(allowed_categories) > 1:
        conditions.append(
            models.FieldCondition(key="category", match=models.MatchAny(any=allowed_categories))
        )

    if sf.act_name:
        conditions.append(
            models.FieldCondition(key="act_name", match=models.MatchValue(value=sf.act_name))
        )
    if sf.doc_id:
        conditions.append(
            models.FieldCondition(key="doc_id", match=models.MatchValue(value=sf.doc_id))
        )
    if sf.language:
        conditions.append(
            models.FieldCondition(key="language", match=models.MatchValue(value=sf.language))
        )
    if sf.section_num:
        norm_section = normalize_nepali_digits(sf.section_num).strip()
        if norm_section:
            conditions.append(
                models.FieldCondition(key="section_num", match=models.MatchValue(value=norm_section))
            )

    if not conditions:
        return None
    return models.Filter(must=conditions)


class QdrantVectorStore:
    """Idempotent Qdrant store using embedded disk persistence or remote Qdrant URL."""

    def __init__(
        self,
        settings: Settings | None = None,
        *,
        embedding_provider: str = "gemini",
        dimension: int = 768,
        collection_name: str | None = None,
        qdrant_path: Path | str | None = None,
        qdrant_url: str | None = None,
        qdrant_api_key: str | None = None,
    ) -> None:
        self.settings = settings or get_settings()
        self.dimension = int(dimension)
        self.embedding_provider = embedding_provider
        self.collection_name = collection_name or build_collection_name(
            self.settings.qdrant_collection_prefix,
            embedding_provider,
            self.dimension,
        )

        resolved_url = qdrant_url if qdrant_url is not None else self.settings.qdrant_url
        resolved_key = qdrant_api_key if qdrant_api_key is not None else self.settings.qdrant_api_key
        resolved_path = Path(qdrant_path) if qdrant_path is not None else self.settings.qdrant_path

        if resolved_url:
            self.mode = "remote"
            self.client = QdrantClient(
                url=resolved_url,
                api_key=resolved_key,
                timeout=30.0,
            )
        else:
            self.mode = "embedded"
            resolved_path.mkdir(parents=True, exist_ok=True)
            self.client = QdrantClient(path=str(resolved_path))

        self._collection_ready = False

    def ensure_collection(self, dimension: int | None = None) -> str:
        """Create collection & payload indexes if missing, or validate existing vector dimension."""
        if dimension is not None and int(dimension) != self.dimension and not self._collection_ready:
            self.dimension = int(dimension)
            self.collection_name = build_collection_name(
                self.settings.qdrant_collection_prefix,
                self.embedding_provider,
                self.dimension,
            )

        if self._collection_ready:
            return self.collection_name

        if not self.client.collection_exists(self.collection_name):
            self.client.create_collection(
                collection_name=self.collection_name,
                vectors_config=models.VectorParams(
                    size=self.dimension,
                    distance=models.Distance.COSINE,
                ),
            )
            self._ensure_payload_indexes()
        else:
            info = self.client.get_collection(self.collection_name)
            vectors_cfg = info.config.params.vectors
            existing_size = getattr(vectors_cfg, "size", None)
            if existing_size is not None and int(existing_size) != self.dimension:
                raise ValueError(
                    f"Qdrant collection '{self.collection_name}' has dimension {existing_size}, "
                    f"expected {self.dimension}."
                )
            self._ensure_payload_indexes()

        self._collection_ready = True
        return self.collection_name

    def _ensure_payload_indexes(self) -> None:
        with warnings.catch_warnings():
            warnings.filterwarnings(
                "ignore",
                message="Payload indexes have no effect in the local Qdrant.*",
                category=UserWarning,
            )
            for field_name in _PAYLOAD_INDEX_FIELDS:
                try:
                    self.client.create_payload_index(
                        collection_name=self.collection_name,
                        field_name=field_name,
                        field_schema=models.PayloadSchemaType.KEYWORD,
                    )
                except Exception as exc:
                    logger.debug("Payload index creation skipped for %s: %s", field_name, exc)

    def upsert_chunks(
        self,
        chunks: Sequence[dict[str, Any]],
        vectors: Sequence[Sequence[float]],
        batch_size: int = 100,
    ) -> int:
        """Idempotently upsert chunk payloads and dense vectors into Qdrant."""
        if not chunks:
            return 0
        if len(chunks) != len(vectors):
            raise ValueError(
                f"Chunk count ({len(chunks)}) does not match vector count ({len(vectors)})."
            )

        vec_dim = len(vectors[0])
        self.ensure_collection(dimension=vec_dim)

        points: list[models.PointStruct] = []
        for chunk, vec in zip(chunks, vectors):
            payload = dict(chunk)
            if "category" in payload and payload["category"] is not None:
                payload["category"] = _enum_str(payload["category"])
            if payload.get("section_num"):
                payload["section_num"] = normalize_nepali_digits(str(payload["section_num"])).strip()
            chunk_id = str(payload.get("chunk_id") or uuid.uuid4())
            payload["chunk_id"] = chunk_id
            points.append(
                models.PointStruct(
                    id=_to_qdrant_point_id(chunk_id),
                    vector=[float(x) for x in vec],
                    payload=payload,
                )
            )

        for start in range(0, len(points), batch_size):
            self.client.upsert(
                collection_name=self.collection_name,
                points=points[start : start + batch_size],
                wait=True,
            )
        return len(points)

    def search_dense(
        self,
        query_vec: Sequence[float],
        limit: int = 10,
        filters: SearchFilter | dict[str, Any] | None = None,
        score_threshold: float | None = None,
    ) -> list[dict[str, Any]]:
        """Query Qdrant for dense nearest neighbors with optional payload filters."""
        if limit <= 0 or not self.client.collection_exists(self.collection_name):
            return []

        qfilter = build_qdrant_filter(filters)
        response = self.client.query_points(
            collection_name=self.collection_name,
            query=[float(x) for x in query_vec],
            query_filter=qfilter,
            limit=limit,
            with_payload=True,
            score_threshold=score_threshold,
        )

        hits: list[dict[str, Any]] = []
        for point in response.points:
            payload = dict(point.payload or {})
            payload.setdefault("chunk_id", str(point.id))
            payload["dense_score"] = float(point.score)
            hits.append(payload)
        return hits

    def delete_by_doc_id(self, doc_id: str) -> int:
        """Delete all points associated with `doc_id` and return removed count."""
        if not doc_id or not self.client.collection_exists(self.collection_name):
            return 0

        doc_filter = models.Filter(
            must=[models.FieldCondition(key="doc_id", match=models.MatchValue(value=doc_id))]
        )
        before_count = int(
            self.client.count(
                collection_name=self.collection_name,
                count_filter=doc_filter,
                exact=True,
            ).count
        )
        if before_count == 0:
            return 0

        self.client.delete(
            collection_name=self.collection_name,
            points_selector=models.FilterSelector(filter=doc_filter),
            wait=True,
        )
        return before_count

    def count_points(self) -> int:
        """Return total indexed vector count in the active collection."""
        if not self.client.collection_exists(self.collection_name):
            return 0
        return int(self.client.count(collection_name=self.collection_name, exact=True).count)

    def list_doc_chunks(self, doc_id: str, limit: int = 1000) -> list[dict[str, Any]]:
        """Retrieve all stored chunk payloads for a given `doc_id`, ordered by `chunk_index`."""
        if not doc_id or not self.client.collection_exists(self.collection_name):
            return []

        doc_filter = models.Filter(
            must=[models.FieldCondition(key="doc_id", match=models.MatchValue(value=doc_id))]
        )
        collected: list[dict[str, Any]] = []
        next_offset: Any = None

        while len(collected) < limit:
            page_limit = min(256, limit - len(collected))
            records, next_offset = self.client.scroll(
                collection_name=self.collection_name,
                scroll_filter=doc_filter,
                limit=page_limit,
                offset=next_offset,
                with_payload=True,
                with_vectors=False,
            )
            for rec in records:
                payload = dict(rec.payload or {})
                payload.setdefault("chunk_id", str(rec.id))
                collected.append(payload)
            if next_offset is None or not records:
                break

        collected.sort(key=lambda item: int(item.get("chunk_index", 0)))
        return collected

    def close(self) -> None:
        """Close the underlying Qdrant client cleanly to release local file locks."""
        try:
            self.client.close()
        except Exception as exc:
            logger.debug("Ignoring Qdrant close error: %s", exc)
