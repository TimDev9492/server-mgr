#!/bin/bash

# load environment
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
cd ${SCRIPT_DIR}
source ./setup_testing.sh
source ../common/utils.sh
tests_failed=0

# Get the base filename, e.g. "test_function_name.sh"
filename=$(basename "$0")
# Remove the "test_" prefix and ".sh" suffix to get the function name
function_name="${filename#test_}"
function_name="${function_name%.sh}"
# check if function exists
if ! declare -f "$function_name" >/dev/null; then
  echo "❌ FAIL: Function '$function_name' does not exist."
  exit 1
fi
export -f "$function_name"

test_to_screen_session_name() {
  local server_alias="$1"
  local expected="$2"
  local description="$3"

  run_test 0 "$description" bash -c "
    output=\$(to_screen_session_name \"$server_alias\")
    [[ \"\$output\" == \"$expected\" ]]
  "
}

# Basic server alias
test_to_screen_session_name "server1" "minecraft-server-server1" "Basic server alias"

# Numeric alias
test_to_screen_session_name "123" "minecraft-server-123" "Numeric server alias"

# Alias with dashes
test_to_screen_session_name "test-server" "minecraft-server-test-server" "Server alias with dashes"

# Alias with underscores
test_to_screen_session_name "my_server" "minecraft-server-my_server" "Server alias with underscores"

# Empty alias (should produce prefix only)
test_to_screen_session_name "" "minecraft-server-" "Empty server alias"

# Alias with spaces (spaces included as is)
test_to_screen_session_name "my server" "minecraft-server-my server" "Server alias with spaces"

# Alias with special chars
test_to_screen_session_name "srv!@#" "minecraft-server-srv!@#" "Server alias with special characters"

[ "$tests_failed" -eq 0 ] && exit 0 || exit 1
