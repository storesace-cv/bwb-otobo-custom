from __future__ import annotations

import json
import re
from dataclasses import asdict, dataclass
from pathlib import Path
from typing import Iterable

from rank_bm25 import BM25Okapi


_TOKEN_RE = re.compile(r"[a-z0-9àáâãäåæçèéêëìíîïñòóôõöùúûüýÿ]+", re.I)


def tokenize(text: str) -> list[str]:
    return [t.lower() for t in _TOKEN_RE.findall(text or "")]


@dataclass
class Doc:
    doc_id: str
    kind: str  # faq | ticket
    title: str
    number: str
    category: str
    body: str
    url: str
    meta: dict

    @property
    def search_text(self) -> str:
        return " ".join(
            [
                self.number or "",
                self.title or "",
                self.category or "",
                self.body or "",
                " ".join(str(v) for v in (self.meta or {}).values()),
            ]
        )


class IndexStore:
    def __init__(self, data_dir: Path) -> None:
        self.data_dir = data_dir
        self.data_dir.mkdir(parents=True, exist_ok=True)
        self.path = self.data_dir / "index.json"
        self.docs: list[Doc] = []
        self._bm25: BM25Okapi | None = None
        self._corpus_tokens: list[list[str]] = []
        self.load()

    def load(self) -> None:
        if not self.path.exists():
            self.docs = []
            self._rebuild()
            return
        raw = json.loads(self.path.read_text(encoding="utf-8"))
        self.docs = [Doc(**item) for item in raw.get("docs", [])]
        self._rebuild()

    def save(self) -> None:
        payload = {"docs": [asdict(d) for d in self.docs]}
        self.path.write_text(json.dumps(payload, ensure_ascii=False), encoding="utf-8")

    def replace_kind(self, kind: str, docs: Iterable[Doc]) -> int:
        kept = [d for d in self.docs if d.kind != kind]
        new_docs = list(docs)
        self.docs = kept + new_docs
        self._rebuild()
        self.save()
        return len(new_docs)

    def _rebuild(self) -> None:
        self._corpus_tokens = [tokenize(d.search_text) for d in self.docs]
        if self._corpus_tokens and any(self._corpus_tokens):
            self._bm25 = BM25Okapi(self._corpus_tokens)
        else:
            self._bm25 = None

    def search(self, query: str, *, kinds: list[str] | None = None, limit: int = 8) -> list[tuple[Doc, float]]:
        if not self.docs or not self._bm25:
            return []
        tokens = tokenize(query)
        if not tokens:
            return []
        scores = self._bm25.get_scores(tokens)
        ranked: list[tuple[Doc, float]] = []
        for doc, score in zip(self.docs, scores):
            if kinds and doc.kind not in kinds:
                continue
            if score <= 0:
                continue
            ranked.append((doc, float(score)))
        ranked.sort(key=lambda x: x[1], reverse=True)
        return ranked[:limit]
