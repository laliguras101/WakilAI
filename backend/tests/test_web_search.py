"""Tests for live web search modes (`off`, `auto`, `always`), Tavily/DDGS parsing, and resilience."""

from __future__ import annotations

import asyncio
import sys
import types
from typing import Any

import httpx
import pytest

from app.config import Settings
from app.schemas import CategoryEnum, RetrievedChunk, WebSearchMode
from app.search.web_search import (
    NEPAL_LEGAL_DOMAINS,
    LiveWebSearchService,
    should_run_web_search,
)


def _make_chunk(
    *,
    score: float = 0.04,
    dense_score: float = 0.72,
    bm25_score: float = 4.5,
) -> RetrievedChunk:
    return RetrievedChunk(
        chunk_id="c-1",
        doc_id="d-1",
        text="Section 391 house rent provision.",
        act_name="Muluki Civil Code 2074",
        category=CategoryEnum.CODES,
        score=score,
        dense_score=dense_score,
        bm25_score=bm25_score,
    )


def test_web_search_mode_and_auto_trigger_thresholds() -> None:
    strong_hits = [_make_chunk(), _make_chunk()]

    # Explicit OFF / ALWAYS policies
    assert should_run_web_search(WebSearchMode.OFF, [], "latest amendment 2082") is False
    assert should_run_web_search("off", [], "anything") is False
    assert should_run_web_search(WebSearchMode.ALWAYS, strong_hits, "Article 28") is True
    assert should_run_web_search("always", strong_hits, "Article 28") is True

    # Auto mode: skips when strong local hits exist and no freshness trigger
    assert should_run_web_search(WebSearchMode.AUTO, strong_hits, "house rent increase section 391") is False

    # Auto mode: triggers on freshness cues (year / amendment / latest judgment / Nepali terms)
    assert should_run_web_search(WebSearchMode.AUTO, strong_hits, "latest amendment 2082 Nepal") is True
    assert should_run_web_search(WebSearchMode.AUTO, strong_hits, "संशोधन २०८१ बारे") is True
    assert should_run_web_search(WebSearchMode.AUTO, strong_hits, "recent Supreme Court judgment") is True

    # Auto mode: triggers on empty / sparse (<2) / weak RRF score / weak dense+bm25 scores
    assert should_run_web_search(WebSearchMode.AUTO, [], "Article 28") is True
    assert should_run_web_search(WebSearchMode.AUTO, [_make_chunk()], "Article 28") is True
    assert (
        should_run_web_search(
            WebSearchMode.AUTO,
            [_make_chunk(score=0.01), _make_chunk(score=0.008)],
            "Article 28",
        )
        is True
    )
    assert (
        should_run_web_search(
            WebSearchMode.AUTO,
            [_make_chunk(score=0.02, dense_score=0.20, bm25_score=0.5), _make_chunk()],
            "Article 28",
        )
        is True
    )


def test_tavily_primary_search_and_domain_sorting(
    isolated_settings: Settings,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    isolated_settings.tavily_api_key = "tvly-test-key"
    captured_payloads: list[dict[str, Any]] = []

    class FakeResponse:
        def __init__(self, payload: dict[str, Any]) -> None:
            self._payload = payload

        def raise_for_status(self) -> None:
            return None

        def json(self) -> dict[str, Any]:
            return self._payload

    class FakeAsyncClient:
        def __init__(self, *args: Any, **kwargs: Any) -> None:
            pass

        async def __aenter__(self) -> FakeAsyncClient:
            return self

        async def __aexit__(self, *args: Any) -> None:
            return None

        async def post(self, url: str, json: dict[str, Any]) -> FakeResponse:
            captured_payloads.append(json)
            return FakeResponse(
                {
                    "results": [
                        {
                            "title": "General Legal Blog",
                            "url": "https://example.org/nepal-rent",
                            "content": "General blog post on rent.",
                            "score": 0.91,
                        },
                        {
                            "title": "Nepal Law Commission - Muluki Civil Code",
                            "url": "https://www.lawcommission.gov.np/en/civil-code",
                            "content": "Section 391 regulates rent increase.",
                            "score": 0.85,
                            "published_date": "2024-01-10",
                        },
                    ]
                }
            )

    monkeypatch.setattr(httpx, "AsyncClient", FakeAsyncClient)

    service = LiveWebSearchService(settings=isolated_settings)
    resp = asyncio.run(service.search("house rent increase Nepal", max_results=4, nepal_legal_only=True))

    assert resp.provider == "tavily"
    assert resp.error is None
    assert resp.total_results == 2
    assert captured_payloads[0]["include_domains"] == list(NEPAL_LEGAL_DOMAINS)
    # Authoritative Nepal domain should be prioritized first
    assert resp.results[0].domain == "lawcommission.gov.np"
    assert resp.results[0].source == "tavily"
    assert resp.results[0].published_date == "2024-01-10"


def test_ddgs_fallback_when_tavily_fails_or_unset(
    isolated_settings: Settings,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    isolated_settings.tavily_api_key = "tvly-failing-key"

    class FailingAsyncClient:
        def __init__(self, *args: Any, **kwargs: Any) -> None:
            pass

        async def __aenter__(self) -> FailingAsyncClient:
            return self

        async def __aexit__(self, *args: Any) -> None:
            return None

        async def post(self, *args: Any, **kwargs: Any) -> Any:
            raise httpx.ConnectError("Tavily unreachable")

    class FakeDDGS:
        def text(self, query: str, max_results: int = 5, backend: str = "auto") -> list[dict[str, Any]]:
            return [
                {
                    "title": "Supreme Court Precedent NKP",
                    "href": "https://supremecourt.gov.np/web/nkp-decision",
                    "body": "Decision on tenancy rights and due notice.",
                },
                {
                    "title": "Duplicate Hit",
                    "href": "https://supremecourt.gov.np/web/nkp-decision",
                    "body": "Duplicate should be deduped.",
                },
            ]

    monkeypatch.setattr(httpx, "AsyncClient", FailingAsyncClient)
    monkeypatch.setitem(sys.modules, "ddgs", types.SimpleNamespace(DDGS=FakeDDGS))

    service = LiveWebSearchService(settings=isolated_settings)
    resp = asyncio.run(service.search("tenancy precedent", max_results=5))

    assert resp.provider == "ddgs"
    assert resp.error is None
    assert resp.total_results == 1
    assert resp.results[0].domain == "supremecourt.gov.np"
    assert resp.results[0].source == "ddgs"


def test_web_search_error_resilience_when_all_providers_fail(
    isolated_settings: Settings,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    isolated_settings.tavily_api_key = "tvly-bad"

    class FailingAsyncClient:
        def __init__(self, *args: Any, **kwargs: Any) -> None:
            pass

        async def __aenter__(self) -> FailingAsyncClient:
            return self

        async def __aexit__(self, *args: Any) -> None:
            return None

        async def post(self, *args: Any, **kwargs: Any) -> Any:
            raise RuntimeError("Tavily HTTP 500")

    class BrokenDDGS:
        def text(self, *args: Any, **kwargs: Any) -> Any:
            raise RuntimeError("DDGS rate limited")

    monkeypatch.setattr(httpx, "AsyncClient", FailingAsyncClient)
    monkeypatch.setitem(sys.modules, "ddgs", types.SimpleNamespace(DDGS=BrokenDDGS))

    service = LiveWebSearchService(settings=isolated_settings)
    resp = asyncio.run(service.search("Nepal supreme court latest", max_results=3))

    assert resp.provider == "none"
    assert resp.total_results == 0
    assert resp.results == []
    assert resp.error is not None
    assert "Tavily" in resp.error
    assert "DDGS" in resp.error


def test_fetch_url_text_strips_navigation_and_scripts(
    isolated_settings: Settings,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    class FakeGetResponse:
        headers = {"content-type": "text/html; charset=utf-8"}
        text = (
            "<html><body><nav>Menu</nav><script>console.log(1)</script>"
            "<main><p>Section 391 governs house rent increases in Nepal.</p></main>"
            "<footer>Footer</footer></body></html>"
        )

        def raise_for_status(self) -> None:
            return None

    class FakeAsyncClient:
        def __init__(self, *args: Any, **kwargs: Any) -> None:
            pass

        async def __aenter__(self) -> FakeAsyncClient:
            return self

        async def __aexit__(self, *args: Any) -> None:
            return None

        async def get(self, url: str) -> FakeGetResponse:
            return FakeGetResponse()

    monkeypatch.setattr(httpx, "AsyncClient", FakeAsyncClient)

    service = LiveWebSearchService(settings=isolated_settings)
    extracted = asyncio.run(service.fetch_url_text("https://lawcommission.gov.np/civil-code"))
    assert extracted is not None
    assert "Section 391 governs house rent increases in Nepal." in extracted
    assert "Menu" not in extracted
    assert "console.log" not in extracted

