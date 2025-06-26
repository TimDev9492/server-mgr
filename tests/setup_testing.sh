#!/bin/bash

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
    fi
}
