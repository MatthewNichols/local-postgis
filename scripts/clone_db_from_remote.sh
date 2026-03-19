#!/usr/bin/env bash
# @description Clone a database from a remote PostgreSQL server to the local server
# @usage clone_db_from_remote <source_connection_string> <target_db>
# @arg source_connection_string  PostgreSQL connection string for the remote source
# @arg target_db                 Name for the new local database
# @env PGHOST                    Local PostgreSQL host (default: postgis-local)
# @env PGPORT                    Local PostgreSQL port (default: 5432)
# @env PGUSER                    Local PostgreSQL user (default: postgres)
# @env PGPASSWORD                Local PostgreSQL password (default: localdev)
# @example clone_db_from_remote "postgresql://user:pass@remote.host:5432/prod_db" local_copy
# @example clone_db_from_remote "postgresql://user:pass@10.0.1.50/staging_db" staging_local
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
