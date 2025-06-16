#!/usr/bin/env bats

# Load test helpers
load 'lib/bats-support/load'
load 'lib/bats-assert/load'

# Setup function run before each test
setup() {
    # Create a temporary directory for testing
    export TEST_DIR
    TEST_DIR=$(mktemp -d)
    export TEST_REPO="$TEST_DIR/dotfiles"
    export TEST_HOME="$TEST_DIR/home"
    export TEST_CONFIG_DIR="$TEST_HOME/.config/dotfiles"
    export TEST_CONFIG_FILE="$TEST_CONFIG_DIR/config.toml"
    
    # Create test directories
    mkdir -p "$TEST_REPO/config"
    mkdir -p "$TEST_HOME"
    mkdir -p "$TEST_CONFIG_DIR"
    
    # Initialize git repository
    cd "$TEST_REPO" || exit
    git init
    git config user.email "test@example.com"
    git config user.name "Test User"
    
    # Create test config file
    cat > "$TEST_CONFIG_FILE" <<EOF
repository_path = "$TEST_REPO"
stow_directory = "config"
target_directory = "$TEST_HOME"
EOF
    
    # Set up PATH to use our dotfiles script
    export PATH="$BATS_TEST_DIRNAME/../bin:$PATH"
}

# Teardown function run after each test
teardown() {
    # Clean up temporary directory
    rm -rf "$TEST_DIR"
}

@test "add command shows error when no path specified" {
    export XDG_CONFIG_HOME="$TEST_HOME/.config"
    run dotfiles add
    assert_failure
    assert_output --partial "Error: No file or directory specified"
}

@test "add command shows error when file doesn't exist" {
    export XDG_CONFIG_HOME="$TEST_HOME/.config"
    run dotfiles add "$TEST_HOME/nonexistent"
    assert_failure
    assert_output --partial "does not exist"
}

@test "add command shows error when path is outside managed tree" {
    export XDG_CONFIG_HOME="$TEST_HOME/.config"
    # Create a file outside the managed directory
    mkdir -p "$TEST_DIR/outside"
    echo "test content" > "$TEST_DIR/outside/testfile"
    
    run dotfiles add "$TEST_DIR/outside/testfile"
    assert_failure
    assert_output --partial "outside the managed directory tree"
}

@test "add command successfully adds a file within managed tree" {
    export XDG_CONFIG_HOME="$TEST_HOME/.config"
    # Create a test file in the home directory
    echo "test content" > "$TEST_HOME/.testrc"
    
    run dotfiles add "$TEST_HOME/.testrc"
    assert_success
    assert_output --partial "SUCCESS: File successfully added"
    
    # Verify file was moved to repository
    assert [ -f "$TEST_REPO/config/.testrc" ]
    
    # Verify symlink was created (original file should now be a symlink)
    assert [ -L "$TEST_HOME/.testrc" ]
}

@test "add command successfully adds a directory within managed tree" {
    export XDG_CONFIG_HOME="$TEST_HOME/.config"
    # Create a test directory in the home directory
    mkdir -p "$TEST_HOME/.config/testapp"
    echo "config content" > "$TEST_HOME/.config/testapp/config.conf"
    
    run dotfiles add "$TEST_HOME/.config/testapp"
    assert_success
    assert_output --partial "SUCCESS: File successfully added"
    
    # Verify directory was moved to repository
    assert [ -d "$TEST_REPO/config/.config/testapp" ]
    assert [ -f "$TEST_REPO/config/.config/testapp/config.conf" ]
    
    # Verify symlink was created (original directory should now be a symlink)
    assert [ -L "$TEST_HOME/.config/testapp" ]
}

@test "add command with --commit flag commits and pushes changes" {
    export XDG_CONFIG_HOME="$TEST_HOME/.config"
    # Create a test file
    echo "test content" > "$TEST_HOME/.testrc"
    
    # Add remote to test repository (using local path for testing)
    cd "$TEST_REPO"
    git remote add origin "$TEST_DIR/remote.git"
    git init --bare "$TEST_DIR/remote.git"
    
    run dotfiles add "$TEST_HOME/.testrc" --commit
    assert_success
    assert_output --partial "successfully added, committed, and pushed"
    
    # Verify file was committed
    cd "$TEST_REPO"
    run git log --oneline
    assert_success
    assert_output --partial "Add .testrc to dotfiles"
}

@test "add command shows error when destination already exists" {
    export XDG_CONFIG_HOME="$TEST_HOME/.config"
    # Create a file in both locations
    echo "original content" > "$TEST_REPO/config/.testrc"
    echo "new content" > "$TEST_HOME/.testrc"
    
    run dotfiles add "$TEST_HOME/.testrc"
    assert_failure
    assert_output --partial "Destination already exists"
}

@test "add command handles unknown options gracefully" {
    export XDG_CONFIG_HOME="$TEST_HOME/.config"
    run dotfiles add --unknown-option
    assert_failure
    assert_output --partial "Unknown option"
}
