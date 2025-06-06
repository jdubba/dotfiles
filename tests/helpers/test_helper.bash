#!/usr/bin/env bash

# Load BATS helper libraries
load '/usr/local/lib/bats-support/load'
load '/usr/local/lib/bats-assert/load'
load '/usr/local/lib/bats-file/load'

# Test configuration
export DOTFILES_DIR="${DOTFILES_DIR:-$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)}"
export TEST_TEMP_DIR="${BATS_TMPDIR}/dotfiles-test"
export TEST_HOME="${TEST_TEMP_DIR}/home"

# Create temporary test environment
setup_test_env() {
    mkdir -p "${TEST_HOME}"
    mkdir -p "${TEST_HOME}/.local/bin"
    mkdir -p "${TEST_HOME}/.config"
    export HOME="${TEST_HOME}"
    export PATH="${TEST_HOME}/.local/bin:${PATH}"
}

# Clean up test environment
teardown_test_env() {
    if [[ -d "${TEST_TEMP_DIR}" ]]; then
        rm -rf "${TEST_TEMP_DIR}"
    fi
}

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check if package manager exists
has_package_manager() {
    local pm="$1"
    case "$pm" in
        apt) command_exists apt-get ;;
        dnf) command_exists dnf ;;
        yum) command_exists yum ;;
        pacman) command_exists pacman ;;
        zypper) command_exists zypper ;;
        *) return 1 ;;
    esac
}

# Get current distribution
get_distribution() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        echo "$ID"
    elif [[ -f /etc/arch-release ]]; then
        echo "arch"
    else
        echo "unknown"
    fi
}

# Skip test if not on specified distribution
skip_unless_distribution() {
    local required_dist="$1"
    local current_dist
    current_dist=$(get_distribution)
    
    if [[ "$current_dist" != "$required_dist" ]]; then
        skip "Test requires $required_dist distribution (current: $current_dist)"
    fi
}

# Skip test if package manager not available
skip_unless_package_manager() {
    local pm="$1"
    if ! has_package_manager "$pm"; then
        skip "Test requires $pm package manager"
    fi
}

# Create mock script for testing
create_mock_script() {
    local script_path="$1"
    local content="$2"
    
    mkdir -p "$(dirname "$script_path")"
    cat > "$script_path" << EOF
#!/usr/bin/env bash
$content
EOF
    chmod +x "$script_path"
}

# Create test dotfile
create_test_dotfile() {
    local file_path="$1"
    local content="$2"
    
    mkdir -p "$(dirname "$file_path")"
    echo "$content" > "$file_path"
}

# Verify script has correct permissions
assert_executable() {
    local file="$1"
    assert_file_exists "$file"
    run test -x "$file"
    assert_success
}

# Verify symlink exists and points to correct target
assert_symlink() {
    local link="$1"
    local expected_target="$2"
    
    assert_file_exists "$link"
    
    # Get the actual target (resolve to absolute path)
    local actual_target
    actual_target=$(readlink -f "$link")
    
    # Compare resolved absolute paths
    [[ "$actual_target" == "$expected_target" ]] || {
        echo "Symlink target mismatch:"
        echo "  Link: $link"
        echo "  Expected: $expected_target"
        echo "  Actual: $actual_target"
        return 1
    }
}

# Run install script with error handling
run_install_script() {
    local script="$1"
    shift
    
    cd "$DOTFILES_DIR"
    run bash "$script" "$@"
}

# Check if service/process is running
is_running() {
    local process="$1"
    pgrep -f "$process" >/dev/null 2>&1
}

# Wait for condition with timeout
wait_for_condition() {
    local condition="$1"
    local timeout="${2:-30}"
    local count=0
    
    while ! eval "$condition" && [[ $count -lt $timeout ]]; do
        sleep 1
        ((count++))
    done
    
    [[ $count -lt $timeout ]]
}