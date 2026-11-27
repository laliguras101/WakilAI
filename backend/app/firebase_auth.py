"""Optional Firebase ID token verification for FastAPI routes."""

from __future__ import annotations

import asyncio
from functools import lru_cache
from typing import Any, Optional

from fastapi import Depends, HTTPException, Request, status
from google.auth.transport.requests import Request as GoogleAuthRequest
from google.oauth2 import id_token

from app.config import Settings, get_settings


@lru_cache(maxsize=1)
def _google_request_adapter() -> GoogleAuthRequest:
    """Return a cached HTTP transport adapter for Google public certificate fetches."""
    return GoogleAuthRequest()


def verify_firebase_id_token(token: str, project_id: str) -> dict[str, Any]:
    """Verify a Firebase Auth ID JWT synchronously against Google's public certs."""
    claims = id_token.verify_firebase_token(
        token,
        _google_request_adapter(),
        audience=project_id,
    )
    if not isinstance(claims, dict) or not claims.get("sub"):
        raise ValueError("Invalid Firebase token payload.")
    return claims


async def verify_firebase_if_required(
    request: Request,
) -> Optional[dict[str, Any]]:
    """Enforce Firebase Auth only when `FIREBASE_AUTH_REQUIRED=true` in settings."""
    settings = getattr(request.app.state, "settings", None) or get_settings()
    if not settings.firebase_auth_required:
        return None

    project_id = (settings.firebase_project_id or "").strip()
    if not project_id:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="FIREBASE_AUTH_REQUIRED=true requires FIREBASE_PROJECT_ID.",
        )

    auth_header = request.headers.get("Authorization", "").strip()
    if not auth_header.lower().startswith("bearer "):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Missing Bearer Firebase ID token.",
        )

    token = auth_header[7:].strip()
    if not token:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Empty Bearer Firebase ID token.",
        )

    try:
        return await asyncio.to_thread(verify_firebase_id_token, token, project_id)
    except Exception as exc:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=f"Invalid Firebase ID token: {exc}",
        ) from exc
