# dotfiles

A small, safe, **layered symlink manager** for keeping configuration consistent
across machines. Pure Bash, no runtime dependencies beyond `git` and coreutils.

![Test Dotfiles](https://github.com/jdubba/dotfiles/workflows/Test%20Dotfiles/badge.svg)

## Why this instead of GNU Stow / chezmoi?

- **Changes apply by syncing.** Managed files are symlinks into the repo, so
  `git pull` takes effect immediately (a git hook re-links when new files
  appear). No separate "apply" step.
- **Live edits are already staged.** Editing `~/.config/nvim/init.lua` edits the
  repo file directly; `git add` stages it. No "re-add" step.
- **Machine-specific config without a sledgehammer.** 90%+ of config is shared
  and costs zero ceremony; only what actually differs goes in a profile or host
  layer.
- **It cannot eat your `~/.config`.** The failure mode that motivated this tool
  (Stow folding `~/.config` into one symlink and absorbing every app's writes)
  is structurally impossible here — see [Safety](#safety-guarantees).

## The model

Three layers are linked into `$HOME`, in order (later layers add to / override
earlier ones). Only `home/` is required; the others exist only where you
actually diverge.

```
home/                 shared config - the 90%+ that never varies
profiles/<name>/      shared across LIKE machines (e.g. hyprland, gnome, fedora)
hosts/<hostname>/     truly per-machine bits (e.g. monitor layout)
```

A file's path under a layer mirrors its destination under `$HOME`:
`home/.config/nvim/init.lua` → `~/.config/nvim/init.lua`, `home/.gitconfig` →
`~/.gitconfig` (files outside `~/.config` are handled identically).

## Install

```bash
git clone https://github.com/jdubba/dotfiles.git ~/source/dotfiles
cd ~/source/dotfiles
make install          # symlink `dotfiles` onto your PATH + install the git hook
dotfiles status       # preview what will be linked (read-only, no changes)
dotfiles link         # apply
```

`dotfiles` runs from the repo checkout; `make install` just adds a convenience
symlink at `~/.local/bin/dotfiles`. Ensure `~/.local/bin` is on your `PATH`.

## Commands

| Command | Description |
|---|---|
| `dotfiles status [-v]` | Show what `link` would do, plus drift. **Read-only.** |
| `dotfiles link [--dry-run] [-v]` | Create/repair symlinks for this machine. Idempotent. |
| `dotfiles doctor [--fix]` | Detect/repair hazards (folded containers, broken links). |
| `dotfiles add <path> [--to home\|host\|profile:<name>]` | Adopt an existing file/dir into the repo and link it back. |
| `dotfiles sync [--no-link]` | `git pull --ff-only` then `link`. |
| `dotfiles profile list\|enable\|disable <name>` | Manage machine-local profile selection. |
| `dotfiles dconf dump\|load [keyfile]` | Snapshot/apply GNOME dconf settings. |
| `dotfiles hook install\|uninstall` | Manage the `git pull` auto-link hook. |
| `dotfiles info` | Show detected identity and active layers. |

### Adding a config

```bash
dotfiles add ~/.config/foot                 # -> home/ (shared), symlinked back
dotfiles add ~/.config/hypr/monitors.conf --to host      # -> hosts/<hostname>/
dotfiles add ~/.tmux.conf                   # files outside ~/.config work too
git -C ~/source/dotfiles add -A && git commit
```

`add` is the **only** operation that moves files into the repo, and it is always
explicit. `link`/`sync` never adopt anything.

## Machine-specific configuration

Two lightweight mechanisms, used only where needed:

**1. Layers.** Put shared config in `home/`. Put config common to a class of
machines in `profiles/<name>/` (auto-activated when the name matches your distro
id, distro family, or desktop — e.g. `fedora`, `hyprland`, `gnome` — or enable
it explicitly with `dotfiles profile enable <name>`). Put per-machine files in
`hosts/<hostname>/`. When two layers contribute to the same directory, that
directory is kept real and each file is linked individually.

**2. Native includes** for a single file that is *mostly* shared. Instead of
templating, have the shared file pull in a small per-host fragment:

```ini
# home/.config/hypr/hyprland.conf  (shared, identical everywhere)
source = ~/.config/hypr/monitors.conf
```
```ini
# hosts/<hostname>/.config/hypr/monitors.conf  (this machine only)
monitor = DP-1, 3840x2160@144, 0x0, 1
```

The same pattern works for git `[include]`, SSH `Include`, etc.

## GNOME / dconf

GNOME settings live in dconf, not files, so they can't be symlinked. Keep a
keyfile in the repo instead:

```bash
dotfiles dconf dump                 # snapshot live settings -> profiles/gnome/dconf/user.ini
git -C ~/source/dotfiles commit -am 'update gnome dconf'
dotfiles dconf load                 # on another machine: apply the keyfile
```

## Safety guarantees

Each is covered by the test suite (`tests/link.bats`):

1. **Container directories are never folded.** `~/.config`, `~/.local[/*]`,
   `~/.cache`, `~/.ssh`, `~/.gnupg`, … are always real directories; only their
   managed children are linked. (Extend the list in `dotfiles.conf`.)
2. **No implicit adoption.** `link` only creates links the repo defines; it
   never pulls target files into the repo. Adoption is `add`-only.
3. **Never clobbers.** A real file/dir the repo doesn't own is reported as a
   CONFLICT and left untouched — nothing is overwritten.
4. **Plan-first & idempotent.** Every change is previewable (`status` /
   `--dry-run`); re-running is a no-op.
5. **`doctor` repairs the classic hazard** — a container that became a repo
   symlink is restored to a real directory.

## Development

```bash
make test     # BATS suite (auto-installs bats-core locally if needed)
make lint     # shellcheck
make all      # lint + test
```

## Repository layout

```
bin/dotfiles          CLI entrypoint
lib/*.sh              core, config, identity, linker
lib/commands/*.sh     one file per subcommand
hooks/post-merge      git hook (installed via `dotfiles hook install`)
dotfiles.conf         optional repo config (extend container set, ignore names)
home/ profiles/ hosts/ the layers
tests/*.bats          test suite
```
