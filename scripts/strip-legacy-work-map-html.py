#!/usr/bin/env python3
"""Strip legacy Wikimedia map frame/pin from worksheet HTML attachments."""
import binascii
import re
import subprocess
import sys


def main() -> int:
    rows = subprocess.check_output(
        [
            "mysql",
            "-N",
            "otobo",
            "-e",
            """
            SELECT id FROM article_data_mime_attachment
            WHERE content_type LIKE 'text/html%'
              AND content LIKE '%Mapa da localização%'
              AND content LIKE '%maps.wikimedia.org%'
            """,
        ],
        text=True,
    ).strip().split()

    if not rows:
        print("Nenhum anexo legado encontrado.")
        return 0

    for aid in rows:
        hex_in = subprocess.check_output(
            [
                "mysql",
                "-N",
                "--binary-as-hex",
                "otobo",
                "-e",
                f"SELECT HEX(content) FROM article_data_mime_attachment WHERE id={aid}",
            ],
            text=True,
        ).strip()
        html = binascii.unhexlify(hex_in).decode("utf-8", errors="replace")
        orig = html
        html = re.sub(
            r"<div[^>]*>\s*Localização no fecho\s*</div>",
            "",
            html,
            flags=re.I,
        )
        html = re.sub(
            r"<div[^>]*>\s*Localização \(coordenadas da loja\)\s*</div>",
            "",
            html,
            flags=re.I,
        )
        html = re.sub(
            r'<div\s+style="margin:0 6px 28px;">.*?</div>(?=\s*<table\s+class="BWBAccountedDuration")',
            "",
            html,
            flags=re.I | re.S,
        )
        html = re.sub(
            r'<img[^>]*alt="Mapa da localização"[^>]*/?>',
            "",
            html,
            flags=re.I,
        )
        html = re.sub(
            r'<span[^>]*rotate\(-45deg\)[^>]*>\s*</span>',
            "",
            html,
            flags=re.I,
        )
        if html == orig:
            print(f"attachment {aid}: sem alterações")
            continue
        hex_out = binascii.hexlify(html.encode("utf-8")).decode("ascii")
        subprocess.check_call(
            [
                "mysql",
                "otobo",
                "-e",
                f"UPDATE article_data_mime_attachment SET content=UNHEX('{hex_out}') WHERE id={aid}",
            ]
        )
        still = "maps.wikimedia.org" in html or "Mapa da localização" in html
        print(f"attachment {aid}: limpo (ainda tem mapa legado={still})")
    return 0


if __name__ == "__main__":
    sys.exit(main())
