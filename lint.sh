#!/bin/bash
# Lint script for dotfiles project
# Checks shell scripts for syntax and best practices

set -e

# Function to suggest package installation based on detected system
suggest_shellcheck_install() {
    echo "Error: shellcheck is not installed. Please install it first."
    
    # Detect package manager and provide appropriate instructions
    if command -v apt &> /dev/null; then
        echo "Debian/Ubuntu: sudo apt install shellcheck"
    elif command -v dnf &> /dev/null; then
        echo "Fedora/RHEL: sudo dnf install ShellCheck"
    elif command -v yum &> /dev/null; then
        echo "CentOS/RHEL: sudo yum install epel-release && sudo yum install ShellCheck"
    elif command -v pacman &> /dev/null; then
        echo "Arch Linux: sudo pacman -S shellcheck"
    elif command -v zypper &> /dev/null; then
        echo "openSUSE: sudo zypper install ShellCheck"
    elif command -v emerge &> /dev/null; then
        echo "Gentoo: sudo emerge --ask dev-util/shellcheck"
    elif command -v brew &> /dev/null; then
        echo "macOS: brew install shellcheck"
    else
        echo "Please install shellcheck using your system's package manager"
    fi
    
    echo "More info: https://github.com/koalaman/shellcheck#installing"
    exit 1
}

# Check if shellcheck is installed
if ! command -v shellcheck &> /dev/null; then
    suggest_shellcheck_install
fi

echo "Running shellcheck on shell scripts..."

# Find all shell scripts, excluding git internal files and test libraries
SHELL_SCRIPTS=$(find . -type f -name "*.sh" -o -name "install*" | grep -v "tests/lib" | grep -v "^./.git/")

# Check if any shell scripts were found
if [ -z "$SHELL_SCRIPTS" ]; then
    echo "No shell scripts found to lint."
    exit 0
fi

# Run shellcheck on all shell scripts
# Exclude SC1091 (source file not found) as it's expected for dynamic paths
echo "$SHELL_SCRIPTS" | xargs shellcheck -x --exclude=SC1091

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

# Check test files with special options to handle BATS
echo "Checking BATS test files..."
find tests -name "*.bats" -not -path "tests/lib/*" -print0 | xargs -0 shellcheck --shell=bash --external-sources --exclude=SC1091 || true

echo "Linting completed successfully!"
