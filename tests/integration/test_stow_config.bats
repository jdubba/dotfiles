#!/usr/bin/env bats

load '../helpers/test_helper'

setup() {
    setup_test_env
    
    # Create test package directories (these are the stow packages)
    mkdir -p "$TEST_TEMP_DIR/bash"
    mkdir -p "$TEST_TEMP_DIR/git"
    mkdir -p "$TEST_TEMP_DIR/test-app"
}

teardown() {
    teardown_test_env
}

@test "stow creates symlinks for config files" {
    # Create test packages (bash and git are package names)
    create_test_dotfile "$TEST_TEMP_DIR/bash/.bashrc" "# Test bashrc"
    create_test_dotfile "$TEST_TEMP_DIR/git/.gitconfig" "[user]\n    name = Test User"
    
    # Run stow
    cd "$TEST_TEMP_DIR"
    run stow -d . -t "$TEST_HOME" bash git
    assert_success
    
    # Verify symlinks were created
    assert_symlink "$TEST_HOME/.bashrc" "$TEST_TEMP_DIR/bash/.bashrc"
    assert_symlink "$TEST_HOME/.gitconfig" "$TEST_TEMP_DIR/git/.gitconfig"
}

@test "stow handles existing files with --adopt" {
    # Create existing file in home directory
    create_test_dotfile "$TEST_HOME/.bashrc" "existing bashrc content"
    
    # Create package file
    create_test_dotfile "$TEST_TEMP_DIR/bash/.bashrc" "# New bashrc content"
    
    # Run stow with --adopt
    cd "$TEST_TEMP_DIR"
    run stow --adopt -d . -t "$TEST_HOME" bash
    assert_success
    
    # Verify symlink was created
    assert_symlink "$TEST_HOME/.bashrc" "$TEST_TEMP_DIR/bash/.bashrc"
    
    # Verify content was adopted (moved to package)
    run cat "$TEST_TEMP_DIR/bash/.bashrc"
    assert_output "existing bashrc content"
}

@test "stow handles nested directory structures" {
    # Create nested structure in package
    mkdir -p "$TEST_TEMP_DIR/app/.config/app"
    create_test_dotfile "$TEST_TEMP_DIR/app/.config/app/config.yml" "test: value"
    
    # Run stow
    cd "$TEST_TEMP_DIR"
    run stow -d . -t "$TEST_HOME" app
    assert_success
    
    # Verify nested symlink
    assert_symlink "$TEST_HOME/.config/app/config.yml" "$TEST_TEMP_DIR/app/.config/app/config.yml"
}

@test "stow handles conflicts gracefully" {
    # Create conflicting directory structure
    mkdir -p "$TEST_HOME/.config/app"
    create_test_dotfile "$TEST_HOME/.config/app/existing.conf" "existing config"
    
    mkdir -p "$TEST_TEMP_DIR/app/.config/app"
    create_test_dotfile "$TEST_TEMP_DIR/app/.config/app/new.conf" "new config"
    
    # Run stow (should succeed with --adopt)
    cd "$TEST_TEMP_DIR"
    run stow --adopt -d . -t "$TEST_HOME" app
    assert_success
}

@test "stow dry-run mode works" {
    create_test_dotfile "$TEST_TEMP_DIR/test-app/.testrc" "test config"
    
    # Run stow in dry-run mode
    cd "$TEST_TEMP_DIR"
    run stow -n -d . -t "$TEST_HOME" test-app
    assert_success
    
    # Verify no actual changes were made
    assert_file_not_exists "$TEST_HOME/.testrc"
}

@test "unstow removes symlinks correctly" {
    # Create and stow package
    create_test_dotfile "$TEST_TEMP_DIR/test-app/.testrc" "test config"
    
    cd "$TEST_TEMP_DIR"
    run stow -d . -t "$TEST_HOME" test-app
    assert_success
    assert_symlink "$TEST_HOME/.testrc" "$TEST_TEMP_DIR/test-app/.testrc"
    
    # Unstow
    run stow -D -d . -t "$TEST_HOME" test-app
    assert_success
    assert_file_not_exists "$TEST_HOME/.testrc"
}