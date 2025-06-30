#!/bin/bash

# A gum wrapper for serman.sh

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
cd "${SCRIPT_DIR}/../"
source ./common/utils.sh

# Load variables
if [ ! -f "./load_config.sh" ]; then
  echo "[ERROR] load_config.sh not found in the script directory." >&2
  exit 1
fi
source ./load_config.sh

# Check for required commands
check_prerequisites gum cut

select_server() {
  # while read -r line; do
  #   local alias="$(trim "$(echo "$line" | cut -d':' -f1)")"
  #   local status="$(trim "$(echo "$line" | cut -d':' -f2)")"
  #   echo "$alias ($status)" >&2
  # done <<<"$serman_output"
  local selection="$(./serman.sh status | gum choose \
    --header "Select a server:" \
    --limit=1)"
  local alias="$(trim "$(echo "$selection" | cut -d':' -f1)")"
  echo "$alias"
}

select_operation() {
  local server_alias="$1"

  local operations=()
  local status="$(get_server_status "$server_alias")"
  case "$status" in
  "Idle")
    operations+=("start")
    ;;
  "Running")
    operations+=("stop" "restart")
    ;;
  *)
    echo "[ERROR] Unknown server status: $status" >&2
    exit 1
    ;;
  esac
  operations+=("backup" "uninstall")

  gum choose \
    --header "What do you want to do?" \
    --limit=1 \
    "${operations[@]}"
}

select_backups() {
  local server_alias="$1"
  local delimiter=${2:- | }
  local -n selected="$3"

  selected=()

  echo "[INFO] Listing backups..." >&2

  local backup_infos="$(./serman.sh backup list "$server_alias" --json-format)"
  local backup_count=$(echo "$backup_infos" | jq -r 'length')
  if [ "$backup_count" -eq 0 ]; then
    echo "[INFO] No backups found for server '$server_alias'." >&2
    return 0
  fi
  local backup_options=()
  for ((i = 0; i < $backup_count; i++)); do
    local backup_meta="$(echo "$backup_infos" | jq -r ".[$i]")"
    local backup_id="$(echo "$backup_meta" | jq -r '.id')"
    local backup_unix_time="$(echo "$backup_meta" | jq -r '.unix_time')"
    local now_unix_time="$(date +%s)"
    local time_since_backup="$(print_elapsed_time "$backup_unix_time" "$now_unix_time")"
    backup_options+=("${backup_id}${delimiter}(${time_since_backup} ago)")
  done

  print_table "$delimiter" "$delimiter" "" "${backup_options[@]}" | gum choose \
    --header "Select backups to delete:" \
    --no-limit
}

select_stop_options() {
  declare -n out_delay=$1
  declare -n out_stop_note=$2
  declare -n out_kick_reason=$3

  local default_delay="${4:-60}"
  local default_stop_note="$5"
  local default_kick_reason="$6"

  out_stop_note="${default_stop_note:-null}"
  out_kick_reason="$default_kick_reason"

  gum confirm "Add countdown?" \
    --default="No"
  confirmation="$?"
  if [ "$confirmation" -eq 130 ]; then
    echo "[ERROR] User aborted script, exiting..." >&2
    return 1
  elif [ "$confirmation" -eq 1 ]; then
    out_delay=0
    return 0
  fi

  while ! is_number "$out_delay"; do
    out_delay=$(gum input \
      --header "Enter countdown in seconds:" \
      --placeholder "seconds" \
      --value "$default_delay")
    if [ "$?" -eq 130 ]; then
      echo "[ERROR] User aborted script, exiting..." >&2
      return 1
    fi
  done

  out_stop_note=$(gum input \
    --header "Enter keyword that describes the shutdown intention:" \
    --placeholder "Note (optional)" \
    --value "$default_stop_note")
  if [ "$?" -eq 130 ]; then
    echo "[ERROR] User aborted script, exiting..." >&2
    return 1
  fi
  out_stop_note=${out_stop_note:-null}

  out_kick_reason=$(gum write \
    --header "Enter shutdown message for players:" \
    --placeholder "Reason for kicking players" \
    --value "$default_kick_reason")
  if [ "$?" -eq 130 ]; then
    echo "[ERROR] User aborted script, exiting..." >&2
    return 1
  fi

  return 0
}

server_alias=$(select_server)
if [ -z "$server_alias" ]; then
  echo "[ERROR] No server selected, exiting..." >&2
  exit 1
fi

operation=$(select_operation "$server_alias")
if [ "$?" -ne 0 ] || [ -z "$operation" ]; then
  echo "[ERROR] No operation selected, exiting..." >&2
  exit 1
fi

case "$operation" in
start)
  ./serman.sh start "$server_alias"
  ;;
stop)
  select_stop_options delay stop_note kick_reason || exit 1
  ./serman.sh stop "$server_alias" "$delay" "$stop_note" "$kick_reason"
  if [ "$delay" -eq 0 ]; then
    echo "[INFO] Stopping server '$server_alias'..." >&2
    exit 0
  else
    echo "[INFO] Scheduled shutdown for server '$server_alias' in $(print_time $delay)" >&2
    exit 0
  fi
  ;;
restart)
  select_stop_options delay stop_note kick_reason || exit 1
  gum spin --spinner="minidot" --title "Shutting down server '$server_alias'" \
    -- ./serman.sh stop --wait "$server_alias" "$delay" "$stop_note" "$kick_reason"
  if [ "$?" -ne 0 ]; then
    echo "[ERROR] Server '$server_alias' did not shut down correctly. Aborting restart..." >&2
    exit 1
  fi
  echo "[INFO] Server '$server_alias' shut down successfully. Restarting..." >&2
  ./serman.sh start "$server_alias"
  ;;
backup)
  status=$(get_server_status "$server_alias")
  start_after_backup=false
  [ "$status" == "Running" ] &&
    gum confirm "Server '$server_alias' is currently running. Do you want to stop it before creating the backup?" \
      --affirmative="Stop" \
      --negative="Ignore" \
      --default=1 && {
    start_after_backup=true
    select_stop_options delay stop_note kick_reason "10" "Backup" "Creating a server backup. The server will restart shortly." || exit 1
    gum spin --spinner="minidot" --title "Shutting down server '$server_alias' for backup" \
      -- ./serman.sh stop --wait "$server_alias" "$delay" "$stop_note" "$kick_reason"
  } || {
    confirmation="$?"
    if [ "$confirmation" -eq 130 ]; then
      echo "[ERROR] User aborted script, exiting..." >&2
      exit 1
    elif [ "$confirmation" -eq 1 ]; then
      echo "[INFO] Ignoring running server..." >&2
    fi
  }
  stop_status="$?"
  if [ "$stop_status" -ne 0 ]; then
    echo "[ERROR] Server '$server_alias' did not shut down correctly. Aborting backup..." >&2
    exit 1
  fi

  echo "[INFO] Creating backup for server '$server_alias'..." >&2
  gum spin --show-output --spinner="jump" --title "Backing up server '$server_alias'..." \
    -- ./serman.sh backup create "$server_alias"

  if ! $start_after_backup; then
    exit 0
  fi

  ./serman.sh start "$server_alias"
  ;;
uninstall)
  status=$(get_server_status "$server_alias")
  [ "$status" == "Running" ] &&
    gum confirm "Server '$server_alias' is currently running. You have to shut it down first." \
      --affirmative="Stop server" \
      --negative="Abort" \
      --default=0 && {
    select_stop_options delay stop_note kick_reason "10" "Delete" "This server is getting deleted. It will no longer exist." || exit 1
    gum spin --spinner="minidot" --title "Shutting down server '$server_alias'" \
      -- ./serman.sh stop --wait "$server_alias" "$delay" "$stop_note" "$kick_reason"
  } || {
    confirmation="$?"
    if [ "$status" == "Running" ]; then
      if [ "$confirmation" -ne 0 ]; then
        echo "[ERROR] User aborted server uninstall, exiting..." >&2
        exit 1
      fi
    fi
  }
  stop_status="$?"
  if [ "$stop_status" -ne 0 ]; then
    echo "[ERROR] Server '$server_alias' did not shut down correctly. Aborting uninstall..." >&2
    exit 1
  fi
  backup_separator=' | '
  backups_to_delete="$(select_backups "$server_alias" "$backup_separator" backups_to_delete)"
  if [ "$?" -ne 0 ]; then
    echo "[ERROR] An error occurred while selecting backups, exiting..." >&2
    exit 1
  fi
  if [ -n "$backups_to_delete" ]; then
    # define variable text in color red
    red_text="\e[31mThis is my text\e[0m"

    gum confirm "$(echo -e "The following backups will get deleted:\n\n$(colorize_output "${backups_to_delete}" "red")\n\nAre you sure?")" \
      --affirmative="Delete" \
      --negative="Abort" \
      --default=0 || {
      echo "[INFO] Aborting uninstall..." >&2
      exit 0
    }

    # Use awk to map selection to backup IDs
    backup_delete_ids="$(awk -v FS="$backup_separator" -v n=1 '{ print $n }' <<<"$backups_to_delete")"

    gum spin --show-output --spinner="minidot" --title "Deleting selected backups for server '$server_alias'" -- bash -c '
      while IFS="" read -r backup_id; do
        ./serman.sh backup delete "'"$server_alias"'" "$backup_id"
      done <<<"$1"
    ' _ "$backup_delete_ids"
  fi
  gum confirm "Are you sure you want to uninstall server '$server_alias'? $(colorize_output "This action is irreversible!" "red")" \
    --affirmative="Uninstall" \
    --negative="Cancel" \
    --default=0 || {
    echo "[INFO] Aborting uninstall..." >&2
    exit 0
  }
  gum spin --show-output --spinner="points" --title "Uninstalling server '$server_alias'" \
    -- ./serman.sh uninstall "$server_alias" && {
    echo "[INFO] Server '$server_alias' uninstalled successfully." >&2
    exit 0
  } || {
    echo "[ERROR] Uninstalling server '$server_alias' failed." >&2
    exit 1
  }
  ;;
*)
  echo "[ERROR] Unknown operation: $operation" >&2
  exit 1
  ;;
esac
