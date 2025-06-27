# tests/test_print_time.sh

#!/bin/bash

# load environment
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
cd ${SCRIPT_DIR}
source ./setup_testing.sh
source ../common/utils.sh
tests_failed=0

# Check if function exists
function_name="print_time"
if ! declare -f "$function_name" >/dev/null; then
    echo "❌ FAIL: Function '$function_name' does not exist."
    exit 1
fi

# Helper to wrap output-based functions
run_test_output() {
    local expected="$1"
    local description="$2"
    shift 2
    local actual_output
    actual_output="$("$@")"

    if [[ "$actual_output" == "$expected" ]]; then
        echo "✅ PASS: $description"
    else
        echo "❌ FAIL: $description (expected '$expected', got '$actual_output')"
        tests_failed=$((tests_failed + 1))
    fi
}

# Test cases for print_time
run_test_output "0s" "Zero seconds" print_time 0
run_test_output "5s" "Under a minute" print_time 5
run_test_output "59s" "Just below a minute" print_time 59
run_test_output "1min 0s" "Exactly one minute" print_time 60
run_test_output "1min 1s" "One minute one second" print_time 61
run_test_output "2min 30s" "Two and a half minutes" print_time 150
run_test_output "10min 0s" "Ten minutes" print_time 600
run_test_output "123min 45s" "Large input" print_time 7425

[ "$tests_failed" -eq 0 ] && exit 0 || exit 1
