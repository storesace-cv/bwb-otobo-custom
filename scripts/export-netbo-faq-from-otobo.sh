#!/usr/bin/env bash
# Export read-only do corpus NETBO-* da produção para db/netbo-content/.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOST="${1:-bwb-otobo-prod}"
REMOTE="/tmp/netbo-faq-export"

ssh "$HOST" "bash -s" <<REMOTE
set -euo pipefail
OUT='$REMOTE'
rm -rf "\$OUT"
mkdir -p "\$OUT/articles" "\$OUT/media" "\$OUT/meta"
mysql otobo -N -e "SELECT f_number FROM faq_item WHERE f_number LIKE 'NETBO-%' ORDER BY id" > "\$OUT/numbers.txt"
while IFS= read -r NUM; do
  ID=\$(mysql otobo -N -e "SELECT id FROM faq_item WHERE f_number='\$NUM'")
  mysql otobo -N -e "SELECT f_name FROM faq_item WHERE id=\$ID" > "\$OUT/meta/\${NUM}.name"
  mysql otobo -N -e "SELECT f_subject FROM faq_item WHERE id=\$ID" > "\$OUT/meta/\${NUM}.title"
  mysql otobo -N -r -e "SELECT IFNULL(f_keywords,'') FROM faq_item WHERE id=\$ID" > "\$OUT/meta/\${NUM}.keywords"
  mysql otobo -N -r -e "SELECT IFNULL(f_field1,'') FROM faq_item WHERE id=\$ID" > "\$OUT/meta/\${NUM}.summary"
  mysql otobo -N -r -e "SELECT IFNULL(f_field2,'') FROM faq_item WHERE id=\$ID" > "\$OUT/meta/\${NUM}.use_when"
  mysql otobo -N -r -e "SELECT IFNULL(f_field3,'') FROM faq_item WHERE id=\$ID" > "\$OUT/articles/\${NUM}.html"
  echo "\$ID" > "\$OUT/meta/\${NUM}.id"
  mysql otobo -N -e "SELECT id, filename, content_type, content_size FROM faq_attachment WHERE faq_id=\$ID ORDER BY id" > "\$OUT/meta/\${NUM}.attachments"
  while IFS=\$'\\t' read -r FID FNAME CTYPE CSIZE; do
    [ -z "\${FID:-}" ] && continue
    mysql otobo -N -r -e "SELECT HEX(content) FROM faq_attachment WHERE id=\$FID" > "\$OUT/media/\${FNAME}.hex"
  done < "\$OUT/meta/\${NUM}.attachments"
  echo "exported \$NUM"
done < "\$OUT/numbers.txt"
REMOTE

RAW="$ROOT/db/netbo-content-raw"
OUT="$ROOT/db/netbo-content"
rm -rf "$RAW" "$OUT"
mkdir -p "$OUT"
rsync -a "$HOST:$REMOTE/" "$RAW/"

python3 - <<PY
from __future__ import annotations
import json, re
from pathlib import Path
RAW = Path("$RAW")
OUT = Path("$OUT")
(OUT / "articles").mkdir(parents=True, exist_ok=True)
(OUT / "media").mkdir(parents=True, exist_ok=True)
URL_RE = re.compile(
    r"/otobo/index\\.pl\\?Action=AgentFAQZoom;Subaction=DownloadAttachment;"
    r"ItemID=(?P<item>\\d+);FileID=(?P<file>\\d+)",
    re.I,
)
numbers = [n.strip() for n in (RAW / "numbers.txt").read_text().splitlines() if n.strip()]
if len(numbers) != 17 or len(set(numbers)) != 17:
    raise SystemExit(f"Esperados 17 NETBO-* únicos, obtidos {numbers}")
articles = []
for number in numbers:
    name = (RAW / "meta" / f"{number}.name").read_text(encoding="utf-8").strip()
    title = (RAW / "meta" / f"{number}.title").read_text(encoding="utf-8").strip()
    keywords = (RAW / "meta" / f"{number}.keywords").read_text(encoding="utf-8").strip()
    summary = (RAW / "meta" / f"{number}.summary").read_text(encoding="utf-8").rstrip("\\n")
    use_when = (RAW / "meta" / f"{number}.use_when").read_text(encoding="utf-8").rstrip("\\n")
    body = (RAW / "articles" / f"{number}.html").read_text(encoding="utf-8")
    file_map = {}
    assets = []
    att = RAW / "meta" / f"{number}.attachments"
    if att.exists():
        for line in att.read_text(encoding="utf-8").splitlines():
            if not line.strip():
                continue
            fid, filename, ctype, size = line.split("\\t", 3)
            file_map[fid] = filename
            raw = bytes.fromhex((RAW / "media" / f"{filename}.hex").read_text().strip())
            (OUT / "media" / filename).write_bytes(raw)
            assets.append({
                "filename": filename,
                "path": f"media/{filename}",
                "content_type": ctype.split(";", 1)[0].strip() or "image/png",
                "token": f"@@NETBO_IMAGE:{filename}@@",
            })
    def repl(m):
        fn = file_map.get(m.group("file"))
        return f"@@NETBO_IMAGE:{fn}@@" if fn else m.group(0)
    body_tok = URL_RE.sub(repl, body)
    if URL_RE.search(body_tok):
        raise SystemExit(f"URLs sem mapa em {number}")
    (OUT / "articles" / f"{number}.html").write_text(body_tok.rstrip() + "\\n", encoding="utf-8")
    articles.append({
        "number": number,
        "name": name,
        "title": title,
        "keywords": keywords,
        "summary": summary,
        "use_when": use_when,
        "body": f"articles/{number}.html",
        "assets": assets,
        "source": "exported-from-production",
    })
manifest = {
    "category": {
        "name": "NET-bo",
        "comment": "Base de conhecimento interna NET-bo para agentes de suporte.",
    },
    "notes": [
        "Destino: Documentação interna > NET-bo (lookup por parent/name).",
        "Não alterar Manuais de utilização > NET-bo.",
        "SQL gerado por apply-netbo-faq.py fica fora do Git.",
    ],
    "articles": articles,
}
(OUT / "manifest.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\\n", encoding="utf-8")
print(f"OK {len(articles)} artigos, {sum(len(a['assets']) for a in articles)} anexos")
PY

rm -rf "$RAW"
python3 "$ROOT/scripts/validate-netbo-faq.py"
echo "Export concluído em $OUT"
