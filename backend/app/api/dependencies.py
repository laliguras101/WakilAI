"""Shared FastAPI dependencies and exception translation helpers."""

from __future__ import annotations

from fastapi import HTTPException, Request, status

from app.llm.providers import LLMConfigurationError, LLMProviderError
from app.pipeline import WakilRAGPipeline


def get_pipeline(request: Request) -> WakilRAGPipeline:
    """Retrieve the shared `WakilRAGPipeline` bound to `app.state`."""
    pipeline = getattr(request.app.state, "pipeline", None)
    if pipeline is None:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="WakilRAGPipeline is not initialized yet.",
        )
    return pipeline


def raise_for_llm_error(exc: Exception) -> None:
    """Translate sanitized LLM errors into clean HTTP responses."""
    if isinstance(exc, LLMConfigurationError):
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc
    if isinstance(exc, LLMProviderError):
        raise HTTPException(status_code=status.HTTP_502_BAD_GATEWAY, detail=str(exc)) from exc
    raise exc
