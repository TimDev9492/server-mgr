#!/bin/bash

# Load configuration variables

# load environment
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
cd ${SCRIPT_DIR}
source ./common/utils.sh

VERBOSE=false
if in_array "-v" "$@"; then
    VERBOSE=true
fi

# Array of config locations in priority order
CONFIG_PATHS=(
    "$HOME/.config/server-mgr/config.sh"
    "/etc/server-mgr/configh.sh"
    "/usr/local/share/server-mgr/config.sh"
)

# Fallback file
DEFAULT_CONFIG_PATH="${SCRIPT_DIR}/default_config.sh"

# Flag to track if we successfully sourced a file
sourced=false

log() {
    $VERBOSE && echo "$@" >&2
}

# Loop through locations and source the first one that exists
for config in "${CONFIG_PATHS[@]}"; do
    if [[ -f "$config" ]]; then
        log "[INFO] Using config: $config"
        source "$config"
        sourced=true
        break
    fi
done

# Source the fallback if none of the above exist
if ! $sourced; then
    if [ -f "$DEFAULT_CONFIG_PATH" ]; then
        config_destination_path="${CONFIG_PATHS[0]}"
        log "[INFO] Copying default config to $config_destination_path"
        mkdir -p "$(dirname "$config_destination_path")"
        cp "$DEFAULT_CONFIG_PATH" "$config_destination_path"
        chmod +x "$config_destination_path"
        log "[INFO] Using default config."
        source "$config_destination_path"
    else
        log "[ERROR] No default config found!"
        exit 1
    fi
fi
