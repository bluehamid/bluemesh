#!/bin/bash
set -euo pipefail

REPO_URL="https://raw.githubusercontent.com/bluehamid/bluemesh/main"
INSTALL_DIR="/usr/local/bin"
SCRIPT_NAME="bluemesh"

echo "Installing BlueMesh..."

# Check root
if [[ $EUID -ne 0 ]]; then
    echo "Please run as root"
    exit 1
fi

# Download main script
curl -s -L "${REPO_URL}/bluemesh.sh" -o "${INSTALL_DIR}/${SCRIPT_NAME}"
chmod +x "${INSTALL_DIR}/${SCRIPT_NAME}"

# Create symlink
ln -sf "${INSTALL_DIR}/${SCRIPT_NAME}" /usr/bin/bluemesh

echo "✓ BlueMesh installed successfully!"
echo "Run 'bluemesh' to start"
