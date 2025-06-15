#!/usr/bin/env bash
#
# GNU Stow utility functions for the dotfiles utility
#

# Check if stow is installed
check_stow() {
  if ! command -v stow &> /dev/null; then
    echo "Error: GNU Stow is not installed."
    echo "Please install it using your package manager."
    echo "For example:"
    echo "  - Debian/Ubuntu: sudo apt install stow"
    echo "  - Fedora: sudo dnf install stow"
    echo "  - Arch Linux: sudo pacman -S stow"
    echo "  - macOS: brew install stow"
    return 1
  fi
  return 0
}

# Check for uncommitted changes in the stow directory
check_uncommitted_changes() {
  local repo_dir="$1"
  local stow_dir="$2"
  
  # Change to repository directory
  cd "$repo_dir" || return 1
  
  # Check if this is a git repository
  if [[ ! -d .git ]]; then
    echo "Warning: Not a git repository, skipping uncommitted changes check."
    return 0
  fi
  
  # Check for uncommitted changes in the stow directory
  if [[ -n $(git status --porcelain "$stow_dir/") ]]; then
    echo "ERROR: Detected untracked or staged changes in the $stow_dir folder."
    echo ""
    echo "The following files have changes:"
    git status --porcelain "$stow_dir/"
    echo ""
    echo "INSTRUCTIONS TO RESOLVE:"
    echo "1. Either commit your changes: git add $stow_dir/ && git commit -m 'Update config files'"
    echo "2. Or discard your changes: git restore $stow_dir/ && git clean -fd $stow_dir/"
    echo ""
    echo "After resolving the changes, run this command again."
    return 1
  fi
  
  echo "No pending changes detected in $stow_dir folder. Proceeding with stow..."
  return 0
}

# Run stow to create symlinks
run_stow() {
  local repo_dir="$1"
  local stow_dir="$2"
  local target_dir="$3"
  
  # Check if directories exist
  if [[ ! -d "$repo_dir/$stow_dir" ]]; then
    echo "Error: Stow directory '$repo_dir/$stow_dir' does not exist."
    return 1
  fi
  
  # Create target directory if it doesn't exist
  mkdir -p "$target_dir"
  
  # Run stow with adopt flag and handle errors
  echo "Linking dotfiles from $repo_dir/$stow_dir to $target_dir..."
  if ! stow -v --adopt -d "$repo_dir" -t "$target_dir" "$stow_dir"; then
    echo "Error: Failed to run stow."
    return 1
  fi
  
  # Only restore the stow directory, preserving other changes
  if [[ -d "$repo_dir/.git" ]]; then
    cd "$repo_dir" || return 1
    git restore "$stow_dir/"
    echo "Restored any changes that might have been adopted during the process."
  fi
  
  echo "Configuration files have been successfully linked."
  return 0
}