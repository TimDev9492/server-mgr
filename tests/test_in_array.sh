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

# Test cases

# Test 1: Array contains value
arr=("apple" "banana" "cherry")
run_test 0 "Value in array" in_array "banana" "${arr[@]}"

# Test 2: Array does not contain value
run_test 1 "Value not in array" in_array "grape" "${arr[@]}"

# Test 3: Multiline string contains value
str=$'apple\nbanana\ncherry pie'
run_test 0 "Value in multiline string" in_array "banana" "$str"

# Test 4: Multiline string does not contain value
run_test 1 "Value not in multiline string" in_array "grape" "$str"

# Test 5: Value with space in array
arr2=("cherry pie" "banana split")
run_test 0 "Value with space in array" in_array "cherry pie" "${arr2[@]}"

# Test 6: Value with space in multiline string
str2=$'cherry pie\nbanana split'
run_test 0 "Value with space in multiline string" in_array "banana split" "$str2"

# Test 7: number array
arr3=(1 2 3 4 5)
run_test 0 "Number in number array" in_array 2 "${arr3[@]}"

[ "$tests_failed" -eq 0 ] && exit 0 || exit 1
