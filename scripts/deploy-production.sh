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
rsync -av "$ROOT/otobo/var/httpd/htdocs/" "$TARGET:/opt/otobo/var/httpd/htdocs/"

ssh "$TARGET" "set -e; su - otobo -s /bin/bash -c '/opt/otobo/bin/otobo.Console.pl Maint::Config::Rebuild'; su - otobo -s /bin/bash -c '/opt/otobo/bin/otobo.Console.pl Maint::Cache::Delete'; /opt/otobo/bin/otobo.Daemon.pl status"

echo "Publicado. Cópia de segurança: $BACKUP"
