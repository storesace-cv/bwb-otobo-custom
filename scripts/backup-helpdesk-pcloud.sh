#!/bin/bash
# LEGADO — dumps MariaDB iam para Euronodes S3 (scripts/backup-helpdesk-s3.sh).
# pCloud: apenas configs (scripts/backup-helpdesk-config-pcloud.sh).
echo "AVISO: backup-helpdesk-pcloud.sh está obsoleto. Use backup-helpdesk-run.sh" >&2
exec "$(dirname "$0")/backup-helpdesk-s3.sh"
