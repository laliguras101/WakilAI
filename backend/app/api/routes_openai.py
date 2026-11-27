"""OpenAI-compatible `/v1` drop-in endpoints (`GET /v1/models`, `POST /v1/chat/completions`)."""

from __future__ import annotations

from typing import Any

from fastapi import APIRouter, Depends, HTTPException, Request, status
from fastapi.responses import StreamingResponse

from app.api.dependencies import get_pipeline, raise_for_llm_error
from app.llm.providers import LLMConfigurationError, LLMProviderError
from app.pipeline import WakilRAGPipeline
from app.schemas import OpenAIChatCompletionRequest, OpenAIChatCompletionResponse

router = APIRouter(prefix="/v1", tags=["OpenAI Compatible"])


@router.get("/models")
async def openai_list_models(
    pipeline: WakilRAGPipeline = Depends(get_pipeline),
) -> dict[str, Any]:
    """Return an OpenAI-compatible model catalog exposing `kilo/*`, `gemini/*`, and custom models."""
    models = await pipeline.list_models()
    data = []
    for item in models:
        prefixed_id = (
            f"{item.provider}/{item.id}"
            if item.provider in ("kilo", "gemini") and not item.id.startswith(f"{item.provider}/")
            else item.id
        )
        data.append(
            {
                "id": prefixed_id,
                "object": "model",
                "created": 0,
                "owned_by": item.provider,
                "name": item.name,
                "is_free": item.is_free,
                "available": item.available,
                "context_length": item.context_length,
            }
        )
    return {"object": "list", "data": data}


@router.post("/chat/completions", response_model=OpenAIChatCompletionResponse)
async def openai_chat_completions(
    body: OpenAIChatCompletionRequest,
    request: Request,
    pipeline: WakilRAGPipeline = Depends(get_pipeline),
) -> Any:
    """OpenAI drop-in chat completions endpoint injecting Wakil Hybrid RAG + Live Web Search."""
    headers = dict(request.headers)
    try:
        if body.stream:
            stream_iter = await pipeline.prepare_openai_stream(body, headers=headers)
            return StreamingResponse(
                stream_iter,
                media_type="text/event-stream",
                headers={
                    "Cache-Control": "no-cache",
                    "Connection": "keep-alive",
                    "X-Accel-Buffering": "no",
                },
            )
        return await pipeline.openai_chat_completion(body, headers=headers)
    except (LLMConfigurationError, LLMProviderError) as exc:
        raise_for_llm_error(exc)
    except ValueError as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc
