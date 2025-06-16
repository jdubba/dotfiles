#!/usr/bin/env bash
#
# Git utility functions for the dotfiles utility
#

# Check if we're in a git repository
check_git_repo() {
  local repo_dir="$1"
  
  cd "$repo_dir" || return 1
  
  if [[ ! -d .git ]]; then
    echo "Error: '$repo_dir' is not a git repository."
    return 1
  fi
  
  return 0
}

# Check if git is installed
check_git() {
  if ! command -v git &> /dev/null; then
    echo "Error: Git is not installed."
    echo "Please install git using your package manager."
    return 1
  fi
  return 0
}

# Add specific files to git staging area
git_add_files() {
  local repo_dir="$1"
  shift
  local files=("$@")
  
  cd "$repo_dir" || return 1
  
  for file in "${files[@]}"; do
    if [[ -e "$file" ]]; then
      echo "Adding $file to git staging area..."
      if ! git add "$file"; then
        echo "Error: Failed to add $file to git."
        return 1
      fi
    else
      echo "Warning: File $file does not exist, skipping."
    fi
  done
  
  return 0
}

# Commit staged changes with a specific message
git_commit_changes() {
  local repo_dir="$1"
  local commit_message="$2"
  
  cd "$repo_dir" || return 1
  
  # Check if there are staged changes
  if [[ -z $(git diff --cached --name-only) ]]; then
    echo "No staged changes to commit."
    return 0
  fi
  
  echo "Committing changes..."
  if ! git commit -m "$commit_message"; then
    echo "Error: Failed to commit changes."
    return 1
  fi
  
  echo "Changes committed successfully."
  return 0
}

# Push changes to remote repository
git_push_changes() {
  local repo_dir="$1"
  
  cd "$repo_dir" || return 1
  
  # Check if we have a remote configured
  if ! git remote get-url origin &> /dev/null; then
    echo "Warning: No remote 'origin' configured. Skipping push."
    return 0
  fi
  
  echo "Pushing changes to remote repository..."
  if ! git push; then
    echo "Error: Failed to push changes to remote repository."
    echo "You may need to push manually later."
    return 1
  fi
  
  echo "Changes pushed successfully."
  return 0
}

# Get the relative path of a file within the repository
get_relative_path() {
  local repo_dir="$1"
  local file_path="$2"
  
  cd "$repo_dir" || return 1
  
  # Use git to get the relative path if possible
  if [[ -e "$file_path" ]]; then
    realpath --relative-to="$repo_dir" "$file_path"
  else
    echo "Error: File $file_path does not exist."
    return 1
  fi
}

# Check if there are any uncommitted changes in the repository
has_uncommitted_changes() {
  local repo_dir="$1"
  
  cd "$repo_dir" || return 1
  
  # Check for any changes (staged or unstaged)
  if [[ -n $(git status --porcelain) ]]; then
    return 0  # Has changes
  else
    return 1  # No changes
  fi
}
