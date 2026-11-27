"""Grounded Nepalese legal Q&A and SSE streaming chat endpoints (`/api/v1/chat`, `/api/v1/chat/stream`)."""

from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException, status
from sse_starlette.sse import EventSourceResponse

from app.api.dependencies import get_pipeline, raise_for_llm_error
from app.llm.providers import LLMConfigurationError, LLMProviderError
from app.pipeline import WakilRAGPipeline
from app.schemas import ChatRequest, ChatResponse

router = APIRouter(prefix="/api/v1", tags=["Legal Chat"])


@router.post("/chat", response_model=ChatResponse)
async def legal_chat(
    body: ChatRequest,
    pipeline: WakilRAGPipeline = Depends(get_pipeline),
) -> ChatResponse:
    """Answer a Nepalese legal query using Hybrid RAG, optional live web search, and any configured LLM."""
    try:
        return await pipeline.chat(body)
    except (LLMConfigurationError, LLMProviderError) as exc:
        raise_for_llm_error(exc)
    except ValueError as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc


@router.post("/chat/stream")
async def legal_chat_stream(
    body: ChatRequest,
    pipeline: WakilRAGPipeline = Depends(get_pipeline),
) -> EventSourceResponse:
    """Stream grounded legal answers as SSE events: `meta`, `token`, and `done`."""
    try:
        generator = pipeline.chat_stream(body)
        # Prime the generator through the initial `meta` event so credential/validation failures
        # return clean HTTP 400/502 JSON responses instead of failing mid-SSE handshake.
        first_event = await anext(generator)
    except StopAsyncIteration as exc:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Chat stream produced no events.",
        ) from exc
    except (LLMConfigurationError, LLMProviderError) as exc:
        raise_for_llm_error(exc)
    except ValueError as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc

    async def _event_stream():
        yield first_event
        async for event in generator:
            yield event

    return EventSourceResponse(_event_stream(), media_type="text/event-stream")
