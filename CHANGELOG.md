# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- **Theme system.** A `themes/<name>/` layer (injected between profiles and
  host) coordinates colours across kitty, ghostty, hyprland/hyprlock, waybar,
  walker, tmux, starship, nvim, opencode, bat/fzf, and the wallpaper. Managed
  with `dotfiles theme status|list|set|unset`. Ships `catppuccin-mocha` and
  `gruvbox-dark`; selectable per-host (committed) with a repo default.
- Each tool reads a stable seam path the active theme provides (e.g. kitty
  `include current-theme.conf`, waybar `@import "colors.css"`), so switching a
  theme is a relink + live reload.
- **Auto-theming** (`dotfiles theme auto now|enable|disable|status`): derives a
  palette from the current wallpaper and generates the whole `themes/auto/` tree
  (gitignored). Palette backend preference wallust → pywal → bundled
  python+Pillow, with a notice recommending wallust when a lesser backend is
  used. Continuous mode is a polling systemd user service; nvim uses generated
  base16, bat `ansi`, opencode `system`. See `docs/auto-theming.md` (incl. the
  GNOME/KDE detection backlog).
- **Waybar theme switcher**: a `custom/theme` pill (between the controls pill and
  battery) opens a Walker menu to pick any predefined theme, or a Walker-based
  image browser to generate an auto theme from a chosen wallpaper
  (`scripts/thememenu`, backed by `dotfiles theme list --plain`).
- Waybar section pills now use per-section accent colors with contrast-adjusted
  text (previously all rendered near-black); walker's accent likewise uses a
  vivid color instead of the darkest palette tone.
- **~40 curated themes** generated from an official-palette registry
  (`tools/build-themes.sh` + the shared `df_theme_emit_seams` emitter):
  Catppuccin (Latte/Frappé/Macchiato/Mocha), Nord, Solarized (Dark/Light),
  Rosé Pine (Main/Moon/Dawn), Gruvbox (Dark/Light), Dracula,
  Tokyo Night (Night/Storm/Moon/Day), One Dark, Everforest (Dark/Light),
  Kanagawa (Wave/Dragon/Lotus), Monokai/Monokai-Pro, Ayu (Dark/Mirage/Light),
  GitHub (Dark/Light), Material, Oxocarbon, Nightfox family
  (Dusk/Nord/Tera/Carbon/Dawnfox), Melange, Zenburn, Palenight. Each ships a
  matching wallpaper (palette-gradient default; real images where dropped in).

### Changed
- **Active theme selection is machine-local** (`$XDG_STATE_HOME/dotfiles/theme`)
  rather than a committed per-host file, so switching themes no longer churns the
  repo. `theme set`/`unset` write/clear it; a committed per-host override
  (`hosts/<host>/.config/dotfiles/theme`) remains an optional lower-priority
  fallback. Adds `dotfiles theme name` (resolved active theme to stdout).
- `hypr` wallpaper path made portable: `hyprpaper.conf` reads
  `$HOME/.config/background` (coordinated with hyprlock) instead of a hardcoded
  personal path. `hyprland`/`hyprlock` `source=` switched to relative paths
  (`source=` does not expand `$HOME`/`~`).
- Neovim colorscheme config bundles catppuccin, gruvbox, and base16-nvim and
  applies whichever the active theme names (`lua/dotfiles_theme.lua`).
- ghostty theme seam switched from `theme = current` to `config-file =
  themes/current`: ghostty's single-instance daemon caches *named* themes and
  wouldn't hot-reload when the file behind the name changed, so switching themes
  left the terminal colors stale. A direct config-file include is re-read and
  applied on `SIGUSR2` reload.

## [1.0.0] - 2026-07-04

Ground-up rebuild. The GNU Stow-based system is replaced by a custom,
dependency-free Bash tool that manages a layered symlink farm.

### Added
- New `bin/dotfiles` tool with a safe, plan-first linker (`lib/`).
- Three-layer model: `home/` (shared) + `profiles/<name>/` (like machines) +
  `hosts/<hostname>/` (per-machine), auto-resolved from hostname/distro/desktop.
- Commands: `link`, `status`, `doctor`, `add`, `sync`, `profile`, `dconf`,
  `hook`, `info`.
- `doctor` detects and repairs the folded-container hazard and broken links.
- `dconf dump`/`load` for GNOME settings (which cannot be symlinked).
- `git post-merge` hook so `git pull` re-links automatically.
- BATS coverage for every safety guarantee (container protection, no-adopt,
  no-clobber, fold/auto-unfold, idempotency, disaster recovery).

### Changed
- Configuration content moved from `config/` to `home/` (history preserved).
- CI reworked for the new tool; now runs on Ubuntu and Fedora.

### Removed
- Legacy `install.sh`, the Stow-based `src/` utility, TOML config, and all
  GNU Stow usage. Removed tracked backup cruft (`*.bak`).

### Safety
- Container directories (`~/.config`, `~/.local[/*]`, `~/.cache`, `~/.ssh`, …)
  are never folded into a symlink; only managed children are linked.
- Files the repo does not own are never overwritten or implicitly adopted.

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