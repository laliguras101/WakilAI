# WakilAI Backend — Nepalese Legal Hybrid RAG & Universal AI Gateway

Production-grade FastAPI backend for **WakilAI**, combining statutory Nepalese legal ingestion, hybrid vector + lexical retrieval (Qdrant + BM25 with Reciprocal Rank Fusion and Romanized Nepglish query expansion), live legal web search (Tavily + DuckDuckGo), and a model-agnostic LLM gateway supporting **KiloAI** (including free models), **Google Gemini**, and **any OpenAI-compatible provider** (OpenAI, OpenRouter, Ollama, LM Studio, vLLM, Groq, etc.).

---

## 1. Local Setup (Python 3.13 + `uv`)

From `D:\Codes\WakilAI\backend` (or `./backend`):

```powershell
# 1. Create isolated Python 3.13 virtual environment (already created if using repo `.venv`)
uv venv --python 3.13 .venv

# 2. Install locked dependencies
uv pip install --python .\.venv\Scripts\python.exe -r requirements.txt

# 3. Configure environment variables
Copy-Item .env.example .env
# Edit .env and add any combination of KILOCODE_API_KEY, GEMINI_API_KEY, OPENAI_API_KEY, TAVILY_API_KEY
```

### Bootstrap Real Nepalese Statutory Corpus

Download or ingest real Nepal legal statutes (Constitution of Nepal 2015/2072, Muluki Civil Code 2074, Muluki Penal Code 2074, Labour Act 2074, Electronic Transactions Act 2063, etc.) into local Qdrant + BM25. By default (`EMBEDDING_PROVIDER=auto`), WakilAI uses local multilingual `fastembed` (`sentence-transformers/paraphrase-multilingual-MiniLM-L12-v2`, 384d) for fast, zero-rate-limit Nepali + English embeddings:

```powershell
# Use local law_commission_pdfs / law_commission_md corpus if present, else fallback URLs
.\.venv\Scripts\python.exe scripts\bootstrap_nepal_laws.py
# Or explicitly pass a local corpus folder:
.\.venv\Scripts\python.exe scripts\bootstrap_nepal_laws.py --source "D:\DATA For WAkil"
```

### Run the FastAPI Server

```powershell
.\.venv\Scripts\python.exe -m uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
```

Interactive OpenAPI docs are available at:
- Swagger UI: `http://localhost:8000/docs`
- Health check: `http://localhost:8000/health`

---

## 2. Core API Endpoints

| Group | Method & Path | Description |
|---|---|---|
| **Health** | `GET /health` | Qdrant, BM25, embedding backend, and provider readiness |
| **Ingestion** | `POST /api/v1/ingest/file` | Upload PDF, DOCX, TXT, or MD legal documents |
| | `POST /api/v1/ingest/path` | Ingest a local file or directory |
| | `POST /api/v1/ingest/url` | Fetch and index a remote PDF or web statute |
| | `POST /api/v1/ingest/bootstrap` | Download and index built-in Nepal statutory corpus |
| | `POST /api/v1/ingest/reindex` | Rebuild Qdrant/BM25 indexes from manifest/raw sources |
| | `GET /api/v1/corpus` | List indexed statutory documents |
| | `DELETE /api/v1/corpus/{doc_id}` | Remove a document from Qdrant, BM25, and manifest |
| **Search & RAG** | `POST /api/v1/rag/search` | Hybrid Qdrant + BM25 + Nepglish RRF statutory search |
| | `POST /api/v1/search/web` | Live web search (Tavily primary, DuckDuckGo fallback) |
| **Legal Chat** | `POST /api/v1/chat` | Grounded Nepalese legal Q&A with citations & web sources |
| | `POST /api/v1/chat/stream` | Server-Sent Events (`meta`, `token`, `done`) |
| **Models** | `GET /api/v1/models` | List available models (`?provider=kilo&free_only=true`) |
| | `POST /api/v1/models/test` | Connectivity test against a selected model/provider |
| **OpenAI Drop-In** | `GET /v1/models` | OpenAI-compatible model catalog |
| | `POST /v1/chat/completions` | OpenAI-compatible RAG + Web Search gateway (`stream` supported) |

---

## 3. Using KiloAI Free Models

Set `KILOCODE_API_KEY` in `.env` (or pass `llm.api_key` per request):

```bash
# Discover free Kilo models live from the gateway
curl "http://localhost:8000/api/v1/models?provider=kilo&free_only=true"

# Ask a Nepalese legal question using Kilo's free auto router
curl -X POST http://localhost:8000/api/v1/chat \
  -H "Content-Type: application/json" \
  -d '{
    "query": "gharbeti le rent badhauna milchha ra kati notice dinuparchha?",
    "web_search": "auto",
    "llm": {
      "provider": "kilo",
      "model": "kilo-auto/free"
    }
  }'
```

You can switch models or providers per request via `llm`:
- **Gemini:** `{"provider": "gemini", "model": "gemini-2.5-flash"}`
- **Ollama (local):** `{"provider": "openai_compatible", "base_url": "http://localhost:11434/v1", "model": "llama3.2", "api_key": "ollama"}`
- **Custom OpenAI-compatible:** `{"provider": "openai_compatible", "base_url": "https://openrouter.ai/api/v1", "model": "...", "api_key": "..."}`

---

## 4. Using the OpenAI-Compatible `/v1` Gateway

Any OpenAI SDK client, Kilo Code, Flutter client, or `curl` script can point its `base_url` to `http://localhost:8000/v1` and automatically receive Hybrid RAG + Live Web Search grounding:

```python
from openai import OpenAI

client = OpenAI(
    base_url="http://localhost:8000/v1",
    api_key="local-or-provider-key",
)

resp = client.chat.completions.create(
    model="kilo/kilo-auto/free",  # also supports gemini/gemini-2.5-flash or openai/<model>
    messages=[
        {"role": "user", "content": "What does the Constitution of Nepal say about right to privacy?"}
    ],
    stream=False,
)
print(resp.choices[0].message.content)
```

Optional request headers for `/v1/chat/completions`:
- `X-Wakil-Use-Rag`: `true` | `false`
- `X-Wakil-Web-Search`: `auto` | `always` | `off`
- `X-Wakil-Base-Url`: custom OpenAI-compatible upstream URL

---

## 5. Docker Compose (FastAPI + Qdrant)

```powershell
cd D:\Codes\WakilAI\backend
Copy-Item .env.example .env
# Populate keys in .env if needed
docker compose up --build -d
```

- Backend API: `http://localhost:8000`
- Qdrant Dashboard: `http://localhost:6333/dashboard`
- Persistent data is mounted to `./data` and Docker volume `qdrant_storage`.

---

## 6. Running Tests

```powershell
cd D:\Codes\WakilAI\backend
.\.venv\Scripts\python.exe -m pytest -v
```
