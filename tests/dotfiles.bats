#!/usr/bin/env bats

# Load our custom helper that can find libraries in multiple locations
# shellcheck source=./helper.bash
source "$(dirname "$BATS_TEST_FILENAME")/helper.bash"
load_all_helpers

# Setup test environment before each test
setup() {
  # Create a temporary test directory
  if ! TEST_DIR=$(mktemp -d); then
    echo "Failed to create temp directory" >&2
    return 1
  fi
  
  # Store the project root directory
  export PROJECT_ROOT
  PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  
  # Export variables for test
  export HOME="${TEST_DIR}/home"
  export REPO_DIR="${TEST_DIR}/repo"
  export CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles"
  
  # Set up test repo structure
  mkdir -p "${HOME}"
  mkdir -p "${HOME}/.local/bin"
  mkdir -p "${HOME}/.local/share/dotfiles/lib"
  mkdir -p "${HOME}/.local/share/dotfiles/commands"
  mkdir -p "${REPO_DIR}/config"
  mkdir -p "${CONFIG_DIR}"
  
  # Copy dotfiles binary to test home directory
  cp "${PROJECT_ROOT}/bin/dotfiles" "${HOME}/.local/bin/"
  chmod +x "${HOME}/.local/bin/dotfiles"
  
  # Copy library files to test home directory
  cp "${PROJECT_ROOT}/src/lib/"*.sh "${HOME}/.local/share/dotfiles/lib/"
  cp "${PROJECT_ROOT}/src/commands/"*.sh "${HOME}/.local/share/dotfiles/commands/"
  chmod +x "${HOME}/.local/share/dotfiles/lib/"*.sh
  chmod +x "${HOME}/.local/share/dotfiles/commands/"*.sh
  
  # Create sample config files in the repo
  echo "test content" > "${REPO_DIR}/config/.testrc"
  echo "alias ll='ls -la'" > "${REPO_DIR}/config/.bash_aliases"
  
  # Initialize git repo
  cd "${REPO_DIR}" || return 1
  git init -q
  git config --local user.email "test@example.com"
  git config --local user.name "Test User"
  git add .
  git commit -q -m "Initial commit"
  
  # Create config file for dotfiles
  cat > "${CONFIG_DIR}/config.toml" << EOF
# Dotfiles configuration

# Path to the dotfiles repository
repository_path = "${REPO_DIR}"

# Default stow directory within the repository
stow_directory = "config"

# Target directory (defaults to $HOME)
target_directory = "${HOME}"
EOF
}

# Clean up after each test
teardown() {
  # Clean up test environment
  rm -rf "${TEST_DIR}"
}

@test "dotfiles help command shows usage information" {
  PATH="${HOME}/.local/bin:$PATH"
  run dotfiles help
  assert_success
  assert_output --partial "Usage:"
  assert_output --partial "Commands:"
  assert_output --partial "install"
}

@test "dotfiles --help option shows usage information" {
  PATH="${HOME}/.local/bin:$PATH"
  run dotfiles --help
  assert_success
  assert_output --partial "Usage:"
  assert_output --partial "Commands:"
  assert_output --partial "install"
}

@test "dotfiles -h option shows usage information" {
  PATH="${HOME}/.local/bin:$PATH"
  run dotfiles -h
  assert_success
  assert_output --partial "Usage:"
  assert_output --partial "Commands:"
  assert_output --partial "install"
}

@test "dotfiles version command shows version information" {
  PATH="${HOME}/.local/bin:$PATH"
  run dotfiles version
  assert_success
  assert_output --partial "dotfiles version"
}

@test "dotfiles --version option shows version information" {
  PATH="${HOME}/.local/bin:$PATH"
  run dotfiles --version
  assert_success
  assert_output --partial "dotfiles version"
}

@test "dotfiles -v option shows version information" {
  PATH="${HOME}/.local/bin:$PATH"
  run dotfiles -v
  assert_success
  assert_output --partial "dotfiles version"
}

@test "dotfiles handles unknown commands gracefully" {
  PATH="${HOME}/.local/bin:$PATH"
  run dotfiles unknown-command
  assert_failure
  assert_output --partial "Unknown command"
}

@test "dotfiles handles unknown options gracefully" {
  PATH="${HOME}/.local/bin:$PATH"
  run dotfiles --unknown-option
  assert_failure
  assert_output --partial "Unknown option"
}

@test "dotfiles install command runs without errors" {
  PATH="${HOME}/.local/bin:$PATH"
  run dotfiles install
  assert_success
  assert_output --partial "Configuration files have been successfully linked"
}

@test "dotfiles install creates symlinks correctly" {
  PATH="${HOME}/.local/bin:$PATH"
  run dotfiles install
  assert_success
  
  # Check that symlinks were created
  [ -L "${HOME}/.testrc" ]
  [ -L "${HOME}/.bash_aliases" ]
  
  # Verify content is correct
  assert_equal "$(cat "${HOME}/.testrc")" "test content"
  assert_equal "$(cat "${HOME}/.bash_aliases")" "alias ll='ls -la'"
}

@test "dotfiles install detects uncommitted changes" {
  PATH="${HOME}/.local/bin:$PATH"
  # Create an uncommitted change
  echo "modified content" > "${REPO_DIR}/config/.testrc"
  
  run dotfiles install
  
  # Should fail with error code 1
  assert_failure
  assert_output --partial "ERROR: Detected untracked or staged changes"
}

@test "dotfiles install preserves existing files with stow adopt" {
  PATH="${HOME}/.local/bin:$PATH"
  # Create an existing file in home
  echo "existing content" > "${HOME}/.bashrc"
  
  # Add .bashrc to repo
  echo "repo content" > "${REPO_DIR}/config/.bashrc"
  cd "${REPO_DIR}" || skip "Could not change to repo directory"
  git add config/.bashrc
  git commit -q -m "Add .bashrc"
  
  # Run dotfiles install
  run dotfiles install
  assert_success
  
  # Check that symlink was created
  [ -L "${HOME}/.bashrc" ]
  
  # Verify content is correct after restore
  assert_equal "$(cat "${HOME}/.bashrc")" "repo content"
}

@test "dotfiles install is idempotent" {
  PATH="${HOME}/.local/bin:$PATH"
  # Run install once
  dotfiles install
  
  # Run install again
  run dotfiles install
  assert_success
  
  # Check that symlinks still exist
  [ -L "${HOME}/.testrc" ]
  
  # Verify content is correct
  assert_equal "$(cat "${HOME}/.testrc")" "test content"
}