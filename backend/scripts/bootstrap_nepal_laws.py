"""Standalone CLI to acquire and index real Nepalese statutory documents into Qdrant and BM25."""

from __future__ import annotations

import argparse
import asyncio
import json
import sys
from pathlib import Path

# Ensure `backend/` is importable regardless of current working directory
_BACKEND_DIR = Path(__file__).resolve().parent.parent
if str(_BACKEND_DIR) not in sys.path:
    sys.path.insert(0, str(_BACKEND_DIR))

from app.config import get_settings
from app.ingestion.pipeline import IngestionPipeline


def _parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Bootstrap real Nepalese statutory laws into WakilAI Qdrant + BM25 indexes.",
    )
    parser.add_argument(
        "--source",
        type=str,
        default=None,
        help=r"Optional local corpus directory (e.g., D:\DATA For WAkil). Auto-detected if present.",
    )
    parser.add_argument(
        "--all",
        action="store_true",
        dest="include_all",
        help="Ingest all discovered documents in --source rather than only curated core statutes.",
    )
    parser.add_argument(
        "--no-download",
        action="store_true",
        help="Skip downloading verified public statutory PDFs into data/raw.",
    )
    parser.add_argument(
        "--force-reindex",
        action="store_true",
        help="Force re-indexing even when SHA-256 already exists in corpus_manifest.json.",
    )
    parser.add_argument(
        "--json",
        action="store_true",
        help="Emit full JSON summary instead of human-readable output.",
    )
    return parser.parse_args()


async def _run_bootstrap(args: argparse.Namespace) -> int:
    from app.rag.hybrid_retriever import HybridRetriever

    settings = get_settings()
    settings.ensure_data_dirs()
    retriever = HybridRetriever(settings=settings)
    pipeline = IngestionPipeline(settings=settings, retriever=retriever)

    try:
        result = await pipeline.bootstrap_nepal_corpus(
            source=args.source,
            include_all=args.include_all,
            download_public=not args.no_download,
            force_reindex=args.force_reindex,
        )
        stats = retriever.get_stats()
        all_docs = pipeline.list_documents()

        if args.json:
            payload = {
                "result": result.model_dump(mode="json"),
                "retriever_stats": stats,
                "total_manifest_documents": len(all_docs),
            }
            print(json.dumps(payload, indent=2, ensure_ascii=False))
        else:
            print(f"Status        : {result.status}")
            print(f"Message       : {result.message}")
            print(f"New Chunks    : {result.chunks_indexed}")
            print(f"Manifest Docs : {len(all_docs)}")
            print(f"Qdrant Points : {stats.get('qdrant_points', 0)} ({stats.get('qdrant_collection')})")
            print(f"BM25 Chunks   : {stats.get('bm25_docs', 0)}")
            print(f"Embeddings    : {stats.get('embedding_provider')} / {stats.get('embedding_model')} ({stats.get('embedding_dim')}d)")
            print("\nTracked Documents:")
            for doc in all_docs:
                print(
                    f"  - [{doc.category.value}] {doc.title} "
                    f"({doc.language}, {doc.chunks_count} chunks, id={doc.doc_id})"
                )
            if result.errors:
                print("\nWarnings / Non-fatal Errors:")
                for err in result.errors:
                    print(f"  ! {err}")

        return 0 if all_docs else 1
    finally:
        await retriever.aclose()


def main() -> int:
    args = _parse_args()
    return asyncio.run(_run_bootstrap(args))


if __name__ == "__main__":
    raise SystemExit(main())
