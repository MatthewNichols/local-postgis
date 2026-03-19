#!/usr/bin/env zsh
# pg-help - show documentation for all pg scripts in the environment

SCRIPTS_DIR="/opt/scripts"

_pg_list_commands() {
  for script in "$SCRIPTS_DIR"/*.sh; do
    [[ -f "$script" ]] || continue
    name=$(basename "$script" .sh)
    desc=$(grep '^# @description' "$script" | head -1 | sed 's/# @description //')
    printf "  %-30s %s\n" "$name" "$desc"
  done
}

_pg_show_command_help() {
  local script="$SCRIPTS_DIR/$1.sh"
  if [[ ! -f "$script" ]]; then
    # try without stripping extension in case user passed full name
    script="$SCRIPTS_DIR/$1"
  fi
  if [[ ! -f "$script" ]]; then
    echo "Unknown command: $1" >&2
    return 1
  fi
  grep '^# @' "$script" | sed 's/^# @//'
}

pg-help() {
  case "${1:-}" in
    "")
      echo "Available commands:"
      _pg_list_commands
      echo ""
      echo "Run 'pg-help <command>' for detailed usage."
      ;;
    *)
      _pg_show_command_help "$1"
      ;;
  esac
}
