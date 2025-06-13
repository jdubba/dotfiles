#!/bin/bash
# Lint script for dotfiles project
# Checks shell scripts for syntax and best practices

set -e

# Check if shellcheck is installed
if ! command -v shellcheck &> /dev/null; then
    echo "Error: shellcheck is not installed. Please install it first."
    echo "Ubuntu/Debian: sudo apt-get install shellcheck"
    echo "macOS: brew install shellcheck"
    echo "More info: https://github.com/koalaman/shellcheck#installing"
    exit 1
fi

echo "Running shellcheck on shell scripts..."

# Find all shell scripts
SHELL_SCRIPTS=$(find . -type f -name "*.sh" -o -name "install*" | grep -v "tests/lib")

# Check if any shell scripts were found
if [ -z "$SHELL_SCRIPTS" ]; then
    echo "No shell scripts found to lint."
    exit 0
fi

# Run shellcheck on all shell scripts
echo "$SHELL_SCRIPTS" | xargs shellcheck -x

# Check bash configuration files
if [ -f "config/.bashrc" ]; then
    echo "Checking config/.bashrc..."
    shellcheck -x config/.bashrc || true
fi

if [ -f "config/.bash_aliases" ]; then
    echo "Checking config/.bash_aliases..."
    shellcheck -x config/.bash_aliases || true
fi

if [ -f "config/.profile" ]; then
    echo "Checking config/.profile..."
    shellcheck -x config/.profile || true
fi

echo "Linting completed successfully!"
