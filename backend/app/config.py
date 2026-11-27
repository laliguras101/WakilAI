"""Application configuration and normalized filesystem paths for WakilAI backend."""

from __future__ import annotations

import os
from functools import lru_cache
from pathlib import Path
from typing import Literal, Optional

from pydantic import Field, field_validator
from pydantic_settings import BaseSettings, SettingsConfigDict

BACKEND_DIR: Path = Path(__file__).resolve().parent.parent
DATA_DIR: Path = BACKEND_DIR / "data"


def normalize_backend_path(value: str | Path, base_dir: Path = BACKEND_DIR) -> Path:
    """Resolve relative paths against the backend root directory and expand vars."""
    expanded = os.path.expandvars(os.path.expanduser(str(value).strip()))
    path = Path(expanded)
    if not path.is_absolute():
        path = base_dir / path
    return path.resolve()


class Settings(BaseSettings):
    """Typed runtime settings loaded from environment variables and `.env`."""

    model_config = SettingsConfigDict(
        env_file=(str(BACKEND_DIR / ".env"), ".env"),
        env_file_encoding="utf-8",
        extra="ignore",
        case_sensitive=False,
    )

    # Application & Server
    app_name: str = "WakilAI Legal RAG API"
    app_version: str = "0.1.0"
    host: str = "0.0.0.0"
    port: int = Field(default=8000, ge=1, le=65535)
    log_level: str = "info"
    cors_origins: list[str] = Field(default_factory=lambda: ["*"])

    # API Keys & External Endpoints
    gemini_api_key: Optional[str] = None
    kilocode_api_key: Optional[str] = None
    openai_api_key: Optional[str] = None
    openai_base_url: Optional[str] = None
    tavily_api_key: Optional[str] = None

    # Optional Firebase Auth Verification (RAG & AI routing remain standalone when false)
    firebase_project_id: Optional[str] = None
    firebase_auth_required: bool = False

    # Vector Store & Persistence Paths
    qdrant_url: Optional[str] = None
    qdrant_api_key: Optional[str] = None
    qdrant_collection_prefix: str = "wakil_nepal_laws"
    qdrant_path: Path = Field(default_factory=lambda: DATA_DIR / "qdrant")
    bm25_path: Path = Field(default_factory=lambda: DATA_DIR / "bm25_index.json")
    manifest_path: Path = Field(default_factory=lambda: DATA_DIR / "corpus_manifest.json")
    raw_data_dir: Path = Field(default_factory=lambda: DATA_DIR / "raw")

    # Embeddings Configuration
    embedding_provider: Literal[
        "auto",
        "gemini",
        "fastembed",
        "openai",
        "openai_compatible",
        "hashed_tfidf",
    ] = "auto"
    embedding_model: str = "gemini-embedding-001"
    embedding_dim: int = Field(default=768, ge=64, le=4096)
    fastembed_model: str = "sentence-transformers/paraphrase-multilingual-MiniLM-L12-v2"
    openai_embedding_model: str = "text-embedding-3-small"

    # LLM Gateway Configuration
    default_llm_provider: Literal["auto", "kilo", "gemini", "openai_compatible"] = "auto"
    kilo_base_url: str = "https://api.kilo.ai/api/gateway"
    default_kilo_model: str = "kilo-auto/free"
    default_gemini_model: str = "gemini-2.5-flash"
    default_openai_model: str = "gpt-4o-mini"
    default_temperature: float = Field(default=0.2, ge=0.0, le=2.0)
    default_max_tokens: int = Field(default=2048, ge=64, le=128000)

    # Ingestion & Search Tuning
    chunk_size: int = Field(default=1200, ge=200, le=8000)
    chunk_overlap: int = Field(default=200, ge=0, le=2000)
    default_top_k: int = Field(default=6, ge=1, le=50)
    web_search_timeout: float = Field(default=15.0, ge=1.0, le=120.0)
    llm_timeout: float = Field(default=60.0, ge=5.0, le=300.0)

    @field_validator(
        "gemini_api_key",
        "kilocode_api_key",
        "openai_api_key",
        "openai_base_url",
        "tavily_api_key",
        "qdrant_url",
        "qdrant_api_key",
        mode="before",
    )
    @classmethod
    def _empty_str_to_none(cls, value: object) -> object:
        if isinstance(value, str):
            stripped = value.strip()
            return stripped if stripped else None
        return value

    @field_validator("qdrant_path", "bm25_path", "manifest_path", "raw_data_dir", mode="before")
    @classmethod
    def _normalize_storage_paths(cls, value: object) -> Path:
        if value is None or (isinstance(value, str) and not value.strip()):
            raise ValueError("Storage path cannot be empty")
        if isinstance(value, (str, Path)):
            return normalize_backend_path(value)
        raise TypeError(f"Invalid path type: {type(value)!r}")

    @field_validator("kilo_base_url", "openai_base_url", mode="after")
    @classmethod
    def _strip_trailing_slash(cls, value: Optional[str]) -> Optional[str]:
        if value is None:
            return None
        return value.rstrip("/")

    @field_validator("cors_origins", mode="before")
    @classmethod
    def _parse_cors_origins(cls, value: object) -> object:
        if isinstance(value, str):
            stripped = value.strip()
            if not stripped:
                return ["*"]
            if stripped.startswith("["):
                return value
            return [origin.strip() for origin in stripped.split(",") if origin.strip()]
        return value

    @property
    def backend_dir(self) -> Path:
        """Absolute path to the `backend/` root directory."""
        return BACKEND_DIR

    @property
    def data_dir(self) -> Path:
        """Absolute path to the default `backend/data/` directory."""
        return DATA_DIR

    def ensure_data_dirs(self) -> None:
        """Create local storage directories required by Qdrant, BM25, and manifest."""
        self.data_dir.mkdir(parents=True, exist_ok=True)
        self.raw_data_dir.mkdir(parents=True, exist_ok=True)
        if not self.qdrant_url:
            self.qdrant_path.mkdir(parents=True, exist_ok=True)
        self.bm25_path.parent.mkdir(parents=True, exist_ok=True)
        self.manifest_path.parent.mkdir(parents=True, exist_ok=True)


@lru_cache(maxsize=1)
def get_settings() -> Settings:
    """Return cached singleton `Settings` instance."""
    return Settings()
