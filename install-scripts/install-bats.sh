#!/usr/bin/env bash

set -euo pipefail

echo "Installing BATS testing framework..."

# Check if BATS is already installed
if command -v bats >/dev/null 2>&1; then
    echo "BATS is already installed: $(bats --version)"
    exit 0
fi

# Create temporary directory
TEMP_DIR=$(mktemp -d)
trap 'rm -rf "$TEMP_DIR"' EXIT

cd "$TEMP_DIR"

# Install BATS core
echo "Installing BATS core..."
git clone https://github.com/bats-core/bats-core.git
cd bats-core
sudo ./install.sh /usr/local
cd ..

# Install BATS helper libraries
echo "Installing BATS helper libraries..."

# bats-support
git clone https://github.com/bats-core/bats-support.git
sudo cp -r bats-support /usr/local/lib/

# bats-assert
git clone https://github.com/bats-core/bats-assert.git
sudo cp -r bats-assert /usr/local/lib/

# bats-file
git clone https://github.com/bats-core/bats-file.git
sudo cp -r bats-file /usr/local/lib/

# Verify installation
if command -v bats >/dev/null 2>&1; then
    echo "BATS installation completed successfully!"
    bats --version
else
    echo "BATS installation failed!" >&2
    exit 1
fi