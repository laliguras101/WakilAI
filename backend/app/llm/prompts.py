"""Bilingual (EN / NP / Nepglish) Nepalese legal RAG system prompts and token-budgeted formatting."""

from __future__ import annotations

import re
from typing import Iterable, Literal, Mapping, Sequence, Union

from app.schemas import ChatMessageItem, OpenAIChatMessage, RetrievedChunk, WebSearchResult

DEFAULT_LEGAL_TEMPERATURE: float = 0.2

_DEVANAGARI_RE = re.compile(r"[\u0900-\u097F]")
_ASCII_WORD_RE = re.compile(r"[a-z]+")

# Strong Romanized Nepglish legal and grammatical markers (require either 1 strong marker
# or 2+ general markers to avoid false positives on standard English questions).
_STRONG_NEPGLISH_TOKENS: frozenset[str] = frozenset(
    {
        "gharbeti",
        "gharbheti",
        "dinuparchha",
        "dinuparcha",
        "parchha",
        "parcha",
        "milchha",
        "milcha",
        "hunchha",
        "huncha",
        "chha",
        "chhan",
        "samvidhan",
        "sambidhan",
        "firyad",
        "phirad",
        "phiradpatra",
        "bahal",
        "faujdari",
        "dewani",
        "kanoon",
        "kanun",
        "dafa",
        "dhara",
        "ansha",
        "jarimana",
        "sajaya",
        "adalat",
        "mudda",
        "wakil",
        "nyaya",
        "muluki",
        "ain",
        "niyam",
        "nkp",
        "talab",
        "jyala",
        "bihaha",
        "bibaha",
        "chhodpatra",
        "sambandha",
        "bicched",
    }
)

_GENERAL_NEPGLISH_TOKENS: frozenset[str] = frozenset(
    {
        "kati",
        "kasari",
        "kina",
        "kun",
        "kasto",
        "tapai",
        "hamro",
        "mero",
        "garna",
        "garnu",
        "bata",
        "haru",
        "lagne",
        "badhauna",
        "haina",
        "hoina",
        "ra",
        "le",
        "ma",
        "ko",
        "lai",
        "chhaina",
        "chaina",
        "bhane",
        "pachhi",
        "aghi",
        "mathi",
    }
)


def is_nepglish(text: str) -> bool:
    """Return True when an ASCII query exhibits Romanized Nepali (Nepglish) markers."""
    if not text or _DEVANAGARI_RE.search(text):
        return False
    tokens = _ASCII_WORD_RE.findall(text.lower())
    if not tokens:
        return False
    token_set = set(tokens)
    if token_set & _STRONG_NEPGLISH_TOKENS:
        return True
    return len(token_set & _GENERAL_NEPGLISH_TOKENS) >= 3


def detect_query_language(
    query: str,
    preferred: Literal["auto", "EN", "NP"] = "auto",
) -> Literal["EN", "NP"]:
    """Resolve output language (`EN` or `NP`) from explicit preference or query script."""
    if preferred in ("EN", "NP"):
        return preferred
    devanagari_chars = len(_DEVANAGARI_RE.findall(query or ""))
    if devanagari_chars >= 2:
        return "NP"
    return "EN"


def estimate_tokens(text: str) -> int:
    """Estimate LLM token count conservatively across ASCII and Devanagari scripts."""
    if not text:
        return 0
    devanagari_count = len(_DEVANAGARI_RE.findall(text))
    other_count = len(text) - devanagari_count
    # Devanagari characters frequently map to ~0.5-0.75 tokens each; ASCII averages ~0.25.
    estimated = (devanagari_count * 0.65) + (other_count * 0.25)
    return max(1, int(estimated) + 1)


def _truncate_to_token_budget(text: str, max_tokens: int) -> str:
    """Truncate text cleanly at word boundary to fit within `max_tokens`."""
    if max_tokens <= 0:
        return ""
    if estimate_tokens(text) <= max_tokens:
        return text
    # Approximate safe character budget based on average density.
    ratio = len(text) / max(1, estimate_tokens(text))
    target_chars = max(40, int(max_tokens * ratio * 0.9))
    clipped = text[:target_chars].rsplit(" ", 1)[0].rstrip()
    if not clipped:
        clipped = text[:target_chars]
    return f"{clipped}..."


def build_system_prompt(
    language: Literal["EN", "NP"] = "EN",
    *,
    has_rag: bool = True,
    has_web: bool = False,
    nepglish_detected: bool = False,
    extra_instruction: str | None = None,
) -> str:
    """Build the Nepalese legal RAG system prompt with strict citation & anti-fabrication rules."""
    if language == "NP":
        base_prompt = (
            "तपाईं WakilAI हुनुहुन्छ — नेपालको संविधान, प्रचलित ऐन, नियम, र सर्वोच्च अदालतका नजीरहरूमा आधारित एक विश्वसनीय कानूनी सहायक।\n\n"
            "कडाइका साथ पालना गर्नुपर्ने नियमहरू:\n"
            "१. **प्रमाणमा आधारित उद्धरण (Citation Grounding)**: प्रदान गरिएको कानूनी सन्दर्भ (RAG खण्डहरू) बाट लिइएको प्रत्येक कानूनी तथ्य वा दाबीको पछाडि अनिवार्य रूपमा सटीक उद्धरण राख्नुहोस् — जस्तै `[ऐनको नाम, दफा X]` वा `[Act Name, Sec. X]` (सन्दर्भमा दिइएको exact citation label प्रयोग गर्नुहोस्)।\n"
            "२. **लाइभ वेब स्रोत उद्धरण**: वेब खोज (Web Search) बाट लिइएको जानकारीको पछाडि अनिवार्य रूपमा `[Web: Source Title](url)` ढाँचामा लिंक उद्धरण राख्नुहोस्।\n"
            "३. **काल्पनिक वा बनावटी तथ्य निषेध (Zero Fabrication)**: यदि दिइएको सन्दर्भ सामग्री वा वेब नतिजाले प्रश्नको कुनै भागको पर्याप्त उत्तर दिँदैन भने, कृपया स्पष्ट रूपमा 'उपलब्ध कानूनी सन्दर्भमा यस विषयमा पर्याप्त विवरण भेटिएन' भन्नुहोस्। कहिल्यै पनि दफा, धारा, सजाय, म्याद वा मुद्दा नम्बर अनुमान वा बनावट नगर्नुहोस्।\n"
            "४. **स्पष्टता र भाषा**: शुद्ध, सम्मानजनक र बुझ्न सजिलो नेपाली भाषामा कानूनी प्रावधान, अपवाद र व्यावहारिक प्रक्रिया बुँदागत रूपमा व्याख्या गर्नुहोस्।\n"
            "५. **सूचनात्मक सीमा**: उत्तरको अन्त्यमा यो सामान्य कानूनी जानकारी मात्र हो र औपचारिक कानूनी सल्लाह होइन भनी एक वाक्यमा उल्लेख गर्नुहोस्।"
        )
    else:
        base_prompt = (
            "You are WakilAI, an authoritative Nepalese Legal Research Assistant grounded in the "
            "Constitution of Nepal, prevailing Nepalese statutes, rules, directives, and Supreme Court precedents.\n\n"
            "STRICT GROUNDING & CITATION RULES:\n"
            "1. **Statutory Citation Grounding**: Every legal rule, right, penalty, time limit, or procedural claim derived from the retrieved statutory context MUST include an inline citation using the exact label provided, e.g., `[Act Name, Sec. X]` or `[Constitution of Nepal 2072, Art. X]` (or `[दफा X]` when citing Nepali text).\n"
            "2. **Live Web Citation Grounding**: Every fact derived from live web search results MUST include an inline markdown citation in the exact format `[Web: Source Title](url)`.\n"
            "3. **Strict Anti-Fabrication & Refusal**: Never invent, guess, or extrapolate section numbers, article numbers, statutory fines, limitation periods, case citations, or amendment dates. If the provided statutory context and web results are empty or insufficient to answer part or all of the question, explicitly state what is missing in the provided sources.\n"
            "4. **Structured Legal Analysis**: Organize answers clearly (Relevant Provision -> Key Requirements/Exceptions -> Practical Next Steps) in accurate, accessible language.\n"
            "5. **Informational Boundary**: End with a brief one-sentence note clarifying that this is legal information, not formal legal representation."
        )
        if nepglish_detected:
            base_prompt += (
                "\n6. **Romanized Nepglish Query Handling**: The user asked in Romanized Nepali (Nepglish). "
                "Respond in clear, plain English while preserving key Nepali legal terms in parentheses "
                "(e.g., *Gharbeti / Landlord*, *Bahal / Rent*, *Dafa / Section*) so the answer is immediately clear."
            )

    if not has_rag and not has_web:
        if language == "NP":
            base_prompt += (
                "\n\nनोट: यस अनुरोधमा कुनै स्थानीय कानूनी कागजात (RAG) वा वेब खोज सन्दर्भ उपलब्ध गराइएको छैन। "
                "तसर्थ, कुनै विशिष्ट दफा वा धाराको संख्या दाबी गर्नुअघि सन्दर्भ उपलब्ध नभएको स्पष्ट पार्नुहोस्।"
            )
        else:
            base_prompt += (
                "\n\nNOTE: No statutory RAG chunks or live web search results were provided for this turn. "
                "Do not fabricate specific section numbers or unverified recent amendments; state clearly when statutory verification is required."
            )

    if extra_instruction and extra_instruction.strip():
        base_prompt += f"\n\nAdditional Client Context:\n{extra_instruction.strip()}"

    return base_prompt


def format_context_block(
    chunks: Sequence[RetrievedChunk],
    web_results: Sequence[WebSearchResult],
    *,
    max_context_tokens: int = 5500,
) -> str:
    """Format retrieved RAG chunks and live web snippets into a token-capped grounding block."""
    if not chunks and not web_results:
        return ""

    sections: list[str] = []
    remaining_tokens = max(256, max_context_tokens)

    if chunks:
        rag_budget = int(remaining_tokens * (0.75 if web_results else 1.0))
        rag_lines: list[str] = ["### RETRIEVED NEPAL STATUTORY & LEGAL CONTEXT"]
        used = estimate_tokens(rag_lines[0])
        for idx, chunk in enumerate(chunks, start=1):
            label = chunk.citation_label or chunk.act_name or f"Document {chunk.doc_id}"
            pages = ""
            if chunk.page_start is not None:
                pages = (
                    f" | Pages: {chunk.page_start}-{chunk.page_end}"
                    if chunk.page_end and chunk.page_end != chunk.page_start
                    else f" | Page: {chunk.page_start}"
                )
            sec_title = f" | Title: {chunk.section_title}" if chunk.section_title else ""
            header = (
                f"[S{idx}] Citation: [{label}] | Category: {chunk.category.value} | "
                f"Lang: {chunk.language}{pages}{sec_title} | Relevance: {chunk.score:.3f}"
            )
            body = chunk.text.strip()
            entry = f"{header}\n{body}"
            entry_tokens = estimate_tokens(entry)
            if used + entry_tokens > rag_budget:
                avail = rag_budget - used - estimate_tokens(header) - 10
                if idx == 1 and avail >= 120:
                    entry = f"{header}\n{_truncate_to_token_budget(body, avail)}"
                    rag_lines.append(entry)
                    used += estimate_tokens(entry)
                break
            rag_lines.append(entry)
            used += entry_tokens
        if len(rag_lines) > 1:
            block = "\n\n".join(rag_lines)
            sections.append(block)
            remaining_tokens = max(200, remaining_tokens - used)

    if web_results:
        web_lines: list[str] = ["### LIVE WEB SEARCH RESULTS"]
        used = estimate_tokens(web_lines[0])
        for idx, hit in enumerate(web_results, start=1):
            meta_parts = [f"[W{idx}] Citation Format: [Web: {hit.title}]({hit.url})"]
            if hit.domain:
                meta_parts.append(f"Domain: {hit.domain}")
            if hit.published_date:
                meta_parts.append(f"Published: {hit.published_date}")
            header = " | ".join(meta_parts)
            body = (hit.content or hit.snippet or "").strip()
            entry = f"{header}\n{body}" if body else header
            entry_tokens = estimate_tokens(entry)
            if used + entry_tokens > remaining_tokens:
                avail = remaining_tokens - used - estimate_tokens(header) - 10
                if idx == 1 and avail >= 80 and body:
                    entry = f"{header}\n{_truncate_to_token_budget(body, avail)}"
                    web_lines.append(entry)
                    used += estimate_tokens(entry)
                break
            web_lines.append(entry)
            used += entry_tokens
        if len(web_lines) > 1:
            sections.append("\n\n".join(web_lines))

    return "\n\n---\n\n".join(sections)


def trim_history(
    history: Sequence[Union[ChatMessageItem, OpenAIChatMessage, Mapping[str, str]]],
    *,
    max_history_tokens: int = 2000,
) -> list[dict[str, str]]:
    """Keep the most recent non-system conversation turns within `max_history_tokens`."""
    normalized: list[dict[str, str]] = []
    for item in history:
        if isinstance(item, OpenAIChatMessage):
            role = item.role
            content = item.text_content().strip()
        elif isinstance(item, ChatMessageItem):
            role = item.role
            content = item.content.strip()
        else:
            role = str(item.get("role", "user")).strip().lower()
            content = str(item.get("content", "")).strip()
        if role not in ("user", "assistant") or not content:
            continue
        normalized.append({"role": role, "content": content})

    if not normalized or max_history_tokens <= 0:
        return []

    kept_reversed: list[dict[str, str]] = []
    used_tokens = 0
    for msg in reversed(normalized):
        msg_tokens = estimate_tokens(msg["content"]) + 6
        if used_tokens + msg_tokens > max_history_tokens:
            if not kept_reversed:
                clipped = _truncate_to_token_budget(msg["content"], max_history_tokens - 6)
                if clipped:
                    kept_reversed.append({"role": msg["role"], "content": clipped})
            break
        kept_reversed.append(msg)
        used_tokens += msg_tokens
    kept_reversed.reverse()
    return kept_reversed


def build_rag_messages(
    query: str,
    *,
    chunks: Sequence[RetrievedChunk] = (),
    web_results: Sequence[WebSearchResult] = (),
    history: Sequence[Union[ChatMessageItem, OpenAIChatMessage, Mapping[str, str]]] = (),
    language: Literal["auto", "EN", "NP"] = "auto",
    extra_system_instruction: str | None = None,
    max_context_tokens: int = 5500,
    max_history_tokens: int = 2000,
) -> tuple[list[dict[str, str]], Literal["EN", "NP"]]:
    """Assemble grounded system, history, and context-augmented user messages within token budgets."""
    resolved_lang = detect_query_language(query, preferred=language)
    nepglish = resolved_lang == "EN" and is_nepglish(query)

    system_prompt = build_system_prompt(
        resolved_lang,
        has_rag=bool(chunks),
        has_web=bool(web_results),
        nepglish_detected=nepglish,
        extra_instruction=extra_system_instruction,
    )

    messages: list[dict[str, str]] = [{"role": "system", "content": system_prompt}]
    messages.extend(trim_history(history, max_history_tokens=max_history_tokens))

    context_block = format_context_block(
        chunks,
        web_results,
        max_context_tokens=max_context_tokens,
    )
    if context_block:
        user_content = (
            f"{context_block}\n\n"
            f"### USER QUESTION\n{query.strip()}\n\n"
            "Answer strictly from the grounded sources above where applicable, preserving exact inline citations."
        )
    else:
        user_content = query.strip()

    messages.append({"role": "user", "content": user_content})
    return messages, resolved_lang
