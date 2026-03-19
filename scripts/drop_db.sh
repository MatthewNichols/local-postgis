#!/usr/bin/env bash
# @description Terminate all connections and drop a database (prompts for confirmation)
# @usage drop_db <database_name>
# @arg database_name  Name of the database to drop
# @env PGHOST         PostgreSQL host (default: postgis-local)
# @env PGPORT         PostgreSQL port (default: 5432)
# @env PGUSER         PostgreSQL user (default: postgres)
# @env PGPASSWORD     PostgreSQL password (default: localdev)
# @example drop_db db_feature_x
set -euo pipefail

if [ "$#" -ne 1 ]; then
  echo "Usage: $0 <db_to_drop>"
  exit 2
fi

TARGET_DB="$1"

: "${PGHOST:=postgis-local}"
: "${PGPORT:=5432}"
: "${PGUSER:=postgres}"

read -r -p "Are you sure you want to DROP database '${TARGET_DB}' on ${PGHOST}:${PGPORT}? Type YES to proceed: " confirm
if [ "$confirm" != "YES" ]; then
  echo "Aborting."
  exit 1
fi

echo "Revoking new connections and terminating active backends for ${TARGET_DB}..."
PGPASSWORD="${PGPASSWORD:-}" psql -h "${PGHOST}" -p "${PGPORT}" -U "${PGUSER}" -d postgres -c "REVOKE CONNECT ON DATABASE \"${TARGET_DB}\" FROM public;"
PGPASSWORD="${PGPASSWORD:-}" psql -h "${PGHOST}" -p "${PGPORT}" -U "${PGUSER}" -d postgres -c "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = '${TARGET_DB}' AND pid <> pg_backend_pid();"

echo "Dropping database ${TARGET_DB}..."
PGPASSWORD="${PGPASSWORD:-}" dropdb -h "${PGHOST}" -p "${PGPORT}" -U "${PGUSER}" "${TARGET_DB}"

echo "Dropped ${TARGET_DB}."