"""Retrieval helpers: FAQ priority + ticket context filter + thresholds."""
from __future__ import annotations

from typing import Any

from app.context import (
    catalog_from_docs,
    contexts_from_hits,
    detect_question_contexts,
    doc_labels,
    is_procedural_question,
    shares_context,
)
from app.index_store import Doc, IndexStore
from app.synthesize import build_justification

# Relative BM25 threshold for similar tickets (fraction of the best ticket score
# among context-filtered candidates). Absolute floor avoids noise on tiny scores.
TICKET_SCORE_RATIO = 0.45
TICKET_SCORE_FLOOR = 3.0
FAQ_SCORE_FLOOR = 1.0


def retrieve_faq(
    store: IndexStore,
    question: str,
    *,
    limit: int = 5,
    seed_excerpts: list[dict[str, Any]] | None = None,
) -> tuple[list[dict[str, Any]], dict[str, Any]]:
    seed_by_id = {e.get("doc_id"): e for e in (seed_excerpts or []) if e.get("doc_id")}
    catalog = catalog_from_docs(d for d in store.docs if d.kind == "faq")
    detected = detect_question_contexts(question, catalog)

    raw = store.search(question, kinds=["faq"], limit=max(limit * 4, 12))
    if not detected and raw:
        detected = contexts_from_hits(raw, top_n=3)

    boosted: list[tuple[Doc, float, str]] = []
    excluded: list[dict[str, Any]] = []
    for doc, score in raw:
        if score < FAQ_SCORE_FLOOR:
            excluded.append({"doc_id": doc.doc_id, "reason": "below_faq_floor", "score": score})
            continue
        in_context = shares_context(doc, detected) if detected else True
        # Prefer in-context docs; keep a few out-of-context only if pool is empty later.
        adj = score * (1.35 if in_context and detected else 1.0)
        # Slight boost for confirmed technical markers in body (generic, language-based).
        body_l = (doc.body or "").lower()
        if "confirmado" in body_l:
            adj *= 1.1
        if "por validar" in body_l:
            adj *= 0.85
        q_l = question.lower()
        if "loop" in q_l and "loop" in body_l:
            adj *= 1.25
        if is_procedural_question(question) and any(
            tok in body_l for tok in ("systemctl", "chown", "procedimento", "pre>")
        ):
            adj *= 1.15
        boosted.append((doc, adj, "in_context" if in_context else "out_of_context"))

    in_ctx = [(d, s, t) for d, s, t in boosted if t == "in_context"]
    out_ctx = [(d, s, t) for d, s, t in boosted if t == "out_of_context"]
    chosen = in_ctx if in_ctx else out_ctx
    chosen.sort(key=lambda x: x[1], reverse=True)

    ranked: list[dict[str, Any]] = []
    seen: set[str] = set()
    for doc, score, tag in chosen[:limit]:
        source = "otobo_seed" if doc.doc_id in seed_by_id else "index"
        ranked.append(
            {
                "doc_id": doc.doc_id,
                "kind": doc.kind,
                "number": doc.number,
                "title": doc.title,
                "category": doc.category,
                "excerpt": doc.body[:1200],
                "body": doc.body[:8000],
                "url": doc.url,
                "meta": {
                    **(doc.meta or {}),
                    "score": score,
                    "source": source,
                    "context_match": tag,
                    "labels": sorted(doc_labels(doc)),
                },
                "justification": build_justification(
                    question,
                    title=doc.title,
                    body=doc.body,
                    number=doc.number,
                    score=float(score),
                    source=source,
                ),
            }
        )
        seen.add(doc.doc_id)

    for doc_id, seed in seed_by_id.items():
        if doc_id in seen:
            continue
        body = seed.get("body") or seed.get("excerpt") or ""
        ranked.append(
            {
                **seed,
                "meta": {**(seed.get("meta") or {}), "source": "otobo_seed"},
                "justification": build_justification(
                    question,
                    title=seed.get("title") or "",
                    body=body,
                    number=seed.get("number") or "",
                    score=None,
                    source="otobo_seed",
                ),
            }
        )

    debug = {
        "detected_contexts": sorted(detected),
        "catalog_size": len(catalog),
        "faq_raw": len(raw),
        "faq_in_context": len(in_ctx),
        "faq_out_of_context": len(out_ctx),
        "faq_excluded": excluded[:20],
        "procedural_question": is_procedural_question(question),
        "returned_faq": [x.get("doc_id") for x in ranked[:limit]],
    }
    return ranked[:limit], debug


def retrieve_tickets(
    store: IndexStore,
    question: str,
    *,
    contexts: set[str],
    limit: int = 5,
) -> tuple[list[dict[str, Any]], dict[str, Any]]:
    if not contexts:
        return [], {
            "ticket_raw": 0,
            "ticket_kept": 0,
            "ticket_excluded": [],
            "threshold": None,
            "threshold_ratio": TICKET_SCORE_RATIO,
            "threshold_floor": TICKET_SCORE_FLOOR,
            "reason": "no_product_context",
        }

    raw = store.search(question, kinds=["ticket"], limit=max(limit * 8, 24))
    excluded: list[dict[str, Any]] = []
    filtered: list[tuple[Doc, float]] = []

    for doc, score in raw:
        # Product/context filter BEFORE relevance ranking: never pad with
        # other-product tickets just because BM25 found generic lexical overlap.
        if not shares_context(doc, contexts):
            excluded.append(
                {
                    "doc_id": doc.doc_id,
                    "number": doc.number,
                    "reason": "context_mismatch",
                    "score": score,
                    "labels": sorted(doc_labels(doc)),
                }
            )
            continue
        filtered.append((doc, score))

    if not filtered:
        return [], {
            "ticket_raw": len(raw),
            "ticket_kept": 0,
            "ticket_excluded": excluded[:30],
            "threshold": None,
            "threshold_ratio": TICKET_SCORE_RATIO,
            "threshold_floor": TICKET_SCORE_FLOOR,
            "reason": "no_in_context_tickets",
        }

    best = max(score for _doc, score in filtered)
    threshold = max(TICKET_SCORE_FLOOR, best * TICKET_SCORE_RATIO)
    kept: list[tuple[Doc, float]] = []
    for doc, score in filtered:
        if score < threshold:
            excluded.append(
                {
                    "doc_id": doc.doc_id,
                    "number": doc.number,
                    "reason": "below_threshold",
                    "score": score,
                    "threshold": threshold,
                }
            )
            continue
        kept.append((doc, score))

    kept.sort(key=lambda x: x[1], reverse=True)
    results: list[dict[str, Any]] = []
    for doc, score in kept[:limit]:
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
                "meta": {**(doc.meta or {}), "labels": sorted(doc_labels(doc))},
                "justification": build_justification(
                    question,
                    title=doc.title,
                    body=doc.body,
                    number=doc.number,
                    score=float(score),
                    source="index",
                ),
            }
        )

    return results, {
        "ticket_raw": len(raw),
        "ticket_kept": len(results),
        "ticket_excluded": excluded[:30],
        "threshold": threshold,
        "threshold_ratio": TICKET_SCORE_RATIO,
        "threshold_floor": TICKET_SCORE_FLOOR,
        "best_score": best,
        "returned_tickets": [r["doc_id"] for r in results],
        "contexts_applied": sorted(contexts),
    }
