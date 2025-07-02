#!/bin/bash

# load environment
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
cd "${SCRIPT_DIR}"
source ./setup_testing.sh
source ../common/utils.sh
tests_failed=0

filename=$(basename "$0")
function_name="${filename#test_}"
function_name="${function_name%.sh}"
if ! declare -f "$function_name" >/dev/null; then
  echo "❌ FAIL: Function '$function_name' does not exist."
fi

# Helper: check if arrays match expected content
check_keys_and_values() {
  local json_input="$1"
  shift
  local -a expected_keys=("${!1}")
  shift
  local -a expected_values=("${!1}")

  local keys=()
  local values=()

  json_object_to_key_value_pairs keys values "$json_input" || return 1

  if [[ "${#keys[@]}" -ne "${#expected_keys[@]}" || "${#values[@]}" -ne "${#expected_values[@]}" ]]; then
    return 1
  fi

  for i in "${!expected_keys[@]}"; do
    [[ "${keys[$i]}" != "${expected_keys[$i]}" ]] && return 1
    [[ "${values[$i]}" != "${expected_values[$i]}" ]] && return 1
  done
  return 0
}

# === Test Cases ===

json='{"a":1,"b":"two","c":true}'
expected_keys=("a" "b" "c")
expected_vals=("1" "two" "true")
run_test 0 "Flat JSON with mixed types" check_keys_and_values "$json" expected_keys[@] expected_vals[@]

json='{}'
expected_keys=()
expected_vals=()
run_test 0 "Empty JSON object" check_keys_and_values "$json" expected_keys[@] expected_vals[@]

json='{"x":10,"y":20}'
expected_keys=("x" "y")
expected_vals=("10" "20")
run_test 0 "Numeric values" check_keys_and_values "$json" expected_keys[@] expected_vals[@]

json='{"flag1":true,"flag2":false}'
expected_keys=("flag1" "flag2")
expected_vals=("true" "false")
run_test 0 "Boolean values" check_keys_and_values "$json" expected_keys[@] expected_vals[@]

json='{"key":null}'
expected_keys=("key")
expected_vals=("null")
run_test 0 "Null value" check_keys_and_values "$json" expected_keys[@] expected_vals[@]

# === Invalid input cases (expect failure) ===

json='["a", "b", "c"]'
run_test 1 "Array instead of object" json_object_to_key_value_pairs keys values "$json"

json='{"a":1,"b":{"nested":2}}'
run_test 1 "Object with nested object" json_object_to_key_value_pairs keys values "$json"

json='{"a":1,"b":[1,2,3]}'
run_test 1 "Object with array value" json_object_to_key_value_pairs keys values "$json"

json='{"a":1, "b":}'
run_test 1 "Malformed JSON" json_object_to_key_value_pairs keys values "$json"

json='not a json string'
run_test 1 "Non-JSON input" json_object_to_key_value_pairs keys values "$json"

# === Done ===

[ "$tests_failed" -eq 0 ] && exit 0 || exit 1
