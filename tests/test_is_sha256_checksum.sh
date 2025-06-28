#!/bin/bash

# Load environment
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
cd ${SCRIPT_DIR}
source ./setup_testing.sh
source ../common/utils.sh
tests_failed=0

# Get the base filename and derive function name
filename=$(basename "$0")
function_name="${filename#test_}"
function_name="${function_name%.sh}"

# Check if function exists
if ! declare -f "$function_name" >/dev/null; then
    echo "❌ FAIL: Function '$function_name' does not exist."
    # exit 1
fi

# Test cases for is_sha256_checksum

run_test 0 "Valid lowercase SHA-256" is_sha256_checksum "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
run_test 0 "Valid uppercase SHA-256" is_sha256_checksum "E3B0C44298FC1C149AFBF4C8996FB92427AE41E4649B934CA495991B7852B855"
run_test 1 "Too short (63 characters)" is_sha256_checksum "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b85"
run_test 1 "Too long (65 characters)" is_sha256_checksum "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b85511"
run_test 1 "Contains non-hex character (g)" is_sha256_checksum "g3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
run_test 1 "Empty string" is_sha256_checksum ""
run_test 1 "SHA-1 length (40 hex characters)" is_sha256_checksum "da39a3ee5e6b4b0d3255bfef95601890afd80709"

[ "$tests_failed" -eq 0 ] && exit 0 || exit 1
