# Testing Strategy

This document outlines the testing strategy for the dotfiles repository, ensuring reliable installation and configuration across multiple Linux distributions.

## Overview

The testing strategy uses a multi-layered approach:

1. **Unit Tests**: Test individual install scripts in isolation
2. **Integration Tests**: Test complete installation workflows
3. **Cross-Distribution Testing**: Validate compatibility across Linux distributions
4. **CI/CD Pipeline**: Automated testing on every commit and pull request

## Testing Framework

### BATS (Bash Automated Testing System)
- Primary testing framework for shell scripts
- Simple, readable test syntax
- Built-in assertion functions
- Easy integration with CI/CD

### Docker-based Distribution Testing
- Test against multiple Linux distributions using Docker containers
- Supported distributions:
  - Ubuntu 20.04, 22.04, 24.04
  - Fedora 40, 41, 42
  - Arch Linux
  - openSUSE Leap 15.5, Tumbleweed
  - Debian 11, 12

## Test Categories

### 1. Unit Tests (`tests/unit/`)
Test individual components in isolation:
- Package manager detection
- Command availability checks
- Error handling
- Configuration file parsing
- Script permissions and executability

### 2. Integration Tests (`tests/integration/`)
Test complete workflows:
- Full installation process
- Configuration deployment with Stow
- Script linking to ~/.local/bin
- Tool-specific installations (kitty, neovim, etc.)

### 3. Distribution Tests (`tests/distributions/`)
Validate cross-distribution compatibility:
- Package manager variations (apt, dnf, pacman, zypper)
- Distribution-specific quirks
- Version compatibility (dnf4 vs dnf5)

## Test Structure

```
tests/
├── unit/
│   ├── test_package_detection.bats
│   ├── test_error_handling.bats
│   └── test_utilities.bats
├── integration/
│   ├── test_full_install.bats
│   ├── test_stow_config.bats
│   └── test_script_linking.bats
├── distributions/
│   ├── ubuntu.bats
│   ├── fedora.bats
│   ├── arch.bats
│   └── opensuse.bats
├── docker/
│   ├── Dockerfile.ubuntu
│   ├── Dockerfile.fedora
│   ├── Dockerfile.arch
│   └── Dockerfile.opensuse
└── helpers/
    ├── test_helper.bash
    └── setup.bash
```

## Running Tests

### Local Testing
```bash
# Run all tests
./run-tests.sh

# Run specific test suite
./run-tests.sh unit
./run-tests.sh integration
./run-tests.sh distributions

# Run tests for specific distribution
./run-tests.sh --distribution ubuntu
./run-tests.sh --distribution fedora
```

### Docker-based Testing
```bash
# Test against all supported distributions
./run-tests.sh --docker --all

# Test against specific distribution
./run-tests.sh --docker --distribution ubuntu:22.04
```

## Test Environment

### Prerequisites
- Docker (for cross-distribution testing)
- BATS testing framework
- Git (for repository operations)

### Test Data
- Mock configuration files in `tests/fixtures/`
- Sample dotfiles for testing Stow operations
- Test scripts with known behaviors

## Continuous Integration

### GitHub Actions Workflow
- Triggered on: push, pull_request, schedule (weekly)
- Matrix testing across multiple distributions
- Parallel execution for faster feedback
- Artifact collection for failed tests

### Test Coverage
- Script execution paths
- Error conditions
- Edge cases (missing dependencies, permission issues)
- Configuration conflicts

## Best Practices

### Writing Tests
1. **Isolated**: Tests should not depend on external state
2. **Idempotent**: Can be run multiple times safely
3. **Fast**: Quick feedback loop for developers
4. **Descriptive**: Clear test names and failure messages

### Test Maintenance
1. Keep tests updated with script changes
2. Add tests for new features/scripts
3. Remove obsolete tests
4. Regular test execution to catch regressions

## Debugging Failed Tests

### Local Debugging
```bash
# Run with verbose output
./run-tests.sh --verbose

# Run single test file
bats tests/unit/test_package_detection.bats

# Debug with shell access
docker run -it --rm -v $(pwd):/dotfiles test-ubuntu:22.04 /bin/bash
```

### CI Debugging
- Check GitHub Actions logs
- Download test artifacts
- Reproduce locally with same Docker image

## Future Enhancements

1. **Performance Testing**: Measure installation times
2. **Security Testing**: Validate GPG signatures and checksums
3. **Regression Testing**: Automated tests on dotfiles updates
4. **User Acceptance Testing**: End-to-end scenarios
5. **Compatibility Matrix**: Document tested combinations


🚀 Usage Examples

  # Install BATS locally
  ./install-scripts/install-bats.sh

  # Run all tests locally
  ./run-tests.sh

  # Test specific distribution in Docker
  ./run-tests.sh --docker --distribution ubuntu

  # Test all distributions
  ./run-tests.sh --docker --all

  # Run only unit tests
  ./run-tests.sh unit

  The testing system validates package manager detection, script permissions, Stow configuration management, and cross-distribution compatibility - ensuring your dotfiles work reliably across Ubuntu, Fedora,
   Arch Linux, and openSUSE environments.
