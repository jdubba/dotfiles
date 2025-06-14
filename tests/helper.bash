#!/usr/bin/env bash
# Helper functions for BATS tests

# Determine the directory where this script is located
TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load bats-support
load_bats_support() {
  # Try loading from the local installation first
  if [ -f "${TESTS_DIR}/lib/bats-support/load.bash" ]; then
    # shellcheck source=./lib/bats-support/load.bash
    source "${TESTS_DIR}/lib/bats-support/load.bash"
    return 0
  fi
  
  # Try loading from the system installation (Homebrew on macOS)
  if [ -f "/opt/homebrew/lib/bats-support/load.bash" ]; then
    # shellcheck source=/dev/null
    source "/opt/homebrew/lib/bats-support/load.bash"
    return 0
  fi
  
  # Try loading from common system paths
  for path in \
    "/usr/local/lib/bats-support" \
    "/usr/lib/bats-support"; do
    if [ -f "${path}/load.bash" ]; then
      # shellcheck source=/dev/null
      source "${path}/load.bash"
      return 0
    fi
  done
  
  echo "Error: Could not find bats-support library" >&2
  return 1
}

# Load bats-assert
load_bats_assert() {
  # Try loading from the local installation first
  if [ -f "${TESTS_DIR}/lib/bats-assert/load.bash" ]; then
    # shellcheck source=./lib/bats-assert/load.bash
    source "${TESTS_DIR}/lib/bats-assert/load.bash"
    return 0
  fi
  
  # Try loading from the system installation (Homebrew on macOS)
  if [ -f "/opt/homebrew/lib/bats-assert/load.bash" ]; then
    # shellcheck source=/dev/null
    source "/opt/homebrew/lib/bats-assert/load.bash"
    return 0
  fi
  
  # Try loading from common system paths
  for path in \
    "/usr/local/lib/bats-assert" \
    "/usr/lib/bats-assert"; do
    if [ -f "${path}/load.bash" ]; then
      # shellcheck source=/dev/null
      source "${path}/load.bash"
      return 0
    fi
  done
  
  echo "Error: Could not find bats-assert library" >&2
  return 1
}

# Load all helpers
load_all_helpers() {
  load_bats_support
  load_bats_assert
}

# Export functions
export -f load_bats_support
export -f load_bats_assert
export -f load_all_helpers
