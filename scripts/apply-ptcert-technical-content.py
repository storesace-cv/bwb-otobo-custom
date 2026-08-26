#!/usr/bin/env python3
"""Actualiza f_field3 dos artigos técnicos PTcert a partir de db/ptcert-technical-content/articles/.

Uso:
  python3 scripts/apply-ptcert-technical-content.py --write /tmp/ptcert-technical-update.sql
  # depois, em produção (com dump prévio):
  # ssh bwb-otobo-prod 'mysql otobo' < /tmp/ptcert-technical-update.sql
"""
from __future__ import annotations

import argparse
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parents[1]
ARTICLES = ROOT / "db" / "ptcert-technical-content" / "articles"

# Só estes f_number — não toca operacionais nem categoria id 12.
ALLOWED = {
    "PTC-TEC-ARRANQUE",
    "PTC-TEC-GRAFICO-USUARIOS",
    "PTC-WSL2-INSTALACAO-ARRANQUE",
    "PTC-WSL2-LAUNCHER-DIAGNOSTICO",
}


def sql_escape(value: str) -> str:
    return value.replace("\\", "\\\\").replace("'", "''")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--write", required=True, type=pathlib.Path)
    args = parser.parse_args()

    files = sorted(ARTICLES.glob("*.html"))
    if not files:
        print(f"Sem artigos em {ARTICLES}", file=sys.stderr)
        return 1

    lines = [
        "-- Actualização conteúdo técnico PTcert (2026-08-25)",
        "-- Só f_field3 por f_number listado; idempotente em conteúdo.",
        "START TRANSACTION;",
    ]
    for path in files:
        number = path.stem
        if number not in ALLOWED:
            print(f"Ignorado (não allowlist): {number}", file=sys.stderr)
            continue
        body = path.read_text(encoding="utf-8").strip() + "\n"
        lines.append(
            "UPDATE faq_item SET f_field3 = '{body}', changed = NOW() "
            "WHERE f_number = '{number}' AND state_id = 2;".format(
                body=sql_escape(body), number=sql_escape(number)
            )
        )
    lines.append("COMMIT;")
    args.write.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"Escrito {args.write} ({len(files)} ficheiros na pasta, allowlist {len(ALLOWED)})")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
