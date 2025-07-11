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

test_valid_filename() {
  local filename="$1"
  local expected_output="$2"
  local description="$3"

  run_test 0 "$description" bash -c "
    output=\$(get_info_from_filename \"$filename\")
    [[ \"\$output\" == \"$expected_output\" ]]
  "
}

test_invalid_filename() {
  local filename="$1"
  local description="$2"

  run_test 1 "$description" bash -c "
    get_info_from_filename \"$filename\" >/dev/null 2>&1
  "
}

# Valid filenames
test_valid_filename "project-1.20-123-release.jar" "project 1.20 123 release" "Valid filename: project-1.20-123-release.jar"
test_valid_filename "myProj-0.9.1-7-beta.jar" "myProj 0.9.1 7 beta" "Valid filename: myProj-0.9.1-7-beta.jar"
test_valid_filename "test-2025-9999-stable.jar" "test 2025 9999 stable" "Valid filename: test-2025-9999-stable.jar"

# Invalid filenames
test_invalid_filename "project-1.20-123-release.zip" "Invalid extension .zip"
test_invalid_filename "project-1.20-release.jar" "Missing build number"
test_invalid_filename "project_1.20-123-release.jar" "Underscore instead of dash in project"
test_invalid_filename "project-1.20-123-release-extra.jar" "Extra part before .jar"
test_invalid_filename "project-1.20-123.jar" "Missing channel part"

# Edge case: filename with dash in parts (should fail as per current regex)
test_invalid_filename "my-proj-1.20-123-release.jar" "Dash inside project name (invalid)"

[ "$tests_failed" -eq 0 ] && exit 0 || exit 1
