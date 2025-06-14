#!/bin/bash
# Script to install BATS testing framework

set -e

BATS_CORE_VERSION="v1.9.0"
BATS_SUPPORT_VERSION="v0.3.0"
BATS_ASSERT_VERSION="v2.1.0"

# Create lib directory for BATS
mkdir -p tests/lib

# Function to clone a repository with fallbacks
clone_repo() {
  local repo=$1
  local target=$2
  local version=$3
  
  echo "Installing $repo..."
  
  # Try with specific version tag first
  if [ -n "$version" ]; then
    git clone --depth 1 -b "$version" "https://github.com/$repo.git" "$target" 2>/dev/null || true
  fi
  
  # If directory doesn't exist, try without version tag
  if [ ! -d "$target" ]; then
    git clone --depth 1 "https://github.com/$repo.git" "$target" 2>/dev/null || true
  fi
  
  # If still doesn't exist, try with https
  if [ ! -d "$target" ]; then
    git clone --depth 1 "https://github.com/$repo.git" "$target" || {
      echo "Failed to clone $repo"
      return 1
    }
  fi
  
  # Verify the clone was successful
  if [ ! -d "$target" ]; then
    echo "Failed to clone $repo to $target"
    return 1
  fi
  
  return 0
}

# Install bats-core
if [ ! -d "tests/lib/bats-core" ]; then
  clone_repo "bats-core/bats-core" "tests/lib/bats-core" "$BATS_CORE_VERSION"
fi

# Install bats-support
if [ ! -d "tests/lib/bats-support" ]; then
  clone_repo "bats-core/bats-support" "tests/lib/bats-support" "$BATS_SUPPORT_VERSION"
fi

# Install bats-assert
if [ ! -d "tests/lib/bats-assert" ]; then
  clone_repo "bats-core/bats-assert" "tests/lib/bats-assert" "$BATS_ASSERT_VERSION"
fi

# Verify installations
echo "Verifying installations..."
for dir in "tests/lib/bats-core" "tests/lib/bats-support" "tests/lib/bats-assert"; do
  if [ ! -d "$dir" ]; then
    echo "Error: $dir was not installed correctly"
    exit 1
  else
    echo "✓ $dir installed"
  fi
done

# Check for bats executable and install it if not found
if [ ! -f "tests/lib/bats-core/bin/bats" ]; then
  echo "Bats executable not found, attempting to install it..."
  
  # Check if we can run the install script
  if [ -f "tests/lib/bats-core/install.sh" ]; then
    echo "Running bats-core install script..."
    (cd tests/lib/bats-core && ./install.sh /tmp/bats-temp)
    
    # Copy the bats executable if it was created
    if [ -f "/tmp/bats-temp/bin/bats" ]; then
      mkdir -p tests/lib/bats-core/bin
      cp /tmp/bats-temp/bin/bats tests/lib/bats-core/bin/
      chmod +x tests/lib/bats-core/bin/bats
    fi
  fi
  
  # If that didn't work, try to create a simple wrapper script
  if [ ! -f "tests/lib/bats-core/bin/bats" ]; then
    echo "Creating bats wrapper script..."
    mkdir -p tests/lib/bats-core/bin
    cat > tests/lib/bats-core/bin/bats << 'EOF'
#!/usr/bin/env bash
exec "$(dirname "$0")/../libexec/bats" "$@"
EOF
    chmod +x tests/lib/bats-core/bin/bats
  fi
fi

# Final verification of bats executable
if [ ! -f "tests/lib/bats-core/bin/bats" ]; then
  echo "Error: bats executable not found"
  # List the contents of the bats-core directory for debugging
  echo "Contents of tests/lib/bats-core:"
  ls -la tests/lib/bats-core
  if [ -d "tests/lib/bats-core/libexec" ]; then
    echo "Contents of tests/lib/bats-core/libexec:"
    ls -la tests/lib/bats-core/libexec
  fi
  exit 1
else
  echo "✓ bats executable found"
  # Make sure it's executable
  chmod +x tests/lib/bats-core/bin/bats
fi

echo "BATS and helper libraries installed successfully."
echo "You can run tests with: tests/lib/bats-core/bin/bats tests/*.bats"
