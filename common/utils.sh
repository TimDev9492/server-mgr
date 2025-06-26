#!/bin/bash

# check if required programs are installed
check_prerequisites() {
  local required_commands=("curl" "jq" "which" "awk" "grep" "sed" "screen")

  # Accept more requirements passed as arguments
  if [ $# -gt 0 ]; then
    required_commands+=("$@")
  fi

  # Check if required commands are installed
  for cmd in "${required_commands[@]}"; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
      echo "[ERROR] $cmd is not installed." >&2
      exit 1
    fi
  done
}

# fetch data from an API endpoint and exit on error,
# otherwise, return the response as a string.
fetch_api() {
  local url="$1"
  local response=$(curl -s "$url")

  is_error_response=$(echo "$response" | jq 'has("error")')
  if [ "$is_error_response" == "true" ]; then
    echo "[ERROR] API request failed: $response" >&2
    exit 1
  else
    echo "$response"
  fi
}

# Convert the following infos to a filename:
# - project
# - minecraft version
# - build number
# - channel
to_filename() {
  local project="$1"
  local version="$2"
  local build="$3"
  local channel="$4"
  echo "${project}-${version}-${build}-${channel}.jar"
}

# Extract information from a filename constructed using to_filename
get_info_from_filename() {
  local filename="$1"
  if [[ "$filename" =~ ^([^-]+)-([^-]+)-([^-]+)-([^-]+)\.jar$ ]]; then
    echo "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}" "${BASH_REMATCH[3]}" "${BASH_REMATCH[4]}"
  else
    echo "[ERROR] Invalid filename format: $filename" >&2
    exit 1
  fi
}

# Parse command line arguments into flags and positional arguments
# Usage: parse_args flags args "$@"
# - flags: an array to hold flags (e.g., -v, --verbose)
# - args: an array to hold positional arguments (e.g., server alias)
parse_args() {
  local -n _flags="$1"
  local -n _args="$2"
  shift 2

  _flags=()
  _args=()

  for arg in "$@"; do
    if [[ "$arg" == -* ]]; then
      _flags+=("$arg")
    else
      _args+=("$arg")
    fi
  done
}

# Check if a value is in an array
# Usage: in_array value array
# - value: the value to check
# - array: the array to check against (passed as a string)
in_array() {
  local value="$1"
  shift
  local element
  for element in "$@"; do
    if [[ "$element" == "$value" ]]; then
      return 0 # Value found
    fi
  done
  return 1 # Value not found
}
