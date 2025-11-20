#!/usr/bin/env bash
# Usage:
#   ./scripts/backup_db_data.sh <database_name>
# Examples:
#   ./scripts/backup_db_data.sh dev
#   ./scripts/backup_db_data.sh db_feature_x
#
# This script creates a data-only backup (INSERT statements) of the specified database
# The backup is saved to /var/backups with a timestamp in the filename
# Connects to the PG server defined by PGHOST/PGPORT/PGUSER/PGPASSWORD
# Defaults are set in docker-compose: PGHOST=postgis-local, PGUSER=postgres, PGPASSWORD=localdev
set -euo pipefail

if [ "$#" -ne 1 ]; then
  echo "Usage: $0 <database_name>"
  exit 2
fi

DB_NAME="$1"
TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
BACKUP_FILE="/var/backups/${DB_NAME}_data_${TIMESTAMP}.sql"

: "${PGHOST:=postgis-local}"
: "${PGPORT:=5432}"
: "${PGUSER:=postgres}"

echo "Creating data-only backup of ${DB_NAME} from ${PGHOST}:${PGPORT} as ${PGUSER}..."
echo "Backup file: ${BACKUP_FILE}"

PGPASSWORD="${PGPASSWORD:-}" pg_dump \
  --data-only \
  --inserts \
  -h "${PGHOST}" \
  -p "${PGPORT}" \
  -U "${PGUSER}" \
  -f "${BACKUP_FILE}" \
  "${DB_NAME}"

echo "Backup completed successfully!"
echo "File: ${BACKUP_FILE}"
