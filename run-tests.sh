#!/usr/bin/env bash

set -euo pipefail

# Test runner script for dotfiles repository
# Supports local and Docker-based testing across multiple distributions

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEST_DIR="$SCRIPT_DIR/tests"

# Default values
DOCKER_MODE=false
ALL_DISTRIBUTIONS=false
VERBOSE=false
DRY_RUN=false
DISTRIBUTION=""
TEST_SUITE=""

# Supported distributions
SUPPORTED_DISTRIBUTIONS=("ubuntu" "fedora" "arch" "opensuse")

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Print colored output
print_color() {
    local color=$1
    shift
    echo -e "${color}$*${NC}"
}

# Print usage information
usage() {
    cat << EOF
Usage: $0 [OPTIONS] [TEST_SUITE]

Run tests for the dotfiles repository.

OPTIONS:
    -h, --help              Show this help message
    -d, --docker            Run tests in Docker containers
    -a, --all               Test against all supported distributions (requires --docker)
    -D, --distribution DIST Test against specific distribution
    -v, --verbose           Enable verbose output
    -n, --dry-run           Show what would be executed without running
    
TEST_SUITE:
    unit                    Run unit tests only
    integration             Run integration tests only
    distributions           Run distribution-specific tests only
    (default: run all tests)

DISTRIBUTIONS:
    ubuntu, fedora, arch, opensuse

EXAMPLES:
    $0                                  # Run all tests locally
    $0 unit                            # Run unit tests locally
    $0 --docker --all                  # Test all distributions in Docker
    $0 --docker --distribution ubuntu  # Test Ubuntu in Docker
    $0 --verbose integration           # Run integration tests with verbose output

EOF
}

# Check if BATS is installed
check_bats() {
    if ! command -v bats >/dev/null 2>&1; then
        print_color "$RED" "Error: BATS testing framework not found!"
        print_color "$YELLOW" "Install BATS by running: ./install-scripts/install-bats.sh"
        exit 1
    fi
}

# Check if Docker is installed and running
check_docker() {
    if ! command -v docker >/dev/null 2>&1; then
        print_color "$RED" "Error: Docker not found!"
        print_color "$YELLOW" "Docker is required for cross-distribution testing."
        exit 1
    fi
    
    if ! docker info >/dev/null 2>&1; then
        print_color "$RED" "Error: Docker daemon not accessible!"
        print_color "$YELLOW" "Make sure Docker is running and you have permissions to access it."
        print_color "$YELLOW" "Try: sudo usermod -aG docker \$USER && newgrp docker"
        exit 1
    fi
}

# Build Docker image for distribution
build_docker_image() {
    local dist=$1
    local dockerfile="$TEST_DIR/docker/Dockerfile.$dist"
    local image_name="dotfiles-test-$dist"
    
    if [[ ! -f "$dockerfile" ]]; then
        print_color "$RED" "Error: Dockerfile not found for distribution: $dist"
        return 1
    fi
    
    print_color "$BLUE" "Building Docker image for $dist..."
    
    if [[ "$DRY_RUN" == "true" ]]; then
        echo "Would run: docker build -t $image_name -f $dockerfile $TEST_DIR/docker/"
        return 0
    fi
    
    if ! docker build -t "$image_name" -f "$dockerfile" "$TEST_DIR/docker/"; then
        print_color "$RED" "Failed to build Docker image for $dist"
        return 1
    fi
    
    print_color "$GREEN" "Successfully built image: $image_name"
}

# Run tests in Docker container
run_docker_tests() {
    local dist=$1
    local test_suite=$2
    local image_name="dotfiles-test-$dist"
    
    print_color "$BLUE" "Running tests for $dist..."
    
    # Determine test files to run
    local test_files=""
    case "$test_suite" in
        "unit")
            test_files="tests/unit/"
            ;;
        "integration")
            test_files="tests/integration/"
            ;;
        "distributions")
            if [[ -f "$TEST_DIR/distributions/$dist.bats" ]]; then
                test_files="tests/distributions/$dist.bats"
            else
                print_color "$YELLOW" "No distribution-specific tests for $dist"
                return 0
            fi
            ;;
        *)
            test_files="tests/unit/ tests/integration/"
            if [[ -f "$TEST_DIR/distributions/$dist.bats" ]]; then
                test_files="$test_files tests/distributions/$dist.bats"
            fi
            ;;
    esac
    
    # Prepare docker run command
    local docker_cmd="docker run --rm"
    docker_cmd="$docker_cmd -v $SCRIPT_DIR:/dotfiles:Z"
    docker_cmd="$docker_cmd -w /dotfiles"
    docker_cmd="$docker_cmd -e DOTFILES_DIR=/dotfiles"
    
    if [[ "$VERBOSE" == "true" ]]; then
        docker_cmd="$docker_cmd -e BATS_VERBOSE=1"
    fi
    
    docker_cmd="$docker_cmd $image_name"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        echo "Would run: $docker_cmd bats $test_files"
        return 0
    fi
    
    # Run the tests
    if eval "$docker_cmd bats $test_files"; then
        print_color "$GREEN" "✓ Tests passed for $dist"
        return 0
    else
        print_color "$RED" "✗ Tests failed for $dist"
        return 1
    fi
}

# Run tests locally
run_local_tests() {
    local test_suite=$1
    
    print_color "$BLUE" "Running tests locally..."
    
    # Determine test files to run
    local test_files=""
    case "$test_suite" in
        "unit")
            test_files="$TEST_DIR/unit/"
            ;;
        "integration")
            test_files="$TEST_DIR/integration/"
            ;;
        "distributions")
            # Run distribution test for current system
            local current_dist
            if [[ -f /etc/os-release ]]; then
                current_dist=$(. /etc/os-release && echo "$ID")
            elif [[ -f /etc/arch-release ]]; then
                current_dist="arch"
            else
                print_color "$YELLOW" "Cannot detect current distribution"
                return 0
            fi
            
            if [[ -f "$TEST_DIR/distributions/$current_dist.bats" ]]; then
                test_files="$TEST_DIR/distributions/$current_dist.bats"
            else
                print_color "$YELLOW" "No distribution-specific tests for $current_dist"
                return 0
            fi
            ;;
        *)
            test_files="$TEST_DIR/unit/ $TEST_DIR/integration/"
            ;;
    esac
    
    # Prepare bats command
    local bats_cmd="bats"
    if [[ "$VERBOSE" == "true" ]]; then
        bats_cmd="$bats_cmd --verbose-run"
    fi
    
    if [[ "$DRY_RUN" == "true" ]]; then
        echo "Would run: $bats_cmd $test_files"
        return 0
    fi
    
    # Run the tests
    if eval "$bats_cmd $test_files"; then
        print_color "$GREEN" "✓ Local tests passed"
        return 0
    else
        print_color "$RED" "✗ Local tests failed"
        return 1
    fi
}

# Validate distribution name
validate_distribution() {
    local dist=$1
    for supported in "${SUPPORTED_DISTRIBUTIONS[@]}"; do
        if [[ "$dist" == "$supported" ]]; then
            return 0
        fi
    done
    print_color "$RED" "Error: Unsupported distribution: $dist"
    print_color "$YELLOW" "Supported distributions: ${SUPPORTED_DISTRIBUTIONS[*]}"
    exit 1
}

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                usage
                exit 0
                ;;
            -d|--docker)
                DOCKER_MODE=true
                shift
                ;;
            -a|--all)
                ALL_DISTRIBUTIONS=true
                shift
                ;;
            -D|--distribution)
                DISTRIBUTION="$2"
                validate_distribution "$DISTRIBUTION"
                shift 2
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            -n|--dry-run)
                DRY_RUN=true
                shift
                ;;
            unit|integration|distributions)
                TEST_SUITE="$1"
                shift
                ;;
            *)
                print_color "$RED" "Unknown option: $1"
                usage
                exit 1
                ;;
        esac
    done
}

# Main execution
main() {
    parse_args "$@"
    
    # Validate arguments
    if [[ "$ALL_DISTRIBUTIONS" == "true" && "$DOCKER_MODE" == "false" ]]; then
        print_color "$RED" "Error: --all requires --docker"
        exit 1
    fi
    
    if [[ -n "$DISTRIBUTION" && "$DOCKER_MODE" == "false" ]]; then
        print_color "$YELLOW" "Warning: --distribution specified without --docker, running locally"
    fi
    
    # Check prerequisites
    if [[ "$DOCKER_MODE" == "true" ]]; then
        check_docker
    else
        check_bats
    fi
    
    print_color "$BLUE" "Dotfiles Test Runner"
    print_color "$BLUE" "==================="
    
    # Run tests
    local exit_code=0
    
    if [[ "$DOCKER_MODE" == "true" ]]; then
        if [[ "$ALL_DISTRIBUTIONS" == "true" ]]; then
            # Test all distributions
            for dist in "${SUPPORTED_DISTRIBUTIONS[@]}"; do
                if ! build_docker_image "$dist"; then
                    exit_code=1
                    continue
                fi
                
                if ! run_docker_tests "$dist" "$TEST_SUITE"; then
                    exit_code=1
                fi
            done
        elif [[ -n "$DISTRIBUTION" ]]; then
            # Test specific distribution
            if build_docker_image "$DISTRIBUTION"; then
                if ! run_docker_tests "$DISTRIBUTION" "$TEST_SUITE"; then
                    exit_code=1
                fi
            else
                exit_code=1
            fi
        else
            print_color "$RED" "Error: Docker mode requires --all or --distribution"
            exit 1
        fi
    else
        # Run tests locally
        if ! run_local_tests "$TEST_SUITE"; then
            exit_code=1
        fi
    fi
    
    # Summary
    if [[ $exit_code -eq 0 ]]; then
        print_color "$GREEN" "All tests completed successfully!"
    else
        print_color "$RED" "Some tests failed!"
    fi
    
    exit $exit_code
}

# Run main function with all arguments
main "$@"