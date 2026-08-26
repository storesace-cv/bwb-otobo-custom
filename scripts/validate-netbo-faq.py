#!/usr/bin/env python3
"""Validate db/netbo-content (manifest, tokens, assets, safety markers)."""
from __future__ import annotations

import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CONTENT = ROOT / "db" / "netbo-content"
TOKEN_RE = re.compile(r"@@NETBO_IMAGE:([^@]+)@@")
EDITORIAL_RE = re.compile(
    r"inserir captura|\[inserir captura|página craft aqui|TODO:|FIXME:|file://|C:\\\\Users\\\\|/Users/jorge",
    re.I,
)
SECRET_RE = re.compile(
    r"BEGIN (OPENSSH|RSA|EC|DSA) PRIVATE KEY|api[_-]?key\s*[:=]\s*['\"]?[A-Za-z0-9_\-]{16,}",
    re.I,
)


def main() -> int:
    manifest_path = CONTENT / "manifest.json"
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    articles = manifest["articles"]
    errors: list[str] = []
    warnings: list[str] = []

    numbers = [a["number"] for a in articles]
    if len(numbers) != 17:
        errors.append(f"Esperados 17 artigos, encontrados {len(numbers)}")
    if len(set(numbers)) != len(numbers):
        errors.append("f_number duplicados")
    for n in numbers:
        if not n.startswith("NETBO-"):
            errors.append(f"f_number sem prefixo NETBO-: {n}")

    cat = manifest.get("category") or {}
    if cat.get("name") != "NET-bo":
        errors.append("manifest.category.name deve ser 'NET-bo'")

    for article in articles:
        body_path = CONTENT / article["body"]
        if not body_path.is_file():
            errors.append(f"Body em falta: {body_path}")
            continue
        body = body_path.read_text(encoding="utf-8")
        if len(body.strip()) < 40:
            errors.append(f"{article['number']}: corpo demasiado curto")
        if SECRET_RE.search(body):
            errors.append(f"{article['number']}: possível segredo no HTML")
        if EDITORIAL_RE.search(body):
            errors.append(f"{article['number']}: marcador editorial residual")
        tokens = TOKEN_RE.findall(body)
        asset_names = {a["filename"] for a in article["assets"]}
        for tok in tokens:
            if tok not in asset_names:
                errors.append(f"{article['number']}: token sem asset {tok}")
        for asset in article["assets"]:
            path = CONTENT / asset["path"]
            if not path.is_file():
                errors.append(f"Asset em falta: {path}")
            expected = f"@@NETBO_IMAGE:{asset['filename']}@@"
            if asset.get("token") != expected:
                errors.append(f"Token incorrecto para {asset['filename']}")
            prefix = f"NETBO-{article['name']}-"
            if not asset["filename"].startswith(prefix):
                errors.append(
                    f"{article['number']}: filename {asset['filename']} "
                    f"não começa por {prefix}"
                )
        unused = asset_names - set(tokens)
        if unused:
            warnings.append(f"{article['number']}: assets não referenciados {sorted(unused)}")
        leftover_urls = re.findall(r"Action=AgentFAQZoom;Subaction=DownloadAttachment", body)
        if leftover_urls:
            errors.append(f"{article['number']}: URL AgentFAQZoom residual no corpus")

    if warnings:
        print("Avisos:")
        for w in warnings:
            print(f"  - {w}")
    if errors:
        print("Erros:", file=sys.stderr)
        for e in errors:
            print(f"  - {e}", file=sys.stderr)
        return 1
    print(f"OK: {len(numbers)} f_numbers NETBO-* únicos; tokens/assets coerentes.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
