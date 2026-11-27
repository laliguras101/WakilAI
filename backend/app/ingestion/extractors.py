"""Multi-format legal document extraction with PDF fallback, Preeti conversion, and UTF-8 cleanup."""

from __future__ import annotations

import io
import json
import re
import unicodedata
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any, Iterable, Optional
from urllib.parse import urlparse

import httpx
import pdfplumber
import pypdf
from bs4 import BeautifulSoup
from docx import Document as DocxDocument

_IKAR_MARK = "\uE001"
_REPH_MARK = "\uE002"

_DEFAULT_USER_AGENT = (
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
    "AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36"
)


class DocumentExtractionError(ValueError):
    """Raised when a document cannot be parsed or yields unusable text."""


class ScannedPDFError(DocumentExtractionError):
    """Raised when a PDF contains pages but lacks an extractable text layer."""


@dataclass(slots=True)
class ExtractedPage:
    """Extracted text for a single 1-based page or logical section."""

    page_number: int
    text: str
    extractor: str = "native"
    is_preeti_converted: bool = False


@dataclass(slots=True)
class ExtractedDocument:
    """Normalized extracted document text, page map, and metadata."""

    text: str
    pages: list[ExtractedPage]
    page_count: int
    format: str
    language: str
    title: Optional[str] = None
    source_path: Optional[str] = None
    source_url: Optional[str] = None
    metadata: dict[str, Any] = field(default_factory=dict)


class PreetiConverter:
    """Converts legacy Preeti/Kantipur/Himali ASCII-mapped Nepali PDF text to Unicode Devanagari."""

    PREETI_FONTS: frozenset[str] = frozenset(
        {
            "preeti",
            "kantipur",
            "sagarmatha",
            "himalb",
            "himali",
            "pcs nepali",
            "rukmini",
            "shangrila",
            "ganapati",
            "sabdatara",
            "kanchan",
            "navjeevan",
            "sathi",
            "pcs",
            "pcsnepali",
            "pc nepali",
            "rupak",
            "aakriti",
            "ananda",
        }
    )

    # Note: Fontasy Himali is sometimes used exclusively for ASCII page numbers in Nepal Law Commission PDFs.
    CONDITIONAL_PREETI_FONTS: frozenset[str] = frozenset({"fontasy himali"})

    PREETI_PATTERNS: tuple[str, ...] = (
        "g]kfn",
        "sfg\"g",
        "wkmf",
        "bkmf",
        "P]g",
        "/fli6«o",
        "k|lt",
        "adf]lhd",
        "axfn",
        "3/wgL",
        ";+lxtf",
        "d'n'sL",
        "k|df0fLs/0f",
    )

    MULTI_CHAR_MAP: dict[str, str] = {
        "cf]": "ओ",
        "cf}": "औ",
        "O{": "ई",
        "P]": "ऐ",
        "cf": "आ",
        "km": "फ",
        "em": "झ",
        "pm": "ऊ",
        "If": "क्ष",
        "Qm": "क्त",
        "qm": "त्र",
        "0f": "ण",
        "if": "ष",
        "f]": "ो",
        "f}": "ौ",
        "M–": ":–",
        "M-": ":-",
    }

    CHAR_MAP: dict[str, str] = {
        # Vowels & vowel signs
        "c": "अ",
        "O": "इ",
        "p": "उ",
        "C": "ऋ",
        "P": "ए",
        "f": "ा",
        "l": _IKAR_MARK,
        "L": "ी",
        "'": "ु",
        '"': "ू",
        "[": "ृ",
        "]": "े",
        "}": "ै",
        "{": _REPH_MARK,
        "+": "ं",
        "F": "ँ",
        "\\": "्",
        "|": "्र",
        "«": "्र",
        # Consonants (full and half forms)
        "s": "क",
        "S": "क्",
        "v": "ख",
        "V": "ख्",
        "u": "ग",
        "U": "ग्",
        "3": "घ",
        "ª": "ङ",
        "r": "च",
        "R": "च्",
        "5": "छ",
        "h": "ज",
        "H": "ज्",
        "`": "ञ",
        "~": "ञ्",
        "6": "ट",
        "7": "ठ",
        "8": "ड",
        "9": "ढ",
        "0": "ण्",
        "t": "त",
        "T": "त्",
        "y": "थ",
        "Y": "थ्",
        "b": "द",
        "w": "ध",
        "W": "ध्",
        "g": "न",
        "G": "न्",
        "k": "प",
        "K": "प्",
        "a": "ब",
        "A": "ब्",
        "e": "भ",
        "E": "भ्",
        "d": "म",
        "D": "म्",
        "o": "य",
        "/": "र",
        "n": "ल",
        "N": "ल्",
        "j": "व",
        "J": "व्",
        "z": "श",
        "Z": "श्",
        "i": "ष्",
        ";": "स",
        ":": "स्",
        "x": "ह",
        "X": "ह्",
        "I": "क्ष्",
        "q": "त्र",
        "Q": "क्त्",
        "1": "ज्ञ",
        "2": "द्द",
        "4": "द्ध",
        "B": "द्य",
        "¿": "रू",
        "Ë": "ङ्ग",
        "Í": "ङ्",
        "ß": "द्व",
        "æ": "“",
        "Æ": "”",
        "÷": "/",
        # Preeti numerals
        "!": "१",
        "@": "२",
        "#": "३",
        "$": "४",
        "%": "५",
        "^": "६",
        "&": "७",
        "*": "८",
        "(": "९",
        ")": "०",
        # Preeti punctuation
        "-": "(",
        "_": ")",
        "=": ".",
        ".": "।",
        "<": "?",
        ">": "श्र",
        "M": ":",
    }

    @classmethod
    def is_preeti_font(cls, font_name: str, sample_text: str = "") -> bool:
        """Return True if PDF span font name indicates legacy Preeti encoding."""
        low = (font_name or "").lower()
        if any(pf in low for pf in cls.PREETI_FONTS):
            return True
        if any(pf in low for pf in cls.CONDITIONAL_PREETI_FONTS):
            stripped = sample_text.strip()
            if not stripped or stripped.isdigit():
                return False
            return cls.is_preeti_text(stripped) or any(ch in stripped for ch in "{}[]\\|;+=")
        return False

    @classmethod
    def is_preeti_text(cls, text: str) -> bool:
        """Heuristically detect legacy Preeti ASCII encoding in extracted text."""
        if not text or len(text.strip()) < 12:
            return False
        sample = text[:4000]
        dev_count = sum(1 for c in sample if "\u0900" <= c <= "\u097F")
        if dev_count > len(sample) * 0.15:
            return False
        matches = sum(1 for pat in cls.PREETI_PATTERNS if pat in sample)
        if matches >= 2:
            return True
        if matches == 1 and any(c in sample for c in "{}[]\\|"):
            return True
        weird = sum(1 for c in sample[:600] if c in "{}\\|;[]~" and c.isascii())
        return weird > max(4, len(sample[:600]) * 0.04)

    @classmethod
    def convert(cls, text: str) -> str:
        """Convert Preeti-encoded ASCII text into normalized Unicode Devanagari."""
        if not text:
            return text

        out: list[str] = []
        i = 0
        length = len(text)
        while i < length:
            matched = False
            if i + 2 < length:
                tri = text[i : i + 3]
                if tri in cls.MULTI_CHAR_MAP:
                    out.append(cls.MULTI_CHAR_MAP[tri])
                    i += 3
                    matched = True
            if not matched and i + 1 < length:
                di = text[i : i + 2]
                if di in cls.MULTI_CHAR_MAP:
                    out.append(cls.MULTI_CHAR_MAP[di])
                    i += 2
                    matched = True
            if not matched:
                ch = text[i]
                out.append(cls.CHAR_MAP.get(ch, ch))
                i += 1

        converted = "".join(out)
        # Move visual pre-consonant ikar ('l') after the following Devanagari conjunct cluster
        converted = re.sub(
            rf"{_IKAR_MARK}((?:[\u0915-\u0939]\u094D)*[\u0915-\u0939](?:\u094D[\u0915-\u0939])*)",
            r"\1ि",
            converted,
        )
        converted = converted.replace(_IKAR_MARK, "ि")

        # Move visual post-syllable reph ('{') before the preceding consonant cluster
        converted = re.sub(
            rf"((?:[\u0915-\u0939]\u094D)*[\u0915-\u0939][\u093E-\u094C\u0901-\u0903]*){_REPH_MARK}",
            r"र्\1",
            converted,
        )
        converted = converted.replace(_REPH_MARK, "र्")

        # Collapse duplicate vowel signs that occasionally appear in PDF spans
        converted = re.sub(r"ा{2,}", "ा", converted)
        converted = re.sub(r"ि{2,}", "ि", converted)
        converted = re.sub(r"ी{2,}", "ी", converted)
        converted = re.sub(r"्{2,}", "्", converted)
        return unicodedata.normalize("NFC", converted)


def detect_text_language(text: str) -> str:
    """Detect whether text is primarily English (`EN`), Nepali (`NE`), or `BILINGUAL`."""
    sample = (text or "")[:12000]
    dev = sum(1 for c in sample if "\u0900" <= c <= "\u097F")
    lat = sum(1 for c in sample if ("A" <= c <= "Z") or ("a" <= c <= "z"))
    total = dev + lat
    if total == 0:
        return "EN"
    dev_ratio = dev / total
    lat_ratio = lat / total
    if dev >= 40 and lat >= 40 and dev_ratio >= 0.15 and lat_ratio >= 0.15:
        return "BILINGUAL"
    return "NE" if dev_ratio >= 0.35 else "EN"


def clean_extracted_text(text: str, *, is_markdown: bool = False) -> str:
    """Clean PDF watermarks, broken line-wrap hyphens, and normalize UTF-8 text."""
    if not text:
        return ""

    cleaned = unicodedata.normalize("NFC", text)
    cleaned = cleaned.replace("\r\n", "\n").replace("\r", "\n")
    cleaned = cleaned.replace("\u00a0", " ").replace("\uf026", "").replace("\uf0ab", "")

    if is_markdown:
        # Remove converter HTML comments & placeholder translation blocks
        cleaned = re.sub(r"<!--.*?-->", "", cleaned, flags=re.DOTALL)
        cleaned = re.sub(
            r"\*\*English Translation:\*\*\s*\n+\s*\{TODO:\s*Add English translation\}\s*",
            "",
            cleaned,
            flags=re.IGNORECASE,
        )
        cleaned = re.sub(
            r"\*\*Nepali Translation[^*]*:\*\*\s*\n+\s*\{TODO:\s*Add Nepali translation\}\s*",
            "",
            cleaned,
            flags=re.IGNORECASE,
        )
        cleaned = re.sub(r"\{TODO:\s*Add [^}]+\}", "", cleaned, flags=re.IGNORECASE)

    # Remove common Law Commission page header/footer clutter without altering section lines
    lines = []
    for line in cleaned.split("\n"):
        stripped = line.strip()
        if stripped.lower() in {"www.lawcommission.gov.np", "http://www.lawcommission.gov.np"}:
            continue
        if re.fullmatch(r"Page\s+\d+(?:\s+of\s+\d+)?", stripped, flags=re.IGNORECASE):
            continue
        if re.fullmatch(r"(?:Nepal\s+2015\s+Page\s+\d+|constituteproject\.org[^\n]*)", stripped, flags=re.IGNORECASE):
            continue
        lines.append(re.sub(r"[ \t]{2,}", " ", line.rstrip()))

    cleaned = "\n".join(lines)
    # Re-join English words split across line breaks with a trailing hyphen
    cleaned = re.sub(r"([A-Za-z])-\n([a-z])", r"\1\2", cleaned)
    cleaned = re.sub(r"\n{3,}", "\n\n", cleaned)
    return cleaned.strip()


def _extract_pdf_page_with_pdfplumber(page: pdfplumber.page.Page) -> tuple[str, bool]:
    """Extract a single `pdfplumber` page in one pass, converting Preeti-font runs cleanly."""
    chars = page.chars
    if not chars:
        raw_text = page.extract_text() or ""
        if PreetiConverter.is_preeti_text(raw_text):
            return PreetiConverter.convert(raw_text), True
        return raw_text, False

    has_preeti_font = any(
        PreetiConverter.is_preeti_font(ch.get("fontname", ""), ch.get("text", ""))
        for ch in chars
    )
    if not has_preeti_font:
        raw_text = page.extract_text() or ""
        if PreetiConverter.is_preeti_text(raw_text):
            converted_lines = [
                PreetiConverter.convert(ln)
                if PreetiConverter.is_preeti_text(ln) or any(c in ln for c in "{}[]\\|")
                else ln
                for ln in raw_text.split("\n")
            ]
            return "\n".join(converted_lines), True
        return raw_text, False

    # Single-pass line/word reconstruction directly from `page.chars`
    sorted_chars = sorted(chars, key=lambda c: (float(c.get("top", 0.0)), float(c.get("x0", 0.0))))
    line_groups: list[list[dict[str, Any]]] = []
    current_group: list[dict[str, Any]] = []
    anchor_top: Optional[float] = None
    for ch in sorted_chars:
        if not ch.get("text"):
            continue
        top = float(ch.get("top", 0.0))
        size = float(ch.get("size", 10.0) or 10.0)
        if anchor_top is not None and abs(top - anchor_top) > max(5.0, size * 0.55):
            if current_group:
                line_groups.append(current_group)
            current_group = [ch]
            anchor_top = top
        else:
            if anchor_top is None:
                anchor_top = top
            current_group.append(ch)
    if current_group:
        line_groups.append(current_group)

    lines: list[str] = []
    converted_any = False

    for group in line_groups:
        group.sort(key=lambda c: float(c.get("x0", 0.0)))
        line_segments: list[tuple[bool, list[str]]] = []
        current_is_preeti: Optional[bool] = None
        current_buf: list[str] = []
        last_x1: Optional[float] = None

        for ch in group:
            txt = ch.get("text", "")
            x0 = float(ch.get("x0", 0.0))
            x1 = float(ch.get("x1", x0))
            size = float(ch.get("size", 10.0) or 10.0)
            ch_preeti = PreetiConverter.is_preeti_font(ch.get("fontname", ""), txt)

            if last_x1 is not None and (x0 - last_x1) > max(1.8, size * 0.2):
                if current_buf and not current_buf[-1].isspace():
                    current_buf.append(" ")

            if current_is_preeti is not None and ch_preeti != current_is_preeti:
                if current_buf and current_is_preeti is not None:
                    line_segments.append((current_is_preeti, current_buf))
                current_buf = []

            current_is_preeti = ch_preeti
            current_buf.append(txt)
            last_x1 = x1

        if current_buf and current_is_preeti is not None:
            line_segments.append((current_is_preeti, current_buf))

        parts: list[str] = []
        for seg_preeti, seg_chars in line_segments:
            seg_text = "".join(seg_chars)
            if seg_preeti:
                if seg_text.strip().isdigit() and len(line_segments) == 1:
                    parts.append(seg_text)
                else:
                    parts.append(PreetiConverter.convert(seg_text))
                    converted_any = True
            else:
                parts.append(seg_text)

        joined_line = "".join(parts).strip()
        if joined_line:
            lines.append(joined_line)

    return "\n".join(lines), converted_any


def extract_pdf_bytes(
    content: bytes,
    *,
    source_path: Optional[str] = None,
    source_url: Optional[str] = None,
    title: Optional[str] = None,
) -> ExtractedDocument:
    """Extract PDF bytes page-by-page using `pdfplumber` with automatic `pypdf` fallback."""
    if not content:
        raise DocumentExtractionError("PDF input is empty (0 bytes).")

    pages: list[ExtractedPage] = []
    pypdf_reader: Optional[pypdf.PdfReader] = None
    page_count = 0

    try:
        with pdfplumber.open(io.BytesIO(content)) as pdf:
            page_count = len(pdf.pages)
            for idx, page in enumerate(pdf.pages):
                page_num = idx + 1
                extractor_used = "pdfplumber"
                is_preeti = False
                text = ""

                try:
                    text, is_preeti = _extract_pdf_page_with_pdfplumber(page)
                except Exception:
                    text = ""

                if not text.strip():
                    if pypdf_reader is None:
                        try:
                            pypdf_reader = pypdf.PdfReader(io.BytesIO(content))
                        except Exception:
                            pypdf_reader = None
                    if pypdf_reader is not None and idx < len(pypdf_reader.pages):
                        try:
                            fallback_text = pypdf_reader.pages[idx].extract_text() or ""
                            if fallback_text.strip():
                                if PreetiConverter.is_preeti_text(fallback_text):
                                    fallback_text = PreetiConverter.convert(fallback_text)
                                    is_preeti = True
                                text = fallback_text
                                extractor_used = "pypdf"
                        except Exception:
                            pass

                cleaned_page = clean_extracted_text(text)
                pages.append(
                    ExtractedPage(
                        page_number=page_num,
                        text=cleaned_page,
                        extractor=extractor_used,
                        is_preeti_converted=is_preeti,
                    )
                )
    except DocumentExtractionError:
        raise
    except Exception as plumber_err:
        # Full-file fallback to pypdf if pdfplumber fails to open the PDF
        try:
            pypdf_reader = pypdf.PdfReader(io.BytesIO(content))
            page_count = len(pypdf_reader.pages)
            for idx, p in enumerate(pypdf_reader.pages):
                raw = p.extract_text() or ""
                is_preeti = False
                if PreetiConverter.is_preeti_text(raw):
                    raw = PreetiConverter.convert(raw)
                    is_preeti = True
                pages.append(
                    ExtractedPage(
                        page_number=idx + 1,
                        text=clean_extracted_text(raw),
                        extractor="pypdf",
                        is_preeti_converted=is_preeti,
                    )
                )
        except Exception as pypdf_err:
            raise DocumentExtractionError(
                f"Failed to parse PDF via pdfplumber ({plumber_err}) and pypdf ({pypdf_err})."
            ) from pypdf_err

    non_empty_pages = [p for p in pages if p.text.strip()]
    total_chars = sum(len(re.sub(r"\s+", "", p.text)) for p in non_empty_pages)
    if page_count > 0 and (not non_empty_pages or total_chars < 40):
        raise ScannedPDFError(
            f"Scanned or image-only PDF detected ({page_count} pages, {total_chars} extractable non-space chars). "
            "Provide a text-layer PDF or run OCR (e.g., Tesseract with nep+eng) before ingesting."
        )

    full_text = "\n\n".join(p.text for p in non_empty_pages)
    inferred_title = title or _infer_title_from_text(full_text)
    return ExtractedDocument(
        text=full_text,
        pages=pages,
        page_count=page_count or len(pages),
        format="pdf",
        language=detect_text_language(full_text),
        title=inferred_title,
        source_path=source_path,
        source_url=source_url,
        metadata={
            "preeti_pages": sum(1 for p in pages if p.is_preeti_converted),
            "pypdf_fallback_pages": sum(1 for p in pages if p.extractor == "pypdf"),
        },
    )


def extract_docx_bytes(
    content: bytes,
    *,
    source_path: Optional[str] = None,
    source_url: Optional[str] = None,
    title: Optional[str] = None,
) -> ExtractedDocument:
    """Extract text from a DOCX document including paragraphs and tables."""
    if not content:
        raise DocumentExtractionError("DOCX input is empty.")
    try:
        doc = DocxDocument(io.BytesIO(content))
    except Exception as exc:
        raise DocumentExtractionError(f"Failed to read DOCX document: {exc}") from exc

    blocks: list[str] = []
    for para in doc.paragraphs:
        txt = para.text.strip()
        if txt:
            blocks.append(txt)
    for table in doc.tables:
        for row in table.rows:
            cells = [cell.text.strip() for cell in row.cells if cell.text.strip()]
            if cells:
                blocks.append(" | ".join(cells))

    full_text = clean_extracted_text("\n\n".join(blocks))
    if not full_text:
        raise DocumentExtractionError("DOCX document contains no extractable text.")

    pages = [ExtractedPage(page_number=1, text=full_text, extractor="python-docx")]
    return ExtractedDocument(
        text=full_text,
        pages=pages,
        page_count=1,
        format="docx",
        language=detect_text_language(full_text),
        title=title or _infer_title_from_text(full_text),
        source_path=source_path,
        source_url=source_url,
    )


def extract_html_text(
    html: str,
    *,
    source_path: Optional[str] = None,
    source_url: Optional[str] = None,
    title: Optional[str] = None,
) -> ExtractedDocument:
    """Extract clean readable text from HTML while stripping nav, scripts, styles, and footers."""
    if not html or not html.strip():
        raise DocumentExtractionError("HTML content is empty.")

    try:
        soup = BeautifulSoup(html, "lxml")
    except Exception:
        soup = BeautifulSoup(html, "html.parser")

    extracted_title = title
    if not extracted_title and soup.title and soup.title.string:
        extracted_title = soup.title.string.strip()

    for tag_name in ("script", "style", "noscript", "nav", "header", "footer", "aside", "svg"):
        for tag in soup.find_all(tag_name):
            tag.decompose()

    main_node = soup.find("main") or soup.find("article") or soup.body or soup
    raw_text = main_node.get_text("\n", strip=True)
    cleaned = clean_extracted_text(raw_text)
    if not cleaned:
        raise DocumentExtractionError("HTML page yielded no readable body text after stripping navigation/scripts.")

    pages = [ExtractedPage(page_number=1, text=cleaned, extractor="beautifulsoup")]
    return ExtractedDocument(
        text=cleaned,
        pages=pages,
        page_count=1,
        format="html",
        language=detect_text_language(cleaned),
        title=extracted_title or _infer_title_from_text(cleaned),
        source_path=source_path,
        source_url=source_url,
    )


def _flatten_json_text(obj: Any) -> list[str]:
    """Recursively collect human-readable text segments from structured JSON statutes."""
    lines: list[str] = []
    if isinstance(obj, str):
        stripped = obj.strip()
        if stripped:
            lines.append(stripped)
    elif isinstance(obj, dict):
        preferred_keys = ("title", "act_name", "section", "heading", "text", "content", "body")
        seen: set[str] = set()
        for k in preferred_keys:
            if k in obj:
                seen.add(k)
                lines.extend(_flatten_json_text(obj[k]))
        for k, v in obj.items():
            if k not in seen:
                lines.extend(_flatten_json_text(v))
    elif isinstance(obj, list):
        for item in obj:
            lines.extend(_flatten_json_text(item))
    elif obj is not None:
        lines.append(str(obj))
    return lines


def extract_bytes(
    content: bytes,
    file_name: str,
    *,
    source_path: Optional[str] = None,
    source_url: Optional[str] = None,
    title: Optional[str] = None,
) -> ExtractedDocument:
    """Dispatch extraction by file extension or magic bytes across PDF, DOCX, HTML, MD, TXT, JSON."""
    if not content:
        raise DocumentExtractionError(f"Empty input for `{file_name}`.")

    ext = Path(file_name).suffix.lower()
    if content.lstrip()[:5] == b"%PDF-" or ext == ".pdf":
        return extract_pdf_bytes(content, source_path=source_path, source_url=source_url, title=title)

    if ext == ".docx":
        return extract_docx_bytes(content, source_path=source_path, source_url=source_url, title=title)

    decoded = _decode_text_bytes(content)
    if ext in {".html", ".htm"} or _looks_like_html(decoded):
        return extract_html_text(decoded, source_path=source_path, source_url=source_url, title=title)

    if ext == ".json":
        try:
            parsed = json.loads(decoded)
            flattened = "\n\n".join(_flatten_json_text(parsed))
            cleaned = clean_extracted_text(flattened)
        except json.JSONDecodeError as exc:
            raise DocumentExtractionError(f"Invalid JSON in `{file_name}`: {exc}") from exc
        if not cleaned:
            raise DocumentExtractionError(f"JSON file `{file_name}` contains no extractable text.")
        return ExtractedDocument(
            text=cleaned,
            pages=[ExtractedPage(page_number=1, text=cleaned, extractor="json")],
            page_count=1,
            format="json",
            language=detect_text_language(cleaned),
            title=title or Path(file_name).stem,
            source_path=source_path,
            source_url=source_url,
        )

    is_md = ext in {".md", ".markdown"}
    cleaned = clean_extracted_text(decoded, is_markdown=is_md)
    if not cleaned:
        raise DocumentExtractionError(f"Text document `{file_name}` is empty after cleanup.")

    doc_format = "markdown" if is_md else "text"
    return ExtractedDocument(
        text=cleaned,
        pages=[ExtractedPage(page_number=1, text=cleaned, extractor=doc_format)],
        page_count=1,
        format=doc_format,
        language=detect_text_language(cleaned),
        title=title or _infer_title_from_text(cleaned) or Path(file_name).stem,
        source_path=source_path,
        source_url=source_url,
    )


def extract_file(path: str | Path, *, title: Optional[str] = None) -> ExtractedDocument:
    """Read and extract a local file on disk."""
    file_path = Path(path)
    if not file_path.exists():
        raise FileNotFoundError(f"File not found: {file_path}")
    if not file_path.is_file():
        raise DocumentExtractionError(f"Path is not a file: {file_path}")
    content = file_path.read_bytes()
    return extract_bytes(
        content,
        file_path.name,
        source_path=str(file_path.resolve()),
        title=title,
    )


async def extract_url(
    url: str,
    *,
    title: Optional[str] = None,
    timeout: float = 30.0,
) -> tuple[ExtractedDocument, bytes, str]:
    """Download a remote PDF, HTML, or text statute URL and return `(doc, raw_bytes, file_name)`."""
    parsed = urlparse(url)
    if parsed.scheme not in {"http", "https"}:
        raise DocumentExtractionError(f"Unsupported URL scheme `{parsed.scheme}` in `{url}`.")

    headers = {
        "User-Agent": _DEFAULT_USER_AGENT,
        "Accept": "application/pdf,text/html,application/xhtml+xml,text/plain,*/*;q=0.9",
        "Referer": f"{parsed.scheme}://{parsed.netloc}/",
    }
    async with httpx.AsyncClient(follow_redirects=True, timeout=timeout) as client:
        resp = await client.get(url, headers=headers)
        resp.raise_for_status()
        raw_bytes = resp.content
        content_type = (resp.headers.get("content-type") or "").lower()
        final_url = str(resp.url)

    if not raw_bytes:
        raise DocumentExtractionError(f"Empty response returned from `{url}`.")

    path_name = Path(urlparse(final_url).path).name or "remote_document"
    if "application/pdf" in content_type or raw_bytes.lstrip()[:5] == b"%PDF-":
        if not path_name.lower().endswith(".pdf"):
            path_name = f"{path_name}.pdf"
    elif "html" in content_type and not path_name.lower().endswith((".html", ".htm")):
        path_name = f"{path_name}.html"
    elif "." not in path_name:
        path_name = f"{path_name}.txt"

    doc = extract_bytes(
        raw_bytes,
        path_name,
        source_url=final_url,
        title=title,
    )
    return doc, raw_bytes, path_name


def _decode_text_bytes(content: bytes) -> str:
    for encoding in ("utf-8-sig", "utf-8", "utf-16", "cp1252", "latin-1"):
        try:
            return content.decode(encoding)
        except UnicodeDecodeError:
            continue
    return content.decode("utf-8", errors="replace")


def _looks_like_html(text: str) -> bool:
    head = (text or "").lstrip()[:400].lower()
    return head.startswith("<!doctype html") or head.startswith("<html") or "<body" in head


def _infer_title_from_text(text: str) -> Optional[str]:
    for line in (text or "").splitlines():
        stripped = line.strip().lstrip("#*,.:;–- ").strip()
        if not stripped:
            continue
        if stripped.lower().startswith(("www.", "http://", "https://")):
            continue
        if len(stripped) >= 4:
            return stripped[:140]
    return None
