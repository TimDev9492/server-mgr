#!/bin/bash

# Make sure the script is run with root privileges
if [ "$(id -u)" -ne 0 ]; then
  echo "[ERROR] This script must be run as root or with sudo."
  exit 1
fi

# The installation directory for the symlinks, should be in PATH
user_install_dir="/usr/local/bin"

# The directory where java versions get detected
java_search_dir="/usr/lib/jvm"

# Find all major java versions installed on the system
# and link them to the specified directory with the
# format java<major_version> (e.g., java8, java11, java17)

if [ -z "$1" ]; then
  echo "[INFO] Use --delete-existing to delete existing links before installing new ones."
fi
if [ "$1" == "--delete-existing" ]; then
  delete_existing=true
else
  delete_existing=false
fi

# Delete existing links
if [ "$delete_existing" = true ]; then
  for file in "$user_install_dir"/*; do
    # Only delete files in the format java<major_version>
    basename "$file" | grep -qE '^java[0-9]+$' || continue

    # Only delete symlinks
    [ -L "$file" ] || continue

    echo "[INFO] Deleting existing link: $file"
    rm "$file"
  done
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
    echo "[WARNING] No java binary found in $installed_java_dir, skipping."
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
  link_name="$user_install_dir/java$major_version"
  if [ -L "$link_name" ]; then
    echo "[WARNING] Link already exists: $link_name, skipping."
  else
    echo "[INFO] Creating link: $link_name -> $java_binary_path"
    ln -s "$java_binary_path" "$link_name"
  fi
done
