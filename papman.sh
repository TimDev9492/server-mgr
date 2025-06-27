#!/bin/bash

# PapMan - The Paper Manager
# A script to install and manage jar files for PaperMC projects.

# load environment
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
cd ${SCRIPT_DIR}
source ./common/utils.sh

# Load variables
if [ ! -f "./load_config.sh" ]; then
  echo "[ERROR] load_config.sh not found in the script directory." >&2
  exit 1
fi
source ./load_config.sh

# Check for required commands
check_prerequisites

# parse arguments
operations=("install" "list-versions" "list-builds")

print_usage() {
  if [ -z "$1" ]; then
    local IFS='|'
    local ops="${operations[*]}"
    echo "Usage: papman.sh <$ops>" >&2
  else
    case "$1" in
    install)
      echo "Usage: papman.sh install <project> <version> <build>" >&2
      ;;
    list-versions)
      echo "Usage: papman.sh list-versions <project>" >&2
      ;;
    list-builds)
      echo "Usage: papman.sh list-builds <project> <version> [-c: with channels]" >&2
      ;;
    *)
      echo "[ERROR] Unknown operation: $1" >&2
      ;;
    esac
  fi
}

if [ -z "$1" ]; then
  print_usage "$1"
  exit 1
fi

get_latest_build_file() {
  local project="$1"
  local version="$2"
  local latest_jar_filename="null"
  local latest_build_number="-1"

  for jar_path in "${PAPER_DOWNLOAD_DIR}/${project}/${version}"/*.jar; do
    # skip symlinks
    [ -L "$jar_path" ] && continue
    if [ -f "$jar_path" ]; then
      jar_filename=$(basename "$jar_path")
      # get build number from filename using common/utils.sh get_info_from_filename function
      read -r project_name project_version build_number channel_name < <(get_info_from_filename "$jar_filename")
      [ "$latest_build_number" -gt "$build_number" ] && continue
      latest_build_number="$build_number"
      latest_jar_filename="$jar_filename"
    fi
  done

  echo "$latest_jar_filename"
}

operation="$1"

case "$operation" in
install)
  if [ -z "$2" ] || [ -z "$3" ] || [ -z "$4" ]; then
    print_usage "$operation"
    exit 1
  fi

  project="$2"
  version="$3"
  build="$4"

  build_info=$(fetch_api "${PAPER_API_ENDPOINT}/projects/${project}/versions/${version}/builds/${build}")
  api_jar_name=$(echo "$build_info" |
    jq -r '.downloads.application.name')
  channel=$(echo "$build_info" | jq -r '.channel')
  jar_output_filename=$(to_filename "$project" "$version" "$build" "$channel")
  jar_output_directory="${PAPER_DOWNLOAD_DIR}/${project}/${version}"
  mkdir -p "${jar_output_directory}"

  output_path="${jar_output_directory}/${jar_output_filename}"

  download_url="${PAPER_API_ENDPOINT}/projects/${project}/versions/${version}/builds/${build}/downloads/${api_jar_name}"
  # Check if file exists before downloading
  if curl --head -s --fail "${download_url}" >/dev/null; then
    # download the file
    curl -s "${download_url}" -o "${output_path}"

    chmod +x "${output_path}"
    # TODO: Link to the actual lastest build jar file
    latest_jar_filename=$(get_latest_build_file "$project" "$version")
    if [ "$latest_jar_filename" == "null" ]; then
      echo "[ERROR] Unexpected failuer: No latest jar file found for project '$project' and version '$version'." >&2
      exit 1
    fi
    ln -sf "${jar_output_directory}/${latest_jar_filename}" "${jar_output_directory}/${project}-latest.jar"
    echo "[INFO] Successfully installed $project version $version (build: $build) (channel: $channel)" >&2
  else
    echo "[ERROR] The file does not exist at the specified URL: ${download_url}" >&2
    exit 1
  fi
  ;;
list-versions)
  if [ -z "$2" ]; then
    print_usage "$operation"
    exit 1
  fi

  project="$2"

  for dir in "${PAPER_DOWNLOAD_DIR}/${project}"/*; do
    [ -d "$dir" ] || continue
    # check if directory name is a valid version
    dir_version=$(basename "$dir")
    # check if dir_version matches the version regex
    echo "$dir_version" | grep -Eq '^[0-9]+(\.[0-9]+){1,2}$' || continue
    # check if the directory exists in the API
    # curl -sf -o /dev/null "${PAPER_API_ENDPOINT}/projects/paper/versions/${dir_version}" || continue
    echo "$dir_version"
  done
  ;;
list-builds)
  if [ -z "$2" ] || [ -z "$3" ]; then
    print_usage "$operation"
    exit 1
  fi

  project="$2"
  version="$3"

  for jar_path in "${PAPER_DOWNLOAD_DIR}/${project}/${version}"/*.jar; do
    # skip symlinks
    [ -L "$jar_path" ] && continue
    if [ -f "$jar_path" ]; then
      jar_filename=$(basename "$jar_path")
      # get build number from filename using common/utils.sh get_info_from_filename function
      read -r project_name project_version build_number channel_name < <(get_info_from_filename "$jar_filename")
      [ -z "$build_number" ] && continue
      if [ "$4" == "-c" ]; then
        # if -c is passed, print build number and channel name
        echo "${build_number}-${channel_name}"
      else
        # print only build number
        echo "${build_number}"
      fi
    fi
  done
  ;;
*)
  echo "[ERROR] Unknown operation: $operation" >&2
  print_usage
  exit 1
  ;;
esac
