#!/usr/bin/env bash
# @description Create a data-only backup (INSERT statements) of a database
# @usage backup_db_data <database_name>
# @arg database_name  Name of the database to back up
# @env PGHOST         PostgreSQL host (default: postgis-local)
# @env PGPORT         PostgreSQL port (default: 5432)
# @env PGUSER         PostgreSQL user (default: postgres)
# @env PGPASSWORD     PostgreSQL password (default: localdev)
# @example backup_db_data dev
# @example backup_db_data db_feature_x
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
