#!/usr/bin/env bash
set -euo pipefail

if [[ "${1:-}" != "--apply" ]]; then
    echo "Uso: $0 --apply" >&2
    exit 2
fi

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET="${OTOBO_TARGET:-bwb-otobo-prod}"
STAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP="/root/otobo-backups/custom-git-${STAMP}"

ssh "$TARGET" "mkdir -p '$BACKUP' && cp -a /opt/otobo/Custom '$BACKUP/Custom'"
rsync -av "$ROOT/otobo/Custom/" "$TARGET:/opt/otobo/Custom/"
rsync -av "$ROOT/otobo/Kernel/Config/Files/" "$TARGET:/opt/otobo/Kernel/Config/Files/"
# SysConfig XML is loaded from Kernel/Config/Files/XML (not Custom/)
rsync -av "$ROOT/otobo/Custom/Kernel/Config/Files/XML/" "$TARGET:/opt/otobo/Kernel/Config/Files/XML/"
rsync -av "$ROOT/otobo/var/httpd/htdocs/" "$TARGET:/opt/otobo/var/httpd/htdocs/"
ssh "$TARGET" "install -d -o otobo -g otobo -m 750 /opt/otobo/Custom/scripts"
rsync -av "$ROOT/scripts/runtime-web-system-modules.txt" "$TARGET:/opt/otobo/Custom/scripts/"

# rsync as root must not leave runtime files unreadable by Apache.
# SysConfig compilado (ZZZAAuto.pm / ZZZ*.pm) é carregado em cada pedido web:
# tem de ser legível por www-data. Fontes XML e User/ permanecem privadas ao otobo.
ssh "$TARGET" 'bash -s' <<'REMOTE'
set -euo pipefail

chown -R otobo:otobo /opt/otobo/Custom
chown -R otobo:www-data /opt/otobo/var/httpd/htdocs

for runtime_dir in /opt/otobo/Custom/Kernel/Modules /opt/otobo/Custom/Kernel/Output; do
    if [ -d "$runtime_dir" ]; then
        find "$runtime_dir" -type d -exec chgrp www-data {} + -exec chmod 750 {} +
        find "$runtime_dir" -type f \( -name '*.pm' -o -name '*.tt' \) -exec chgrp www-data {} + -exec chmod 640 {} +
    fi
done

while IFS= read -r relative; do
    case "$relative" in ''|'#'*) continue ;; esac
    file="/opt/otobo/Custom/$relative"
    test -f "$file"
    chgrp www-data "$file"
    chmod 640 "$file"
    directory=$(dirname "$file")
    while [ "$directory" != /opt/otobo/Custom ]; do
        chgrp www-data "$directory"
        chmod 750 "$directory"
        directory=$(dirname "$directory")
    done
done < /opt/otobo/Custom/scripts/runtime-web-system-modules.txt

apply_config_files_permissions() {
    chown otobo:www-data /opt/otobo/Kernel/Config/Files
    chmod 2750 /opt/otobo/Kernel/Config/Files
    find /opt/otobo/Kernel/Config/Files -maxdepth 1 -type f -name '*.pm' \
        -exec chown otobo:www-data {} + -exec chmod 640 {} +

    if [ -d /opt/otobo/Kernel/Config/Files/XML ]; then
        chown -R otobo:otobo /opt/otobo/Kernel/Config/Files/XML
        find /opt/otobo/Kernel/Config/Files/XML -type d -exec chmod 2750 {} +
        find /opt/otobo/Kernel/Config/Files/XML -type f -exec chmod 640 {} +
    fi
    if [ -d /opt/otobo/Kernel/Config/Files/User ]; then
        chown -R otobo:otobo /opt/otobo/Kernel/Config/Files/User
        find /opt/otobo/Kernel/Config/Files/User -type d -exec chmod 2750 {} +
        find /opt/otobo/Kernel/Config/Files/User -type f -exec chmod 640 {} +
    fi
}

apply_config_files_permissions
su -c '/opt/otobo/bin/otobo.Console.pl Maint::Config::Rebuild' -s /bin/bash otobo
# Rebuild reescreve ZZZAAuto.pm como otobo:otobo; reaplicar leitura web.
apply_config_files_permissions
su -c '/opt/otobo/bin/otobo.Console.pl Maint::Cache::Delete' -s /bin/bash otobo
su -c '/opt/otobo/bin/otobo.Daemon.pl status' -s /bin/bash otobo
systemctl reload apache2

check_readable() {
    path="$1"
    su -s /bin/sh www-data -c "test -r \"$path\""
}
find /opt/otobo/Custom/Kernel/Modules /opt/otobo/Custom/Kernel/Output -type f \( -name '*.pm' -o -name '*.tt' \) -print0 |
    while IFS= read -r -d '' file; do check_readable "$file"; done
while IFS= read -r relative; do
    case "$relative" in ''|'#'*) continue ;; esac
    check_readable "/opt/otobo/Custom/$relative"
done < /opt/otobo/Custom/scripts/runtime-web-system-modules.txt
check_readable /opt/otobo/Kernel/Config/Files/ZZZAAuto.pm
check_readable /opt/otobo/Kernel/Config.pm

body="$(mktemp)"
code="$(curl -ksS -o "$body" -w '%{http_code}' https://127.0.0.1/otobo/index.pl?Action=AgentDashboard)"
if grep -Fq 'not registered in Kernel/Config.pm' "$body"; then
    echo "ERRO: resposta contém módulo não registado (ZZZAAuto ilegível?)" >&2
    rm -f "$body"
    exit 1
fi
rm -f "$body"
test "$code" = 200 -o "$code" = 302
REMOTE

echo "Publicado. Cópia de segurança: $BACKUP"
