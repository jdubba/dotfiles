#!/usr/bin/env bats

load '../helpers/test_helper'

setup() {
    skip_unless_distribution "opensuse"
    setup_test_env
}

teardown() {
    teardown_test_env
}

@test "zypper package manager is available" {
    run command -v zypper
    assert_success
}

@test "openSUSE-specific detection works" {
    run cat /etc/os-release
    assert_success
    assert_output --partial "opensuse"
}

@test "zypper can query packages" {
    run zypper info gcc
    assert_success
}

@test "package installation script recognizes openSUSE" {
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

@test "development patterns are available" {
    # Check if development patterns can be queried
    run zypper search -t pattern devel
    assert_success
}