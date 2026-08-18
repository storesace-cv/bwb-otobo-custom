# shellcheck shell=bash
# Funções partilhadas pelos scripts de backup helpdesk (S3 + pCloud config).
# Espera ENV_FILE definido pelo script caller.

backup_read_env() {
    local key="$1"
    local def="${2:-}"
    local val="${!key-}"
    if [ -n "$val" ]; then
        echo "$val"
        return
    fi
    if [ -z "${ENV_FILE:-}" ] || [ ! -f "$ENV_FILE" ]; then
        echo "$def"
        return
    fi
    local line
    line="$(grep -E "^${key}=" "$ENV_FILE" 2>/dev/null | tail -1 || true)"
    if [ -z "$line" ]; then
        echo "$def"
        return
    fi
    val="${line#*=}"
    val="${val%\"}"
    val="${val#\"}"
    val="${val%\'}"
    val="${val#\'}"
    echo "$val"
}

backup_load_env_file() {
    if [ -n "${ENV_FILE:-}" ] && [ -f "$ENV_FILE" ]; then
        set -a
        # shellcheck disable=SC1090
        source "$ENV_FILE"
        set +a
    fi
}

backup_send_alert_email() {
    local subject="$1"
    local body="$2"
    local to host port user pass from_addr from_name

    to="$(backup_read_env BWB_HELPDESK_BACKUP_ALERT_EMAIL "")"
    [ -n "$to" ] || return 1

    host="$(backup_read_env BWB_HELPDESK_BACKUP_SMTP_HOST "")"
    port="$(backup_read_env BWB_HELPDESK_BACKUP_SMTP_PORT 2525)"
    user="$(backup_read_env BWB_HELPDESK_BACKUP_SMTP_USER "")"
    pass="$(backup_read_env BWB_HELPDESK_BACKUP_SMTP_PASS "")"
    from_addr="$(backup_read_env BWB_HELPDESK_BACKUP_SMTP_FROM "$user")"
    from_name="$(backup_read_env BWB_HELPDESK_BACKUP_SMTP_FROM_NAME "Backup Helpdesk BWB")"

    [ -n "$host" ] && [ -n "$user" ] && [ -n "$pass" ] || return 1

    BWB_ALERT_TO="$to" \
    BWB_ALERT_SUBJECT="$subject" \
    BWB_ALERT_BODY="$body" \
    BWB_ALERT_SMTP_HOST="$host" \
    BWB_ALERT_SMTP_PORT="$port" \
    BWB_ALERT_SMTP_USER="$user" \
    BWB_ALERT_SMTP_PASS="$pass" \
    BWB_ALERT_SMTP_FROM="$from_addr" \
    BWB_ALERT_SMTP_FROM_NAME="$from_name" \
    python3 - <<'PY'
import os
import smtplib
from email.message import EmailMessage
from email.utils import formataddr

to = os.environ["BWB_ALERT_TO"].strip()
subject = os.environ["BWB_ALERT_SUBJECT"]
body = os.environ["BWB_ALERT_BODY"]
host = os.environ["BWB_ALERT_SMTP_HOST"].strip()
port = int(os.environ["BWB_ALERT_SMTP_PORT"])
user = os.environ["BWB_ALERT_SMTP_USER"].strip()
password = os.environ["BWB_ALERT_SMTP_PASS"]
from_addr = os.environ["BWB_ALERT_SMTP_FROM"].strip() or user
from_name = os.environ.get("BWB_ALERT_SMTP_FROM_NAME", "").strip()

msg = EmailMessage()
msg["Subject"] = subject
msg["From"] = formataddr((from_name, from_addr)) if from_name else from_addr
msg["To"] = to
msg.set_content(body)
msg.add_alternative(f"<pre>{body}</pre>", subtype="html")

with smtplib.SMTP(host=host, port=port, timeout=30) as smtp:
    smtp.starttls()
    smtp.login(user, password)
    smtp.send_message(msg)
print("sent")
PY
}

backup_human_bytes() {
    python3 - <<PY
b = int("${1:-0}")
for u in ("B", "KB", "MB", "GB", "TB"):
    if b < 1024 or u == "TB":
        print(f"{b:.1f} {u}" if u != "B" else f"{b} B")
        break
    b /= 1024
PY
}
