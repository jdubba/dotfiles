#!/usr/bin/env bash
#
# Add command implementation for the dotfiles utility
#

# Source git library functions
# shellcheck source=../lib/git.sh
source "$LIB_DIR/git.sh"

# Function to validate that a path is within the managed directory tree
validate_path_in_tree() {
  local target_path="$1"
  local managed_root="$2"
  
  # Convert both paths to absolute paths
  local abs_target
  local abs_managed
  
  abs_target=$(realpath "$target_path" 2>/dev/null) || {
    echo "Error: Cannot resolve path '$target_path'. Please ensure the file or directory exists."
    return 1
  }
  
  abs_managed=$(realpath "$managed_root" 2>/dev/null) || {
    echo "Error: Cannot resolve managed directory '$managed_root'."
    return 1
  }
  
  # Check if target path starts with managed root path
  if [[ "$abs_target" == "$abs_managed"/* ]] || [[ "$abs_target" == "$abs_managed" ]]; then
    return 0
  else
    echo "Error: The requested file or directory is outside the managed directory tree."
    echo ""
    echo "DETAILS:"
    echo "  Requested path: $abs_target"
    echo "  Managed root:   $abs_managed"
    echo ""
    echo "EXPLANATION:"
    echo "The dotfiles utility can only manage files and directories that are within"
    echo "the target directory tree (typically your home directory). This restriction"
    echo "ensures that:"
    echo "  - Symbolic links are created in the correct locations"
    echo "  - File permissions and ownership are preserved"
    echo "  - The configuration remains portable across different systems"
    echo ""
    echo "SOLUTION:"
    echo "Please specify a file or directory that is located within: $abs_managed"
    echo ""
    echo "Examples of valid paths:"
    echo "  $abs_managed/.vimrc"
    echo "  $abs_managed/.config/app/"
    echo "  $abs_managed/.bashrc"
    return 1
  fi
}

# Function to calculate the destination path within the stow directory
calculate_stow_path() {
  local source_path="$1"
  local managed_root="$2"
  local stow_dir="$3"
  
  # Get absolute paths
  local abs_source
  local abs_managed
  
  abs_source=$(realpath "$source_path")
  abs_managed=$(realpath "$managed_root")
  
  # Calculate relative path from managed root
  local rel_path="${abs_source#"$abs_managed"/}"
  
  # If the source is exactly the managed root, this is an error
  if [[ "$rel_path" == "$abs_source" ]]; then
    echo "Error: Cannot add the entire managed directory."
    return 1
  fi
  
  # Construct destination path
  echo "$stow_dir/$rel_path"
}

# Function to move file/directory to the repository
move_to_repository() {
  local source_path="$1"
  local dest_path="$2"
  local repo_dir="$3"
  
  local full_dest_path="$repo_dir/$dest_path"
  local dest_dir
  dest_dir=$(dirname "$full_dest_path")
  
  # Create destination directory if it doesn't exist
  if [[ ! -d "$dest_dir" ]]; then
    echo "Creating directory: $dest_dir"
    if ! mkdir -p "$dest_dir"; then
      echo "Error: Failed to create directory $dest_dir"
      return 1
    fi
  fi
  
  # Check if destination already exists
  if [[ -e "$full_dest_path" ]]; then
    echo "Error: Destination already exists: $full_dest_path"
    echo "The file or directory is already being managed by dotfiles."
    return 1
  fi
  
  # Move the file/directory
  echo "Moving $source_path to $full_dest_path"
  if ! mv "$source_path" "$full_dest_path"; then
    echo "Error: Failed to move $source_path to $full_dest_path"
    return 1
  fi
  
  echo "Successfully moved to repository."
  return 0
}

# Function to run the add command
run_add() {
  local commit_flag=false
  local target_path=""
  
  # Parse arguments
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --commit)
        commit_flag=true
        shift
        ;;
      -*)
        echo "Error: Unknown option $1"
        echo "Use 'dotfiles help' for usage information."
        return 1
        ;;
      *)
        if [[ -z "$target_path" ]]; then
          target_path="$1"
        else
          echo "Error: Multiple paths specified. Please specify only one file or directory."
          return 1
        fi
        shift
        ;;
    esac
  done
  
  # Check if target path was provided
  if [[ -z "$target_path" ]]; then
    echo "Error: No file or directory specified."
    echo "Usage: dotfiles add <path> [--commit]"
    return 1
  fi
  
  # Ensure we have valid configuration
  if [[ -z "$DF_REPOSITORY_PATH" ]]; then
    echo "Error: Repository path is not set in the configuration."
    echo "Please ensure your config file is properly set up."
    return 1
  fi
  
  # Check if target exists
  if [[ ! -e "$target_path" ]]; then
    echo "Error: File or directory '$target_path' does not exist."
    return 1
  fi
  
  # Validate path is within managed tree
  if ! validate_path_in_tree "$target_path" "$DF_TARGET_DIRECTORY"; then
    return 1
  fi
  
  # Calculate destination path in stow directory
  local stow_dest_path
  if ! stow_dest_path=$(calculate_stow_path "$target_path" "$DF_TARGET_DIRECTORY" "$DF_STOW_DIRECTORY"); then
    return 1
  fi
  
  echo "Planning to add: $target_path"
  echo "Destination: $DF_REPOSITORY_PATH/$stow_dest_path"
  
  # Check git if commit flag is set
  if [[ "$commit_flag" == true ]]; then
    if ! check_git; then
      return 1
    fi
    
    if ! check_git_repo "$DF_REPOSITORY_PATH"; then
      return 1
    fi
  fi
  
  # Move file to repository
  if ! move_to_repository "$target_path" "$stow_dest_path" "$DF_REPOSITORY_PATH"; then
    return 1
  fi
  
  # Update stow to manage the new file
  echo "Updating stow configuration..."
  if ! run_stow "$DF_REPOSITORY_PATH" "$DF_STOW_DIRECTORY" "$DF_TARGET_DIRECTORY"; then
    echo "Error: Failed to update stow configuration."
    echo "The file has been moved to the repository but may not be properly linked."
    return 1
  fi
  
  # Handle git operations if commit flag is set
  if [[ "$commit_flag" == true ]]; then
    local relative_path
    if ! relative_path=$(get_relative_path "$DF_REPOSITORY_PATH" "$DF_REPOSITORY_PATH/$stow_dest_path"); then
      echo "Warning: Could not determine relative path for git operations."
      relative_path="$stow_dest_path"
    fi
    
    # Add file to git
    if ! git_add_files "$DF_REPOSITORY_PATH" "$relative_path"; then
      echo "Error: Failed to add file to git. You may need to commit manually."
      return 1
    fi
    
    # Commit changes
    local commit_message
    commit_message="Add $(basename "$target_path") to dotfiles"
    if ! git_commit_changes "$DF_REPOSITORY_PATH" "$commit_message"; then
      echo "Error: Failed to commit changes. You may need to commit manually."
      return 1
    fi
    
    # Push changes
    if ! git_push_changes "$DF_REPOSITORY_PATH"; then
      echo "Warning: Failed to push changes. You may need to push manually."
      # Don't return error here as the main operation succeeded
    fi
    
    echo "File successfully added, committed, and pushed to repository."
  else
    echo ""
    echo "SUCCESS: File successfully added to dotfiles management."
    echo ""
    echo "NEXT STEPS:"
    echo "The file has been moved to your dotfiles repository and is now being"
    echo "managed by stow. To save these changes permanently, you should commit"
    echo "them to your git repository:"
    echo ""
    echo "  cd $DF_REPOSITORY_PATH"
    echo "  git add $stow_dest_path"
    echo "  git commit -m \"Add $(basename "$target_path") to dotfiles\""
    echo "  git push"
    echo ""
    echo "Alternatively, you can use the --commit flag next time:"
    echo "  dotfiles add <path> --commit"
  fi
  
  return 0
}
