# PostgreSQL database management shell functions
# These functions wrap the scripts in /opt/scripts for convenient use and are really cool.

backup_db_data() {
  /opt/scripts/backup_db_data.sh "$@"
}

backup_db_full() {
  /opt/scripts/backup_db_full.sh "$@"
}

clone_db() {
  /opt/scripts/clone_db.sh "$@"
}

drop_db() {
  /opt/scripts/drop_db.sh "$@"
}

restore_db_full() {
  /opt/scripts/restore_db_full.sh "$@"
}

