"""Verified Nepal statutory corpus registry, local dataset discovery, and safe URL downloader."""

from __future__ import annotations

import logging
import os
import tempfile
from dataclasses import dataclass, field
from pathlib import Path
from typing import Optional
from urllib.parse import urlparse

import httpx

from app.ingestion.extractors import extract_bytes
from app.schemas import CategoryEnum

logger = logging.getLogger(__name__)

DEFAULT_LOCAL_CORPUS_DIR = Path(r"D:\DATA For WAkil")

_DEFAULT_USER_AGENT = (
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
    "AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36"
)


@dataclass(frozen=True, slots=True)
class NepalSourceSpec:
    """Metadata and verified download/local paths for a core Nepalese statutory document."""

    key: str
    title: str
    act_name: str
    category: CategoryEnum
    language: str
    filename: str
    act_name_ne: Optional[str] = None
    local_md_relpath: Optional[str] = None
    local_pdf_relpath: Optional[str] = None
    urls: tuple[str, ...] = field(default_factory=tuple)
    min_chars: int = 1000
    is_core: bool = True


# Every URL listed below has been verified to serve real Nepalese legislation (>1000 extracted chars).
CORE_NEPAL_SOURCES: tuple[NepalSourceSpec, ...] = (
    NepalSourceSpec(
        key="constitution_en",
        title="Constitution of Nepal 2072 (2015) — English",
        act_name="Constitution of Nepal 2072",
        act_name_ne="नेपालको संविधान, २०७२",
        category=CategoryEnum.CONSTITUTION,
        language="EN",
        filename="Constitution_of_Nepal_2015_EN.pdf",
        local_md_relpath="Constitution/Constitution-of-Nepal.md",
        local_pdf_relpath="Constitution/Constitution-of-Nepal.pdf",
        urls=("https://www.constituteproject.org/constitution/Nepal_2015.pdf",),
    ),
    NepalSourceSpec(
        key="constitution_ne",
        title="नेपालको संविधान (दोस्रो संशोधन सहित) — Nepali Unicode",
        act_name="नेपालको संविधान, २०७२ (Constitution of Nepal)",
        act_name_ne="नेपालको संविधान",
        category=CategoryEnum.CONSTITUTION,
        language="NE",
        filename="Constitution_of_Nepal_2081_NE.pdf",
        urls=(
            "https://giwmscdnone.gov.np/media/pdf_upload/%E0%A4%A8%E0%A5%87%E0%A4%AA%E0%A4%BE%E0%A4%B2%E0%A4%95%E0%A5%8B%20%E0%A4%B8_%E0%A4%82%E0%A4%B5%E0%A4%BF%E0%A4%A7%E0%A4%BE%E0%A4%A8%20unicode%20%E0%A4%AD%E0%A4%BE%E0%A4%A6%E0%A5%8D%E0%A4%B0%20%E0%A5%A8%E0%A5%A6%E0%A5%AE%E0%A5%A7_mtbuyjt.pdf",
        ),
    ),
    NepalSourceSpec(
        key="muluki_civil_code_en",
        title="The National Civil (Code) Act, 2017 (Muluki Civil Code 2074) — English",
        act_name="Muluki Civil Code 2074",
        act_name_ne="मुलुकी देवानी संहिता, २०७४",
        category=CategoryEnum.CODES,
        language="EN",
        filename="Muluki_Civil_Code_2074_EN.pdf",
        urls=("https://faolex.fao.org/docs/pdf/nep209663.pdf",),
    ),
    NepalSourceSpec(
        key="muluki_civil_code_ne",
        title="मुलुकी देवानी संहिता, २०७४ (Muluki Civil Code 2074) — Nepali",
        act_name="Muluki Civil Code 2074 (मुलुकी देवानी संहिता)",
        act_name_ne="मुलुकी देवानी संहिता, २०७४",
        category=CategoryEnum.CODES,
        language="NE",
        filename="Muluki_Civil_Code_2074_NE.pdf",
        local_pdf_relpath="Acts/मुलुकी-देवानी-संहिता-ऐन-२०७४.pdf",
        urls=(
            "https://www.jica.go.jp/Resource/activities/issues/governance/portal/nepal/ku57pq00002khibz-att/simplified_ver_of_all_codes_ne.pdf",
        ),
    ),
    NepalSourceSpec(
        key="muluki_penal_code_en",
        title="The National Penal (Code) Act, 2017 (Muluki Criminal Code 2074) — English",
        act_name="Muluki Criminal Code 2074",
        act_name_ne="मुलुकी अपराध संहिता, २०७४",
        category=CategoryEnum.CODES,
        language="EN",
        filename="Muluki_Penal_Code_2074_EN.pdf",
        urls=("https://www.globalanimallaw.org/downloads/database/criminal-code-nepal.pdf",),
    ),
    NepalSourceSpec(
        key="muluki_penal_code_ne",
        title="मुलुकी अपराध संहिता, २०७४ (Muluki Criminal Code 2074) — Nepali",
        act_name="Muluki Criminal Code 2074 (मुलुकी अपराध संहिता)",
        act_name_ne="मुलुकी अपराध संहिता, २०७४",
        category=CategoryEnum.CODES,
        language="NE",
        filename="Muluki_Penal_Code_2074_NE.pdf",
        local_pdf_relpath="Acts/मुलुकी-अपराध-संहिता-२०७४.pdf",
        urls=(
            "https://www.moljpa.gov.np/public/uploads/2a2be198-8843-442e-92ca-e86a1092ef8d.pdf",
        ),
    ),
    NepalSourceSpec(
        key="labour_act_en",
        title="The Labour Act, 2017 (2074) — English / Bilingual",
        act_name="Labour Act 2074",
        act_name_ne="श्रम ऐन, २०७४",
        category=CategoryEnum.CODES,
        language="BILINGUAL",
        filename="Labour_Act_2074_EN.pdf",
        local_md_relpath="Acts/The-Labor-Act-2017-2074.md",
        local_pdf_relpath="Acts/The-Labor-Act-2017-2074.pdf",
        urls=("https://antislaverylaw.ac.uk/wp-content/uploads/2019/08/The-Labour-Act-2017.pdf",),
    ),
    NepalSourceSpec(
        key="labour_act_ne",
        title="श्रम ऐन, २०७४ (Labour Act 2074) — Nepali Unicode",
        act_name="Labour Act 2074 (श्रम ऐन)",
        act_name_ne="श्रम ऐन, २०७४",
        category=CategoryEnum.CODES,
        language="NE",
        filename="Labour_Act_2074_NE.pdf",
        local_pdf_relpath="Acts/श्रम-ऐन-२०७४.pdf",
        urls=(
            "https://giwmscdnone.gov.np/media/pdf_upload/15.%20%20%E0%A4%B6%E0%A5%8D%E0%A4%B0%E0%A4%AE%20%E0%A4%90%E0%A4%A8%2C_oinkgks.pdf",
        ),
    ),
    NepalSourceSpec(
        key="eta_2063_en",
        title="Electronic Transactions Act, 2063 (2008) — English",
        act_name="Electronic Transactions Act 2063",
        act_name_ne="विद्युतीय (इलेक्ट्रोनिक) कारोबार ऐन, २०६३",
        category=CategoryEnum.CODES,
        language="EN",
        filename="Electronic_Transactions_Act_2063_EN.pdf",
        urls=("https://radiantca.com.np/assets/nav_file/Electronic%20Transaction%20Act%202063.pdf",),
    ),
    NepalSourceSpec(
        key="eta_2063_ne",
        title="विद्युतीय (इलेक्ट्रोनिक) कारोबार ऐन, २०६३ — Nepali Unicode",
        act_name="Electronic Transactions Act 2063 (विद्युतीय कारोबार ऐन)",
        act_name_ne="विद्युतीय (इलेक्ट्रोनिक) कारोबार ऐन, २०६३",
        category=CategoryEnum.CODES,
        language="NE",
        filename="Electronic_Transactions_Act_2063_NE.pdf",
        local_pdf_relpath="Acts/विद्युतीय-इलेक्ट्रोनिक-कारोबार-ऐन-२०६३.pdf",
        urls=(
            "https://giwmscdnone.gov.np/media/pdf_upload/15.%20%E0%A4%B5%E0%A4%BF%E0%A4%A6%E0%A5%8D%E0%A4%AF%E0%A5%81%E0%A4%A4%E0%A5%80%E0%A4%AF%20(%E0%A4%87%E0%A4%B2%E0%A5%87%E0%A4%95%E0%A5%8D%E0%A4%9F%E0%A5%8D%E0%A4%B0%E0%A5%8B%E0%A4%A8%E0%A4%BF%E0%A4%95)%20%E0%A4%95%E0%A4%BE%E0%A4%B0%E0%A5%8B%E0%A4%AC%E0%A4%BE%E0%A4%B0%20%E0%A4%90%E0%A4%A8%2C%20%E0%A5%A8%E0%A5%A6%E0%A5%AC%E0%A5%A9_jkxllj0.pdf",
        ),
    ),
    NepalSourceSpec(
        key="companies_act_2063",
        title="Companies Act, 2063 (कम्पनी ऐन, २०६३) — Bilingual",
        act_name="Companies Act 2063",
        act_name_ne="कम्पनी ऐन, २०६३",
        category=CategoryEnum.CODES,
        language="BILINGUAL",
        filename="Companies_Act_2063.md",
        local_md_relpath="Acts/कम्पनी-ऐन-२०६३.md",
        local_pdf_relpath="Acts/कम्पनी-ऐन-२०६३.pdf",
    ),
    NepalSourceSpec(
        key="consumer_protection_act_2075",
        title="Consumer Protection Act, 2075 (उपभोक्ता संरक्षण ऐन, २०७५) — Bilingual",
        act_name="Consumer Protection Act 2075",
        act_name_ne="उपभोक्ता संरक्षण ऐन, २०७५",
        category=CategoryEnum.CODES,
        language="BILINGUAL",
        filename="Consumer_Protection_Act_2075.md",
        local_md_relpath="Acts/The-Consumer-Protection-Act-2075-2018.md",
        local_pdf_relpath="Acts/The-Consumer-Protection-Act-2075-2018.pdf",
    ),
    NepalSourceSpec(
        key="evidence_act_2031",
        title="Evidence Act, 2031 (प्रमाण ऐन, २०३१)",
        act_name="Evidence Act 2031 (प्रमाण ऐन, २०३१)",
        act_name_ne="प्रमाण ऐन, २०३१",
        category=CategoryEnum.CODES,
        language="NE",
        filename="Evidence_Act_2031.pdf",
        local_pdf_relpath="Acts/प्रमाण-ऐन-२०३१.pdf",
    ),
)


def infer_category_from_path_or_name(path_or_name: str | Path) -> CategoryEnum:
    """Infer `CategoryEnum` cleanly from folder or filename markers."""
    text = str(path_or_name).lower()
    if "constitution" in text or "संविधान" in str(path_or_name):
        return CategoryEnum.CONSTITUTION
    if any(
        tok in text or tok in str(path_or_name)
        for tok in ("rules", "directive", "guideline", "policy", "formation_order", "नियमावली", "निर्देशिका", "नीति")
    ):
        return CategoryEnum.DIRECTIVES
    if any(tok in text or tok in str(path_or_name) for tok in ("nkp", "kanoon patrika", "precedent", "नजीर")):
        return CategoryEnum.NKP
    if any(
        tok in text or tok in str(path_or_name)
        for tok in ("act", "code", "ordinance", "ऐन", "संहिता", "अध्यादेश")
    ):
        return CategoryEnum.CODES
    return CategoryEnum.OTHER


def infer_act_name_from_path(path: Path) -> str:
    """Derive a clean human-readable statute name from a local file path."""
    stem = path.stem.replace("-", " ").replace("_", " ").strip()
    return " ".join(stem.split()) or path.name


def discover_local_corpus_files(
    source_root: Path,
    *,
    include_all: bool = False,
) -> list[tuple[Path, str, CategoryEnum, Optional[str]]]:
    """Discover local statutory `.md` / `.pdf` files under `source_root` (e.g., `D:\\DATA For WAkil`).

    Returns tuples of `(file_path, act_name, category, language_override)`.
    """
    if not source_root.exists():
        raise FileNotFoundError(f"Local corpus directory does not exist: {source_root}")

    md_root = source_root / "law_commission_md"
    pdf_root = source_root / "law_commission_pdfs"

    if not include_all:
        discovered: list[tuple[Path, str, CategoryEnum, Optional[str]]] = []
        seen_paths: set[Path] = set()
        for spec in CORE_NEPAL_SOURCES:
            chosen: Optional[Path] = None
            lang_override: Optional[str] = spec.language
            if spec.local_md_relpath and md_root.exists():
                cand = md_root / spec.local_md_relpath
                if cand.is_file():
                    chosen = cand
            if chosen is None and spec.local_pdf_relpath and pdf_root.exists():
                cand = pdf_root / spec.local_pdf_relpath
                if cand.is_file():
                    chosen = cand
            if chosen is None and spec.local_md_relpath:
                cand = source_root / spec.local_md_relpath
                if cand.is_file():
                    chosen = cand
            if chosen is None and spec.local_pdf_relpath:
                cand = source_root / spec.local_pdf_relpath
                if cand.is_file():
                    chosen = cand
            if chosen is not None:
                resolved = chosen.resolve()
                if resolved not in seen_paths:
                    seen_paths.add(resolved)
                    discovered.append((resolved, spec.act_name, spec.category, lang_override))
        if discovered:
            return discovered

    # Full-corpus discovery (`include_all=True`, or a plain custom folder of PDFs/MDs)
    results: list[tuple[Path, str, CategoryEnum, Optional[str]]] = []
    seen_stems: set[tuple[str, str]] = set()
    search_roots = [r for r in (md_root, pdf_root) if r.exists()] or [source_root]
    allowed_exts = {".md", ".markdown", ".pdf", ".docx", ".txt", ".json"}
    for root in search_roots:
        for fp in sorted(root.rglob("*")):
            if not fp.is_file() or fp.suffix.lower() not in allowed_exts:
                continue
            rel_parent = fp.parent.name
            dedupe_key = (rel_parent.lower(), fp.stem)
            # Prefer pre-converted `.md` over raw `.pdf` when both exist in `law_commission_md` + `law_commission_pdfs`
            if root == pdf_root and dedupe_key in seen_stems:
                continue
            seen_stems.add(dedupe_key)
            results.append(
                (
                    fp.resolve(),
                    infer_act_name_from_path(fp),
                    infer_category_from_path_or_name(fp),
                    None,
                )
            )
    return results


def _has_sufficient_extractable_text(data: bytes, file_name: str, min_chars: int) -> bool:
    """Quickly verify a downloaded PDF/document contains >`min_chars` of real text without full-doc double parsing."""
    if data.lstrip()[:5] == b"%PDF-" or file_name.lower().endswith(".pdf"):
        import io
        import pdfplumber
        import pypdf

        total = 0
        try:
            with pdfplumber.open(io.BytesIO(data)) as pdf:
                for page in pdf.pages[:15]:
                    total += len((page.extract_text() or "").strip())
                    if total >= min_chars:
                        return True
        except Exception:
            pass
        try:
            reader = pypdf.PdfReader(io.BytesIO(data))
            for page in reader.pages[:15]:
                total += len((page.extract_text() or "").strip())
                if total >= min_chars:
                    return True
        except Exception:
            return False
        return total >= min_chars

    doc = extract_bytes(data, file_name)
    return len(doc.text) >= min_chars


async def download_verified_source(
    spec: NepalSourceSpec,
    dest_dir: Path,
    *,
    timeout: float = 35.0,
) -> Optional[tuple[Path, str]]:
    """Download a `NepalSourceSpec` into `dest_dir`, verifying valid file bytes and >1000 extracted chars."""
    if not spec.urls:
        return None

    dest_dir.mkdir(parents=True, exist_ok=True)
    target_path = (dest_dir / spec.filename).resolve()

    if target_path.exists() and target_path.stat().st_size > 2048:
        try:
            if _has_sufficient_extractable_text(target_path.read_bytes(), target_path.name, spec.min_chars):
                return target_path, spec.urls[0]
        except Exception:
            pass

    req_timeout = httpx.Timeout(timeout, connect=12.0)
    async with httpx.AsyncClient(follow_redirects=True, timeout=req_timeout) as client:
        for url in spec.urls:
            parsed = urlparse(url)
            headers = {
                "User-Agent": _DEFAULT_USER_AGENT,
                "Accept": "application/pdf,text/html,text/plain,*/*;q=0.9",
                "Referer": f"{parsed.scheme}://{parsed.netloc}/",
            }
            try:
                resp = await client.get(url, headers=headers)
                resp.raise_for_status()
                data = resp.content
                if len(data) < 1024:
                    logger.warning("Downloaded source %s too small (%d bytes)", url, len(data))
                    continue

                if target_path.suffix.lower() == ".pdf" and data.lstrip()[:5] != b"%PDF-":
                    logger.warning("Source %s did not return PDF magic bytes", url)
                    continue

                if not _has_sufficient_extractable_text(data, target_path.name, spec.min_chars):
                    logger.warning("Extracted sample text from %s below min_chars=%d", url, spec.min_chars)
                    continue

                # Atomic write to raw_data_dir
                with tempfile.NamedTemporaryFile(
                    mode="wb",
                    dir=str(dest_dir),
                    prefix=f".{target_path.stem}_",
                    suffix=".tmp",
                    delete=False,
                ) as tmp:
                    tmp.write(data)
                    tmp_path = Path(tmp.name)
                os.replace(tmp_path, target_path)
                return target_path, str(resp.url)
            except Exception as exc:
                logger.warning("Failed downloading %s from %s: %s", spec.key, url, exc)

    return None
