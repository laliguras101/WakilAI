"""Hybrid RAG subsystem for WakilAI: tokenizer, embeddings, Qdrant, BM25, and RRF retriever."""

from app.rag.bm25_store import BM25Store
from app.rag.embeddings import EmbeddingProvider, create_embedding_provider
from app.rag.hybrid_retriever import HybridRetriever
from app.rag.qdrant_store import QdrantVectorStore, build_collection_name
from app.rag.tokenizer import (
    DEVANAGARI_STATUTORY_ALIASES,
    NEPGLISH_STATUTORY_ALIASES,
    clean_legal_text,
    expand_query_tokens,
    extract_section_numbers,
    normalize_nepali_digits,
    tokenize_legal_text,
)

__all__ = [
    "BM25Store",
    "DEVANAGARI_STATUTORY_ALIASES",
    "EmbeddingProvider",
    "HybridRetriever",
    "NEPGLISH_STATUTORY_ALIASES",
    "QdrantVectorStore",
    "build_collection_name",
    "clean_legal_text",
    "create_embedding_provider",
    "expand_query_tokens",
    "extract_section_numbers",
    "normalize_nepali_digits",
    "tokenize_legal_text",
]
