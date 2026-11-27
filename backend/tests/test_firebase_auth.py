"""Tests for optional Firebase ID token verification (`app/firebase_auth.py`)."""

from __future__ import annotations

from fastapi import Depends, FastAPI
from fastapi.testclient import TestClient

from app.api.main import create_app
from app.config import Settings
from app.firebase_auth import verify_firebase_if_required


def _build_test_app(settings: Settings) -> FastAPI:
    app = FastAPI()
    app.state.settings = settings

    @app.get("/protected")
    async def protected(claims=Depends(verify_firebase_if_required)):
        return {"claims": claims}

    return app


def test_firebase_auth_bypassed_when_not_required():
    app = _build_test_app(
        Settings(firebase_project_id="wakil-3a91d", firebase_auth_required=False)
    )
    client = TestClient(app)
    resp = client.get("/protected")
    assert resp.status_code == 200
    assert resp.json() == {"claims": None}


def test_firebase_auth_enforced_when_required(monkeypatch):
    monkeypatch.setattr(
        "app.firebase_auth.verify_firebase_id_token",
        lambda token, project_id: {"sub": "uid-123", "aud": project_id, "tok": token},
    )
    app = _build_test_app(
        Settings(firebase_project_id="wakil-3a91d", firebase_auth_required=True)
    )
    client = TestClient(app)

    missing = client.get("/protected")
    assert missing.status_code == 401

    ok = client.get("/protected", headers={"Authorization": "Bearer valid.jwt.token"})
    assert ok.status_code == 200
    assert ok.json()["claims"]["sub"] == "uid-123"
    assert ok.json()["claims"]["aud"] == "wakil-3a91d"


def test_main_app_keeps_health_open_and_gates_api_only_when_enabled(tmp_path):
    settings = Settings(
        qdrant_path=tmp_path / "qdrant",
        bm25_path=tmp_path / "bm25.json",
        manifest_path=tmp_path / "manifest.json",
        raw_data_dir=tmp_path / "raw",
        embedding_provider="hashed_tfidf",
        firebase_project_id="wakil-3a91d",
        firebase_auth_required=True,
    )
    with TestClient(create_app(settings=settings)) as client:
        assert client.get("/health").status_code == 200
        assert client.get("/api/v1/corpus").status_code == 401
