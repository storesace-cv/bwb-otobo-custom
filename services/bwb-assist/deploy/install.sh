#!/usr/bin/env bash
# Install / update BWB Assist on mcp-mail host (178.159.34.165).
# Does NOT install Ollama by default (requires >= ~8 GiB free RAM for 7B).
set -euo pipefail

REPO_ROOT="${REPO_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
APP_DIR="${APP_DIR:-/var/www/bwb-assist}"
DATA_DIR="${DATA_DIR:-/var/lib/bwb-assist}"
SERVICE_SRC="$REPO_ROOT/deploy/bwb-assist.service"
NGINX_SRC="$REPO_ROOT/deploy/nginx-assist.conf"

echo "==> Host memory check"
AVAIL_MIB=$(awk '/MemAvailable:/ {print int($2/1024)}' /proc/meminfo)
echo "MemAvailable=${AVAIL_MIB} MiB"
if [[ "$AVAIL_MIB" -lt 1500 ]]; then
  echo "WARN: low memory; keeping Ollama disabled (extractive mode)."
fi

if ! python3 -c 'import venv' 2>/dev/null; then
  echo "==> Installing python3-venv"
  export DEBIAN_FRONTEND=noninteractive
  apt-get update -qq
  apt-get install -y -qq python3-venv python3-pip
fi

echo "==> User and dirs"
id bwbassist >/dev/null 2>&1 || useradd --system --no-create-home --shell /usr/sbin/nologin --comment "bwb-assist" bwbassist
mkdir -p "$APP_DIR" "$DATA_DIR"
chown -R bwbassist:bwbassist "$DATA_DIR"
chmod 750 "$DATA_DIR"

echo "==> Sync app"
rsync -a --delete \
  --exclude .venv --exclude .env --exclude __pycache__ --exclude .git \
  --filter 'P .env' \
  "$REPO_ROOT/" "$APP_DIR/"
chown -R root:bwbassist "$APP_DIR"
chmod 755 "$APP_DIR"

if [[ ! -f "$APP_DIR/.env" ]]; then
  echo "==> Creating .env"
  BEARER="$(openssl rand -hex 32)"
  cp "$REPO_ROOT/deploy/env.example" "$APP_DIR/.env"
  sed -i "s/^BWB_ASSIST_BEARER=.*/BWB_ASSIST_BEARER=$BEARER/" "$APP_DIR/.env"
  sed -i "s|^BWB_ASSIST_DATA_DIR=.*|BWB_ASSIST_DATA_DIR=$DATA_DIR|" "$APP_DIR/.env"
  sed -i "s/^BWB_ASSIST_OLLAMA_ENABLED=.*/BWB_ASSIST_OLLAMA_ENABLED=0/" "$APP_DIR/.env"
  chown root:bwbassist "$APP_DIR/.env"
  chmod 640 "$APP_DIR/.env"
  echo "Generated Bearer (store also on OTOBO /opt/otobo/var/bwb-assist.token):"
  echo "$BEARER"
else
  chown root:bwbassist "$APP_DIR/.env"
  chmod 640 "$APP_DIR/.env"
fi

echo "==> Python venv"
python3 -m venv "$APP_DIR/.venv"
"$APP_DIR/.venv/bin/pip" install --upgrade pip
"$APP_DIR/.venv/bin/pip" install -r "$APP_DIR/requirements.txt"
chown -R root:bwbassist "$APP_DIR/.venv"

echo "==> systemd"
cp "$SERVICE_SRC" /etc/systemd/system/bwb-assist.service
systemctl daemon-reload
systemctl enable bwb-assist.service
systemctl restart bwb-assist.service
sleep 1
systemctl --no-pager --full status bwb-assist.service | sed -n '1,20p'

if [[ -d /etc/nginx ]]; then
  echo "==> nginx snippet (127.0.0.1:18101)"
  cp "$NGINX_SRC" /etc/nginx/sites-available/bwb-assist.conf
  ln -sfn /etc/nginx/sites-available/bwb-assist.conf /etc/nginx/sites-enabled/bwb-assist.conf
  nginx -t && systemctl reload nginx
fi

echo "==> Health"
curl -sS "http://127.0.0.1:18100/health" || true
echo
echo "Done. Ollama remains disabled until RAM upgrade (>=8 GiB free)."
