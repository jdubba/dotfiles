#!/bin/bash
# Script to install BATS testing framework

set -e

BATS_CORE_VERSION="v1.9.0"
BATS_SUPPORT_VERSION="v0.3.0"
BATS_ASSERT_VERSION="v2.1.0"

# Create lib directory for BATS
mkdir -p tests/lib

# Install bats-core
if [ ! -d "tests/lib/bats-core" ]; then
  echo "Installing bats-core..."
  git clone --depth 1 -b ${BATS_CORE_VERSION} https://github.com/bats-core/bats-core.git tests/lib/bats-core
fi

# Install bats-support
if [ ! -d "tests/lib/bats-support" ]; then
  echo "Installing bats-support..."
  git clone --depth 1 -b ${BATS_SUPPORT_VERSION} https://github.com/bats-core/bats-support.git tests/lib/bats-support
fi

# Install bats-assert
if [ ! -d "tests/lib/bats-assert" ]; then
  echo "Installing bats-assert..."
  git clone --depth 1 -b ${BATS_ASSERT_VERSION} https://github.com/bats-core/bats-assert.git tests/lib/bats-assert
fi

echo "BATS and helper libraries installed successfully."
echo "You can run tests with: tests/lib/bats-core/bin/bats tests/*.bats"
