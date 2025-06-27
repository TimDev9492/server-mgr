#!/bin/bash

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
cd ${SCRIPT_DIR}
source ../common/utils.sh

# Load variables
if [ ! -f "../variables.sh" ]; then
  echo "[ERROR] variables.sh not found in the script directory."
  exit 1
fi
source ../variables.sh

# Check for required commands
check_prerequisites readlink rsync

print_usage() {
  echo "Usage: backup_server.sh <server_alias>"
}

# parse arguments
if [ -n "$1" ]; then
  server_alias="$1"
else
  print_usage
  exit 1
fi

backup_server() {
  # check preconditions
  local server_alias="$1"
  if [ -z "$server_alias" ]; then
    echo "[ERROR] Server alias is required." >&2
    exit 1
  fi
  local server_dir="${MINECRAFT_SERVER_DIR}/${server_alias}/"
  if [ ! -d "$server_dir" ]; then
    echo "[ERROR] Server directory '$server_dir' does not exist." >&2
    exit 1
  fi

  # create server backup directory
  local server_backup_dir="${MINECRAFT_SERVER_BACKUP_DIR}/${server_alias}"
  mkdir -p "$server_backup_dir"

  local timestamp="$(date +%Y-%m-%d-%H%M%S)"
  local latest_backup_dir="${server_backup_dir}/latest"
  local backup_dir="${server_backup_dir}/${timestamp}"

  local rsync_opts=("-a" "--delete" "--include-from=${SCRIPT_DIR}/../assets/default-include.txt")
  if [ -d "$latest_backup_dir" ]; then
    rsync_opts+=("--link-dest=$latest_backup_dir")
  fi

  # backup all important server files except server.jar
  rsync ${rsync_opts[@]} "$server_dir/" "$backup_dir/"

  if [ $? -ne 0 ]; then
    echo "[ERROR] Backing up server files failed." >&2
    return 1
  fi

  # create server.jar symlink
  current_jar="${server_dir}/server.jar"
  if [ ! -f "$current_jar" ]; then
    echo "[ERROR] server.jar not found in '$server_dir'." >&2
    rm -rf "$backup_dir"
    return 1
  fi
  if [ -L "$current_jar" ]; then
    # server.jar is symlink
    # flatten the symlink
    flattened_server_jar="$(readlink -f "$current_jar")"
    # add a symlink to the backup directory
    ln -sf "$flattened_server_jar" "${backup_dir}/server.jar"
  else
    # server.jar is not a symlink, backup using rsync
    rsync -a --delete "$current_jar" "${backup_dir}/server.jar"
  fi

  if [ $? -ne 0 ]; then
    echo "[ERROR] Backup of server.jar failed." >&2
    rm -rf "$backup_dir"
    return 1
  fi

  # create latest symlink
  ln -sfn "$backup_dir" "$latest_backup_dir"

  echo "[INFO] Successfully created backup at '$backup_dir'."

  return 0
}

# create backup directory if it does not exist
mkdir -p "$MINECRAFT_SERVER_BACKUP_DIR"

backup_server "$server_alias"
if [ $? -eq 0 ]; then
  exit 0
else
  echo "[ERROR] Backup failed."
  exit 1
fi
