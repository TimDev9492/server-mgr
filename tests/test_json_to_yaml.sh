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

  [[ "$actual_output" == "$expected" ]]
}

run_test 0 "Simple flat object" compare_json_to_yaml 'key: "value"' '{"key":"value"}'

run_test 0 "Flat object with multiple keys" compare_json_to_yaml $'key1: "value1"\nkey2: "value2"' '{"key1":"value1","key2":"value2"}'

run_test 0 "Nested object" compare_json_to_yaml $'nested:\n  key: "value"' '{"nested":{"key":"value"}}'

run_test 0 "Array of strings" compare_json_to_yaml $'- "item1"\n- "item2"\n- "item3"' '["item1","item2","item3"]'

run_test 0 "Mixed nested structure" compare_json_to_yaml $'root:\n  array:\n    - "item1"\n    - "item2"\n  number: 123' '{"root":{"array":["item1","item2"],"number":123}}'

run_test 0 "Empty JSON object" compare_json_to_yaml "{}" '{}'

run_test 0 "Empty JSON array" compare_json_to_yaml "[]" '[]'

run_test 0 "Booleans and null" compare_json_to_yaml $'boolean_true: true\nboolean_false: false\nnull_value: null' '{"boolean_true":true,"boolean_false":false,"null_value":null}'

run_test 0 "Complex API response" compare_json_to_yaml $'version:\n  id: "1.21.1"\n  support:\n    status: "UNSUPPORTED"\n  java:\n    version:\n      minimum: 21\n    flags:\n      recommended:\n        - "-XX:+AlwaysPreTouch"\n        - "-XX:+DisableExplicitGC"\n        - "-XX:+ParallelRefProcEnabled"\n        - "-XX:+PerfDisableSharedMem"\n        - "-XX:+UnlockExperimentalVMOptions"\n        - "-XX:+UseG1GC"\n        - "-XX:G1HeapRegionSize=8M"\n        - "-XX:G1HeapWastePercent=5"\n        - "-XX:G1MaxNewSizePercent=40"\n        - "-XX:G1MixedGCCountTarget=4"\n        - "-XX:G1MixedGCLiveThresholdPercent=90"\n        - "-XX:G1NewSizePercent=30"\n        - "-XX:G1RSetUpdatingPauseTimePercent=5"\n        - "-XX:G1ReservePercent=20"\n        - "-XX:InitiatingHeapOccupancyPercent=15"\n        - "-XX:MaxGCPauseMillis=200"\n        - "-XX:MaxTenuringThreshold=1"\n        - "-XX:SurvivorRatio=32"\nbuilds:\n  - 133\n  - 132\n  - 131\n  - 130\n  - 128\n  - 127\n  - 126\n  - 125\n  - 123\n  - 122\n  - 121\n  - 120\n  - 119\n  - 118\n  - 117\n  - 116\n  - 115\n  - 114\n  - 113\n  - 112\n  - 111\n  - 110\n  - 109\n  - 108\n  - 107\n  - 106\n  - 105\n  - 104\n  - 103\n  - 102\n  - 101\n  - 100\n  - 99\n  - 98\n  - 97\n  - 96\n  - 95\n  - 94\n  - 93\n  - 92\n  - 91\n  - 90\n  - 89\n  - 88\n  - 87\n  - 86\n  - 85\n  - 84\n  - 83\n  - 82\n  - 81\n  - 80\n  - 79\n  - 78\n  - 77\n  - 76\n  - 75\n  - 74\n  - 73\n  - 72\n  - 71\n  - 70\n  - 69\n  - 68\n  - 67\n  - 66\n  - 65\n  - 64\n  - 63\n  - 62\n  - 61\n  - 60\n  - 59\n  - 58\n  - 57\n  - 56\n  - 55\n  - 54\n  - 53\n  - 52\n  - 51\n  - 50\n  - 49\n  - 48\n  - 47\n  - 46\n  - 45\n  - 44\n  - 43\n  - 42\n  - 41\n  - 40\n  - 39\n  - 38\n  - 37\n  - 36\n  - 35\n  - 34\n  - 33\n  - 32\n  - 31\n  - 30\n  - 29\n  - 28\n  - 27\n  - 26\n  - 25\n  - 24\n  - 23\n  - 22\n  - 19\n  - 18\n  - 17\n  - 16\n  - 15\n  - 14\n  - 13\n  - 12\n  - 11\n  - 10\n  - 9\n  - 8\n  - 7\n  - 6\n  - 5\n  - 4\n  - 3\n  - 2' '{"version":{"id":"1.21.1","support":{"status":"UNSUPPORTED"},"java":{"version":{"minimum":21},"flags":{"recommended":["-XX:+AlwaysPreTouch","-XX:+DisableExplicitGC","-XX:+ParallelRefProcEnabled","-XX:+PerfDisableSharedMem","-XX:+UnlockExperimentalVMOptions","-XX:+UseG1GC","-XX:G1HeapRegionSize=8M","-XX:G1HeapWastePercent=5","-XX:G1MaxNewSizePercent=40","-XX:G1MixedGCCountTarget=4","-XX:G1MixedGCLiveThresholdPercent=90","-XX:G1NewSizePercent=30","-XX:G1RSetUpdatingPauseTimePercent=5","-XX:G1ReservePercent=20","-XX:InitiatingHeapOccupancyPercent=15","-XX:MaxGCPauseMillis=200","-XX:MaxTenuringThreshold=1","-XX:SurvivorRatio=32"]}}},"builds":[133,132,131,130,128,127,126,125,123,122,121,120,119,118,117,116,115,114,113,112,111,110,109,108,107,106,105,104,103,102,101,100,99,98,97,96,95,94,93,92,91,90,89,88,87,86,85,84,83,82,81,80,79,78,77,76,75,74,73,72,71,70,69,68,67,66,65,64,63,62,61,60,59,58,57,56,55,54,53,52,51,50,49,48,47,46,45,44,43,42,41,40,39,38,37,36,35,34,33,32,31,30,29,28,27,26,25,24,23,22,19,18,17,16,15,14,13,12,11,10,9,8,7,6,5,4,3,2]}'

[ "$tests_failed" -eq 0 ] && exit 0 || exit 1
