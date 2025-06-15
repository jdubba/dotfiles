#!/usr/bin/env bash
#
# Install command implementation for the dotfiles utility
#

# Default config file location (will be overridden by the value from main script)
: "${CONFIG_FILE:=${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles/config.toml}"

# Function to run the install command
run_install() {
  # Ensure we have valid configuration
  if [[ -z "$DF_REPOSITORY_PATH" ]]; then
    echo "Error: Repository path is not set in the configuration."
    echo "Please ensure your config file at $CONFIG_FILE is properly set up."
    return 1
  fi
  
  # Ensure stow is installed
  if ! check_stow; then
    return 1
  fi
  
  # Change to repository directory
  cd "$DF_REPOSITORY_PATH" || {
    echo "Error: Failed to change directory to $DF_REPOSITORY_PATH"
    return 1
  }
  
  # Check for uncommitted changes
  if ! check_uncommitted_changes "$DF_REPOSITORY_PATH" "$DF_STOW_DIRECTORY"; then
    return 1
  fi
  
  # Run stow to create symlinks
  if ! run_stow "$DF_REPOSITORY_PATH" "$DF_STOW_DIRECTORY" "$DF_TARGET_DIRECTORY"; then
    return 1
  fi
  
  return 0
}