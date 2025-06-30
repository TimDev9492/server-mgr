#!/bin/bash

# load environment
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
cd ${SCRIPT_DIR}
source ./setup_testing.sh
source ../common/utils.sh
tests_failed=0

# IMPORTANT: Set timezone to UTC for consistent, reproducible results
export TZ=UTC

# --- Function existence check ---
filename=$(basename "$0")
function_name="${filename#test_}"
function_name="${function_name%.sh}"

if ! declare -f "$function_name" >/dev/null; then
  echo "❌ FAIL: Function '$function_name' does not exist in utils.sh."
  exit 1
fi
# --- End of check ---

# Test cases for unix_to_date
# Note: We use `[ "$(unix_to_date ...)" = "..." ]` to compare the function's output.
# This command will have an exit code of 0 on match (success) and 1 on mismatch (failure),
# which works perfectly with the run_test helper.

run_test 0 "The Unix epoch (timestamp 0)" \
  [ "$(unix_to_date 0)" = "1970-01-01 00:00:00" ]

run_test 0 "A specific date in the past" \
  [ "$(unix_to_date 946684800)" = "2000-01-01 00:00:00" ]

run_test 0 "A more recent date and time" \
  [ "$(unix_to_date 1672531200)" = "2023-01-01 00:00:00" ]

run_test 0 "A date with specific time" \
  [ "$(unix_to_date 1698393000)" = "2023-10-27 07:50:00" ]

run_test 0 "A leap year date" \
  [ "$(unix_to_date 1709208000)" = "2024-02-29 12:00:00" ]

# --- Test failure cases ---
# Here, we expect the function itself to fail (return a non-zero exit code)
# because `date` will fail with invalid input.

run_test 1 "Invalid non-numeric input" unix_to_date "not-a-timestamp"
run_test 1 "Empty string input" unix_to_date ""
run_test 1 "Negative timestamp (can be valid but might not be supported by older $(date) versions)" \
  [ "$(unix_to_date -1)" = "1969-12-31 23:59:59" ]

[ "$tests_failed" -eq 0 ] && exit 0 || exit 1
