#!/bin/bash

# load environment
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
cd ${SCRIPT_DIR}
source ./setup_testing.sh
source ../common/utils.sh
tests_failed=0

# Get the base filename logic (standard boilerplate)
filename=$(basename "$0")
function_name="${filename#test_}"
function_name="${function_name%.sh}"

# Check if function exists
if ! declare -f "$function_name" >/dev/null; then
    echo "❌ FAIL: Function '$function_name' does not exist."
    # exit 1
fi

# --- Test Setup ---

# Create a temporary file for testing
TEST_FILE="${SCRIPT_DIR}/tmp_mc_test.txt"

# Ensure cleanup happens even if script exits early
trap "rm -f '$TEST_FILE'" EXIT

# --- Custom Helper for Content Verification ---

# Usage: check_mc_content "file_content_string" "expected_output_string"
check_mc_content() {
    local content="$1"
    local expected="$2"
    
    # Write content to temp file
    echo -e "$content" > "$TEST_FILE"
    
    # Run the function and capture output
    # We ignore the exit code of get_mc_commands here because grep returns 1 
    # if output is empty (e.g., file contained only comments), 
    # but we are testing for the *empty string*, which is a valid result.
    local actual
    actual=$($function_name "$TEST_FILE")
    
    if [[ "$actual" == "$expected" ]]; then
        return 0
    else
        # Print detailed diff for debugging if running manually
        # echo "    --- EXPECTED ---"
        # echo "$expected"
        # echo "    --- ACTUAL ---"
        # echo "$actual"
        return 1
    fi
}

# --- Test Cases ---

# 1. Test Exit Code Logic (File Existence)
run_test 1 "File does not exist" get_mc_commands "non_existent_file_XYZ.txt"


# 2. Test Content Logic

# Case: Standard config with mixed comments, indentation, and blanks
# Input description:
# - Line 1: Comment
# - Line 2: Valid command
# - Line 3: Indented comment
# - Line 4: Blank line
# - Line 5: Indented command
input_mixed="# A comment
command1 argument

  # Indented comment
  command2"

expected_mixed="command1 argument
  command2"

run_test 0 "Filter comments and empty lines" check_mc_content "$input_mixed" "$expected_mixed"


# Case: Only comments
input_comments="# comment 1
  # comment 2"
expected_comments=""

run_test 0 "File with only comments returns empty output" check_mc_content "$input_comments" "$expected_comments"


# Case: Only whitespace
input_space="   
  "
expected_space=""

run_test 0 "File with only whitespace returns empty output" check_mc_content "$input_space" "$expected_space"


# Case: No filtering needed (Clean file)
input_clean="cmd1
cmd2"
expected_clean="cmd1
cmd2"

run_test 0 "Clean file remains unchanged" check_mc_content "$input_clean" "$expected_clean"

# --- Final Check ---
[ "$tests_failed" -eq 0 ] && exit 0 || exit 1