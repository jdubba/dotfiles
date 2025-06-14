#!/bin/bash
# Main test runner script for dotfiles project

set -e

# Install BATS if not already installed
if [ ! -d "tests/lib/bats-core" ] || [ ! -f "tests/lib/bats-core/bin/bats" ]; then
  echo "BATS not found or incomplete. Installing testing dependencies..."
  ./tests/install_bats.sh
fi

# Verify bats executable exists and is executable
if [ ! -f "tests/lib/bats-core/bin/bats" ]; then
  echo "Error: bats executable not found after installation"
  exit 1
fi

chmod +x tests/lib/bats-core/bin/bats

# Run all tests
echo "Running tests..."
tests/lib/bats-core/bin/bats tests/*.bats

echo "All tests completed."
