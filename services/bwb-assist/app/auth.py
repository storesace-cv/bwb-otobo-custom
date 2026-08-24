from __future__ import annotations

from typing import Any

from fastapi import Header, HTTPException, Request

from app.config import get_settings


def _client_ip(request: Request) -> str:
    forwarded = request.headers.get("x-forwarded-for") or ""
    if forwarded:
        return forwarded.split(",")[0].strip()
    if request.client:
        return request.client.host or ""
    return ""


def require_bearer(request: Request, authorization: str | None = Header(default=None)) -> None:
    settings = get_settings()
    if not settings.bearer:
        raise HTTPException(status_code=503, detail="bearer_not_configured")

    ip = _client_ip(request)
    # Local sync/admin always allowed; remote callers must match allowlist when set.
    if settings.allowed_ips and ip not in settings.allowed_ips and ip not in {"127.0.0.1", "::1"}:
        raise HTTPException(status_code=403, detail="forbidden_ip")

    token = ""
    if authorization and authorization.lower().startswith("bearer "):
        token = authorization[7:].strip()
    if not token or token != settings.bearer:
        raise HTTPException(status_code=401, detail="unauthorized")


def log_safe(event: str, **fields: Any) -> dict[str, Any]:
    """Structured log payload without full document bodies."""
    return {"event": event, **fields}
