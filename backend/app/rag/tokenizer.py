"""Bilingual English, Devanagari, and Romanized Nepglish legal tokenizer."""

from __future__ import annotations

import re
import unicodedata

NEPALI_DIGIT_TRANSLATION = str.maketrans("०१२३४५६७८९", "0123456789")

# Zero-width and stray symbol artifacts occasionally seen in converted statutory texts
_ZERO_WIDTH_RE = re.compile(r"[\u200b\u200c\u200d\ufeff]")
_PUNCT_TO_SPACE_RE = re.compile(r"[\u0964\u0965\u0970\u2013\u2014\uf0e5\uf0b2•·।॥॰\"'`´‘’“”()\[\]{}<>:;,.!?/\\|_~@#$%^&*+=]+")
_WHITESPACE_RE = re.compile(r"\s+")

# Separate Devanagari runs, ASCII letter words, and ASCII numbers so e.g. "दफा३९१" -> ["दफा", "391"]
_TOKEN_RE = re.compile(
    r"[\u0900-\u0963\u0971-\u097F\uA8E0-\uA8FF]+|[A-Za-z]+|[0-9]+"
)

# Conservative English-only function stopwords; never drop numbers, Devanagari, or legal nouns/verbs
_ENGLISH_STOPWORDS: frozenset[str] = frozenset(
    {
        "a",
        "an",
        "and",
        "are",
        "as",
        "at",
        "be",
        "been",
        "being",
        "by",
        "did",
        "do",
        "does",
        "for",
        "from",
        "had",
        "has",
        "have",
        "how",
        "in",
        "is",
        "it",
        "its",
        "of",
        "on",
        "or",
        "that",
        "the",
        "these",
        "this",
        "those",
        "to",
        "was",
        "were",
        "what",
        "when",
        "where",
        "which",
        "who",
        "whom",
        "whose",
        "why",
        "with",
    }
)

# Multi-word Romanized Nepglish legal phrases expanded before token-level mapping
NEPGLISH_PHRASE_ALIASES: dict[str, tuple[str, ...]] = {
    "sambandha bicched": ("marriage", "divorce", "सम्बन्ध", "विच्छेद"),
    "sambandha bichhed": ("marriage", "divorce", "सम्बन्ध", "विच्छेद"),
    "ghar bahal": ("house", "rent", "lease", "tenancy", "landlord", "घरबहाल"),
    "sarbochcha adalat": ("supreme", "court", "सर्वोच्च", "अदालत"),
    "nepal kanoon patrika": ("nkp", "supreme", "court", "precedent"),
    "nepal kanun patrika": ("nkp", "supreme", "court", "precedent"),
}

# Token-level Romanized Nepglish statutory alias map (boosts BM25 recall without altering facts)
NEPGLISH_STATUTORY_ALIASES: dict[str, tuple[str, ...]] = {
    "gharbeti": ("landlord", "house", "rent", "tenancy", "घरबेटी", "घरबहाल"),
    "gharbheti": ("landlord", "house", "rent", "tenancy", "घरबेटी", "घरबहाल"),
    "bahal": ("rent", "lease", "tenancy", "बहाल", "भाडा"),
    "bhada": ("rent", "lease", "tenancy", "भाडा", "बहाल"),
    "karar": ("contract", "agreement", "करार"),
    "firyad": ("plaint", "petition", "complaint", "फिराद", "फिरादपत्र"),
    "phiradpatra": ("plaint", "petition", "complaint", "फिरादपत्र"),
    "firyadpatra": ("plaint", "petition", "complaint", "फिरादपत्र"),
    "dafa": ("section", "clause", "दफा"),
    "dhara": ("article", "clause", "धारा"),
    "niyam": ("rule", "regulation", "नियम"),
    "niyamawali": ("rules", "regulations", "नियमावली"),
    "kanun": ("law", "act", "statute", "कानुन", "ऐन"),
    "kanoon": ("law", "act", "statute", "कानुन", "ऐन"),
    "ain": ("act", "statute", "law", "ऐन"),
    "nkp": ("supreme", "court", "precedent", "nepal", "kanoon", "patrika", "नेपाल", "कानुन", "पत्रिका"),
    "dewani": ("civil", "देवानी"),
    "aparadh": ("criminal", "penal", "offence", "अपराध"),
    "faujdari": ("criminal", "penal", "फौजदारी"),
    "shram": ("labour", "labor", "employment", "श्रम"),
    "samvidhan": ("constitution", "संविधान"),
    "sambidhan": ("constitution", "संविधान"),
    "talab": ("wage", "salary", "remuneration", "तलब", "पारिश्रमिक"),
    "jyala": ("wage", "salary", "remuneration", "ज्याला", "पारिश्रमिक"),
    "bihaha": ("marriage", "matrimonial", "विवाह"),
    "bihe": ("marriage", "matrimonial", "विवाह"),
    "bicched": ("marriage", "divorce", "विच्छेद"),
    "bichhed": ("marriage", "divorce", "विच्छेद"),
    "ansha": ("partition", "property", "share", "अंश", "अंशबण्डा"),
    "anshabanda": ("partition", "property", "share", "अंशबण्डा"),
    "cyber": ("electronic", "transactions", "cybercrime", "विद्युतीय", "कारोबार"),
    "jagga": ("land", "property", "जग्गा"),
    "mudda": ("case", "lawsuit", "litigation", "मुद्दा"),
    "adalat": ("court", "अदालत"),
    "sarbochcha": ("supreme", "court", "सर्वोच्च"),
    "wakil": ("lawyer", "advocate", "counsel", "वकिल"),
    "praman": ("evidence", "proof", "प्रमाण"),
    "company": ("company", "corporate", "कम्पनी"),
}

# Cross-lingual Devanagari -> English/Nepglish aliases for bilingual statute retrieval
DEVANAGARI_STATUTORY_ALIASES: dict[str, tuple[str, ...]] = {
    "दफा": ("section", "dafa"),
    "धारा": ("article", "dhara"),
    "नियम": ("rule", "niyam"),
    "ऐन": ("act", "law", "statute"),
    "संविधान": ("constitution", "samvidhan"),
    "करार": ("contract", "agreement"),
    "देवानी": ("civil", "dewani"),
    "अपराध": ("criminal", "penal", "offence"),
    "फौजदारी": ("criminal", "penal"),
    "श्रम": ("labour", "labor", "employment"),
    "घरबहाल": ("house", "rent", "lease", "tenancy", "landlord"),
    "घरबेटी": ("landlord", "house", "rent", "tenancy"),
    "बहाल": ("rent", "lease", "tenancy"),
    "तलब": ("wage", "salary", "remuneration"),
    "ज्याला": ("wage", "salary", "remuneration"),
    "विवाह": ("marriage", "matrimonial"),
    "विच्छेद": ("divorce", "marriage"),
    "अंश": ("partition", "property", "share"),
    "अंशबण्डा": ("partition", "property", "share"),
    "विद्युतीय": ("electronic", "transactions", "cyber"),
    "कारोबार": ("transactions", "electronic"),
    "प्रमाण": ("evidence", "proof"),
    "कम्पनी": ("company", "corporate"),
    "फिरादपत्र": ("plaint", "petition"),
    "सर्वोच्च": ("supreme", "court"),
}

# Explicit section/article/rule patterns (after Nepali digit translation)
_SECTION_NUM_RE = re.compile(
    r"(?:^|[\s(,;:])"
    r"(?:section|sec\.?|article|art\.?|rule|clause|sub-?section|dafa|dhara|niyam|दफा|धारा|नियम|उपदफा|s\.)"
    r"\s*(?:no\.?|number|नं\.?)?\s*[:\-]?\s*([0-9]{1,4})",
    flags=re.IGNORECASE,
)


def normalize_nepali_digits(text: str) -> str:
    """Convert Unicode Devanagari digits (०-९) into ASCII digits (0-9)."""
    if not text:
        return ""
    return text.translate(NEPALI_DIGIT_TRANSLATION)


def clean_legal_text(text: str) -> str:
    """Normalize Unicode, convert Nepali digits, clean purna biram/symbols, and tidy whitespace."""
    if not text:
        return ""
    normalized = unicodedata.normalize("NFC", text)
    normalized = normalize_nepali_digits(normalized)
    normalized = _ZERO_WIDTH_RE.sub("", normalized)
    normalized = _PUNCT_TO_SPACE_RE.sub(" ", normalized)
    return _WHITESPACE_RE.sub(" ", normalized).strip()


def tokenize_legal_text(text: str, *, remove_stopwords: bool = True) -> list[str]:
    """Tokenize English, Devanagari, and numeric statutory text cleanly."""
    cleaned = clean_legal_text(text)
    if not cleaned:
        return []

    tokens: list[str] = []
    for raw in _TOKEN_RE.findall(cleaned):
        tok = raw.lower() if raw.isascii() else raw
        if remove_stopwords and tok in _ENGLISH_STOPWORDS:
            continue
        tokens.append(tok)
    return tokens


def expand_query_tokens(query: str, *, include_devanagari_aliases: bool = True) -> list[str]:
    """Tokenize a query and append Nepglish/Devanagari statutory aliases without duplicates."""
    base_tokens = tokenize_legal_text(query, remove_stopwords=True)
    if not base_tokens:
        return []

    seen: set[str] = set()
    ordered: list[str] = []

    def _add(token: str) -> None:
        if token and token not in seen:
            seen.add(token)
            ordered.append(token)

    for tok in base_tokens:
        _add(tok)

    lowered_clean = clean_legal_text(query).lower()
    for phrase, expansions in NEPGLISH_PHRASE_ALIASES.items():
        if phrase in lowered_clean:
            for exp in expansions:
                if not include_devanagari_aliases and not exp.isascii():
                    continue
                _add(exp.lower() if exp.isascii() else exp)

    for tok in base_tokens:
        if tok in NEPGLISH_STATUTORY_ALIASES:
            for exp in NEPGLISH_STATUTORY_ALIASES[tok]:
                if not include_devanagari_aliases and not exp.isascii():
                    continue
                _add(exp.lower() if exp.isascii() else exp)
        elif tok in DEVANAGARI_STATUTORY_ALIASES:
            for exp in DEVANAGARI_STATUTORY_ALIASES[tok]:
                if not include_devanagari_aliases and not exp.isascii():
                    continue
                _add(exp.lower() if exp.isascii() else exp)

    return ordered


def extract_section_numbers(text: str) -> list[str]:
    """Extract normalized ASCII section/article/rule numbers explicitly referenced in text."""
    if not text:
        return []
    normalized = normalize_nepali_digits(unicodedata.normalize("NFC", text))
    found: list[str] = []
    seen: set[str] = set()
    for match in _SECTION_NUM_RE.finditer(normalized):
        num = match.group(1).lstrip("0") or "0"
        if num not in seen:
            seen.add(num)
            found.append(num)
    return found
