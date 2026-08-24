from __future__ import annotations

import os
from functools import lru_cache
from pathlib import Path


def _bool(value: str | None, default: bool = False) -> bool:
    if value is None or value == "":
        return default
    return value.strip().lower() in {"1", "true", "yes", "on"}


@lru_cache
def get_settings() -> "Settings":
    return Settings()


class Settings:
    def __init__(self) -> None:
        self.host = os.getenv("BWB_ASSIST_HOST", "127.0.0.1")
        self.port = int(os.getenv("BWB_ASSIST_PORT", "18100"))
        self.bearer = (os.getenv("BWB_ASSIST_BEARER") or "").strip()
        allowed = os.getenv("BWB_ASSIST_ALLOWED_IPS", "")
        self.allowed_ips = {ip.strip() for ip in allowed.split(",") if ip.strip()}
        self.ollama_url = os.getenv("BWB_ASSIST_OLLAMA_URL", "http://127.0.0.1:11434").rstrip("/")
        self.ollama_model = os.getenv("BWB_ASSIST_OLLAMA_MODEL", "qwen2.5:7b-instruct")
        self.ollama_enabled = _bool(os.getenv("BWB_ASSIST_OLLAMA_ENABLED"), False)
        self.data_dir = Path(os.getenv("BWB_ASSIST_DATA_DIR", "/var/lib/bwb-assist"))
        self.otobo_index_url = (os.getenv("OTOBO_ASSIST_INDEX_URL") or "").rstrip("/")
        self.otobo_index_token = (os.getenv("OTOBO_ASSIST_INDEX_TOKEN") or "").strip()
