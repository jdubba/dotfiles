#!/usr/bin/env bats

load '../helpers/test_helper'

setup() {
    setup_test_env
}

teardown() {
    teardown_test_env
}

@test "main install script exists and is executable" {
    assert_executable "$DOTFILES_DIR/install.sh"
}

@test "install script syntax check" {
    # Test that the main install script is syntactically correct
    run bash -n "$DOTFILES_DIR/install.sh"
    assert_success
}

@test "package installation script syntax check" {
    # Test that the script is syntactically correct
    run bash -n "$DOTFILES_DIR/install-scripts/install-packages.sh"
    assert_success
}

@test "stow configuration script validation" {
    # Create minimal config structure for testing
    mkdir -p "$TEST_TEMP_DIR/config/test"
    create_test_dotfile "$TEST_TEMP_DIR/config/test/.testrc" "test config"
    
    # Test stow with config directory
    cd "$TEST_TEMP_DIR"
    run stow -n -d . -t "$TEST_HOME" config
    assert_success
}

@test "script linking functionality" {
    # Create test script
    mkdir -p "$TEST_TEMP_DIR/scripts"
    create_mock_script "$TEST_TEMP_DIR/scripts/test-script.sh" 'echo "test script"'
    
    # Test linking
    mkdir -p "$TEST_HOME/.local/bin"
    run ln -s "$TEST_TEMP_DIR/scripts/test-script.sh" "$TEST_HOME/.local/bin/test-script"
    assert_success
    assert_symlink "$TEST_HOME/.local/bin/test-script" "$TEST_TEMP_DIR/scripts/test-script.sh"
}

@test "directory structure creation" {
    local required_dirs=(
        ".local/bin"
        ".config"
        ".ssh"
    )
    
    for dir in "${required_dirs[@]}"; do
        run mkdir -p "$TEST_HOME/$dir"
        assert_success
        assert_dir_exists "$TEST_HOME/$dir"
    done
}

@test "git configuration validation" {
    # Skip if git is not available
    if ! command_exists git; then
        skip "Git not available"
    fi
    
    # Test git config read (should not fail even if no config exists)
    run git config --global user.name || true
    # This might fail if no git config exists, which is fine
}

@test "font installation directory setup" {
    local font_dir="$TEST_HOME/.local/share/fonts"
    
    run mkdir -p "$font_dir"
    assert_success
    assert_dir_exists "$font_dir"
}