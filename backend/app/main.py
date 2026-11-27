"""Top-level ASGI entrypoint (`uvicorn app.main:app`) re-exporting the FastAPI app."""

from app.api.main import app, create_app

__all__ = ["app", "create_app"]
