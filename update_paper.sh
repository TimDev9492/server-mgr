#!/bin/bash

project="paper"
channels="default"

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
cd ${SCRIPT_DIR}
source ./common/utils.sh

# Load variables
if [ ! -f "./variables.sh" ]; then
  echo "[ERROR] variables.sh not found in the script directory."
  exit 1
fi
source ./variables.sh

# Check for required commands
check_prerequisites

print_usage() {
  echo "Usage: update_paper.sh <version|'latest'|'installed'> <channels: comma-separated, default: 'default'> <project: optional, default: 'paper'>"
}

# parse arguments
if [ -z "$1" ]; then
  print_usage
  exit 1
else
  version="$1"
fi
if [ -n "$2" ]; then
  channels="$2"
else
  channels="default"
fi
if [ -n "$3" ]; then
  project="$3"
fi

# Get the latest build for the specified version and channel
get_latest_build() {
  target_version="$1"
  target_channel="$2"

  # Fetch the latest build information for the specified version and channel
  response=$(fetch_api "${PAPER_API_ENDPOINT}/projects/${project}/versions/${target_version}/builds") || echo "null"
  latest_build=$(echo "$response" | jq ".builds | map(select(.channel == \"$target_channel\") | .build) | .[-1]")

  echo "$latest_build"
}

# Download the latest build for the specified version.
# Expects the version to be a Minecraft version string (e.g., '1.16.1')
download_latest_build() {
  target_version="$1"
  download_channels="$2"

  # echo "[INFO] Searching for latest build of $project version $target_version in channels: $download_channels"

  # Convert to array using IFS (Internal Field Separator)
  IFS=',' read -ra build_channels <<<"$download_channels"

  # Loop over the array
  for channel in "${build_channels[@]}"; do
    latest_build=$(get_latest_build "$target_version" "$channel")
    if [ "$latest_build" == "null" ]; then
      # echo "[WARNING] No build found for version $target_version in channel $channel."
      continue
    fi
    local selected_channel="$channel"
    break
  done

  if [ -z "$selected_channel" ]; then
    echo "[WARNING] No builds found for version $target_version in any of the specified channels: $download_channels."
    exit 1
  fi

  # echo "[INFO] Downloading latest $selected_channel build for $project version $target_version build $latest_build..."

  args=("$@")
  set -- "install" "$project" "$target_version" "$latest_build"
  source ./papman.sh
  set -- "${args[@]}" # Restore original arguments
}

if [ "$version" == "latest" ]; then
  response=$(fetch_api ${PAPER_API_ENDPOINT}/projects/${project}) || exit 1
  latest_version=$(echo "$response" | jq -r '.versions[-1]')
  download_latest_build "$latest_version" "$channels"
elif [ "$version" == "installed" ]; then
  # Go through all installed versions and download
  # the latest build for each using the specified
  # channels and project
  project_directory="${PAPER_DOWNLOAD_DIR}/${project}"
  if [ ! -d "$project_directory" ]; then
    echo "[ERROR] No installation found for project $project."
    exit 1
  fi
  installed_versions=$(find "${project_directory}" -mindepth 1 -maxdepth 1 -type d | xargs -I {} basename {})
  if [ -z "$installed_versions" ]; then
    echo "[WARNING] No installed versions found for project $project."
    exit 1
  fi
  for installed_version in $installed_versions; do
    echo "[INFO] Updating project $project version $installed_version..."
    download_latest_build "$installed_version" "$channels"
  done
else
  download_latest_build "$version" "$channels"
fi
