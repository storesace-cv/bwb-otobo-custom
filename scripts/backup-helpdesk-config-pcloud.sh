#!/bin/bash
# Snapshot de configuração do servidor helpdesk → pCloud (auditoria / troubleshooting).
# Não inclui dumps de BD nem ficheiros com segredos (rclone.conf, .env backup, passwords em claro).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/backup-helpdesk-common.sh
source "$SCRIPT_DIR/lib/backup-helpdesk-common.sh"

ENV_FILE="${BWB_HELPDESK_BACKUP_ENV:-/root/.config/bwb-helpdesk-backup.env}"
LOG_DIR="${BWB_HELPDESK_BACKUP_LOG_DIR:-/var/log/bwb-helpdesk}"
LOCAL_DIR="${BWB_HELPDESK_CONFIG_LOCAL_DIR:-/var/lib/bwb-helpdesk/backups/config}"
STAGING=""

log() { echo "[$(date -Iseconds)] [pcloud-config] $*"; }
fail() { log "ERROR: $*"; exit 1; }

cleanup() {
    [ -n "$STAGING" ] && [ -d "$STAGING" ] && rm -rf "$STAGING"
}
trap cleanup EXIT

backup_load_env_file

ENABLED="$(backup_read_env BWB_HELPDESK_CONFIG_BACKUP_ENABLED 1)"
if [ "$ENABLED" != "1" ] && [ "$ENABLED" != "true" ] && [ "$ENABLED" != "yes" ]; then
    log "Config backup desactivado — skip"
    exit 0
fi

RCLONE_REMOTE="$(backup_read_env BWB_HELPDESK_PCLOUD_RCLONE_REMOTE bwb-pcloud-helpdesk)"
PCLOUD_SUBPATH="$(backup_read_env BWB_HELPDESK_PCLOUD_CONFIG_PATH backups/helpdesk-config)"
PCLOUD_SUBPATH="${PCLOUD_SUBPATH#/}"
RETENTION_DAYS="$(backup_read_env BWB_HELPDESK_CONFIG_RETENTION_DAYS 30)"
HOST_LABEL="$(backup_read_env BWB_HELPDESK_BACKUP_TARGET_LABEL helpdesk)"

mkdir -p "$LOG_DIR" "$LOCAL_DIR"
command -v rclone >/dev/null 2>&1 || fail "rclone não instalado"

STAGING="$(mktemp -d)"
META="$STAGING/MANIFEST.txt"
{
    echo "hostname=$(hostname -f 2>/dev/null || hostname)"
    echo "generated=$(date -Iseconds)"
    echo "label=${HOST_LABEL}"
    echo "kernel=$(uname -r)"
    echo "os=$(. /etc/os-release 2>/dev/null && echo "$PRETTY_NAME" || true)"
    echo "---"
    echo "Conteúdo: configs Ubuntu/OTOBO para auditoria (sem segredos)."
} > "$META"

crontab -l > "$STAGING/crontab-root.txt" 2>/dev/null || echo "(sem crontab root)" > "$STAGING/crontab-root.txt"
dpkg --get-selections > "$STAGING/dpkg-selections.txt" 2>/dev/null || true
systemctl list-unit-files --type=service --state=enabled > "$STAGING/systemd-enabled-services.txt" 2>/dev/null || true

copy_tree() {
    local src="$1"
    local dest="$2"
    [ -e "$src" ] || return 0
    mkdir -p "$(dirname "$dest")"
    cp -a "$src" "$dest" 2>/dev/null || true
}

copy_tree /etc/nginx "$STAGING/etc/nginx"
copy_tree /etc/apache2 "$STAGING/etc/apache2"
copy_tree /etc/postfix "$STAGING/etc/postfix"
copy_tree /etc/mysql "$STAGING/etc/mysql"
copy_tree /etc/cron.d "$STAGING/etc/cron.d"
copy_tree /etc/cron.daily "$STAGING/etc/cron.daily"
copy_tree /etc/systemd/system "$STAGING/etc/systemd/system"
copy_tree /opt/otobo/Kernel/Config/Files "$STAGING/opt/otobo/Kernel/Config/Files"
copy_tree /opt/otobo/Custom/Kernel/Config/Files/XML "$STAGING/opt/otobo/Custom/Kernel/Config/Files/XML"
copy_tree /opt/bwb-helpdesk/scripts "$STAGING/opt/bwb-helpdesk/scripts"

for f in /etc/hosts /etc/resolv.conf /etc/fstab /etc/ssh/sshd_config; do
    [ -f "$f" ] && copy_tree "$f" "$STAGING$f"
done

if [ -f /opt/otobo/Kernel/Config.pm ]; then
    mkdir -p "$STAGING/opt/otobo/Kernel"
    sed -E 's/(\x27DatabasePw\x27\s*=>\s*).*/\1"[REDACTED]",/' \
        /opt/otobo/Kernel/Config.pm > "$STAGING/opt/otobo/Kernel/Config.pm.redacted"
fi

TS="$(date +%Y-%m-%d_%H%M%S)"
ARCHIVE="${LOCAL_DIR}/config-${HOST_LABEL}-${TS}.tar.gz"
REMOTE_PATH="${RCLONE_REMOTE}:${PCLOUD_SUBPATH}/config-${HOST_LABEL}-${TS}.tar.gz"

log "Empacotar configs → ${PCLOUD_SUBPATH}/"
tar -czf "$ARCHIVE" -C "$STAGING" .

SIZE="$(du -h "$ARCHIVE" | awk '{print $1}')"
log "Arquivo local OK (${SIZE}): $ARCHIVE"

if ! rclone copyto "$ARCHIVE" "$REMOTE_PATH" --stats-one-line; then
    fail "rclone upload falhou para $REMOTE_PATH"
fi
log "Upload pCloud OK: $REMOTE_PATH"

find "$LOCAL_DIR" -type f -name 'config-*.tar.gz' -mtime +"$RETENTION_DAYS" -delete 2>/dev/null || true
rclone delete "${RCLONE_REMOTE}:${PCLOUD_SUBPATH}" \
    --min-age "${RETENTION_DAYS}d" --include 'config-*.tar.gz' 2>/dev/null || true

log "Concluído (retenção ${RETENTION_DAYS}d)"
