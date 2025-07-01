#!/bin/bash

# load environment
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
cd ${SCRIPT_DIR}
source ./setup_testing.sh
source ../common/utils.sh
tests_failed=0

filename=$(basename "$0")
function_name="${filename#test_}"
function_name="${function_name%.sh}"

if ! declare -f "$function_name" >/dev/null; then
  echo "❌ FAIL: Function '$function_name' does not exist."
  exit 1
fi

# Helper to compare output with expected YAML and return 0/1 for run_test
compare_json_to_yaml() {
  local expected="$1"
  local input_json="$2"

  local actual_output
  actual_output=$(json_to_yaml "$input_json")

  # echo -e "[DEBUG] Expected YAML:\n'$expected'" >&2
  # echo -e "[DEBUG] Actual YAML:\n'$actual_output'" >&2

  [[ "$actual_output" == "$expected" ]]
}

# Now run tests using run_test:
run_test 0 "Simple flat object" compare_json_to_yaml 'key: "value"' '{"key":"value"}'

run_test 0 "Flat object with multiple keys" compare_json_to_yaml $'key1: "value1"\nkey2: "value2"' '{"key1":"value1","key2":"value2"}'

run_test 0 "Nested object" compare_json_to_yaml $'nested:\n  key: "value"' '{"nested":{"key":"value"}}'

run_test 0 "Array of strings" compare_json_to_yaml $'- "item1"\n- "item2"\n- "item3"' '["item1","item2","item3"]'

run_test 0 "Mixed nested structure" compare_json_to_yaml $'root:\n  array:\n    - "item1"\n    - "item2"\n  number: 123' '{"root":{"array":["item1","item2"],"number":123}}'

run_test 0 "Empty JSON object" compare_json_to_yaml "{}" '{}'

run_test 0 "Empty JSON array" compare_json_to_yaml "[]" '[]'

run_test 0 "Booleans and null" compare_json_to_yaml $'boolean_true: true\nboolean_false: false\nnull_value: null' '{"boolean_true":true,"boolean_false":false,"null_value":null}'

[ "$tests_failed" -eq 0 ] && exit 0 || exit 1
