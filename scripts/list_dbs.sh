#!/usr/bin/env bash
# @description List local databases with size, clone date, last write time, and base/branch classification
# @usage list_dbs [--json]
# @arg --json      Emit a JSON array instead of a table (for scripts and AI tooling)
# @env PGHOST      PostgreSQL host (default: postgis-local)
# @env PGPORT      PostgreSQL port (default: 5432)
# @env PGUSER      PostgreSQL user (default: postgres)
# @env PGPASSWORD  PostgreSQL password
# @note Branch databases follow the convention <stem>_branch_<branch>
# @note cloned = date parsed from the "Cloned from X on <timestamp>" comment written by clone_db
# @note last_write = newest file mtime in the DB's data directory (approximate; reads are not tracked)
# @example list_dbs --json
set -euo pipefail

FORMAT="table"
case "${1:-}" in
  "") ;;
  --json) FORMAT="json" ;;
  *) echo "Usage: $0 [--json]"; exit 2 ;;
esac

: "${PGHOST:=postgis-local}"
: "${PGPORT:=5432}"
: "${PGUSER:=postgres}"

# kind/stem/branch are derived from the <stem>_branch_<branch> naming convention
BASE_QUERY="
SELECT
  d.datname AS name,
  CASE WHEN d.datname LIKE '%\_branch\_%' THEN 'branch' ELSE 'base' END AS kind,
  regexp_replace(d.datname, '_branch_.*\$', '') AS stem,
  NULLIF(substring(d.datname from '_branch_(.*)\$'), '') AS branch,
  pg_database_size(d.datname) AS size_bytes,
  pg_size_pretty(pg_database_size(d.datname)) AS size,
  (SELECT count(*) FROM pg_stat_activity a WHERE a.datname = d.datname) AS connections,
  shobj_description(d.oid, 'pg_database') AS comment,
  to_timestamp(substring(shobj_description(d.oid, 'pg_database') from 'Cloned from .* on ([0-9]{14})\$'), 'YYYYMMDDHH24MISS') AS cloned,
  (SELECT max((pg_stat_file('base/' || d.oid || '/' || f)).modification) FROM pg_ls_dir('base/' || d.oid) f) AS last_write
FROM pg_database d
WHERE NOT d.datistemplate AND d.datname <> 'postgres'
"

if [ "$FORMAT" = "json" ]; then
  psql -h "${PGHOST}" -p "${PGPORT}" -U "${PGUSER}" -d postgres -tA \
    -c "SELECT coalesce(json_agg(t ORDER BY stem, kind DESC, name), '[]') FROM (${BASE_QUERY}) t;"
else
  psql -h "${PGHOST}" -p "${PGPORT}" -U "${PGUSER}" -d postgres \
    -c "SELECT name, kind, size, connections AS conns, to_char(cloned, 'YYYY-MM-DD') AS cloned, to_char(last_write, 'YYYY-MM-DD HH24:MI') AS last_write, comment FROM (${BASE_QUERY}) t ORDER BY stem, kind DESC, name;"
fi
