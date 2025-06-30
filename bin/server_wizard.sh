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
check_prerequisites gum

abort_server_creation() {
  echo "[ERROR] Server creation aborted by user." >&2
  exit 1
}

select_version() {
  local version_selection="$(./papman.sh list-versions paper)"
  [ -n "$version_selection" ] && version_selection+=$'\n'
  version_selection+="other (select version to install)"
  echo "$version_selection" | gum choose \
    --header="Select Minecraft version" \
    --limit=1
}

get_minimum_java_version() {
  local minecraft_version="$1"
  local version_info="$(fetch_api "${PAPER_API_ENDPOINT}/projects/paper/versions/${minecraft_version}")"
  [ $? -ne 0 ] && exit 1
  echo "$version_info" | jq -r '.version.java.version.minimum'
}

server_alias="$(
  gum input \
    --header="Give your server a name" \
    --placeholder="Type a server alias..." \
    --value=""
)"
[ $? -eq 130 ] && abort_server_creation
if [ -z "$server_alias" ]; then
  echo "[ERROR] Received invalid server alias, exiting..." >&2
  exit 1
fi

while true; do
  minecraft_version="$(select_version)"
  [ $? -eq 130 ] && abort_server_creation
  if [[ "$minecraft_version" == other* ]]; then
    ./bin/update_helper.sh
  else
    break
  fi
done

minimum_java_version="$(get_minimum_java_version "$minecraft_version")"
if [ $? -ne 1 ] && [ -n "$minimum_java_version" ]; then
  minimum_java_version="$(colorize_output "$minimum_java_version" "green")"
else
  echo "[ERROR] Failed to get minimum Java version for Minecraft $minecraft_version." >&2
  minimum_java_version="$(colorize_output "unknown" "red")"
fi

java_version="$(
  ./javman.sh list | gum choose \
    --header="Select Java version $(colorize_output "(minimum: " "yellow")$minimum_java_version$(colorize_output ")" "yellow")" \
    --limit=1
)"
[ $? -eq 130 ] && abort_server_creation

echo "[DEBUG] Creating server with alias: $server_alias, Minecraft version: $minecraft_version, Java version: $java_version"
