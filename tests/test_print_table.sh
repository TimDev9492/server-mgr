#!/bin/bash

# Load environment
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
cd ${SCRIPT_DIR}
source ./setup_testing.sh
source ../common/utils.sh
tests_failed=0

# Get function name from filename
filename=$(basename "$0")
function_name="${filename#test_}"
function_name="${function_name%.sh}"

# Check if function exists
if ! declare -f "$function_name" >/dev/null; then
    echo "❌ FAIL: Function '$function_name' does not exist."
    exit 1
fi

### Test case 1: Standard table
test_standard_table() {
    local header="Name Age City"
    local rows=("Alice 30 London" "Bob 25 New_York" "Charlie 28 Paris")
    local expected_output=$(
        cat <<EOF
Name    Age City    
Alice   30  London  
Bob     25  New_York
Charlie 28  Paris   
EOF
    )
    local output
    output="$(print_table " " " " "$header" "${rows[@]}")"
    [[ "$output" == "$expected_output" ]]
}
run_test 0 "Standard table formatting" test_standard_table

### Test case 2: Empty input
test_empty_input() {
    local header="Name Age City"
    local -a rows=()
    local expected_output="Name Age City"
    local output
    output="$(print_table " " " " "$header" "${rows[@]}")"
    [[ "$output" == "$expected_output" ]]
}
run_test 0 "Empty rows produce header only" test_empty_input

### Test case 3: Single row
test_single_row() {
    local header="Fruit Quantity"
    local rows=("Apple 5")
    local expected_output=$(
        cat <<EOF
Fruit Quantity
Apple 5       
EOF
    )
    local output
    output="$(print_table " " " " "$header" "${rows[@]}")"
    [[ "$output" == "$expected_output" ]]
}
run_test 0 "Single row formatting" test_single_row

### Test case 4: Longest value in last column
test_wide_last_column() {
    local header="ID Desc"
    local rows=("1 Short" "2 A_very_long_description")
    local expected_output=$(
        cat <<EOF
ID Desc                   
1  Short                  
2  A_very_long_description
EOF
    )
    local output
    output="$(print_table " " " " "$header" "${rows[@]}")"
    [[ "$output" == "$expected_output" ]]
}
run_test 0 "Wide content in last column handled correctly" test_wide_last_column

### Test case 5: Columns with numbers only
test_numeric_columns() {
    local header="X Y Z"
    local rows=("1 2 3" "100 200 300")
    local expected_output=$(
        cat <<EOF
X   Y   Z  
1   2   3  
100 200 300
EOF
    )
    local output
    output="$(print_table " " " " "$header" "${rows[@]}")"
    [[ "$output" == "$expected_output" ]]
}
run_test 0 "All numeric content aligns properly" test_numeric_columns

### Test case 6: Comma-delimited table with spaces in header columns
test_comma_delimited_table() {
    local header="First Name,Last Name,City"
    local rows=("Alice,Smith,New York" "Bob,Johnson,San Francisco" "Charlie,Brown,Los Angeles")
    local expected_output=$(
        cat <<EOF
First Name Last Name City         
Alice      Smith     New York     
Bob        Johnson   San Francisco
Charlie    Brown     Los Angeles  
EOF
    )
    local output
    output="$(print_table "," " " "$header" "${rows[@]}")"
    [[ "$output" == "$expected_output" ]]
}
run_test 0 "Comma-delimited with spaces in headers" test_comma_delimited_table

### Test case 7: Tab-delimited table
test_tab_delimited_table() {
    local header=$'Name\tAge\tCity'
    local rows=($'Alice\t30\tLondon' $'Bob\t25\tNew_York' $'Charlie\t28\tParis')
    local expected_output=$(
        cat <<EOF
Name    Age City    
Alice   30  London  
Bob     25  New_York
Charlie 28  Paris   
EOF
    )
    local output
    output="$(print_table $'\t' " " "$header" "${rows[@]}")"
    [[ "$output" == "$expected_output" ]]
}
run_test 0 "Tab-delimited table" test_tab_delimited_table

### Test case 8: Semicolon-delimited with multi-word fields
test_semicolon_delimited_table() {
    local header="Product;Price;Description"
    local rows=(
        "Widget A;19.99;Small widget"
        "Widget B;29.99;Larger widget"
        "Gadget;49.99;Multi-purpose gadget"
    )
    local expected_output=$(
        cat <<EOF
Product  Price Description         
Widget A 19.99 Small widget        
Widget B 29.99 Larger widget       
Gadget   49.99 Multi-purpose gadget
EOF
    )
    local output
    output="$(print_table ";" " " "$header" "${rows[@]}")"
    [[ "$output" == "$expected_output" ]]
}
run_test 0 "Semicolon-delimited with multi-word fields" test_semicolon_delimited_table

### Final test result
[ "$tests_failed" -eq 0 ] && exit 0 || exit 1
