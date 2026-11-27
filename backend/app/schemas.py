"""Pydantic v2 request, response, and domain schemas for WakilAI backend."""

from __future__ import annotations

from datetime import datetime, timezone
from enum import Enum
from typing import Any, Literal, Optional, Union

from pydantic import BaseModel, ConfigDict, Field


class CategoryEnum(str, Enum):
    """Statutory and legal knowledge corpus categories."""

    CONSTITUTION = "CONSTITUTION"
    CODES = "CODES"
    NKP = "NKP"
    DIRECTIVES = "DIRECTIVES"
    WEB = "WEB"
    OTHER = "OTHER"


class WebSearchMode(str, Enum):
    """Controls when live web search supplements static legal RAG retrieval."""

    OFF = "off"
    AUTO = "auto"
    ALWAYS = "always"


class LLMOverride(BaseModel):
    """Per-request override for AI provider, model, custom endpoint, or generation params."""

    provider: Optional[str] = Field(
        default=None,
        description="LLM provider: auto, kilo, gemini, or openai_compatible.",
    )
    model: Optional[str] = Field(
        default=None,
        description="Model identifier (e.g., kilo-auto/free, gemini-2.5-flash, llama3.2).",
    )
    base_url: Optional[str] = Field(
        default=None,
        description="Optional OpenAI-compatible base URL override.",
    )
    api_key: Optional[str] = Field(
        default=None,
        description="Optional caller-supplied API key (never logged or returned).",
    )
    temperature: Optional[float] = Field(
        default=None,
        ge=0.0,
        le=2.0,
        description="Sampling temperature override.",
    )
    max_tokens: Optional[int] = Field(
        default=None,
        ge=1,
        le=128000,
        description="Maximum generated tokens override.",
    )


class CorpusDocumentMeta(BaseModel):
    """Metadata record persisted in `corpus_manifest.json` for each ingested document."""

    doc_id: str = Field(..., description="Deterministic or UUID document identifier.")
    title: str = Field(..., description="Display title of the statutory document.")
    act_name: Optional[str] = Field(
        default=None,
        description="Normalized statute or act name used for legal citations.",
    )
    category: CategoryEnum = Field(
        default=CategoryEnum.OTHER,
        description="Legal corpus classification category.",
    )
    language: str = Field(
        default="EN",
        description="Primary document language: EN, NE, or BILINGUAL.",
    )
    file_name: Optional[str] = Field(default=None, description="Original filename.")
    source_path: Optional[str] = Field(default=None, description="Local filesystem source path.")
    source_url: Optional[str] = Field(default=None, description="Remote origin URL if fetched from web.")
    sha256: str = Field(default="", description="SHA-256 content digest for deduplication.")
    file_size_bytes: int = Field(default=0, ge=0, description="Source byte size.")
    page_count: int = Field(default=0, ge=0, description="Extracted page count.")
    chunks_count: int = Field(default=0, ge=0, description="Indexed chunk count.")
    status: str = Field(default="INDEXED", description="Current indexing status.")
    ingested_at: datetime = Field(
        default_factory=lambda: datetime.now(timezone.utc),
        description="UTC timestamp when document was indexed.",
    )
    metadata: dict[str, Any] = Field(
        default_factory=dict,
        description="Additional source-specific metadata.",
    )


class IngestResponse(BaseModel):
    """Unified response returned by file, path, URL, bootstrap, and reindex operations."""

    status: str = Field(default="ok", description="Operation status (`indexed`, `skipped_duplicate`, `ok`, `error`).")
    doc_id: Optional[str] = Field(default=None, description="Primary ingested document ID.")
    title: Optional[str] = Field(default=None, description="Primary ingested document title.")
    chunks_indexed: int = Field(default=0, ge=0, description="Total chunks written to Qdrant and BM25.")
    deduplicated: bool = Field(
        default=False,
        description="True when identical SHA-256 content already existed in the corpus.",
    )
    document: Optional[CorpusDocumentMeta] = Field(
        default=None,
        description="Metadata of the ingested document for single-item requests.",
    )
    documents: list[CorpusDocumentMeta] = Field(
        default_factory=list,
        description="Metadata list when ingesting multiple files or bootstrapping corpus.",
    )
    message: str = Field(default="", description="Human-readable summary of ingestion outcome.")
    errors: list[str] = Field(
        default_factory=list,
        description="Non-fatal warnings or per-file errors encountered during batch ingestion.",
    )


class IngestPathRequest(BaseModel):
    """Request body for ingesting a local file or directory path."""

    path: str = Field(..., min_length=1, description="Local file or directory path to ingest.")
    category: CategoryEnum = Field(
        default=CategoryEnum.OTHER,
        description="Category assigned to ingested documents.",
    )
    act_name: Optional[str] = Field(default=None, description="Optional act/statute name override.")
    language: Optional[str] = Field(default=None, description="Optional language override (`EN`, `NE`, `BILINGUAL`).")
    recursive: bool = Field(default=True, description="Traverse subdirectories when path is a directory.")
    force_reindex: bool = Field(default=False, description="Re-ingest even if SHA-256 hash matches manifest.")


class IngestUrlRequest(BaseModel):
    """Request body for fetching and ingesting a statutory document from a URL."""

    url: str = Field(..., min_length=1, description="HTTP/HTTPS URL pointing to a PDF, HTML, or text statute.")
    title: Optional[str] = Field(default=None, description="Optional document title override.")
    act_name: Optional[str] = Field(default=None, description="Optional act/statute name override.")
    category: CategoryEnum = Field(
        default=CategoryEnum.OTHER,
        description="Category assigned to the fetched document.",
    )
    language: Optional[str] = Field(default=None, description="Optional language override (`EN`, `NE`, `BILINGUAL`).")
    force_reindex: bool = Field(default=False, description="Re-ingest even if SHA-256 hash matches manifest.")


class SearchFilter(BaseModel):
    """Metadata filters applied across both Qdrant vector search and BM25 lexical search."""

    category: Optional[CategoryEnum] = Field(default=None, description="Single category filter.")
    categories: Optional[list[CategoryEnum]] = Field(
        default=None,
        description="Optional list of allowed categories.",
    )
    act_name: Optional[str] = Field(default=None, description="Filter by statute/act name.")
    doc_id: Optional[str] = Field(default=None, description="Restrict search to a specific document ID.")
    language: Optional[str] = Field(default=None, description="Filter by language (`EN`, `NE`, `BILINGUAL`).")
    section_num: Optional[str] = Field(
        default=None,
        description="Normalized ASCII section/article number (e.g., `391`).",
    )


class RetrievedChunk(BaseModel):
    """A statutory chunk returned by hybrid Qdrant + BM25 retrieval."""

    chunk_id: str = Field(..., description="Deterministic chunk UUID string.")
    doc_id: str = Field(..., description="Parent document ID.")
    text: str = Field(..., description="Extracted statutory text chunk.")
    act_name: str = Field(default="", description="Name of the act or legal source.")
    category: CategoryEnum = Field(default=CategoryEnum.OTHER, description="Document category.")
    language: str = Field(default="EN", description="Chunk language (`EN`, `NE`, `BILINGUAL`).")
    section_num: Optional[str] = Field(
        default=None,
        description="Normalized ASCII article/section/rule number if detected.",
    )
    section_title: Optional[str] = Field(
        default=None,
        description="Detected section or article heading.",
    )
    citation_label: str = Field(
        default="",
        description="Formatted legal citation string, e.g., `Muluki Civil Code 2074, Sec. 391`.",
    )
    page_start: Optional[int] = Field(default=None, description="Starting 1-based page number.")
    page_end: Optional[int] = Field(default=None, description="Ending 1-based page number.")
    chunk_index: int = Field(default=0, ge=0, description="Zero-based chunk order within parent document.")
    source_path: Optional[str] = Field(default=None, description="Origin local file path.")
    source_url: Optional[str] = Field(default=None, description="Origin source URL.")
    score: float = Field(default=0.0, description="Final fused relevance score (RRF).")
    dense_score: Optional[float] = Field(default=None, description="Raw Qdrant dense similarity score.")
    bm25_score: Optional[float] = Field(default=None, description="Raw BM25 lexical score.")
    retrieval_sources: list[str] = Field(
        default_factory=list,
        description="Signals contributing to this hit (e.g., `dense`, `bm25`, `section_exact`).",
    )
    metadata: dict[str, Any] = Field(
        default_factory=dict,
        description="Additional payload metadata.",
    )


class WebSearchResult(BaseModel):
    """A live web search hit returned by Tavily or DuckDuckGo."""

    title: str = Field(..., description="Result page title.")
    url: str = Field(..., description="Result URL.")
    snippet: str = Field(default="", description="Relevant text excerpt from search provider.")
    content: Optional[str] = Field(
        default=None,
        description="Optional full extracted text when page fetching is enabled.",
    )
    source: str = Field(default="web", description="Search provider name (`tavily`, `ddgs`, `direct`).")
    domain: Optional[str] = Field(default=None, description="Hostname of the result URL.")
    published_date: Optional[str] = Field(default=None, description="Published timestamp if provided.")
    score: Optional[float] = Field(default=None, description="Provider relevance score if available.")


class RAGSearchRequest(BaseModel):
    """Request body for standalone hybrid vector + BM25 statutory retrieval."""

    query: str = Field(..., min_length=1, description="English, Nepali, or Nepglish legal query.")
    top_k: int = Field(default=6, ge=1, le=50, description="Maximum number of fused chunks to return.")
    filters: Optional[SearchFilter] = Field(default=None, description="Optional metadata filters.")
    use_dense: bool = Field(default=True, description="Include Qdrant dense vector retrieval.")
    use_bm25: bool = Field(default=True, description="Include BM25 lexical retrieval.")
    min_score: Optional[float] = Field(default=None, description="Optional minimum fused score threshold.")


class RAGSearchResponse(BaseModel):
    """Response from hybrid RAG retrieval."""

    query: str = Field(..., description="Original query string.")
    expanded_tokens: list[str] = Field(
        default_factory=list,
        description="Normalized and Nepglish-expanded query tokens used for lexical search.",
    )
    results: list[RetrievedChunk] = Field(default_factory=list, description="Ranked retrieved statutory chunks.")
    total_results: int = Field(default=0, ge=0, description="Count of returned chunks.")
    embedding_provider: Optional[str] = Field(default=None, description="Active dense embedding backend.")
    latency_ms: Optional[float] = Field(default=None, description="Retrieval execution time in milliseconds.")


class WebSearchRequest(BaseModel):
    """Request body for standalone live Nepal legal web search."""

    query: str = Field(..., min_length=1, description="Web search query.")
    max_results: int = Field(default=5, ge=1, le=20, description="Maximum number of web results.")
    nepal_legal_only: bool = Field(
        default=True,
        description="Prioritize authoritative Nepal legal portals when true.",
    )
    include_domains: Optional[list[str]] = Field(
        default=None,
        description="Explicit domain allowlist override.",
    )
    fetch_page_content: bool = Field(
        default=False,
        description="Fetch and extract clean page text for top results.",
    )


class WebSearchResponse(BaseModel):
    """Response from live web search."""

    query: str = Field(..., description="Executed search query.")
    provider: str = Field(default="none", description="Provider used (`tavily`, `ddgs`, or `none`).")
    results: list[WebSearchResult] = Field(default_factory=list, description="Returned web search hits.")
    total_results: int = Field(default=0, ge=0, description="Count of returned web results.")
    latency_ms: Optional[float] = Field(default=None, description="Search execution time in milliseconds.")
    error: Optional[str] = Field(default=None, description="Non-fatal provider error notice if search degraded.")


class ChatMessageItem(BaseModel):
    """Single conversation turn passed in chat history."""

    role: Literal["system", "user", "assistant"] = Field(..., description="Message speaker role.")
    content: str = Field(..., description="Message text content.")


class ChatRequest(BaseModel):
    """Native WakilAI legal chat request supporting hybrid RAG, web search, and any LLM."""

    query: str = Field(..., min_length=1, description="User legal question in English, Nepali, or Nepglish.")
    history: list[ChatMessageItem] = Field(
        default_factory=list,
        description="Prior conversation turns.",
    )
    language: Literal["auto", "EN", "NP"] = Field(
        default="auto",
        description="Preferred response language (`auto` matches query language).",
    )
    top_k: int = Field(default=6, ge=1, le=30, description="Number of statutory chunks to retrieve.")
    filters: Optional[SearchFilter] = Field(default=None, description="Optional RAG corpus metadata filters.")
    use_rag: bool = Field(default=True, description="Enable hybrid Qdrant + BM25 retrieval.")
    web_search: WebSearchMode = Field(
        default=WebSearchMode.AUTO,
        description="Live web search policy: `off`, `auto`, or `always`.",
    )
    web_max_results: int = Field(default=4, ge=1, le=15, description="Max live web results when web search runs.")
    nepal_legal_web_only: bool = Field(
        default=True,
        description="Bias live web search toward official Nepal legal sources.",
    )
    llm: Optional[LLMOverride] = Field(
        default=None,
        description="Optional per-request LLM provider, model, URL, or API key override.",
    )
    stream: bool = Field(default=False, description="Whether streaming SSE is requested.")


class ChatResponse(BaseModel):
    """Structured WakilAI legal RAG chat response with grounded statutory and web citations."""

    answer: str = Field(..., description="Generated grounded legal assistant response.")
    language: str = Field(default="EN", description="Resolved output language (`EN` or `NP`).")
    provider: str = Field(default="", description="Resolved LLM provider used.")
    model: str = Field(default="", description="Resolved LLM model ID used.")
    used_rag: bool = Field(default=False, description="Whether hybrid RAG retrieval was executed.")
    used_web_search: bool = Field(default=False, description="Whether live web search was executed.")
    citations: list[RetrievedChunk] = Field(
        default_factory=list,
        description="Retrieved statutory chunks provided as grounding context.",
    )
    web_results: list[WebSearchResult] = Field(
        default_factory=list,
        description="Live web search results provided as supplementary context.",
    )
    usage: dict[str, Any] = Field(
        default_factory=dict,
        description="Token usage stats if reported by the upstream provider.",
    )
    latency_ms: Optional[float] = Field(default=None, description="End-to-end request duration in milliseconds.")


class ModelInfo(BaseModel):
    """Describes an available AI model across KiloAI, Gemini, or OpenAI-compatible gateways."""

    id: str = Field(..., description="Model identifier.")
    provider: str = Field(..., description="Provider key (`kilo`, `gemini`, `openai_compatible`).")
    name: str = Field(default="", description="Human-friendly display name.")
    is_free: bool = Field(default=False, description="True if model is a zero-cost/free tier model.")
    context_length: Optional[int] = Field(default=None, description="Maximum context window in tokens.")
    description: Optional[str] = Field(default=None, description="Short model capability description.")
    supports_streaming: bool = Field(default=True, description="Whether async token streaming is supported.")
    available: bool = Field(default=True, description="Whether provider credentials/endpoint are ready.")
    base_url: Optional[str] = Field(default=None, description="Gateway base URL if applicable.")


class HealthResponse(BaseModel):
    """Backend health and subsystem readiness status."""

    status: str = Field(default="ok", description="Overall service status (`ok` or `degraded`).")
    app_name: str = Field(default="WakilAI Legal RAG API", description="Service name.")
    version: str = Field(default="0.1.0", description="Backend version.")
    qdrant_connected: bool = Field(default=False, description="True when Qdrant client is initialized.")
    qdrant_mode: str = Field(default="embedded", description="`embedded` local path or `remote` Qdrant URL.")
    qdrant_collection: str = Field(default="", description="Active Qdrant collection name.")
    qdrant_points: int = Field(default=0, ge=0, description="Indexed vector count in Qdrant.")
    bm25_docs: int = Field(default=0, ge=0, description="Indexed chunk count in BM25 store.")
    corpus_documents: int = Field(default=0, ge=0, description="Tracked source documents in manifest.")
    embedding_provider: str = Field(default="", description="Active dense embedding provider.")
    embedding_model: str = Field(default="", description="Active embedding model identifier.")
    embedding_dim: int = Field(default=768, ge=1, description="Active vector dimensionality.")
    llm_default_provider: str = Field(default="", description="Resolved default LLM provider.")
    llm_default_model: str = Field(default="", description="Resolved default LLM model.")
    tavily_configured: bool = Field(default=False, description="True when TAVILY_API_KEY is configured.")
    gemini_configured: bool = Field(default=False, description="True when GEMINI_API_KEY is configured.")
    kilo_configured: bool = Field(default=False, description="True when KILOCODE_API_KEY is configured.")
    openai_configured: bool = Field(default=False, description="True when OPENAI_API_KEY/BASE_URL is configured.")


class OpenAIChatMessage(BaseModel):
    """OpenAI-compatible chat message payload."""

    model_config = ConfigDict(extra="allow")

    role: Literal["system", "user", "assistant", "tool"] = Field(
        ...,
        description="OpenAI message role.",
    )
    content: Union[str, list[dict[str, Any]], None] = Field(
        default="",
        description="Text content or multimodal content array.",
    )
    name: Optional[str] = Field(default=None, description="Optional participant name.")

    def text_content(self) -> str:
        """Extract normalized plain text regardless of string or content-part array input."""
        if self.content is None:
            return ""
        if isinstance(self.content, str):
            return self.content
        parts: list[str] = []
        for item in self.content:
            if isinstance(item, dict) and item.get("type") == "text":
                text = item.get("text")
                if isinstance(text, str):
                    parts.append(text)
        return "\n".join(parts)


class OpenAIChatCompletionRequest(BaseModel):
    """OpenAI `/v1/chat/completions` compatible request with optional Wakil RAG extensions."""

    model_config = ConfigDict(extra="allow")

    model: str = Field(
        default="kilo/kilo-auto/free",
        description="Model string, optionally prefixed with `kilo/`, `gemini/`, or `openai/`.",
    )
    messages: list[OpenAIChatMessage] = Field(
        ...,
        min_length=1,
        description="Ordered conversation messages.",
    )
    temperature: Optional[float] = Field(default=None, ge=0.0, le=2.0)
    max_tokens: Optional[int] = Field(default=None, ge=1)
    stream: bool = Field(default=False, description="Return OpenAI SSE `chat.completion.chunk` events.")
    top_p: Optional[float] = Field(default=None, ge=0.0, le=1.0)
    stop: Optional[Union[str, list[str]]] = None
    user: Optional[str] = None

    # Optional Wakil RAG / provider routing extensions
    use_rag: Optional[bool] = Field(default=None, description="Enable/disable Wakil hybrid RAG injection.")
    web_search: Optional[WebSearchMode] = Field(default=None, description="Web search policy override.")
    top_k: Optional[int] = Field(default=None, ge=1, le=30, description="RAG chunk count override.")
    filters: Optional[SearchFilter] = Field(default=None, description="Optional statutory metadata filters.")
    base_url: Optional[str] = Field(default=None, description="Custom OpenAI-compatible gateway URL.")
    api_key: Optional[str] = Field(default=None, description="Caller-supplied upstream API key.")


class OpenAIUsage(BaseModel):
    """OpenAI-compatible token usage block."""

    prompt_tokens: int = 0
    completion_tokens: int = 0
    total_tokens: int = 0


class OpenAIChatCompletionChoice(BaseModel):
    """Single choice in a non-streaming OpenAI chat completion response."""

    index: int = 0
    message: OpenAIChatMessage
    finish_reason: Optional[str] = "stop"


class OpenAIChatCompletionResponse(BaseModel):
    """OpenAI `/v1/chat/completions` compatible response payload."""

    id: str
    object: Literal["chat.completion"] = "chat.completion"
    created: int
    model: str
    choices: list[OpenAIChatCompletionChoice]
    usage: OpenAIUsage = Field(default_factory=OpenAIUsage)
    wakil_citations: list[RetrievedChunk] = Field(default_factory=list)
    wakil_web_results: list[WebSearchResult] = Field(default_factory=list)
