#!/bin/bash

load_project_info() {
  # load environment
  local script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
  cd "${script_dir}/.."
  local project_info="$(cat project_info.json)"
  HOMEPAGE=$(echo "$project_info" | jq -r '.homepage')
  VERSION=$(echo "$project_info" | jq -r '.version')
  PAPER_API_ENDPOINT=$(echo "$project_info" | jq -r '.api_endpoint')
}

load_project_info

get_project_user_agent() {
  echo "server-mgr/$VERSION ($HOMEPAGE)"
}

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
  local response=$(curl -s -H "$(get_project_user_agent)" "$url")

  is_error_response=$(echo "$response" | jq 'type != "array" and has("error")')
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

  # If one argument left and it contains newlines, treat it as multiline string
  if [[ $# -eq 1 && "$1" == *$'\n'* ]]; then
    local line
    while IFS= read -r line; do
      if [[ "$line" == "$value" ]]; then
        return 0
      fi
    done <<<"$1"
  else
    local element
    for element in "$@"; do
      if [[ "$element" == "$value" ]]; then
        return 0
      fi
    done
  fi

  return 1
}

print_screen_session_names() {
  screen -ls | awk '/\t/{print $1}' | cut -d. -f2
}

to_screen_session_name() {
  local server_alias="$1"
  echo "minecraft-server-$server_alias"
}

get_server_status() {
  local server_alias="$1"
  local screen_session_names=$(print_screen_session_names)
  if in_array "$(to_screen_session_name $server_alias)" $screen_session_names; then
    echo "Running"
  else
    echo "Idle"
  fi
}

send_server_command() {
  local server_alias="$1"
  shift
  local command="$*"
  local screen_session_name=$(to_screen_session_name "$server_alias")

  if in_array "$screen_session_name" $(print_screen_session_names); then
    screen -S "$screen_session_name" -p 0 -X stuff "$command$(printf \\r)"
    return 0
  else
    echo "[ERROR] Server '$server_alias' is not running." >&2
    return 1
  fi
  return 0
}

is_number() {
  case "$1" in
  '' | *[!0-9]*)
    return 1
    ;; # Not a number
  *)
    return 0
    ;; # Is a number
  esac
}

trim() {
  echo "$1" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//'
}

print_time() {
  local secs="$1"
  if ((secs >= 60)); then
    local mins=$((secs / 60))
    local rem=$((secs % 60))
    echo "${mins}min ${rem}s"
  else
    echo "${secs}s"
  fi
}
is_sha256_checksum() {
  local input="$1"

  # A SHA-256 checksum is exactly 64 hexadecimal characters
  [[ "$input" =~ ^[a-fA-F0-9]{64}$ ]]
}

is_sha256_checksum() {
  local input="$1"

  # A SHA-256 checksum is exactly 64 hexadecimal characters
  [[ "$input" =~ ^[a-fA-F0-9]{64}$ ]]
}

print_table() {
  local parsing_delimiter="$1"
  local column_delimiter="$2"
  local header="$3"
  shift 3
  local -a rows=("$@")

  # Default delimiter to space if empty
  [[ -z "$parsing_delimiter" ]] && parsing_delimiter=' '
  [[ -z "$column_delimiter" ]] && column_delimiter=' '
  IFS="$parsing_delimiter"

  # Split header and rows into arrays of fields
  local -a headers
  read -r -a headers <<<"$header"
  local num_cols="${#headers[@]}"

  # Initialize max width for each column with header lengths
  local -a col_widths
  for ((i = 0; i < num_cols; i++)); do
    col_widths[i]=${#headers[i]}
  done

  # Process rows to determine max width per column
  for row in "${rows[@]}"; do
    local -a fields
    read -r -a fields <<<"$row"
    for ((i = 0; i < num_cols; i++)); do
      [[ -n "${fields[i]}" ]] && ((${#fields[i]} > col_widths[i])) && col_widths[i]=${#fields[i]}
    done
  done

  # Print header
  for ((i = 0; i < num_cols; i++)); do
    printf "%-*s" "${col_widths[i]}" "${headers[i]}"
    if ((i < num_cols - 1)); then
      printf "%s" "${column_delimiter}"
    fi
  done
  echo

  # Print rows
  for row in "${rows[@]}"; do
    read -r -a fields <<<"$row"
    for ((i = 0; i < num_cols; i++)); do
      printf "%-*s" "${col_widths[i]}" "${fields[i]}"
      if ((i < num_cols - 1)); then
        printf "%s" "${column_delimiter}"
      fi
    done
    echo
  done
}

get_creation_or_mod_time() {
  local dir_path="$1"
  local unix_time="$(stat -c %W "$dir_path")"

  if [ "$unix_time" -eq -1 ]; then
    unix_time="$(stat -c %Y "$dir_path")"
  fi

  echo "$unix_time"
}
