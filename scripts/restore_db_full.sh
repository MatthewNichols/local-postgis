#!/usr/bin/env bash
# @description Restore a full SQL backup into a new database (target must not already exist)
# @usage restore_db_full <database_name> <backup_filename>
# @arg database_name   Name for the restored database (must not already exist)
# @arg backup_filename Filename within /var/backups to restore from
# @env PGHOST          PostgreSQL host (default: postgis-local)
# @env PGPORT          PostgreSQL port (default: 5432)
# @env PGUSER          PostgreSQL user (default: postgres)
# @env PGPASSWORD      PostgreSQL password (default: localdev)
# @example restore_db_full dev dev_full_20251226_120000.sql
set -euo pipefail

if [ "$#" -ne 2 ]; then
  echo "Usage: $0 <database_name> <backup_filename>"
  exit 2
fi

DB_NAME="$1"
BACKUP_NAME="$2"
BACKUP_FILE="/var/backups/${BACKUP_NAME}"

: "${PGHOST:=postgis-local}"
: "${PGPORT:=5432}"
: "${PGUSER:=postgres}"

if [ ! -f "${BACKUP_FILE}" ]; then
  echo "Backup file not found: ${BACKUP_FILE}"
  exit 3
fi

export PGPASSWORD="${PGPASSWORD:-}"

EXISTS="$(PGPASSWORD="$PGPASSWORD" psql -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" -tAc "SELECT 1 FROM pg_database WHERE datname = '$DB_NAME'")"

if [ "$EXISTS" = "1" ]; then
  echo "Database '${DB_NAME}' already exists. Refusing to overwrite."
  echo "Drop the database first or choose a different name."
  exit 4
fi

echo "Creating database '${DB_NAME}' on ${PGHOST}:${PGPORT} as ${PGUSER}..."
PGPASSWORD="$PGPASSWORD" psql -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" -c "CREATE DATABASE \"${DB_NAME}\";"

echo "Restoring backup '${BACKUP_NAME}' into '${DB_NAME}'..."
PGPASSWORD="$PGPASSWORD" psql -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" -d "$DB_NAME" -f "${BACKUP_FILE}"

echo "Restore completed successfully."
echo "Restored file: ${BACKUP_FILE} -> database: ${DB_NAME}"