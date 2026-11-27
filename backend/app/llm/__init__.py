"""Universal AI model router and bilingual Nepalese legal RAG prompt engine."""

from app.llm.prompts import (
    DEFAULT_LEGAL_TEMPERATURE,
    build_rag_messages,
    build_system_prompt,
    detect_query_language,
    estimate_tokens,
    format_context_block,
    is_nepglish,
    trim_history,
)
from app.llm.providers import (
    KILO_FALLBACK_MODELS,
    LLMCompletionResult,
    LLMConfigurationError,
    LLMProviderError,
    LLMRouter,
    LLMStreamChunk,
    ResolvedLLMRoute,
    list_kilo_models,
    sanitize_error_message,
)

__all__ = [
    "DEFAULT_LEGAL_TEMPERATURE",
    "KILO_FALLBACK_MODELS",
    "LLMCompletionResult",
    "LLMConfigurationError",
    "LLMProviderError",
    "LLMRouter",
    "LLMStreamChunk",
    "ResolvedLLMRoute",
    "build_rag_messages",
    "build_system_prompt",
    "detect_query_language",
    "estimate_tokens",
    "format_context_block",
    "is_nepglish",
    "list_kilo_models",
    "sanitize_error_message",
    "trim_history",
]
