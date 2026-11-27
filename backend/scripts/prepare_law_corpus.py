"""Audit, deterministically clean, and visually convert Nepalese statutory PDFs for WakilAI."""

from __future__ import annotations

import argparse
from concurrent.futures import ThreadPoolExecutor, as_completed
import io
import json
import os
import re
import sys
import tempfile
import threading
import time
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Optional

import pypdf
import pypdfium2 as pdfium
from google import genai
from google.genai import types

_BACKEND_DIR = Path(__file__).resolve().parent.parent
if str(_BACKEND_DIR) not in sys.path:
    sys.path.insert(0, str(_BACKEND_DIR))

from app.ingestion.chunker import chunk_document
from app.ingestion.extractors import PreetiConverter, clean_extracted_text, extract_bytes
from app.ingestion.nepal_sources import (
    DEFAULT_LOCAL_CORPUS_DIR,
    infer_act_name_from_path,
    infer_category_from_path_or_name,
)

# Corrupt Devanagari / broken PDF CMap patterns observed across legacy Nepal Law Commission PDFs.
_CORRUPT_NEPALI_RE = re.compile(
    r"धमधि|संशोिन|गने\s+ऐन|िुनेछ|नपे\s*ाल|िामी|प्रस्िा|पररच्छेद|व्र्त्ति|सम्भनु|ददएको|धियम|बिाएको"
    r"|अमधकार|ननयमावली|अनसु\s*न्धान|ाे|ाै"
    r"|[^\s\u094D]\s+[\u093E-\u094C\u0902]"
    r"|([\u0905-\u0939])\1{3,}"
)

# Foreign scripts, intra-word ASCII glued to Devanagari, or English filler words injected into Nepali sentences.
_CROSS_SCRIPT_LEAK_RE = re.compile(
    r"[\u0400-\u04FF\u0980-\u0DFF\u3040-\u30FF]"
    r"|[\u0900-\u0963\u0966-\u097F][A-Za-z]{1,12}"
    r"|[A-Za-z]{1,12}[\u0900-\u0963\u0966-\u097F]"
    r"|[\u0900-\u097F]\s+(?:and|or|the|of|to|in|for|with|by|from|as|on|at|is|are|be|not)\s+[\u0900-\u097F]"
)

_PRIORITY_DIRS = (
    "Constitution",
    "Codes",
    "Acts",
    "Ordinances",
    "Formation_Orders",
    "Rules_and_Regulations",
    "Rules",
    "Guidelines",
    "Policies",
)

_GEMINI_SYSTEM_PROMPT = """You are an expert Nepalese statutory document converter for WakilAI Legal RAG.
Read the attached rendered PDF page images visually and transcribe EVERY statutory provision verbatim into WakilAI structured Markdown.

STRICT ACCURACY & SCHEMA RULES:
1. Output ONLY raw Markdown blocks matching the schema below. No intro/outro chatter or code fences (```).
2. Emit ONE SEPARATE block (separated by a line containing only `---`) for EACH Preamble and EACH numbered Section, Article, Rule, or Schedule. NEVER merge multiple numbered sections (e.g., 7, 8, 9...) into a single block.
3. Transcribe ALL statutory text verbatim in clean UTF-8 Devanagari (`U+0900..U+097F`) or clean English. Include the Act title, Gazette date, amending Acts list, Preamble, and EVERY sub-section `(1)`, `(2)`, `(क)`, `(ख)`, proviso (`तर`), and explanation (`स्पष्टीकरण`).
4. CRITICAL SCRIPT INTEGRITY: NEVER output Cyrillic (`а`, `л`), Gujarati (`સ`, `ો`), Gurmukhi (`ਾ`), Japanese Kana (`ゅ`), English filler words (`and`, `or`, `the`) inside Nepali sentences (use `र`, `वा`), or mixed Latin letters inside Nepali words (never `चलाun`, `नлаग्ने`, `आपूm` — write pure Devanagari `आफू`/`आफूसँग`). Every Nepali word MUST be pure Unicode Devanagari.
5. Preserve EVERY Bikram Sambat date (e.g., २०६७।१०।६, २०२६।५।१९), Act number (e.g., २०२६ सालको ऐन नं. १७), and section number accurately. Cross-check digits/dates against the supplied PDF reference text, while reading Devanagari spelling visually from the page images.
6. Omit watermarks (`www.lawcommission.gov.np`, diagonal `नेपाल कानून आयोग`) and bare page numbers.
7. Include ONLY the language(s) actually printed in the images. Do NOT invent translations or `{TODO: ...}`.
8. If a section starts mid-sentence at the top of page 1 of this image batch (continuation from the prior page), open that fragment with `## Section cont: Continued` and `- @section: Continued` so nothing is lost.

BLOCK SCHEMA (every block MUST include `- @section:`):
## Section <number or Preamble>: <short title>

- @act: <Official Act/Rule/Order Name in English>
- @act_ne: <Official Act/Rule/Order Name in Devanagari Nepali>
- @section: <e.g., Preamble or Section 1 or Article 1 or Rule 1>
- @section_ne: <e.g., प्रस्तावना or दफा १ or धारा १ or नियम १>
- @title: <Section title in English if present or short English gloss>
- @title_ne: <Section title in Devanagari Nepali>
- @part: <Chapter/Part name if visible, else General>
- @source_language: <ne | en | bilingual>

<Verbatim full statutory text of this single section/article/rule>

---"""


@dataclass(slots=True)
class TriageItem:
    rel_path: str
    bucket: str  # clean_structured | minor_glitch | unstructured_clean | corrupt_md | missing_pdf
    pdf_path: Optional[Path]
    md_path: Optional[Path]
    page_count: int = 0


def _atomic_write_text(path: Path, text: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile(
        mode="w",
        encoding="utf-8",
        dir=str(path.parent),
        prefix=f".{path.stem}_",
        suffix=".tmp",
        delete=False,
    ) as tmp:
        tmp.write(text)
        tmp_path = Path(tmp.name)
    os.replace(tmp_path, path)


def normalize_devanagari_text(text: str) -> str:
    """Fix decomposed Devanagari vowel pairs (`ाे` -> `ो`, `ाै` -> `ौ`) and strip Wingdings PUA glyphs."""
    cleaned = re.sub(r"[\uf000-\uf0ff]", "", text)
    return cleaned.replace("\u093E\u0947", "\u094B").replace("\u093E\u0948", "\u094C")


def find_script_leaks(text: str) -> list[str]:
    """Return any lines containing cross-script homoglyphs or Latin letters glued to Devanagari."""
    leaks: list[str] = []
    for ln in text.splitlines():
        if _CROSS_SCRIPT_LEAK_RE.search(ln):
            leaks.append(ln.strip()[:160])
    return leaks


def is_corrupt_nepali_text(text: str) -> bool:
    """Return True if text contains Preeti ASCII artifacts, broken CMap Devanagari, or cross-script leaks."""
    if PreetiConverter.is_preeti_text(text[:8000]):
        return True
    if _CORRUPT_NEPALI_RE.search(text):
        # Allow a single isolated token only if not paired; >=2 triggers re-OCR
        if len(_CORRUPT_NEPALI_RE.findall(text)) >= 2:
            return True
    return bool(find_script_leaks(text))


def _clean_existing_structured_md(raw_text: str, stem: str) -> str:
    """Fix converter metadata glitches (`@act: np`, `{TODO: ...}`, watermarks) without altering statutory wording."""
    cleaned = raw_text.replace("\r\n", "\n").replace("\r", "\n")
    cleaned = re.sub(r"(?m)^#\s+np\s*\n\s*\d+\s*\n+", "# ", cleaned)
    cleaned = re.sub(
        r"(?m)^(- @(?:act|act_ne):\s*)np\s*\n\s*\d+\s*\n+\s*([^\n]+)",
        r"\1\2",
        cleaned,
    )
    cleaned = re.sub(r"<!--.*?-->\s*", "", cleaned, flags=re.DOTALL)
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
    cleaned = re.sub(r"\{TODO:\s*Add [^}]+\}\s*", "", cleaned, flags=re.IGNORECASE)

    out_lines: list[str] = []
    for line in cleaned.splitlines():
        if line.strip().lower() in {"www.lawcommission.gov.np", "http://www.lawcommission.gov.np"}:
            continue
        out_lines.append(line.rstrip())
    res = normalize_devanagari_text("\n".join(out_lines))
    res = re.sub(r"\n{3,}", "\n\n", res).strip() + "\n"
    if "- @section:" not in res and "- @act:" in res:
        res = res.replace("- @act:", f"- @section: {stem}\n- @act:", 1)
    return res


def _structure_constitution_en(raw_text: str) -> str:
    """Convert raw `Constitution-of-Nepal.md` into clean Article-level WakilAI Markdown blocks."""
    cleaned = clean_extracted_text(raw_text, is_markdown=False)
    lines = cleaned.splitlines()
    blocks: list[str] = []
    current_part = "Preliminary"
    preamble_lines: list[str] = []
    in_preamble = False
    current_art_num: Optional[str] = None
    current_art_title: Optional[str] = None
    current_art_lines: list[str] = []

    def flush_article() -> None:
        if current_art_num is not None and current_art_lines:
            body = "\n".join(current_art_lines).strip()
            title = current_art_title or f"Article {current_art_num}"
            blocks.append(
                f"## Article {current_art_num}: {title}\n\n"
                "- @act: Constitution of Nepal 2072 (2015)\n"
                "- @act_ne: नेपालको संविधान, २०७२\n"
                f"- @section: Article {current_art_num}\n"
                f"- @section_ne: धारा {current_art_num}\n"
                f"- @title: {title}\n"
                f"- @part: {current_part}\n"
                "- @source_language: en\n\n"
                f"{body}\n"
            )

    art_re = re.compile(r"^\*\*([0-9]{1,3})\.\s+([^:]+):\s*(.*)$")
    part_re = re.compile(r"^(?:##\s*)?(Part[-\s]*[0-9]+.*)$", re.IGNORECASE)
    sched_re = re.compile(r"^(?:##\s*)?(Schedule[-\s]*[0-9]+)$", re.IGNORECASE)

    i = 0
    while i < len(lines):
        line = lines[i].strip()
        i += 1
        if not line or re.fullmatch(r"\d{1,3}", line):
            continue
        if line.lower().startswith("preamble"):
            in_preamble = True
            preamble_lines.append(line)
            continue
        pm = part_re.match(line)
        if pm and len(line) < 90 and not line.endswith("."):
            flush_article()
            current_art_num = None
            current_art_lines = []
            next_nonempty = lines[i].strip() if i < len(lines) else ""
            if next_nonempty and not art_re.match(next_nonempty) and len(next_nonempty) < 90:
                current_part = f"{pm.group(1).lstrip('# ').strip()}: {next_nonempty}"
                i += 1
            else:
                current_part = pm.group(1).lstrip("# ").strip()
            in_preamble = False
            continue
        sm = sched_re.match(line)
        if sm and current_art_num is not None:
            flush_article()
            current_art_num = sm.group(1)
            current_art_title = sm.group(1)
            current_art_lines = [line.lstrip("# ").strip()]
            continue

        am = art_re.match(line)
        if am:
            if in_preamble and preamble_lines:
                blocks.append(
                    "## Preamble: Constitution of Nepal\n\n"
                    "- @act: Constitution of Nepal 2072 (2015)\n"
                    "- @act_ne: नेपालको संविधान, २०७२\n"
                    "- @section: Preamble\n"
                    "- @section_ne: प्रस्तावना\n"
                    "- @title: Preamble\n"
                    "- @part: Preamble\n"
                    "- @source_language: en\n\n"
                    + "\n".join(preamble_lines).strip()
                    + "\n"
                )
                in_preamble = False
                preamble_lines = []
            flush_article()
            current_art_num = am.group(1).strip()
            current_art_title = am.group(2).strip()
            rest = am.group(3).rstrip("*").strip()
            current_art_lines = [f"{current_art_num}. {current_art_title}: {rest}".strip()]
            continue

        clean_line = line.replace("## ", "") if line.startswith("## Schedule-") else line
        clean_line = clean_line.rstrip("*") if clean_line.endswith("**") and not clean_line.startswith("**") else clean_line
        if in_preamble:
            preamble_lines.append(clean_line)
        elif current_art_num is not None:
            current_art_lines.append(clean_line)

    flush_article()
    return "\n---\n\n".join(blocks).strip() + "\n"


def validate_markdown(md_text: str, rel_path: str) -> tuple[bool, int, str]:
    """Verify generated/cleaned Markdown parses cleanly into WakilAI chunks without corruption or script leaks."""
    if not md_text or len(md_text.strip()) < 150:
        return False, 0, "too_short"
    if PreetiConverter.is_preeti_text(md_text[:8000]):
        return False, 0, "preeti_text"
    if len(_CORRUPT_NEPALI_RE.findall(md_text)) >= 2:
        return False, 0, "corrupt_nepali_text"
    leaks = find_script_leaks(md_text)
    if leaks:
        return False, 0, f"script_leak:{leaks[0][:80]}"
    try:
        fp = Path(rel_path)
        doc = extract_bytes(md_text.encode("utf-8"), fp.name)
        chunks = chunk_document(
            doc,
            doc_id=f"val-{fp.stem[:20]}",
            act_name=infer_act_name_from_path(fp),
            category=infer_category_from_path_or_name(fp),
        )
        if not chunks:
            return False, 0, "zero_chunks"
        return True, len(chunks), "ok"
    except Exception as exc:
        return False, 0, f"chunk_err:{exc}"


def triage_corpus(data_root: Path) -> list[TriageItem]:
    """Classify all existing MDs and PDFs under `data_root`."""
    md_root = data_root / "law_commission_md"
    pdf_root = data_root / "law_commission_pdfs"

    pdf_by_key: dict[tuple[str, str], Path] = {}
    pdf_by_stem: dict[str, Path] = {}
    for p in sorted(pdf_root.rglob("*.pdf")):
        pdf_by_key[(p.parent.name.lower(), p.stem)] = p
        pdf_by_stem.setdefault(p.stem, p)

    items: list[TriageItem] = []
    seen_stems: set[str] = set()

    for md in sorted(md_root.rglob("*.md")):
        rel = str(md.relative_to(md_root))
        seen_stems.add(md.stem)
        txt = md.read_text(encoding="utf-8", errors="replace")
        pdf = pdf_by_key.get((md.parent.name.lower(), md.stem)) or pdf_by_stem.get(md.stem)
        has_meta = "- @section:" in txt
        has_np_glitch = bool(re.search(r"@act:\s*np\b", txt))
        if is_corrupt_nepali_text(txt):
            bucket = "corrupt_md"
        elif has_meta and has_np_glitch:
            bucket = "minor_glitch"
        elif has_meta:
            bucket = "clean_structured"
        else:
            bucket = "unstructured_clean"
        items.append(TriageItem(rel_path=rel, bucket=bucket, pdf_path=pdf, md_path=md))

    for pdf in sorted(pdf_root.rglob("*.pdf")):
        if pdf.stem in seen_stems:
            continue
        rel = str(pdf.relative_to(pdf_root).with_suffix(".md"))
        items.append(TriageItem(rel_path=rel, bucket="missing_pdf", pdf_path=pdf, md_path=None))

    def sort_key(it: TriageItem) -> tuple[int, int, str]:
        top = Path(it.rel_path).parts[0] if Path(it.rel_path).parts else ""
        prio = _PRIORITY_DIRS.index(top) if top in _PRIORITY_DIRS else 99
        bucket_prio = {"corrupt_md": 0, "missing_pdf": 1}.get(it.bucket, 2)
        return (bucket_prio, prio, it.rel_path)

    items.sort(key=sort_key)
    return items


def run_stage_clean(data_root: Path, out_root: Path) -> dict[str, Any]:
    """Safely normalize clean MDs into `out_root` and emit `corpus_triage_manifest.json`."""
    items = triage_corpus(data_root)
    summary: dict[str, Any] = {
        "total_items": len(items),
        "buckets": {},
        "staged_clean": [],
        "staged_failed": [],
        "needs_ocr": [],
    }

    for it in items:
        summary["buckets"][it.bucket] = summary["buckets"].get(it.bucket, 0) + 1
        out_path = out_root / it.rel_path

        if it.bucket in {"clean_structured", "minor_glitch", "unstructured_clean"} and it.md_path:
            raw = it.md_path.read_text(encoding="utf-8", errors="replace")
            if it.bucket == "unstructured_clean" and "constitution-of-nepal" in it.md_path.name.lower():
                fixed = _structure_constitution_en(raw)
            else:
                fixed = _clean_existing_structured_md(raw, it.md_path.stem)
            ok, chunk_cnt, msg = validate_markdown(fixed, it.rel_path)
            if ok:
                _atomic_write_text(out_path, fixed)
                summary["staged_clean"].append({"rel_path": it.rel_path, "chunks": chunk_cnt, "bucket": it.bucket})
            else:
                summary["staged_failed"].append({"rel_path": it.rel_path, "reason": msg})
                summary["needs_ocr"].append({"rel_path": it.rel_path, "bucket": "validation_failed", "pdf": str(it.pdf_path or "")})
        else:
            summary["needs_ocr"].append({"rel_path": it.rel_path, "bucket": it.bucket, "pdf": str(it.pdf_path or "")})

    manifest_path = data_root / "corpus_triage_manifest.json"
    _atomic_write_text(manifest_path, json.dumps(summary, indent=2, ensure_ascii=False))
    return summary


def _load_gemini_keys(cli_key: Optional[str], keys_file: Optional[Path]) -> list[str]:
    """Load one or more Gemini API keys without hardcoding or logging secrets."""
    keys: list[str] = []
    if cli_key:
        keys.append(cli_key.strip())
    if keys_file and keys_file.is_file():
        for ln in keys_file.read_text(encoding="utf-8").splitlines():
            k = ln.strip().strip('"').strip("'")
            if k:
                keys.append(k)
    if os.environ.get("GEMINI_API_KEY"):
        keys.append(os.environ["GEMINI_API_KEY"].strip())
    for env_candidate in (
        Path(r"C:\Users\bhugo\antigravity\Wakil\.env"),
        _BACKEND_DIR / ".env",
        _BACKEND_DIR.parent / ".env",
    ):
        if env_candidate.is_file():
            m = re.search(r"^GEMINI_API_KEY=(.+)$", env_candidate.read_text(encoding="utf-8"), re.M)
            if m and m.group(1).strip():
                keys.append(m.group(1).strip().strip('"').strip("'"))
    unique = list(dict.fromkeys(k for k in keys if k))
    if not unique:
        raise RuntimeError("No GEMINI_API_KEY found. Pass --api-key, --keys-file, or set GEMINI_API_KEY in .env.")
    return unique


class _KeyPool:
    """Thread-safe Gemini key pool with per-(key, model) RPM spacing, LRU health scheduling, and backoff."""

    def __init__(self, keys: list[str], min_interval: float = 8.0) -> None:
        self._lock = threading.Lock()
        self._keys = list(keys)
        self._min_interval = min_interval
        self._cooldown_until: dict[tuple[str, str], float] = {}
        self._model_backoff_until: dict[str, float] = {}
        self._last_used: dict[tuple[str, str], float] = {}
        self._consec_429: dict[tuple[str, str], int] = {}
        self._consec_err: dict[tuple[str, str], int] = {}
        self._dead_keys: set[str] = set()
        self._dead_pairs: set[tuple[str, str]] = set()
        self._clients: dict[str, genai.Client] = {
            k: genai.Client(
                api_key=k,
                http_options=types.HttpOptions(timeout=25000, retry_options=types.HttpRetryOptions(attempts=1)),
            )
            for k in keys
        }

    def acquire(self, model: str) -> tuple[str, genai.Client]:
        while True:
            with self._lock:
                now = time.monotonic()
                alive = [k for k in self._keys if k not in self._dead_keys and (k, model) not in self._dead_pairs]
                if not alive:
                    raise RuntimeError(f"All Gemini keys exhausted/disabled for model {model}.")
                model_wait = self._model_backoff_until.get(model, 0.0) - now
                ready = [k for k in alive if self._cooldown_until.get((k, model), 0.0) <= now]
                if ready and model_wait <= 0:
                    # Prefer healthy keys first, then least recently used so 504/429-prone pairs stay back
                    best_k = min(
                        ready,
                        key=lambda k: (self._consec_err.get((k, model), 0), self._last_used.get((k, model), 0.0)),
                    )
                    pair = (best_k, model)
                    self._last_used[pair] = now
                    self._cooldown_until[pair] = now + self._min_interval
                    return best_k, self._clients[best_k]
                soonest = min(self._cooldown_until.get((k, model), now + 2.0) for k in alive)
                wait_s = max(0.3, min(15.0, max(soonest - now, model_wait)))
            time.sleep(wait_s)

    def mark_success(self, key: str, model: str) -> None:
        with self._lock:
            pair = (key, model)
            self._consec_429[pair] = 0
            self._consec_err[pair] = 0

    def mark_rate_limited(self, key: str, model: str, seconds: float = 25.0, *, is_429: bool = False) -> None:
        with self._lock:
            now = time.monotonic()
            pair = (key, model)
            err_hits = self._consec_err.get(pair, 0) + 1
            self._consec_err[pair] = err_hits
            if is_429:
                hits = self._consec_429.get(pair, 0) + 1
                self._consec_429[pair] = hits
                seconds = min(90.0, seconds * hits)
                # Brief per-model stagger prevents concurrent workers stampeding shared-project AQ keys
                self._model_backoff_until[model] = max(self._model_backoff_until.get(model, 0.0), now + 2.5)
            else:
                seconds = min(90.0, seconds * err_hits)
            self._cooldown_until[pair] = max(self._cooldown_until.get(pair, 0.0), now + seconds)

    def mark_dead(self, key: str, model: Optional[str] = None) -> None:
        with self._lock:
            if model is None:
                self._dead_keys.add(key)
            else:
                self._dead_pairs.add((key, model))

    def active_count(self) -> int:
        with self._lock:
            return len([k for k in self._keys if k not in self._dead_keys])


def _extract_slice_hint(pdf_path: Path, start_idx: int, end_idx: int) -> str:
    """Extract raw/Preeti-converted PDF text for `[start_idx, end_idx)` strictly as numeral/section anchor."""
    try:
        reader = pypdf.PdfReader(str(pdf_path))
        snippets: list[str] = []
        for idx in range(start_idx, end_idx):
            txt = reader.pages[idx].extract_text() or ""
            if PreetiConverter.is_preeti_text(txt):
                txt = PreetiConverter.convert(txt)
            txt = clean_extracted_text(txt)
            if txt:
                snippets.append(f"[Page {idx + 1}]\n{txt[:2500]}")
        return "\n".join(snippets)[:8000]
    except Exception:
        return ""


def _render_slice_images(pdf_doc: pdfium.PdfDocument, start_idx: int, end_idx: int, scale: float = 2.0) -> list[bytes]:
    """Render `[start_idx, end_idx)` PDF pages as crisp JPEGs (~120 KB/page) so corrupt CMaps never pollute Gemini."""
    imgs: list[bytes] = []
    for idx in range(start_idx, end_idx):
        pil_img = pdf_doc[idx].render(scale=scale).to_pil().convert("RGB")
        buf = io.BytesIO()
        pil_img.save(buf, format="JPEG", quality=88, optimize=True)
        imgs.append(buf.getvalue())
    return imgs


def _strip_code_fences(text: str) -> str:
    s = text.strip()
    if s.startswith("```"):
        s = re.sub(r"^```[a-zA-Z0-9_-]*\n?", "", s)
        s = re.sub(r"\n?```$", "", s)
    return s.strip()


def _merge_converted_slices(slices_md: list[str]) -> str:
    """Join multi-slice statutory Markdown outputs cleanly, stitching any Continued block into the previous section."""
    blocks: list[str] = []
    for chunk_md in slices_md:
        for raw_blk in re.split(r"\n---\n", chunk_md):
            blk = raw_blk.strip()
            if not blk or len(blk) < 20:
                continue
            if blocks and re.search(r"^- @section:\s*Continued\b", blk, re.M | re.I):
                body_lines: list[str] = []
                for ln in blk.splitlines():
                    s = ln.strip()
                    if s.startswith("## ") or s.startswith("- @"):
                        continue
                    body_lines.append(ln)
                cont_body = "\n".join(body_lines).strip()
                if cont_body:
                    blocks[-1] = f"{blocks[-1].rstrip()}\n{cont_body}"
            else:
                blocks.append(blk)
    return normalize_devanagari_text("\n\n---\n\n".join(blocks).strip()) + "\n"


def _process_slice(
    pdf_path: Path,
    *,
    act_hint: str,
    start: int,
    end: int,
    total_pages: int,
    doc_cache: Path,
    key_pool: _KeyPool,
    models: list[str],
    render_lock: threading.Lock,
) -> tuple[int, Optional[str], str]:
    """Render and convert a single `[start, end)` page slice, returning `(start, text, error)`."""
    cache_file = doc_cache / f"png_p{start + 1:04d}_{end:04d}.md"
    if cache_file.is_file():
        cached = normalize_devanagari_text(cache_file.read_text(encoding="utf-8"))
        if len(cached.strip()) > 30 and not is_corrupt_nepali_text(cached):
            return start, cached, ""

    # pypdfium2 PdfDocument objects are NOT thread-safe across threads; open/render safely per slice
    with render_lock:
        pdf_doc = pdfium.PdfDocument(str(pdf_path))
        img_list = _render_slice_images(pdf_doc, start, end, scale=2.0)
        pdf_doc.close()
        ref_hint = _extract_slice_hint(pdf_path, start, end)

    user_prompt = (
        f"Statute filename hint: {act_hint}\n"
        f"Rendered page images {start + 1} to {end} (of {total_pages}).\n"
        "Transcribe ALL attached page images verbatim into WakilAI structured Markdown.\n"
        "IMPORTANT: Give EVERY numbered Section/Article/Rule/दफा/धारा/नियम its OWN `---` block.\n"
    )
    if ref_hint:
        user_prompt += (
            "\nDigit/section reference from PDF (use ONLY to verify Bikram Sambat dates & section numbers; "
            "NEVER copy garbled Devanagari from here):\n"
            f"---\n{ref_hint}\n---\n"
        )

    contents: list[Any] = [types.Part.from_bytes(data=b, mime_type="image/jpeg") for b in img_list]
    contents.append(user_prompt)

    converted_md: Optional[str] = None
    last_err = ""
    max_attempts = max(12, min(24, max(1, key_pool.active_count()) * 2))
    for _attempt in range(max_attempts):
        exhausted_models = 0
        for mdl in models:
            key_str = ""
            try:
                key_str, client = key_pool.acquire(mdl)
                resp = client.models.generate_content(
                    model=mdl,
                    contents=contents,
                    config=types.GenerateContentConfig(
                        system_instruction=_GEMINI_SYSTEM_PROMPT,
                        temperature=0.0,
                    ),
                )
                candidate = normalize_devanagari_text(_strip_code_fences(resp.text or ""))
                if len(candidate) > 20 and not is_corrupt_nepali_text(candidate):
                    key_pool.mark_success(key_str, mdl)
                    converted_md = candidate
                    break
                key_pool.mark_success(key_str, mdl)
                leaks = find_script_leaks(candidate)
                last_err = f"rejected_output(leaks={leaks[:1]})"
            except RuntimeError as pool_err:
                last_err = str(pool_err)
                exhausted_models += 1
                continue
            except Exception as exc:
                full_err = str(exc)
                last_err = full_err[:180]
                if any(code in full_err for code in ("400 INVALID_ARGUMENT", "401 UNAUTHENTICATED", "403 PERMISSION_DENIED")):
                    if key_str:
                        key_pool.mark_dead(key_str)
                elif "429" in full_err or "RESOURCE_EXHAUSTED" in full_err:
                    if key_str:
                        if (
                            "PerDay" in full_err
                            or "GenerateRequestsPerDay" in full_err
                            or "'quota_limit_value': '0'" in full_err
                            or '"quota_limit_value": "0"' in full_err
                        ):
                            key_pool.mark_dead(key_str, mdl)
                        else:
                            key_pool.mark_rate_limited(key_str, mdl, seconds=20.0, is_429=True)
                elif "503" in full_err or "504" in full_err or "DEADLINE_EXCEEDED" in full_err or "timed out" in full_err.lower():
                    if key_str:
                        key_pool.mark_rate_limited(key_str, mdl, seconds=15.0)
        if converted_md is not None or exhausted_models == len(models):
            break
        if _attempt >= 2 and (_attempt == 2 or _attempt % 4 == 0):
            print(f"  [retry#{_attempt}] {pdf_path.name} p{start + 1}-{end}/{total_pages}: {last_err[:100]}", flush=True)
        # Brief inter-attempt pause when all keys in rotation are hitting transient RPM/TPM limits
        if "429" in last_err or "RESOURCE_EXHAUSTED" in last_err:
            time.sleep(2.0)

    if converted_md is None:
        return start, None, last_err

    _atomic_write_text(cache_file, converted_md)
    print(f"  [cached] {pdf_path.name} p{start + 1}-{end}/{total_pages}", flush=True)
    return start, converted_md, ""


def _convert_single_pdf(
    item: TriageItem,
    *,
    out_root: Path,
    cache_root: Path,
    key_pool: _KeyPool,
    models: list[str],
    slice_pages: int,
    slice_pool: ThreadPoolExecutor,
) -> dict[str, Any]:
    assert item.pdf_path is not None
    out_path = out_root / item.rel_path
    if out_path.is_file():
        existing = out_path.read_text(encoding="utf-8", errors="replace")
        ok, chunks_n, _ = validate_markdown(existing, item.rel_path)
        if ok:
            return {"rel_path": item.rel_path, "status": "skipped_existing", "chunks": chunks_n}

    total_pages = len(pypdf.PdfReader(str(item.pdf_path)).pages)
    doc_cache = cache_root / item.rel_path.replace("\\", "__").replace("/", "__")
    doc_cache.mkdir(parents=True, exist_ok=True)
    act_hint = infer_act_name_from_path(item.pdf_path)
    render_lock = threading.Lock()

    ranges = [(start, min(total_pages, start + slice_pages)) for start in range(0, total_pages, slice_pages)]
    futs = [
        slice_pool.submit(
            _process_slice,
            item.pdf_path,
            act_hint=act_hint,
            start=s,
            end=e,
            total_pages=total_pages,
            doc_cache=doc_cache,
            key_pool=key_pool,
            models=models,
            render_lock=render_lock,
        )
        for s, e in ranges
    ]

    ordered: dict[int, str] = {}
    for fut in as_completed(futs):
        s_idx, text_out, err = fut.result()
        if text_out is None:
            return {
                "rel_path": item.rel_path,
                "status": "failed_slice",
                "slice": f"{s_idx + 1}",
                "error": err,
            }
        ordered[s_idx] = text_out

    slice_outputs = [ordered[s] for s, _ in ranges]
    merged_md = _merge_converted_slices(slice_outputs)
    ok, chunks_n, reason = validate_markdown(merged_md, item.rel_path)
    if not ok:
        return {"rel_path": item.rel_path, "status": "validation_failed", "reason": reason}

    _atomic_write_text(out_path, merged_md)
    return {
        "rel_path": item.rel_path,
        "status": "converted",
        "pages": total_pages,
        "chunks": chunks_n,
    }


def run_ocr_batch(
    data_root: Path,
    out_root: Path,
    *,
    api_keys: list[str],
    workers: int,
    limit: Optional[int],
    max_pages: Optional[int],
    slice_pages: int,
    models: list[str],
    category_filter: Optional[str],
) -> dict[str, Any]:
    """Run parallel resumable Gemini Vision conversion across pending PDFs using rotated key pool."""
    items = [
        it
        for it in triage_corpus(data_root)
        if it.bucket in {"corrupt_md", "missing_pdf"} and it.pdf_path and not (out_root / it.rel_path).is_file()
    ]
    if category_filter:
        low = category_filter.lower()
        items = [it for it in items if low in it.rel_path.lower()]
    if max_pages is not None:
        filtered: list[TriageItem] = []
        for it in items:
            try:
                n = len(pypdf.PdfReader(str(it.pdf_path)).pages)
            except Exception:
                n = 9999
            if n <= max_pages:
                it.page_count = n
                filtered.append(it)
        items = filtered
    if limit is not None:
        items = items[:limit]

    cache_root = data_root / ".conversion_cache"
    cache_root.mkdir(parents=True, exist_ok=True)
    key_pool = _KeyPool(api_keys)
    results: list[dict[str, Any]] = []

    with (
        ThreadPoolExecutor(max_workers=min(4, max(1, len(items)))) as doc_pool,
        ThreadPoolExecutor(max_workers=max(1, workers)) as slice_pool,
    ):
        futs = {
            doc_pool.submit(
                _convert_single_pdf,
                it,
                out_root=out_root,
                cache_root=cache_root,
                key_pool=key_pool,
                models=models,
                slice_pages=slice_pages,
                slice_pool=slice_pool,
            ): it
            for it in items
        }
        for fut in as_completed(futs):
            res = fut.result()
            results.append(res)
            print(json.dumps(res, ensure_ascii=False), flush=True)

    return {
        "processed": len(results),
        "converted": sum(1 for r in results if r["status"] == "converted"),
        "skipped_existing": sum(1 for r in results if r["status"] == "skipped_existing"),
        "failed": [r for r in results if r["status"] not in {"converted", "skipped_existing"}],
        "active_keys_remaining": key_pool.active_count(),
    }


def _parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(description="Clean, triage, and convert WakilAI statutory corpus.")
    p.add_argument("--data-root", type=Path, default=DEFAULT_LOCAL_CORPUS_DIR)
    p.add_argument("--out-dir", type=Path, default=None, help="Defaults to <data-root>/law_commission_md_clean")
    p.add_argument("--stage-clean", action="store_true", help="Copy/fix clean MDs into out-dir and emit triage manifest.")
    p.add_argument("--convert", action="store_true", help="Convert corrupt/missing PDFs via parallel Gemini Vision.")
    p.add_argument("--verify", action="store_true", help="Validate all staged .md files in out-dir via WakilAI chunker.")
    p.add_argument("--workers", type=int, default=6)
    p.add_argument("--limit", type=int, default=None)
    p.add_argument("--max-pages", type=int, default=None)
    p.add_argument("--slice-pages", type=int, default=2)
    p.add_argument("--category", type=str, default=None)
    p.add_argument("--api-key", type=str, default=None)
    p.add_argument("--keys-file", type=Path, default=None, help="Optional newline-separated file of Gemini API keys.")
    p.add_argument(
        "--models",
        type=str,
        default="gemini-3.1-flash-lite,gemini-3.5-flash-lite",
    )
    return p.parse_args()


def main() -> int:
    args = _parse_args()
    data_root: Path = args.data_root
    out_root: Path = args.out_dir or (data_root / "law_commission_md_clean")

    if not any((args.stage_clean, args.convert, args.verify)):
        args.stage_clean = True

    if args.stage_clean:
        s1 = run_stage_clean(data_root, out_root)
        print(
            "STAGE 1 SUMMARY:",
            json.dumps(
                {
                    "buckets": s1["buckets"],
                    "staged_clean": len(s1["staged_clean"]),
                    "staged_failed": len(s1["staged_failed"]),
                    "needs_ocr": len(s1["needs_ocr"]),
                },
                ensure_ascii=False,
            ),
        )

    if args.convert:
        keys = _load_gemini_keys(args.api_key, args.keys_file)
        models = [m.strip() for m in args.models.split(",") if m.strip()]
        s2 = run_ocr_batch(
            data_root,
            out_root,
            api_keys=keys,
            workers=args.workers,
            limit=args.limit,
            max_pages=args.max_pages,
            slice_pages=args.slice_pages,
            models=models,
            category_filter=args.category,
        )
        print("STAGE 2 SUMMARY:", json.dumps(s2, ensure_ascii=False))

    if args.verify:
        total, ok_n, bad = 0, 0, []
        total_chunks = 0
        for p in sorted(out_root.rglob("*.md")):
            total += 1
            rel = str(p.relative_to(out_root))
            ok, n, reason = validate_markdown(p.read_text(encoding="utf-8", errors="replace"), rel)
            if ok:
                ok_n += 1
                total_chunks += n
            else:
                bad.append({"rel_path": rel, "reason": reason})
        print(
            "VERIFY SUMMARY:",
            json.dumps(
                {"total_staged_md": total, "valid": ok_n, "total_chunks": total_chunks, "invalid": bad[:20]},
                ensure_ascii=False,
            ),
        )
        return 0 if not bad else 1

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
