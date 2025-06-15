#!/usr/bin/env bash
#
# Configuration file handling for the dotfiles utility
#

# Configuration defaults
export DF_REPOSITORY_PATH=""
export DF_STOW_DIRECTORY="config"
export DF_TARGET_DIRECTORY="$HOME"

# Function to parse TOML configuration file
# This is a simple parser for basic TOML keys
load_config() {
  local config_file="$1"
  
  if [[ ! -f "$config_file" ]]; then
    echo "Error: Configuration file '$config_file' not found."
    return 1
  fi
  
  echo "Loading configuration from: $config_file"
  
  # Parse key-value pairs from the TOML file
  # This is a basic implementation that handles simple key = "value" pairs
  while IFS= read -r line; do
    # Skip comments and empty lines
    [[ "$line" =~ ^[[:space:]]*# ]] && continue
    [[ "$line" =~ ^[[:space:]]*$ ]] && continue
    
    # Extract key and value
    if [[ "$line" =~ ^[[:space:]]*([a-zA-Z0-9_]+)[[:space:]]*=[[:space:]]*\"(.*)\"[[:space:]]*$ ]]; then
      key="${BASH_REMATCH[1]}"
      value="${BASH_REMATCH[2]}"
      
      # Set variables based on keys
      case "$key" in
        repository_path)
          export DF_REPOSITORY_PATH="$value"
          ;;
        stow_directory)
          export DF_STOW_DIRECTORY="$value"
          ;;
        target_directory)
          export DF_TARGET_DIRECTORY="$value"
          ;;
        *)
          echo "Warning: Unknown configuration key: $key"
          ;;
      esac
    fi
  done < "$config_file"
  
  # Validate required config values
  if [[ -z "$DF_REPOSITORY_PATH" ]]; then
    echo "Error: repository_path must be set in the configuration file."
    return 1
  fi
  
  # Ensure the repository path exists
  if [[ ! -d "$DF_REPOSITORY_PATH" ]]; then
    echo "Error: Repository directory '$DF_REPOSITORY_PATH' does not exist."
    return 1
  fi
  
  return 0
}

# Function to create default config file
create_default_config() {
  local config_dir="$1"
  local config_file="$2"
  local repository_path="$3"
  
  # Create config directory if it doesn't exist
  mkdir -p "$config_dir"
  
  # Create default config file
  cat > "$config_file" <<EOF
# Dotfiles configuration

# Path to the dotfiles repository
repository_path = "$repository_path"

# Default stow directory within the repository
stow_directory = "config"

# Target directory (defaults to \$HOME)
# target_directory = "$HOME"
EOF

  echo "Created default configuration at: $config_file"
  return 0
}