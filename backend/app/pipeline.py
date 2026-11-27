"""End-to-end WakilAI orchestration pipeline uniting ingestion, hybrid RAG, web search, and LLM routing."""

from __future__ import annotations

import inspect
import json
import time
import uuid
from dataclasses import dataclass
from pathlib import Path
from typing import Any, AsyncIterator, Literal, Mapping, Optional, Sequence

from app.config import Settings, get_settings
from app.ingestion.pipeline import IngestionPipeline
from app.llm.prompts import build_rag_messages
from app.llm.providers import (
    LLMConfigurationError,
    LLMProviderError,
    LLMRouter,
    sanitize_error_message,
)
from app.rag.hybrid_retriever import HybridRetriever
from app.schemas import (
    CategoryEnum,
    ChatMessageItem,
    ChatRequest,
    ChatResponse,
    CorpusDocumentMeta,
    HealthResponse,
    IngestPathRequest,
    IngestResponse,
    IngestUrlRequest,
    LLMOverride,
    ModelInfo,
    OpenAIChatCompletionChoice,
    OpenAIChatCompletionRequest,
    OpenAIChatCompletionResponse,
    OpenAIChatMessage,
    OpenAIUsage,
    RAGSearchRequest,
    RAGSearchResponse,
    RetrievedChunk,
    SearchFilter,
    WebSearchMode,
    WebSearchRequest,
    WebSearchResponse,
    WebSearchResult,
)
from app.search.web_search import LiveWebSearchService, should_run_web_search

_DUMMY_BEARER_TOKENS: frozenset[str] = frozenset(
    {
        "local",
        "local-or-provider-key",
        "not-needed",
        "none",
        "null",
        "dummy",
        "test",
        "wakil",
        "wakil-local",
        "ollama",
        "sk-dummy",
        "changeme",
    }
)


async def _maybe_await(value: Any) -> Any:
    """Await coroutine/awaitable values transparently while supporting sync implementations."""
    if inspect.isawaitable(value):
        return await value
    return value


def _call_with_supported_kwargs(func: Any, **kwargs: Any) -> Any:
    """Invoke `func` passing only keyword arguments accepted by its signature (unless `**kwargs`)."""
    sig = inspect.signature(func)
    params = sig.parameters
    if any(p.kind == inspect.Parameter.VAR_KEYWORD for p in params.values()):
        return func(**kwargs)
    filtered = {k: v for k, v in kwargs.items() if k in params}
    return func(**filtered)


def _parse_bool_header(value: Optional[str]) -> Optional[bool]:
    if value is None:
        return None
    norm = value.strip().lower()
    if norm in {"1", "true", "yes", "on"}:
        return True
    if norm in {"0", "false", "no", "off"}:
        return False
    return None


def _parse_web_mode_header(value: Optional[str]) -> Optional[WebSearchMode]:
    if value is None:
        return None
    norm = value.strip().lower()
    for mode in WebSearchMode:
        if mode.value == norm:
            return mode
    return None


@dataclass(slots=True)
class PreparedChatContext:
    """Intermediate grounded prompt assembly state shared by sync and streaming chat flows."""

    messages: list[dict[str, str]]
    resolved_language: Literal["EN", "NP"]
    used_rag: bool
    used_web_search: bool
    citations: list[RetrievedChunk]
    web_results: list[WebSearchResult]


class WakilRAGPipeline:
    """Single shared facade tying together Hybrid RAG, Live Web Search, Ingestion, and LLMRouter."""

    def __init__(
        self,
        settings: Optional[Settings] = None,
        *,
        retriever: Optional[HybridRetriever] = None,
        web_search: Optional[LiveWebSearchService] = None,
        ingestion: Optional[IngestionPipeline] = None,
        llm_router: Optional[LLMRouter] = None,
    ) -> None:
        self.settings = settings or get_settings()
        self.settings.ensure_data_dirs()
        self.retriever = retriever or HybridRetriever(settings=self.settings)
        self.web_search = web_search or LiveWebSearchService(settings=self.settings)
        self.ingestion = ingestion or IngestionPipeline(
            settings=self.settings,
            retriever=self.retriever,
        )
        self.llm_router = llm_router or LLMRouter(settings=self.settings)

    async def startup(self) -> None:
        """Perform lightweight startup initialization."""
        self.settings.ensure_data_dirs()

    async def shutdown(self) -> None:
        """Close LLM HTTP clients, web search resources, and Qdrant/BM25 handles cleanly."""
        for obj in (self.llm_router, self.web_search, self.retriever):
            if obj is None:
                continue
            for method_name in ("aclose", "close"):
                method = getattr(obj, method_name, None)
                if callable(method):
                    try:
                        await _maybe_await(method())
                    except Exception:
                        pass
                    break

    # ------------------------------------------------------------------
    # Health & Corpus Management
    # ------------------------------------------------------------------

    async def health(self) -> HealthResponse:
        """Collect subsystem readiness across Qdrant, BM25, corpus manifest, and LLM providers."""
        stats: dict[str, Any] = {}
        try:
            raw_stats = await _maybe_await(self.retriever.get_stats())
            if isinstance(raw_stats, Mapping):
                stats = dict(raw_stats)
        except Exception:
            stats = {"qdrant_connected": False}

        corpus_count = 0
        try:
            docs = await self.list_corpus()
            corpus_count = len(docs)
        except Exception:
            corpus_count = 0

        try:
            default_route = self.llm_router.resolve_route()
            llm_provider = default_route.provider
            llm_model = default_route.model
        except Exception:
            llm_provider = str(self.settings.default_llm_provider)
            llm_model = self.settings.default_kilo_model

        qdrant_connected = bool(stats.get("qdrant_connected", False))
        return HealthResponse(
            status="ok" if qdrant_connected else "degraded",
            app_name=self.settings.app_name,
            version=self.settings.app_version,
            qdrant_connected=qdrant_connected,
            qdrant_mode=str(stats.get("qdrant_mode") or ("remote" if self.settings.qdrant_url else "embedded")),
            qdrant_collection=str(stats.get("qdrant_collection") or ""),
            qdrant_points=int(stats.get("qdrant_points", 0) or 0),
            bm25_docs=int(stats.get("bm25_docs", 0) or 0),
            corpus_documents=corpus_count,
            embedding_provider=str(stats.get("embedding_provider") or self.settings.embedding_provider),
            embedding_model=str(stats.get("embedding_model") or self.settings.embedding_model),
            embedding_dim=int(stats.get("embedding_dim") or self.settings.embedding_dim),
            llm_default_provider=llm_provider,
            llm_default_model=llm_model,
            tavily_configured=bool(self.settings.tavily_api_key),
            gemini_configured=bool(self.settings.gemini_api_key),
            kilo_configured=bool(self.settings.kilocode_api_key),
            openai_configured=bool(self.settings.openai_api_key or self.settings.openai_base_url),
        )

    async def list_corpus(self) -> list[CorpusDocumentMeta]:
        """Return all indexed statutory documents tracked in the manifest."""
        docs = await _maybe_await(self.ingestion.list_documents())
        result: list[CorpusDocumentMeta] = []
        for item in docs or []:
            if isinstance(item, CorpusDocumentMeta):
                result.append(item)
            elif isinstance(item, Mapping):
                result.append(CorpusDocumentMeta.model_validate(item))
        return result

    async def delete_document(self, doc_id: str) -> dict[str, Any]:
        """Delete a document from manifest, Qdrant, and BM25 stores."""
        outcome = await _maybe_await(self.ingestion.delete_document(doc_id))
        if isinstance(outcome, IngestResponse):
            deleted = outcome.status not in {"not_found", "error"}
            return {
                "deleted": deleted,
                "doc_id": doc_id,
                "status": outcome.status,
                "message": outcome.message,
            }
        if isinstance(outcome, Mapping):
            deleted = bool(outcome.get("deleted", outcome.get("status") not in {"not_found", "error"}))
            return {
                "deleted": deleted,
                "doc_id": doc_id,
                "status": str(outcome.get("status", "deleted" if deleted else "not_found")),
                "message": str(outcome.get("message", "")),
            }
        deleted = bool(outcome)
        return {
            "deleted": deleted,
            "doc_id": doc_id,
            "status": "deleted" if deleted else "not_found",
            "message": f"Document `{doc_id}` deleted." if deleted else f"Document `{doc_id}` not found.",
        }

    # ------------------------------------------------------------------
    # Ingestion Operations
    # ------------------------------------------------------------------

    async def ingest_bytes(
        self,
        *,
        content: bytes,
        file_name: str,
        category: CategoryEnum = CategoryEnum.OTHER,
        act_name: Optional[str] = None,
        language: Optional[str] = None,
        source_url: Optional[str] = None,
        force_reindex: bool = False,
    ) -> IngestResponse:
        """Ingest raw uploaded bytes from multipart uploads."""
        res = await _maybe_await(
            _call_with_supported_kwargs(
                self.ingestion.ingest_bytes,
                content=content,
                file_name=file_name,
                category=category,
                act_name=act_name,
                language=language,
                source_url=source_url,
                force_reindex=force_reindex,
            )
        )
        return res if isinstance(res, IngestResponse) else IngestResponse.model_validate(res)

    async def ingest_path(self, req: IngestPathRequest) -> IngestResponse:
        """Ingest a local file or directory path."""
        target = Path(req.path)
        if not target.exists():
            raise FileNotFoundError(f"Path does not exist: {req.path}")
        if target.is_dir():
            res = await _maybe_await(
                _call_with_supported_kwargs(
                    self.ingestion.ingest_directory,
                    path=target,
                    directory=target,
                    category=req.category,
                    act_name=req.act_name,
                    language=req.language,
                    recursive=req.recursive,
                    force_reindex=req.force_reindex,
                )
            )
        else:
            res = await _maybe_await(
                _call_with_supported_kwargs(
                    self.ingestion.ingest_file,
                    path=target,
                    file_path=target,
                    category=req.category,
                    act_name=req.act_name,
                    language=req.language,
                    force_reindex=req.force_reindex,
                )
            )
        return res if isinstance(res, IngestResponse) else IngestResponse.model_validate(res)

    async def ingest_url(self, req: IngestUrlRequest) -> IngestResponse:
        """Fetch and ingest a statutory PDF or web page by URL."""
        res = await _maybe_await(
            _call_with_supported_kwargs(
                self.ingestion.ingest_url,
                url=req.url,
                title=req.title,
                act_name=req.act_name,
                category=req.category,
                language=req.language,
                force_reindex=req.force_reindex,
            )
        )
        return res if isinstance(res, IngestResponse) else IngestResponse.model_validate(res)

    async def bootstrap_corpus(
        self,
        *,
        source: Optional[str] = None,
        include_all: bool = False,
        force_reindex: bool = False,
    ) -> IngestResponse:
        """Ingest curated or local Nepal statutory corpus."""
        res = await _maybe_await(
            _call_with_supported_kwargs(
                self.ingestion.bootstrap_nepal_corpus,
                retriever=self.retriever,
                source=source,
                source_dir=source,
                include_all=include_all,
                force_reindex=force_reindex,
            )
        )
        return res if isinstance(res, IngestResponse) else IngestResponse.model_validate(res)

    async def reindex_corpus(self) -> IngestResponse:
        """Rebuild Qdrant and BM25 indexes from tracked corpus sources."""
        res = await _maybe_await(_call_with_supported_kwargs(self.ingestion.reindex_all))
        return res if isinstance(res, IngestResponse) else IngestResponse.model_validate(res)

    # ------------------------------------------------------------------
    # Retrieval & Live Web Search
    # ------------------------------------------------------------------

    async def rag_search(self, req: RAGSearchRequest) -> RAGSearchResponse:
        """Run hybrid Qdrant + BM25 + Nepglish retrieval."""
        res = await _maybe_await(
            self.retriever.search(
                query=req.query,
                top_k=req.top_k,
                filters=req.filters,
                use_dense=req.use_dense,
                use_bm25=req.use_bm25,
                min_score=req.min_score,
            )
        )
        if isinstance(res, RAGSearchResponse):
            return res
        return RAGSearchResponse.model_validate(res)

    async def search_web(self, req: WebSearchRequest) -> WebSearchResponse:
        """Execute live web search via Tavily (with DuckDuckGo fallback)."""
        res = await _maybe_await(
            self.web_search.search(
                query=req.query,
                max_results=req.max_results,
                nepal_legal_only=req.nepal_legal_only,
                include_domains=req.include_domains,
                fetch_page_content=req.fetch_page_content,
            )
        )
        if isinstance(res, WebSearchResponse):
            return res
        return WebSearchResponse.model_validate(res)

    # ------------------------------------------------------------------
    # Grounded Chat & OpenAI Drop-In Gateway
    # ------------------------------------------------------------------

    async def _prepare_chat_context(
        self,
        *,
        query: str,
        history: Sequence[ChatMessageItem | OpenAIChatMessage | Mapping[str, str]] = (),
        language: Literal["auto", "EN", "NP"] = "auto",
        top_k: int = 6,
        filters: Optional[SearchFilter] = None,
        use_rag: bool = True,
        web_search: WebSearchMode = WebSearchMode.AUTO,
        web_max_results: int = 4,
        nepal_legal_web_only: bool = True,
        extra_system_instruction: Optional[str] = None,
    ) -> PreparedChatContext:
        citations: list[RetrievedChunk] = []
        used_rag = False
        if use_rag:
            used_rag = True
            rag_resp = await self.rag_search(
                RAGSearchRequest(
                    query=query,
                    top_k=top_k,
                    filters=filters,
                    use_dense=True,
                    use_bm25=True,
                )
            )
            citations = list(rag_resp.results)

        web_results: list[WebSearchResult] = []
        used_web_search = False
        if should_run_web_search(web_search, citations, query):
            web_resp = await self.search_web(
                WebSearchRequest(
                    query=query,
                    max_results=web_max_results,
                    nepal_legal_only=nepal_legal_web_only,
                    fetch_page_content=False,
                )
            )
            web_results = list(web_resp.results)
            used_web_search = True

        messages, resolved_lang = build_rag_messages(
            query,
            chunks=citations,
            web_results=web_results,
            history=history,
            language=language,
            extra_system_instruction=extra_system_instruction,
        )
        return PreparedChatContext(
            messages=messages,
            resolved_language=resolved_lang,
            used_rag=used_rag,
            used_web_search=used_web_search,
            citations=citations,
            web_results=web_results,
        )

    async def chat(self, req: ChatRequest) -> ChatResponse:
        """Execute full grounded RAG + optional web search + LLM completion."""
        t0 = time.perf_counter()
        ctx = await self._prepare_chat_context(
            query=req.query,
            history=req.history,
            language=req.language,
            top_k=req.top_k,
            filters=req.filters,
            use_rag=req.use_rag,
            web_search=req.web_search,
            web_max_results=req.web_max_results,
            nepal_legal_web_only=req.nepal_legal_web_only,
        )
        completion = await self.llm_router.complete(ctx.messages, llm=req.llm)
        latency_ms = round((time.perf_counter() - t0) * 1000, 2)
        return ChatResponse(
            answer=completion.content,
            language=ctx.resolved_language,
            provider=completion.provider,
            model=completion.model,
            used_rag=ctx.used_rag,
            used_web_search=ctx.used_web_search,
            citations=ctx.citations,
            web_results=ctx.web_results,
            usage=completion.usage,
            latency_ms=latency_ms,
        )

    async def chat_stream(self, req: ChatRequest) -> AsyncIterator[dict[str, Any]]:
        """Yield SSE event dictionaries (`meta`, `token`, `done`, or `error`) for `/api/v1/chat/stream`."""
        t0 = time.perf_counter()
        ctx = await self._prepare_chat_context(
            query=req.query,
            history=req.history,
            language=req.language,
            top_k=req.top_k,
            filters=req.filters,
            use_rag=req.use_rag,
            web_search=req.web_search,
            web_max_results=req.web_max_results,
            nepal_legal_web_only=req.nepal_legal_web_only,
        )
        route = self.llm_router.resolve_route(req.llm)
        # Validate credentials before emitting `meta` so missing key errors fail cleanly with HTTP status.
        self.llm_router._validate_route_credentials(route)

        yield {
            "event": "meta",
            "data": json.dumps(
                {
                    "language": ctx.resolved_language,
                    "provider": route.provider,
                    "model": route.model,
                    "used_rag": ctx.used_rag,
                    "used_web_search": ctx.used_web_search,
                    "citations": [c.model_dump(mode="json") for c in ctx.citations],
                    "web_results": [w.model_dump(mode="json") for w in ctx.web_results],
                },
                ensure_ascii=False,
            ),
        }

        answer_parts: list[str] = []
        last_usage: dict[str, int] = {}
        actual_provider = route.provider
        actual_model = route.model
        try:
            async for chunk in self.llm_router.stream(ctx.messages, llm=req.llm):
                actual_provider = chunk.provider or actual_provider
                actual_model = chunk.model or actual_model
                if chunk.delta:
                    answer_parts.append(chunk.delta)
                    yield {
                        "event": "token",
                        "data": json.dumps({"delta": chunk.delta}, ensure_ascii=False),
                    }
                if chunk.usage:
                    last_usage = chunk.usage
        except LLMProviderError as exc:
            yield {
                "event": "error",
                "data": json.dumps({"message": str(exc)}, ensure_ascii=False),
            }
            return
        except Exception as exc:
            safe_msg = sanitize_error_message(exc, self.llm_router._collect_secrets(req.llm))
            yield {
                "event": "error",
                "data": json.dumps({"message": safe_msg}, ensure_ascii=False),
            }
            return

        latency_ms = round((time.perf_counter() - t0) * 1000, 2)
        yield {
            "event": "done",
            "data": json.dumps(
                {
                    "answer": "".join(answer_parts),
                    "language": ctx.resolved_language,
                    "provider": actual_provider,
                    "model": actual_model,
                    "used_rag": ctx.used_rag,
                    "used_web_search": ctx.used_web_search,
                    "usage": last_usage,
                    "latency_ms": latency_ms,
                },
                ensure_ascii=False,
            ),
        }

    # ------------------------------------------------------------------
    # OpenAI `/v1/chat/completions` Translation Helpers
    # ------------------------------------------------------------------

    def _build_openai_context_args(
        self,
        req: OpenAIChatCompletionRequest,
        headers: Optional[Mapping[str, str]] = None,
    ) -> tuple[str, list[OpenAIChatMessage], Optional[str], bool, WebSearchMode, int, LLMOverride]:
        hdrs = {k.lower(): v for k, v in (headers or {}).items()}

        system_notes: list[str] = []
        convo: list[OpenAIChatMessage] = []
        for msg in req.messages:
            if msg.role == "system":
                txt = msg.text_content().strip()
                if txt:
                    system_notes.append(txt)
            elif msg.role in ("user", "assistant"):
                convo.append(msg)

        last_user_idx = -1
        for idx in range(len(convo) - 1, -1, -1):
            if convo[idx].role == "user" and convo[idx].text_content().strip():
                last_user_idx = idx
                break

        if last_user_idx >= 0:
            query = convo[last_user_idx].text_content().strip()
            history = convo[:last_user_idx]
        elif convo:
            query = convo[-1].text_content().strip()
            history = convo[:-1]
        else:
            raise ValueError("At least one non-empty user message is required.")

        use_rag_hdr = _parse_bool_header(hdrs.get("x-wakil-use-rag"))
        use_rag = req.use_rag if req.use_rag is not None else (use_rag_hdr if use_rag_hdr is not None else True)

        web_hdr = _parse_web_mode_header(hdrs.get("x-wakil-web-search"))
        web_search = req.web_search or web_hdr or WebSearchMode.AUTO

        top_k = req.top_k if req.top_k is not None else self.settings.default_top_k
        base_url = (req.base_url or hdrs.get("x-wakil-base-url") or "").strip() or None

        api_key = (req.api_key or hdrs.get("x-wakil-api-key") or "").strip() or None
        if not api_key:
            auth_hdr = hdrs.get("authorization", "")
            if auth_hdr.lower().startswith("bearer "):
                bearer = auth_hdr[7:].strip()
                if bearer and bearer.lower() not in _DUMMY_BEARER_TOKENS:
                    api_key = bearer

        llm_override = LLMOverride(
            model=req.model,
            base_url=base_url,
            api_key=api_key,
            temperature=req.temperature,
            max_tokens=req.max_tokens,
        )
        extra_sys = "\n\n".join(system_notes) if system_notes else None
        return query, history, extra_sys, use_rag, web_search, top_k, llm_override

    async def openai_chat_completion(
        self,
        req: OpenAIChatCompletionRequest,
        *,
        headers: Optional[Mapping[str, str]] = None,
    ) -> OpenAIChatCompletionResponse:
        """Handle non-streaming OpenAI `/v1/chat/completions` with transparent RAG + web grounding."""
        query, history, extra_sys, use_rag, web_search, top_k, llm_override = self._build_openai_context_args(
            req, headers
        )
        ctx = await self._prepare_chat_context(
            query=query,
            history=history,
            language="auto",
            top_k=top_k,
            filters=req.filters,
            use_rag=use_rag,
            web_search=web_search,
            extra_system_instruction=extra_sys,
        )
        completion = await self.llm_router.complete(
            ctx.messages,
            llm=llm_override,
            top_p=req.top_p,
            stop=req.stop,
        )
        usage = OpenAIUsage(
            prompt_tokens=int(completion.usage.get("prompt_tokens", 0)),
            completion_tokens=int(completion.usage.get("completion_tokens", 0)),
            total_tokens=int(completion.usage.get("total_tokens", 0)),
        )
        return OpenAIChatCompletionResponse(
            id=f"chatcmpl-{uuid.uuid4().hex[:24]}",
            created=int(time.time()),
            model=req.model or completion.model,
            choices=[
                OpenAIChatCompletionChoice(
                    index=0,
                    message=OpenAIChatMessage(role="assistant", content=completion.content),
                    finish_reason=completion.finish_reason or "stop",
                )
            ],
            usage=usage,
            wakil_citations=ctx.citations,
            wakil_web_results=ctx.web_results,
        )

    async def prepare_openai_stream(
        self,
        req: OpenAIChatCompletionRequest,
        *,
        headers: Optional[Mapping[str, str]] = None,
    ) -> AsyncIterator[str]:
        """Validate request/credentials, run RAG/web retrieval, and return an OpenAI SSE chunk iterator."""
        query, history, extra_sys, use_rag, web_search, top_k, llm_override = self._build_openai_context_args(
            req, headers
        )
        route = self.llm_router.resolve_route(llm_override)
        self.llm_router._validate_route_credentials(route)

        ctx = await self._prepare_chat_context(
            query=query,
            history=history,
            language="auto",
            top_k=top_k,
            filters=req.filters,
            use_rag=use_rag,
            web_search=web_search,
            extra_system_instruction=extra_sys,
        )

        completion_id = f"chatcmpl-{uuid.uuid4().hex[:24]}"
        created_ts = int(time.time())
        model_label = req.model or route.model

        async def _sse_generator() -> AsyncIterator[str]:
            role_chunk = {
                "id": completion_id,
                "object": "chat.completion.chunk",
                "created": created_ts,
                "model": model_label,
                "choices": [{"index": 0, "delta": {"role": "assistant"}, "finish_reason": None}],
            }
            yield f"data: {json.dumps(role_chunk, ensure_ascii=False)}\n\n"

            sent_finish = False
            try:
                async for chunk in self.llm_router.stream(
                    ctx.messages,
                    llm=llm_override,
                    top_p=req.top_p,
                    stop=req.stop,
                ):
                    if chunk.delta:
                        payload = {
                            "id": completion_id,
                            "object": "chat.completion.chunk",
                            "created": created_ts,
                            "model": model_label,
                            "choices": [
                                {
                                    "index": 0,
                                    "delta": {"content": chunk.delta},
                                    "finish_reason": None,
                                }
                            ],
                        }
                        yield f"data: {json.dumps(payload, ensure_ascii=False)}\n\n"
                    if chunk.finish_reason:
                        sent_finish = True
                        end_payload = {
                            "id": completion_id,
                            "object": "chat.completion.chunk",
                            "created": created_ts,
                            "model": model_label,
                            "choices": [
                                {
                                    "index": 0,
                                    "delta": {},
                                    "finish_reason": chunk.finish_reason,
                                }
                            ],
                        }
                        yield f"data: {json.dumps(end_payload, ensure_ascii=False)}\n\n"
                if not sent_finish:
                    end_payload = {
                        "id": completion_id,
                        "object": "chat.completion.chunk",
                        "created": created_ts,
                        "model": model_label,
                        "choices": [{"index": 0, "delta": {}, "finish_reason": "stop"}],
                    }
                    yield f"data: {json.dumps(end_payload, ensure_ascii=False)}\n\n"
            except Exception as exc:
                safe_msg = sanitize_error_message(exc, self.llm_router._collect_secrets(llm_override))
                err_payload = {"error": {"message": safe_msg, "type": "upstream_error"}}
                yield f"data: {json.dumps(err_payload, ensure_ascii=False)}\n\n"

            yield "data: [DONE]\n\n"

        return _sse_generator()

    async def list_models(
        self,
        *,
        provider: Optional[str] = None,
        free_only: bool = False,
        force_refresh: bool = False,
    ) -> list[ModelInfo]:
        """Return available AI models across all configured gateways."""
        return await self.llm_router.list_models(
            provider=provider,
            free_only=free_only,
            force_refresh=force_refresh,
        )
