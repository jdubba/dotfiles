#!/usr/bin/env bats

load '../helpers/test_helper'

setup() {
    skip_unless_distribution "ubuntu"
    setup_test_env
}

teardown() {
    teardown_test_env
}

@test "apt package manager is available" {
    run command -v apt-get
    assert_success
    
    run command -v apt
    assert_success
}

@test "Ubuntu-specific packages can be detected" {
    # Test some Ubuntu-specific package availability
    run apt-cache show build-essential
    assert_success
}

@test "package installation script recognizes Ubuntu" {
    run_install_script "install-scripts/install-packages.sh" --dry-run
    assert_success
}

@test "snap is available on Ubuntu" {
    # Snap should be available on most Ubuntu systems
    if command_exists snap; then
        run snap --version
        assert_success
    else
        skip "Snap not available in this Ubuntu environment"
    fi
}

@test "systemd is available" {
    run command -v systemctl
    assert_success
}

@test "Ubuntu version detection" {
    run lsb_release -rs 2>/dev/null || cat /etc/os-release
    assert_success
}