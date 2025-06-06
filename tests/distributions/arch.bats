#!/usr/bin/env bats

load '../helpers/test_helper'

setup() {
    skip_unless_distribution "arch"
    setup_test_env
}

teardown() {
    teardown_test_env
}

@test "pacman package manager is available" {
    run command -v pacman
    assert_success
}

@test "makepkg is available for AUR" {
    run command -v makepkg
    assert_success
}

@test "Arch-specific detection works" {
    run cat /etc/arch-release
    assert_success
}

@test "AUR helper installation script detects Arch" {
    run_install_script "install-scripts/install-aur-helper.sh" --dry-run
    assert_success
}

@test "base-devel group equivalent is available" {
    # Check if base development tools are available
    run pacman -Qi gcc
    assert_success
}

@test "git is available for AUR operations" {
    run command -v git
    assert_success
}

@test "systemd is available" {
    run command -v systemctl
    assert_success
}

@test "package installation script recognizes Arch" {
    run_install_script "install-scripts/install-packages.sh" --dry-run
    assert_success
}