#!/bin/bash
# Main test runner script for dotfiles project

set -e

# Install BATS if not already installed
if [ ! -d "tests/lib/bats-core" ]; then
  echo "BATS not found. Installing testing dependencies..."
  ./tests/install_bats.sh
fi

# Run all tests
echo "Running tests..."
tests/lib/bats-core/bin/bats tests/*.bats

echo "All tests completed."
