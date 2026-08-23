#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Aplica ou actualiza artigos FAQ internos (Ajuda) a partir de db/faq-content/."""

from __future__ import annotations

import argparse
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
CONTENT = ROOT / "db" / "faq-content"

MANUALS = [
    {
        "f_number": "HD-GPS-FOLHA",
        "f_name": "manual-folha-gps",
        "f_subject": "Localização GPS ao terminar a folha de trabalho",
        "category_id": 21,
        "f_keywords": "gps localização folha trabalho terminar mapa loja field mode",
        "f_field1": (
            "<p>Registar onde estava ao <strong>terminar uma folha de trabalho</strong>, "
            "com mapa interno no ticket (só agentes).</p>"
        ),
        "f_field2": (
            "<p>Utilize quando precisa de perceber como funciona o pedido de localização "
            "ao carregar em <strong>Terminar trabalho</strong> (computador ou telemóvel).</p>"
        ),
        "f_field3_file": "HD-GPS-FOLHA-field3.html",
    },
    {
        "f_number": "HD-TICKETS-CALENDARIO",
        "f_name": "manual-tickets-calendario",
        "f_subject": "Tickets e calendário — agendamentos",
        "category_id": 20,
        "f_keywords": (
            "calendário marcação agendamento pendente folha compromisso dashboard "
            "cancelado visita retoma"
        ),
        "f_field1": (
            "<p>Ligar <strong>tickets</strong> e <strong>marcações no calendário</strong> "
            "quando o pedido fica para uma data futura.</p>"
        ),
        "f_field2": (
            "<p>Utilize para visitas presenciais, retomas agendadas, formações no cliente "
            "ou qualquer continuação com data e hora acordada.</p>"
        ),
        "f_field3_file": "HD-TICKETS-CALENDARIO-field3.html",
    },
]


def sql_escape(value: str) -> str:
    return value.replace("\\", "\\\\").replace("'", "''")


def build_sql() -> str:
    lines = [
        "-- Manuais Ajuda: GPS na folha + tickets/calendário.",
        "-- Idempotente: INSERT se novo; UPDATE se f_number já existir.",
        "-- Reversão: DELETE FROM faq_item WHERE f_number IN ('HD-GPS-FOLHA','HD-TICKETS-CALENDARIO');",
        "",
        "SET NAMES utf8mb4;",
        "",
    ]

    for manual in MANUALS:
        field3_path = CONTENT / manual["f_field3_file"]
        if not field3_path.is_file():
            raise SystemExit(f"Ficheiro em falta: {field3_path}")
        field3 = field3_path.read_text(encoding="utf-8").strip()

        lines.extend(
            [
                f"-- {manual['f_number']}",
                "INSERT INTO faq_item (",
                "  f_number, f_name, f_subject, f_language_id, state_id, category_id,",
                "  approved, valid_id, content_type, f_keywords,",
                "  f_field1, f_field2, f_field3, f_field6,",
                "  created, created_by, changed, changed_by",
                ")",
                "SELECT",
                f"  '{sql_escape(manual['f_number'])}',",
                f"  '{sql_escape(manual['f_name'])}',",
                f"  '{sql_escape(manual['f_subject'])}',",
                "  3, 2,",
                f"  {manual['category_id']},",
                "  1, 1, 'text/html',",
                f"  '{sql_escape(manual['f_keywords'])}',",
                f"  '{sql_escape(manual['f_field1'])}',",
                f"  '{sql_escape(manual['f_field2'])}',",
                f"  '{sql_escape(field3)}',",
                "  '',",
                "  UTC_TIMESTAMP(), 2, UTC_TIMESTAMP(), 2",
                "FROM DUAL",
                f"WHERE NOT EXISTS (SELECT 1 FROM faq_item WHERE f_number = '{sql_escape(manual['f_number'])}');",
                "",
                "UPDATE faq_item SET",
                f"  f_name = '{sql_escape(manual['f_name'])}',",
                f"  f_subject = '{sql_escape(manual['f_subject'])}',",
                f"  category_id = {manual['category_id']},",
                f"  f_keywords = '{sql_escape(manual['f_keywords'])}',",
                f"  f_field1 = '{sql_escape(manual['f_field1'])}',",
                f"  f_field2 = '{sql_escape(manual['f_field2'])}',",
                f"  f_field3 = '{sql_escape(field3)}',",
                "  content_type = 'text/html',",
                "  approved = 1,",
                "  valid_id = 1,",
                "  changed = UTC_TIMESTAMP(),",
                "  changed_by = 2",
                f"WHERE f_number = '{sql_escape(manual['f_number'])}';",
                "",
            ]
        )

    return "\n".join(lines)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--write",
        metavar="PATH",
        help="Gravar SQL gerado (por defeito db/migrations/2026-08-22-faq-manuais-gps-calendario.sql)",
    )
    args = parser.parse_args()

    sql = build_sql()
    out_path = pathlib.Path(args.write) if args.write else (
        ROOT / "db" / "migrations" / "2026-08-22-faq-manuais-gps-calendario.sql"
    )
    out_path.write_text(sql, encoding="utf-8")
    print(out_path)
    return 0


if __name__ == "__main__":
    sys.exit(main())
