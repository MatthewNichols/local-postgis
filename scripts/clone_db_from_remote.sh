#!/usr/bin/env bash
# Usage:
#   ./scripts/clone_db_from_remote.sh <source_connection_string> <target_db>
# Examples:
#   ./scripts/clone_db_from_remote.sh "postgresql://user:pass@remote.host:5432/prod_db" local_copy
#   ./scripts/clone_db_from_remote.sh "postgresql://user:pass@10.0.1.50/staging_db" staging_local
#
# This script clones a database from a remote PostgreSQL server (specified by connection string)
# to the local PG server defined by PGHOST/PGPORT/PGUSER/PGPASSWORD
# Defaults are set in docker-compose: PGHOST=postgis-local, PGUSER=postgres, PGPASSWORD=localdev
set -euo pipefail

if [ "$#" -ne 2 ]; then
  echo "Usage: $0 <source_connection_string> <target_db>"
  echo "Example: $0 \"postgresql://user:pass@remote.host:5432/source_db\" target_db"
  exit 2
fi

SOURCE_CONN_STRING="$1"
TARGET_DB="$2"
TIMESTAMP="$(date +%Y%m%d%H%M%S)"
CLONE_DIR="/var/backups/clones"
DUMP_FILE="${CLONE_DIR}/remote_${TIMESTAMP}.dump"

# Local target server defaults
: "${PGHOST:=postgis-local}"
: "${PGPORT:=5432}"
: "${PGUSER:=postgres}"

# Ensure the clones directory exists
mkdir -p "${CLONE_DIR}"

echo "Dumping database from remote server -> ${DUMP_FILE}..."
pg_dump -Fc -d "${SOURCE_CONN_STRING}" -f "${DUMP_FILE}"

echo "Creating target DB ${TARGET_DB} on ${PGHOST}:${PGPORT}..."
PGPASSWORD="${PGPASSWORD:-}" createdb -h "${PGHOST}" -p "${PGPORT}" -U "${PGUSER}" "${TARGET_DB}"

echo "Restoring dump into ${TARGET_DB}..."
PGPASSWORD="${PGPASSWORD:-}" pg_restore -h "${PGHOST}" -p "${PGPORT}" -U "${PGUSER}" -d "${TARGET_DB}" "${DUMP_FILE}"

echo "Setting ownership of objects in ${TARGET_DB} to ${PGUSER} (best-effort)..."
PGPASSWORD="${PGPASSWORD:-}" psql -h "${PGHOST}" -p "${PGPORT}" -U "${PGUSER}" -d "${TARGET_DB}" -c "REASSIGN OWNED BY current_user TO \"${PGUSER}\";" || true

echo "Adding database comment..."
PGPASSWORD="${PGPASSWORD:-}" psql -h "${PGHOST}" -p "${PGPORT}" -U "${PGUSER}" -d "${TARGET_DB}" -c "COMMENT ON DATABASE \"${TARGET_DB}\" IS 'Cloned from remote server on ${TIMESTAMP}';"

echo "Done. You can connect using:"
echo "  psql postgresql://${PGUSER}:<password>@${PGHOST}:${PGPORT}/${TARGET_DB}"
echo "or with pgcli (interactive):"
echo "  pgcli postgresql://${PGUSER}:<password>@${PGHOST}:${PGPORT}/${TARGET_DB}"
