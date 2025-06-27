#!/bin/bash

# Create a new server directory with configs and utility scripts
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
cd ${SCRIPT_DIR}
source ./common/utils.sh

# Load variables
if [ ! -f "./load_config.sh" ]; then
  echo "[Error] load_config.sh not found in the script directory."
  exit 1
fi
source ./load_config.sh

# Check for required commands
check_prerequisites

print_usage() {
  echo "Usage: create_server.sh <server_alias> <project_version> <java_version> <project: optional, default: paper>"
}

if [ -z "$1" ]; then
  print_usage
  exit 1
else
  server_alias="$1"
fi

if [ -z "$2" ]; then
  print_usage
  exit 1
else
  project_version="$2"
fi

if [ -z "$3" ]; then
  print_usage
  exit 1
else
  java_version="$3"
fi

if [ -z "$4" ]; then
  project="paper"
else
  project="$4"
fi

# test if java version is installed properly
if ! command -v "java$java_version" >/dev/null 2>&1; then
  echo "[ERROR] Java $java_version is not installed. Install Java $java_version first and rerun this script." >&2
  exit 1
fi

project_latest_jar_path="${PAPER_DOWNLOAD_DIR}/${project}/${project_version}/${project}-latest.jar"

# test if project jar is installed
if ! [ -L "$project_latest_jar_path" ]; then
  echo "[ERROR] $project for version $project_version is not installed. Install first and rerun the script."
  exit 1
fi

server_installation_dir="${MINECRAFT_SERVER_DIR}/${server_alias}"

# test if server is not already installed
[ -d "$server_installation_dir" ] && echo "[ERROR] Server with alias '$server_alias' is already installed. Exiting..." && exit 1

echo "[INFO] Installing $project $project_version server '$server_alias' with java version ${java_version}..."

# start installation
mkdir -p "${server_installation_dir}/bin"
cd "$server_installation_dir"
ln -s "$project_latest_jar_path" server.jar
cp "${SCRIPT_DIR}/assets/templates/eula.txt" .
cp "${SCRIPT_DIR}/assets/templates/spigot.yml" .
cp "${SCRIPT_DIR}/assets/templates/startServer.sh.tmpl" bin/startServer.sh

# edit startServer.sh script
echo "Enter maximum RAM usage (Gigabytes):"
read max_ram_usage

sed -i "s|<server_directory>|$server_installation_dir|;s|<server_alias>|$server_alias|;s|<java_version>|$java_version|;s|<gigabytes>|$max_ram_usage|g" bin/startServer.sh
chmod +x bin/startServer.sh

# edit server.properties
public_ip=$(curl -s https://api.ipify.org)
if [ -z "$public_ip" ]; then
  public_ip="127.0.0.1"
fi
read -p "Enter value for 'server-ip' [$public_ip]: " server_ip
echo "server-ip=${server_ip:-$public_ip}" >>server.properties
while IFS="" read -r property; do
  key=$(awk -F= '{ print $1 }' <<<$property)
  value=$(awk -F= '{ print $2 }' <<<$property)
  read -u 3 -p "Enter value for '$key' [$value]: " new_val
  new_val=${new_val:-$value}
  echo "$key=$new_val" >>server.properties
done 3<&0 <"${SCRIPT_DIR}/assets/templates/server.properties.tmpl"

# edit spigot.yml
while IFS="" read -r property; do
  key=$(awk -F: '{ gsub(/ /,""); print $1 }' <<<$property)
  value=$(awk -F: '{ gsub(/ /,""); print $2 }' <<<$property)
  read -u 3 -p "Enter value for 'entity-tracking-range' ($key) [$value]: " new_val
  new_val=${new_val:-$value}
  echo "      $key: $new_val" >>spigot.yml
done 3<&0 <"${SCRIPT_DIR}/assets/templates/spigot.yml.tracking"

echo "[INFO] Server '$server_alias' created successfully at $server_installation_dir"
