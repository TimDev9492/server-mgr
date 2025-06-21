#!/bin/bash

required_commands=("curl" "jq" "which" "awk" "grep" "sed")

# Check if required commands are installed
for cmd in "${required_commands[@]}"; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "[ERROR] $cmd is not installed." >&2
    exit 1
  fi
done
