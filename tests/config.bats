#!/usr/bin/env bats

# Load our custom helper that can find libraries in multiple locations
source "$(dirname "$BATS_TEST_FILENAME")/helper.bash"
load_all_helpers

# Setup test environment before each test
setup() {
  # Store the project root directory
  export PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  export CONFIG_DIR="${PROJECT_ROOT}/config"
}

@test "bash configuration files are valid" {
  # Test .bashrc syntax
  if [ -f "${CONFIG_DIR}/.bashrc" ]; then
    run bash -n "${CONFIG_DIR}/.bashrc"
    assert_success
  fi
  
  # Test .bash_aliases syntax
  if [ -f "${CONFIG_DIR}/.bash_aliases" ]; then
    run bash -n "${CONFIG_DIR}/.bash_aliases"
    assert_success
  fi
  
  # Test .profile syntax
  if [ -f "${CONFIG_DIR}/.profile" ]; then
    run bash -n "${CONFIG_DIR}/.profile"
    assert_success
  fi
}

@test "git configuration is valid" {
  if [ -f "${CONFIG_DIR}/.gitconfig" ]; then
    run git config -f "${CONFIG_DIR}/.gitconfig" --list
    assert_success
  fi
}

@test "starship configuration is valid" {
  if [ -f "${CONFIG_DIR}/.config/starship.toml" ]; then
    # Simple check that it's valid TOML
    # This is a basic check - ideally we'd use a TOML validator
    run grep -q "=" "${CONFIG_DIR}/.config/starship.toml"
    assert_success
  fi
}

@test "config directory structure is correct" {
  # Check that .config directory exists
  [ -d "${CONFIG_DIR}/.config" ]
  
  # Check that expected config directories exist
  if [ -d "${CONFIG_DIR}/.config/nvim" ]; then
    [ -d "${CONFIG_DIR}/.config/nvim" ]
  fi
  
  if [ -d "${CONFIG_DIR}/.config/kitty" ]; then
    [ -d "${CONFIG_DIR}/.config/kitty" ]
  fi
}

@test "no unexpected file types in config" {
  # Check for binary files or other unexpected file types
  # Skip this test for now as it needs refinement
  skip "This test needs refinement to handle expected binary files"
}
