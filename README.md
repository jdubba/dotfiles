# dotfiles

Common tool configuration files and management utility to allow configurations to be saved and managed
in a git repository, and be managed centrally across multiple machines.

All managed configurations will be present and linked with stow, even for software that is not installed. The extra 
unused configuration files should not be an issue, but is noted here for awareness, and that it is expected.

![Test Dotfiles](https://github.com/jdubba/dotfiles/workflows/Test%20Dotfiles/badge.svg)

## Installation

### Quick Installation

```bash
# Install the dotfiles utility and create symlinks
make setup
```

### Manual Installation

You can also install just the utility and then run it separately:

```bash
# Install the dotfiles utility
make install

# Use the utility to create symlinks
dotfiles install
```

### Legacy Installation

For backward compatibility, you can still use the old method:

```bash
./install.sh
```

## Configuration

The dotfiles utility uses a TOML configuration file located at `~/.config/dotfiles/config.toml`. This file is automatically created during installation with default values:

```toml
# Dotfiles configuration

# Path to the dotfiles repository
repository_path = "/path/to/your/dotfiles"

# Default stow directory within the repository
stow_directory = "config"

# Target directory (defaults to $HOME)
# target_directory = "/home/username"
```

## Usage

After installation, you can use the `dotfiles` command:

```bash
# Install/update dotfiles
dotfiles install

# Add a file or directory to dotfiles management
dotfiles add ~/.vimrc

# Add a file and automatically commit the changes
dotfiles add ~/.config/app --commit

# Show help information
dotfiles help

# Show version information
dotfiles version
```

### Adding Files to Dotfiles Management

The `add` command allows you to easily add existing configuration files to your dotfiles repository:

```bash
# Add a single configuration file
dotfiles add ~/.bashrc

# Add an entire configuration directory
dotfiles add ~/.config/nvim

# Add and automatically commit/push changes
dotfiles add ~/.gitconfig --commit
```

**Important Notes:**
- Files must be located within your home directory (or configured target directory)
- The command will move the original file to the repository and create a symlink
- Use `--commit` to automatically commit and push changes to your git repository
- Without `--commit`, you'll need to manually commit the changes later

## Development

### Prerequisites

- GNU Stow
- Git
- Bash
- ShellCheck (for linting)

### Commands

This project uses a Makefile to simplify common tasks:

```bash
# Install dotfiles utility
make install

# Install utility and run dotfiles install
make setup

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