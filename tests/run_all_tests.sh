#!/bin/bash

# load environment
TEST_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
cd ${TEST_DIR}

all_passed=0

echo "Running all tests in $TEST_DIR..."

for test_script in "$TEST_DIR"/test_*.sh; do
    if [ ! -f "$test_script" ]; then
        echo "No test scripts found."
        exit 1
    fi

    echo
    echo "=== Running $(basename $test_script) ==="
    bash "$test_script"
    exit_code=$?

    if [ $exit_code -ne 0 ]; then
        echo "❌ Some tests FAILED in $test_script"
        all_passed=1
    else
        echo "✅ All tests passed in $test_script"
    fi
done

echo
if [ $all_passed -eq 0 ]; then
    echo "🎉 All tests passed successfully!"
else
    echo "⚠️ Some tests failed."
    exit 1
fi
