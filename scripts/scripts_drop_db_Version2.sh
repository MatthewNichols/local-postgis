#!/usr/bin/env bash
# Usage:
#   ./scripts/drop_db.sh <target_db>
# This will terminate connections and drop the database.
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