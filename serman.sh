#!/bin/bash

# SerMan - The Server Instance Manager
# A script to manage minecraft server instances.

# load environment
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
cd ${SCRIPT_DIR}
source ./common/utils.sh

# Load variables
if [ ! -f "./load_config.sh" ]; then
  echo "[ERROR] load_config.sh not found in the script directory." >&2
  exit 1
fi
source ./load_config.sh

# Check for required commands
check_prerequisites

VERBOSE=false

# Parse command line arguments into flags and positional arguments
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
operations=("list" "backup" "uninstall" "status" "start" "stop")
backup_operations=("create" "delete" "list")

print_usage() {
  if [ -z "${args[0]}" ]; then
    local IFS='|'
    local ops="${operations[*]}"
    echo "Usage: serman.sh <$ops>" >&2
  else
    case "${args[0]}" in
    list) ;;
    backup)
      case "${args[1]}" in
      create)
        echo "Usage: serman.sh backup create <server_alias>" >&2
        ;;
      delete)
        echo "Usage: serman.sh backup delete <server_alias> <backup_id|'latest'>" >&2
        ;;
      list)
        echo "Usage: serman.sh backup list <server_alias> [--json-format]" >&2
        ;;
      *)
        local IFS='|'
        local backup_ops="${backup_operations[*]}"
        echo "Usage: serman.sh backup <${backup_ops[*]}>" >&2
        ;;
      esac
      ;;
    uninstall)
      echo "Usage: serman.sh uninstall <server_alias> [--delete-backups]" >&2
      ;;
    status)
      echo "Usage: serman.sh status" >&2
      ;;
    start)
      echo "Usage: serman.sh start <server_alias>" >&2
      ;;
    stop)
      echo "Usage: serman.sh stop <server_alias> [<delay_seconds>] [<note>] [<reason>] [--wait]" >&2
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

operation="${args[0]}"

case "$operation" in
list)
  list_installed_servers
  ;;
backup)
  backup_operation="${args[1]}"
  if [ -z "$backup_operation" ] || ! in_array "$backup_operation" "${backup_operations[@]}"; then
    print_usage "${args[0]}"
    exit 1
  fi
  case "$backup_operation" in
  create)
    server_alias="${args[2]}"
    if [ -z "$server_alias" ]; then
      print_usage "${args[0]}" "${args[1]}"
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
  delete)
    server_alias="${args[2]}"
    if [ -z "$server_alias" ]; then
      print_usage "${args[0]}" "${args[1]}"
      exit 1
    fi
    # check if server installation is corret
    server_directory="${MINECRAFT_SERVER_DIR}/${server_alias}"
    check_server_installation "$server_directory" || {
      echo "[ERROR] Server '$server_alias' is corrupted." >&2
      $VERBOSE || echo "[INFO] Run again with -v for verbose logging." >&2
      exit 1
    }
    backup_id="${args[3]}"
    if [ -z "$backup_id" ]; then
      print_usage "${args[0]}" "${args[1]}" "${args[2]}"
      exit 1
    fi

    backup_infos="$(./serman.sh backup list "$server_alias" --json-format)"
    if [ "$?" -ne 0 ]; then
      echo "[ERROR] Failed to list backups for server '$server_alias'." >&2
      exit 1
    fi

    if [ "$backup_id" == "latest" ]; then
      latest_timestamp=$(echo "$backup_infos" | jq -r '.[].unix_time' | sort -n | tail -n1)
      backup_meta="$(echo "$backup_infos" | jq -rc 'sort_by(.unix_time) | last')"
    else
      backup_meta="$(echo "$backup_infos" | jq -rc --arg id "$backup_id" '.[] | select(.id == $id)')"
    fi
    matching_count=$(echo "$backup_meta" | jq -s 'length')
    if [ "$matching_count" -eq 0 ]; then
      echo "[ERROR] Backup with ID '$backup_id' not found for server '$server_alias'." >&2
      exit 1
    elif [ "$matching_count" -gt 1 ]; then
      echo "[ERROR] Found multiple backups with the same ID. This should not happen and needs manual fixing!" >&2
      exit 1
    fi

    rm -rf "$(echo "$backup_meta" | jq -rc '.path')"
    if [ $? -ne 0 ]; then
      echo "[ERROR] Failed to delete backup with ID '$backup_id' for server '$server_alias'." >&2
      exit 1
    fi
    echo "[INFO] Successfully deleted backup with ID '$backup_id' for server '$server_alias'." >&2

    latest_path="$(
      ./serman.sh backup list "$server_alias" --json-format |
        jq -rc 'sort_by(.unix_time) | last | .path'
    )"
    if [ "$latest_path" == "null" ]; then
      log "[INFO] No backups left for server '$server_alias'. Removing 'latest' symlink and backup directory."
      rm -rf "${MINECRAFT_SERVER_BACKUP_DIR}/${server_alias}"
      if [ $? -ne 0 ]; then
        log "[ERROR] Failed to remove backup directory for server '$server_alias'."
        exit 1
      fi
      exit 0
    fi
    log "[INFO] Linking latest backup to $latest_path" >&2
    ln -sf "$latest_path" "${MINECRAFT_SERVER_BACKUP_DIR}/${server_alias}/latest"
    if [ $? -ne 0 ]; then
      echo "[ERROR] Failed to create symlink for latest backup." >&2
      exit 1
    fi
    ;;
  list)
    server_alias="${args[2]}"
    if [ -z "$server_alias" ]; then
      print_usage "${args[0]}" "${args[1]}"
      exit 1
    fi
    # check if server installation is corret
    server_directory="${MINECRAFT_SERVER_DIR}/${server_alias}"
    check_server_installation "$server_directory" || {
      echo "[ERROR] Server '$server_alias' is corrupted." >&2
      $VERBOSE || echo "[INFO] Run again with -v for verbose logging." >&2
      exit 1
    }
    # list backup information
    if in_array "--json-format" "${flags[@]}"; then
      declare -a json_objs
    else
      declare -a table_rows
    fi
    table_delim='|'
    for backup_dir in "${MINECRAFT_SERVER_BACKUP_DIR}/${server_alias}"/*; do
      # skip symlinks
      [ -L "$backup_dir" ] && continue
      # skip if not a directory
      [ -d "$backup_dir" ] || continue
      check_server_installation "$backup_dir" || continue
      backup_path="${backup_dir}"
      backup_id="$(basename "$backup_path")"
      backup_unix="$(get_creation_or_mod_time "$backup_path")"
      if in_array "--json-format" "${flags[@]}"; then
        json_objs+=("$(
          jq -nrc --arg id "$backup_id" --arg unix_time "$backup_unix" --arg path "$backup_path" \
            '{id: $id, unix_time: $unix_time, path: $path}'
        )")
      else
        table_rows+=("${backup_id}${table_delim}${backup_unix}${table_delim}${backup_path}")
      fi
    done
    if in_array "--json-format" "${flags[@]}"; then
      IFS=',' joined_json="${json_objs[*]}"
      output="$(jq -nr "[${joined_json}]")"
    else
      output="$(print_table "$table_delim" "  " "Backup ID${table_delim}Backup Time${table_delim}Path" "${table_rows[@]}")"
    fi
    echo "$output"
    ;;
  *)
    echo "[ERROR] Unknown backup operation: $backup_operation" >&2
    print_usage "${args[0]}"
    exit 1
    ;;
  esac
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

  [ -z "$installed_servers" ] && exit 0

  parsing_delimiter='|'
  out_delimiter=' : '
  status_lines=()
  while IFS='' read -r alias; do
    status_lines+=("${alias}${parsing_delimiter}$(get_server_status "$alias")")
  done <<<"$installed_servers"
  if [ ${#status_lines[@]} -eq 0 ]; then
    log "[INFO] No servers installed."
    exit 0
  fi

  print_table "$parsing_delimiter" "$out_delimiter" "" "${status_lines[@]}"
  ;;
start)
  server_alias="${args[1]}"
  if [ -z "$server_alias" ]; then
    print_usage "${args[0]}"
    exit 1
  fi
  # check if server installation is correct
  server_directory="${MINECRAFT_SERVER_DIR}/${server_alias}"
  check_server_installation "$server_directory" || {
    echo "[ERROR] Server '$server_alias' is corrupted." >&2
    exit 1
  }
  # check if server is already running
  server_status=$(get_server_status "$server_alias")
  if [[ "$server_status" == "Running" ]]; then
    echo "[ERROR] Server '$server_alias' is already running." >&2
    exit 1
  fi
  # Sart the server
  source "${server_directory}/bin/startServer.sh"
  echo "[INFO] Starting server '$server_alias'."
  ;;
stop)
  server_alias="${args[1]}"
  delay_seconds="${args[2]:-0}"
  if ! is_number "$delay_seconds"; then
    echo "[ERROR] Delay seconds must be a valid number." >&2
    print_usage "${args[0]}"
    exit 1
  fi
  stop_note="${args[3]:-null}"
  kick_reason="${args[4]:-The server was stopped.}"
  wait_flag=false
  in_array "--wait" "${flags[@]}" && wait_flag=true

  if [ -z "$server_alias" ] || [ -z "$delay_seconds" ]; then
    print_usage "${args[0]}"
    exit 1
  fi

  # check if server installation is correct
  server_directory="${MINECRAFT_SERVER_DIR}/${server_alias}"
  check_server_installation "$server_directory" || {
    echo "[ERROR] Server '$server_alias' is corrupted." >&2
    exit 1
  }
  # check if server is running
  server_status=$(get_server_status "$server_alias")
  if [[ "$server_status" != "Running" ]]; then
    echo "[ERROR] Server '$server_alias' is not running." >&2
    exit 1
  fi

  if $wait_flag; then
    (
      source ./helpers/schedule_server_stop.sh "$server_alias" "$delay_seconds" "$stop_note" "$kick_reason"
    )
    if [ $? -ne 0 ]; then
      echo "[ERROR] Failed to stop server '$server_alias'." >&2
      exit 1
    else
      echo "[INFO] Server '$server_alias' successfully stopped."
    fi
  else
    (
      source ./helpers/schedule_server_stop.sh "$server_alias" "$delay_seconds" "$stop_note" "$kick_reason"
    ) >/dev/null 2>&1 &
  fi
  ;;
*)
  print_usage
  exit 1
  ;;
esac

exit 0
