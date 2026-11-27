"""Nepalese legal corpus ingestion package for WakilAI."""

from app.ingestion.chunker import (
    StatutoryChunk,
    build_citation_label,
    chunk_document,
    detect_language,
    normalize_devanagari_digits,
)
from app.ingestion.extractors import (
    DocumentExtractionError,
    ExtractedDocument,
    ExtractedPage,
    PreetiConverter,
    ScannedPDFError,
    extract_bytes,
    extract_file,
    extract_url,
)
from app.ingestion.nepal_sources import (
    CORE_NEPAL_SOURCES,
    NepalSourceSpec,
    discover_local_corpus_files,
    infer_category_from_path_or_name,
)
from app.ingestion.pipeline import (
    IngestionPipeline,
    RetrieverProtocol,
    bootstrap_nepal_corpus,
)

__all__ = [
    "CORE_NEPAL_SOURCES",
    "DocumentExtractionError",
    "ExtractedDocument",
    "ExtractedPage",
    "IngestionPipeline",
    "NepalSourceSpec",
    "PreetiConverter",
    "RetrieverProtocol",
    "ScannedPDFError",
    "StatutoryChunk",
    "bootstrap_nepal_corpus",
    "build_citation_label",
    "chunk_document",
    "detect_language",
    "discover_local_corpus_files",
    "extract_bytes",
    "extract_file",
    "extract_url",
    "infer_category_from_path_or_name",
    "normalize_devanagari_digits",
]
