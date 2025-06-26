#!/bin/bash

# load environment
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
cd ${SCRIPT_DIR}
source ./setup_testing.sh
source ../common/utils.sh
tests_failed=0

# check if function exists
if ! declare -f "to_filename" >/dev/null; then
    echo "❌ FAIL: Function 'to_filename' does not exist."
    exit 1
fi
if ! declare -f "get_info_from_filename" >/dev/null; then
    echo "❌ FAIL: Function 'get_info_from_filename' does not exist."
    exit 1
fi

export -f "to_filename"
export -f "get_info_from_filename"

test_inverse() {
    local project="$1"
    local version="$2"
    local build="$3"
    local channel="$4"
    local description="to_filename and get_info_from_filename are inverses for $project-$version-$build-$channel.jar"

    run_test 0 "$description" bash -c "
        filename=\$(to_filename \"$project\" \"$version\" \"$build\" \"$channel\")
        parsed=\$(get_info_from_filename \"\$filename\") || exit 1
        read -r p v b c <<<\"\$parsed\"
        [[ \"$project\" == \"\$p\" && \"$version\" == \"\$v\" && \"$build\" == \"\$b\" && \"$channel\" == \"\$c\" ]]
    "
}

# Test cases
test_inverse "myproj" "1.20.1" "42" "release"
test_inverse "coolProj" "2.0" "7" "beta"
test_inverse "proj" "0.1.0" "100" "snapshot"

[ "$tests_failed" -eq 0 ] && exit 0 || exit 1
