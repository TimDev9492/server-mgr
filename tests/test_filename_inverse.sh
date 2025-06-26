#!/bin/bash

# load environment
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
cd ${SCRIPT_DIR}
source ./setup_testing.sh
source ../common/utils.sh

test_inverse() {
    local project="$1"
    local version="$2"
    local build="$3"
    local channel="$4"

    local filename
    filename=$(to_filename "$project" "$version" "$build" "$channel")

    # get_info_from_filename outputs space-separated values
    local parsed
    parsed=$(get_info_from_filename "$filename") || return 1

    # Split parsed into array
    read -r p v b c <<<"$parsed"

    if [[ "$project" == "$p" && "$version" == "$v" && "$build" == "$b" && "$channel" == "$c" ]]; then
        echo "✅ PASS: to_filename and get_info_from_filename are inverses for $filename"
        return 0
    else
        echo "❌ FAIL: mismatch for $filename"
        echo "    Expected: $project $version $build $channel"
        echo "    Got:      $p $v $b $c"
        return 1
    fi
}

# Test cases
test_inverse "myproj" "1.20.1" "42" "release"
test_inverse "coolProj" "2.0" "7" "beta"
test_inverse "proj" "0.1.0" "100" "snapshot"
