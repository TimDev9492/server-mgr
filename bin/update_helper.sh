#!/bin/bash

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
cd "${SCRIPT_DIR}/../"
source ./common/utils.sh

# Load variables
if [ ! -f "./variables.sh" ]; then
  echo "[ERROR] variables.sh not found in the script directory." >&2
  exit 1
fi
source ./variables.sh

# Check for required commands
check_prerequisites gum

select_project() {
  local projects=$(fetch_api "${PAPER_API_ENDPOINT}/projects" | jq -rc '.projects[]')
  if [ -z "$projects" ]; then
    echo "[ERROR] No projects found in the API response." >&2
    exit 1
  fi
  gum filter --limit 1 \
    --header "Select a project:" \
    --select-if-one \
    $projects
}

select_operation() {
  local operations=("install" "update")
  local operation=$(gum choose \
    --header "What do you want to do?" \
    --limit=1 \
    --select-if-one \
    "${operations[@]}")

  echo "$operation"
}

select_version() {
  local project=$1
  if [ -z "$project" ]; then exit 1; fi

  local versions=$(fetch_api "${PAPER_API_ENDPOINT}/projects/${project}" | jq -rc ".versions[]")
  local version=$(gum filter --limit 1 \
    --header "Select version to update:" \
    --select-if-one \
    $versions)
  if [ -z "$version" ]; then
    echo "[ERROR] No version selected." >&2
    exit 1
  fi
  echo "$version"
}

select_build() {
  local project=$1
  local version=$2
  local select_latest=$3
  [ -z "$3" ] && select_latest="false" || select_latest=$(echo "$3" | tr '[:upper:]' '[:lower:]')

  if [ -z "$project" ] || [ -z "$version" ]; then exit 1; fi

  local builds_by_channel=$(fetch_api "${PAPER_API_ENDPOINT}/projects/${project}/versions/${version}/builds" |
    jq -r '.builds | sort_by(.channel) | group_by(.channel) | map({ (.[0].channel): map(.build) }) | add')

  if [ -z "$builds_by_channel" ]; then
    echo "[ERROR] No builds found for project '$project' and version '$version'." >&2
    exit 1
  fi

  local channels=$(echo "$builds_by_channel" | jq -r 'keys[]' | sort -du)
  local channel=$(gum filter --limit 1 \
    --header "Select channel (version $version):" \
    --select-if-one \
    $channels)

  if [ -z "$channel" ]; then
    echo "[ERROR] No channel selected." >&2
    exit 1
  fi

  local builds=$(echo "$builds_by_channel" | jq -r ".\"$channel\"[]" | sort -nur)

  if [ "$select_latest" == "true" ]; then
    local build=$(echo "$builds" | head -n1)
    echo $build
    exit 0
  fi

  gum confirm "Download latest build (channel: $channel)?"
  local confirmation_result="$?"
  if [ "$confirmation_result" -eq 0 ]; then
    local build=$(echo "$builds" | head -n1)
  elif [ "$confirmation_result" -eq 1 ]; then
    local build=$(gum filter --limit 1 \
      --header "Select build for channel '$channel' (version $version):" \
      --select-if-one \
      $builds)
  else
    echo "[ERROR] Confirmation failed with code $confirmation_result" >&2
    exit 1
  fi

  echo $build
}

project=$(select_project)
operation=$(select_operation)

if [ -z "$project" ]; then
  echo "[ERROR] No project selected, exiting..." >&2
  exit 1
fi

case "$operation" in
install)
  version=$(select_version "$project")
  build=$(select_build "$project" "$version")

  # install the selected build
  gum spin --show-output --spinner="points" --title "Installing $project $version build $build" -- bash -c '
    source ./papman.sh
  ' _ "install" "$project" "$version" "$build"
  ;;
update)
  installed_versions=$(bash -c "source ./papman.sh" _ "list-versions" "$project")
  version_to_update=$(gum choose \
    --header "Select version(s) to update:" \
    --no-limit \
    $installed_versions)

  declare -a updates=()
  version_build_delimiter="|"

  for version in $version_to_update; do
    # trigger select_build to let the user select the correct channel
    build=$(select_build "$project" "$version" "true")

    if [ -z "$build" ]; then
      echo "[ERROR] No build selected, exiting..." >&2
      exit 1
    fi

    installed_builds=$(bash -c "source ./papman.sh" _ "list-builds" "$project" "$version")
    latest_installed_build=$(echo "$installed_builds" | sort -nr | head -n1)
    if [ -n "$latest_installed_build" ] && [ "$build" -le "$latest_installed_build" ]; then
      echo "[INFO] Newest build is already installed for version $version, skipping update." >&2
      continue
    fi

    updates+=("${version}${version_build_delimiter}${build}")
  done

  if [ ${#updates[@]} -eq 0 ]; then
    echo "[INFO] Nothing to update." >&2
    exit 0
  fi

  update_format_string=""
  for update in "${updates[@]}"; do
    IFS="$version_build_delimiter" read -r version build <<<"$update"
    update_format_string+=$(printf -- "- %-8s (build %s)\\\n" "$version" "$build")
  done

  gum confirm "$(echo -e "Update the following versions?\n$update_format_string")" \
    --affirmative="Apply" --negative="Cancel" || {
    echo "[INFO] Operation cancelled." >&2
    exit 0
  }

  # update the selected versions
  for update in "${updates[@]}"; do
    IFS="$version_build_delimiter" read -r version build <<<"$update"
    gum spin --show-output --spinner="points" --title "Updating $project $version (installing build $build)" -- bash -c '
      source ./papman.sh
    ' _ "install" "$project" "$version" "$build"
  done

  echo "[INFO] Update completed successfully." >&2
  exit 0
  ;;
*)
  echo "[ERROR] Unknown operation: $operation" >&2
  exit 1
  ;;
esac
