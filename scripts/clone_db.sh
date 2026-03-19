#!/usr/bin/env bash
# @description Clone a local database to a new database on the same server
# @usage clone_db <source_db> <target_db>
# @arg source_db   Name of the database to clone from
# @arg target_db   Name for the new cloned database
# @env PGHOST      PostgreSQL host (default: postgis-local)
# @env PGPORT      PostgreSQL port (default: 5432)
# @env PGUSER      PostgreSQL user (default: postgres)
# @env PGPASSWORD  PostgreSQL password (default: localdev)
# @example clone_db dev db_feature_x
set -euo pipefail

if [ "$#" -ne 2 ]; then
  echo "Usage: $0 <source_db> <target_db>"
  exit 2
fi

SOURCE_DB="$1"
TARGET_DB="$2"
TIMESTAMP="$(date +%Y%m%d%H%M%S)"
CLONE_DIR="/var/backups/clones"
DUMP_FILE="${CLONE_DIR}/${SOURCE_DB}_${TIMESTAMP}.dump"

: "${PGHOST:=postgis-local}"
: "${PGPORT:=5432}"
: "${PGUSER:=postgres}"

# Ensure the clones directory exists
mkdir -p "${CLONE_DIR}"

echo "Dumping ${SOURCE_DB} from ${PGHOST}:${PGPORT} as ${PGUSER} -> ${DUMP_FILE}..."
PGPASSWORD="${PGPASSWORD:-}" pg_dump -Fc -h "${PGHOST}" -p "${PGPORT}" -U "${PGUSER}" -f "${DUMP_FILE}" "${SOURCE_DB}"

echo "Creating target DB ${TARGET_DB}..."
PGPASSWORD="${PGPASSWORD:-}" createdb -h "${PGHOST}" -p "${PGPORT}" -U "${PGUSER}" "${TARGET_DB}"

echo "Restoring dump into ${TARGET_DB}..."
PGPASSWORD="${PGPASSWORD:-}" pg_restore -h "${PGHOST}" -p "${PGPORT}" -U "${PGUSER}" -d "${TARGET_DB}" "${DUMP_FILE}"

echo "Setting ownership of objects in ${TARGET_DB} to ${PGUSER} (best-effort)..."
PGPASSWORD="${PGPASSWORD:-}" psql -h "${PGHOST}" -p "${PGPORT}" -U "${PGUSER}" -d "${TARGET_DB}" -c "REASSIGN OWNED BY current_user TO \"${PGUSER}\";" || true

echo "Adding database comment..."
PGPASSWORD="${PGPASSWORD:-}" psql -h "${PGHOST}" -p "${PGPORT}" -U "${PGUSER}" -d "${TARGET_DB}" -c "COMMENT ON DATABASE \"${TARGET_DB}\" IS 'Cloned from ${SOURCE_DB} on ${TIMESTAMP}';"

echo "Done. You can connect using:"
echo "  psql postgresql://${PGUSER}:<password>@${PGHOST}:${PGPORT}/${TARGET_DB}"
echo "or with pgcli (interactive):"
echo "  pgcli postgresql://${PGUSER}:<password>@${PGHOST}:${PGPORT}/${TARGET_DB}"