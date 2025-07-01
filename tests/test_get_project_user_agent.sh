#!/bin/bash

# load environment
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
cd ${SCRIPT_DIR}
source ./setup_testing.sh
source ../common/utils.sh
tests_failed=0

# Mock environment variables
export VERSION="1.2.3"
export HOMEPAGE="https://example.com"

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

# Helper to test output
check_user_agent_output() {
  expected_output="server-mgr/$VERSION ($HOMEPAGE)"
  actual_output=$(get_project_user_agent)
  [[ "$actual_output" == "$expected_output" ]]
}

run_test 0 "Correct user agent output with valid VERSION and HOMEPAGE" check_user_agent_output

# Edge case: Empty VERSION or HOMEPAGE
export VERSION=""
export HOMEPAGE=""
check_empty_user_agent_output() {
  expected_output="server-mgr/ ()"
  actual_output=$(get_project_user_agent)
  [[ "$actual_output" == "$expected_output" ]]
}

run_test 0 "User agent output with empty VERSION and HOMEPAGE" check_empty_user_agent_output

[ "$tests_failed" -eq 0 ] && exit 0 || exit 1
