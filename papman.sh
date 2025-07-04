#!/bin/bash

# PapMan - The Paper Manager
# A script to install and manage jar files for PaperMC projects.

# load environment
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
cd ${SCRIPT_DIR}
source ./common/utils.sh

# logging
VERBOSE=false
log() {
  $VERBOSE && echo "$@" >&2
}

# Load variables
if [ ! -f "./load_config.sh" ]; then
  echo "[ERROR] load_config.sh not found in the script directory." >&2
  exit 1
fi
source ./load_config.sh

# Check for required commands
check_prerequisites

# Parse command line arguments into flags and positional arguments
parse_args flags args "$@"

if in_array "-v" "${flags[@]}"; then
  VERBOSE=true
fi

operations=("install" "list-versions" "list-builds" "link")

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
    link)
      echo "Usage: papman.sh link <link_name> <project> <version> <build|'latest'> [<channel>]" >&2
      ;;
    *)
      echo "[ERROR] Unknown operation: $1" >&2
      ;;
    esac
  fi
}

if [ -z "${args[0]}" ]; then
  print_usage "${args[0]}"
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

list_versions() {
  local project="$1"

  local dir
  for dir in "${PAPER_DOWNLOAD_DIR}/${project}"/*; do
    [ -d "$dir" ] || continue
    # check if directory name is a valid version
    local dir_version=$(basename "$dir")
    # check if dir_version matches the version regex
    echo "$dir_version" | grep -Eq '^[0-9]+(\.[0-9]+){1,2}$' || continue
    # check if the directory exists in the API
    # curl -sf -o /dev/null -H "User-Agent: $(get_project_user_agent)" "${PAPER_API_ENDPOINT}/projects/paper/versions/${dir_version}" || continue
    echo "$dir_version"
  done
}

list_builds() {
  local project="$1"
  local version="$2"

  local jar_path
  for jar_path in "${PAPER_DOWNLOAD_DIR}/${project}/${version}"/*.jar; do
    # skip symlinks
    [ -L "$jar_path" ] && continue
    if [ -f "$jar_path" ]; then
      local jar_filename=$(basename "$jar_path")
      # get build number from filename using common/utils.sh get_info_from_filename function
      local project_name
      local project_version
      local build_number
      local channel_name
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
}

construct_jar_output_dir() {
  local project="$1"
  local version="$2"
  echo "${PAPER_DOWNLOAD_DIR}/${project}/${version}"
}

construct_latest_jar_name() {
  local project="$1"
  echo "${project}-latest.jar"
}

operation="${args[0]}"

case "$operation" in
install)
  if [ -z "${args[1]}" ] || [ -z "${args[2]}" ] || [ -z "${args[3]}" ]; then
    print_usage "$operation"
    exit 1
  fi

  project="${args[1]}"
  version="${args[2]}"
  build="${args[3]}"

  build_info=$(fetch_api "${PAPER_API_ENDPOINT}/projects/${project}/versions/${version}/builds/${build}")
  api_jar_name=$(echo "$build_info" |
    jq -r '.downloads.["server:default"].name')
  channel=$(echo "$build_info" | jq -r '.channel')
  jar_output_filename=$(to_filename "$project" "$version" "$build" "$channel")
  # jar_output_directory="${PAPER_DOWNLOAD_DIR}/${project}/${version}"
  jar_output_directory="$(construct_jar_output_dir "$project" "$version")"
  mkdir -p "${jar_output_directory}"

  output_path="${jar_output_directory}/${jar_output_filename}"

  download_url="$(echo "$build_info" | jq -r '.downloads.["server:default"].url')"
  expected_sha256_checksum="$(echo "$build_info" | jq -r '.downloads.["server:default"].checksums.sha256')"
  # Check if file exists before downloading
  if curl --head -s --fail -H "User-Agent: $(get_project_user_agent)" "${download_url}" >/dev/null; then
    # download the file
    curl -s -H "User-Agent: $(get_project_user_agent)" "${download_url}" -o "${output_path}"
    # verify the checksum
    actual_sha256_checksum="$(sha256sum "${output_path}" | awk '{print $1}')"
    if is_sha256_checksum "$expected_sha256_checksum" && [ "$actual_sha256_checksum" != "$expected_sha256_checksum" ]; then
      echo "[ERROR] Checksum verification failed for ${output_path}, deleting..." >&2
      rm -f "${output_path}"
      exit 1
    fi

    chmod +x "${output_path}"
    latest_jar_filename=$(get_latest_build_file "$project" "$version")
    if [ "$latest_jar_filename" == "null" ]; then
      echo "[ERROR] Unexpected failure: No latest jar file found for project '$project' and version '$version'." >&2
      exit 1
    fi
    # ln -sf "${jar_output_directory}/${latest_jar_filename}" "${jar_output_directory}/${project}-latest.jar"
    ln -sf "${jar_output_directory}/${latest_jar_filename}" "${jar_output_directory}/$(construct_latest_jar_name "$project")"
    echo "[INFO] Successfully installed $project version $version (build: $build) (channel: $channel)" >&2
  else
    echo "[ERROR] The file does not exist at the specified URL: ${download_url}" >&2
    exit 1
  fi
  ;;
list-versions)
  if [ -z "${args[1]}" ]; then
    print_usage "$operation"
    exit 1
  fi

  list_versions "${args[1]}"
  ;;
list-builds)
  if [ -z "${args[1]}" ] || [ -z "${args[2]}" ]; then
    print_usage "$operation"
    exit 1
  fi

  list_builds "${args[1]}" "${args[2]}"
  ;;
link)
  link_name="${args[1]}"
  project="${args[2]}"
  version="${args[3]}"
  build="${args[4]}"
  channel="${args[5]}"
  target_filename=''
  if [ -z "$link_name" ] || [ -z "$project" ] || [ -z "$version" ] || [ -z "$build" ]; then
    print_usage "$operation"
    exit 1
  fi
  if [ "$(list_versions "$project" | grep -c "^$version$")" -eq 0 ]; then
    echo "[ERROR] Version '$version' not found for project '$project'." >&2
    exit 1
  fi
  if [ "$build" == "latest" ]; then
    target_jar="$(construct_latest_jar_name "$project")"
    target_filename="$(construct_jar_output_dir "$project" "$version")/${target_jar}"
  else
    if [ $"$(list_builds "$project" "$version" | grep -c "^$build$")" -eq 0 ]; then
      echo "[ERROR] Build '$build' not found for project '$project' and version '$version'." >&2
      exit 1
    fi
    if [ -n "$channel" ]; then
      target_jar="$(to_filename "$project" "$version" "$build" "$channel")"
      target_filename="$(construct_jar_output_dir "$project" "$version")/${target_jar}"
    else
      # search for the suiting channel jar
      jar_dir="$(construct_jar_output_dir "$project" "$version")"
      target_filename=''
      matching_count=0
      for jar_path in "${jar_dir}"/*.jar; do
        # skip symlinks
        [ -L "$jar_path" ] && continue
        # skip if not a file
        [ ! -f "$jar_path" ] && continue

        jar_filename=$(basename "$jar_path")
        read -r jar_project jar_version jar_build jar_channel < <(get_info_from_filename "$jar_filename")
        if [ "$jar_project" == "$project" ] && [ "$jar_version" == "$version" ] && [ "$jar_build" == "$build" ]; then
          target_filename="$jar_path"
          ((matching_count++))
        fi
      done
      if [ -z "$target_filename" ]; then
        echo "[ERROR] No jar file found for project '$project', version '$version', build '$build'." >&2
        exit 1
      fi
      if [ "$matching_count" -gt 1 ]; then
        echo "[ERROR] Found $matching_count matching jar files for project '$project', version '$version', build '$build', resolve manually..." >&2
        exit 1
      fi
    fi
  fi
  if [ ! -f "$target_filename" ]; then
    echo "[ERROR] Target file '$target_filename' does not exist." >&2
    exit 1
  fi
  # create the link
  ln -sf "$target_filename" "$link_name"
  if [ $? -ne 0 ]; then
    echo "[ERROR] Failed to create symlink '$link_name' -> '$target_filename'" >&2
    exit 1
  fi
  log "[INFO] Successfully linked '$link_name' to '$target_filename'" >&2
  ;;
*)
  echo "[ERROR] Unknown operation: $operation" >&2
  print_usage
  exit 1
  ;;
esac

exit 0
