# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.3.0] - 2025-06-16

### Added
- New `add` command for the dotfiles utility
- Ability to add files and directories to dotfiles management
- Automatic validation that files are within the managed directory tree
- Verbose error messages explaining path validation issues
- Optional `--commit` flag to automatically commit and push changes
- Git integration with selective commit functionality
- Comprehensive test coverage for the add command

### Fixed
- Fixed all ShellCheck warnings and linting issues
- Improved error handling in test files with proper cd error checking
- Fixed parameter expansion quoting issues
- Separated variable declaration and assignment to avoid masking return values

## [0.2.0] - 2025-06-15

### Added
- New `dotfiles` utility that replaces the legacy install.sh script
- TOML-based configuration file at ~/.config/dotfiles/config.toml
- Support for standard command-line switches (--help, --version)
- Makefile targets for simplified installation and management
- BATS tests for the new dotfiles utility
- Improved GitHub Actions workflows for testing both legacy and new methods

### Changed
- Renamed environment variables to use DF_ prefix to avoid conflicts
  - REPOSITORY_PATH → DF_REPOSITORY_PATH
  - STOW_DIRECTORY → DF_STOW_DIRECTORY
  - TARGET_DIRECTORY → DF_TARGET_DIRECTORY
- Fixed linting errors in installation scripts
- Updated library path resolution for better compatibility
- Improved error handling in stow operations

### Fixed
- Fixed installation of library files in the correct locations
- Fixed CI workflows to properly test both installation methods
- Fixed handling of Git repository checks in container environments

## [0.1.0] - Initial Release

### Added
- Basic dotfiles installation using GNU Stow
- Simple install.sh script to set up symlinks
- BATS tests for the installation process
- GitHub Actions workflows for CI testing