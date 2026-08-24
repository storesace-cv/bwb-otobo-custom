from __future__ import annotations

import httpx

from app.config import get_settings


async def ollama_chat(system: str, user: str, timeout: float = 60.0) -> str | None:
    settings = get_settings()
    if not settings.ollama_enabled:
        return None
    payload = {
        "model": settings.ollama_model,
        "stream": False,
        "messages": [
            {"role": "system", "content": system},
            {"role": "user", "content": user},
        ],
        "options": {"temperature": 0.2},
    }
    try:
        async with httpx.AsyncClient(timeout=timeout) as client:
            response = await client.post(f"{settings.ollama_url}/api/chat", json=payload)
            response.raise_for_status()
            data = response.json()
            return (data.get("message") or {}).get("content") or None
    except Exception:
        return None
