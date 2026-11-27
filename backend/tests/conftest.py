"""Shared pytest fixtures for WakilAI backend tests."""

from __future__ import annotations

import io
import uuid
from pathlib import Path
from typing import Any, Iterator

import pytest

from app.config import Settings, get_settings
from app.rag.hybrid_retriever import HybridRetriever
from app.schemas import CategoryEnum


def build_sample_pdf_bytes(pages: list[list[str]]) -> bytes:
    """Create a valid multi-page PDF 1.4 byte stream readable by `pdfplumber` and `pypdf`."""
    objects: list[bytes] = []

    def add_obj(body: bytes | str) -> int:
        raw = body.encode("latin-1") if isinstance(body, str) else body
        objects.append(raw)
        return len(objects)

    def escape_pdf_text(text: str) -> str:
        return text.replace("\\", "\\\\").replace("(", "\\(").replace(")", "\\)")

    font_id = add_obj("<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>")
    pages_id = add_obj("")
    page_ids: list[int] = []

    for lines in pages:
        cmds = ["BT", "/F1 11 Tf", "50 750 Td", "14 TL"]
        for idx, line in enumerate(lines):
            escaped = escape_pdf_text(line)
            cmds.append(f"({escaped}) Tj" if idx == 0 else f"T* ({escaped}) Tj")
        cmds.append("ET")
        stream_bytes = "\n".join(cmds).encode("latin-1")
        content_id = add_obj(
            f"<< /Length {len(stream_bytes)} >>\nstream\n".encode("ascii")
            + stream_bytes
            + b"\nendstream"
        )
        page_id = add_obj(
            f"<< /Type /Page /Parent {pages_id} 0 R /MediaBox [0 0 612 792] "
            f"/Resources << /Font << /F1 {font_id} 0 R >> >> /Contents {content_id} 0 R >>"
        )
        page_ids.append(page_id)

    kids = " ".join(f"{pid} 0 R" for pid in page_ids)
    objects[pages_id - 1] = f"<< /Type /Pages /Kids [{kids}] /Count {len(page_ids)} >>".encode(
        "ascii"
    )
    catalog_id = add_obj(f"<< /Type /Catalog /Pages {pages_id} 0 R >>")

    buf = io.BytesIO()
    buf.write(b"%PDF-1.4\n")
    offsets: list[int] = [0]
    for obj_num, body in enumerate(objects, start=1):
        offsets.append(buf.tell())
        buf.write(f"{obj_num} 0 obj\n".encode("ascii"))
        buf.write(body)
        buf.write(b"\nendobj\n")

    xref_pos = buf.tell()
    buf.write(f"xref\n0 {len(objects) + 1}\n".encode("ascii"))
    buf.write(b"0000000000 65535 f \n")
    for off in offsets[1:]:
        buf.write(f"{off:010d} 00000 n \n".encode("ascii"))

    buf.write(
        f"trailer\n<< /Size {len(objects) + 1} /Root {catalog_id} 0 R >>\n"
        f"startxref\n{xref_pos}\n%%EOF\n".encode("ascii")
    )
    return buf.getvalue()


SAMPLE_NEPAL_LAW_PDF_PAGES: list[list[str]] = [
    [
        "The Constitution of Nepal 2072 (2015)",
        "Part-3 Fundamental Rights",
        "Article 18. Right to equality: All citizens shall be equal before law.",
        "Article 28. Right to privacy: The privacy of any person, his or her residence,",
        "property, document, data, correspondence and matters relating to his or her",
        "character shall, except in accordance with law, be inviolable.",
    ],
    [
        "Muluki Civil Code 2074 (2017)",
        "Chapter 9 Provisions Relating to House Rent",
        "Section 386. Provisions relating to house rent: A person may give or take",
        "a house on rent by concluding a written house rent agreement.",
        "Section 391. Increase in house rent: The house owner or landlord may increase",
        "house rent only according to the agreement or after completion of two years",
        "with prior written notice to the tenant.",
        "Section 392. Termination of tenancy: Either party may terminate a rent agreement",
        "by giving written advance notice as prescribed by law.",
    ],
    [
        "Section 106. Entitlement to remuneration (Labour Act 2074): Every employee",
        "shall receive minimum remuneration, wage, and festival allowance from the employer.",
        "Section 47. Publication of illegal materials (Electronic Transactions Act 2063):",
        "Publishing prohibited material in electronic form is punishable under cyber law.",
    ],
]


@pytest.fixture
def sample_nepal_law_pdf_bytes() -> bytes:
    """Return multi-page Nepal statutory PDF bytes readable by `pdfplumber` and `pypdf`."""
    return build_sample_pdf_bytes(SAMPLE_NEPAL_LAW_PDF_PAGES)


@pytest.fixture
def sample_nepal_law_pdf_path(tmp_path: Path, sample_nepal_law_pdf_bytes: bytes) -> Path:
    """Write the sample multi-page Nepal statutory PDF to a temporary path."""
    pdf_path = tmp_path / "nepal_sample_statutes.pdf"
    pdf_path.write_bytes(sample_nepal_law_pdf_bytes)
    return pdf_path


@pytest.fixture
def isolated_settings(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> Iterator[Settings]:
    """Provide isolated offline-safe `Settings` using temporary disk storage & `hashed_tfidf`."""
    for env_var in (
        "GEMINI_API_KEY",
        "KILOCODE_API_KEY",
        "OPENAI_API_KEY",
        "OPENAI_BASE_URL",
        "TAVILY_API_KEY",
        "QDRANT_URL",
        "QDRANT_API_KEY",
        "QDRANT_PATH",
        "BM25_PATH",
        "MANIFEST_PATH",
        "RAW_DATA_DIR",
        "EMBEDDING_PROVIDER",
        "DEFAULT_LLM_PROVIDER",
    ):
        monkeypatch.delenv(env_var, raising=False)

    monkeypatch.setenv("EMBEDDING_PROVIDER", "hashed_tfidf")
    get_settings.cache_clear()

    data_root = tmp_path / "wakil_data"
    settings = Settings(
        _env_file=None,
        qdrant_url=None,
        qdrant_api_key=None,
        qdrant_path=data_root / "qdrant",
        bm25_path=data_root / "bm25_index.json",
        manifest_path=data_root / "corpus_manifest.json",
        raw_data_dir=data_root / "raw",
        embedding_provider="hashed_tfidf",
        embedding_dim=256,
        default_llm_provider="auto",
        gemini_api_key=None,
        kilocode_api_key=None,
        openai_api_key=None,
        openai_base_url=None,
        tavily_api_key=None,
    )
    settings.ensure_data_dirs()
    yield settings
    get_settings.cache_clear()


@pytest.fixture
def sample_legal_chunks() -> list[dict[str, Any]]:
    """Return representative English, Devanagari, and Nepglish-targetable statutory chunks."""
    def _cid(name: str) -> str:
        return str(uuid.uuid5(uuid.NAMESPACE_URL, f"wakil-test:{name}"))

    return [
        {
            "chunk_id": _cid("const-28"),
            "doc_id": "doc-constitution-2072",
            "text": (
                "Article 28. Right to privacy: The privacy of any person, his or her residence, "
                "property, document, data, correspondence and character shall be inviolable."
            ),
            "act_name": "Constitution of Nepal 2072",
            "category": CategoryEnum.CONSTITUTION.value,
            "language": "EN",
            "section_num": "28",
            "section_title": "Article 28. Right to privacy",
            "citation_label": "Constitution of Nepal 2072, Art. 28",
            "page_start": 1,
            "page_end": 1,
            "chunk_index": 0,
            "source_path": "constitution.pdf",
            "metadata": {"part": "Part-3"},
        },
        {
            "chunk_id": _cid("civil-386"),
            "doc_id": "doc-civil-2074",
            "text": (
                "Section 386. Provisions relating to house rent: A landlord and tenant may "
                "enter into a written lease agreement for residential tenancy."
            ),
            "act_name": "Muluki Civil Code 2074",
            "category": CategoryEnum.CODES.value,
            "language": "EN",
            "section_num": "386",
            "section_title": "Section 386. Provisions relating to house rent",
            "citation_label": "Muluki Civil Code 2074, Sec. 386",
            "page_start": 120,
            "page_end": 120,
            "chunk_index": 0,
            "source_path": "civil_code.pdf",
            "metadata": {"chapter": "9"},
        },
        {
            "chunk_id": _cid("civil-391"),
            "doc_id": "doc-civil-2074",
            "text": (
                "दफा ३९१. घरबहाल वृद्धि गर्न सकिने: घरधनी (landlord / gharbeti) ले करार बमोजिम "
                "वा दुई वर्ष पूरा भएपछि मात्र घरबहाल (house rent) वृद्धि गर्न सक्नेछ। "
                "Section 391: House rent increase notice rules for landlord and tenant."
            ),
            "act_name": "Muluki Civil Code 2074",
            "category": CategoryEnum.CODES.value,
            "language": "BILINGUAL",
            "section_num": "391",
            "section_title": "दफा ३९१. घरबहाल वृद्धि",
            "citation_label": "Muluki Civil Code 2074, Sec. 391",
            "page_start": 122,
            "page_end": 122,
            "chunk_index": 1,
            "source_path": "civil_code.pdf",
            "metadata": {"chapter": "9"},
        },
        {
            "chunk_id": _cid("eta-47"),
            "doc_id": "doc-eta-2063",
            "text": (
                "Section 47. Publication of illegal materials in electronic form: "
                "Any person publishing prohibited cyber material electronically commits an offence."
            ),
            "act_name": "Electronic Transactions Act 2063",
            "category": CategoryEnum.CODES.value,
            "language": "EN",
            "section_num": "47",
            "section_title": "Section 47. Publication of illegal materials",
            "citation_label": "Electronic Transactions Act 2063, Sec. 47",
            "page_start": 18,
            "page_end": 18,
            "chunk_index": 0,
            "source_path": "eta_2063.pdf",
            "metadata": {},
        },
        {
            "chunk_id": _cid("labour-106"),
            "doc_id": "doc-labour-2074",
            "text": (
                "Section 106. Entitlement to remuneration: An employer must pay at least the "
                "prescribed minimum wage and salary on time to every worker."
            ),
            "act_name": "Labour Act 2074",
            "category": CategoryEnum.CODES.value,
            "language": "EN",
            "section_num": "106",
            "section_title": "Section 106. Entitlement to remuneration",
            "citation_label": "Labour Act 2074, Sec. 106",
            "page_start": 40,
            "page_end": 40,
            "chunk_index": 0,
            "source_path": "labour_2074.pdf",
            "metadata": {},
        },
    ]


@pytest.fixture
def hybrid_retriever(isolated_settings: Settings) -> Iterator[HybridRetriever]:
    """Create a temporary-disk `HybridRetriever` with deterministic embeddings and clean teardown."""
    retriever = HybridRetriever(settings=isolated_settings)
    try:
        yield retriever
    finally:
        retriever.close()
