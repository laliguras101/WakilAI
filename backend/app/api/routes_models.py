"""AI model catalog and provider connectivity test endpoints (`/api/v1/models`)."""

from __future__ import annotations

from typing import Optional

from fastapi import APIRouter, Body, Depends, Query
from pydantic import BaseModel, Field

from app.api.dependencies import get_pipeline, raise_for_llm_error
from app.llm.providers import LLMConfigurationError, LLMProviderError
from app.pipeline import WakilRAGPipeline
from app.schemas import LLMOverride, ModelInfo

router = APIRouter(prefix="/api/v1", tags=["Models"])


class ModelListResponse(BaseModel):
    """Catalog of discovered AI models across KiloAI, Gemini, and OpenAI-compatible gateways."""

    total: int = 0
    models: list[ModelInfo] = Field(default_factory=list)


class ModelTestResponse(BaseModel):
    """Connectivity test summary for an AI provider/model route."""

    status: str
    provider: str
    model: str
    reply: str
    latency_ms: float
    usage: dict[str, int] = Field(default_factory=dict)


@router.get("/models", response_model=ModelListResponse)
async def list_available_models(
    provider: Optional[str] = Query(
        default=None,
        description="Optional filter: `kilo`, `gemini`, or `openai_compatible`.",
    ),
    free_only: bool = Query(
        default=False,
        description="When true, return only free-tier models (e.g., Kilo free models).",
    ),
    refresh: bool = Query(
        default=False,
        description="Force refresh the cached live KiloAI model catalog.",
    ),
    pipeline: WakilRAGPipeline = Depends(get_pipeline),
) -> ModelListResponse:
    """List available models across KiloAI (live catalog), Gemini, and OpenAI-compatible gateways."""
    models = await pipeline.list_models(
        provider=provider,
        free_only=free_only,
        force_refresh=refresh,
    )
    return ModelListResponse(total=len(models), models=models)


@router.post("/models/test", response_model=ModelTestResponse)
async def test_model_connection(
    body: Optional[LLMOverride] = Body(default=None),
    pipeline: WakilRAGPipeline = Depends(get_pipeline),
) -> ModelTestResponse:
    """Send a quick ping completion to verify credentials and connectivity for an AI model."""
    try:
        result = await pipeline.llm_router.test_connection(llm=body)
        return ModelTestResponse.model_validate(result)
    except (LLMConfigurationError, LLMProviderError) as exc:
        raise_for_llm_error(exc)
