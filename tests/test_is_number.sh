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

# Test cases for is_number

run_test 0 "Positive integer" is_number 123
run_test 0 "Zero" is_number 0
run_test 1 "Empty string" is_number ""
run_test 1 "Alphabetic string" is_number abc
run_test 1 "Alphanumeric string" is_number 123abc
run_test 0 "Number with leading zeros" is_number 007
run_test 1 "Negative number (should fail if only digits allowed)" is_number -123
run_test 1 "Floating point number" is_number 3.14
run_test 1 "Negative float" is_number -0.5
run_test 1 "Space in number" is_number "12 3"
run_test 1 "Number with comma" is_number "1,000"
run_test 1 "Special characters" is_number "#$%123"

[ "$tests_failed" -eq 0 ] && exit 0 || exit 1
