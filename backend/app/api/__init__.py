"""FastAPI routers and ASGI application factory for WakilAI backend."""

from app.api.main import app, create_app

__all__ = ["app", "create_app"]
