# dotfiles
Common tool configuration files and simple stow implementation to allow configurations to be saved and managed
in a git repository, and be managed centrally across multiple machines.

All managed configurations will be present and linked with stow, even for software that is not installed.  The extra 
unused configuration files should not be an issue, but is noted here to for awarness, and that it is expected.

![Test Dotfiles](https://github.com/jdubba/dotfiles/workflows/Test%20Dotfiles/badge.svg)

## Installation

```bash
./install.sh
```

## Development

### Prerequisites

- GNU Stow
- Git
- Bash
- ShellCheck (for linting)

### Commands

This project uses a Makefile to simplify common tasks:

```bash
# Install dotfiles
make install

# Run tests
make test

# Run linting
make lint

# Show all available commands
make help
```

## Testing

This project uses BATS (Bash Automated Testing System) for testing.

### Running Tests

To run the test suite:

```bash
./test.sh
```

This will automatically install BATS and its helper libraries if they're not already installed.

### Linting

To check shell scripts for syntax and best practices:

```bash
./lint.sh
```

## Continuous Integration

This project uses GitHub Actions for continuous integration:

- Linting is performed on all shell scripts
- Tests are run on both Ubuntu and macOS
- Installation is verified in a clean environment
