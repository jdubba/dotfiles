#!/usr/bin/env bats

load '../helpers/test_helper'

setup() {
    setup_test_env
}

teardown() {
    teardown_test_env
}

@test "stow is available" {
    run command -v stow
    assert_success
}

@test "git is available" {
    run command -v git
    assert_success
}

@test "curl is available" {
    run command -v curl
    assert_success
}

@test "directory creation works" {
    local test_dir="$TEST_TEMP_DIR/test_dir"
    
    run mkdir -p "$test_dir"
    assert_success
    assert_dir_exists "$test_dir"
}

@test "file creation and permissions" {
    local test_file="$TEST_TEMP_DIR/test_file.sh"
    
    create_test_dotfile "$test_file" '#!/bin/bash\necho "test"'
    assert_file_exists "$test_file"
    
    run chmod +x "$test_file"
    assert_success
    assert_executable "$test_file"
}

@test "symlink creation" {
    local source_file="$TEST_TEMP_DIR/source"
    local link_file="$TEST_TEMP_DIR/link"
    
    create_test_dotfile "$source_file" "test content"
    
    run ln -s "$source_file" "$link_file"
    assert_success
    assert_symlink "$link_file" "$source_file"
}

@test "environment variable handling" {
    export TEST_VAR="test_value"
    
    run bash -c 'echo $TEST_VAR'
    assert_success
    assert_output "test_value"
}

@test "home directory expansion" {
    run bash -c 'echo ~'
    assert_success
    assert_output "$HOME"
}

@test "path manipulation" {
    local original_path="$PATH"
    local test_path="/test/path"
    
    export PATH="$test_path:$PATH"
    
    run bash -c 'echo $PATH'
    assert_success
    assert_output --partial "$test_path"
    
    # Restore original PATH
    export PATH="$original_path"
}