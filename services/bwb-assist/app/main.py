from __future__ import annotations

import logging
from typing import Any, Literal

import httpx
from fastapi import Depends, FastAPI, HTTPException
from pydantic import BaseModel, Field

from app.auth import log_safe, require_bearer
from app.config import get_settings
from app.index_store import Doc, IndexStore
from app.synthesize import synthesize

logger = logging.getLogger("bwb-assist")
logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")

app = FastAPI(title="BWB Assist", version="1.0.0")
_store: IndexStore | None = None


def store() -> IndexStore:
    global _store
    if _store is None:
        settings = get_settings()
        settings.data_dir.mkdir(parents=True, exist_ok=True)
        _store = IndexStore(settings.data_dir)
    return _store


class ExcerptIn(BaseModel):
    doc_id: str
    kind: Literal["faq", "ticket"] = "faq"
    number: str = ""
    title: str = ""
    category: str = ""
    excerpt: str = ""
    body: str = ""
    url: str = ""
    meta: dict[str, Any] = Field(default_factory=dict)


class AssistFAQRequest(BaseModel):
    question: str = Field(min_length=2, max_length=2000)
    excerpts: list[ExcerptIn] = Field(default_factory=list)
    limit: int = Field(default=5, ge=1, le=20)
    use_index: bool = True


class AssistSearchRequest(BaseModel):
    question: str = Field(min_length=2, max_length=2000)
    kinds: list[Literal["faq", "ticket"]] = Field(default_factory=lambda: ["faq"])
    limit: int = Field(default=8, ge=1, le=30)


class IndexDocsRequest(BaseModel):
    kind: Literal["faq", "ticket"]
    docs: list[ExcerptIn]


@app.get("/health")
def health() -> dict[str, Any]:
    settings = get_settings()
    st = store()
    return {
        "ok": True,
        "docs": len(st.docs),
        "ollama_enabled": settings.ollama_enabled,
        "model": settings.ollama_model if settings.ollama_enabled else None,
    }


@app.post("/v1/assist/faq")
async def assist_faq(payload: AssistFAQRequest, _: None = Depends(require_bearer)) -> dict[str, Any]:
    question = payload.question.strip()
    excerpts = [e.model_dump() for e in payload.excerpts]

    # Optional BM25 re-rank / fill from local index when OTOBO sent few hits.
    if payload.use_index:
        hits = store().search(question, kinds=["faq"], limit=payload.limit)
        for doc, score in hits:
            if any(x.get("doc_id") == doc.doc_id for x in excerpts):
                continue
            excerpts.append(
                {
                    "doc_id": doc.doc_id,
                    "kind": doc.kind,
                    "number": doc.number,
                    "title": doc.title,
                    "category": doc.category,
                    "excerpt": doc.body[:800],
                    "body": doc.body[:2000],
                    "url": doc.url,
                    "meta": {**(doc.meta or {}), "score": score},
                }
            )
        excerpts = excerpts[: payload.limit]

    summary, mode = await synthesize(question, excerpts)
    cited = [e.get("doc_id") for e in excerpts if e.get("doc_id")]
    logger.info("%s", log_safe("assist_faq", mode=mode, hits=len(excerpts), cited=cited))
    return {
        "ok": True,
        "summary": summary,
        "mode": mode,
        "excerpts": excerpts,
        "cited_ids": cited,
    }


@app.post("/v1/assist/search")
async def assist_search(payload: AssistSearchRequest, _: None = Depends(require_bearer)) -> dict[str, Any]:
    hits = store().search(payload.question, kinds=list(payload.kinds), limit=payload.limit)
    results = []
    for doc, score in hits:
        results.append(
            {
                "doc_id": doc.doc_id,
                "kind": doc.kind,
                "number": doc.number,
                "title": doc.title,
                "category": doc.category,
                "excerpt": doc.body[:800],
                "url": doc.url,
                "score": score,
                "meta": doc.meta,
            }
        )
    logger.info("%s", log_safe("assist_search", kinds=payload.kinds, hits=len(results)))
    return {"ok": True, "results": results}


@app.post("/v1/index/replace")
async def index_replace(payload: IndexDocsRequest, _: None = Depends(require_bearer)) -> dict[str, Any]:
    docs = [
        Doc(
            doc_id=d.doc_id,
            kind=payload.kind,
            title=d.title,
            number=d.number,
            category=d.category,
            body=(d.body or d.excerpt or "")[:20000],
            url=d.url,
            meta=d.meta or {},
        )
        for d in payload.docs
    ]
    count = store().replace_kind(payload.kind, docs)
    logger.info("%s", log_safe("index_replace", kind=payload.kind, count=count))
    return {"ok": True, "kind": payload.kind, "count": count}


class SyncRequest(BaseModel):
    kinds: list[Literal["faq", "ticket"]] = Field(default_factory=lambda: ["faq"])


@app.post("/v1/index/sync-from-otobo")
async def sync_from_otobo(
    payload: SyncRequest | None = None,
    _: None = Depends(require_bearer),
) -> dict[str, Any]:
    kinds = (payload.kinds if payload else None) or ["faq"]
    settings = get_settings()
    if not settings.otobo_index_url or not settings.otobo_index_token:
        raise HTTPException(status_code=503, detail="otobo_index_not_configured")

    synced: dict[str, int] = {}
    async with httpx.AsyncClient(timeout=180.0) as client:
        for kind in kinds:
            params = {"Action": "PublicBWBAssistIndex", "Kind": kind}
            response = await client.get(
                settings.otobo_index_url,
                params=params,
                headers={"Authorization": f"Bearer {settings.otobo_index_token}"},
            )
            if response.status_code != 200:
                raise HTTPException(status_code=502, detail=f"otobo_index_{kind}_http_{response.status_code}")
            data = response.json()
            if not data.get("ok"):
                raise HTTPException(status_code=502, detail=f"otobo_index_{kind}_error")
            docs_raw = data.get("docs") or []
            docs = [
                Doc(
                    doc_id=str(item.get("doc_id") or item.get("id")),
                    kind=kind,
                    title=item.get("title") or "",
                    number=item.get("number") or "",
                    category=item.get("category") or "",
                    body=(item.get("body") or "")[:20000],
                    url=item.get("url") or "",
                    meta=item.get("meta") or {},
                )
                for item in docs_raw
                if item.get("doc_id") or item.get("id")
            ]
            synced[kind] = store().replace_kind(kind, docs)

    logger.info("%s", log_safe("sync_from_otobo", synced=synced))
    return {"ok": True, "synced": synced}
