"""Tests for multi-format extraction, Preeti conversion, chunking, deduplication, and deletion."""

from __future__ import annotations

import asyncio
import io
from pathlib import Path

import pytest
from docx import Document as DocxDocument

from app.config import Settings
from app.ingestion.chunker import (
    build_citation_label,
    chunk_document,
    normalize_devanagari_digits,
)
from app.ingestion.extractors import (
    PreetiConverter,
    ScannedPDFError,
    extract_bytes,
    extract_file,
)
from app.ingestion.pipeline import IngestionPipeline
from app.rag.hybrid_retriever import HybridRetriever
from app.schemas import CategoryEnum, SearchFilter
from tests.conftest import build_sample_pdf_bytes


def test_pdf_extraction_and_page_chunking(sample_nepal_law_pdf_path: Path) -> None:
    extracted = extract_file(sample_nepal_law_pdf_path)
    assert extracted.format == "pdf"
    assert extracted.page_count == 3
    assert len(extracted.pages) == 3
    assert "Article 28" in extracted.pages[0].text
    assert "Section 391" in extracted.pages[1].text
    assert "Section 106" in extracted.pages[2].text

    chunks = chunk_document(
        extracted,
        doc_id="doc-sample-pdf",
        act_name="Nepal Sample Statutes",
        category=CategoryEnum.CODES,
    )
    assert len(chunks) >= 5
    sec_391 = next(c for c in chunks if c.section_num == "391")
    sec_106 = next(c for c in chunks if c.section_num == "106")
    assert sec_391.page_start == 2
    assert sec_391.page_end == 2
    assert sec_106.page_start == 3
    assert sec_391.citation_label == "Nepal Sample Statutes, Sec. 391"


def test_scanned_pdf_raises_actionable_error() -> None:
    empty_pdf = build_sample_pdf_bytes([[""], [""]])
    with pytest.raises(ScannedPDFError, match="Scanned or image-only PDF"):
        extract_bytes(empty_pdf, "scanned.pdf")


def test_docx_txt_html_and_markdown_extraction(tmp_path: Path) -> None:
    # 1. DOCX with bilingual paragraphs + table
    docx_path = tmp_path / "rent_notice.docx"
    doc = DocxDocument()
    doc.add_paragraph("Muluki Civil Code 2074")
    doc.add_paragraph("दफा ३९१. बहाल वृद्धि सम्बन्धी व्यवस्था: घरधनीले दोब्बर भाडा असुल गर्न पाउँदैन।")
    table = doc.add_table(rows=1, cols=2)
    table.cell(0, 0).text = "Section 386"
    table.cell(0, 1).text = "Written house rent agreement required."
    doc.save(docx_path)

    docx_extracted = extract_file(docx_path)
    assert docx_extracted.format == "docx"
    assert "दफा ३९१" in docx_extracted.text
    assert "Section 386 | Written house rent agreement required." in docx_extracted.text

    # 2. TXT extraction (English + Devanagari)
    txt_bytes = (
        "Muluki Civil Code 2074\n"
        "दफा ३९१. घरबहाल वृद्धि:\n"
        "दुई वर्ष पूरा भएपछि मात्र घरबहाल वृद्धि गर्न सकिनेछ।\n"
        "Section 392. Termination of tenancy with prior notice."
    ).encode("utf-8")
    txt_extracted = extract_bytes(txt_bytes, "civil_rent.txt")
    assert txt_extracted.format == "text"
    assert txt_extracted.language == "BILINGUAL"

    # 3. HTML extraction stripping nav/script/footer
    html_bytes = (
        "<html><head><title>Nepal Law Commission - Labour Act</title>"
        "<script>alert('bad');</script><style>body{}</style></head>"
        "<body><nav>Home | About | Login</nav>"
        "<main><h1>Labour Act 2074</h1>"
        "<p>Section 106. Every employee shall receive minimum remuneration.</p></main>"
        "<footer>Copyright Nepal Law Commission</footer></body></html>"
    ).encode("utf-8")
    html_extracted = extract_bytes(html_bytes, "labour.html")
    assert html_extracted.format == "html"
    assert html_extracted.title == "Nepal Law Commission - Labour Act"
    assert "Section 106" in html_extracted.text
    assert "alert('bad')" not in html_extracted.text
    assert "Home | About | Login" not in html_extracted.text
    assert "Copyright Nepal Law Commission" not in html_extracted.text

    # 4. Structured Markdown (`law_commission_md`) stripping HTML comments & {TODO: ...}
    md_bytes = (
        "# मुलुकी अपराध संहिता, २०७४\n\n"
        "<!-- SOURCE: NE PDF | FONT: preeti_converted -->\n\n"
        "---\n\n"
        "## दफा ५४: कसूर सम्बन्धी व्यवस्था\n\n"
        "- @act: मुलुकी अपराध संहिता, २०७४\n"
        "- @section: Section 54\n"
        "- @section_ne: दफा ५४\n"
        "- @title_ne: कसूर सम्बन्धी व्यवस्था\n"
        "- @part: General\n\n"
        "**Nepali Text (Primary):**\n"
        "नेपाल बाहिर गरेको कसूरमा समेत सजाय हुनेछ।\n\n"
        "**English Translation:**\n"
        "{TODO: Add English translation}\n"
    ).encode("utf-8")
    md_extracted = extract_bytes(md_bytes, "penal.md")
    assert md_extracted.format == "markdown"
    assert "SOURCE: NE PDF" not in md_extracted.text
    assert "TODO:" not in md_extracted.text

    md_chunks = chunk_document(
        md_extracted,
        doc_id="doc-md-test",
        act_name="Muluki Criminal Code 2074",
        category=CategoryEnum.CODES,
    )
    assert len(md_chunks) == 1
    assert md_chunks[0].section_num == "54"
    assert md_chunks[0].metadata.get("section_ne") == "दफा ५४"
    assert "TODO:" not in md_chunks[0].text


def test_preeti_detection_and_unicode_conversion() -> None:
    preeti_sample = 'g]kfn sfg"g ;+lxtf wkmf #(! adf]lhd axfn 3/wgL'
    assert PreetiConverter.is_preeti_text(preeti_sample) is True

    converted = PreetiConverter.convert(preeti_sample)
    assert "नेपाल" in converted
    assert "३९१" in converted
    assert PreetiConverter.is_preeti_text(converted) is False


def test_devanagari_digit_normalization_and_section_chunking() -> None:
    assert normalize_devanagari_digits("दफा ३९१") == "दफा 391"
    assert build_citation_label("Muluki Civil Code 2074", section_num="३९१") == (
        "Muluki Civil Code 2074, Sec. 391"
    )
    assert build_citation_label("Constitution of Nepal 2072", section_num="२८") == (
        "Constitution of Nepal 2072, Art. 28"
    )

    bilingual_text = (
        "भाग ३ मौलिक हक र कर्तव्य\n"
        "धारा २८. गोपनीयताको हक: कुनै पनि व्यक्तिको जीउ, आवास, सम्पत्तिको गोपनीयता अनतिक्रम्य हुनेछ।\n\n"
        "Muluki Civil Code 2074\n"
        "दफा ३९१. बहाल वृद्धि गर्ने व्यवस्था: घरबहाल दुई वर्षमा मात्र वृद्धि गर्न सकिनेछ।\n"
        "Section 392. Repair and maintenance responsibility of house owner."
    )
    extracted = extract_bytes(bilingual_text.encode("utf-8"), "bilingual_statutes.txt")
    chunks = chunk_document(
        extracted,
        doc_id="doc-bilingual",
        act_name="Muluki Civil Code 2074",
        category=CategoryEnum.CODES,
    )
    section_nums = [c.section_num for c in chunks]
    assert "28" in section_nums
    assert "391" in section_nums
    assert "392" in section_nums

    sec_391 = next(c for c in chunks if c.section_num == "391")
    assert sec_391.citation_label == "Muluki Civil Code 2074, Sec. 391"
    assert len(sec_391.chunk_id) == 36


def test_sha256_deduplication_and_pipeline_delete_cleanup(
    isolated_settings: Settings,
    hybrid_retriever: HybridRetriever,
    sample_nepal_law_pdf_path: Path,
) -> None:
    pipeline = IngestionPipeline(settings=isolated_settings, retriever=hybrid_retriever)

    # First ingestion succeeds
    first = asyncio.run(
        pipeline.ingest_file(
            sample_nepal_law_pdf_path,
            category=CategoryEnum.CODES,
            act_name="Nepal Sample Statutes",
        )
    )
    assert first.status == "indexed"
    assert first.deduplicated is False
    assert first.chunks_indexed >= 4
    assert first.doc_id is not None
    doc_id = first.doc_id

    assert len(pipeline.list_documents()) == 1
    assert hybrid_retriever.get_stats()["qdrant_points"] == first.chunks_indexed
    assert hybrid_retriever.get_stats()["bm25_docs"] == first.chunks_indexed

    # Duplicate content (even under different filename) is deduplicated via SHA-256
    dup = asyncio.run(
        pipeline.ingest_bytes(
            sample_nepal_law_pdf_path.read_bytes(),
            "renamed_copy.pdf",
            category=CategoryEnum.CODES,
            act_name="Nepal Sample Statutes",
        )
    )
    assert dup.status == "skipped_duplicate"
    assert dup.deduplicated is True
    assert dup.chunks_indexed == 0
    assert dup.doc_id == doc_id

    # Force reindex re-processes and replaces chunks cleanly without doubling counts
    reindexed = asyncio.run(
        pipeline.ingest_file(
            sample_nepal_law_pdf_path,
            category=CategoryEnum.CODES,
            act_name="Nepal Sample Statutes",
            force_reindex=True,
        )
    )
    assert reindexed.status == "indexed"
    assert reindexed.deduplicated is False
    assert hybrid_retriever.get_stats()["qdrant_points"] == first.chunks_indexed
    assert hybrid_retriever.get_stats()["bm25_docs"] == first.chunks_indexed

    # Delete removes chunks from Qdrant, BM25, and manifest
    deleted = asyncio.run(pipeline.delete_document(doc_id))
    assert deleted.status == "deleted"
    assert pipeline.list_documents() == []
    assert hybrid_retriever.get_stats()["qdrant_points"] == 0
    assert hybrid_retriever.get_stats()["bm25_docs"] == 0
    after_search = asyncio.run(
        hybrid_retriever.search("house rent 391", filters=SearchFilter(doc_id=doc_id))
    )
    assert after_search.total_results == 0
