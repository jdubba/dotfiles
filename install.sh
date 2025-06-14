#!/bin/bash

set -e

stow_directory=$(pwd)
stow_target_directory=$HOME

# Check for untracked or staged changes in the config folder
if [[ -n $(git status --porcelain config/) ]]; then
    echo "ERROR: Detected untracked or staged changes in the config folder."
    echo ""
    echo "The following files have changes:"
    git status --porcelain config/
    echo ""
    echo "INSTRUCTIONS TO RESOLVE:"
    echo "1. Either commit your changes: git add config/ && git commit -m 'Update config files'"
    echo "2. Or discard your changes: git restore config/ && git clean -fd config/"
    echo ""
    echo "After resolving the changes, run this script again."
    exit 1
fi

echo "No pending changes detected in config folder. Proceeding with stow..."

# Establish config symlinks, using --adopt followed by targeted git restore
stow -v --adopt -d "$stow_directory" -t "$stow_target_directory" config

# Only restore the config directory, preserving other changes
git restore config/

echo "Configuration files have been successfully linked."
