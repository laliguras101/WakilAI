"""Nepal statutory structure-aware chunker supporting English, Devanagari, and bilingual Markdown."""

from __future__ import annotations

import re
import uuid
from dataclasses import dataclass, field
from typing import Any, Optional

from pydantic import BaseModel, Field

from app.ingestion.extractors import ExtractedDocument, clean_extracted_text, detect_text_language
from app.schemas import CategoryEnum

_NAMESPACE_WAKIL_CHUNK = uuid.UUID("6d8a2a4c-2a95-4f8f-9d54-9a91b86d1001")
_DEVANAGARI_DIGITS = str.maketrans("०१२३४५६७८९", "0123456789")

# Regexes for bilingual Nepal statutory Markdown blocks (e.g. law_commission_md)
_MD_SECTION_SPLIT_RE = re.compile(r"\n---\n")
_MD_HEADING_RE = re.compile(
    r"^##\s+(?:(Section|Article|Rule|Schedule|दफा|धारा|नियम|अनुसूची)\s*([०-९0-9A-Za-zक-ह]+)?\s*[:\-–—.]?\s*(.*)|(.+))$",
    re.IGNORECASE,
)
_MD_META_RE = re.compile(r"^-\s*@([a-zA-Z0-9_]+)\s*:\s*(.+?)\s*$")

# Regexes for English & Nepali statutory hierarchy
_EN_PART_RE = re.compile(r"^(?:#+\s*)?(Part[\s\-–—]*[0-9A-Za-z]+(?:\s*[:\-–—]?\s*.*)?)$", re.IGNORECASE)
_EN_CHAPTER_RE = re.compile(r"^(?:#+\s*)?(Chapter[\s\-–—]*[0-9A-Za-z]+(?:\s*[:\-–—]?\s*.*)?)$", re.IGNORECASE)
_NE_PART_RE = re.compile(r"^(?:#+\s*)?(भाग[\s\-–—]*[०-९0-9]+(?:\s*[:\-–—]?\s*.*)?)$")
_NE_CHAPTER_RE = re.compile(
    r"^(?:#+\s*)?((?:परिच्छेद|अध्याय)[\s\-–—]*[०-९0-9]+(?:\s*[:\-–—]?\s*.*)?)$"
)

# Explicit English section/article/rule patterns
_EXPLICIT_EN_SEC_RE = re.compile(
    r"^(?:#+\s*|\*\*)?(Article|Section|Rule)\s+([0-9]+[A-Za-z]?)\s*(?:[:.\-–—]\s*(.+?))?(?:\*\*)?$",
    re.IGNORECASE,
)
# Numbered Gazette-style English section: e.g. `391. Mode and procedure of payment of rent: ...`
_NUMBERED_EN_SEC_RE = re.compile(
    r"^(?:\*\*)?([0-9]{1,4}[A-Za-z]?)\.\s+([A-Z][^\n]{2,120}?)(?:[:\-–—]|\*\*|$)(.*)$"
)
# Explicit Nepali section/article/rule patterns: e.g. `दफा ३९१: ...` or `धारा २५.`
_EXPLICIT_NE_SEC_RE = re.compile(
    r"^(?:#+\s*|\*\*)?(दफा|धारा|नियम|अनुच्छेद)\s*([०-९0-9]+(?:[कखगघङच]?))\s*(?:[:ः.\-–—]\s*(.+?))?(?:\*\*)?$"
)
# Numbered Gazette-style Nepali section: e.g. `२५. सम्पत्तिको हकः ...` or `३९१. बहाल बुझाउने तरिका : ...`
_NUMBERED_NE_SEC_RE = re.compile(
    r"^([०-९0-9]{1,4}[कखगघङच]?)\.\s+([\u0900-\u097F][^\n]{1,120}?)\s*(?:[:ः\-–—]|$)(.*)$"
)
# Dotted table-of-contents lines that must not trigger false section splits
_TOC_LINE_RE = re.compile(r"\.{4,}\s*[०-९0-9]+\s*$")


def normalize_devanagari_digits(value: Optional[str]) -> Optional[str]:
    """Convert Devanagari digits (`०-९`) to ASCII (`0-9`) for metadata normalization."""
    if value is None:
        return None
    normalized = value.translate(_DEVANAGARI_DIGITS).strip()
    return normalized or None


def detect_language(text: str) -> str:
    """Return `EN`, `NE`, or `BILINGUAL` for a text fragment."""
    return detect_text_language(text)


def build_citation_label(
    act_name: str,
    *,
    section_num: Optional[str] = None,
    unit_kind: Optional[str] = None,
    chapter: Optional[str] = None,
    page_start: Optional[int] = None,
) -> str:
    """Format a uniform legal citation label like `Muluki Civil Code 2074, Sec. 391`."""
    base = (act_name or "Nepal Statute").strip()
    norm_sec = normalize_devanagari_digits(section_num)
    if norm_sec:
        kind = (unit_kind or "").lower()
        if "article" in kind or "धारा" in kind or "constitution" in base.lower() or "संविधान" in base:
            abbrev = "Art."
        elif "rule" in kind or "नियम" in kind:
            abbrev = "Rule"
        elif "schedule" in kind or "अनुसूची" in kind:
            abbrev = "Sch."
        else:
            abbrev = "Sec."
        return f"{base}, {abbrev} {norm_sec}"
    if chapter:
        return f"{base}, {chapter[:50]}"
    if page_start:
        return f"{base} (p. {page_start})"
    return base


class StatutoryChunk(BaseModel):
    """Structured statutory chunk matching `RetrievedChunk` payload keys."""

    chunk_id: str
    doc_id: str
    text: str
    act_name: str
    category: str = CategoryEnum.OTHER.value
    language: str = "EN"
    section_num: Optional[str] = None
    section_title: Optional[str] = None
    citation_label: str = ""
    page_start: Optional[int] = None
    page_end: Optional[int] = None
    chunk_index: int = 0
    source_path: Optional[str] = None
    source_url: Optional[str] = None
    metadata: dict[str, Any] = Field(default_factory=dict)


@dataclass(slots=True)
class _SectionBlock:
    text: str
    section_num: Optional[str] = None
    section_title: Optional[str] = None
    unit_kind: Optional[str] = None
    chapter: Optional[str] = None
    part: Optional[str] = None
    page_start: Optional[int] = None
    page_end: Optional[int] = None
    extra_meta: dict[str, Any] = field(default_factory=dict)


def _extract_heading(line: str, act_name: str) -> Optional[tuple[str, Optional[str], Optional[str]]]:
    """Detect `(unit_kind, raw_num, title)` if `line` opens a statutory Article/Section/Rule."""
    stripped = line.strip()
    if not stripped or len(stripped) > 260 or _TOC_LINE_RE.search(stripped):
        return None
    if stripped.startswith(("(", "Provided", "Explanation", "स्पष्टीकरण", "तर")):
        return None

    m = _EXPLICIT_EN_SEC_RE.match(stripped)
    if m:
        return m.group(1), m.group(2), (m.group(3) or "").strip() or None

    m = _EXPLICIT_NE_SEC_RE.match(stripped)
    if m:
        return m.group(1), m.group(2), (m.group(3) or "").strip() or None

    m = _NUMBERED_NE_SEC_RE.match(stripped)
    if m:
        raw_num, title_part = m.group(1), m.group(2).strip(" :ः-–—")
        kind = "धारा" if ("संविधान" in act_name or "constitution" in act_name.lower()) else "दफा"
        return kind, raw_num, title_part or None

    m = _NUMBERED_EN_SEC_RE.match(stripped)
    if m:
        raw_num, title_part = m.group(1), m.group(2).strip(" :-–—*")
        # Require a short title rather than a full narrative numbered list sentence
        if len(title_part.split()) <= 16:
            kind = "Article" if "constitution" in act_name.lower() else "Section"
            return kind, raw_num, title_part or None

    return None


def _split_markdown_metadata_blocks(
    doc: ExtractedDocument,
    default_act_name: str,
) -> Optional[list[_SectionBlock]]:
    """Parse structured `law_commission_md` files with `@act`/`@section` metadata lines."""
    if doc.format != "markdown" or "- @section:" not in doc.text:
        return None

    raw_blocks = _MD_SECTION_SPLIT_RE.split(doc.text)
    sections: list[_SectionBlock] = []
    for raw in raw_blocks:
        block = raw.strip()
        if not block:
            continue
        lines = block.splitlines()
        meta: dict[str, str] = {}
        heading_line: Optional[str] = None
        body_lines: list[str] = []

        for line in lines:
            s = line.strip()
            if s.startswith("## ") and heading_line is None:
                heading_line = s
                continue
            m_meta = _MD_META_RE.match(s)
            if m_meta:
                meta[m_meta.group(1).lower()] = m_meta.group(2).strip()
                continue
            body_lines.append(line)

        if not meta and heading_line is None:
            continue

        # Clean empty translation markers if body has no actual text under them
        body_text = "\n".join(body_lines).strip()
        body_text = re.sub(r"\n*\*\*(?:English|Nepali) Translation[^*]*:\*\*\s*$", "", body_text).strip()
        body_text = clean_extracted_text(body_text, is_markdown=True)
        if not body_text:
            continue

        sec_raw = meta.get("section") or meta.get("section_ne") or ""
        sec_num_match = re.search(r"([०-९0-9]+(?:[A-Za-zक-ह]?))", sec_raw)
        sec_num = normalize_devanagari_digits(sec_num_match.group(1)) if sec_num_match else None

        sec_title = meta.get("title") or meta.get("title_ne")
        if not sec_title and heading_line:
            hm = _MD_HEADING_RE.match(heading_line)
            if hm:
                sec_title = (hm.group(3) or hm.group(4) or "").strip() or None

        unit_kind = "Article" if "constitution" in default_act_name.lower() else (
            "Section" if "section" in sec_raw.lower() or not sec_raw else sec_raw
        )

        # Build clean, self-contained chunk text with heading
        header_label = heading_line.lstrip("# ").strip() if heading_line else (
            f"{sec_raw}: {sec_title}" if sec_raw and sec_title else (sec_title or default_act_name)
        )
        full_section_text = f"{header_label}\n{body_text}" if header_label and header_label not in body_text[:120] else body_text

        extra: dict[str, Any] = {}
        for k in ("act_ne", "section_ne", "title_ne", "part", "part_ne", "legal_domains", "keywords", "keywords_ne"):
            if k in meta and meta[k] not in {"N/A", "लागु हुँदैन", "None", "कुनै छैन"}:
                extra[k] = meta[k]

        sections.append(
            _SectionBlock(
                text=full_section_text,
                section_num=sec_num,
                section_title=sec_title,
                unit_kind=unit_kind,
                chapter=meta.get("part") or meta.get("part_ne"),
                part=meta.get("part"),
                page_start=1,
                page_end=doc.page_count or 1,
                extra_meta=extra,
            )
        )
    return sections or None


def _split_pages_by_headings(doc: ExtractedDocument, act_name: str) -> list[_SectionBlock]:
    """Walk page-by-page lines and split into statutory sections while tracking page ranges."""
    blocks: list[_SectionBlock] = []
    current_lines: list[str] = []
    current_sec_num: Optional[str] = None
    current_sec_title: Optional[str] = None
    current_unit_kind: Optional[str] = None
    current_part: Optional[str] = None
    current_chapter: Optional[str] = None
    current_page_start: Optional[int] = None
    current_page_end: Optional[int] = None

    def flush() -> None:
        text = "\n".join(current_lines).strip()
        if text:
            blocks.append(
                _SectionBlock(
                    text=text,
                    section_num=normalize_devanagari_digits(current_sec_num),
                    section_title=current_sec_title,
                    unit_kind=current_unit_kind,
                    chapter=current_chapter,
                    part=current_part,
                    page_start=current_page_start,
                    page_end=current_page_end,
                )
            )
        current_lines.clear()

    pages = doc.pages if doc.pages else []
    for page in pages:
        if not page.text.strip():
            continue
        for raw_line in page.text.splitlines():
            line = raw_line.strip()
            if not line:
                if current_lines and current_lines[-1] != "":
                    current_lines.append("")
                continue

            if _EN_PART_RE.match(line) or _NE_PART_RE.match(line):
                current_part = line.lstrip("# ").strip()
            elif _EN_CHAPTER_RE.match(line) or _NE_CHAPTER_RE.match(line):
                current_chapter = line.lstrip("# ").strip()

            heading = _extract_heading(line, act_name)
            if heading is not None:
                flush()
                unit_kind, raw_num, sec_title = heading
                current_unit_kind = unit_kind
                current_sec_num = normalize_devanagari_digits(raw_num)
                current_sec_title = sec_title
                current_page_start = page.page_number
                current_page_end = page.page_number
                current_lines.append(line.lstrip("# ").strip())
            else:
                if current_page_start is None:
                    current_page_start = page.page_number
                current_page_end = page.page_number
                current_lines.append(line)

    flush()
    return blocks


def _split_long_text(text: str, max_chars: int, overlap: int) -> list[str]:
    """Split oversized sections into overlapping windows along paragraph/sentence/word boundaries."""
    if len(text) <= max_chars:
        return [text]

    lines = text.splitlines()
    prefix = ""
    body = text
    if len(lines) > 1 and len(lines[0]) <= 160:
        prefix = lines[0].strip()

    chunks: list[str] = []
    start = 0
    total = len(body)
    safe_overlap = min(max(0, overlap), max(0, max_chars // 3))

    while start < total:
        end = min(total, start + max_chars)
        if end < total:
            # Prefer clean break at double-newline, newline, sentence punctuation, or whitespace
            cut = -1
            search_from = start + max(max_chars // 2, 100)
            for sep in ("\n\n", "\n", "। ", ". ", "; ", " "):
                pos = body.rfind(sep, search_from, end)
                if pos != -1:
                    cut = pos + len(sep)
                    break
            if cut > start:
                end = cut

        segment = body[start:end].strip()
        if segment:
            if start > 0 and prefix and not segment.startswith(prefix[:30]):
                segment = f"{prefix}\n{segment}"
            chunks.append(segment)

        if end >= total:
            break
        next_start = max(start + 1, end - safe_overlap)
        start = next_start

    return chunks


def _merge_tiny_blocks(blocks: list[_SectionBlock], min_chars: int = 160, max_chars: int = 1200) -> list[_SectionBlock]:
    """Merge tiny unsectioned preamble/metadata fragments without collapsing distinct numbered sections."""
    merged: list[_SectionBlock] = []
    for blk in blocks:
        if (
            merged
            and blk.section_num is None
            and merged[-1].section_num is None
            and len(merged[-1].text) + len(blk.text) + 2 <= max_chars
            and (len(merged[-1].text) < min_chars or len(blk.text) < min_chars)
        ):
            prev = merged[-1]
            merged[-1] = _SectionBlock(
                text=f"{prev.text}\n\n{blk.text}".strip(),
                section_num=prev.section_num,
                section_title=prev.section_title or blk.section_title,
                unit_kind=prev.unit_kind or blk.unit_kind,
                chapter=blk.chapter or prev.chapter,
                part=blk.part or prev.part,
                page_start=prev.page_start,
                page_end=blk.page_end or prev.page_end,
                extra_meta={**prev.extra_meta, **blk.extra_meta},
            )
        else:
            merged.append(blk)
    return merged


def chunk_document(
    doc: ExtractedDocument,
    *,
    doc_id: str,
    act_name: str,
    category: CategoryEnum | str = CategoryEnum.OTHER,
    language: Optional[str] = None,
    max_chars: int = 1200,
    chunk_overlap: int = 200,
) -> list[StatutoryChunk]:
    """Chunk an extracted legal document into structure-aware, citation-ready `StatutoryChunk` objects."""
    cat_value = category.value if isinstance(category, CategoryEnum) else str(category or CategoryEnum.OTHER.value)

    blocks = _split_markdown_metadata_blocks(doc, act_name)
    if blocks is None:
        blocks = _split_pages_by_headings(doc, act_name)
    blocks = _merge_tiny_blocks(blocks, max_chars=max_chars)

    chunks: list[StatutoryChunk] = []
    chunk_idx = 0

    for blk in blocks:
        sub_texts = _split_long_text(blk.text, max_chars=max_chars, overlap=chunk_overlap)
        for sub_text in sub_texts:
            stripped = sub_text.strip()
            if len(stripped) < 15:
                continue

            chunk_lang = language or detect_language(stripped)
            citation = build_citation_label(
                act_name,
                section_num=blk.section_num,
                unit_kind=blk.unit_kind,
                chapter=blk.chapter,
                page_start=blk.page_start,
            )
            chunk_uuid = str(
                uuid.uuid5(
                    _NAMESPACE_WAKIL_CHUNK,
                    f"{doc_id}:{chunk_idx}:{blk.section_num or ''}",
                )
            )
            meta = dict(blk.extra_meta)
            if blk.part:
                meta.setdefault("part", blk.part)
            if blk.chapter:
                meta.setdefault("chapter", blk.chapter)
            if blk.unit_kind:
                meta.setdefault("unit_kind", blk.unit_kind)

            chunks.append(
                StatutoryChunk(
                    chunk_id=chunk_uuid,
                    doc_id=doc_id,
                    text=stripped,
                    act_name=act_name,
                    category=cat_value,
                    language=chunk_lang,
                    section_num=blk.section_num,
                    section_title=blk.section_title,
                    citation_label=citation,
                    page_start=blk.page_start,
                    page_end=blk.page_end,
                    chunk_index=chunk_idx,
                    source_path=doc.source_path,
                    source_url=doc.source_url,
                    metadata=meta,
                )
            )
            chunk_idx += 1

    return chunks
