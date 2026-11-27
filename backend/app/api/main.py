"""FastAPI application factory, lifespan management, CORS middleware, and root/health routes."""

from __future__ import annotations

from contextlib import asynccontextmanager
from typing import AsyncIterator, Optional

from fastapi import Depends, FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.api.dependencies import get_pipeline
from app.api.routes_chat import router as chat_router
from app.api.routes_ingest import router as ingest_router
from app.api.routes_models import router as models_router
from app.api.routes_openai import router as openai_router
from app.api.routes_rag import router as rag_router
from app.config import Settings, get_settings
from app.firebase_auth import verify_firebase_if_required
from app.pipeline import WakilRAGPipeline
from app.schemas import HealthResponse

OPENAPI_TAGS = [
    {"name": "Health", "description": "Service metadata, subsystem readiness, and OpenAPI entry points."},
    {"name": "Ingestion & Corpus", "description": "Upload, extract, chunk, bootstrap, and manage legal documents."},
    {"name": "Search & RAG", "description": "Hybrid Qdrant + BM25 + Nepglish retrieval and live legal web search."},
    {"name": "Legal Chat", "description": "Grounded Nepalese legal Q&A and Server-Sent Events streaming."},
    {"name": "Models", "description": "Live KiloAI, Gemini, and OpenAI-compatible model catalog and testing."},
    {"name": "OpenAI Compatible", "description": "Drop-in `/v1/models` and `/v1/chat/completions` gateway with RAG."},
]


def create_app(
    settings: Optional[Settings] = None,
    *,
    pipeline: Optional[WakilRAGPipeline] = None,
) -> FastAPI:
    """Construct and configure the WakilAI FastAPI application."""
    cfg = settings or get_settings()

    @asynccontextmanager
    async def lifespan(fastapi_app: FastAPI) -> AsyncIterator[None]:
        active_pipeline = pipeline or WakilRAGPipeline(settings=cfg)
        owns_pipeline = pipeline is None
        await active_pipeline.startup()
        fastapi_app.state.pipeline = active_pipeline
        fastapi_app.state.settings = cfg
        try:
            yield
        finally:
            if owns_pipeline:
                await active_pipeline.shutdown()

    fastapi_app = FastAPI(
        title=cfg.app_name,
        version=cfg.app_version,
        description=(
            "Nepalese Legal Hybrid RAG (Qdrant + BM25 + Nepglish RRF + Live Web Search) "
            "and Universal AI Model Gateway (KiloAI, Google Gemini, and OpenAI-compatible endpoints)."
        ),
        openapi_tags=OPENAPI_TAGS,
        lifespan=lifespan,
    )

    fastapi_app.add_middleware(
        CORSMiddleware,
        allow_origins=cfg.cors_origins,
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )

    @fastapi_app.get("/", tags=["Health"])
    async def root() -> dict[str, str]:
        """Root service discovery response."""
        return {
            "name": cfg.app_name,
            "version": cfg.app_version,
            "status": "ok",
            "docs_url": "/docs",
            "health_url": "/health",
            "openai_base_url": "/v1",
        }

    @fastapi_app.get("/health", response_model=HealthResponse, tags=["Health"])
    async def health(
        active_pipeline: WakilRAGPipeline = Depends(get_pipeline),
    ) -> HealthResponse:
        """Report Qdrant, BM25, embedding backend, and AI provider readiness."""
        return await active_pipeline.health()

    auth_deps = [Depends(verify_firebase_if_required)]
    fastapi_app.include_router(ingest_router, dependencies=auth_deps)
    fastapi_app.include_router(rag_router, dependencies=auth_deps)
    fastapi_app.include_router(chat_router, dependencies=auth_deps)
    fastapi_app.include_router(models_router, dependencies=auth_deps)
    fastapi_app.include_router(openai_router, dependencies=auth_deps)

    return fastapi_app


app = create_app()
