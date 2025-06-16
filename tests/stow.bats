#!/usr/bin/env bats

# Load our custom helper that can find libraries in multiple locations
# shellcheck source=./helper.bash
source "$(dirname "$BATS_TEST_FILENAME")/helper.bash"
load_all_helpers

# Setup test environment before each test
setup() {
  # Create a temporary test environment
  export TEST_DIR
  TEST_DIR="$(mktemp -d)"
  export HOME="${TEST_DIR}/home"
  export STOW_DIR="${TEST_DIR}/stow"
  export CONFIG_DIR="${STOW_DIR}/config"
  
  # Set up test structure
  mkdir -p "${HOME}"
  mkdir -p "${CONFIG_DIR}"
  mkdir -p "${CONFIG_DIR}/.config/app"
  
  # Create sample config files
  echo "test content" > "${CONFIG_DIR}/.testrc"
  echo "app config" > "${CONFIG_DIR}/.config/app/settings"
}

# Clean up after each test
teardown() {
  # Clean up test environment
  rm -rf "${TEST_DIR}"
}

@test "stow creates accessible content regardless of symlink structure" {
  # Run stow directly
  run stow -v -d "${STOW_DIR}" -t "${HOME}" config
  assert_success
  
  # Check that content is accessible, regardless of how symlinks are structured
  [ -e "${HOME}/.testrc" ]
  [ -e "${HOME}/.config/app/settings" ]
  
  # Verify content is correct
  assert_equal "$(cat "${HOME}/.testrc")" "test content"
  assert_equal "$(cat "${HOME}/.config/app/settings")" "app config"
}

@test "stow creates symlinks appropriate for the installed version" {
  # Get stow version and print for debugging
  local stow_version
  stow_version=$(stow --version | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
  echo "Detected stow version: $stow_version"
  
  # Run stow
  run stow -v -d "${STOW_DIR}" -t "${HOME}" config
  assert_success
  
  # Check that root level symlink was created (consistent across versions)
  [ -L "${HOME}/.testrc" ]
  
  # For nested directories, focus on functionality rather than implementation
  # Check that the content is accessible and correct, regardless of how it's linked
  [ -e "${HOME}/.config/app/settings" ]
  assert_equal "$(cat "${HOME}/.config/app/settings")" "app config"
  
  # Print additional debugging info about the file structure
  echo "File type for ${HOME}/.config/app/settings:"
  ls -la "${HOME}/.config/app/settings"
  echo "Directory structure:"
  ls -la "${HOME}/.config/"
  ls -la "${HOME}/.config/app/" || echo "app directory not found or not accessible"
}

@test "stow handles conflicts with --adopt" {
  # Create existing files
  mkdir -p "${HOME}/.config/app"
  echo "existing content" > "${HOME}/.testrc"
  echo "existing app config" > "${HOME}/.config/app/settings"
  
  # Run stow with --adopt
  run stow -v --adopt -d "${STOW_DIR}" -t "${HOME}" config
  assert_success
  
  # Check that symlinks were created
  [ -L "${HOME}/.testrc" ]
  [ -L "${HOME}/.config/app/settings" ]
  
  # Check that content was moved to the stow directory
  assert_equal "$(cat "${CONFIG_DIR}/.testrc")" "existing content"
  assert_equal "$(cat "${CONFIG_DIR}/.config/app/settings")" "existing app config"
}

@test "stow handles restow correctly" {
  # First stow
  stow -v -d "${STOW_DIR}" -t "${HOME}" config
  
  # Modify the target file
  echo "modified content" > "${CONFIG_DIR}/.testrc"
  
  # Restow
  run stow -v -R -d "${STOW_DIR}" -t "${HOME}" config
  assert_success
  
  # Check content is correct after restow
  assert_equal "$(cat "${HOME}/.testrc")" "modified content"
}

@test "stow handles delete correctly" {
  # First stow
  stow -v -d "${STOW_DIR}" -t "${HOME}" config
  
  # Delete with stow
  run stow -v -D -d "${STOW_DIR}" -t "${HOME}" config
  assert_success
  
  # Check that symlinks were removed
  [ ! -e "${HOME}/.testrc" ]
  [ ! -e "${HOME}/.config/app/settings" ]
  
  # But the original files still exist
  [ -f "${CONFIG_DIR}/.testrc" ]
  [ -f "${CONFIG_DIR}/.config/app/settings" ]
}
