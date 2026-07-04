# AGENTS.md

Guidance for AI agents and contributors working in this repository.

## Repository Overview

This repository is a **dotfiles configuration manager**. It keeps configuration
consistent across multiple Linux machines using a custom, dependency-free Bash
tool (`bin/dotfiles`, currently v1.0.0) that manages a **layered symlink farm**.

It replaced an earlier GNU Stow-based system. Stow is no longer used.

## Environment & scope

- **Linux only.** Target distros are **Gentoo** and **Fedora**; desktops are
  **Hyprland** and **GNOME**. No macOS/Windows/WSL support is maintained.
- Primary machine: **`stationzebra`** (Gentoo, Hyprland, laptop + dual external
  displays via a dock).
- **No secrets in the repo.** Machine-specific private values stay in untracked
  local includes (e.g. `~/.gitsigning` referenced from `.gitconfig`). Do not add
  encryption or commit credentials.
- `.opencode/` is agent tooling and is **gitignored** — never commit it.

## Architecture

Three layers are symlinked into `$HOME`, applied in order (later overrides/adds):

- `home/` — shared configuration (the 90%+ that does not vary between machines)
- `profiles/<name>/` — shared across like machines (e.g. `hyprland`, `gnome`, `fedora`)
- `hosts/<hostname>/` — truly per-machine configuration (e.g. `hosts/stationzebra/`)

A path under a layer mirrors its `$HOME` destination
(`home/.config/nvim` → `~/.config/nvim`; `home/.gitconfig` → `~/.gitconfig`).

Profiles auto-activate when their name matches the detected distro id, distro
family, or desktop; extra ones are enabled with `dotfiles profile enable`.

### Key safety invariants (do not regress these)

1. **Container directories are never symlinked.** `~/.config`, `~/.local[/*]`,
   `~/.cache`, `~/.ssh`, `~/.gnupg`, etc. (see `DF_CONTAINER_DIRS` in
   `lib/config.sh`) are always materialised as real directories; only managed
   children are linked. This prevents the folding-`~/.config` disaster.
2. **No implicit adoption.** `link`/`sync` never move target files into the repo.
   Only `dotfiles add` adopts, explicitly and per-path.
3. **Never clobber.** Real files the repo does not own are reported as CONFLICTs.
4. **Plan-first, idempotent.** Mutating commands are previewable and safe to rerun.
5. **`doctor` repairs migration/hazard debris** — a container that became a repo
   symlink, and broken links into the repo (incl. stale relative links left by a
   previous tool like Stow).

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

## Shell configuration (bash + zsh share one core)

The shell config is itself modular, and the common parts are shared between bash
and zsh rather than duplicated:

- `home/.config/shell/` — **POSIX sh, shared by both shells**:
  - `env.sh` — XDG dirs, `EDITOR`/`VISUAL`, pager, `GCC_COLORS`, and an
    **idempotent PATH** builder. Sourced from `.zshenv` and from bash
    (`.bash_profile`/`.profile`/`.bashrc`). Must have **no side effects** (no
    network, no prompt) and **no bashisms/zshisms**.
  - `aliases.sh` — the single alias set (replaced `.bash_aliases` and
    `zsh/aliases.zsh`).
  - `interactive.sh` — interactive-only setup; exports `EXTERNAL_IP`
    (a `curl --max-time 2 ipinfo.io/ip`). Sourced from `.bashrc` and `.zshrc`.
- `home/.config/bash/` — bash modules mirroring the zsh ones: `fzf.bash`,
  `bindings.bash`, `tools.bash` (nvm, azure-cli), `prompt.bash`.
- `home/.config/zsh/` — zsh modules: `fzf.zsh`, `bindings.zsh`, `plugins.zsh`,
  `prompt.zsh`. zsh-only bits (e.g. `compdef eza=ls`) live in `.zshrc`.
- Entrypoints: `.bashrc` (slim, mirrors `.zshrc`), `.bash_profile`, `.profile`,
  `.zshrc`, `.zshenv`.

### Shell conventions & gotchas (durable)

- **PATH is re-sourced in `.zshrc`.** On Gentoo login shells, `/etc/zprofile` →
  `/etc/profile.env` can reset `PATH` *after* `.zshenv` runs, so `env.sh` is
  sourced again from `.zshrc`; its `_pathadd` is idempotent so this is safe.
- **starship owns bash's `PROMPT_COMMAND`** and overwrites it. To run something
  every prompt (e.g. history sync), use starship's `starship_precmd_user_func`
  hook, not a pre-set `PROMPT_COMMAND`.
- **`EXTERNAL_IP`** is consumed by starship's `[custom.externalip]` module
  (`command = "printf $EXTERNAL_IP"`). It must be **exported** in whichever shell
  renders the prompt — hence it lives in the shared `interactive.sh` (both shells).
- **Shared history:** bash mimics zsh's `SHARE_HISTORY` via `history -a; history -n`
  each prompt, wired through `starship_precmd_user_func` (`_df_share_history`).
- **History files are XDG:** `$XDG_STATE_HOME/{bash,zsh}/history`. Each shell
  **creates its own history dir on startup** (and zsh creates `$XDG_CACHE_HOME/zsh`
  for the completion dump) so a fresh machine doesn't error on first run.
- **zsh completion:** run `compinit` **once** into `$XDG_CACHE_HOME/zsh/zcompdump`
  with `bashcompinit` *after* it. Do not reintroduce a bare `compinit` — it writes
  a stray `~/.zcompdump` on every startup.

### Monitors / desktop specifics

- `hyprland.conf` carries **no static `monitor=` lines** and no workspace→monitor
  bindings; **kanshi** owns output geometry *and* workspace placement (via its
  `move-workspaces.sh`). kanshi config lives in the host layer
  (`hosts/stationzebra/.config/kanshi/`).
- GNOME settings are not files; manage them with `dotfiles dconf dump|load`
  (keyfile under `profiles/gnome/dconf/`).

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
dotfiles doctor --fix    # detect/repair hazards (folded containers, broken links)
dotfiles add <path>      # adopt an existing config file/dir (--to home|host|profile:<n>)
dotfiles profile enable <name>
dotfiles dconf dump|load # GNOME settings
```

## Development Guidelines

1. Shell is **Bash** for the tool; keep scripts `shellcheck`-clean (`./lint.sh`
   must pass). Libraries are sourced, so guard against `set -euo pipefail`
   foot-guns (e.g. `shopt -p` returns non-zero when an option is off — prefer an
   isolated subshell for temporary `shopt` changes).
2. **Shared shell files (`home/.config/shell/*.sh`) must stay POSIX** — they are
   sourced by `.zshenv` and by `sh`/display managers, not just bash.
3. Add BATS coverage in `tests/*.bats` for any new behavior, especially anything
   touching the linker — the safety invariants above must stay tested.
4. Configuration content lives under `home/`, `profiles/`, `hosts/`. Managed
   configs are symlinked even for software that isn't installed; that's expected.
5. Machine-local state (enabled profiles) lives under `$XDG_STATE_HOME/dotfiles`
   and is never committed.
6. Do not run `dotfiles link`/`add` against the real `$HOME` without intent; they
   mutate live symlinks. Tests run entirely in throwaway temp dirs.
7. CI runs on Ubuntu and Fedora (see `.github/workflows/test.yml`).

## Testing

BATS (Bash Automated Testing System). `./test.sh` bootstraps `bats-core` locally
if it isn't already installed, then runs `tests/*.bats`. `tests/repo.bats`
syntax-checks shipped config in all three dialects — `bash -n`, `sh -n`, and
`zsh -n` (the zsh checks skip when zsh isn't installed).
