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
  local required_commands=("curl" "jq" "which" "awk" "grep" "sed" "screen" "cut" "printf" "date")

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

  noheader=false

  if [ -z "$header" ]; then
    # set header to first row
    noheader=true
    if [ ${#rows[@]} -eq 0 ]; then
      echo "[ERROR] No header or rows provided." >&2
      return 1
    fi
    header="${rows[0]}"
  fi

  if [[ "$parsing_delimiter" == *"/"* ]]; then
    echo "[ERROR] Parsing delimiter cannot contain '/' character." >&2
    return 1
  fi

  # Default delimiter to space if empty
  [[ -z "$parsing_delimiter" ]] && parsing_delimiter=' '
  [[ -z "$column_delimiter" ]] && column_delimiter=' '

  # Split header and rows into arrays of fields
  local -a headers
  IFS=$'\n' read -rd '' -a headers <<<"$(sed "s/$parsing_delimiter/\n/g" <<<"$header")"
  local num_cols="${#headers[@]}"

  # Initialize max width for each column with header lengths
  local -a col_widths
  for ((i = 0; i < num_cols; i++)); do
    col_widths[i]=${#headers[i]}
  done

  # Process rows to determine max width per column
  for row in "${rows[@]}"; do
    local -a fields
    IFS=$'\n' read -rd '' -a fields <<<"$(sed "s/$parsing_delimiter/\n/g" <<<"$row")"
    # read -r -a fields <<<"$row"
    for ((i = 0; i < num_cols; i++)); do
      [[ -n "${fields[i]}" ]] && ((${#fields[i]} > col_widths[i])) && col_widths[i]=${#fields[i]}
    done
  done

  # Print header
  if ! $noheader; then
    for ((i = 0; i < num_cols; i++)); do
      printf "%-*s" "${col_widths[i]}" "${headers[i]}"
      if ((i < num_cols - 1)); then
        printf "%s" "${column_delimiter}"
      fi
    done
    echo
  fi

  # Print rows
  for row in "${rows[@]}"; do
    IFS=$'\n' read -rd '' -a fields <<<"$(sed "s/$parsing_delimiter/\n/g" <<<"$row")"
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

unix_to_date() {
  # check if input is a number
  if ! is_number "$1"; then
    return 1
  fi
  date -d "@$1" +"%Y-%m-%d %H:%M:%S"
}

# Use the following approach:
# subtract biggest unit, then check if threshold is passed,
# otherwise subtract next biggest unit, and so on.
# Using date -d "-1 month" for example
print_elapsed_time() {
  local event_time="$1"
  local reference_time="$2"

  if ((event_time > reference_time)); then
    echo "Error: event_time is after reference_time"
    return 1
  fi

  local units=("year" "month" "day" "hour" "minute")
  local unit_values=(0 0 0 0 0)
  local unit_format=("y" "m" "d" "h" "min")
  local current_unit_index=0

  i=0
  while ((i < ${#units[@]})); do
    local backtrack_str=""
    for part in "${!units[@]}"; do
      local value="${unit_values[part]}"
      if ((part == i)); then ((value++)); fi
      backtrack_str+="${value} ${units[part]} ago "
    done

    # Trim trailing space
    backtrack_str="${backtrack_str%" "}"

    local backtrack_time="$(date -d "$(unix_to_date "$reference_time") $backtrack_str" +%s)"
    if ((backtrack_time < event_time)); then
      ((i++))
      continue
    fi
    ((unit_values[i]++))
  done

  # format the output

  # --- 1. Decide which format to use ---
  # The index for 'm' (months) is 1.
  # The condition is: if the month value is > 1.
  local indices_to_use
  if ((unit_values[0] > 0 || unit_values[1] > 0)); then
    # Use years, months, days (indices 0, 1, 2)
    indices_to_use=(0 1 2)
  else
    # Use days, hours, minutes (indices 2, 3, 4)
    indices_to_use=(2 3 4)
  fi

  # --- 2. Build the output string respecting the rules ---
  local result_parts=()
  local found_first_non_zero=false
  # Get the last index from our chosen set
  local last_index=${indices_to_use[-1]}

  for i in "${indices_to_use[@]}"; do
    local value=${unit_values[i]}
    local unit=${unit_format[i]}

    # Rule: Leave out leading zeros
    if ((value > 0)); then
      found_first_non_zero=true
    fi

    # We add a part to the result if:
    #   a) We have already found a non-zero value (so we print everything that follows)
    #   b) This is the very last unit, which must always be printed
    if [[ "$found_first_non_zero" == true || "$i" -eq "$last_index" ]]; then
      result_parts+=("${value}${unit}")
    fi
  done

  # --- 3. Join the parts with spaces and print ---
  (
    IFS=' '
    echo "${result_parts[*]}"
  )
}

colorize_output() {
  local input="$1"
  local color="${2:-green}" # Default color is green
  local color_code

  # Map color names to ANSI codes
  case "$color" in
  black) color_code="0;30" ;;
  red) color_code="0;31" ;;
  green) color_code="0;32" ;;
  yellow) color_code="0;33" ;;
  blue) color_code="0;34" ;;
  magenta) color_code="0;35" ;;
  cyan) color_code="0;36" ;;
  white) color_code="0;37" ;;
  *) color_code="0;32" ;; # Default to green
  esac

  # Print each line with color
  while IFS= read -r line; do
    echo -e "\e[${color_code}m${line}\e[0m"
  done <<<"$input"
}

# Prompt the user for a value with a default
# Usage: prompt_default_value "Enter your name" "John Doe"
prompt_default_value() {
  local prompt="$1"
  local default="$2"

  local input=''
  read -p "$prompt [$default]: " input
  read_status="$?"
  echo "${input:-$default}" # If input is empty, return default value
  return $read_status       # Return the status of the read command
}

is_valid_alias() {
  local alias="$1"
  local regex='^[a-zA-Z0-9_-]+$' # Allow alphanumeric characters and hyphens
  [[ "$alias" =~ $regex ]]
  return $?
}

json_to_yaml() {
  # Read JSON from the first argument or from stdin if no argument is provided.
  local json_input="$1"

  # The core jq script for conversion.
  # This script defines a recursive function to handle the conversion.
  local jq_script='
    def to_yaml_recursive(indent):
      type as $type
      | if $type == "object" then
          if . == {} then "{}"
          else
            to_entries
            | map(
                indent + .key + ":" +
                (
                  if (.value | type) == "object" or (.value | type) == "array" then "\n" else " " end
                ) +
                (.value | to_yaml_recursive(indent + "  "))
              )
            | join("\n")
          end
      elif $type == "array" then
        if . == [] then "[]"
        else
          # For arrays, print each element prefixed with "- " at current indentation
          map(
            indent + "- " + to_yaml_recursive(indent + "  ")
          )
          | join("\n")
        end
      else
        tojson
      end;

    to_yaml_recursive("")
  '

  # Execute jq with the script and input.
  # The -r flag removes the outer quotes from the final output strings.
  echo "$json_input" | jq -r "$jq_script"
}
