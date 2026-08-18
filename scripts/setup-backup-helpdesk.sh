#!/bin/bash
# Configura backups helpdesk: MariaDB → Euronodes S3; configs → pCloud.
# Lê .env local (PCLOUD_*, EURONODES_S3_*, opcional GOTRUE_SMTP_*).
#
# Uso:
#   BWB_ENV_FILE=/path/to/.env scripts/setup-backup-helpdesk.sh [--run-now]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
RUN_NOW=0

for arg in "$@"; do
    case "$arg" in
        --run-now) RUN_NOW=1 ;;
        -h|--help)
            echo "Uso: $0 [--run-now]"
            exit 0
            ;;
    esac
done

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'
log_info() { echo -e "${GREEN}[helpdesk-backup-setup]${NC} $1"; }
log_err() { echo -e "${RED}[helpdesk-backup-setup]${NC} $1" >&2; }

load_kv() {
    local file="$1" key="$2"
    [ -f "$file" ] || return 1
    grep -E "^${key}=" "$file" 2>/dev/null | tail -1 | cut -d'=' -f2- | sed 's/^["'\''"]//;s/["'\''"]$//'
}

ENV_CANDIDATES=()
[ -n "${BWB_ENV_FILE:-}" ] && ENV_CANDIDATES+=("$BWB_ENV_FILE")
ENV_CANDIDATES+=(
    "$REPO_ROOT/.env"
    "$REPO_ROOT/.env.local"
    "$HOME/desenvolvimento/my-bwb-app/.env"
)

SOURCE_ENV=""
for candidate in "${ENV_CANDIDATES[@]}"; do
    if [ -f "$candidate" ] && grep -q '^EURONODES_S3_ACCESS_KEY=' "$candidate" 2>/dev/null; then
        SOURCE_ENV="$candidate"
        break
    fi
done

[ -n "$SOURCE_ENV" ] || { log_err "EURONODES_S3_ACCESS_KEY em falta. Defina BWB_ENV_FILE."; exit 1; }

S3_KEY="$(load_kv "$SOURCE_ENV" EURONODES_S3_ACCESS_KEY || true)"
S3_SECRET="$(load_kv "$SOURCE_ENV" EURONODES_S3_SECRET_KEY || true)"
S3_BUCKET="$(load_kv "$SOURCE_ENV" EURONODES_S3_BUCKET || echo bwb-backups)"
S3_PATH="$(load_kv "$SOURCE_ENV" EURONODES_S3_PATH || echo helpdesk)"
S3_PATH="${S3_PATH#/}"
S3_PATH="${S3_PATH%/}"

PCLOUD_USER="$(load_kv "$SOURCE_ENV" PCLOUD_USERNAME || true)"
PCLOUD_PASS="$(load_kv "$SOURCE_ENV" PCLOUD_PASSWORD || true)"

[ -n "$S3_KEY" ] && [ -n "$S3_SECRET" ] || { log_err "EURONODES_S3_ACCESS_KEY/SECRET em falta"; exit 1; }
[ -n "$PCLOUD_USER" ] && [ -n "$PCLOUD_PASS" ] || { log_err "PCLOUD_USERNAME/PASSWORD em falta (config backup)"; exit 1; }

SMTP_HOST="$(load_kv "$SOURCE_ENV" GOTRUE_SMTP_HOST || echo mail.smtp2go.com)"
SMTP_PORT="$(load_kv "$SOURCE_ENV" GOTRUE_SMTP_PORT || echo 2525)"
SMTP_USER="$(load_kv "$SOURCE_ENV" GOTRUE_SMTP_USER || true)"
SMTP_PASS="$(load_kv "$SOURCE_ENV" GOTRUE_SMTP_PASS || true)"
SMTP_FROM="$(load_kv "$SOURCE_ENV" GOTRUE_SMTP_ADMIN_EMAIL || echo "$SMTP_USER")"
SMTP_NAME="$(load_kv "$SOURCE_ENV" GOTRUE_SMTP_SENDER_NAME || echo "Backup Helpdesk BWB")"

SSH_TARGET="${OTOBO_TARGET:-bwb-otobo-prod}"
SSH_KEY="${BWB_SSH_KEY_PATH:-$HOME/.ssh/digitalocean}"
SSH_OPTS=(-o BatchMode=yes -o ConnectTimeout=15)
[ -f "$SSH_KEY" ] && SSH_OPTS+=(-i "$SSH_KEY")

DB_RETENTION="${BWB_HELPDESK_S3_RETENTION_DAYS:-8}"
CONFIG_RETENTION="${BWB_HELPDESK_CONFIG_RETENTION_DAYS:-30}"
PCLOUD_CONFIG_PATH="${BWB_HELPDESK_PCLOUD_CONFIG_PATH:-backups/helpdesk-config}"
ALERT_EMAIL="${BWB_HELPDESK_BACKUP_ALERT_EMAIL:-jorge.peixinho@bwb.pt}"
S3_ALERT_GB="${BWB_HELPDESK_S3_ALERT_SIZE_GB:-800}"

S3_SECRET_B64="$(printf '%s' "$S3_SECRET" | base64 | tr -d '\n')"
PCLOUD_PASS_B64="$(printf '%s' "$PCLOUD_PASS" | base64 | tr -d '\n')"
SMTP_PASS_B64="$(printf '%s' "$SMTP_PASS" | base64 | tr -d '\n')"
SMTP_NAME_B64="$(printf '%s' "$SMTP_NAME" | base64 | tr -d '\n')"
SMTP_FROM_B64="$(printf '%s' "$SMTP_FROM" | base64 | tr -d '\n')"

log_info "Fonte: $SOURCE_ENV"
log_info "S3: ${S3_BUCKET}/${S3_PATH}/ (retenção ${DB_RETENTION}d, 01:00 e 12:00)"
log_info "pCloud config: ${PCLOUD_CONFIG_PATH}/ (retenção ${CONFIG_RETENTION}d, 01:30)"

ssh "${SSH_OPTS[@]}" "$SSH_TARGET" 'mkdir -p /opt/bwb-helpdesk/scripts/lib'
rsync -av "$SCRIPT_DIR/lib/" "$SSH_TARGET:/opt/bwb-helpdesk/scripts/lib/"
rsync -av \
    "$SCRIPT_DIR/backup-helpdesk-s3.sh" \
    "$SCRIPT_DIR/backup-helpdesk-config-pcloud.sh" \
    "$SCRIPT_DIR/backup-helpdesk-run.sh" \
    "$SSH_TARGET:/opt/bwb-helpdesk/scripts/"

ssh "${SSH_OPTS[@]}" "$SSH_TARGET" \
    env \
    S3_ACCESS_KEY="$S3_KEY" \
    S3_SECRET_B64="$S3_SECRET_B64" \
    S3_BUCKET="$S3_BUCKET" \
    S3_PATH="$S3_PATH" \
    PCLOUD_USERNAME="$PCLOUD_USER" \
    PCLOUD_PASSWORD_B64="$PCLOUD_PASS_B64" \
    SMTP_HOST="$SMTP_HOST" \
    SMTP_PORT="$SMTP_PORT" \
    SMTP_USER="$SMTP_USER" \
    SMTP_PASS_B64="$SMTP_PASS_B64" \
    SMTP_FROM_B64="$SMTP_FROM_B64" \
    SMTP_NAME_B64="$SMTP_NAME_B64" \
    bash -s -- "$DB_RETENTION" "$CONFIG_RETENTION" "$PCLOUD_CONFIG_PATH" "$ALERT_EMAIL" "$S3_ALERT_GB" <<'REMOTE'
set -euo pipefail
DB_RETENTION="$1"
CONFIG_RETENTION="$2"
PCLOUD_CONFIG_PATH="$3"
ALERT_EMAIL="$4"
S3_ALERT_GB="$5"
INSTALL_DIR="/opt/bwb-helpdesk"
ENV_FILE="/root/.config/bwb-helpdesk-backup.env"
S3_SECRET="$(printf '%s' "$S3_SECRET_B64" | base64 -d)"
PCLOUD_PASSWORD="$(printf '%s' "$PCLOUD_PASSWORD_B64" | base64 -d)"
SMTP_PASS="$(printf '%s' "$SMTP_PASS_B64" | base64 -d)"
SMTP_FROM="$(printf '%s' "$SMTP_FROM_B64" | base64 -d)"
SMTP_NAME="$(printf '%s' "$SMTP_NAME_B64" | base64 -d)"

if ! command -v rclone >/dev/null 2>&1; then
    curl -fsSL https://rclone.org/install.sh | bash
fi

mkdir -p "$INSTALL_DIR/scripts/lib" \
    /var/lib/bwb-helpdesk/backups/mariadb \
    /var/lib/bwb-helpdesk/backups/config \
    /var/log/bwb-helpdesk /root/.config
chmod 750 /var/lib/bwb-helpdesk/backups/mariadb /var/lib/bwb-helpdesk/backups/config
chmod +x "$INSTALL_DIR/scripts/"*.sh

rclone config delete euronodes-s3 2>/dev/null || true
rclone config create euronodes-s3 s3 \
    provider=Ceph \
    access_key_id="$S3_ACCESS_KEY" \
    secret_access_key="$S3_SECRET" \
    endpoint=https://eu-west-1.euronodes.com \
    acl=private \
    force_path_style=true \
    region=other-v2-signature \
    config_is_local false >/dev/null 2>&1

rclone config delete bwb-pcloud-helpdesk 2>/dev/null || true
rclone config create bwb-pcloud-helpdesk webdav \
    url https://webdav.pcloud.com \
    vendor other \
    user "$PCLOUD_USERNAME" \
    pass "$PCLOUD_PASSWORD" \
    config_is_local false >/dev/null 2>&1
chmod 600 "${HOME}/.config/rclone/rclone.conf" 2>/dev/null || true

rclone lsd "euronodes-s3:${S3_BUCKET}" >/dev/null 2>&1 || rclone mkdir "euronodes-s3:${S3_BUCKET}"
rclone lsd bwb-pcloud-helpdesk: >/dev/null 2>&1

write_env_kv() {
    printf '%s=%q\n' "$1" "$2" >> "$ENV_FILE"
}

: > "$ENV_FILE"
write_env_kv BWB_HELPDESK_BACKUP_TARGET_LABEL helpdesk
write_env_kv BWB_HELPDESK_S3_DB_ENABLED 1
write_env_kv BWB_HELPDESK_S3_RCLONE_REMOTE euronodes-s3
write_env_kv BWB_HELPDESK_S3_BUCKET "$S3_BUCKET"
write_env_kv BWB_HELPDESK_S3_PATH "$S3_PATH"
write_env_kv BWB_HELPDESK_S3_RETENTION_DAYS "$DB_RETENTION"
write_env_kv BWB_HELPDESK_CONFIG_BACKUP_ENABLED 1
write_env_kv BWB_HELPDESK_PCLOUD_RCLONE_REMOTE bwb-pcloud-helpdesk
write_env_kv BWB_HELPDESK_PCLOUD_CONFIG_PATH "$PCLOUD_CONFIG_PATH"
write_env_kv BWB_HELPDESK_CONFIG_RETENTION_DAYS "$CONFIG_RETENTION"
write_env_kv BWB_HELPDESK_BACKUP_DB_NAME otobo
write_env_kv BWB_HELPDESK_BACKUP_ALERT_EMAIL "$ALERT_EMAIL"
write_env_kv BWB_HELPDESK_S3_ALERT_SIZE_GB "$S3_ALERT_GB"
write_env_kv BWB_HELPDESK_BACKUP_SMTP_HOST "$SMTP_HOST"
write_env_kv BWB_HELPDESK_BACKUP_SMTP_PORT "$SMTP_PORT"
write_env_kv BWB_HELPDESK_BACKUP_SMTP_USER "$SMTP_USER"
write_env_kv BWB_HELPDESK_BACKUP_SMTP_PASS "$SMTP_PASS"
write_env_kv BWB_HELPDESK_BACKUP_SMTP_FROM "$SMTP_FROM"
write_env_kv BWB_HELPDESK_BACKUP_SMTP_FROM_NAME "$SMTP_NAME"
chmod 600 "$ENV_FILE"

RUN_CMD="${INSTALL_DIR}/scripts/backup-helpdesk-run.sh >> /var/log/bwb-helpdesk/backup-cron.log 2>&1"
S3_CMD="${INSTALL_DIR}/scripts/backup-helpdesk-s3.sh >> /var/log/bwb-helpdesk/backup-s3-cron.log 2>&1"
CRON_1="0 1 * * * ${RUN_CMD}"
CRON_12="0 12 * * * ${S3_CMD}"
CRON_CFG="30 1 * * * ${INSTALL_DIR}/scripts/backup-helpdesk-config-pcloud.sh >> /var/log/bwb-helpdesk/backup-config-cron.log 2>&1"

( crontab -l 2>/dev/null \
    | grep -v 'backup-helpdesk-pcloud.sh' \
    | grep -v 'backup-helpdesk-run.sh' \
    | grep -v 'backup-helpdesk-config-pcloud.sh' \
    | grep -v 'backup-helpdesk-s3.sh' \
    || true
  echo "$CRON_1"
  echo "$CRON_12"
  echo "$CRON_CFG"
) | crontab -

echo "Cron:"
echo "  $CRON_1"
echo "  $CRON_12"
echo "  $CRON_CFG"
echo "Config: $ENV_FILE"
REMOTE

if [ "$RUN_NOW" -eq 1 ]; then
    log_info "Executar backups iniciais..."
    ssh "${SSH_OPTS[@]}" "$SSH_TARGET" '/opt/bwb-helpdesk/scripts/backup-helpdesk-run.sh'
fi

log_info "Setup concluído."
