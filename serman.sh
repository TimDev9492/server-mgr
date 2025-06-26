#!/bin/bash

# SerMan - The Server Instance Manager
# A script to manage minecraft server instances.

# load environment
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
cd ${SCRIPT_DIR}
source ./common/utils.sh

# Load variables
if [ ! -f "./variables.sh" ]; then
  echo "[ERROR] variables.sh not found in the script directory." >&2
  exit 1
fi
source ./variables.sh

# Check for required commands
check_prerequisites

# Parse command line arguments into flags and positional arguments
VERBOSE=false

parse_args flags args "$@"

# parse the flags
for flag in "${flags[@]}"; do
  case "$flag" in
  -v)
    VERBOSE=true
    ;;
  esac
done

# parse arguments
operations=("list" "backup" "uninstall" "status")

print_usage() {
  if [ -z "${args[0]}" ]; then
    local IFS='|'
    local ops="${operations[*]}"
    echo "Usage: serman.sh <$ops>" >&2
  else
    case "${args[0]}" in
    list) ;;
    backup)
      echo "Usage: serman.sh backup <server_alias>" >&2
      ;;
    uninstall)
      echo "Usage: serman.sh uninstall <server_alias> [--delete-backups]" >&2
      ;;
    status)
      echo "Usage: serman.sh status" >&2
      ;;
    *)
      echo "[ERROR] Unknown operation: ${args[0]}" >&2
      ;;
    esac
  fi
}

if [ -z "${args[0]}" ]; then
  print_usage
  exit 1
fi

# logging
log() {
  $VERBOSE && echo "$@" >&2
}

# Check if the server installation is correct
check_server_installation() {
  local server_directory="$1"
  if [ ! -d "$server_directory" ]; then
    log "[ERROR] Server directory '$server_directory' does not exist."
    return 1
  fi
  local files_to_check=("server.jar" "server.properties" "bin/startServer.sh")
  for file in "${files_to_check[@]}"; do
    if [ ! -f "${server_directory}/${file}" ]; then
      log "[ERROR] Required file '$file' is missing in '$server_directory'."
      return 1
    fi
  done
  return 0
}

list_installed_servers() {
  for server_dir in "${MINECRAFT_SERVER_DIR}"/*; do
    # skip if not a directory
    [ -d "$server_dir" ] || continue
    server_alias=$(basename "$server_dir")
    # check if the server directory is a valid server installation
    check_server_installation "$server_dir" && echo "$server_alias" || continue
  done
}

get_player_amount() {
  local server_alias="$1"
  local server_directory="${MINECRAFT_SERVER_DIR}/${server_alias}"
  if [ ! -d "$server_directory" ]; then
    echo "[ERROR] Server '$server_alias' does not exist." >&2
    return 1
  fi
  # Check if the server is running
  if ! screen -list | grep -q "$(to_screen_session_name "$server_alias")"; then
    echo "[Idle]"
    return 0
  fi
  # Get the player count from the server log or status file
  local player_count=$(grep -oP 'There are \K\d+' "${server_directory}/logs/latest.log" | tail -n1)
  echo "$player_count"
}

operation="${args[0]}"

case "$operation" in
list)
  list_installed_servers
  ;;
backup)
  server_alias="${args[1]}"
  if [ -z "$server_alias" ]; then
    print_usage "${args[0]}"
    exit 1
  fi
  # check if server installation is corret
  server_directory="${MINECRAFT_SERVER_DIR}/${server_alias}"
  check_server_installation "$server_directory" || {
    echo "[ERROR] Server '$server_alias' is corrupted." >&2
    $VERBOSE || echo "[INFO] Run again with -v for verbose logging." >&2
    exit 1
  }
  bash -c '
    source ./helpers/backup_server.sh
  ' _ "$server_alias"
  ;;
uninstall)
  server_alias="${args[1]}"
  if [ -z "$server_alias" ]; then
    print_usage "${args[0]}"
    exit 1
  fi
  if in_array "--delete-backups" "${flags[@]}"; then
    delete_backups=true
  else
    delete_backups=false
  fi
  # check if server installation is correct
  server_directory="${MINECRAFT_SERVER_DIR}/${server_alias}"
  if [ ! -d "$server_directory" ]; then
    log "[ERROR] Server '$server_alias' does not exist."
    exit 1
  fi
  rm -rf "$server_directory"
  log "[INFO] Uninstalled server '$server_alias'."
  if $delete_backups; then
    backup_dir="${MINECRAFT_SERVER_BACKUP_DIR}/${server_alias}"
    if [ -d "$backup_dir" ]; then
      rm -rf "$backup_dir"
      log "[INFO] Deleted backups for server '$server_alias'."
    else
      log "[INFO] No backups found for server '$server_alias'."
    fi
  fi
  ;;
status)
  installed_servers="$(list_installed_servers)"

  # First, find the maximum width of the alias names
  max_width=0
  while IFS= read -r alias; do
    ((${#alias} > max_width)) && max_width=${#alias}
    aliases+=("$alias")
  done <<<"$installed_servers"

  while IFS= read -r installed_server_alias; do
    status=$(get_server_status "$installed_server_alias")
    printf "%-${max_width}s : %s\n" "$installed_server_alias" "$status"
  done <<<"$installed_servers"
  ;;
*)
  echo "[ERROR] Unknown operation: $operation" >&2
  print_usage
  exit 1
  ;;
esac
