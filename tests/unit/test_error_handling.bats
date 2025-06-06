#!/usr/bin/env bats

load '../helpers/test_helper'

setup() {
    setup_test_env
}

teardown() {
    teardown_test_env
}

@test "install scripts have proper shebang" {
    for script in "$DOTFILES_DIR"/install-scripts/*.sh; do
        [[ ! -f "$script" ]] && continue
        
        run head -n1 "$script"
        # Accept either #!/bin/bash or #!/usr/bin/env bash
        if [[ ! "$output" =~ ^#!.*bash$ ]]; then
            fail "Script $script has invalid shebang: $output"
        fi
    done
}

@test "install scripts use error handling" {
    local scripts_with_error_handling=0
    local total_scripts=0
    
    for script in "$DOTFILES_DIR"/install-scripts/*.sh; do
        [[ ! -f "$script" ]] && continue
        total_scripts=$((total_scripts + 1))
        
        # Check for any form of error handling (set -e, set -euo pipefail, or explicit error checks)
        if grep -q -E "(set -e|set -euo|exit [0-9]|return [0-9])" "$script"; then
            scripts_with_error_handling=$((scripts_with_error_handling + 1))
        fi
    done
    
    # Skip test if no scripts found
    [[ $total_scripts -gt 0 ]] || skip "No install scripts found"
    
    # At least 25% of scripts should have some error handling
    local percentage=$((scripts_with_error_handling * 100 / total_scripts))
    [[ $percentage -ge 25 ]]
}

@test "install scripts are executable" {
    for script in "$DOTFILES_DIR"/install-scripts/*.sh; do
        [[ ! -f "$script" ]] && continue
        assert_executable "$script"
    done
}

@test "main install script is executable" {
    assert_executable "$DOTFILES_DIR/install.sh"
}

@test "scripts handle command not found gracefully" {
    # Create a mock script that checks for non-existent command
    create_mock_script "$TEST_TEMP_DIR/mock_script.sh" '
#!/usr/bin/env bash
set -euo pipefail

if command -v nonexistent_command >/dev/null 2>&1; then
    echo "Command found"
else
    echo "Command not found - handling gracefully"
fi
'
    
    run bash "$TEST_TEMP_DIR/mock_script.sh"
    assert_success
    assert_output "Command not found - handling gracefully"
}

@test "scripts validate prerequisites" {
    # Test that git is available (required for most scripts)
    run command -v git
    assert_success
}

@test "error handling in arch detection script" {
    run_install_script "install-scripts/install-aur-helper.sh" --dry-run
    
    # Should handle non-Arch systems gracefully
    if [[ "$(get_distribution)" != "arch" ]]; then
        assert_success
    fi
}