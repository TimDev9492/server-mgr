#!/bin/bash

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
