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
for flag in "${flags[*]}"; do
  case "$flag" in
  -v)
    VERBOSE=true
    ;;
  -*)
    echo "[ERROR] Unknown option: $flag" >&2
    exit 1
    ;;
  esac
done

# parse arguments
operations=("list" "backup")

print_usage() {
  if [ -z "${args[0]}" ]; then
    local IFS='|'
    local ops="${operations[*]}"
    echo "Usage: serman.sh <$ops>" >&2
  else
    case "${args[0]}" in
    list) ;;
    backup)
      echo "Usage: papman.sh backup <server_alias>" >&2
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

operation="${args[0]}"

case "$operation" in
list)
  for server_dir in "${MINECRAFT_SERVER_DIR}"/*; do
    # skip if not a directory
    [ -d "$server_dir" ] || continue
    server_alias=$(basename "$server_dir")
    # check if the server directory is a valid server installation
    check_server_installation "$server_dir" && echo "$server_alias" || continue
  done
  ;;
backup)
  # backup the server
  echo "[INFO] Not implemented yet." >&2
  ;;
*)
  echo "[ERROR] Unknown operation: $operation" >&2
  print_usage
  exit 1
  ;;
esac
