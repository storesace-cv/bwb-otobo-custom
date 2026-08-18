#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET="${OTOBO_TARGET:-bwb-otobo-prod}"

if [[ "${1:-}" != "--production" ]]; then
    echo "Uso: $0 --production" >&2
    exit 2
fi

ssh "$TARGET" 'set -u
failed=0
check_readable() {
    path="$1"
    su -s /bin/sh www-data -c "test -r \"$path\"" || {
        echo "ERRO: www-data não consegue ler $path" >&2
        failed=1
    }
}

find /opt/otobo/Custom/Kernel/Modules /opt/otobo/Custom/Kernel/Output \
    -type f \( -name "*.pm" -o -name "*.tt" \) -print0 |
while IFS= read -r -d "" file; do check_readable "$file"; done

while IFS= read -r relative; do
    [[ -z "$relative" || "$relative" = \#* ]] && continue
    check_readable "/opt/otobo/Custom/$relative"
done < /opt/otobo/Custom/scripts/runtime-web-system-modules.txt

check_readable /opt/otobo/Kernel/Config.pm
check_readable /opt/otobo/Kernel/Config/Files/ZZZAAuto.pm
for zzz in /opt/otobo/Kernel/Config/Files/ZZZBWB*.pm; do
    [ -e "$zzz" ] || continue
    check_readable "$zzz"
done

body=$(mktemp)
http_code=$(curl -ksS -o "$body" -w "%{http_code}" \
    https://127.0.0.1/otobo/index.pl?Action=AgentDashboard)
echo "Painel Agent HTTP: $http_code"
if grep -Fq "not registered in Kernel/Config.pm" "$body"; then
    echo "ERRO: resposta indica módulo não registado (ZZZAAuto.pm ilegível por www-data?)" >&2
    failed=1
fi
rm -f "$body"
[ "$http_code" = 200 ] || [ "$http_code" = 302 ] || failed=1
[ "$failed" -eq 0 ] || exit 1
echo "Permissões de execução web: OK"
'

echo "Verificação de permissões em produção concluída."
