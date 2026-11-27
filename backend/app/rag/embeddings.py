"""Model-agnostic dense embedding providers for WakilAI Hybrid RAG."""

from __future__ import annotations

import asyncio
import hashlib
import logging
import math
import re
from typing import Any, Sequence

from app.config import Settings, get_settings
from app.rag.tokenizer import tokenize_legal_text

logger = logging.getLogger(__name__)

_RETRY_DELAY_RE = re.compile(
    r"(?:retry\s+(?:in|after)\s+|retryDelay[\"']?\s*[:=]\s*[\"']?)([0-9]+(?:\.[0-9]+)?)\s*s?",
    flags=re.IGNORECASE,
)

try:
    from fastembed import TextEmbedding as _FastEmbedTextEmbedding  # type: ignore
except ImportError:  # pragma: no cover - optional dependency fallback
    _FastEmbedTextEmbedding = None


def _l2_normalize(vector: Sequence[float]) -> list[float]:
    """Normalize a vector to unit L2 length for consistent cosine similarity."""
    vals = [float(x) for x in vector]
    norm = math.sqrt(sum(x * x for x in vals))
    if norm <= 1e-12:
        return vals
    return [x / norm for x in vals]


def _is_fastembed_available() -> bool:
    return _FastEmbedTextEmbedding is not None


def _resolve_fastembed_dim(model_name: str, fallback_dim: int) -> int:
    if _FastEmbedTextEmbedding is None:
        return fallback_dim
    try:
        for meta in _FastEmbedTextEmbedding.list_supported_models():
            if meta.get("model") == model_name and meta.get("dim"):
                return int(meta["dim"])
    except Exception:
        pass
    return fallback_dim


def _infer_openai_dim(model_name: str, fallback_dim: int) -> int:
    known = {
        "text-embedding-3-small": 1536,
        "text-embedding-3-large": 3072,
        "text-embedding-ada-002": 1536,
        "nomic-embed-text": 768,
        "mxbai-embed-large": 1024,
        "bge-m3": 1024,
    }
    return known.get(model_name, fallback_dim)


class EmbeddingProvider:
    """Unified async dense embedding interface supporting Gemini, FastEmbed, OpenAI-compatible, and hashed TF-IDF."""

    def __init__(
        self,
        settings: Settings | None = None,
        *,
        provider: str | None = None,
        model_name: str | None = None,
        dimension: int | None = None,
    ) -> None:
        self.settings = settings or get_settings()
        requested = (provider or self.settings.embedding_provider or "auto").strip().lower()

        self.is_fallback = False
        self.status_note = ""
        self._fastembed_instance: Any = None
        self._gemini_client: Any = None
        self._dimension_confirmed = False

        resolved = self._resolve_provider(requested)
        self.provider_name: str = resolved

        if resolved == "gemini":
            self.model_name = model_name or self.settings.embedding_model
            self.dimension = int(dimension or self.settings.embedding_dim)
            self._dimension_confirmed = True
            self.status_note = "Google Gemini embeddings active"
        elif resolved == "fastembed":
            self.model_name = model_name or self.settings.fastembed_model
            self.dimension = int(dimension or _resolve_fastembed_dim(self.model_name, 384))
            self._dimension_confirmed = True
            self.status_note = "Local FastEmbed ONNX embeddings active"
        elif resolved == "openai_compatible":
            self.model_name = model_name or self.settings.openai_embedding_model
            if dimension is not None:
                self.dimension = int(dimension)
                self._dimension_confirmed = True
            else:
                self.dimension = _infer_openai_dim(self.model_name, self.settings.embedding_dim)
            self.status_note = "OpenAI-compatible embeddings active"
        else:
            self.provider_name = "hashed_tfidf"
            self.model_name = model_name or "hashed-tfidf-ngram-v1"
            self.dimension = int(dimension or self.settings.embedding_dim)
            self.is_fallback = True
            self._dimension_confirmed = True
            self.status_note = (
                "Non-neural deterministic hashed TF-IDF n-gram embeddings active (explicit/fallback)"
            )

    def _resolve_provider(self, requested: str) -> str:
        if requested == "openai":
            requested = "openai_compatible"

        if requested != "auto":
            if requested == "gemini" and not self.settings.gemini_api_key:
                raise ValueError("EMBEDDING_PROVIDER='gemini' requires GEMINI_API_KEY.")
            if requested == "fastembed" and not _is_fastembed_available():
                raise ValueError("EMBEDDING_PROVIDER='fastembed' requested, but fastembed is not installed.")
            if requested == "openai_compatible" and not (
                self.settings.openai_base_url or self.settings.openai_api_key
            ):
                raise ValueError(
                    "EMBEDDING_PROVIDER='openai_compatible' requires OPENAI_BASE_URL or OPENAI_API_KEY."
                )
            return requested

        # Auto selection order: local multilingual FastEmbed -> Gemini -> OpenAI embeddings -> hashed_tfidf
        if _is_fastembed_available():
            return "fastembed"
        if self.settings.gemini_api_key:
            return "gemini"
        if self.settings.openai_base_url:
            return "openai_compatible"
        return "hashed_tfidf"

    def _get_gemini_client(self) -> Any:
        if self._gemini_client is None:
            from google import genai

            self._gemini_client = genai.Client(api_key=self.settings.gemini_api_key)
        return self._gemini_client

    def _get_fastembed_model(self) -> Any:
        if self._fastembed_instance is None:
            if _FastEmbedTextEmbedding is None:
                raise RuntimeError("fastembed package is not installed")
            self._fastembed_instance = _FastEmbedTextEmbedding(model_name=self.model_name)
        return self._fastembed_instance

    def _embed_gemini_batch_sync(self, texts: list[str], task_type: str) -> list[list[float]]:
        from google.genai import types

        client = self._get_gemini_client()
        response = client.models.embed_content(
            model=self.model_name,
            contents=texts,
            config=types.EmbedContentConfig(
                task_type=task_type,
                output_dimensionality=self.dimension,
            ),
        )
        return [_l2_normalize(item.values) for item in response.embeddings]

    @staticmethod
    def _is_rate_limit_error(exc: Exception) -> bool:
        msg = f"{type(exc).__name__} {exc}".lower()
        return "429" in msg or "resource_exhausted" in msg or "quota" in msg or "rate limit" in msg

    @staticmethod
    def _extract_retry_delay_seconds(exc: Exception, attempt: int) -> float:
        match = _RETRY_DELAY_RE.search(str(exc))
        if match:
            try:
                parsed = float(match.group(1))
                return min(max(parsed + 2.0, 5.0), 75.0)
            except ValueError:
                pass
        return min(60.0 + attempt * 5.0, 75.0)

    async def _embed_gemini_with_retry(
        self, texts: list[str], task_type: str, max_attempts: int = 4
    ) -> list[list[float]]:
        for attempt in range(max_attempts):
            try:
                return await asyncio.to_thread(self._embed_gemini_batch_sync, texts, task_type)
            except Exception as exc:
                if attempt >= max_attempts - 1:
                    raise
                if self._is_rate_limit_error(exc):
                    delay = self._extract_retry_delay_seconds(exc, attempt)
                    logger.warning(
                        "Gemini embedding rate-limited (attempt %d/%d); sleeping %.1fs before retry",
                        attempt + 1,
                        max_attempts,
                        delay,
                    )
                else:
                    delay = min(1.0 * (2**attempt), 8.0)
                    logger.warning(
                        "Gemini embedding transient error (%s, attempt %d/%d); retrying in %.1fs",
                        type(exc).__name__,
                        attempt + 1,
                        max_attempts,
                        delay,
                    )
                await asyncio.sleep(delay)
        raise RuntimeError("Unreachable Gemini embedding retry exit")

    def _embed_fastembed_sync(self, texts: list[str], is_query: bool) -> list[list[float]]:
        model = self._get_fastembed_model()
        if is_query and hasattr(model, "query_embed"):
            raw_vectors = list(model.query_embed(texts))
        else:
            raw_vectors = list(model.embed(texts, batch_size=64))
        vectors = [_l2_normalize(vec.tolist() if hasattr(vec, "tolist") else vec) for vec in raw_vectors]
        if vectors and len(vectors[0]) != self.dimension:
            self.dimension = len(vectors[0])
        self._dimension_confirmed = True
        return vectors

    async def _embed_openai_batch(self, texts: list[str]) -> list[list[float]]:
        from openai import AsyncOpenAI

        client_kwargs: dict[str, Any] = {
            "api_key": self.settings.openai_api_key or "not-needed",
            "timeout": float(self.settings.llm_timeout),
        }
        if self.settings.openai_base_url:
            client_kwargs["base_url"] = self.settings.openai_base_url

        client = AsyncOpenAI(**client_kwargs)
        try:
            kwargs: dict[str, Any] = {
                "model": self.model_name,
                "input": texts,
            }
            if self.model_name.startswith("text-embedding-3-"):
                kwargs["dimensions"] = self.dimension

            try:
                response = await client.embeddings.create(**kwargs)
            except Exception as exc:
                # Some custom OpenAI-compatible gateways reject the optional `dimensions` arg
                if "dimensions" in kwargs and "dimension" in str(exc).lower():
                    kwargs.pop("dimensions", None)
                    response = await client.embeddings.create(**kwargs)
                else:
                    raise

            sorted_data = sorted(response.data, key=lambda item: item.index)
            vectors = [_l2_normalize(item.embedding) for item in sorted_data]
            if vectors and not self._dimension_confirmed:
                self.dimension = len(vectors[0])
                self._dimension_confirmed = True
            return vectors
        finally:
            await client.close()

    def _embed_hashed_tfidf_sync(self, texts: list[str]) -> list[list[float]]:
        dim = self.dimension
        vectors: list[list[float]] = []

        for text in texts:
            vec = [0.0] * dim
            tokens = tokenize_legal_text(text, remove_stopwords=False)
            counts: dict[str, int] = {}

            for tok in tokens:
                counts[f"w:{tok}"] = counts.get(f"w:{tok}", 0) + 1
                # Character 3-grams and 4-grams help Nepglish/Devanagari morphological matching
                if len(tok) >= 3:
                    padded = f"^{tok}$"
                    for n in (3, 4):
                        if len(padded) >= n:
                            for idx in range(len(padded) - n + 1):
                                gram = f"g{n}:{padded[idx : idx + n]}"
                                counts[gram] = counts.get(gram, 0) + 1

            for feature, count in counts.items():
                digest = hashlib.blake2b(feature.encode("utf-8"), digest_size=8).digest()
                raw_int = int.from_bytes(digest, "little", signed=False)
                bucket = raw_int % dim
                sign = 1.0 if ((raw_int >> 63) & 1) == 0 else -1.0
                weight = (1.0 + math.log(count)) * (1.4 if feature.startswith("w:") else 0.6)
                vec[bucket] += sign * weight

            vectors.append(_l2_normalize(vec))
        return vectors

    async def ensure_dimension(self) -> int:
        """Confirm actual vector dimension by probing when the backend dimension is dynamic."""
        if not self._dimension_confirmed:
            vec = await self.embed_query("dimension probe")
            if vec:
                self.dimension = len(vec)
                self._dimension_confirmed = True
        return self.dimension

    async def embed_documents(self, texts: Sequence[str], batch_size: int = 64) -> list[list[float]]:
        """Embed a sequence of document texts into L2-normalized dense vectors."""
        if not texts:
            return []

        effective_batch_size = min(batch_size, 50) if self.provider_name == "gemini" else batch_size
        sanitized = [t if (t and t.strip()) else " " for t in texts]
        results: list[list[float]] = []

        for start in range(0, len(sanitized), effective_batch_size):
            batch = sanitized[start : start + effective_batch_size]
            if self.provider_name == "gemini":
                vecs = await self._embed_gemini_with_retry(batch, "RETRIEVAL_DOCUMENT")
            elif self.provider_name == "fastembed":
                vecs = await asyncio.to_thread(self._embed_fastembed_sync, batch, False)
            elif self.provider_name == "openai_compatible":
                vecs = await self._embed_openai_batch(batch)
            else:
                vecs = self._embed_hashed_tfidf_sync(batch)
            results.extend(vecs)

        return results

    async def embed_query(self, text: str) -> list[float]:
        """Embed a single search query into an L2-normalized dense vector."""
        sanitized = text if (text and text.strip()) else " "
        if self.provider_name == "gemini":
            vecs = await self._embed_gemini_with_retry([sanitized], "RETRIEVAL_QUERY")
            return vecs[0]
        if self.provider_name == "fastembed":
            vecs = await asyncio.to_thread(self._embed_fastembed_sync, [sanitized], True)
            return vecs[0]
        if self.provider_name == "openai_compatible":
            vecs = await self._embed_openai_batch([sanitized])
            return vecs[0]
        return self._embed_hashed_tfidf_sync([sanitized])[0]

    def metadata(self) -> dict[str, Any]:
        """Return diagnostic metadata describing the active embedding provider."""
        return {
            "provider": self.provider_name,
            "model": self.model_name,
            "dimension": self.dimension,
            "is_fallback": self.is_fallback,
            "note": self.status_note,
        }


def create_embedding_provider(
    settings: Settings | None = None,
    *,
    provider: str | None = None,
    model_name: str | None = None,
    dimension: int | None = None,
) -> EmbeddingProvider:
    """Factory creating an `EmbeddingProvider` from runtime `Settings`."""
    return EmbeddingProvider(
        settings=settings,
        provider=provider,
        model_name=model_name,
        dimension=dimension,
    )
