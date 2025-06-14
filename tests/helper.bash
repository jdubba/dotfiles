#!/usr/bin/env bash
# Helper functions for BATS tests

# Enable debug output
DEBUG=true

# Function to print debug information
debug() {
  if [ "$DEBUG" = true ]; then
    echo "DEBUG: $*" >&2
  fi
}

# Determine the directory where this script is located
TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
debug "BASH_SOURCE[0] = ${BASH_SOURCE[0]}"
debug "TESTS_DIR = $TESTS_DIR"

# Load bats-support
load_bats_support() {
  debug "Attempting to load bats-support..."
  
  # Try loading from the local installation first
  if [ -f "${TESTS_DIR}/lib/bats-support/load.bash" ]; then
    debug "Found bats-support in local installation: ${TESTS_DIR}/lib/bats-support/load.bash"
    # shellcheck source=./lib/bats-support/load.bash
    source "${TESTS_DIR}/lib/bats-support/load.bash"
    debug "Successfully loaded bats-support from local installation"
    return 0
  else
    debug "Local bats-support not found at ${TESTS_DIR}/lib/bats-support/load.bash"
  fi
  
  # Try loading from the system installation (Homebrew on macOS)
  if [ -f "/opt/homebrew/lib/bats-support/load.bash" ]; then
    debug "Found bats-support in Homebrew: /opt/homebrew/lib/bats-support/load.bash"
    # shellcheck source=/dev/null
    source "/opt/homebrew/lib/bats-support/load.bash"
    debug "Successfully loaded bats-support from Homebrew"
    return 0
  else
    debug "Homebrew bats-support not found at /opt/homebrew/lib/bats-support/load.bash"
  fi
  
  # Try loading from common system paths
  for path in \
    "/usr/local/lib/bats-support" \
    "/usr/lib/bats-support"; do
    debug "Checking for bats-support in $path/load.bash"
    if [ -f "${path}/load.bash" ]; then
      debug "Found bats-support in system path: ${path}/load.bash"
      # shellcheck source=/dev/null
      source "${path}/load.bash"
      debug "Successfully loaded bats-support from system path"
      return 0
    fi
  done
  
  # List contents of directories to help with debugging
  debug "Listing contents of ${TESTS_DIR}/lib:"
  ls -la "${TESTS_DIR}/lib" 2>/dev/null || debug "Directory not found"
  
  if [ -d "${TESTS_DIR}/lib/bats-support" ]; then
    debug "Listing contents of ${TESTS_DIR}/lib/bats-support:"
    ls -la "${TESTS_DIR}/lib/bats-support" 2>/dev/null || debug "Directory not found"
  fi
  
  echo "Error: Could not find bats-support library" >&2
  return 1
}

# Load bats-assert
load_bats_assert() {
  debug "Attempting to load bats-assert..."
  
  # Try loading from the local installation first
  if [ -f "${TESTS_DIR}/lib/bats-assert/load.bash" ]; then
    debug "Found bats-assert in local installation: ${TESTS_DIR}/lib/bats-assert/load.bash"
    # shellcheck source=./lib/bats-assert/load.bash
    source "${TESTS_DIR}/lib/bats-assert/load.bash"
    debug "Successfully loaded bats-assert from local installation"
    return 0
  else
    debug "Local bats-assert not found at ${TESTS_DIR}/lib/bats-assert/load.bash"
  fi
  
  # Try loading from the system installation (Homebrew on macOS)
  if [ -f "/opt/homebrew/lib/bats-assert/load.bash" ]; then
    debug "Found bats-assert in Homebrew: /opt/homebrew/lib/bats-assert/load.bash"
    # shellcheck source=/dev/null
    source "/opt/homebrew/lib/bats-assert/load.bash"
    debug "Successfully loaded bats-assert from Homebrew"
    return 0
  else
    debug "Homebrew bats-assert not found at /opt/homebrew/lib/bats-assert/load.bash"
  fi
  
  # Try loading from common system paths
  for path in \
    "/usr/local/lib/bats-assert" \
    "/usr/lib/bats-assert"; do
    debug "Checking for bats-assert in $path/load.bash"
    if [ -f "${path}/load.bash" ]; then
      debug "Found bats-assert in system path: ${path}/load.bash"
      # shellcheck source=/dev/null
      source "${path}/load.bash"
      debug "Successfully loaded bats-assert from system path"
      return 0
    fi
  done
  
  # List contents of directories to help with debugging
  if [ -d "${TESTS_DIR}/lib/bats-assert" ]; then
    debug "Listing contents of ${TESTS_DIR}/lib/bats-assert:"
    ls -la "${TESTS_DIR}/lib/bats-assert" 2>/dev/null || debug "Directory not found"
  fi
  
  echo "Error: Could not find bats-assert library" >&2
  return 1
}

# Load all helpers
load_all_helpers() {
  debug "Starting load_all_helpers..."
  
  # Check if we're running in CI
  if [ -n "$CI" ]; then
    debug "Running in CI environment"
  else
    debug "Running in local environment"
  fi
  
  # Check current directory and environment
  debug "Current directory: $(pwd)"
  debug "BATS_TEST_FILENAME: $BATS_TEST_FILENAME"
  
  # Load the helpers
  load_bats_support
  support_result=$?
  debug "load_bats_support returned: $support_result"
  
  load_bats_assert
  assert_result=$?
  debug "load_bats_assert returned: $assert_result"
  
  # Return success only if both loaded successfully
  if [ $support_result -eq 0 ] && [ $assert_result -eq 0 ]; then
    debug "All helpers loaded successfully"
    return 0
  else
    debug "Failed to load all helpers"
    return 1
  fi
}

# Export functions
export -f debug
export -f load_bats_support
export -f load_bats_assert
export -f load_all_helpers
