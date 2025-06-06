#!/usr/bin/env bats

load '../helpers/test_helper'

setup() {
    setup_test_env
    mkdir -p "$TEST_TEMP_DIR/scripts"
    mkdir -p "$TEST_HOME/.local/bin"
}

teardown() {
    teardown_test_env
}

@test "script linking creates proper symlinks" {
    # Create test scripts
    create_mock_script "$TEST_TEMP_DIR/scripts/test-script.sh" 'echo "Hello from test script"'
    create_mock_script "$TEST_TEMP_DIR/scripts/another-script.sh" 'echo "Another script"'
    
    # Link scripts
    for script in "$TEST_TEMP_DIR/scripts"/*.sh; do
        script_name=$(basename "$script" .sh)
        run ln -s "$script" "$TEST_HOME/.local/bin/$script_name"
        assert_success
    done
    
    # Verify symlinks
    assert_symlink "$TEST_HOME/.local/bin/test-script" "$TEST_TEMP_DIR/scripts/test-script.sh"
    assert_symlink "$TEST_HOME/.local/bin/another-script" "$TEST_TEMP_DIR/scripts/another-script.sh"
}

@test "linked scripts are executable" {
    create_mock_script "$TEST_TEMP_DIR/scripts/executable-test.sh" 'echo "Executable test"'
    
    # Link script
    run ln -s "$TEST_TEMP_DIR/scripts/executable-test.sh" "$TEST_HOME/.local/bin/executable-test"
    assert_success
    
    # Verify executable
    assert_executable "$TEST_HOME/.local/bin/executable-test"
}

@test "linked scripts can be executed" {
    create_mock_script "$TEST_TEMP_DIR/scripts/runnable-test.sh" 'echo "Script executed successfully"'
    
    # Link script
    ln -s "$TEST_TEMP_DIR/scripts/runnable-test.sh" "$TEST_HOME/.local/bin/runnable-test"
    
    # Execute script
    run "$TEST_HOME/.local/bin/runnable-test"
    assert_success
    assert_output "Script executed successfully"
}

@test "script linking handles existing files" {
    create_mock_script "$TEST_TEMP_DIR/scripts/conflict-test.sh" 'echo "New script"'
    
    # Create existing file
    create_test_dotfile "$TEST_HOME/.local/bin/conflict-test" "existing content"
    
    # Attempt to link (should handle conflict)
    run ln -sf "$TEST_TEMP_DIR/scripts/conflict-test.sh" "$TEST_HOME/.local/bin/conflict-test"
    assert_success
    
    # Verify symlink was created (force overwrite)
    assert_symlink "$TEST_HOME/.local/bin/conflict-test" "$TEST_TEMP_DIR/scripts/conflict-test.sh"
}

@test "script names are cleaned properly" {
    # Test that .sh extension is removed from linked script names
    create_mock_script "$TEST_TEMP_DIR/scripts/name-test.sh" 'echo "Name cleaned"'
    
    script_path="$TEST_TEMP_DIR/scripts/name-test.sh"
    script_name=$(basename "$script_path" .sh)
    
    run ln -s "$script_path" "$TEST_HOME/.local/bin/$script_name"
    assert_success
    
    # Verify the linked name doesn't have .sh extension
    assert_file_exists "$TEST_HOME/.local/bin/name-test"
    assert_file_not_exists "$TEST_HOME/.local/bin/name-test.sh"
}

@test "PATH includes .local/bin directory" {
    # This test verifies the environment is set up correctly
    run bash -c 'echo $PATH'
    assert_success
    assert_output --partial ".local/bin"
}

@test "linked scripts work from PATH" {
    create_mock_script "$TEST_TEMP_DIR/scripts/path-test.sh" 'echo "Found in PATH"'
    
    # Link script
    ln -s "$TEST_TEMP_DIR/scripts/path-test.sh" "$TEST_HOME/.local/bin/path-test"
    
    # Execute via PATH (without full path)
    run bash -c 'cd /tmp && path-test'
    assert_success
    assert_output "Found in PATH"
}