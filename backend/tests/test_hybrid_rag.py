"""Tests for bilingual/Nepglish tokenization, BM25 + Qdrant RRF fusion, filters, and persistence."""

from __future__ import annotations

import asyncio
from typing import Any

from app.config import Settings
from app.rag.bm25_store import BM25Store
from app.rag.hybrid_retriever import HybridRetriever
from app.rag.qdrant_store import build_collection_name
from app.rag.tokenizer import (
    clean_legal_text,
    expand_query_tokens,
    extract_section_numbers,
    normalize_nepali_digits,
    tokenize_legal_text,
)
from app.schemas import CategoryEnum, SearchFilter


def test_nepali_digit_normalization_and_tokenization() -> None:
    assert normalize_nepali_digits("दफा ३९१, धारा २८ र नियम १०६") == "दफा 391, धारा 28 र नियम 106"

    cleaned = clean_legal_text("दफा ३९१। घरबहाल वृद्धि — Section 391!")
    assert "391" in cleaned
    assert "।" not in cleaned

    tokens = tokenize_legal_text("दफा ३९१ of Muluki Civil Code")
    assert "दफा" in tokens
    assert "391" in tokens
    assert "muluki" in tokens
    assert "of" not in tokens

    assert extract_section_numbers("Compare दफा ३९१ with Article 28 and Sec. 106") == [
        "391",
        "28",
        "106",
    ]


def test_nepglish_and_devanagari_alias_expansion() -> None:
    expanded = expand_query_tokens("gharbeti le dafa 391 ma bahal badhauna milchha?")
    for expected in ("gharbeti", "landlord", "house", "rent", "tenancy", "dafa", "section", "391", "bahal"):
        assert expected in expanded

    dev_expanded = expand_query_tokens("दफा ३९१ घरबहाल")
    assert "section" in dev_expanded
    assert "391" in dev_expanded
    assert "rent" in dev_expanded


def test_hybrid_rrf_fusion_bilingual_and_nepglish(
    hybrid_retriever: HybridRetriever,
    sample_legal_chunks: list[dict[str, Any]],
) -> None:
    indexed = asyncio.run(hybrid_retriever.index_chunks(sample_legal_chunks))
    assert indexed == len(sample_legal_chunks)
    assert hybrid_retriever.count() == len(sample_legal_chunks)

    # Nepglish query combining `gharbeti` + `dafa 391`
    nepglish_resp = asyncio.run(
        hybrid_retriever.search("gharbeti dafa 391 rent increase", top_k=3)
    )
    assert nepglish_resp.total_results >= 1
    assert nepglish_resp.embedding_provider == "hashed_tfidf"
    assert "landlord" in nepglish_resp.expanded_tokens
    top_hit = nepglish_resp.results[0]
    assert top_hit.section_num == "391"
    assert top_hit.doc_id == "doc-civil-2074"
    assert "bm25" in top_hit.retrieval_sources
    assert "section_exact" in top_hit.retrieval_sources
    assert top_hit.score > 0

    # Devanagari query with Nepali digits
    nepali_resp = asyncio.run(hybrid_retriever.search("दफा ३९१ घरबहाल", top_k=3))
    assert nepali_resp.results[0].section_num == "391"

    # English query for Constitution right to privacy
    const_resp = asyncio.run(hybrid_retriever.search("right to privacy residence data", top_k=3))
    assert const_resp.results[0].doc_id == "doc-constitution-2072"
    assert const_resp.results[0].section_num == "28"


def test_metadata_filtering_category_and_section(
    hybrid_retriever: HybridRetriever,
    sample_legal_chunks: list[dict[str, Any]],
) -> None:
    asyncio.run(hybrid_retriever.index_chunks(sample_legal_chunks))

    only_const = asyncio.run(
        hybrid_retriever.search(
            "house rent privacy section 391",
            top_k=5,
            filters=SearchFilter(category=CategoryEnum.CONSTITUTION),
        )
    )
    assert only_const.total_results >= 1
    assert all(hit.category == CategoryEnum.CONSTITUTION for hit in only_const.results)

    only_sec_391 = asyncio.run(
        hybrid_retriever.search(
            "rent",
            top_k=5,
            filters=SearchFilter(category=CategoryEnum.CODES, section_num="३९१"),
        )
    )
    assert only_sec_391.total_results == 1
    assert only_sec_391.results[0].section_num == "391"
    assert only_sec_391.results[0].category == CategoryEnum.CODES


def test_persistence_and_reload_across_restart(
    isolated_settings: Settings,
    sample_legal_chunks: list[dict[str, Any]],
) -> None:
    first_retriever = HybridRetriever(settings=isolated_settings)
    try:
        asyncio.run(first_retriever.index_chunks(sample_legal_chunks))
        stats_before = first_retriever.get_stats()
        assert stats_before["qdrant_points"] == len(sample_legal_chunks)
        assert stats_before["bm25_docs"] == len(sample_legal_chunks)
        assert isolated_settings.bm25_path.exists()
    finally:
        first_retriever.close()

    # Simulate process restart with fresh HybridRetriever pointed at the same disk paths
    reloaded = HybridRetriever(settings=isolated_settings)
    try:
        stats_after = reloaded.get_stats()
        assert stats_after["qdrant_points"] == len(sample_legal_chunks)
        assert stats_after["bm25_docs"] == len(sample_legal_chunks)
        assert stats_after["qdrant_collection"] == build_collection_name(
            isolated_settings.qdrant_collection_prefix,
            "hashed_tfidf",
            isolated_settings.embedding_dim,
        )

        resp = asyncio.run(reloaded.search("dafa 391 gharbeti", top_k=3))
        assert resp.total_results >= 1
        assert resp.results[0].section_num == "391"

        # Verify document deletion persists across Qdrant + BM25 reload
        deleted = asyncio.run(reloaded.delete_document("doc-civil-2074"))
        assert deleted["deleted"] is True
        assert deleted["qdrant_deleted"] == 2
        assert deleted["bm25_deleted"] == 2
    finally:
        reloaded.close()

    after_delete = HybridRetriever(settings=isolated_settings)
    try:
        assert after_delete.get_stats()["qdrant_points"] == len(sample_legal_chunks) - 2
        assert after_delete.get_stats()["bm25_docs"] == len(sample_legal_chunks) - 2
        post_del_resp = asyncio.run(
            after_delete.search("section 391", filters=SearchFilter(doc_id="doc-civil-2074"))
        )
        assert post_del_resp.total_results == 0
    finally:
        after_delete.close()


def test_bm25_pickle_persistence_roundtrip(
    isolated_settings: Settings,
    sample_legal_chunks: list[dict[str, Any]],
) -> None:
    pkl_path = isolated_settings.bm25_path.with_suffix(".pkl")
    store = BM25Store(isolated_settings, index_path=pkl_path)
    store.upsert_chunks(sample_legal_chunks)
    assert pkl_path.exists()

    reloaded_store = BM25Store(isolated_settings, index_path=pkl_path)
    assert reloaded_store.count_docs() == len(sample_legal_chunks)
    hits = reloaded_store.search_bm25("cyber electronic publication 47", limit=2)
    assert hits and hits[0]["doc_id"] == "doc-eta-2063"


def test_embedding_provider_l2_norm_and_collection_naming(
    isolated_settings: Settings,
) -> None:
    import math
    from app.rag.embeddings import EmbeddingProvider

    provider = EmbeddingProvider(settings=isolated_settings, provider="hashed_tfidf", dimension=128)
    assert provider.provider_name == "hashed_tfidf"
    assert provider.is_fallback is True
    assert provider.dimension == 128

    vecs = asyncio.run(provider.embed_documents(["दफा ३९१ घरबहाल", "Section 391 house rent"]))
    assert len(vecs) == 2
    assert len(vecs[0]) == 128
    norm = math.sqrt(sum(v * v for v in vecs[0]))
    assert abs(norm - 1.0) < 1e-6

    qvec1 = asyncio.run(provider.embed_query("dafa 391"))
    qvec2 = asyncio.run(provider.embed_query("dafa 391"))
    assert qvec1 == qvec2

    assert build_collection_name("wakil_nepal_laws", "fastembed", 384) == "wakil_nepal_laws_fastembed_384"
    assert build_collection_name("wakil_nepal_laws", "gemini", 768) == "wakil_nepal_laws_gemini_768"

