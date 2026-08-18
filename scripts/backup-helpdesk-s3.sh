#!/bin/bash
# Backup MariaDB OTOBO (helpdesk) → Euronodes S3 (bucket bwb-backups, prefix helpdesk/).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/backup-helpdesk-common.sh
source "$SCRIPT_DIR/lib/backup-helpdesk-common.sh"

ENV_FILE="${BWB_HELPDESK_BACKUP_ENV:-/root/.config/bwb-helpdesk-backup.env}"
LOG_DIR="${BWB_HELPDESK_BACKUP_LOG_DIR:-/var/log/bwb-helpdesk}"
LOCAL_DIR="${BWB_HELPDESK_S3_LOCAL_DIR:-/var/lib/bwb-helpdesk/backups/mariadb}"

log() { echo "[$(date -Iseconds)] [s3-db] $*"; }
fail() { log "ERROR: $*"; exit 1; }

backup_load_env_file

ENABLED="$(backup_read_env BWB_HELPDESK_S3_DB_ENABLED "$(backup_read_env BWB_HELPDESK_BACKUP_ENABLED 0)")"
if [ "$ENABLED" != "1" ] && [ "$ENABLED" != "true" ] && [ "$ENABLED" != "yes" ]; then
    log "S3 DB backup desactivado — skip"
    exit 0
fi

RCLONE_REMOTE="$(backup_read_env BWB_HELPDESK_S3_RCLONE_REMOTE euronodes-s3)"
S3_BUCKET="$(backup_read_env BWB_HELPDESK_S3_BUCKET bwb-backups)"
S3_PREFIX="$(backup_read_env BWB_HELPDESK_S3_PATH helpdesk)"
S3_PREFIX="${S3_PREFIX#/}"
S3_PREFIX="${S3_PREFIX%/}"
RETENTION_DAYS="$(backup_read_env BWB_HELPDESK_S3_RETENTION_DAYS "$(backup_read_env BWB_HELPDESK_BACKUP_RETENTION_DAYS 8)")"
DB_NAME="$(backup_read_env BWB_HELPDESK_BACKUP_DB_NAME otobo)"
DB_HOST="$(backup_read_env BWB_HELPDESK_BACKUP_DB_HOST 127.0.0.1)"
DB_USER="$(backup_read_env BWB_HELPDESK_BACKUP_DB_USER "")"
DB_PASSWORD="$(backup_read_env BWB_HELPDESK_BACKUP_DB_PASSWORD "")"
HOST_LABEL="$(backup_read_env BWB_HELPDESK_BACKUP_TARGET_LABEL helpdesk)"

mkdir -p "$LOG_DIR" "$LOCAL_DIR"
chmod 750 "$LOCAL_DIR" 2>/dev/null || true

command -v rclone >/dev/null 2>&1 || fail "rclone não instalado"
command -v mysqldump >/dev/null 2>&1 || fail "mysqldump não encontrado"

TS="$(date +%Y-%m-%d_%H%M%S)"
LOCAL_FILE="${LOCAL_DIR}/otobo-${HOST_LABEL}-${TS}.sql.gz"
REMOTE_KEY="${S3_PREFIX}/otobo-${HOST_LABEL}-${TS}.sql.gz"
REMOTE_PATH="${RCLONE_REMOTE}:${S3_BUCKET}/${REMOTE_KEY}"

log "Início → s3://${S3_BUCKET}/${S3_PREFIX}/ (base=${DB_NAME})"

if command -v mysql >/dev/null 2>&1; then
    mysql -e "SET GLOBAL max_allowed_packet=268435456;" 2>/dev/null || true
fi

dump_args=(--single-transaction --quick --max-allowed-packet=512M --routines --triggers)
if [ -n "$DB_USER" ]; then
    dump_args+=(-h "$DB_HOST" -u "$DB_USER")
    [ -n "$DB_PASSWORD" ] && export MYSQL_PWD="$DB_PASSWORD"
fi

if ! mysqldump "${dump_args[@]}" "$DB_NAME" | gzip -9 > "$LOCAL_FILE"; then
    rm -f "$LOCAL_FILE"
    unset MYSQL_PWD 2>/dev/null || true
    fail "mysqldump falhou"
fi
unset MYSQL_PWD 2>/dev/null || true

SIZE="$(du -h "$LOCAL_FILE" | awk '{print $1}')"
log "Dump local OK (${SIZE}): $LOCAL_FILE"

if ! rclone copyto "$LOCAL_FILE" "$REMOTE_PATH" --stats-one-line --retries 5 --low-level-retries 10; then
    fail "rclone upload falhou para $REMOTE_PATH"
fi
log "Upload S3 OK: $REMOTE_PATH"

find "$LOCAL_DIR" -type f -name 'otobo-*.sql.gz' -mtime +"$RETENTION_DAYS" -delete 2>/dev/null || true
rclone delete "${RCLONE_REMOTE}:${S3_BUCKET}/${S3_PREFIX}/" \
    --min-age "${RETENTION_DAYS}d" --include 'otobo-*.sql.gz' 2>/dev/null || true

check_s3_size_alert() {
    local alert_email alert_gb alert_bytes remote_bytes remote_human state_file last_alert now

    alert_email="$(backup_read_env BWB_HELPDESK_BACKUP_ALERT_EMAIL "")"
    alert_gb="$(backup_read_env BWB_HELPDESK_S3_ALERT_SIZE_GB 800)"
    [ -n "$alert_email" ] || return 0
    case "$alert_gb" in ''|*[!0-9.]*) alert_gb=800 ;; esac
    alert_bytes="$(python3 - <<PY
gb = float("${alert_gb}")
print(int(gb * 1024 * 1024 * 1024))
PY
)"

    remote_bytes="$(rclone size "${RCLONE_REMOTE}:${S3_BUCKET}/" --json 2>/dev/null \
        | python3 -c "import json,sys; print(int(json.load(sys.stdin).get('bytes',0)))" 2>/dev/null || echo 0)"
    remote_human="$(backup_human_bytes "$remote_bytes")"
    state_file="${LOG_DIR}/backup-size-alert-s3.state"
    now="$(date +%s)"

    if [ "$remote_bytes" -lt "$alert_bytes" ]; then
        rm -f "$state_file" 2>/dev/null || true
        log "Volume bucket ${remote_human} (< ${alert_gb} GB) — sem alerta"
        return 0
    fi

    if [ -f "$state_file" ]; then
        last_alert="$(cat "$state_file" 2>/dev/null || echo 0)"
        if [ "$((now - last_alert))" -lt 86400 ]; then
            log "Volume bucket ${remote_human} — alerta já enviado nas últimas 24h"
            return 0
        fi
    fi

    subject="[Helpdesk Backup] S3 ${S3_BUCKET}: ${remote_human} (limite ${alert_gb} GB)"
    body="Alerta de volume no bucket Euronodes S3 ${S3_BUCKET}.

Total bucket: ${remote_human} (${remote_bytes} bytes)
Limite configurado: ${alert_gb} GB
Prefixo helpdesk: ${S3_PREFIX}/

Servidor: ${HOST_LABEL}
Retenção dumps: ${RETENTION_DAYS} dias."

    if backup_send_alert_email "$subject" "$body"; then
        echo "$now" > "$state_file"
        chmod 600 "$state_file" 2>/dev/null || true
        log "Alerta email enviado (${remote_human} >= ${alert_gb} GB)"
    else
        log "WARN: falha ao enviar alerta email"
    fi
}

check_s3_size_alert
log "Concluído (retenção ${RETENTION_DAYS}d)"
