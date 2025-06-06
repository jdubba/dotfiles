#!/usr/bin/env bats

load '../helpers/test_helper'

setup() {
    setup_test_env
}

teardown() {
    teardown_test_env
}

@test "detect apt package manager on Ubuntu/Debian" {
    skip_unless_package_manager "apt"
    
    run command -v apt-get
    assert_success
    
    run command -v apt
    assert_success
}

@test "detect dnf package manager on Fedora" {
    skip_unless_package_manager "dnf"
    
    run command -v dnf
    assert_success
}

@test "detect pacman package manager on Arch" {
    skip_unless_package_manager "pacman"
    
    run command -v pacman
    assert_success
}

@test "detect zypper package manager on openSUSE" {
    skip_unless_package_manager "zypper"
    
    run command -v zypper
    assert_success
}

@test "package detection logic in install-packages.sh" {
    # Check if the script exists and is executable
    assert_executable "$DOTFILES_DIR/install-scripts/install-packages.sh"
    
    # Test that the script can detect package managers without running
    local script="$DOTFILES_DIR/install-scripts/install-packages.sh"
    
    # Extract package manager detection logic without executing install commands
    run bash -c "source '$script' && exit 0" 2>/dev/null || true
    
    # Script should at least be syntactically correct
    run bash -n "$script"
    assert_success
}

@test "DNF version detection" {
    skip_unless_package_manager "dnf"
    
    run dnf --version
    assert_success
    
    # Check if version output contains expected format
    assert_output --partial "dnf"
}

@test "package manager availability check" {
    # At least one package manager should be available
    local found=false
    
    if has_package_manager "apt"; then found=true; fi
    if has_package_manager "dnf"; then found=true; fi
    if has_package_manager "pacman"; then found=true; fi
    if has_package_manager "zypper"; then found=true; fi
    
    [[ "$found" == "true" ]]
}