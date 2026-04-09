#!/bin/bash

# Usage: ./install_packages.sh "pkg1 pkg2 pkg3"

if [[ $# -eq 0 ]]; then
  echo "Usage: $0 \"package1 package2 package3\""
  exit 1
fi

PACKAGES=($1)
MISSING=()
TO_INSTALL=()

echo "Updating repositories..."
apk update
echo "Checking packages..."

for pkg in "${PACKAGES[@]}"; do
  if apk info "$pkg" &>/dev/null; then
    TO_INSTALL+=("$pkg")
  else
    echo "WARNING: Package '$pkg' does not exist in the repository — skipping."
    MISSING+=("$pkg")
  fi
done

if [[ ${#TO_INSTALL[@]} -gt 0 ]]; then
  echo ""
  echo "Installing: ${TO_INSTALL[*]}"
  apk add "${TO_INSTALL[@]}"
else
  echo "No valid packages to install."
fi

if [[ ${#MISSING[@]} -gt 0 ]]; then
  echo ""
  echo "Skipped (not found): ${MISSING[*]}"
fi

