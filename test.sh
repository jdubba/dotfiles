#!/bin/bash
# Main test runner script for dotfiles project

set -e

# Function to find a working bats executable
find_bats() {
  # Check if system bats is available
  if command -v bats &>/dev/null; then
    # Print info message to stderr so it doesn't affect the return value
    echo "Using system bats: $(command -v bats)" >&2
    command -v bats
    return 0
  fi
  
  # Check if our local bats is available
  if [ -f "tests/lib/bats-core/bin/bats" ]; then
    # Print info message to stderr
    echo "Using local bats: $(pwd)/tests/lib/bats-core/bin/bats" >&2
    echo "$(pwd)/tests/lib/bats-core/bin/bats"
    return 0
  fi
  
  # Not found
  echo ""
  return 1
}

# Install BATS if not already installed
if [ ! -d "tests/lib/bats-core" ] || [ ! -f "tests/lib/bats-core/bin/bats" ]; then
  echo "BATS not found or incomplete. Installing testing dependencies..."
  ./tests/install_bats.sh
fi

# Find a working bats executable
BATS_EXECUTABLE=$(find_bats)

if [ -z "$BATS_EXECUTABLE" ]; then
  echo "Error: Could not find a working bats executable"
  echo "Checking system path..."
  which bats || echo "bats not found in PATH"
  echo "Checking local installation..."
  ls -la tests/lib/bats-core || echo "bats-core directory not found"
  if [ -d "tests/lib/bats-core" ]; then
    ls -la tests/lib/bats-core/bin || echo "bin directory not found"
  fi
  exit 1
fi

# Make sure it's executable
chmod +x "$BATS_EXECUTABLE" 2>/dev/null || true

# Run all tests
echo "Running tests with $BATS_EXECUTABLE..."
"$BATS_EXECUTABLE" tests/*.bats

echo "All tests completed."
