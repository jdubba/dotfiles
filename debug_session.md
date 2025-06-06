# Docker Distribution Test Debugging Session

## Issue Summary
The Docker-based distribution tests in the dotfiles repository are failing with the error:
```
ERROR: Test file "/dotfiles/tests/distributions/DISTRO.bats" does not exist
```

Where `DISTRO` is replaced with the actual distribution name being tested.

## Investigation Results

### Problem Analysis
1. **Unit and integration tests**: Working correctly
2. **Docker distribution tests**: Failing with path issues
3. **Root cause**: The test runner script `run-tests.sh` has issues with Docker command construction and variable expansion

### Files Examined
- `/home/jwilliams/source/dotfiles/TESTING.md` - Testing strategy documentation
- `/home/jwilliams/source/dotfiles/run-tests.sh` - Main test runner script
- `/home/jwilliams/source/dotfiles/tests/distributions/ubuntu.bats` - Sample distribution test
- `/home/jwilliams/source/dotfiles/tests/helpers/test_helper.bash` - Test helper functions
- `/home/jwilliams/source/dotfiles/tests/docker/Dockerfile.ubuntu` - Docker configuration

### Changes Made
1. **Improved command construction** in `run-tests.sh` line 172-177:
   - Simplified the Docker command execution
   - Removed redundant variable assignments
   - Ensured proper variable expansion

2. **Path verification**: Confirmed that:
   - Distribution test files exist: `ubuntu.bats`, `fedora.bats`, `arch.bats`, `opensuse.bats`
   - Docker mounts repository at `/dotfiles`
   - Working directory is set to `/dotfiles`
   - Test files use relative paths like `tests/distributions/ubuntu.bats`

### Current Status
- **Docker permission issue**: Cannot test changes due to Docker daemon access error
- **Code fixes applied**: Ready for testing once Docker is accessible
- **Next steps**: Fix Docker permissions and test the distribution tests

## Docker Permission Fix Needed
```bash
sudo usermod -aG docker $USER && newgrp docker
```

## Test Commands to Run After Docker Fix
```bash
# Test specific distribution
./run-tests.sh --docker --distribution ubuntu

# Test all distributions
./run-tests.sh --docker --all

# Test with verbose output
./run-tests.sh --docker --distribution ubuntu --verbose
```

## File Structure Context
```
tests/
├── distributions/
│   ├── ubuntu.bats     ✓ exists
│   ├── fedora.bats     ✓ exists
│   ├── arch.bats       ✓ exists
│   └── opensuse.bats   ✓ exists
├── docker/
│   ├── Dockerfile.ubuntu    ✓ exists
│   ├── Dockerfile.fedora    ✓ exists
│   ├── Dockerfile.arch      ✓ exists
│   └── Dockerfile.opensuse  ✓ exists
└── helpers/
    └── test_helper.bash     ✓ exists
```

## Key Insights
1. The error message showing "DISTRO" instead of actual distribution name suggests variable expansion issues
2. The Docker container setup appears correct with proper BATS installation
3. The test files themselves are properly structured and exist
4. The main issue was likely in the command construction in `run-tests.sh`

## Todo List Status
- [x] Investigate Docker distribution test failure
- [x] Fix path issues in run-tests.sh for Docker mode
- [ ] Add better error handling for distribution test file discovery (pending)

## Resume Point
After fixing Docker permissions, test the distribution tests to verify the fixes work correctly. If the issue persists, add debug output to identify the exact command being executed and track down where the literal "DISTRO" string is coming from.