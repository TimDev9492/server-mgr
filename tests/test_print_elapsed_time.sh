#!/bin/bash

# load environment
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
cd "${SCRIPT_DIR}"
source ./setup_testing.sh
source ../common/utils.sh
tests_failed=0

# Helper function to run a test
run_test() {
  local expected="$1"
  local description="$2"
  shift 2

  if "$@"; then
    actual=0
  else
    actual=1
  fi

  if [[ "$actual" -eq "$expected" ]]; then
    echo "✅ PASS: $description"
  else
    echo "❌ FAIL: $description (expected $expected, got $actual)"
    tests_failed=$((tests_failed + 1))
  fi
}

filename=$(basename "$0")
function_name="${filename#test_}"
function_name="${function_name%.sh}"

if ! declare -f "$function_name" >/dev/null; then
  echo "❌ FAIL: Function '$function_name' does not exist."
fi

# Wrapper for output comparison using run_test
assert_output() {
  local expected="$1"
  local event_time="$2"
  local ref_time="$3"

  local output
  output="$("$function_name" "$event_time" "$ref_time" 2>/dev/null)"

  if [[ "$output" == "$expected" ]]; then
    return 0
  else
    echo "Expected '$expected', got '$output'"
    return 1
  fi
}

# === BASIC CHECKS ===

run_test 0 "Exactly 1 year" \
  assert_output "1y 0m 0d" "$(date -d "-1 year" +%s)" "$(date +%s)"

run_test 0 "Exactly 1 month" \
  assert_output "1m 0d" "$(date -d "-1 month" +%s)" "$(date +%s)"

run_test 0 "Exactly 1 day" \
  assert_output "1d 0h 0min" "$(date -d "-1 day" +%s)" "$(date +%s)"

run_test 0 "Exactly 1 hour" \
  assert_output "1h 0min" "$(date -d "-1 hour" +%s)" "$(date +%s)"

run_test 0 "Exactly 1 minute" \
  assert_output "1min" "$(date -d "-1 minute" +%s)" "$(date +%s)"

# === MIXED DURATIONS ===

run_test 0 "2y 3m 5d ago" \
  assert_output "2y 3m 5d" "$(date -d "-2 years -3 months -5 days" +%s)" "$(date +%s)"

run_test 0 "0y 0m 6d 2h 30min ago" \
  assert_output "6d 2h 30min" "$(date -d "-6 days -2 hours -30 minutes" +%s)" "$(date +%s)"

run_test 0 "Only hours and minutes" \
  assert_output "2h 15min" "$(date -d "-2 hours -15 minutes" +%s)" "$(date +%s)"

run_test 0 "Same timestamps" \
  assert_output "0min" "$(date +%s)" "$(date +%s)"

# === VARIABLE MONTH LENGTHS ===

run_test 0 "From Jan 31 to Feb 28 (non-leap year)" \
  assert_output "28d 0h 0min" "$(date -d "2023-01-31" +%s)" "$(date -d "2023-02-28" +%s)"

run_test 0 "From Jan 31 to Mar 3 (non-leap year)" \
  assert_output "1m 3d" "$(date -d "2023-01-31" +%s)" "$(date -d "2023-03-03" +%s)"

run_test 0 "From Feb 28 to Mar 31 (non-leap year)" \
  assert_output "1m 3d" "$(date -d "2023-02-28" +%s)" "$(date -d "2023-03-31" +%s)"

# === LEAP YEAR ===

run_test 0 "Feb 28 to Feb 29 (leap year)" \
  assert_output "1d 0h 0min" "$(date -d "2024-02-28" +%s)" "$(date -d "2024-02-29" +%s)"

run_test 0 "Feb 29 to Mar 1 (leap year)" \
  assert_output "1d 0h 0min" "$(date -d "2024-02-29" +%s)" "$(date -d "2024-03-01" +%s)"

run_test 0 "From Feb 28, 2023 to Feb 28, 2024 (1 common year)" \
  assert_output "1y 0m 0d" "$(date -d "2023-02-28" +%s)" "$(date -d "2024-02-28" +%s)"

# === CROSS YEAR ===

run_test 0 "From Dec 31 to Jan 1" \
  assert_output "1d 0h 0min" "$(date -d "2024-12-31" +%s)" "$(date -d "2025-01-01" +%s)"

run_test 0 "From Dec 15 to Feb 15 (2 months)" \
  assert_output "2m 0d" "$(date -d "2023-12-15" +%s)" "$(date -d "2024-02-15" +%s)"

# === CROSS MONTH ===

# CORRECTED: This should be '1m 0d' to be consistent.
run_test 0 "1 month across February (non-leap year)" \
  assert_output "1m 0d" "$(date -d "2023-02-01" +%s)" "$(date -d "2023-03-01" +%s)"

# CORRECTED: This should be '1m 0d' to be consistent.
run_test 0 "1 month across February (leap year)" \
  assert_output "1m 0d" "$(date -d "2024-02-01" +%s)" "$(date -d "2024-03-01" +%s)"

# CORRECTED: This should be '1m 0d' to be consistent.
run_test 0 "1 month across April-May boundary" \
  assert_output "1m 0d" "$(date -d "2023-04-01" +%s)" "$(date -d "2023-05-01" +%s)"

# CORRECTED: This was the main inconsistency. It should be '1m 0d'.
run_test 0 "1 month across July-August boundary" \
  assert_output "1m 0d" "$(date -d "2023-07-01" +%s)" "$(date -d "2023-08-01" +%s)"

run_test 0 "Exactly 1 month" \
  assert_output "1m 0d" "$(date -d "2023-03-01" +%s)" "$(date -d "2023-04-01" +%s)"

run_test 0 "1 month and 15 days" \
  assert_output "1m 15d" "$(date -d "2023-03-01" +%s)" "$(date -d "2023-04-16" +%s)"

run_test 0 "11 months and 29 days" \
  assert_output "11m 29d" "$(date -d "2022-04-01" +%s)" "$(date -d "2023-03-30" +%s)"

run_test 0 "Exactly 1 year" \
  assert_output "1y 0m 0d" "$(date -d "2022-06-28" +%s)" "$(date -d "2023-06-28" +%s)"

# Exit based on result
[ "$tests_failed" -eq 0 ] && exit 0 || exit 1
