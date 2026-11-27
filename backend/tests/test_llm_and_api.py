"""Tests for LLMRouter, prompts, native chat/SSE, OpenAI `/v1` drop-in gateway, and ingestion HTTP APIs."""

from __future__ import annotations

import asyncio
import json
import types
from pathlib import Path
from typing import Any, AsyncIterator
from unittest.mock import AsyncMock

import httpx
import pytest
from fastapi.testclient import TestClient

from app.api.main import create_app
from app.config import Settings
from app.ingestion.extractors import ExtractedDocument, ExtractedPage
from app.llm import providers as llm_providers
from app.llm.prompts import build_rag_messages, detect_query_language, is_nepglish
from app.llm.providers import LLMConfigurationError, LLMRouter, sanitize_error_message
from app.pipeline import WakilRAGPipeline
from app.schemas import CategoryEnum, LLMOverride, WebSearchMode


class _FakeOpenAICompletion:
    def __init__(self, text: str, finish_reason: str = "stop") -> None:
        self.choices = [
            types.SimpleNamespace(
                message=types.SimpleNamespace(content=text),
                finish_reason=finish_reason,
            )
        ]
        self.usage = types.SimpleNamespace(prompt_tokens=20, completion_tokens=10, total_tokens=30)


async def _fake_openai_stream(chunks: list[str]) -> AsyncIterator[Any]:
    for idx, piece in enumerate(chunks):
        yield types.SimpleNamespace(
            choices=[
                types.SimpleNamespace(
                    delta=types.SimpleNamespace(content=piece),
                    finish_reason=None,
                )
            ]
        )
    yield types.SimpleNamespace(
        choices=[
            types.SimpleNamespace(
                delta=types.SimpleNamespace(content=""),
                finish_reason="stop",
            )
        ]
    )


def _install_fake_openai(
    monkeypatch: pytest.MonkeyPatch,
    recorded_calls: list[dict[str, Any]],
    *,
    reply_text: str = "Grounded legal answer [Muluki Civil Code 2074, Sec. 391].",
    stream_pieces: list[str] | None = None,
) -> None:
    pieces = stream_pieces or ["Grounded ", "legal ", "answer [Muluki Civil Code 2074, Sec. 391]."]

    class FakeAsyncOpenAI:
        def __init__(self, **kwargs: Any) -> None:
            self.init_kwargs = kwargs
            self.chat = types.SimpleNamespace(
                completions=types.SimpleNamespace(create=self._create)
            )

        async def _create(self, **kwargs: Any) -> Any:
            recorded_calls.append({"init": self.init_kwargs, "create": kwargs})
            if kwargs.get("stream"):
                return _fake_openai_stream(pieces)
            return _FakeOpenAICompletion(reply_text)

        async def close(self) -> None:
            return None

    monkeypatch.setattr(llm_providers, "AsyncOpenAI", FakeAsyncOpenAI)


def _install_fake_gemini(
    monkeypatch: pytest.MonkeyPatch,
    recorded_calls: list[dict[str, Any]],
    *,
    reply_text: str = "Gemini grounded answer [Constitution of Nepal 2072, Art. 28].",
    stream_pieces: list[str] | None = None,
) -> None:
    pieces = stream_pieces or ["Gemini ", "grounded ", "answer."]

    class FakeGeminiClient:
        def __init__(self, *, api_key: str, **kwargs: Any) -> None:
            self.api_key = api_key
            self.init_kwargs = kwargs
            self.aio = types.SimpleNamespace(
                models=types.SimpleNamespace(
                    generate_content=self._generate_content,
                    generate_content_stream=self._generate_content_stream,
                )
            )

        async def _generate_content(self, **kwargs: Any) -> Any:
            recorded_calls.append({"api_key": self.api_key, "call": "complete", **kwargs})
            return types.SimpleNamespace(
                text=reply_text,
                usage_metadata=types.SimpleNamespace(
                    prompt_token_count=18,
                    candidates_token_count=9,
                    total_tokens=27,
                ),
            )

        async def _generate_content_stream(self, **kwargs: Any) -> AsyncIterator[Any]:
            recorded_calls.append({"api_key": self.api_key, "call": "stream", **kwargs})

            async def _gen() -> AsyncIterator[Any]:
                for piece in pieces:
                    yield types.SimpleNamespace(
                        text=piece,
                        usage_metadata=types.SimpleNamespace(
                            prompt_token_count=18,
                            candidates_token_count=9,
                            total_tokens=27,
                        ),
                    )

            return _gen()

    monkeypatch.setattr(llm_providers.genai, "Client", FakeGeminiClient)


def _parse_sse_events(raw_text: str) -> list[dict[str, str]]:
    events: list[dict[str, str]] = []
    current: dict[str, str] = {}
    for line in raw_text.replace("\r\n", "\n").splitlines():
        if not line.strip():
            if current:
                events.append(current)
                current = {}
            continue
        if ":" in line:
            key, val = line.split(":", 1)
            key = key.strip()
            val = val.lstrip()
            if key == "data" and "data" in current:
                current["data"] = f"{current['data']}\n{val}"
            else:
                current[key] = val
    if current:
        events.append(current)
    return events


def test_prompt_language_nepglish_and_secret_sanitization() -> None:
    assert is_nepglish("gharbeti le rent badhauna milchha ra?") is True
    assert is_nepglish("What is Article 28 of the Constitution of Nepal?") is False
    assert detect_query_language("दफा ३९१ बारे बताउनुहोस्") == "NP"
    assert detect_query_language("What is Section 391?") == "EN"

    sanitized = sanitize_error_message(
        "Auth failed with Bearer supersecrettoken123 and AIzaSyDummyKey123456789012345",
        secrets=["supersecrettoken123"],
    )
    assert "supersecrettoken123" not in sanitized
    assert "AIzaSyDummyKey" not in sanitized
    assert "***REDACTED***" in sanitized


def test_llm_router_providers_overrides_and_streaming(
    isolated_settings: Settings,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    isolated_settings.kilocode_api_key = "kilo-test-secret"
    isolated_settings.gemini_api_key = "AIzaTestGeminiSecret1234567890123"

    openai_calls: list[dict[str, Any]] = []
    gemini_calls: list[dict[str, Any]] = []
    _install_fake_openai(monkeypatch, openai_calls)
    _install_fake_gemini(monkeypatch, gemini_calls)

    router = LLMRouter(settings=isolated_settings)

    async def _run() -> None:
        # 1. KiloAI complete & stream
        kilo_res = await router.complete(
            [{"role": "user", "content": "Explain house rent rules."}],
            llm=LLMOverride(provider="kilo", model="kilo-auto/free"),
        )
        assert kilo_res.provider == "kilo"
        assert kilo_res.model == "kilo-auto/free"
        assert "Sec. 391" in kilo_res.content
        assert openai_calls[-1]["init"]["base_url"] == isolated_settings.kilo_base_url

        kilo_deltas: list[str] = []
        async for ch in router.stream(
            [{"role": "user", "content": "Stream house rent rules."}],
            llm=LLMOverride(model="kilo/nvidia/nemotron-3.5-super-vl:free"),
        ):
            if ch.delta:
                kilo_deltas.append(ch.delta)
        assert "".join(kilo_deltas).startswith("Grounded legal answer")
        assert openai_calls[-1]["create"]["model"] == "nvidia/nemotron-3.5-super-vl:free"

        # 2. Gemini complete & stream
        gem_res = await router.complete(
            [{"role": "system", "content": "Cite accurately."}, {"role": "user", "content": "Article 28"}],
            llm=LLMOverride(model="gemini/gemini-2.5-flash"),
        )
        assert gem_res.provider == "gemini"
        assert gem_res.model == "gemini-2.5-flash"
        assert "Art. 28" in gem_res.content
        assert gemini_calls[-1]["model"] == "gemini-2.5-flash"

        gem_deltas: list[str] = []
        async for ch in router.stream(
            [{"role": "user", "content": "Stream Article 28"}],
            llm=LLMOverride(provider="gemini", model="gemini-2.5-pro"),
        ):
            if ch.delta:
                gem_deltas.append(ch.delta)
        assert "".join(gem_deltas) == "Gemini grounded answer."

        # 3. Custom OpenAI-compatible override (e.g., Ollama / OpenRouter)
        custom_res = await router.complete(
            [{"role": "user", "content": "Hello"}],
            llm=LLMOverride(
                provider="openai_compatible",
                base_url="http://localhost:11434/v1/",
                model="llama3.2",
            ),
        )
        assert custom_res.provider == "openai_compatible"
        assert custom_res.model == "llama3.2"
        assert openai_calls[-1]["init"]["base_url"] == "http://localhost:11434/v1"
        assert openai_calls[-1]["init"]["api_key"] == "not-needed"

        await router.aclose()

    asyncio.run(_run())


def test_llm_router_missing_credentials_raises_configuration_error(
    isolated_settings: Settings,
) -> None:
    router = LLMRouter(settings=isolated_settings)
    with pytest.raises(LLMConfigurationError, match="Missing KiloAI API key"):
        asyncio.run(
            router.complete(
                [{"role": "user", "content": "Test"}],
                llm=LLMOverride(provider="kilo"),
            )
        )
    with pytest.raises(LLMConfigurationError, match="Missing Gemini API key"):
        asyncio.run(
            router.complete(
                [{"role": "user", "content": "Test"}],
                llm=LLMOverride(provider="gemini"),
            )
        )


def test_fastapi_ingestion_corpus_rag_web_and_models_endpoints(
    isolated_settings: Settings,
    sample_nepal_law_pdf_bytes: bytes,
    tmp_path: Path,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    isolated_settings.kilocode_api_key = "kilo-api-key"
    isolated_settings.tavily_api_key = "tvly-api-key"

    openai_calls: list[dict[str, Any]] = []
    _install_fake_openai(monkeypatch, openai_calls, reply_text="OK")

    # Mock Kilo catalog fetch cleanly (avoids network)
    async def _fake_kilo_fetch(cfg: Settings) -> list[Any]:
        return [
            llm_providers.ModelInfo(
                id="kilo-auto/free",
                provider="kilo",
                name="Kilo Auto Free",
                is_free=True,
                context_length=200000,
                available=True,
                base_url=cfg.kilo_base_url,
            ),
            llm_providers.ModelInfo(
                id="anthropic/claude-sonnet-4",
                provider="kilo",
                name="Claude Sonnet 4",
                is_free=False,
                context_length=200000,
                available=True,
                base_url=cfg.kilo_base_url,
            ),
        ]

    monkeypatch.setattr(llm_providers, "_fetch_kilo_catalog", _fake_kilo_fetch)
    llm_providers._kilo_catalog_cache["ts"] = 0.0
    llm_providers._kilo_catalog_cache["models"] = None

    app = create_app(settings=isolated_settings)

    with TestClient(app) as client:
        # Root & Health before ingestion
        root_resp = client.get("/")
        assert root_resp.status_code == 200
        assert root_resp.json()["openai_base_url"] == "/v1"

        health0 = client.get("/health")
        assert health0.status_code == 200
        assert health0.json()["qdrant_connected"] is True
        assert health0.json()["qdrant_points"] == 0

        # Unsupported file upload returns 400
        bad_upload = client.post(
            "/api/v1/ingest/file",
            files={"file": ("malware.exe", b"MZ...", "application/octet-stream")},
        )
        assert bad_upload.status_code == 400

        # Upload real multi-page Nepal law PDF
        up1 = client.post(
            "/api/v1/ingest/file",
            files={"file": ("nepal_sample.pdf", sample_nepal_law_pdf_bytes, "application/pdf")},
            data={"category": "CODES", "act_name": "Nepal Sample Statutes"},
        )
        assert up1.status_code == 200
        up1_data = up1.json()
        assert up1_data["status"] == "indexed"
        assert up1_data["chunks_indexed"] >= 5
        pdf_doc_id = up1_data["doc_id"]

        # Re-uploading identical bytes deduplicates
        up_dup = client.post(
            "/api/v1/ingest/file",
            files={"file": ("duplicate.pdf", sample_nepal_law_pdf_bytes, "application/pdf")},
            data={"category": "CODES"},
        )
        assert up_dup.status_code == 200
        assert up_dup.json()["deduplicated"] is True

        # Ingest local path (.txt with Devanagari section 391)
        local_txt = tmp_path / "muluki_nepali.txt"
        local_txt.write_text(
            "मुलुकी देवानी संहिता, २०७४\n"
            "दफा ३९१. बहाल वृद्धि सम्बन्धी व्यवस्था: घरधनी (gharbeti) ले दुई वर्षपछि मात्र बहाल वृद्धि गर्न पाउनेछ।\n",
            encoding="utf-8",
        )
        up_path = client.post(
            "/api/v1/ingest/path",
            json={"path": str(local_txt), "category": "CODES", "act_name": "Muluki Civil Code 2074"},
        )
        assert up_path.status_code == 200
        assert up_path.json()["status"] == "indexed"
        txt_doc_id = up_path.json()["doc_id"]

        # Ingest URL (mocking pipeline.ingestion.ingest_url or extract_url)
        from app.ingestion import pipeline as ing_pipeline_mod

        async def _fake_extract_url(url: str, *, title: str | None = None, timeout: float = 30.0):
            txt = "Section 10. Right to information in Nepal public bodies."
            doc = ExtractedDocument(
                text=txt,
                pages=[ExtractedPage(page_number=1, text=txt)],
                page_count=1,
                format="html",
                language="EN",
                title=title or "RTI Act",
                source_url=url,
            )
            return doc, txt.encode("utf-8"), "rti.html"

        monkeypatch.setattr(ing_pipeline_mod, "extract_url", _fake_extract_url)
        up_url = client.post(
            "/api/v1/ingest/url",
            json={"url": "https://lawcommission.gov.np/en/rti", "category": "CODES"},
        )
        assert up_url.status_code == 200
        url_doc_id = up_url.json()["doc_id"]

        # Corpus list & health populated
        corpus = client.get("/api/v1/corpus")
        assert corpus.status_code == 200
        assert corpus.json()["total"] == 3

        health1 = client.get("/health").json()
        assert health1["corpus_documents"] == 3
        assert health1["qdrant_points"] >= 7
        assert health1["bm25_docs"] >= 7

        # Hybrid RAG search over HTTP
        rag_res = client.post(
            "/api/v1/rag/search",
            json={"query": "gharbeti dafa 391 house rent", "top_k": 3},
        )
        assert rag_res.status_code == 200
        rag_body = rag_res.json()
        assert rag_body["total_results"] >= 1
        assert rag_body["results"][0]["section_num"] == "391"

        # Models endpoints & ping test
        free_models = client.get("/api/v1/models", params={"provider": "kilo", "free_only": True})
        assert free_models.status_code == 200
        assert [m["id"] for m in free_models.json()["models"]] == ["kilo-auto/free"]

        # Ping & Reindex endpoints
        ping = client.post("/api/v1/models/test", json={"provider": "kilo", "model": "kilo-auto/free"})
        assert ping.status_code == 200
        assert ping.json()["status"] == "ok"

        reindex_res = client.post("/api/v1/ingest/reindex")
        assert reindex_res.status_code == 200
        assert reindex_res.json()["status"] == "ok"
        assert len(reindex_res.json()["documents"]) == 3

        # Delete documents via HTTP and verify Qdrant + BM25 cleanup
        for did in (pdf_doc_id, txt_doc_id, url_doc_id):
            del_res = client.delete(f"/api/v1/corpus/{did}")
            assert del_res.status_code == 200
            assert del_res.json()["deleted"] is True

        del_missing = client.delete(f"/api/v1/corpus/{pdf_doc_id}")
        assert del_missing.status_code == 404

        health2 = client.get("/health").json()
        assert health2["corpus_documents"] == 0
        assert health2["qdrant_points"] == 0
        assert health2["bm25_docs"] == 0


def test_chat_sse_and_openai_v1_endpoints_with_rag_and_web_injection(
    isolated_settings: Settings,
    sample_nepal_law_pdf_bytes: bytes,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    isolated_settings.kilocode_api_key = "kilo-secret-key"
    isolated_settings.gemini_api_key = "AIzaFakeGeminiKey123456789012345"
    isolated_settings.tavily_api_key = "tvly-secret-key"

    openai_calls: list[dict[str, Any]] = []
    _install_fake_openai(
        monkeypatch,
        openai_calls,
        reply_text="Under [Nepal Sample Statutes, Sec. 391], rent can rise after 2 years.",
        stream_pieces=["Under ", "[Nepal Sample Statutes, Sec. 391]", ", rent rises after 2 years."],
    )

    # Mock LiveWebSearchService.search so web context injection is deterministic and offline
    async def _fake_web_search(self: Any, req: Any) -> Any:
        from app.schemas import WebSearchResponse, WebSearchResult

        return WebSearchResponse(
            query=req.query,
            provider="tavily",
            results=[
                WebSearchResult(
                    title="Nepal Gazette Rent Amendment Notice",
                    url="https://rajpatra.dop.gov.np/notice/391",
                    snippet="Official gazette summary on Section 391 rent notice.",
                    source="tavily",
                    domain="rajpatra.dop.gov.np",
                )
            ],
            total_results=1,
            latency_ms=12.5,
        )

    monkeypatch.setattr(WakilRAGPipeline, "search_web", _fake_web_search)

    app = create_app(settings=isolated_settings)
    with TestClient(app) as client:
        # Ingest sample PDF first so RAG returns real statutory chunks
        ing = client.post(
            "/api/v1/ingest/file",
            files={"file": ("nepal_sample.pdf", sample_nepal_law_pdf_bytes, "application/pdf")},
            data={"category": "CODES", "act_name": "Nepal Sample Statutes"},
        )
        assert ing.status_code == 200

        # 1. Native POST /api/v1/search/web & POST /api/v1/chat
        web_res = client.post(
            "/api/v1/search/web",
            json={"query": "Section 391 rent Nepal", "max_results": 2},
        )
        assert web_res.status_code == 200
        assert web_res.json()["provider"] == "tavily"
        assert web_res.json()["total_results"] == 1

        chat_res = client.post(
            "/api/v1/chat",
            json={
                "query": "gharbeti le dafa 391 anusar rent badhauna milchha?",
                "use_rag": True,
                "web_search": "always",
                "llm": {"provider": "kilo", "model": "kilo-auto/free"},
            },
        )
        assert chat_res.status_code == 200
        chat_json = chat_res.json()
        assert chat_json["used_rag"] is True
        assert chat_json["used_web_search"] is True
        assert len(chat_json["citations"]) >= 1
        assert len(chat_json["web_results"]) == 1
        assert "Sec. 391" in chat_json["answer"]
        # Verify RAG + Web context was actually injected into upstream LLM prompt
        last_messages = openai_calls[-1]["create"]["messages"]
        user_prompt = last_messages[-1]["content"]
        assert "RETRIEVED NEPAL STATUTORY" in user_prompt
        assert "LIVE WEB SEARCH RESULTS" in user_prompt
        assert "rajpatra.dop.gov.np" in user_prompt

        # 2. Native POST /api/v1/chat/stream (SSE meta + token + done)
        with client.stream(
            "POST",
            "/api/v1/chat/stream",
            json={
                "query": "Section 391 house rent increase",
                "use_rag": True,
                "web_search": "off",
                "llm": {"provider": "kilo", "model": "kilo-auto/free"},
                "stream": True,
            },
        ) as sse_resp:
            assert sse_resp.status_code == 200
            raw_sse = "".join(sse_resp.iter_text())

        events = _parse_sse_events(raw_sse)
        event_names = [e.get("event") for e in events]
        assert "meta" in event_names
        assert "token" in event_names
        assert "done" in event_names
        meta_data = json.loads(next(e["data"] for e in events if e.get("event") == "meta"))
        assert len(meta_data["citations"]) >= 1
        done_data = json.loads(next(e["data"] for e in events if e.get("event") == "done"))
        assert "Sec. 391" in done_data["answer"]

        # 3. OpenAI-compatible GET /v1/models
        v1_models = client.get("/v1/models")
        assert v1_models.status_code == 200
        v1_data = v1_models.json()
        assert v1_data["object"] == "list"
        model_ids = [m["id"] for m in v1_data["data"]]
        assert any(mid.startswith("kilo/") for mid in model_ids)
        assert any(mid.startswith("gemini/") for mid in model_ids)

        # 4. OpenAI-compatible POST /v1/chat/completions (non-streaming + header overrides)
        v1_chat = client.post(
            "/v1/chat/completions",
            headers={
                "X-Wakil-Base-Url": "https://custom.gateway.example/v1",
                "X-Wakil-Web-Search": "always",
                "X-Wakil-Use-Rag": "true",
                "Authorization": "Bearer custom-gateway-token",
            },
            json={
                "model": "openai/gpt-4o-mini",
                "messages": [{"role": "user", "content": "Section 391 house rent notice?"}],
                "stream": False,
            },
        )
        assert v1_chat.status_code == 200
        v1_json = v1_chat.json()
        assert v1_json["object"] == "chat.completion"
        assert "Sec. 391" in v1_json["choices"][0]["message"]["content"]
        assert len(v1_json["wakil_citations"]) >= 1
        assert len(v1_json["wakil_web_results"]) == 1
        assert openai_calls[-1]["init"]["base_url"] == "https://custom.gateway.example/v1"
        assert openai_calls[-1]["init"]["api_key"] == "custom-gateway-token"
        assert openai_calls[-1]["create"]["model"] == "openai/gpt-4o-mini"

        # 5. OpenAI-compatible POST /v1/chat/completions (streaming chat.completion.chunk SSE)
        with client.stream(
            "POST",
            "/v1/chat/completions",
            json={
                "model": "kilo/kilo-auto/free",
                "messages": [{"role": "user", "content": "Explain Section 391 house rent"}],
                "web_search": "off",
                "stream": True,
            },
        ) as v1_stream:
            assert v1_stream.status_code == 200
            raw_v1_sse = "".join(v1_stream.iter_text())

        lines = [ln for ln in raw_v1_sse.splitlines() if ln.startswith("data: ")]
        assert lines[-1] == "data: [DONE]"
        chunks = [json.loads(ln[6:]) for ln in lines[:-1]]
        assert all(c["object"] == "chat.completion.chunk" for c in chunks)
        assembled = "".join(c["choices"][0]["delta"].get("content", "") for c in chunks)
        assert "Sec. 391" in assembled
        assert chunks[-1]["choices"][0]["finish_reason"] == "stop"
