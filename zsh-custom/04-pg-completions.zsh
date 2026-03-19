#!/usr/bin/env zsh
# Tab completion for pg scripts and helper functions

# Complete existing database names from the local PG server
_pg_databases() {
  local dbs
  dbs=(${(f)"$(psql \
    -h "${PGHOST:-postgis-local}" \
    -p "${PGPORT:-5432}" \
    -U "${PGUSER:-postgres}" \
    -tAc "SELECT datname FROM pg_database WHERE datistemplate = false" \
    2>/dev/null)"})
  compadd -a dbs
}

# Complete script names available in /opt/scripts (for pg-help)
_pg_script_names() {
  local scripts
  scripts=(${${(f)"$(ls /opt/scripts/*.sh 2>/dev/null)"}:t:r})
  compadd -a scripts
}

# Complete backup files in /var/backups
_pg_backup_files() {
  _files -W /var/backups
}

compdef '_arguments "1:database:_pg_databases"' \
  backup_db_data backup_db_full drop_db

# Suggest <source_db>_ as the starting point for the target name
_clone_db_target() {
  local source="${words[2]}"
  if [[ -n "$source" ]]; then
    compadd -S '' "${source}_"
  fi
}

compdef '_arguments \
  "1:source database:_pg_databases" \
  "2:target database:_clone_db_target"' \
  clone_db

compdef '_arguments \
  "1:source connection string:" \
  "2:target database name:"' \
  clone_db_from_remote

compdef '_arguments \
  "1:target database name:" \
  "2:backup file:_pg_backup_files"' \
  restore_db_full

compdef '_arguments "1:command:_pg_script_names"' pg-help
