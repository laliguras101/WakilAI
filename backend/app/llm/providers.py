"""Model-agnostic LLM router supporting KiloAI, Google Gemini, and any OpenAI-compatible gateway."""

from __future__ import annotations

import asyncio
import inspect
import re
import time
from dataclasses import dataclass, field
from typing import Any, AsyncIterator, Mapping, Optional, Sequence, Union

import httpx
from google import genai
from google.genai import types
from openai import AsyncOpenAI

from app.config import Settings, get_settings
from app.llm.prompts import DEFAULT_LEGAL_TEMPERATURE
from app.schemas import LLMOverride, ModelInfo

_KILO_CATALOG_TTL_SECONDS = 300.0
_SECRET_PATTERNS = (
    re.compile(r"AIza[0-9A-Za-z_\-]{20,}"),
    re.compile(r"sk-[0-9A-Za-z_\-]{12,}"),
    re.compile(r"thk_(?:live|test)_[0-9A-Za-z._\-]{6,}"),
    re.compile(r"eyJ[0-9A-Za-z_\-]{10,}\.[0-9A-Za-z_\-]{10,}\.[0-9A-Za-z_\-]{10,}"),
    re.compile(r"(Bearer\s+)[0-9A-Za-z._\-+/=]{8,}", re.IGNORECASE),
)

# Curated offline fallback catalog when https://api.kilo.ai/api/gateway/models is unreachable.
KILO_FALLBACK_MODELS: tuple[dict[str, Any], ...] = (
    {
        "id": "kilo-auto/free",
        "name": "Kilo Auto Free",
        "is_free": True,
        "context_length": 200000,
        "description": "Automatic free-tier model router on KiloAI Gateway.",
    },
    {
        "id": "nvidia/nemotron-3.5-super-vl:free",
        "name": "NVIDIA Nemotron 3.5 Super VL (Free)",
        "is_free": True,
        "context_length": 262144,
        "description": "Free multimodal reasoning model on KiloAI.",
    },
    {
        "id": "inclusionai/ling-3.2-flash:free",
        "name": "InclusionAI Ling 3.2 Flash (Free)",
        "is_free": True,
        "context_length": 131072,
        "description": "Fast free general model on KiloAI.",
    },
    {
        "id": "openrouter/free",
        "name": "OpenRouter Free Router",
        "is_free": True,
        "context_length": 131072,
        "description": "Free auto-selected OpenRouter model via KiloAI.",
    },
    {
        "id": "nvidia/nemotron-3-ultra-550b-a55b:free",
        "name": "NVIDIA Nemotron 3 Ultra 550B (Free)",
        "is_free": True,
        "context_length": 131072,
        "description": "High-capacity free MoE model on KiloAI.",
    },
)

CURATED_GEMINI_MODELS: tuple[dict[str, Any], ...] = (
    {
        "id": "gemini-3.8-flash",
        "name": "Gemini 3.8 Flash",
        "is_free": False,
        "context_length": 1048576,
        "description": "Latest fast Gemini Flash model for grounded legal RAG.",
    },
    {
        "id": "gemini-3.5-flash",
        "name": "Gemini 3.5 Flash",
        "is_free": False,
        "context_length": 1048576,
        "description": "Fast Gemini 3.5 Flash model for grounded legal analysis.",
    },
    {
        "id": "gemini-3.5-flash-lite",
        "name": "Gemini 3.5 Flash Lite",
        "is_free": False,
        "context_length": 1048576,
        "description": "Ultra-lightweight low-latency Gemini Flash Lite model.",
    },
    {
        "id": "gemini-2.5-flash",
        "name": "Gemini 2.5 Flash",
        "is_free": False,
        "context_length": 1048576,
        "description": "Legacy Gemini 2.5 Flash model (for existing projects).",
    },
    {
        "id": "gemini-2.5-pro",
        "name": "Gemini 2.5 Pro",
        "is_free": False,
        "context_length": 1048576,
        "description": "High-reasoning Gemini Pro model for complex statutory analysis.",
    },
)

_kilo_catalog_lock = asyncio.Lock()
_kilo_catalog_cache: dict[str, Any] = {"ts": 0.0, "models": None}


class LLMProviderError(RuntimeError):
    """Sanitized upstream LLM invocation failure."""


class LLMConfigurationError(LLMProviderError):
    """Raised when required provider credentials or endpoint configuration are missing."""


@dataclass(slots=True)
class ResolvedLLMRoute:
    """Normalized routing decision for a single LLM request."""

    provider: str
    model: str
    base_url: Optional[str]
    api_key: Optional[str] = field(repr=False)
    temperature: float = DEFAULT_LEGAL_TEMPERATURE
    max_tokens: int = 2048


@dataclass(slots=True)
class LLMCompletionResult:
    """Normalized response returned by `LLMRouter.complete`."""

    content: str
    provider: str
    model: str
    usage: dict[str, int] = field(default_factory=dict)
    finish_reason: str = "stop"


@dataclass(slots=True)
class LLMStreamChunk:
    """Single incremental token delta emitted by `LLMRouter.stream`."""

    delta: str
    provider: str
    model: str
    finish_reason: Optional[str] = None
    usage: Optional[dict[str, int]] = None


def sanitize_error_message(
    message: object,
    secrets: Sequence[Optional[str]] = (),
) -> str:
    """Redact API keys and Bearer tokens before returning or logging any error message."""
    text = str(message or "Unknown LLM provider error")
    for secret in secrets:
        if secret and len(secret.strip()) >= 4:
            text = text.replace(secret.strip(), "***REDACTED***")
    for pattern in _SECRET_PATTERNS:
        if pattern.groups:
            text = pattern.sub(r"\1***REDACTED***", text)
        else:
            text = pattern.sub("***REDACTED***", text)
    return text


def _is_kilo_item_free(item: Mapping[str, Any]) -> bool:
    """Detect free-tier KiloAI models from `isFree`, `:free` suffix, or zero pricing."""
    if item.get("isFree") is True or item.get("is_free") is True:
        return True
    model_id = str(item.get("id", "")).strip().lower()
    if model_id.endswith(":free") or model_id in {"kilo-auto/free", "openrouter/free"}:
        return True
    pricing = item.get("pricing")
    if isinstance(pricing, Mapping):
        prompt_cost = str(pricing.get("prompt", "")).strip()
        completion_cost = str(pricing.get("completion", "")).strip()
        if prompt_cost in {"0", "0.0", "0.00"} and completion_cost in {"0", "0.0", "0.00"}:
            return True
    return False


async def list_kilo_models(
    *,
    free_only: bool = False,
    force_refresh: bool = False,
    settings: Optional[Settings] = None,
) -> list[ModelInfo]:
    """Fetch and cache the live KiloAI model catalog with graceful offline fallback."""
    cfg = settings or get_settings()
    now = time.monotonic()

    async with _kilo_catalog_lock:
        cached_models = _kilo_catalog_cache.get("models")
        cached_ts = float(_kilo_catalog_cache.get("ts") or 0.0)
        if not force_refresh and cached_models is not None and (now - cached_ts) < _KILO_CATALOG_TTL_SECONDS:
            models = list(cached_models)
        else:
            models = await _fetch_kilo_catalog(cfg)
            _kilo_catalog_cache["models"] = models
            _kilo_catalog_cache["ts"] = time.monotonic()

    available = bool(cfg.kilocode_api_key)
    normalized: list[ModelInfo] = []
    for item in models:
        is_free = bool(item.is_free)
        if free_only and not is_free:
            continue
        normalized.append(
            item.model_copy(
                update={
                    "available": available,
                    "base_url": cfg.kilo_base_url,
                }
            )
        )
    return normalized


async def _fetch_kilo_catalog(cfg: Settings) -> list[ModelInfo]:
    """Retrieve models from KiloAI `/models` endpoint, falling back offline on failure."""
    url = f"{cfg.kilo_base_url.rstrip('/')}/models"
    try:
        async with httpx.AsyncClient(timeout=10.0) as client:
            resp = await client.get(url)
            resp.raise_for_status()
            payload = resp.json()
        raw_items = payload.get("data", payload) if isinstance(payload, dict) else payload
        if not isinstance(raw_items, list) or not raw_items:
            raise ValueError("Empty Kilo catalog payload")

        parsed: list[ModelInfo] = []
        for entry in raw_items:
            if not isinstance(entry, Mapping) or not entry.get("id"):
                continue
            model_id = str(entry["id"])
            ctx_len = entry.get("context_length")
            if ctx_len is None and isinstance(entry.get("top_provider"), Mapping):
                ctx_len = entry["top_provider"].get("context_length")
            parsed.append(
                ModelInfo(
                    id=model_id,
                    provider="kilo",
                    name=str(entry.get("name") or model_id),
                    is_free=_is_kilo_item_free(entry),
                    context_length=int(ctx_len) if isinstance(ctx_len, (int, float)) else None,
                    description=str(entry.get("description") or "") or None,
                    supports_streaming=True,
                    available=bool(cfg.kilocode_api_key),
                    base_url=cfg.kilo_base_url,
                )
            )
        if parsed:
            return parsed
    except Exception:
        pass

    return [
        ModelInfo(
            id=item["id"],
            provider="kilo",
            name=item["name"],
            is_free=bool(item["is_free"]),
            context_length=item.get("context_length"),
            description=item.get("description"),
            supports_streaming=True,
            available=bool(cfg.kilocode_api_key),
            base_url=cfg.kilo_base_url,
        )
        for item in KILO_FALLBACK_MODELS
    ]


def _normalize_message_list(messages: Sequence[Mapping[str, Any]]) -> list[dict[str, str]]:
    """Normalize role/content dicts cleanly for OpenAI-compatible and Gemini adapters."""
    cleaned: list[dict[str, str]] = []
    for msg in messages:
        role = str(msg.get("role", "user")).strip().lower()
        content = msg.get("content", "")
        if isinstance(content, list):
            parts = [
                str(p.get("text", ""))
                for p in content
                if isinstance(p, Mapping) and p.get("type") == "text"
            ]
            text = "\n".join(parts)
        else:
            text = str(content or "")
        if role in ("system", "user", "assistant", "tool"):
            cleaned.append({"role": role, "content": text})
    return cleaned


def _split_gemini_messages(
    messages: Sequence[Mapping[str, str]],
) -> tuple[Optional[str], list[types.Content]]:
    """Separate system instruction from user/model turns for `google-genai`."""
    system_parts: list[str] = []
    contents: list[types.Content] = []
    for msg in messages:
        role = msg["role"]
        text = msg["content"]
        if role == "system":
            if text.strip():
                system_parts.append(text.strip())
            continue
        gemini_role = "model" if role == "assistant" else "user"
        contents.append(
            types.Content(
                role=gemini_role,
                parts=[types.Part.from_text(text=text)],
            )
        )
    if not contents:
        contents.append(
            types.Content(
                role="user",
                parts=[types.Part.from_text(text=" ")],
            )
        )
    system_instruction = "\n\n".join(system_parts) if system_parts else None
    return system_instruction, contents


class LLMRouter:
    """Routes completion and streaming requests across KiloAI, Gemini, and OpenAI-compatible gateways."""

    def __init__(self, settings: Optional[Settings] = None) -> None:
        self.settings = settings or get_settings()
        self._openai_clients: dict[tuple[str, str], AsyncOpenAI] = {}

    async def aclose(self) -> None:
        """Close cached async OpenAI HTTP clients cleanly."""
        for client in self._openai_clients.values():
            try:
                await client.close()
            except Exception:
                pass
        self._openai_clients.clear()

    def _collect_secrets(self, override: Optional[LLMOverride] = None) -> list[Optional[str]]:
        return [
            self.settings.kilocode_api_key,
            self.settings.gemini_api_key,
            self.settings.openai_api_key,
            self.settings.tavily_api_key,
            self.settings.qdrant_api_key,
            override.api_key if override else None,
        ]

    def resolve_route(
        self,
        override: Optional[LLMOverride] = None,
        *,
        temperature: Optional[float] = None,
        max_tokens: Optional[int] = None,
    ) -> ResolvedLLMRoute:
        """Determine concrete provider, model, gateway base URL, and credentials."""
        req_provider = (override.provider.strip().lower() if override and override.provider else None)
        req_model = (override.model.strip() if override and override.model else None)
        req_base_url = (override.base_url.strip().rstrip("/") if override and override.base_url else None)
        req_key = (override.api_key.strip() if override and override.api_key else None)

        resolved_temp = (
            override.temperature
            if override and override.temperature is not None
            else (temperature if temperature is not None else self.settings.default_temperature)
        )
        resolved_max_tokens = (
            override.max_tokens
            if override and override.max_tokens is not None
            else (max_tokens if max_tokens is not None else self.settings.default_max_tokens)
        )

        # Normalize aliases
        if req_provider in ("openai", "custom", "ollama", "openrouter"):
            req_provider = "openai_compatible"

        # If caller explicitly passed a custom base_url without setting provider to kilo, route via openai_compatible.
        if req_base_url and (not req_provider or req_provider == "auto"):
            req_provider = "openai_compatible"

        # Parse explicit model prefixes like `kilo/kilo-auto/free`, `gemini/gemini-2.5-flash`, `openai/gpt-4o-mini`.
        # Preserve vendor prefixes like `openai/gpt-4o-mini` when targeting custom gateways (e.g., OpenRouter).
        if req_model:
            lowered = req_model.lower()
            if lowered.startswith("openai_compatible/"):
                req_provider = req_provider if req_provider and req_provider != "auto" else "openai_compatible"
                req_model = req_model[len("openai_compatible/") :]
            elif not req_base_url:
                if lowered.startswith("kilo/") and req_provider in (None, "auto", "kilo"):
                    req_provider = "kilo"
                    req_model = req_model[5:]
                elif lowered.startswith("gemini/") and req_provider in (None, "auto", "gemini"):
                    req_provider = "gemini"
                    req_model = req_model[7:]
                elif lowered.startswith("openai/") and req_provider in (None, "auto"):
                    req_provider = "openai_compatible"
                    req_model = req_model[7:]

        # Infer provider from model naming conventions when still `auto` or unset.
        if not req_provider or req_provider == "auto":
            if req_model:
                lowered = req_model.lower()
                if lowered.startswith("kilo-auto/") or lowered.endswith(":free") or lowered == "openrouter/free":
                    req_provider = "kilo"
                elif lowered.startswith("gemini-"):
                    req_provider = "gemini"

        if not req_provider or req_provider == "auto":
            default_prov = self.settings.default_llm_provider
            if default_prov != "auto":
                req_provider = default_prov
            elif self.settings.kilocode_api_key:
                req_provider = "kilo"
            elif self.settings.gemini_api_key:
                req_provider = "gemini"
            elif self.settings.openai_api_key or self.settings.openai_base_url:
                req_provider = "openai_compatible"
            else:
                req_provider = "kilo"

        if req_provider == "kilo":
            return ResolvedLLMRoute(
                provider="kilo",
                model=req_model or self.settings.default_kilo_model,
                base_url=req_base_url or self.settings.kilo_base_url,
                api_key=req_key or self.settings.kilocode_api_key,
                temperature=resolved_temp,
                max_tokens=resolved_max_tokens,
            )

        if req_provider == "gemini":
            return ResolvedLLMRoute(
                provider="gemini",
                model=req_model or self.settings.default_gemini_model,
                base_url=None,
                api_key=req_key or self.settings.gemini_api_key,
                temperature=resolved_temp,
                max_tokens=resolved_max_tokens,
            )

        if req_provider == "openai_compatible":
            return ResolvedLLMRoute(
                provider="openai_compatible",
                model=req_model or self.settings.default_openai_model,
                base_url=req_base_url or self.settings.openai_base_url,
                api_key=req_key or self.settings.openai_api_key,
                temperature=resolved_temp,
                max_tokens=resolved_max_tokens,
            )

        raise LLMConfigurationError(f"Unsupported LLM provider: {req_provider}")

    def _get_openai_client(self, base_url: Optional[str], api_key: str) -> AsyncOpenAI:
        cache_key = (base_url or "", api_key)
        client = self._openai_clients.get(cache_key)
        if client is None:
            kwargs: dict[str, Any] = {
                "api_key": api_key,
                "timeout": self.settings.llm_timeout,
            }
            if base_url:
                kwargs["base_url"] = base_url
            client = AsyncOpenAI(**kwargs)
            self._openai_clients[cache_key] = client
        return client

    def _validate_route_credentials(self, route: ResolvedLLMRoute) -> str:
        if route.provider == "kilo":
            if not route.api_key:
                raise LLMConfigurationError(
                    "Missing KiloAI API key. Set KILOCODE_API_KEY in backend/.env or supply an API key per request."
                )
            return route.api_key
        if route.provider == "gemini":
            if not route.api_key:
                raise LLMConfigurationError(
                    "Missing Gemini API key. Set GEMINI_API_KEY in backend/.env or supply an API key per request."
                )
            return route.api_key
        if route.provider == "openai_compatible":
            if route.api_key:
                return route.api_key
            # Local OpenAI-compatible gateways (Ollama, LM Studio, vLLM) often accept dummy keys.
            if route.base_url:
                return "not-needed"
            raise LLMConfigurationError(
                "Missing OpenAI-compatible credentials. Set OPENAI_API_KEY or supply base_url + api_key per request."
            )
        raise LLMConfigurationError(f"Unsupported provider: {route.provider}")

    def _is_unpinned_auto(self, override: Optional[LLMOverride]) -> bool:
        """True when neither settings nor caller pinned a specific provider, model, or base_url."""
        if self.settings.default_llm_provider != "auto":
            return False
        if override is None:
            return True
        return not (override.provider or override.model or override.base_url)

    def _candidate_routes(
        self,
        override: Optional[LLMOverride] = None,
        *,
        temperature: Optional[float] = None,
        max_tokens: Optional[int] = None,
    ) -> list[ResolvedLLMRoute]:
        """Return primary route, plus configured fallbacks only when request is unpinned `auto`."""
        primary = self.resolve_route(override, temperature=temperature, max_tokens=max_tokens)
        if not self._is_unpinned_auto(override):
            return [primary]

        routes: list[ResolvedLLMRoute] = []
        seen: set[tuple[str, str, Optional[str]]] = set()

        def _push(route: ResolvedLLMRoute) -> None:
            key = (route.provider, route.model, route.base_url)
            if key not in seen:
                seen.add(key)
                routes.append(route)

        _push(primary)
        req_key = override.api_key.strip() if override and override.api_key else None
        if self.settings.kilocode_api_key:
            _push(
                ResolvedLLMRoute(
                    provider="kilo",
                    model=self.settings.default_kilo_model,
                    base_url=self.settings.kilo_base_url,
                    api_key=req_key or self.settings.kilocode_api_key,
                    temperature=primary.temperature,
                    max_tokens=primary.max_tokens,
                )
            )
        if self.settings.gemini_api_key:
            for gm in (
                self.settings.default_gemini_model,
                "gemini-3.5-flash-lite",
                "gemini-3.8-flash",
            ):
                _push(
                    ResolvedLLMRoute(
                        provider="gemini",
                        model=gm,
                        base_url=None,
                        api_key=req_key or self.settings.gemini_api_key,
                        temperature=primary.temperature,
                        max_tokens=primary.max_tokens,
                    )
                )
        if self.settings.openai_api_key or self.settings.openai_base_url:
            _push(
                ResolvedLLMRoute(
                    provider="openai_compatible",
                    model=self.settings.default_openai_model,
                    base_url=self.settings.openai_base_url,
                    api_key=req_key or self.settings.openai_api_key,
                    temperature=primary.temperature,
                    max_tokens=primary.max_tokens,
                )
            )
        return routes

    async def complete(
        self,
        messages: Sequence[Mapping[str, Any]],
        *,
        llm: Optional[LLMOverride] = None,
        temperature: Optional[float] = None,
        max_tokens: Optional[int] = None,
        top_p: Optional[float] = None,
        stop: Optional[Union[str, list[str]]] = None,
    ) -> LLMCompletionResult:
        """Run a non-streaming chat completion against the resolved provider (with auto-failover if unpinned)."""
        routes = self._candidate_routes(llm, temperature=temperature, max_tokens=max_tokens)
        normalized_messages = _normalize_message_list(messages)
        secrets = self._collect_secrets(llm)

        last_error: Optional[Exception] = None
        for idx, route in enumerate(routes):
            try:
                return await self._complete_route(
                    route,
                    normalized_messages,
                    secrets=secrets,
                    top_p=top_p,
                    stop=stop,
                )
            except (LLMConfigurationError, LLMProviderError) as exc:
                last_error = exc
                if idx == len(routes) - 1:
                    raise
        assert last_error is not None
        raise last_error

    async def _complete_route(
        self,
        route: ResolvedLLMRoute,
        normalized_messages: list[dict[str, str]],
        *,
        secrets: Sequence[Optional[str]],
        top_p: Optional[float],
        stop: Optional[Union[str, list[str]]],
    ) -> LLMCompletionResult:
        """Execute a non-streaming completion on a single concrete `ResolvedLLMRoute`."""
        api_key = self._validate_route_credentials(route)

        if route.provider in ("kilo", "openai_compatible"):
            client = self._get_openai_client(route.base_url, api_key)
            kwargs: dict[str, Any] = {
                "model": route.model,
                "messages": normalized_messages,
                "temperature": route.temperature,
                "max_tokens": route.max_tokens,
                "stream": False,
            }
            if top_p is not None:
                kwargs["top_p"] = top_p
            if stop is not None:
                kwargs["stop"] = stop

            try:
                response = await client.chat.completions.create(**kwargs)
            except Exception as exc:
                safe_msg = sanitize_error_message(exc, secrets)
                raise LLMProviderError(f"{route.provider} completion failed: {safe_msg}") from exc

            choice = response.choices[0] if getattr(response, "choices", None) else None
            content = ""
            finish_reason = "stop"
            if choice is not None:
                msg_obj = getattr(choice, "message", None)
                content = str(getattr(msg_obj, "content", "") or "")
                finish_reason = str(getattr(choice, "finish_reason", None) or "stop")
            usage_obj = getattr(response, "usage", None)
            usage = {
                "prompt_tokens": int(getattr(usage_obj, "prompt_tokens", 0) or 0),
                "completion_tokens": int(getattr(usage_obj, "completion_tokens", 0) or 0),
                "total_tokens": int(getattr(usage_obj, "total_tokens", 0) or 0),
            }
            return LLMCompletionResult(
                content=content,
                provider=route.provider,
                model=route.model,
                usage=usage,
                finish_reason=finish_reason,
            )

        # Gemini via official google-genai SDK
        system_instruction, contents = _split_gemini_messages(normalized_messages)
        stop_sequences = [stop] if isinstance(stop, str) else list(stop) if stop else None
        config = types.GenerateContentConfig(
            system_instruction=system_instruction,
            temperature=route.temperature,
            max_output_tokens=route.max_tokens,
            top_p=top_p,
            stop_sequences=stop_sequences,
        )
        try:
            client = genai.Client(
                api_key=api_key,
                http_options=types.HttpOptions(
                    timeout=int(self.settings.llm_timeout * 1000),
                    retry_options=types.HttpRetryOptions(attempts=2, initial_delay=0.5, max_delay=2.0),
                ),
            )
            response = await client.aio.models.generate_content(
                model=route.model,
                contents=contents,
                config=config,
            )
        except Exception as exc:
            safe_msg = sanitize_error_message(exc, secrets)
            raise LLMProviderError(f"gemini completion failed: {safe_msg}") from exc

        text = _extract_gemini_text(response)
        usage_meta = getattr(response, "usage_metadata", None)
        usage = {
            "prompt_tokens": int(getattr(usage_meta, "prompt_token_count", 0) or 0),
            "completion_tokens": int(getattr(usage_meta, "candidates_token_count", 0) or 0),
            "total_tokens": int(getattr(usage_meta, "total_token_count", 0) or 0),
        }
        return LLMCompletionResult(
            content=text,
            provider="gemini",
            model=route.model,
            usage=usage,
            finish_reason="stop",
        )

    async def stream(
        self,
        messages: Sequence[Mapping[str, Any]],
        *,
        llm: Optional[LLMOverride] = None,
        temperature: Optional[float] = None,
        max_tokens: Optional[int] = None,
        top_p: Optional[float] = None,
        stop: Optional[Union[str, list[str]]] = None,
    ) -> AsyncIterator[LLMStreamChunk]:
        """Yield incremental text deltas asynchronously from the resolved LLM provider."""
        routes = self._candidate_routes(llm, temperature=temperature, max_tokens=max_tokens)
        normalized_messages = _normalize_message_list(messages)
        secrets = self._collect_secrets(llm)

        last_error: Optional[Exception] = None
        for idx, route in enumerate(routes):
            emitted_any = False
            try:
                async for chunk in self._stream_route(
                    route,
                    normalized_messages,
                    secrets=secrets,
                    top_p=top_p,
                    stop=stop,
                ):
                    if chunk.delta:
                        emitted_any = True
                    yield chunk
                return
            except (LLMConfigurationError, LLMProviderError) as exc:
                last_error = exc
                if emitted_any or idx == len(routes) - 1:
                    raise
        assert last_error is not None
        raise last_error

    async def _stream_route(
        self,
        route: ResolvedLLMRoute,
        normalized_messages: list[dict[str, str]],
        *,
        secrets: Sequence[Optional[str]],
        top_p: Optional[float],
        stop: Optional[Union[str, list[str]]],
    ) -> AsyncIterator[LLMStreamChunk]:
        """Stream token deltas from a single concrete `ResolvedLLMRoute`."""
        api_key = self._validate_route_credentials(route)

        if route.provider in ("kilo", "openai_compatible"):
            client = self._get_openai_client(route.base_url, api_key)
            kwargs: dict[str, Any] = {
                "model": route.model,
                "messages": normalized_messages,
                "temperature": route.temperature,
                "max_tokens": route.max_tokens,
                "stream": True,
            }
            if top_p is not None:
                kwargs["top_p"] = top_p
            if stop is not None:
                kwargs["stop"] = stop

            try:
                stream_obj = await client.chat.completions.create(**kwargs)
                async for chunk in stream_obj:
                    choices = getattr(chunk, "choices", None) or []
                    if not choices:
                        continue
                    choice = choices[0]
                    delta_obj = getattr(choice, "delta", None)
                    delta_text = str(getattr(delta_obj, "content", "") or "")
                    finish_reason = getattr(choice, "finish_reason", None)
                    if delta_text or finish_reason:
                        yield LLMStreamChunk(
                            delta=delta_text,
                            provider=route.provider,
                            model=route.model,
                            finish_reason=finish_reason,
                        )
            except Exception as exc:
                safe_msg = sanitize_error_message(exc, secrets)
                raise LLMProviderError(f"{route.provider} streaming failed: {safe_msg}") from exc
            return

        # Gemini streaming via official google-genai SDK
        system_instruction, contents = _split_gemini_messages(normalized_messages)
        stop_sequences = [stop] if isinstance(stop, str) else list(stop) if stop else None
        config = types.GenerateContentConfig(
            system_instruction=system_instruction,
            temperature=route.temperature,
            max_output_tokens=route.max_tokens,
            top_p=top_p,
            stop_sequences=stop_sequences,
        )
        try:
            client = genai.Client(
                api_key=api_key,
                http_options=types.HttpOptions(
                    timeout=int(self.settings.llm_timeout * 1000),
                    retry_options=types.HttpRetryOptions(attempts=2, initial_delay=0.5, max_delay=2.0),
                ),
            )
            stream_call = client.aio.models.generate_content_stream(
                model=route.model,
                contents=contents,
                config=config,
            )
            stream_iter = await stream_call if inspect.isawaitable(stream_call) else stream_call
            last_usage: Optional[dict[str, int]] = None
            async for chunk in stream_iter:
                usage_meta = getattr(chunk, "usage_metadata", None)
                if usage_meta is not None:
                    last_usage = {
                        "prompt_tokens": int(getattr(usage_meta, "prompt_token_count", 0) or 0),
                        "completion_tokens": int(getattr(usage_meta, "candidates_token_count", 0) or 0),
                        "total_tokens": int(getattr(usage_meta, "total_token_count", 0) or 0),
                    }
                delta_text = _extract_gemini_text(chunk)
                if delta_text:
                    yield LLMStreamChunk(
                        delta=delta_text,
                        provider="gemini",
                        model=route.model,
                        usage=last_usage,
                    )
            yield LLMStreamChunk(
                delta="",
                provider="gemini",
                model=route.model,
                finish_reason="stop",
                usage=last_usage,
            )
        except Exception as exc:
            safe_msg = sanitize_error_message(exc, secrets)
            raise LLMProviderError(f"gemini streaming failed: {safe_msg}") from exc

    async def _list_openai_compatible_models(self) -> list[ModelInfo]:
        """Discover models from configured `OPENAI_BASE_URL` if set, with fallback to default."""
        openai_ready = bool(self.settings.openai_api_key or self.settings.openai_base_url)
        discovered: list[ModelInfo] = []
        if self.settings.openai_base_url:
            url = f"{self.settings.openai_base_url.rstrip('/')}/models"
            headers: dict[str, str] = {}
            if self.settings.openai_api_key:
                headers["Authorization"] = f"Bearer {self.settings.openai_api_key}"
            try:
                async with httpx.AsyncClient(timeout=5.0) as hc:
                    resp = await hc.get(url, headers=headers)
                    resp.raise_for_status()
                    payload = resp.json()
                for entry in payload.get("data", []) if isinstance(payload, Mapping) else []:
                    if not isinstance(entry, Mapping) or not entry.get("id"):
                        continue
                    mid = str(entry["id"])
                    discovered.append(
                        ModelInfo(
                            id=mid,
                            provider="openai_compatible",
                            name=str(entry.get("label") or entry.get("name") or mid),
                            is_free=False,
                            context_length=entry.get("context_length"),
                            description=str(entry.get("blurb") or entry.get("description") or "") or None,
                            supports_streaming=True,
                            available=openai_ready,
                            base_url=self.settings.openai_base_url,
                        )
                    )
            except Exception:
                pass

        if discovered:
            return discovered

        return [
            ModelInfo(
                id=self.settings.default_openai_model,
                provider="openai_compatible",
                name=f"{self.settings.default_openai_model} (OpenAI-Compatible)",
                is_free=False,
                context_length=None,
                description="Configured OpenAI-compatible gateway model (supports custom base_url per request).",
                supports_streaming=True,
                available=openai_ready,
                base_url=self.settings.openai_base_url,
            )
        ]

    async def list_models(
        self,
        *,
        provider: Optional[str] = None,
        free_only: bool = False,
        force_refresh: bool = False,
    ) -> list[ModelInfo]:
        """List available models across KiloAI, Gemini, and configured OpenAI-compatible gateways."""
        target = provider.strip().lower() if provider else None
        if target in ("openai", "custom", "ollama", "openrouter"):
            target = "openai_compatible"

        catalog: list[ModelInfo] = []
        if target in (None, "kilo"):
            catalog.extend(
                await list_kilo_models(
                    free_only=free_only,
                    force_refresh=force_refresh,
                    settings=self.settings,
                )
            )

        if target in (None, "gemini") and not free_only:
            gemini_ready = bool(self.settings.gemini_api_key)
            seen_ids: set[str] = set()
            gemini_entries = list(CURATED_GEMINI_MODELS)
            if self.settings.default_gemini_model not in {m["id"] for m in gemini_entries}:
                gemini_entries.insert(
                    0,
                    {
                        "id": self.settings.default_gemini_model,
                        "name": self.settings.default_gemini_model,
                        "is_free": False,
                        "context_length": 1048576,
                        "description": "Configured default Gemini model.",
                    },
                )
            for item in gemini_entries:
                if item["id"] in seen_ids:
                    continue
                seen_ids.add(item["id"])
                catalog.append(
                    ModelInfo(
                        id=item["id"],
                        provider="gemini",
                        name=item["name"],
                        is_free=False,
                        context_length=item.get("context_length"),
                        description=item.get("description"),
                        supports_streaming=True,
                        available=gemini_ready,
                        base_url=None,
                    )
                )

        if target in (None, "openai_compatible") and not free_only:
            catalog.extend(await self._list_openai_compatible_models())

        return catalog

    async def test_connection(self, llm: Optional[LLMOverride] = None) -> dict[str, Any]:
        """Run a minimal latency ping against the selected LLM provider."""
        start = time.perf_counter()
        result = await self.complete(
            [{"role": "user", "content": "Reply with exactly: OK"}],
            llm=llm,
            temperature=0.0,
            max_tokens=128,
        )
        latency_ms = round((time.perf_counter() - start) * 1000, 2)
        return {
            "status": "ok",
            "provider": result.provider,
            "model": result.model,
            "reply": result.content.strip(),
            "latency_ms": latency_ms,
            "usage": result.usage,
        }


def _extract_gemini_text(response: Any) -> str:
    """Safely extract text from a `google-genai` response or chunk."""
    try:
        text = getattr(response, "text", None)
        if isinstance(text, str):
            return text
    except Exception:
        pass
    candidates = getattr(response, "candidates", None) or []
    parts_out: list[str] = []
    for cand in candidates:
        content = getattr(cand, "content", None)
        for part in getattr(content, "parts", None) or []:
            part_text = getattr(part, "text", None)
            if isinstance(part_text, str):
                parts_out.append(part_text)
    return "".join(parts_out)
