"""Generic product/context detection from FAQ/ticket metadata and question text.

Product contexts come from number prefixes and category-path segments — not from
every title token — so similar-ticket filtering stays product-scoped.
"""
from __future__ import annotations

import re
import unicodedata
from typing import Any, Iterable

from app.index_store import Doc, tokenize

_STOP = {
    "a", "o", "os", "as", "e", "em", "no", "na", "nos", "nas", "de", "do", "da", "dos", "das",
    "com", "para", "por", "que", "se", "um", "uma", "uns", "umas", "está", "esta", "este",
    "esse", "essa", "the", "and", "or", "of", "to", "in", "on", "at", "is", "are", "item",
    "id", "faq", "ticket", "internal", "agent", "documentação", "documentacao", "interna",
    "helpdesk", "manual", "artigos", "categoria", "ambiente", "grafico", "gráfico", "tecnica",
    "técnica", "arquitectura", "arquitetura", "operacao", "operação", "instalacao", "instalação",
    "configuracao", "configuração", "processo", "original", "linux", "windows", "software",
    "utilizador", "usuarios", "utilizadores", "sessao", "sessão", "arranque", "boot", "erro",
    "erros", "problema", "procedimentos", "procedimento", "comandos", "comando", "root",
    "bwb", "closed", "queue", "fila", "domain", "cliente", "customer", "novos", "novo",
    "funcionarios", "fwd", "email", "formacao", "formação", "backup", "backups", "copias",
    "recuperacao", "suporte", "estado", "vendas", "consumo", "saldo", "display", "contexto",
    "criar", "configurar", "instalar", "pen", "tec", "uid", "run", "new", "startup", "shm",
    "mit", "x11", "xfce", "pos", "lightdm", "autologin", "hardlock", "postgres", "disco",
}

_PATH_STOP = {
    "documentacaointerna",
    "documentacao",
    "interna",
    "documentaçãointerna",
    "ajuda",
    "faq",
    "kb",
    "base",
    "conhecimento",
    "bwbin",
    "zsangolain",
    "zspostmaster",
    "aplicacoeseintegracoes",
    "arquitecturatecnica",
    "comunicacoeseficheiros",
    "configuracaoeadministracao",
    "equipamentoseperifericos",
    "fiscalidadeedocumentos",
    "instalacao",
    "inventarioestock",
    "operacaoevendas",
}


def normalize_label(value: str) -> str:
    text = (value or "").strip().lower()
    text = unicodedata.normalize("NFKD", text)
    text = "".join(ch for ch in text if not unicodedata.combining(ch))
    text = re.sub(r"[^a-z0-9]+", "", text)
    return text


def labels_from_number(number: str) -> set[str]:
    raw = (number or "").strip().upper()
    if not raw:
        return set()
    labels: set[str] = set()
    parts = [p for p in re.split(r"[-_]+", raw) if p]
    if parts:
        head = normalize_label(parts[0])
        if head and head not in _STOP:
            labels.add(head)
        if len(parts) >= 2:
            combo = normalize_label(parts[0] + parts[1])
            if combo and combo not in _STOP:
                labels.add(combo)
    return labels


def labels_from_category_path(path: str) -> set[str]:
    """Product folders in the FAQ tree (e.g. PTcert, NET-bo), not leaf topic names."""
    labels: set[str] = set()
    # Prefer splitting on hierarchy separators; avoid exploding camel/compound blobs.
    for chunk in re.split(r"[>/|]+", str(path or "")):
        chunk = chunk.strip()
        if not chunk:
            continue
        # Also split "Documentação interna - PTcert" style.
        for sub in re.split(r"\s*[-–—]\s*", chunk):
            norm = normalize_label(sub)
            if len(norm) < 4 or norm in _STOP or norm in _PATH_STOP:
                continue
            # Drop long concatenated path leftovers without separators.
            if len(norm) > 24:
                continue
            labels.add(norm)
    return labels


def labels_from_title_product(title: str) -> set[str]:
    """Only keep title tokens that look like product codes/names (length>=5 or mixed)."""
    labels: set[str] = set()
    for tok in tokenize(title or ""):
        norm = normalize_label(tok)
        if norm in _STOP or norm in _PATH_STOP:
            continue
        if len(norm) >= 5 or (len(norm) >= 4 and any(ch.isdigit() for ch in norm)):
            labels.add(norm)
    return labels


def product_labels(doc: Doc) -> set[str]:
    meta = doc.meta or {}
    labels: set[str] = set()
    labels |= labels_from_number(doc.number)
    labels |= labels_from_category_path(doc.category)
    labels |= labels_from_category_path(str(meta.get("category_path") or ""))
    if doc.kind == "ticket":
        labels |= labels_from_title_product(doc.title)
    for key in ("product", "service"):
        val = meta.get(key)
        if val:
            labels |= labels_from_category_path(str(val))
    # Explicit labels: only keep short product-like ones (ignore noisy indexer dumps).
    explicit = meta.get("labels") or meta.get("context_labels") or []
    if isinstance(explicit, (list, tuple, set)):
        for item in explicit:
            norm = normalize_label(str(item))
            if 3 <= len(norm) <= 16 and norm not in _STOP and norm not in _PATH_STOP:
                # Prefer items that look like product codes.
                if len(norm) >= 4:
                    labels.add(norm)
    return labels


def doc_labels(doc: Doc) -> set[str]:
    return product_labels(doc)


def catalog_from_docs(docs: Iterable[Doc]) -> set[str]:
    catalog: set[str] = set()
    for doc in docs:
        if doc.kind != "faq":
            continue
        catalog |= product_labels(doc)
    return catalog


def detect_question_contexts(question: str, catalog: set[str]) -> set[str]:
    if not catalog:
        return set()
    q_norm = normalize_label(question)
    q_tokens = {normalize_label(t) for t in tokenize(question) if len(t) >= 3}
    found: set[str] = set()
    for label in catalog:
        if len(label) < 3 or label in _STOP:
            continue
        if label in q_tokens:
            found.add(label)
            continue
        # Whole label as compact substring only for longer product names (>=5),
        # avoiding accidental hits on short fragments inside Portuguese words.
        if len(label) >= 5 and label in q_norm:
            found.add(label)
            continue
        for tok in q_tokens:
            if len(tok) < 4:
                continue
            shorter, longer = (label, tok) if len(label) <= len(tok) else (tok, label)
            if len(shorter) >= 3 and longer.startswith(shorter) and len(longer) <= len(shorter) + 6:
                found.add(label)
                break
    return found


def contexts_from_hits(hits: list[tuple[Doc, float]], *, top_n: int = 3) -> set[str]:
    labels: set[str] = set()
    for doc, _score in hits[:top_n]:
        labels |= product_labels(doc)
    return labels


def shares_context(doc: Doc, contexts: set[str]) -> bool:
    if not contexts:
        return True
    doc_labs = product_labels(doc)
    if doc_labs & contexts:
        return True
    for ctx in contexts:
        for lab in doc_labs:
            if len(ctx) < 3 or len(lab) < 3:
                continue
            shorter, longer = (ctx, lab) if len(ctx) <= len(lab) else (lab, ctx)
            if len(shorter) >= 3 and longer.startswith(shorter) and len(longer) <= len(shorter) + 6:
                return True
    return False


def significant_overlap(question: str, doc: Doc, *, min_shared: int = 2) -> bool:
    q = {
        normalize_label(t)
        for t in tokenize(question)
        if len(t) >= 4 and normalize_label(t) not in _STOP
    }
    d = {
        normalize_label(t)
        for t in tokenize(doc.search_text)
        if len(t) >= 4 and normalize_label(t) not in _STOP
    }
    return len(q & d) >= min_shared


def is_procedural_question(question: str) -> bool:
    patterns = [
        r"\bo que fazer\b",
        r"\bcomo resolver\b",
        r"\bcomo corrigir\b",
        r"\bcomo diagnosticar\b",
        r"\bprocedimento",
        r"\bprocedimentos\b",
        r"\bcomandos?\b",
        r"\bpasso a passo\b",
        r"\bquais são os passos\b",
        r"\bhow to\b",
        r"\bfix\b",
    ]
    text = question.lower()
    return any(re.search(pat, text) for pat in patterns)


def debug_payload(**fields: Any) -> dict[str, Any]:
    return {k: v for k, v in fields.items() if v is not None}
