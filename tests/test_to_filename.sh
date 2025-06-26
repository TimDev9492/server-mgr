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

test_to_filename_output() {
  local project="$1"
  local version="$2"
  local build="$3"
  local channel="$4"
  local expected="$5"
  local description="$6"

  run_test 0 "$description" bash -c "
    output=\$(to_filename \"$project\" \"$version\" \"$build\" \"$channel\")
    [[ \"\$output\" == \"$expected\" ]]
  "
}

# Basic test
test_to_filename_output "project" "1.20" "123" "release" "project-1.20-123-release.jar" "Basic filename format"

# Version with dots
test_to_filename_output "myProj" "0.9.1" "7" "beta" "myProj-0.9.1-7-beta.jar" "Version with dots"

# Numeric build number
test_to_filename_output "test" "2025" "9999" "stable" "test-2025-9999-stable.jar" "Numeric build number"

# Channel with dashes
test_to_filename_output "proj" "1.0" "1" "release-candidate" "proj-1.0-1-release-candidate.jar" "Channel with dash"

# Empty fields (should still produce format, but empty parts)
test_to_filename_output "" "" "" "" "---.jar" "All empty fields"

# Spaces in project (spaces will appear as-is, might be invalid filename)
test_to_filename_output "my project" "1.0" "1" "stable" "my project-1.0-1-stable.jar" "Project name with space"

# Special characters in project/channel
test_to_filename_output "proj!" "1.0" "1" "beta#" "proj!-1.0-1-beta#.jar" "Special chars in project and channel"

[ "$tests_failed" -eq 0 ] && exit 0 || exit 1
