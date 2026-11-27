"""Live web search subsystem for WakilAI (Tavily primary + DDGS fallback)."""

from app.search.web_search import (
    NEPAL_LEGAL_DOMAINS,
    LiveWebSearchService,
    should_run_web_search,
)

__all__ = [
    "LiveWebSearchService",
    "NEPAL_LEGAL_DOMAINS",
    "should_run_web_search",
]
