#!/usr/bin/env bats

# Load test helpers
load 'lib/bats-support/load'
load 'lib/bats-assert/load'

# Setup test environment before each test
setup() {
  # Create a temporary test directory
  if ! TEST_DIR=$(mktemp -d); then
    echo "Failed to create temp directory" >&2
    return 1
  fi
  
  # Export variables for test
  export HOME="${TEST_DIR}/home"
  export REPO_DIR="${TEST_DIR}/repo"
  
  # Set up test repo structure
  mkdir -p "${HOME}"
  mkdir -p "${REPO_DIR}/config"
  
  # Copy install script to test repo
  cp "$(pwd)/install.sh" "${REPO_DIR}/"
  
  # Create sample config files
  echo "test content" > "${REPO_DIR}/config/.testrc"
  echo "alias ll='ls -la'" > "${REPO_DIR}/config/.bash_aliases"
  
  # Initialize git repo
  cd "${REPO_DIR}" || return 1
  git init -q
  git config --local user.email "test@example.com"
  git config --local user.name "Test User"
  git add .
  git commit -q -m "Initial commit"
}

# Clean up after each test
teardown() {
  # Clean up test environment
  rm -rf "${TEST_DIR}"
}

@test "install script runs without errors" {
  cd "${REPO_DIR}" || skip "Could not change to repo directory"
  run ./install.sh
  assert_success
  assert_output --partial "Configuration files have been successfully linked"
}

@test "install creates symlinks correctly" {
  cd "${REPO_DIR}" || skip "Could not change to repo directory"
  run ./install.sh
  assert_success
  
  # Check that symlinks were created
  [ -L "${HOME}/.testrc" ]
  [ -L "${HOME}/.bash_aliases" ]
  
  # Check that symlinks point to the correct files - using relative path comparison
  TESTRC_LINK=$(readlink "${HOME}/.testrc")
  ALIASES_LINK=$(readlink "${HOME}/.bash_aliases")
  
  # Verify the symlinks point to the right files (allowing for relative paths)
  [ -f "${HOME}/${TESTRC_LINK}" ]
  [ -f "${HOME}/${ALIASES_LINK}" ]
  
  # Verify content is correct
  assert_equal "$(cat "${HOME}/.testrc")" "test content"
  assert_equal "$(cat "${HOME}/.bash_aliases")" "alias ll='ls -la'"
}

@test "install detects uncommitted changes" {
  cd "${REPO_DIR}" || skip "Could not change to repo directory"
  # Create an uncommitted change
  echo "modified content" > "${REPO_DIR}/config/.testrc"
  
  run ./install.sh
  
  # Should fail with error code 1
  assert_failure 1
  assert_output --partial "ERROR: Detected untracked or staged changes in the config folder"
  assert_output --partial "INSTRUCTIONS TO RESOLVE"
}

@test "install preserves existing files with stow adopt" {
  # Create an existing file in home
  echo "existing content" > "${HOME}/.bashrc"
  
  # Add .bashrc to repo
  echo "repo content" > "${REPO_DIR}/config/.bashrc"
  git add config/.bashrc
  git commit -q -m "Add .bashrc"
  
  # Run install
  cd "${REPO_DIR}" || skip "Could not change to repo directory"
  run ./install.sh
  assert_success
  
  # Check that symlink was created
  [ -L "${HOME}/.bashrc" ]
  
  # Verify content is correct after restore
  assert_equal "$(cat "${HOME}/.bashrc")" "repo content"
}

@test "install is idempotent" {
  # Run install once
  cd "${REPO_DIR}" || skip "Could not change to repo directory"
  ./install.sh
  
  # Run install again
  run ./install.sh
  assert_success
  
  # Check that symlinks still exist
  [ -L "${HOME}/.testrc" ]
  
  # Verify content is correct
  assert_equal "$(cat "${HOME}/.testrc")" "test content"
}
