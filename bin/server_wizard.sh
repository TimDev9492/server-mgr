#!/bin/bash

# A gum wrapper for serman.sh

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
cd "${SCRIPT_DIR}/../"
source ./common/utils.sh

# Load variables
if [ ! -f "./load_config.sh" ]; then
  echo "[ERROR] load_config.sh not found in the script directory." >&2
  exit 1
fi
source ./load_config.sh

# Check for required commands
check_prerequisites gum

abort_server_creation() {
  echo "[ERROR] Server creation aborted by user." >&2
  exit 1
}

select_version() {
  local version_selection="$(./papman.sh list-versions paper)"
  [ -n "$version_selection" ] && version_selection+=$'\n'
  version_selection+="other (select version to install)"
  echo "$version_selection" | gum choose \
    --header="Select Minecraft version" \
    --limit=1
}

get_minimum_java_version() {
  local minecraft_version="$1"
  local version_info="$(fetch_api "${PAPER_API_ENDPOINT}/projects/paper/versions/${minecraft_version}")"
  [ $? -ne 0 ] && exit 1
  echo "$version_info" | jq -r '.version.java.version.minimum'
}

get_recommended_java_settings_json_array() {
  local minecraft_version="$1"
  local version_info="$(fetch_api "${PAPER_API_ENDPOINT}/projects/paper/versions/${minecraft_version}")"
  [ $? -ne 0 ] && echo "[]"
  echo "$version_info" | jq -rc '.version.java.flags.recommended'
}

get_system_ram_gb() {
  awk '/MemTotal/ {printf "%.0f", $2 / 1024 / 1024}' /proc/meminfo 2>/dev/null
}

count_values_in_json_object() {
  local json="$1"
  echo "$json" | jq '
    def count_values:
      if (type == "object") or (type == "array") then
        [.[] | count_values] | add
      else
        1
      end;
    count_values
  '
}

server_config_json="{}"

add_to_json_object() {
  local json="$1"
  local key="$2"
  local value="$3"
  echo "$json" | jq --arg key "$key" --arg value "$value" '. + {($key): $value}'
}

add_json_to_json_object() {
  local json="$1"
  local key="$2"
  local value="$3"
  echo "$json" | jq --arg key "$key" --argjson value "$value" '. + {($key): $value}'
}

gum_enter_config_value() {
  local config_file="$1"
  local config_key="$2"
  local config_default_value="$3"
  local progress_indicator="$4"
  local formatted_progress_indicator=""
  if [ -n "$progress_indicator" ]; then
    formatted_progress_indicator=" $(colorize_output "$progress_indicator" "blue")"
  fi
  local gum_header="[$(colorize_output "$config_file" "green")${formatted_progress_indicator}] Enter value for option '$(colorize_output "$config_key" "yellow")':"
  local config_value
  config_value="$(
    gum input \
      --header="$gum_header" \
      --placeholder="Enter value for '$config_key'..." \
      --value="$config_default_value"
  )"
  [ $? -eq 130 ] && return 130
  echo "$config_value"
}

gum_prompt_json_values() {
  local return_delimiter="|"
  local prev_status="$1"
  local json="$2"
  local config_name="$3"
  local parent_key="$4"
  local total_value_count="$5"
  local current_value_count="$6"
  local is_recursive_call="$7"
  [ "$prev_status" -eq 130 ] && return 130
  if [ -z "$total_value_count" ]; then
    total_value_count="$(count_values_in_json_object "$json")"
  fi
  if [ -z "$current_value_count" ]; then
    current_value_count=1
  fi
  if [ -z "$is_recursive_call" ]; then
    is_recursive_call=false
  fi
  local output_json="{}"
  local nested_arrays="$(echo "$json" | jq -r 'with_entries(select(.value | type == "array"))')"
  local nested_objects="$(echo "$json" | jq -r 'with_entries(select(.value | type == "object"))')"
  local prompts="$(echo "$json" | jq -r 'with_entries(select(.value | (type != "object" and type != "array")))')"
  local nested_array_count="$(echo "$nested_arrays" | jq 'length')"
  local nested_object_count="$(echo "$nested_objects" | jq 'length')"
  local prompt_count="$(echo "$prompts" | jq 'length')"
  # run prompts for values
  if [ "$prompt_count" -gt 0 ]; then
    local keys=()
    local values=()
    json_object_to_key_value_pairs keys values "$prompts"
    [ $? -ne 0 ] && return 1
    local i
    for i in "${!keys[@]}"; do
      local key="${keys[$i]}"
      local value="${values[$i]}"
      local formatted_key_name
      if [ -n "$parent_key" ]; then
        formatted_key_name="${parent_key}.${key}"
      else
        formatted_key_name="$key"
      fi
      local entered_value
      entered_value="$(gum_enter_config_value "${config_name}" "$formatted_key_name" "$value" "(${current_value_count}/${total_value_count})")"
      [ $? -eq 130 ] && return 130
      output_json="$(add_to_json_object "$output_json" "$key" "$entered_value")"
      ((current_value_count++))
    done
  fi
  # prompt nested objects recursively
  if [ "$nested_object_count" -gt 0 ]; then
    local keys=()
    local values=()
    json_object_to_key_value_pairs keys values "$nested_objects"
    [ $? -ne 0 ] && return 1
    local i
    for i in "${!keys[@]}"; do
      local key="${keys[$i]}"
      local value="${values[$i]}"
      local recursive_return_value
      recursive_return_value="$(gum_prompt_json_values "$prev_status" "$value" "$config_name" "$key" "$total_value_count" "$current_value_count" "true")"
      [ $? -eq 130 ] && return 130
      local updated_current_value="${recursive_return_value%%"$return_delimiter"*}"
      local nested_output_json="${recursive_return_value#*"$return_delimiter"}"
      current_value_count="$updated_current_value"
      output_json="$(add_json_to_json_object "$output_json" "$key" "$nested_output_json")"
    done
  fi
  if [ "$nested_array_count" -gt 0 ]; then
    echo "[WARNING] Skipping $nested_array_count nested arrays..." >&2
  fi

  if $is_recursive_call; then
    echo "${current_value_count}${return_delimiter}${output_json}"
    return 0
  fi
  echo "$output_json"
  return 0
}

alias_prompt_header="$(colorize_output "Give your server a name" "green")"
while true; do
  server_alias="$(
    gum input \
      --header="$alias_prompt_header" \
      --placeholder="Type a server alias..." \
      --value=""
  )"
  [ $? -eq 130 ] && abort_server_creation
  if ! is_valid_alias "$server_alias"; then
    alias_prompt_header="$(colorize_output "Invalid alias, enter a new one" "yellow")"
    continue
  fi
  existing_alias_count="$(./serman.sh list | grep -c "^$server_alias$")"
  if [ "$existing_alias_count" -gt 0 ]; then
    alias_prompt_header="$(colorize_output "Server" "yellow") $(colorize_output "$server_alias" "red") $(colorize_output "already exists, enter a new one" "yellow")"
    continue
  fi
  break
done
server_config_json="$(add_to_json_object "$server_config_json" "server_alias" "$server_alias")"

while true; do
  minecraft_version="$(select_version)"
  [ $? -eq 130 ] && abort_server_creation
  if [[ "$minecraft_version" == other* ]]; then
    ./bin/update_helper.sh
  else
    break
  fi
done
server_config_json="$(echo "$server_config_json" | jq --arg minecraft_version "$minecraft_version" '. + {minecraft_version: $minecraft_version}')"

minimum_java_version="$(get_minimum_java_version "$minecraft_version")"
if [ $? -ne 1 ] && [ -n "$minimum_java_version" ]; then
  minimum_java_version="$(colorize_output "$minimum_java_version" "green")"
else
  echo "[ERROR] Failed to get minimum Java version for Minecraft $minecraft_version." >&2
  minimum_java_version="$(colorize_output "unknown" "red")"
fi

installed_java_links="$(./javman.sh list)"
if [ -z "$installed_java_links" ]; then
  echo "[ERROR] No Java versions installed. Please install and link a Java version first using javman.sh install" >&2
  exit 1
fi

java_version="$(
  echo "$installed_java_links" | gum choose \
    --header="Select Java version $(colorize_output "(minimum: " "yellow")$minimum_java_version$(colorize_output ")" "yellow")" \
    --limit=1
)"
[ $? -eq 130 ] && abort_server_creation
server_config_json="$(add_to_json_object "$server_config_json" "java_version" "$java_version")"

gum confirm \
  "Do you agree to the Minecraft EULA? (https://account.mojang.com/documents/minecraft_eula)" \
  --affirmative="Agree" \
  --negative="Disagree" \
  --default=1 || abort_server_creation
eula_agree_time="$(date -u)"

# Select java flags
recommended_java_flags="$(get_recommended_java_settings_json_array "$minecraft_version")"

flag_count="$(echo "$recommended_java_flags" | jq 'length')"
java_flags_array="[]"
if [ "$flag_count" -gt 0 ]; then
  selected_flags="$(
    echo "$recommended_java_flags" | jq -r '.[]' | gum choose \
      --header="Select recommended Java flags" \
      --selected='*' \
      --no-limit
  )"
  [ $? -eq 130 ] && abort_server_creation
  java_flags_array="$(echo "$selected_flags" | jq -Rsrc 'split("\n") | map(select(length > 0))')"
fi
system_ram_gb="$(get_system_ram_gb)"
if [ -z "$system_ram_gb" ]; then
  recommended_ram_gb=4
else
  recommended_ram_gb=$((system_ram_gb / 2))
  [ $recommended_ram_gb -lt 1 ] && recommended_ram_gb=1
fi
max_ram_gb="$(
  gum input \
    --header="Enter maximum RAM usage for the server" \
    --placeholder="For example: 4g, 512m, 1024k" \
    --value="${recommended_ram_gb}g"
)"
[ $? -eq 130 ] && abort_server_creation
java_flags_array="$(echo "$java_flags_array" | jq -rc --arg max_ram "$max_ram_gb" --arg initial_ram "512m" '. + ["-Xmx" + $max_ram, "-Xms" + $initial_ram]')"
server_config_json="$(add_json_to_json_object "$server_config_json" "java_flags" "$java_flags_array")"

# Configure server.properties
server_property_template="$(grep -v -e '^$' -e '^\s*#' "${SCRIPT_DIR}/assets/templates/server.properties.tmpl")"
server_property_count="$(echo "$server_property_template" | wc -l)"
current_property_count=1
server_properties_json="{}"
while IFS='' read -r property_template_line; do
  # skip empty lines and commennts
  [[ -z "$property_template_line" || "$property_template_line" =~ ^# ]] && continue
  property_key="$(awk -F= '{print $1}' <<<"$property_template_line")"
  property_default_value="$(awk -F= '{print $2}' <<<"$property_template_line")"
  # add extra case for ip
  if [ "$property_key" == "server-ip" ]; then
    public_ip="$(curl -s https://api.ipify.org 2>/dev/null)"
    [ -n "$public_ip" ] && property_default_value="$public_ip"
  fi
  property_value="$(gum_enter_config_value "server.properties" "$property_key" "$property_default_value" "(${current_property_count}/${server_property_count})")"
  [ $? -eq 130 ] && abort_server_creation
  if [ -z "$property_value" ]; then
    echo "[WARNING] Received empty value for '$property_key', using default '$property_default_value'" >&2
    property_value="$property_default_value"
  fi
  server_properties_json="$(add_to_json_object "$server_properties_json" "$property_key" "$property_value")"
  ((current_property_count++))
done <<<"$server_property_template"
server_config_json="$(add_json_to_json_object "$server_config_json" "server.properties" "$server_properties_json")"

# Configure spigot.yml
spigot_yml_template_json="$(grep -v '^$' "${SCRIPT_DIR}/assets/templates/spigot.yml.template.json")"
spigot_yml_json="$(gum_prompt_json_values 0 "$spigot_yml_template_json" "spigot.yml")"
[ $? -eq 130 ] && abort_server_creation
server_config_json="$(add_json_to_json_object "$server_config_json" "spigot.yml" "$spigot_yml_json")"

echo "$server_config_json" | jq .

exit 0
