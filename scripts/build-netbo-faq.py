#!/usr/bin/env python3
"""Build NET-bo FAQ articles from the source DOCX folder.

Estado neste repositório (2026-08-25):
  O corpus canónico em db/netbo-content/ foi obtido por exportação da produção
  após a importação bem-sucedida (17 artigos NETBO-* + 118 anexos).

O pipeline original de build a partir dos DOCX (segmentação temática, consolidação
de encomendas, Widgets via Craft) não estava presente neste working tree no
momento da integração. Não se regenera automaticamente a partir dos DOCX para
evitar divergência silenciosa face ao conteúdo já publicado.

Para actualizar o corpus a partir da BD viva (read-only):

  bash scripts/export-netbo-faq-from-otobo.sh

Para gerar SQL idempotente (fora do Git):

  python3 scripts/apply-netbo-faq.py --write /tmp/netbo-internal-kb.sql
  python3 scripts/validate-netbo-faq.py
"""
from __future__ import annotations

import sys


def main() -> int:
    print(
        "build-netbo-faq.py: o corpus canónico está em db/netbo-content/ "
        "(exportado da produção). Não sobrescrever a partir dos DOCX sem "
        "revisão humana e diff completo. Use scripts/export-netbo-faq-from-otobo.sh "
        "e scripts/apply-netbo-faq.py.",
        file=sys.stderr,
    )
    return 2


if __name__ == "__main__":
    raise SystemExit(main())
