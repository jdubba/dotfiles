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
  displays via a dock; **AMD** CPU → hwmon `k10temp`).
- Second machine: **`fedora`** (Fedora 43 Workstation, **Intel** Lunar Lake/Arc →
  hwmon `coretemp`). GNOME
  is the default DE with **Hyprland added alongside it** — both selectable at
  **GDM**; single internal display (`eDP-1`). GNOME is never modified.
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

## Layer placement (what goes where)

- `home/` — universal; applies to every machine. (Configs are symlinked even for
  software a given machine doesn't run — expected and harmless.)
- `profiles/<name>/` — shared across a *class* of machines (a desktop or distro):
  e.g. `hyprland`, `gnome`, `fedora`, `gentoo`. Auto-activates when the name
  matches the detected distro id/family or `$XDG_CURRENT_DESKTOP`.
- `hosts/<hostname>/` — one machine only.

**"Shared mechanism + per-host data" pattern** — put the generic, identical part
in `home/` or a profile; keep only the varying data per host:
- Monitors: `hyprland.conf` (in `home/`, deliberately **no** monitor/workspace
  lines) delegates to **kanshi** — whose *service* is shared
  (`profiles/hyprland`) and whose *config* is per-host (`hosts/<host>/.config/kanshi/`).
- machine-env: registry in `home/`, values in `hosts/<host>/`.

**Co-locate app-support scripts with the app** when they exist only to serve it
(waybar's helpers live in `waybar/scripts/`, referenced by absolute path from
`config.jsonc`) rather than in `~/.local/bin`. `~/.local/bin` is itself a
container, so adopting genuinely general-purpose scripts there is fine too.

**Do NOT track:**
- Build artifacts / compiled binaries (e.g. elephant `providers/*.so`). Track a
  manifest indicator (`providers.list`) and mark the dir a container via
  `dotfiles.conf` so the binaries can't be folded/adopted.
- systemd `*.wants/` enablement symlinks (machine-local; some point into
  `/usr/lib`). Re-enable per machine with `systemctl --user enable <unit>`
  (and `systemctl --user daemon-reload` after adopting a unit).
- Secrets (see Environment & scope).

### Current inventory (snapshot)

- `profiles/hyprland/` — `waybar/` (config + style + `scripts/{wifimenu,
  tailscalemenu,tailscale-status,oslogo,cputemp,thememenu}`);
  `walker/themes/{default,topleft,topright}`;
  `elephant/providers.list`; systemd `hyprland-session.target` + (guard-free)
  `kanshi.service` + `dotfiles-autotheme.service`.
- `hosts/stationzebra/` — `kanshi/` (config + `move-workspaces.sh`); systemd
  `rclone-onedrive.service` + `rclone-devsite.service`; `shell/machine-env`
  (`AWS_PROFILE=idkey`); empty `hypr/local.conf` stub.
- `hosts/fedora/` — `kanshi/config` (single `eDP-1`); `hypr/local.conf` (GDM
  session glue); `systemd/user/{kanshi,waybar}.service.d/hyprland-only.conf`
  (dual-session guards); `shell/machine-env`.
- `hyprland.conf` and the rest of `~/.config` still live in `home/`. Only waybar
  was relocated to `profiles/hyprland`; moving `hypr/` there too is a reasonable
  future cleanup.

## Code layout

- `bin/dotfiles` — CLI entrypoint and command dispatch.
- `lib/core.sh` — logging, colour, path helpers.
- `lib/config.sh` — defaults, the container-dir set, repo config, machine state.
- `lib/identity.sh` — hostname/distro/desktop detection, layer resolution.
- `lib/link.sh` — the linker: plan building, fold/unfold, apply. (Content
  reached *through* a folded parent symlink is treated as managed, so a
  fold→unfold transition relinks cleanly instead of reporting conflicts.)
- `lib/machine_env.sh` — machine-specific env registry/host-value parsing + analysis.
- `lib/commands/*.sh` — one file per subcommand (`link`, `status`, `doctor`,
  `add`, `sync`, `profile`, `env`, `dconf`, `hook`, `info`).
- `hooks/post-merge` — git hook that re-links after `git pull`.
- `dotfiles.conf` — optional repo config (extend `DF_CONTAINER_DIRS` / `DF_IGNORE_NAMES`).

## Shell configuration (bash + zsh share one core)

The shell config is itself modular, and the common parts are shared between bash
and zsh rather than duplicated:

- `home/.config/shell/` — **POSIX sh, shared by both shells**:
  - `env.sh` — XDG dirs, `EDITOR`/`VISUAL`, pager, `GCC_COLORS`, and the
    **idempotent PATH** builder (`_pathadd` = append IFF the dir exists and isn't
    already on `PATH`). It sources `~/.config/shell/path.d/*.sh` in filename order;
    core additions live in `home/.config/shell/path.d/00-core.sh` (`~/.local/bin`,
    `~/.cargo/bin`, `~/go/bin`, `~/.opencode/bin`, azure-cli). **Never rewrite
    `PATH` with a fixed list** — that clobbers per-machine entries (e.g. Gentoo's
    `/opt/bin`, llvm); PATH is core + additive. Add per-platform/host dirs by
    dropping another `path.d/*.sh` fragment in a profile or host layer. Sourced
    from `.zshenv` and the bash entrypoints. Must have **no side effects** (no
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
- **Machine-specific env vars** are declared in
  `home/.config/shell/machine-env.registry` (`VAR: description`) and given per-host
  values in `hosts/<host>/.config/shell/machine-env` (`KEY=VALUE`; `@skip` = "not
  relevant here"). `env.sh` exports the current host's values on startup; manage
  with `dotfiles env status|set|skip|add|unset`. `doctor` and `sync` report vars
  that are declared but unset-and-not-skipped on this host (cross-machine
  reconciliation). Values are committed in the host layer (non-secret only).
- **fzf integration loads portably.** `.zshrc`/`.bashrc` prefer `fzf --zsh` /
  `fzf --bash` (fzf >= 0.48 emits key-bindings + completion), then fall back to
  **guarded** per-distro script paths (`/usr/share/fzf/` on Gentoo/Arch,
  `/usr/share/fzf/shell/` on Fedora, `/usr/share/doc/fzf/examples/` on Debian).
  Never source a fixed distro path unguarded.

### Monitors / desktop specifics

- `hyprland.conf` carries **no static `monitor=` lines** and no workspace→monitor
  bindings; **kanshi** owns output geometry *and* workspace placement (via its
  `move-workspaces.sh`). kanshi config lives in the host layer
  (`hosts/stationzebra/.config/kanshi/`).
- GNOME settings are not files; manage them with `dotfiles dconf dump|load`
  (keyfile under `profiles/gnome/dconf/`).

## Hyprland session launch & the `fedora` host (GDM)

The biggest cross-machine difference is **how the compositor is launched**, which
determines its `PATH` and whether the session env reaches `systemd --user`:

- **stationzebra (Gentoo):** Hyprland starts from a **TTY login shell** → full
  login `PATH` (incl. `path.d`) and the session env is already in `systemd --user`.
- **`fedora` (GDM):** the plain "Hyprland" session (`/usr/bin/start-hyprland`) runs
  in a PAM `session.scope` **without a login shell** → minimal
  `PATH=/usr/local/bin:/usr/bin` and **no** import of the session env into
  `systemd --user`. All Fedora-specific glue exists to compensate for this.

Durable rules that follow from it:

1. **Install compositor-launched tools onto the minimal PATH.** `walker`/`elephant`
   are installed to **`/usr/local/bin`** (their makefiles default to
   `PREFIX=/usr/local`) so the shared `exec-once = elephant` /
   `exec-once = walker --gapplication-service` and the `walker` keybinds resolve
   under GDM's minimal PATH — same layout as stationzebra. **Never** add an
   `env = PATH,…` rewrite to shared config, and don't rely on `~/.local/bin` for
   anything the compositor launches by bare name under GDM.
2. **Per-host Hyprland include.** Shared `hyprland.conf` autostart sources
   `local.conf` (before it starts `hyprland-session.target`). Every host ships a
   `local.conf` — an **empty stub** where there's nothing to add.
   **Hyprland's `source=` does NOT expand `~` or `$HOME`.** Paths are relative
   to the config directory (`~/.config/hypr/`), so use bare filenames:
   `source = local.conf`.
3. **Fedora glue is host-scoped** in `hosts/fedora/`:
   - `.config/hypr/local.conf` — `dbus-update-activation-environment --systemd
     --all` (import the Wayland session env so units/guards see
     `WAYLAND_DISPLAY`/`XDG_CURRENT_DESKTOP`), plus `hyprpaper` + `hyprpolkitagent`
     autostarts (stationzebra gets these by other means).
   - `.config/systemd/user/{kanshi,waybar}.service.d/hyprland-only.conf` — the
     dual-session guard (see next point).
4. **Dual-session (GNOME + Hyprland via GDM):** both DEs reach
   `graphical-session.target`, so a `WantedBy=graphical-session.target` user
   service would start under **both**. Keep shared units **guard-free**
   (`profiles/hyprland/.config/systemd/user/kanshi.service`) and put the guard
   `ConditionEnvironment=XDG_CURRENT_DESKTOP=Hyprland` in the Fedora host drop-ins.
   Under Hyprland the units start; under GNOME the condition fails and they stay
   dormant. (`waybar.service` is the Fedora-packaged unit; the drop-in narrows it.)
5. **Packaging:** compositor + ecosystem from the **`lionheartp/Hyprland` COPR**
   (`solopasha/hyprland` is unmaintained for F43); waybar/kanshi/etc. from Fedora
   repos. **walker is Rust/GTK4** (v2, not Go): build needs `cargo` +
   `gtk4-layer-shell-devel` + `poppler-glib-devel`, and its `build.rs` needs
   `protoc` on `PATH` (use the vendored `protoc-bin-vendored`). **elephant is Go**:
   build the binary + each provider as a plugin (`go build -buildmode=plugin` →
   `~/.config/elephant/providers/*.so`). walker requires elephant running (it
   `which("elephant")` and connects to its socket).
6. **After a `git pull` that touches systemd user units, run `systemctl --user
   daemon-reload`** — the `post-merge` hook re-links but does not reload, so new
   unit drop-ins won't take effect until reload (or next login, where
   `systemd --user` starts fresh).

## Fonts, Waybar & app configs (durable)

Making the **shared** configs render correctly on both Fedora and Gentoo taught
one theme: **be explicit and hardware/OS-agnostic; never lean on a machine's
defaults.**

- **Nerd Font glyphs get hijacked on Fedora.** Fedora ships fonts Gentoo does
  not — `adwaita-sans-fonts` (GNOME's UI font), `fontawesome-6-free-fonts`,
  `Jomolhari`, Noto symbols — that also cover the PUA ranges Nerd Font icons use.
  With a non-icon primary font (`font-family: "DM Sans", "JetBrainsMono Nerd
  Font"`), fontconfig's per-glyph fallback may pick one of those → **wrong glyph,
  not tofu**. Rules: (1) **name an installed Nerd Font in the CSS** (a named
  family beats system fallback); `JetBrainsMono Nerd Font` must be installed per
  machine (`~/.fonts` + `fc-cache` — it is a font, not repo content). (2) **only
  use codepoints that exist in a Nerd Font** — FontAwesome 5/6 glyphs like
  `\uf3ed` are in *no* Nerd Font (rendered as Jomolhari here); prefer
  Material-Design `nf-md-*` / Font-Logos `nf-linux-*`, codepoints from
  `ryanoasis/nerd-fonts` `glyphnames.json`. (3) **verify** with
  `fc-list ":charset=<hex>"` (coverage) and a Pango itemize
  (`PangoCairo.FontMap.get_default()` + the CSS family list) for *which* font
  actually renders — assumptions here cost multiple rounds.
- **Waybar helpers detect OS/hardware so one shared `config.jsonc` works
  everywhere** (`profiles/hyprland/.config/waybar/scripts/`):
  - `oslogo` → `/etc/os-release` `$ID` (then `$ID_LIKE`) → Font-Logos
    `nf-linux-*` glyph (Fedora/Gentoo/…), Tux fallback; backs the `custom/oslogo`
    launcher button (replaced the old hardcoded `custom/archicon`).
  - `cputemp` → probes `/sys/class/hwmon` by driver (`coretemp`/`k10temp`/
    `zenpower`/`cpu_thermal`) then the `x86_pkg_temp` zone; backs
    `custom/temperature`. **Do not** use waybar's built-in `temperature` default:
    it reads `thermal_zone0` = `acpitz` (a bogus **-273200** on Lunar Lake), and a
    static `hwmon-path` is not portable (Intel `coretemp` vs AMD `k10temp`).
  - `tailscale-status` → `nf-md-shield-check`/`shield-off` (present in Nerd
    Fonts), not the FA `shield-alt` (`\uf3ed`) that mis-rendered.
  - These are Python; `__pycache__/` and `*.pyc` are gitignored.
- **Waybar bluetooth:** `format-icons` has no `connected` state, so
  `format-connected: "{icon}"` renders **empty** when a device connects. Use a
  literal glyph for `format-connected`/`-battery`; list devices in the tooltip
  via `{device_enumerate}`.
- **Neovim `nvim-treesitter` is pinned `branch = "main"`** (the v1.x rewrite:
  `require("nvim-treesitter").setup()/install()/indentexpr()`). Upstream's default
  branch is the now-archived `master`, whose module has **no `.install`** (→
  `attempt to call field 'install' (a nil value)`); and `lazy-lock.json` is
  gitignored/not synced, so the branch **must** be pinned in the spec or a fresh
  machine installs `master`. Needs recent Neovim + `tree-sitter` CLI + `cc` to
  build parsers.
- **`~/.config/user-dirs.dirs` is dotfiles-managed**, but `xdg-user-dirs-update`
  (login autostart `/etc/xdg/autostart/xdg-user-dirs.desktop`) rewrites it with an
  atomic temp-file+rename, replacing the symlink with a real file every login.
  Ship `home/.config/user-dirs.conf` with `enabled=False` to disable it (verified
  to block the rewrite even under `--force`). `user-dirs.conf` supports only
  `enabled` and `filename_encoding`; with the updater off, edit `user-dirs.dirs`
  directly.

## Theming (durable)

The theme system coordinates colours across every visual tool via a **theme
layer** (`themes/<name>/`, mirroring `$HOME`) injected between profiles and host
(`lib/theme.sh`, `lib/identity.sh`). Active-theme resolution precedence:

1. **machine-local auto flag** (`$XDG_STATE_HOME/dotfiles/auto-theme`) → `auto`
2. per-host override `hosts/<host>/.config/dotfiles/theme` (committed)
3. repo default `themes/default` (committed)
4. hardcoded fallback `catppuccin-mocha`

Manage with `dotfiles theme status|list|set|unset|auto`. `theme set` auto-runs
`link` then live-reloads; flags `--no-link`/`--no-reload`. Shipped themes:
`catppuccin-mocha`, `gruvbox-dark`.

**Seam design.** Each themed tool reads a stable path that only the active theme
layer provides, so switching themes is just a relink + reload. Seams (see
`lib/commands/theme.sh` `_df_theme_seam_source` and `theme status`):

- kitty `include current-theme.conf`; ghostty `theme = current`; tmux
  `source-file current-theme.conf`; hypr `source = current-theme.conf` (borders/
  hyprlock via `$vars`); waybar/walker `@import "colors.css"`.
- **starship** — full-file swap (no include mechanism); **opencode** — full-file
  `tui.json` (`theme` key; built-in `catppuccin`/`gruvbox`); **nvim** — data file
  `lua/dotfiles_theme.lua` read by `lua/plugins/colorscheme.lua`, which bundles
  every candidate colorscheme and applies the named one; **bat/fzf** — env vars
  from `shell/theme-env.sh` (sourced by `env.sh`); **wallpaper** —
  `~/.config/background` (hyprpaper + hyprlock both read it).
- A **home-layer fallback** exists for seams that would otherwise error when no
  theme is linked (e.g. `home/.config/hypr/current-theme.conf`).

**Durable gotchas:**
- **`_df_theme_reload` must not fire in tests.** The sandbox sets
  `DF_TARGET==HOME`, so the `!= HOME` guard is insufficient; `test_helper`
  exports `DF_NO_RELOAD=1` and the reloader honours it. Scripted use can set it.
- **hyprpaper/hyprlock DO expand `$HOME`** in `path` values (unlike hyprland's
  `source=`), so `path = $HOME/.config/background` is correct and portable.
- **hyprpaper 0.8.x IPC** dropped `preload`/`unload`/`listloaded`/`reload` (the
  `invalid hyprpaper request` error lives in `hyprctl`, not the daemon; NOT a
  version skew — 0.55.4 hyprctl ↔ 0.8.4 hyprpaper is a matched pair). Only
  `wallpaper "<mon>,<abspath>"` (loads+applies in one shot, optional
  `contain:`/`cover:`/`tile:` prefix) and `listactive` survive. `_df_theme_reload`
  pushes the new wallpaper live per-monitor
  (`hyprctl monitors | awk '/^Monitor /{print $2}'`, `wallpaper "$mon,$HOME/.config/background"`)
  — no daemon restart, works for both the systemd-service (stationzebra) and
  exec-once (Fedora) setups. Persistence is via `hyprpaper.conf`'s `path=` (read
  on start); there is no config-reload IPC, so only a structural `hyprpaper.conf`
  change needs `systemctl --user restart hyprpaper.service`.

**Auto-theming** (`dotfiles theme auto`, `lib/theme-auto.sh`) derives a palette
from the wallpaper and generates the whole `themes/auto/` tree (gitignored).
Full detail + the GNOME/KDE detection backlog live in **`docs/auto-theming.md`**.
Key points:
- Palette backend preference **wallust → pywal → bundled python+Pillow**
  (`lib/theme-auto/palette.py`); the active backend is reported and a lesser one
  triggers an "install wallust" notice. The core tool stays dependency-free;
  auto-theming is the one feature with an optional external dependency.
- Auto themes: nvim uses generated **base16** (`RRethy/base16-nvim`), bat uses
  `ansi`, opencode uses `system` — i.e. follow the themed terminal where a named
  theme is otherwise required.
- Continuous mode is a **polling** systemd user service
  (`profiles/hyprland/.config/systemd/user/dotfiles-autotheme.service`,
  guard-free; Fedora adds the `XDG_CURRENT_DESKTOP=Hyprland` drop-in). Enabled
  only via `theme auto enable` (which runs `daemon-reload`). Loop-guard: the
  generated wallpaper copy's hash matches the last processed source.
- `DF_WALLPAPER=<image>` overrides detection for a single run (unsupported DEs).

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
dotfiles env set AWS_PROFILE <value>   # machine-specific env vars
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
8. Keep commits **focused** (one concern each) and descriptive; use `git mv` for
   relocations so history is preserved. **Push only when explicitly asked.**

## Testing

BATS (Bash Automated Testing System). `./test.sh` bootstraps `bats-core` locally
if it isn't already installed, then runs `tests/*.bats`. `tests/repo.bats`
syntax-checks shipped config in all three dialects — `bash -n`, `sh -n`, and
`zsh -n` (the zsh checks skip when zsh isn't installed).
