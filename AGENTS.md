# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is a dotfiles repository that uses GNU Stow to manage configuration files across multiple machines. The repository contains configuration files for various tools and applications, organized within the `config` directory.

## Common Commands

### Installation

```bash
# Install dotfiles (creates symlinks in home directory)
./install.sh
# or
make install
```

### Testing

```bash
# Run the test suite (uses BATS)
./test.sh
# or
make test
```

### Linting

```bash
# Lint shell scripts with ShellCheck
./lint.sh
# or
make lint
```

### Other Commands

```bash
# Show all available commands
make help

# Clean up test artifacts
make clean
```

## Repository Structure

- `/config`: Contains all dotfiles to be symlinked to the user's home directory
  - Shell configurations (`.bashrc`, `.bash_aliases`, `.profile`)
  - Git configuration (`.gitconfig`)
  - `.config/` directory with app-specific configurations:
    - `hypr/`: Hyprland window manager configuration
    - `nvim/`: Neovim editor configuration
    - `kitty/`: Kitty terminal emulator configuration
    - `alacritty/`: Alacritty terminal emulator configuration

- `/tests`: Contains BATS test files and helpers
  - `*.bats`: Test files
  - `install_bats.sh`: Script to install BATS testing framework

## Installation Process

The `install.sh` script:
1. Checks for uncommitted changes in the config folder
2. Uses GNU Stow with the `--adopt` flag to create symlinks
3. Restores any changes that might have been adopted during the process

## Development Guidelines

1. All configuration files should be placed in the `config` directory
2. Test any changes with the test suite before committing
3. Run linting to ensure shell scripts follow best practices
4. The repository uses GitHub Actions for continuous integration on both Ubuntu and macOS

## Notes

- All managed configurations will be symbolically linked even if the corresponding software is not installed
- Changes to configuration files should be committed to the repository to be properly tracked