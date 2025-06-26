#!/bin/bash

# load environment
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
cd ${SCRIPT_DIR}
source ../common/utils.sh

if (($# < 2)); then
    echo "Usage: $0 <server_alias> <seconds> <note|null> <kick_reason>"
    exit 1
fi

server_alias="$1"
total_seconds="$2"
note="$3"
shift 3
message="$*"

print_timestamps=(300 180 120 60 30 10 5 4 3 2 1)

print_time() {
    local secs="$1"
    if ((secs >= 60)); then
        local mins=$((secs / 60))
        local rem=$((secs % 60))
        echo "${mins}min ${rem}s"
    else
        echo "${secs}s"
    fi
}

while ((total_seconds > 0)); do
    if in_array "$total_seconds" "${print_timestamps[@]}"; then
        echo "[INFO] Stopping server $server_alias in $(print_time $total_seconds)"
        prefix=""
        [ "$note" != "null" ] && prefix="[$note] "
        send_server_command "$server_alias" "say ${prefix}Stopping server in $(print_time $total_seconds)"
        if [ ! "$?" -eq 0 ]; then
            echo "[ERROR] Failed to send command to server $server_alias" >&2
            exit 1
        fi
    fi
    sleep 1
    ((total_seconds--))
done

send_server_command "$server_alias" "kick @a $message"
send_server_command "$server_alias" "stop"
if [ ! "$?" -eq 0 ]; then
    echo "[ERROR] Failed to stop server $server_alias" >&2
    exit 1
fi

# wait for server to stop
while [ "$(get_server_status "$server_alias")" == "Running" ]; do
    sleep 1
done
