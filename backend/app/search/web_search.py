"""Live web search service using Tavily (primary) and DuckDuckGo (`ddgs`, fallback)."""

from __future__ import annotations

import asyncio
import logging
import re
import time
from typing import Any, Sequence
from urllib.parse import urlparse

import httpx
from bs4 import BeautifulSoup

from app.config import Settings, get_settings
from app.schemas import RetrievedChunk, WebSearchMode, WebSearchResponse, WebSearchResult

logger = logging.getLogger(__name__)

NEPAL_LEGAL_DOMAINS: tuple[str, ...] = (
    "lawcommission.gov.np",
    "supremecourt.gov.np",
    "rajpatra.dop.gov.np",
    "moljpa.gov.np",
    "constituteproject.org",
)

_FRESHNESS_RE = re.compile(
    r"(?:"
    r"\b(?:recent|recently|latest|current|currently|today|news|update|updated|amendment|amendments|amended|"
    r"ordinance|bill|gazette|rajpatra|2080|2081|2082|2083|2024|2025|2026|new\s+law|new\s+act|"
    r"latest\s+judgment|recent\s+judgment|latest\s+decision|recent\s+ruling)\b"
    r"|संशोधन|हालै|नयाँ|अध्यादेश|राजपत्र|२०८०|२०८१|२०८२|२०८३"
    r")",
    flags=re.IGNORECASE,
)


def _extract_domain(url: str) -> str:
    try:
        netloc = urlparse(url).netloc.lower()
        return netloc[4:] if netloc.startswith("www.") else netloc
    except Exception:
        return ""


def _domain_priority(domain: str, preferred_domains: Sequence[str]) -> int:
    if not domain:
        return 2
    for pref in preferred_domains:
        pref_l = pref.lower()
        if domain == pref_l or domain.endswith(f".{pref_l}"):
            return 0
    if domain.endswith(".gov.np"):
        return 1
    return 2


def should_run_web_search(
    mode: WebSearchMode | str,
    rag_hits: Sequence[RetrievedChunk | dict[str, Any]],
    query: str,
) -> bool:
    """Decide whether live web search should supplement local RAG retrieval."""
    raw_mode = mode.value if isinstance(mode, WebSearchMode) else str(mode or "auto").strip().lower()
    if raw_mode == WebSearchMode.OFF.value:
        return False
    if raw_mode == WebSearchMode.ALWAYS.value:
        return True

    # Auto mode: run when local RAG hits are absent/weak OR query asks for recent laws/updates
    if query and _FRESHNESS_RE.search(query):
        return True

    if not rag_hits or len(rag_hits) < 2:
        return True

    top = rag_hits[0]
    if isinstance(top, dict):
        top_score = float(top.get("score") or 0.0)
        top_dense = top.get("dense_score")
        top_bm25 = top.get("bm25_score")
    else:
        top_score = float(top.score or 0.0)
        top_dense = top.dense_score
        top_bm25 = top.bm25_score

    # RRF top single-source rank-7 score is ~0.015; below that indicates weak lexical/vector alignment
    if top_score < 0.015:
        return True

    if top_dense is not None and float(top_dense) < 0.28 and (top_bm25 is None or float(top_bm25) < 1.0):
        return True

    return False


class LiveWebSearchService:
    """Async live web search service with Tavily primary and resilient `ddgs` fallback."""

    TAVILY_URL = "https://api.tavily.com/search"

    def __init__(self, settings: Settings | None = None) -> None:
        self.settings = settings or get_settings()

    @staticmethod
    def should_run_web_search(
        mode: WebSearchMode | str,
        rag_hits: Sequence[RetrievedChunk | dict[str, Any]],
        query: str,
    ) -> bool:
        """Convenience wrapper around module-level `should_run_web_search`."""
        return should_run_web_search(mode=mode, rag_hits=rag_hits, query=query)

    async def _search_tavily(
        self,
        query: str,
        max_results: int,
        domains: list[str] | None,
        nepal_legal_only: bool,
    ) -> list[WebSearchResult]:
        api_key = self.settings.tavily_api_key
        if not api_key:
            return []

        payload: dict[str, Any] = {
            "api_key": api_key,
            "query": query,
            "max_results": max_results,
            "search_depth": "basic",
            "include_answer": False,
        }
        if domains:
            payload["include_domains"] = domains

        async with httpx.AsyncClient(timeout=float(self.settings.web_search_timeout)) as client:
            resp = await client.post(self.TAVILY_URL, json=payload)
            resp.raise_for_status()
            data = resp.json()
            raw_results = data.get("results", [])

            # If strict default Nepal domain filter yields 0 hits, broaden query with Nepal legal bias
            if not raw_results and nepal_legal_only and domains == list(NEPAL_LEGAL_DOMAINS):
                fallback_payload = {
                    "api_key": api_key,
                    "query": f"{query} Nepal law",
                    "max_results": max_results,
                    "search_depth": "basic",
                    "include_answer": False,
                }
                resp2 = await client.post(self.TAVILY_URL, json=fallback_payload)
                resp2.raise_for_status()
                raw_results = resp2.json().get("results", [])

        results: list[WebSearchResult] = []
        for item in raw_results[:max_results]:
            url = str(item.get("url") or "").strip()
            if not url:
                continue
            results.append(
                WebSearchResult(
                    title=str(item.get("title") or url).strip(),
                    url=url,
                    snippet=str(item.get("content") or "").strip(),
                    content=item.get("raw_content"),
                    source="tavily",
                    domain=_extract_domain(url),
                    published_date=item.get("published_date"),
                    score=float(item["score"]) if item.get("score") is not None else None,
                )
            )
        return results

    def _ddgs_text_sync(
        self,
        query: str,
        max_results: int,
        domains: list[str] | None,
        nepal_legal_only: bool,
    ) -> list[WebSearchResult]:
        from ddgs import DDGS

        candidate_queries: list[str] = []
        if domains and len(domains) <= 5:
            site_clause = " OR ".join(f"site:{d}" for d in domains)
            candidate_queries.append(f"{query} ({site_clause})")
        if nepal_legal_only and "nepal" not in query.lower():
            candidate_queries.append(f"{query} Nepal law")
        candidate_queries.append(query)

        raw_hits: list[dict[str, Any]] = []
        last_exc: Exception | None = None
        backends = ("auto", "google", "yahoo", "bing", "duckduckgo")

        for candidate_q in candidate_queries:
            for backend in backends:
                try:
                    hits = DDGS().text(
                        candidate_q,
                        max_results=max_results,
                        backend=backend,
                    )
                    if hits:
                        raw_hits = list(hits)
                        break
                except Exception as exc:
                    last_exc = exc
                    continue
            if raw_hits:
                break

        if not raw_hits and last_exc is not None:
            raise last_exc

        results: list[WebSearchResult] = []
        seen_urls: set[str] = set()
        for item in raw_hits:
            url = str(item.get("href") or item.get("url") or "").strip()
            if not url or url in seen_urls:
                continue
            seen_urls.add(url)
            results.append(
                WebSearchResult(
                    title=str(item.get("title") or url).strip(),
                    url=url,
                    snippet=str(item.get("body") or item.get("snippet") or "").strip(),
                    source="ddgs",
                    domain=_extract_domain(url),
                )
            )

        if domains:
            results.sort(key=lambda r: _domain_priority(r.domain or "", domains))
        return results[:max_results]

    async def fetch_url_text(self, url: str, max_chars: int = 4000) -> str | None:
        """Fetch and extract clean readable text from a web URL via httpx + BeautifulSoup."""
        try:
            async with httpx.AsyncClient(
                timeout=float(self.settings.web_search_timeout),
                follow_redirects=True,
                headers={"User-Agent": "WakilAI-LegalSearch/1.0"},
            ) as client:
                resp = await client.get(url)
                resp.raise_for_status()
                content_type = resp.headers.get("content-type", "").lower()
                if "html" not in content_type and "text" not in content_type:
                    return None
                soup = BeautifulSoup(resp.text, "lxml")
                for tag in soup(["script", "style", "nav", "header", "footer", "aside", "noscript"]):
                    tag.decompose()
                text = " ".join(soup.get_text(separator=" ").split())
                return text[:max_chars] if text else None
        except Exception as exc:
            logger.debug("Optional URL text extraction skipped for %s: %s", url, exc)
            return None

    async def _enrich_page_contents(self, results: list[WebSearchResult]) -> None:
        if not results:
            return
        fetched = await asyncio.gather(
            *(self.fetch_url_text(item.url) for item in results),
            return_exceptions=True,
        )
        for item, text in zip(results, fetched):
            if isinstance(text, str) and text:
                item.content = text

    async def search(
        self,
        query: str,
        max_results: int = 5,
        nepal_legal_only: bool = True,
        include_domains: list[str] | None = None,
        fetch_page_content: bool = False,
    ) -> WebSearchResponse:
        """Execute live web search using Tavily when configured, falling back to `ddgs`."""
        started = time.perf_counter()
        domains = (
            list(include_domains)
            if include_domains
            else (list(NEPAL_LEGAL_DOMAINS) if nepal_legal_only else None)
        )

        results: list[WebSearchResult] = []
        provider = "none"
        errors: list[str] = []

        if self.settings.tavily_api_key:
            try:
                results = await self._search_tavily(
                    query=query,
                    max_results=max_results,
                    domains=domains,
                    nepal_legal_only=nepal_legal_only,
                )
                if results:
                    provider = "tavily"
            except Exception as exc:
                safe_msg = f"Tavily search error ({type(exc).__name__})"
                logger.warning("%s", safe_msg)
                errors.append(safe_msg)

        if not results:
            try:
                results = await asyncio.wait_for(
                    asyncio.to_thread(
                        self._ddgs_text_sync,
                        query,
                        max_results,
                        domains,
                        nepal_legal_only,
                    ),
                    timeout=float(self.settings.web_search_timeout),
                )
                if results:
                    provider = "ddgs"
            except Exception as exc:
                safe_msg = f"DDGS fallback error ({type(exc).__name__}: {exc})"
                logger.warning("%s", safe_msg)
                errors.append(safe_msg)

        if results and domains:
            results.sort(key=lambda r: _domain_priority(r.domain or "", domains))

        if fetch_page_content and results:
            await self._enrich_page_contents(results)

        latency_ms = round((time.perf_counter() - started) * 1000.0, 2)
        return WebSearchResponse(
            query=query,
            provider=provider,
            results=results[:max_results],
            total_results=len(results[:max_results]),
            latency_ms=latency_ms,
            error="; ".join(errors) if (not results and errors) else None,
        )
