#!/bin/bash

# JavMan - The Java Version Manager
# A script to install and manage links for different java versions.

# load environment
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
cd ${SCRIPT_DIR}
source ./common/utils.sh

# Parse command line arguments into flags and positional arguments
VERBOSE=false

parse_args flags args "$@"

# parse the flags
for flag in "${flags[@]}"; do
  case "$flag" in
  -v)
    VERBOSE=true
    ;;
  esac
done

# Load variables
if [ ! -f "./load_config.sh" ]; then
  echo "[ERROR] load_config.sh not found in the script directory." >&2
  exit 1
fi
source ./load_config.sh

# Check for required commands
check_prerequisites

# parse arguments
operations=("list" "install")

print_usage() {
  if [ -z "${args[0]}" ]; then
    local IFS='|'
    local ops="${operations[*]}"
    echo "Usage: papman.sh <$ops>" >&2
  fi
}

if [ -z "${args[0]}" ]; then
  print_usage "${args[0]}}"
  exit 1
fi

# Warn user about different config values when running as root
if [ "$(id -u)" -eq 0 ]; then
  echo "[WARNING] Running as root, config values may be different!" >&2
  java_link_dir="$(prompt_default_value "Enter java link directory" "$JAVA_LINK_DIR")"
  [ $? -eq 130 ] && abort_server_creation
  java_search_dir="$(prompt_default_value "Enter java link directory" "$JAVA_SEARCH_DIR")"
  [ $? -eq 130 ] && abort_server_creation
else
  # Use the default values for non-root users
  java_link_dir="$JAVA_LINK_DIR"
  java_search_dir="$JAVA_SEARCH_DIR"
fi

list_installed_java_links() {
  for file in "$java_link_dir"/*; do
    # Only delete files in the format java<major_version>
    basename "$file" | grep -qE '^java[0-9]+$' || continue

    # Only list symlinks
    [ -L "$file" ] || continue

    echo "$file"
  done
}

operation="${args[0]}"

case "$operation" in
list)
  existing_links=$(list_installed_java_links)
  if [ -n "$existing_links" ]; then
    while IFS='' read -r existing; do
      basename "$existing"
    done <<<"$existing_links"
  fi
  ;;
install)
  # Make sure the script is run with root privileges
  if [ "$(id -u)" -ne 0 ]; then
    echo "[ERROR] This operation must be run as root or with sudo." >&2
    exit 1
  fi

  # Check if the directories exist
  if [ ! -d "$java_link_dir" ]; then
    echo "[ERROR] Java link directory does not exist: $java_link_dir" >&2
    exit 1
  fi
  if [ ! -d "$java_search_dir" ]; then
    echo "[ERROR] Java search directory does not exist: $java_search_dir" >&2
    exit 1
  fi

  # Find all major java versions installed on the system
  # and link them to the specified directory with the
  # format java<major_version> (e.g., java8, java11, java17)

  delete_existing=false
  if ! in_array "--delete-existing" "${flags[@]}"; then
    echo "[INFO] Use --delete-existing to delete existing links before installing new ones." >&2
  else
    delete_existing=true
  fi

  # Delete existing links
  if [ "$delete_existing" = true ]; then
    existing_links=$(list_installed_java_links)
    if [ -n "$existing_links" ]; then
      while IFS='' read -r existing_link; do
        # Only delete files in the format java<major_version>
        basename "$existing_link" | grep -qE '^java[0-9]+$' || continue

        # Only delete symlinks
        [ -L "$existing_link" ] || continue

        echo "[INFO] Deleting existing link: $existing_link" >&2
        rm "$existing_link"
      done <<<"$existing_links"
    fi
  fi

  # Create new links for installed java versions
  for installed_java_dir in "$java_search_dir"/*; do
    # Only process directories
    [ -d "$installed_java_dir" ] || continue

    # Ignore symlinks
    [ -L "$installed_java_dir" ] && continue

    java_binary_path="${installed_java_dir}/bin/java"

    # Skip directory if it does not contain a java binary
    if ! [ -x "$java_binary_path" ]; then
      echo "[WARNING] No java binary found in $installed_java_dir, skipping." >&2
      continue
    fi

    # Extract the major version from the directory name
    full_version=$("$java_binary_path" -version 2>&1 | awk -F '"' '/version/ {print $2}')

    # Determine major version
    if [[ $full_version == 1.* ]]; then
      # Old style: 1.8.0_xxx → major version is the second component
      major_version=$(echo "$full_version" | cut -d. -f2)
    else
      # New style: 11.0.22 → major version is the first component
      major_version=$(echo "$full_version" | cut -d. -f1)
    fi

    # Create the symlink in the user install directory
    link_name="$java_link_dir/java$major_version"
    if [ -L "$link_name" ]; then
      echo "[WARNING] Link already exists: $link_name, skipping." >&2
    else
      echo "[INFO] Creating link: $link_name -> $java_binary_path" >&2
      ln -s "$java_binary_path" "$link_name"
    fi
  done
  ;;
*)
  echo "[ERROR] Unknown operation: $operation" >&2
  print_usage
  exit 1
  ;;
esac
