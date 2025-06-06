#!/usr/bin/env bats

load '../helpers/test_helper'

setup() {
    skip_unless_distribution "fedora"
    setup_test_env
}

teardown() {
    teardown_test_env
}

@test "dnf package manager is available" {
    run command -v dnf
    assert_success
}

@test "dnf version detection works" {
    run dnf --version
    assert_success
    
    # Check if it's DNF5 or DNF4
    if dnf --version | grep -q 'dnf5 version 5\.'; then
        echo "DNF5 detected"
    elif dnf --version | grep -q '4\.'; then
        echo "DNF4 detected"
    fi
}

@test "Fedora-specific packages can be detected" {
    # Test some Fedora-specific package availability
    run dnf info gcc
    assert_success
}

@test "package installation script recognizes Fedora" {
    run_install_script "install-scripts/install-packages.sh" --dry-run
    assert_success
}

@test "rpm is available" {
    run command -v rpm
    assert_success
}

@test "systemd is available" {
    run command -v systemctl
    assert_success
}

@test "Fedora release detection" {
    run cat /etc/fedora-release
    assert_success
}