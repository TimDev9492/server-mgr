#!/bin/bash

# load environment
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
cd ${SCRIPT_DIR}
source ./setup_testing.sh
source ../common/utils.sh

export -f parse_args

test_parse_args_equal() {
  local input=("${!1}")
  local expected_flags=("${!2}")
  local expected_args=("${!3}")
  local description="$4"

  run_test 0 "$description" bash -c "
    parse_args flags args ${input[@]+"${input[@]}"}
    [[ \"\${flags[*]}\" == \"${expected_flags[*]}\" ]] && [[ \"\${args[*]}\" == \"${expected_args[*]}\" ]]
  "
}

# Test 1: Mixed flags and positional args
args=(-v --debug server1 server2)
expected_flags=(-v --debug)
expected_args=(server1 server2)
test_parse_args_equal args[@] expected_flags[@] expected_args[@] "Mixed flags and positional arguments"

# Test 2: Only flags
args=(-a --verbose -q)
expected_flags=(-a --verbose -q)
expected_args=()
test_parse_args_equal args[@] expected_flags[@] expected_args[@] "Only flags"

# Test 3: Only positional arguments
args=(server1 server2 server3)
expected_flags=()
expected_args=(server1 server2 server3)
test_parse_args_equal args[@] expected_flags[@] expected_args[@] "Only positional arguments"

# Test 4: Flags interleaved with positional args
args=(server1 -v server2 --debug server3)
expected_flags=(-v --debug)
expected_args=(server1 server2 server3)
test_parse_args_equal args[@] expected_flags[@] expected_args[@] "Interleaved flags and positional arguments"

# Test 5: Empty input
args=()
expected_flags=()
expected_args=()
test_parse_args_equal args[@] expected_flags[@] expected_args[@] "Empty input"

# Test 6: Flags with equals sign (treated as flags)
args=(--output=file.txt -v)
expected_flags=(--output=file.txt -v)
expected_args=()
test_parse_args_equal args[@] expected_flags[@] expected_args[@] "Flags containing equals sign"
