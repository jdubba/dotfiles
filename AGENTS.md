# AGENTS.md

Guidance for AI agents and contributors working in this repository.

## Repository Overview

This repository is a **dotfiles configuration manager**. It keeps configuration
consistent across multiple Linux machines using a custom, dependency-free Bash
tool (`bin/dotfiles`) that manages a **layered symlink farm**.

It replaced an earlier GNU Stow-based system. Stow is no longer used.

## Architecture

Three layers are symlinked into `$HOME`, applied in order (later overrides/adds):

- `home/` — shared configuration (the 90%+ that does not vary between machines)
- `profiles/<name>/` — shared across like machines (e.g. `hyprland`, `gnome`, `fedora`)
- `hosts/<hostname>/` — truly per-machine configuration

A path under a layer mirrors its `$HOME` destination
(`home/.config/nvim` → `~/.config/nvim`; `home/.gitconfig` → `~/.gitconfig`).

### Key safety invariants (do not regress these)

1. **Container directories are never symlinked.** `~/.config`, `~/.local[/*]`,
   `~/.cache`, `~/.ssh`, `~/.gnupg`, etc. (see `DF_CONTAINER_DIRS` in
   `lib/config.sh`) are always materialised as real directories; only managed
   children are linked. This prevents the folding-`~/.config` disaster.
2. **No implicit adoption.** `link`/`sync` never move target files into the repo.
   Only `dotfiles add` adopts, explicitly and per-path.
3. **Never clobber.** Real files the repo does not own are reported as CONFLICTs.
4. **Plan-first, idempotent.** Mutating commands are previewable and safe to rerun.

## Code layout

- `bin/dotfiles` — CLI entrypoint and command dispatch.
- `lib/core.sh` — logging, colour, path helpers.
- `lib/config.sh` — defaults, the container-dir set, repo config, machine state.
- `lib/identity.sh` — hostname/distro/desktop detection, layer resolution.
- `lib/link.sh` — the linker: plan building, fold/unfold, apply.
- `lib/commands/*.sh` — one file per subcommand (`link`, `status`, `doctor`,
  `add`, `sync`, `profile`, `dconf`, `hook`, `info`).
- `hooks/post-merge` — git hook that re-links after `git pull`.
- `dotfiles.conf` — optional repo config (extend `DF_CONTAINER_DIRS` / `DF_IGNORE_NAMES`).

## Common Commands

```bash
make test     # run the BATS suite (./test.sh)
make lint     # run shellcheck (./lint.sh)
make all      # lint + test
make install  # symlink `dotfiles` onto PATH + install git hook
```

The tool itself:

```bash
dotfiles status          # read-only preview
dotfiles link            # apply
dotfiles doctor --fix    # detect/repair hazards
dotfiles add <path>      # adopt an existing config file/dir
```

## Development Guidelines

1. Shell is **Bash**; keep scripts `shellcheck`-clean (`./lint.sh` must pass).
   Libraries are sourced, so guard against `set -euo pipefail` foot-guns
   (e.g. `shopt -p` returns non-zero when an option is off).
2. Add BATS coverage in `tests/*.bats` for any new behavior, and especially for
   anything touching the linker — the safety invariants above must stay tested.
3. Configuration content lives under `home/`, `profiles/`, `hosts/`. Managed
   configs are symlinked even for software that isn't installed; that's expected.
4. Machine-local state (enabled profiles) lives under `$XDG_STATE_HOME/dotfiles`
   and is never committed.
5. CI runs on Ubuntu and Fedora (see `.github/workflows/test.yml`).

## Testing

BATS (Bash Automated Testing System). `./test.sh` bootstraps `bats-core` locally
if it isn't already installed, then runs `tests/*.bats`.
