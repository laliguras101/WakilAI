"""Ingestion and corpus management endpoints (`/api/v1/ingest/*`, `/api/v1/corpus`)."""

from __future__ import annotations

from pathlib import Path
from typing import Optional

from fastapi import APIRouter, Body, Depends, File, Form, HTTPException, UploadFile, status
from pydantic import BaseModel, Field

from app.api.dependencies import get_pipeline
from app.pipeline import WakilRAGPipeline
from app.schemas import (
    CategoryEnum,
    CorpusDocumentMeta,
    IngestPathRequest,
    IngestResponse,
    IngestUrlRequest,
)

router = APIRouter(prefix="/api/v1", tags=["Ingestion & Corpus"])

_SUPPORTED_UPLOAD_EXTENSIONS: frozenset[str] = frozenset(
    {".pdf", ".docx", ".txt", ".md", ".markdown", ".json", ".html", ".htm"}
)


class IngestBootstrapRequest(BaseModel):
    """Optional parameters for bootstrapping built-in or local Nepal statutory corpora."""

    source: Optional[str] = Field(
        default=None,
        description="Optional local statutory folder path (e.g., `D:\\DATA For WAkil`).",
    )
    include_all: bool = Field(
        default=False,
        description="Ingest all discovered documents in `source` instead of curated core statutes.",
    )
    force_reindex: bool = Field(
        default=False,
        description="Re-ingest even if SHA-256 hash already matches corpus manifest.",
    )


class CorpusListResponse(BaseModel):
    """Response payload listing all indexed statutory documents."""

    total: int = 0
    documents: list[CorpusDocumentMeta] = Field(default_factory=list)


class DeleteDocumentResponse(BaseModel):
    """Response payload after deleting a document from Qdrant, BM25, and manifest."""

    status: str
    doc_id: str
    deleted: bool
    message: str = ""


@router.post("/ingest/file", response_model=IngestResponse)
async def ingest_uploaded_file(
    file: UploadFile = File(...),
    category: CategoryEnum = Form(CategoryEnum.OTHER),
    act_name: Optional[str] = Form(None),
    language: Optional[str] = Form(None),
    force_reindex: bool = Form(False),
    pipeline: WakilRAGPipeline = Depends(get_pipeline),
) -> IngestResponse:
    """Upload and index a PDF, DOCX, TXT, MD, HTML, or JSON legal document."""
    file_name = Path(file.filename or "upload.txt").name
    ext = Path(file_name).suffix.lower()
    if ext not in _SUPPORTED_UPLOAD_EXTENSIONS:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=(
                f"Unsupported file extension '{ext or 'none'}'. "
                f"Supported types: {', '.join(sorted(_SUPPORTED_UPLOAD_EXTENSIONS))}"
            ),
        )
    content = await file.read()
    if not content:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Uploaded file is empty.",
        )

    try:
        return await pipeline.ingest_bytes(
            content=content,
            file_name=file_name,
            category=category,
            act_name=act_name,
            language=language,
            force_reindex=force_reindex,
        )
    except ValueError as exc:
        raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail=str(exc)) from exc
    except Exception as exc:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail=str(exc)) from exc


@router.post("/ingest/path", response_model=IngestResponse)
async def ingest_local_path(
    body: IngestPathRequest,
    pipeline: WakilRAGPipeline = Depends(get_pipeline),
) -> IngestResponse:
    """Ingest a local file or directory of Nepalese legal statutes."""
    try:
        return await pipeline.ingest_path(body)
    except FileNotFoundError as exc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(exc)) from exc
    except ValueError as exc:
        raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail=str(exc)) from exc


@router.post("/ingest/url", response_model=IngestResponse)
async def ingest_remote_url(
    body: IngestUrlRequest,
    pipeline: WakilRAGPipeline = Depends(get_pipeline),
) -> IngestResponse:
    """Fetch and index a remote PDF or HTML statute from a URL."""
    try:
        return await pipeline.ingest_url(body)
    except ValueError as exc:
        raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail=str(exc)) from exc
    except Exception as exc:
        raise HTTPException(status_code=status.HTTP_502_BAD_GATEWAY, detail=str(exc)) from exc


@router.post("/ingest/bootstrap", response_model=IngestResponse)
async def bootstrap_nepal_corpus(
    body: Optional[IngestBootstrapRequest] = Body(default=None),
    pipeline: WakilRAGPipeline = Depends(get_pipeline),
) -> IngestResponse:
    """Download/load and index core Nepalese statutory laws into Qdrant and BM25."""
    opts = body or IngestBootstrapRequest()
    try:
        return await pipeline.bootstrap_corpus(
            source=opts.source,
            include_all=opts.include_all,
            force_reindex=opts.force_reindex,
        )
    except FileNotFoundError as exc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(exc)) from exc
    except Exception as exc:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail=str(exc)) from exc


@router.post("/ingest/reindex", response_model=IngestResponse)
async def reindex_corpus(
    pipeline: WakilRAGPipeline = Depends(get_pipeline),
) -> IngestResponse:
    """Rebuild vector and lexical indexes from tracked corpus sources."""
    try:
        return await pipeline.reindex_corpus()
    except Exception as exc:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail=str(exc)) from exc


@router.get("/corpus", response_model=CorpusListResponse)
async def list_corpus_documents(
    pipeline: WakilRAGPipeline = Depends(get_pipeline),
) -> CorpusListResponse:
    """List all indexed statutory documents in the local corpus manifest."""
    docs = await pipeline.list_corpus()
    return CorpusListResponse(total=len(docs), documents=docs)


@router.delete("/corpus/{doc_id}", response_model=DeleteDocumentResponse)
async def delete_corpus_document(
    doc_id: str,
    pipeline: WakilRAGPipeline = Depends(get_pipeline),
) -> DeleteDocumentResponse:
    """Remove a document from the corpus manifest, Qdrant vector store, and BM25 index."""
    outcome = await pipeline.delete_document(doc_id)
    if not outcome.get("deleted"):
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=outcome.get("message") or f"Document '{doc_id}' not found.",
        )
    return DeleteDocumentResponse(
        status=str(outcome.get("status", "deleted")),
        doc_id=doc_id,
        deleted=True,
        message=str(outcome.get("message", f"Deleted document {doc_id}")),
    )
