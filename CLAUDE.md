# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is a dotfiles repository for Linux environment setup and configuration management. It provides automated installation and configuration of common development tools across different Linux distributions.

## Architecture

The repository uses a modular installation system with the following structure:

- **Main installer**: `install.sh` - Entry point that orchestrates the entire setup process
- **Install scripts**: `install-scripts/` - Modular installation scripts for different tools and components
- **Configuration files**: `config/` - Dotfiles managed by GNU Stow for symlinking to home directory
- **Helper scripts**: `scripts/` - Utility scripts symlinked to `~/.local/bin`
- **Resources**: `res/` - Configuration files for keybindings and other resources

## Key Components

### Installation System
- **Package management**: `install-packages.sh` detects and uses appropriate package manager (apt, dnf, yum, zypper, pacman)
- **Configuration management**: `stow-config.sh` uses GNU Stow with `--adopt` strategy to handle existing files
- **Script linking**: `link-scripts.sh` symlinks utility scripts to `~/.local/bin`

### Configuration Management
- Uses GNU Stow for dotfile management
- Config files are organized under `config/` directory
- Includes configurations for: bash, git, kitty, nvim, alacritty, hypr, starship

## Common Commands

### Full Environment Setup
```bash
./install.sh
```

### Individual Component Installation
```bash
./install-scripts/install-packages.sh
./install-scripts/stow-config.sh
./install-scripts/link-scripts.sh
```

### Configuration Management
```bash
# Apply configuration changes
cd /path/to/dotfiles
stow -v --adopt -d . -t $HOME config
git restore .
```

### Testing
```bash
# Install BATS testing framework
./install-scripts/install-bats.sh

# Run all tests locally
./run-tests.sh

# Run specific test suites
./run-tests.sh unit
./run-tests.sh integration

# Test against specific distribution (requires Docker)
./run-tests.sh --docker --distribution ubuntu

# Test all supported distributions (requires Docker)
./run-tests.sh --docker --all
```

## Development Notes

- The installation system is designed to be idempotent and cross-distribution compatible
- Package installation logic handles different package managers and their variations (e.g., dnf4 vs dnf5)
- Configuration files use the `--adopt` strategy to preserve existing configurations while establishing symlinks
- All install scripts should be made executable before running via `chmod +x ./install-scripts/*.sh`