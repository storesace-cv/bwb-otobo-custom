#!/bin/bash
# Orquestra backup helpdesk: BD → S3 Euronodes; configs → pCloud.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

"$SCRIPT_DIR/backup-helpdesk-s3.sh"
"$SCRIPT_DIR/backup-helpdesk-config-pcloud.sh"
