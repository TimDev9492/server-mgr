#!/bin/bash

# This script reads a server config json from STDIN and installs the server.
# It does not perform any validity checks on the config values, only on the
# structure of the input JSON.

#!/bin/bash

# Load configuration variables

# load environment
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
cd "${SCRIPT_DIR}/../"
source ./common/utils.sh

VERBOSE=false
if in_array "-v" "$@"; then
  VERBOSE=true
fi

log() {
  $VERBOSE && echo "$@" >&2
}

# Load variables
if [ ! -f "./load_config.sh" ]; then
  echo "[ERROR] load_config.sh not found in the script directory." >&2
  exit 1
fi
source ./load_config.sh

# Read json string from stdin
json_config=$(cat)

# Test if json_config is a valid JSON object
if ! echo "$json_config" | jq 'empty' 2>/dev/null; then
  log "[ERROR] Invalid JSON input!"
  exit 1
fi

# Required fields
server_alias="$(echo "$json_config" | jq -r '.server_alias')"
minecraft_version="$(echo "$json_config" | jq -r '.minecraft_version')"
java_version="$(echo "$json_config" | jq -r '.java_version')"
eula_agree_time="$(echo "$json_config" | jq -r '.eula_agree_timestamp')"
if [ "$server_alias" == "null" ]; then
  log "[ERROR] Missing property 'server_alias'"
  exit 1
fi
if [ "$minecraft_version" == "null" ]; then
  log "[ERROR] Missing property 'minecraft_version'"
  exit 1
fi
if [ "$java_version" == "null" ]; then
  log "[ERROR] Missing property 'java_version'"
  exit 1
fi
if [ "$eula_agree_time" == "null" ]; then
  log "[ERROR] Missing property 'eula_agree_timestamp'"
  exit 1
fi

# Create server directory
server_dir="${MINECRAFT_SERVER_DIR}/${server_alias}"
mkdir -p "${server_dir}/bin"
if [ ! -d "$server_dir" ]; then
  log "[ERROR] Failed to create server directory: $server_dir"
  exit 1
fi

# Copy json config to server directory
svrmgr_dir="${server_dir}/srvmgr"
mkdir -p "$svrmgr_dir"
if [ ! -d "${server_dir}/srvmgr" ]; then
  log "[ERROR] Failed to create srvmgr directory in server directory: $svrmgr_dir"
  exit 1
fi
echo "$json_config" >"${svrmgr_dir}/init.json"

# Agree to the EULA
eula_file_path="${server_dir}/eula.txt"
cp "${SCRIPT_DIR}/assets/templates/eula.txt.template" "$eula_file_path"
if [ $? -ne 0 ]; then
  log "[ERROR] Failed to copy eula.txt template!"
  exit 1
fi
# Replace the placeholder <eula_agree_time> with the actual timestamp
sed -i "s|<eula_agree_time>|${eula_agree_time}|g" "$eula_file_path"
if [ $? -ne 0 ]; then
  log "[ERROR] Failed to update eula.txt template!"
  exit 1
fi

# Link the jar file
./papman.sh link "${server_dir}/server.jar" "paper" "$minecraft_version" "latest"
if [ $? -ne 0 ]; then
  log "[ERROR] Failed to link jar file for minecraft version '$minecraft_version'!"
  exit 1
fi

# Create bin/startServer.sh script
start_script_path="${server_dir}/bin/startServer.sh"
cp "${SCRIPT_DIR}/assets/templates/startServer.sh.template" "$start_script_path"
if [ $? -ne 0 ]; then
  log "[ERROR] Failed to copy startServer.sh template!"
  exit 1
fi
# Build the java command string
java_command="$(echo "$json_config" | jq -r '"\(.java_version) \(.java_flags | join(" "))"')"
# Replace the following placeholders in the startServer.sh script using sed:
# - <server_alias> with the server alias
# - <server_directory> with the server directory
# - <java_command> with the java command (e.g. "java21 -Xmx4g")
sed -i "s|<server_alias>|${server_alias}|g;s|<server_directory>|${server_dir}|g;s|<java_command>|${java_command}|g" "$start_script_path"
if [ $? -ne 0 ]; then
  log "[ERROR] Failed to update startServer.sh template!"
  exit 1
fi
# Make the startServer.sh script executable
chmod +x "$start_script_path"

# if ! echo "$json_object" | jq -e 'type == "object"' >/dev/null 2>&1; then

# Create server.properties file
if echo "$json_config" | jq -e 'has("server.properties")' >/dev/null 2>&1; then
  # Write values to server.properties file
  echo "$json_config" | jq -r '.["server.properties"] | to_entries[] | "\(.key)=\(.value)"' >"${server_dir}/server.properties"
  if [ $? -ne 0 ]; then
    log "[ERROR] Failed to create server.properties file!"
    exit 1
  fi
else
  log "[WARNING] No 'server.properties' field found in the JSON config, skipping..."
fi

# Create spigot.yml file
if echo "$json_config" | jq -e 'has("spigot.yml")' >/dev/null 2>&1; then
  # Write values to spigot.yml file
  spigot_yml_config="$(echo "$json_config" | jq -rc '.["spigot.yml"]')"
  json_to_yaml "$spigot_yml_config" >"${server_dir}/spigot.yml"
  if [ $? -ne 0 ]; then
    log "[ERROR] Failed to create spigot.yml file!"
    exit 1
  fi
else
  log "[WARNING] No 'spigot.yml' field found in the JSON config, skipping..."
fi

log "[INFO] Successfully installed server '$server_alias' at $server_dir"
