"""Hybrid RAG and Live Web Search endpoints (`/api/v1/rag/search`, `/api/v1/search/web`)."""

from __future__ import annotations

from fastapi import APIRouter, Depends

from app.api.dependencies import get_pipeline
from app.pipeline import WakilRAGPipeline
from app.schemas import RAGSearchRequest, RAGSearchResponse, WebSearchRequest, WebSearchResponse

router = APIRouter(prefix="/api/v1", tags=["Search & RAG"])


@router.post("/rag/search", response_model=RAGSearchResponse)
async def rag_search(
    body: RAGSearchRequest,
    pipeline: WakilRAGPipeline = Depends(get_pipeline),
) -> RAGSearchResponse:
    """Execute hybrid Qdrant + BM25 + Nepglish RRF statutory retrieval."""
    return await pipeline.rag_search(body)


@router.post("/search/web", response_model=WebSearchResponse)
async def web_search(
    body: WebSearchRequest,
    pipeline: WakilRAGPipeline = Depends(get_pipeline),
) -> WebSearchResponse:
    """Execute live Nepal legal web search (Tavily primary with DuckDuckGo fallback)."""
    return await pipeline.search_web(body)
