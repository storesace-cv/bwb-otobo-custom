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

# rsync as root must not leave Config/Custom unreadable by the otobo user
ssh "$TARGET" "set -e
chown -R otobo:www-data /opt/otobo/Custom /opt/otobo/Kernel/Config/Files /opt/otobo/var/httpd/htdocs
su -c '/opt/otobo/bin/otobo.Console.pl Maint::Config::Rebuild' -s /bin/bash otobo
su -c '/opt/otobo/bin/otobo.Console.pl Maint::Cache::Delete' -s /bin/bash otobo
su -c '/opt/otobo/bin/otobo.Daemon.pl status' -s /bin/bash otobo
"

echo "Publicado. Cópia de segurança: $BACKUP"
