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
- **git identity**: all of `.gitconfig` is shared in `home/` except `[user]`,
  which is a per-host include (`hosts/<host>/.config/git/identity`) — work
  machines commit as the corporate address, personal ones as `jdubba`. Include
  order in `.gitconfig` is load-bearing: `~/.gitsigning` (untracked signing key)
  first, then the host identity, then an
  `includeIf "gitdir:~/source/dotfiles/"` → `~/.config/git/identity-dotfiles`
  that pins **this public repo** to `jdubba` on every machine so a work address
  can't leak into its history. Last include wins. `identity-dotfiles` lives in
  `home/` precisely because it must be identical everywhere. Adding a host means
  adding its `identity` file, or git falls back to guessing.

**Co-locate app-support scripts with the app** when they exist only to serve it
(waybar's helpers live in `waybar/scripts/`, referenced by absolute path from
`config.jsonc`) rather than in `~/.local/bin`. `~/.local/bin` is itself a
container, so adopting genuinely general-purpose scripts there is fine too.

**Do NOT track:**
- Build artifacts / compiled binaries (e.g. elephant `providers/*.so`). Track a
  manifest indicator (`providers.list`) and mark the dir a container via
  `dotfiles.conf` so the binaries can't be folded/adopted.
- opencode's own state under `~/.config/opencode` (`node_modules`,
  `package.json`/`package-lock.json`, `.gitignore`) and machine-local, unmanaged
  content such as `agent/`. Only `opencode.jsonc` (**host layer** — its MCP
  servers are per-machine: corporate endpoints, `AWS_PROFILE`-keyed servers;
  `home/` carries only a schema-only stub, which any host file shadows) and
  `tui.json` (theme seam, with a `home/` fallback) are managed; the dir is a
  container in `dotfiles.conf` so the rest can't be folded into the repo or
  adopted.
- systemd `*.wants/` enablement symlinks (machine-local; some point into
  `/usr/lib`). Re-enable per machine with `systemctl --user enable <unit>`
  (and `systemctl --user daemon-reload` after adopting a unit).
- Self-rewriting configs: `nvim/lazy-lock.json` and `btop/btop.conf` (btop
  rewrites it on exit through its symlink into the home layer) — both gitignored,
  like machine-local state. **`.config/btop` and `.config/btop/themes` are both
  container dirs** (`dotfiles.conf`) precisely because the set of layers owning
  them varies with the active theme: a theme shipping
  `.config/btop/themes/current.theme` makes that layer sole owner of `themes/`,
  while a theme *without* the seam leaves the home layer sole owner of
  `.config/btop`. Either way the sole-owner dir gets folded, and the fold
  collides with the real directory the previously active theme left behind →
  `CONFLICT` → the whole theme switch aborts. As containers, only `btop.conf`
  and `themes/current.theme` are linked, as individual children.
- Secrets (see Environment & scope).

### Current inventory (snapshot)

- `profiles/hyprland/` — `waybar/` (config + style + `scripts/{wifimenu,
  tailscalemenu,tailscale-status,oslogo,cputemp,thememenu,theme-status}`);
  `walker/themes/{default,topleft,topright}`;
  `elephant/providers.list`; systemd `hyprland-session.target` + (guard-free)
  `kanshi.service` + `dotfiles-autotheme.service`.
- `hosts/stationzebra/` — `kanshi/` (config + `move-workspaces.sh` +
  `dock-{layout,monitor}.sh` for the LG TV dock: workspaces 1-3 left TV, 4-6
  middle TV, 7-10 eDP-1 at the far right); systemd `dock-monitor.service` +
  `rclone-onedrive.service` + `rclone-devsite.service`; `shell/machine-env`
  (`AWS_PROFILE=idkey`); `hypr/local.conf`; `hypr/hyprlock-local.conf`
  (per-host hyprlock auth seam — fingerprint stub, no sensor confirmed).
- `hosts/fedora/` — `kanshi/config` (single `eDP-1`); `hypr/local.conf` (GDM
  session glue); `hypr/hyprlock-local.conf` (per-host hyprlock auth seam —
  fingerprint stub, no sensor confirmed);
  `systemd/user/{kanshi,waybar}.service.d/hyprland-only.conf`
  (dual-session guards); `shell/machine-env`.
- `hosts/cltc-aus-lws03/` — Fedora laptop (GNOME + Hyprland from GDM); `kanshi/`;
  `hypr/local.conf` (GDM session glue + rigid workspace→monitor binding);
  `hypr/hyprlock-local.conf` (per-host hyprlock auth seam — **native fingerprint
  enabled**: Goodix MOC + enrolled print; requires the password-only
  `/etc/pam.d/hyprlock` — see `docs/hyprlock-auth.md`);
  `systemd/user/*.service.d/hyprland-only.conf` guards; `shell/machine-env`;
  `opencode/opencode.jsonc` (work MCP servers: internal msgraph endpoint +
  AWS-docs server keyed off `AWS_PROFILE`).
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
- `home/.config/shell/completions/dotfiles.bash` — the `dotfiles` CLI tab
  completion. A **single bash-completion-style script** (one `_dotfiles`
  function + `complete -F`) sourced by **both** shells: directly from `.bashrc`,
  and from `.zshrc` *after* `bashcompinit` (which lets zsh run bash completion
  functions). Static command/subcommand/flag structure is inline; dynamic
  candidates (theme/profile/machine-env names) are fetched live by shelling out
  to the tool's own `<cmd> list --plain` helpers (`theme list --plain`,
  `profile list --plain`, `env list`), so new themes/profiles appear with no
  extra wiring. Add it to `lint.sh`'s sanity loop and `repo.bats`' `bash -n`
  check when touching it.
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
- **The `dotfiles` CLI completion is one bash-completion script for both shells.**
  zsh runs it through `bashcompinit`, whose `_bash_complete`/`compgen` invoke the
  `_dotfiles` function under `emulate -L sh` (so `COMP_WORDS`/`COMP_CWORD` are
  0-indexed just like bash) — hence a single `complete -F`-style definition works
  in both. It **must** be sourced *after* `bashcompinit` in `.zshrc`. Keep it
  shellcheck-clean (`COMPREPLY=( $(compgen …) )` needs a `# shellcheck
  disable=SC2207`; `mapfile` is unavailable under bashcompinit, so don't use it).
  Dynamic candidates come from the tool's `<cmd> list --plain` helpers, which
  print bare names to **stdout** (the rich `list` views print to stderr).
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
- **The LG TV docks are not kanshi profiles** (stationzebra, cltc-aus-lws03): both
  TVs ship the same EDID with a placeholder serial, so only their live connector
  names can order them. `dock-layout.sh` sorts those and applies geometry *and*
  the workspace pins via `hyprctl keyword` at runtime; `local.conf` positions the
  outputs `auto`. Two consequences to respect:
  - **Each `hyprctl keyword monitor` re-resolves every position still set to
    `auto`**, pushing them to the right of the new rightmost monitor. Set the TVs
    first and eDP-1 (far right) last, or eDP-1 drags the TVs off past it.
  - **A config reload discards all of it** — `hyprctl reload` from a theme switch,
    or Hyprland's autoreload when `local.conf` is edited — so the layout silently
    reverts to eDP-1-leftmost with no workspace pins on the TVs. `dock-monitor.sh`
    therefore handles `configreloaded` as well as `monitoradded`, re-applying when
    `layout_is_applied` reports drift. `keyword` commands do **not** emit
    `configreloaded`, so the re-apply cannot loop.
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
    `source = local.conf`. hyprlock has its **own** separate per-host seam,
    `source = hyprlock-local.conf` (host `auth {}` block: native fingerprint +
    PAM) — `local.conf`'s hyprland-only directives are invalid in hyprlock, so it
    needs a distinct file; every host ships a real `hyprlock-local.conf` (stub
    where there's no sensor). Enabling native fingerprint **requires** the host's
    `/etc/pam.d/hyprlock` be password-only first — see `docs/hyprlock-auth.md`.
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

> **Polishing a theme with the user? Read
> [`docs/theming-agent-guide.md`](docs/theming-agent-guide.md) first.** This
> section is the *reference* — mechanisms, palette-slot traps, accumulated
> gotchas. That guide is the *process*: the propose → measure → apply → render →
> discuss → commit loop, the slot-name shorthand the user speaks in, what to ask
> at each seam and in what order, the wallpaper workflow, and how to prove a
> change actually rendered.

The theme system coordinates colours across every visual tool via a **theme
layer** (`themes/<name>/`, mirroring `$HOME`) injected between profiles and host
(`lib/theme.sh`, `lib/identity.sh`). Active-theme resolution precedence:

1. **machine-local auto flag** (`$XDG_STATE_HOME/dotfiles/auto-theme`) → `auto`
2. **machine-local selection** (`$XDG_STATE_HOME/dotfiles/theme`) — what
   `theme set`/`unset` write; kept out of the repo so switching causes no churn
3. per-host committed override `hosts/<host>/.config/dotfiles/theme` (optional,
   synced fallback; hand-edit if you want a per-host default in git)
4. repo default `themes/default` (committed)
5. hardcoded fallback `catppuccin-mocha`

Manage with `dotfiles theme status|list|set|unset|auto`. `theme set` records the
selection in **machine-local state** (never the repo) then auto-runs `link` and
live-reloads; flags `--no-link`/`--no-reload`. `theme unset` clears the
machine-local selection (falling back to the committed override/default).
Scriptable helpers `theme list --plain` (names to stdout) and `theme name`
(resolved active theme) back the waybar switcher pill (`custom/theme` →
`scripts/thememenu` menu + `scripts/theme-status` tooltip). ~40 curated themes
ship (Catppuccin ×4, Tokyo Night ×4, Rosé Pine ×3, Kanagawa ×3, Ayu ×3,
Nightfox ×5, Gruvbox/Solarized/Everforest/GitHub ×2, Nord, Dracula, One Dark,
Monokai/-Pro, Material, Oxocarbon, Melange, Zenburn, Palenight, …).

**Themes are generated, not hand-authored.** `tools/build-themes.sh` holds a
registry (official/canonical 16-colour palette + integration metadata per theme)
and drives the shared emitter `df_theme_emit_seams` (in `lib/theme-auto.sh`,
also used by auto-theming) to (re)generate `themes/<name>/`. Re-run it after
changing a palette or the seam format; it's idempotent and preserves any real
drop-in wallpaper (`themes/<name>/.config/background`). nvim uses the
catppuccin/gruvbox plugins where a flavour/background exists, else a generated
base16 palette (`RRethy/base16-nvim`); bat uses a bat built-in where one exists,
else `ansi`; opencode uses a built-in theme where one exists, else `system`.
Wallpapers without a real drop-in are generated as a subtle palette gradient
(`lib/theme-auto/wallpaper.py`). It also refreshes `docs/palettes/` at the end
(skipped without python3).

**Open `docs/palettes/<theme>.html` before tuning a theme** — one swatch page per
theme (`docs/palettes/index.html` lists all 40), generated by
`tools/build-palette-pages.py` from the shipped seams. Each shows the palette
with its **slot names**, the seams derived from it, every text pair measured, and
the palette's own quirks spelled out (dawnfox: "fg, c7, c15 are all `#575279`;
c0 is all but the background"). The slot names are the point: `c11` for the
inactive dot is an instruction, `#c47b28` is not — steering a theme by hex is
miserable and these exist to make the palette speakable. `build-themes.sh`
regenerates them, and `tests/palette-pages.bats` fails if they drift.

**Real wallpaper art comes from `new-wallpaper`, not from hand-sourcing images.**
`~/.local/bin/new-wallpaper "<prompt>"` is a personal script (**not** in this repo
— machine-local, on `PATH`) that generates a wallpaper via AWS Bedrock (Stable
Image Ultra 16:9 → conservative upscale → ImageMagick normalise to exactly
3840x2160) and writes `~/pictures/wallpapers/<uuid>.jpg`. Curated per-theme
sources are kept alongside at `~/pictures/themes/<theme>.jpg`. Do **not** confuse
it with `lib/theme-auto/wallpaper.py` above, which only draws the gradient
placeholder. Notes:
- It needs a live AWS SSO session (`AWS_PROFILE=idkey` on stationzebra); an
  expired token can only be renewed by the user (`aws sso login --profile idkey`).
- It ends with an interactive "set as desktop wallpaper?" prompt — answer **no**
  for a theme wallpaper. Persistence belongs to the theme system: drop the image
  at `themes/<name>/.config/background`, then `dotfiles theme set <name>`.
- Re-encode to ~1.5-2.0M (`magick <src> -quality 88`) to match the other real
  drop-ins before committing; the raw 4K output is ~2.5M.
- **Replacing an existing wallpaper needs `systemctl --user restart
  hyprpaper.service`.** The seam path is unchanged and only its *content* differs,
  so the `hyprctl hyprpaper wallpaper` push in `_df_theme_reload` re-serves the
  cached decode and the old image stays on screen. (A *theme switch* is fine —
  that changes the resolved path.)

**Hand-tuning goes in `tools/theme-overrides/<theme>/`, never in `themes/`.**
The emitter derives every seam from the 16-colour palette by formula, which a few
themes legitimately need to escape: an upstream-published base16 palette
(nightfox/ayu ship their own, which is *not* a remapping of the 16 ANSI slots), a
vendor's official ghostty file, a panel/accent colour that simply isn't in the
palette (ayu's `#E6B450`), or a deliberately different waybar pill assignment.
A further reason is **contrast**: the formula assigns pill and segment colours by
palette slot, not by luminance, so on some palettes it produces pairs that simply
cannot be read (gruvbox-dark's generated starship put the repo-root name at
1.33:1). Measure with WCAG contrast before and after when tuning for this.
An override is a whole file mirroring its path under `themes/<name>/`, overlaid
after emission by `apply_overrides`. Currently the 9 "polished" themes
(`ayu-{dark,light,mirage}`, `carbonfox`, `catppuccin-{frappe,latte}`, `dracula`,
`gruvbox-{dark,light}`) carry 36 between them. Adding one is a decision to
maintain that file by hand — it stops tracking palette and seam-format changes —
so add one deliberately rather than by habit.

**An override that diverges from the default is not drift.** The generated
assignment is a *default*, and a theme is free to want something else entirely —
a full rainbow across the pills, or a different alignment of roles to hues. So
when an emitter change lands, do not treat the themes it cannot reach as lagging
behind or reconcile them to match: note that they keep their own treatment and
leave them alone unless asked. Retiring an override is only obvious when it
exists *solely* to work around something the formula has since learned to
express.
**Editing `themes/` directly is always wrong**: the next `build-themes.sh` run
silently reverts it.

**Seam design.** Each themed tool reads a stable path that only the active theme
layer provides, so switching themes is just a relink + reload. Seams (see
`lib/commands/theme.sh` `_df_theme_seam_source` and `theme status`):

- kitty `include current-theme.conf`; ghostty `config-file = themes/current`
  (a direct include, NOT `theme = current` — ghostty's gtk-single-instance
  daemon caches named themes and won't hot-reload when the file behind the name
  changes; a `config-file` include is re-read and applied on `SIGUSR2` reload);
  tmux
  `source-file current-theme.conf`; hypr `source = current-theme.conf` (borders/
  hyprlock via `$vars`); waybar/walker `@import "colors.css"`.
- **starship** — full-file swap (no include mechanism); **opencode** — full-file
  `tui.json` (`theme` key; built-in `catppuccin`/`gruvbox`); **nvim** — data file
  `lua/dotfiles_theme.lua` read by `lua/plugins/colorscheme.lua`, which bundles
  every candidate colorscheme and applies the named one; **btop** — a named theme
  `themes/current.theme` selected once per machine by `color_theme = "current"`
  in the (gitignored) `btop.conf`, i.e. press `t` in btop; **bat/fzf** — env vars
  from `shell/theme-env.sh` (sourced by `env.sh`); **wallpaper** —
  `~/.config/background` (hyprpaper + hyprlock both read it).
- A **home-layer fallback** exists for seams that would otherwise error when no
  theme is linked (e.g. `home/.config/hypr/current-theme.conf`).

### Polishing a theme (durable)

*(Findings. For how to run the session itself — seam order, what to ask, the
shorthand — see [`docs/theming-agent-guide.md`](docs/theming-agent-guide.md).)*

**Measure, don't eyeball.** Compute WCAG contrast for every foreground/background
pair before and after. The emitter assigns colours by *palette slot*, not by
luminance, so it reliably produces unreadable pairs on some palettes — worst found
was gruvbox-dark's starship repo-root name at **1.33:1**. Targets: 4.5:1 for text,
3.0:1 for large/bold text and dots. Below 3.0 is a defect, not a taste question.

**Structural colour vs. content colour.** Chrome that should recede (btop
`meter_bg`/`div_line`/`inactive_fg`, empty workspace dots) belongs *below* 3:1
deliberately; only content needs to clear AA. Judge each pair by its role — a
blanket "raise everything" is as wrong as leaving a failure in place.

**Palette-slot assumptions that do not hold** (each cost a real bug):
- `c0` **is the background** in 8 of 41 palettes (gruvbox ×2, monokai/-pro,
  onedark, oxocarbon, palenight, zenburn), so anything using `c0` as a distinct
  surface vanishes there.
- A light palette's "bright" slots can be **darker** than its normal ones
  (gruvbox-light's `c12` `#076678` vs `c4` `#458588`) — the emitter takes the
  normal set regardless, which is backwards for a light bar where the pill must be
  the dark element.
- `c7` is **not** reliably a light grey on light palettes (gruvbox-light's is
  `#7c6f64`, dark), which is how btop's chrome ended up drawing heavy dark bars
  across a cream canvas.
- Mid-luminance accents cap out: nothing reaches 4.5:1 against `#458588` at any
  foreground. On a *saturated* surface only near-black/near-white inks are
  legible, so a vivid highlight and a legible one can be mutually exclusive — say
  so rather than silently picking one.

**Deriving colours generically.** `_df_theme_mix <base> <toward> <pct>` in
`lib/theme-auto.sh` is pure bash integer maths (the core tool stays
dependency-free — do not reach for python here). Two patterns that avoid a
light/dark branch entirely:
- mix the background **toward the foreground** for a surface tone — lifts a dark
  theme, deepens a light one;
- ramp a hue **toward `_dfa_contrast_fg` of the surface** for a state ramp — the
  ink flips with the surface, so one formula serves both polarities. The
  workspaces dots use this at 25/55/85, stops chosen by measuring all 41 palettes.

**waybar specifics established by that pass:**
- `window#waybar` draws `alpha(@bar-bg, 0.6)`. It was hardcoded to a dark slate,
  which every theme inherited — the single biggest cause of themes feeling alike.
- The **workspaces group is a pill**, not chrome. Previously all five `ws-*`
  variables came from achromatic slots (`c0`/`c7`/`c8`/`fg`/`fg`) while every hue
  went to pills, so the bar's centrepiece was the one module with no colour in
  any theme.
- **Accent assignment is drawn per theme, not fixed.** Both left pills and the
  primary right pill share one accent; workspaces and the theme switcher each get
  their own, distinct from it and each other; the battery is not themed at all.
  Which hue lands where comes from a **deterministic** draw — a Fisher-Yates
  shuffle over the five non-red hue families, seeded by `_df_theme_hash` over the
  theme name plus its hues. It must stay deterministic: `build-themes.sh` has to
  reproduce `themes/` byte-for-byte, so a real random source would rewrite all 40
  themes every run. Seeding on the palette as well as the name is what lets
  `theme auto` — always called `auto` — redraw when the wallpaper changes.
  Red is held out of the pool (error semantics elsewhere), and of each family's
  normal/bright pair the emitter takes whichever contrasts better with the bar.
- The **battery pill is deliberately un-themed** — the `batt-*` traffic-light
  palette in `style.css`, in every state, red through green. The emitter no longer
  emits `@pill-batt-*` at all; the 7 hand-written waybar overrides still carry the
  (now dead) lines.
- **`_dfa_contrast_fg` cuts at luminance 110, not the midpoint.** Its two inks sit
  at 20 and 240, so 150 was biased toward white text on mid-luminance accents, and
  WCAG's +0.05 offset pushes the real crossover lower than the 130 midpoint.
  Measured over every accent the shipped palettes use, 150 picked the worse ink 22
  times in 111 and 110 picks it twice.
- starship's template **used to share `color_fg_primary`** across the os,
  directory and git-status segments, which was a systemic contrast failure: that
  key is the palette's light text, and it was drawn on three *accent*
  backgrounds, so on any palette whose accents are mid-to-light it was
  light-on-light. A sweep found **all 40 themes** below AA on at least one pair
  (190 distinct), worst `github-light` drawing `#24292f` on `#24292f` — an
  invisible os/user segment — and `onedark`'s repo root at 1.00:1. The template
  now takes a per-segment ink (`color_os_fg`, `color_dir_fg`,
  `color_repo_change_fg`), each measured by `_dfa_pair_for` against its own
  background, and every *generated* theme clears 4.5:1. The 11 themes whose
  overrides pin the whole `starship.toml` keep their own values and are outside
  the emitter's reach — that is by design, not lag.
  `style_root` still breaks whenever `os_bg` becomes an accent (its ANSI yellow
  disappears) — repoint it at `color_red`.
- **`_dfa_pair_for <surface> <fg> <bg>`** returns a legible `surface ink` pair:
  it picks the ink first (palette fg, else bg, else the near-black/near-white),
  and only where the surface is mid-luminance and *no* ink reaches AA does it
  move the surface away from the ink's pole, capped at 25%. Every shipped palette
  that needed the escape cleared AA within 10% — a slight deepening of an accent,
  not a replacement. `_dfa_ink_for` is the ink-only half, for callers that must
  not touch the surface.
- **Do not use WCAG contrast on the starship powerline separators** — it is the
  wrong instrument and it produced a wrong conclusion here for a long time. A
  separator is a *filled shape*: one pill's background drawn as a `` glyph on
  the next pill's background. WCAG measures relative luminance only, which is
  correct for text (where hue cannot be relied on) and badly wrong for "are these
  two blocks distinguishable". dawnfox's os→directory cap measures **1.39:1** and
  is unmistakable — amber on plum, ~79 CIELAB ΔE apart.
  Measured both ways over the 240 shipped adjacencies: **108 fail WCAG 3:1, but
  only 35 fail ΔE 20.** This note used to cite the WCAG figure ("71 pairs") and
  conclude the whole class was cosmetic and only fixable by reassigning accents.
  That hid a real bug inside the noise for months.
  Use **`_dfa_rgb_dist`** for shape-vs-shape questions and `_dfa_contrast` only
  for text. `_dfa_rgb_dist` is Manhattan distance in sRGB, calibrated against
  CIELAB across every shipped palette (under ΔE 20 ⇒ ≤124; over ⇒ ≥144, a clean
  gap), because real CIELAB needs a cube root integer bash cannot do.
- **The os segment's leading cap was invisible on 8 palettes, now fixed.** It is
  drawn in `color_os_bg` on the terminal background, and `color_os_bg` is `c0` —
  which **is the background** in monokai, monokai-pro, onedark, oxocarbon,
  palenight and zenburn, so the cap rendered as nothing at all (ΔE 0), and sat
  within a few ΔE of it on a dozen more. It looked like a squared-off pill rather
  than a defect, and every sweep filed its 1.00:1 under "cosmetic separators".
  `_dfa_emit_starship` now lifts the os surface off the background
  (`_dfa_rgb_dist` ≥ 60, ≈ ΔE 10) before `_dfa_pair_for` picks the ink; the 21
  palettes whose `c0` already stands apart keep `c0` exactly. No zero-distance cap
  remains.
  What is genuinely left of this class is small and needs no framework: seven
  adjacent-pill pairs merge (`branch→changes` on gruvbox ×2, kanagawa-dragon and
  rose-pine-dawn; `changes→ahead/behind` on kanagawa-dragon and zenburn;
  `os→directory` on ayu-dark). Those are close in *both* hue and luminance, and
  fixing them really would mean reassigning accents as a sequence.
- **`hyprland/workspaces` has no `.occupied` class.** It marks the *empty*
  workspaces, not the occupied ones — the classes are `.active`, `.empty`,
  `.persistent`, `.visible`, `.special`, `.urgent`, `.hosting-monitor`. A
  `#workspaces button.occupied` rule therefore matches nothing, which is how
  `@ws-fg-occupied` went unrendered in every theme while empty and occupied dots
  both fell through to the base rule. `style.css` now carries the occupied ink on
  the base rule and dims it back down in `.empty`; `.active` must stay *after*
  `.empty`, as they share specificity and an active-but-empty workspace still has
  to read as active. Note `strings waybar | grep -x occupied` **does** hit, so the
  binary is not evidence the class exists — probe the live bar with sentinel
  colours instead.

**The emitter can measure contrast — use it.** `_dfa_contrast <a> <b>` in
`lib/theme-auto.sh` returns a real WCAG ratio scaled by 1000 (`4500` == 4.5:1),
backed by `_dfa_wcag_lum` and the 256-entry `_DFA_LIN` sRGB linearisation table.
Integer bash, no dependencies, because `theme auto` runs the emitter at runtime.
The table exists because WCAG's transform needs a 2.4 power shell arithmetic
cannot express; it agrees with a float implementation to ~0.001 in ratio terms.
Do **not** reach for `_dfa_lum` when the question is legibility — that is Rec.601
luma, useful only for the near-black/near-white ink choice in `_dfa_contrast_fg`.

Two long-standing defects came from the emitter assigning by palette slot with no
way to check the result, and both are now measured rather than assumed:

- **Workspace dots.** The occupied stop was a fixed 55% along a ramp starting from
  a *different* hue than the surface, so where the pill accent sat near the
  workspace surface in luminance the middle of the ramp landed on top of it — 16
  of 40 themes under the 3:1 dot target, worst `catppuccin-latte` at 1.29:1. The
  stop now starts at 55 and walks up until it measures 3:1 against the surface, so
  themes that already passed keep their exact colours; active keeps a 15-point
  lead to preserve the ordering, and empty stays fixed and faint because it is
  chrome.
- **The dots encode lit-ness, not prominence — empty is the *dimmest*, active the
  brightest, whatever the surface.** A dark dot means "nothing running here", and
  that reading does not flip with polarity. The ramp delivered it only by
  accident: it runs toward `_dfa_contrast_fg(surface)`, so a dark surface gets a
  near-white ink and the right order, while a **light** surface gets a near-black
  one and runs backwards — empty brightest, active nearly black. 31 of 40 shipped
  themes were inverted, 28 of them light-surface.
  Inverting the ramp on light surfaces is the wrong fix: brighter means *lower*
  contrast there, so it buys the ordering by making the active dot the least
  visible one. **The workspace surface is deepened below the ink cut instead**
  (luminance 110, the value `_dfa_contrast_fg` switches on), which dissolves the
  conflict rather than trading it — once the surface is dark, brightest and
  most-legible are the same dot.
  Two non-obvious constraints govern *how*. Deepen the **minimum** amount: on a
  dark theme the pill is squeezed between the ink cut and a bar background that is
  itself dark, so every step past the cut is separation given away (10% steps cost
  nord 17 points of `_dfa_rgb_dist`). And there is **no single best direction** —
  near-black keeps the accent's hue, but the palette's dark pole is the bar
  background on a dark theme, and which one lands further from the bar is
  per-palette (nord's bar has enough blue that mixing *toward* it preserves more
  blue separation than mixing toward black). The emitter tries each pole at 5%
  granularity and keeps whichever measures furthest from the bar.
- **Terminal selection.** `selection_foreground = fg` over `selection_background =
  c8` left selected text under 4.5:1 in 26 of 40 themes (`solarized-light` 1.21:1
  — selecting text made it invisible). `c8` is kept, being the palette's own
  selection tone, and the ink is chosen by measurement: `fg`, else `bg`, else the
  near-black/near-white that must work. Where `c8` is mid-luminance and no ink can
  clear 4.5 (5 palettes), the surface moves instead, mixing `c8` away from the
  `fg`'s own pole.

No shipped theme is now under either target — worst occupied 3.01:1, worst
selected text 4.53:1. **When adding a pairing to the emitter, measure it across
every palette rather than picking a constant that looks right on the theme in
front of you**; that is what both of these got wrong, and a sweep over
`themes/*/` catches it in seconds.

**An override pins a value, so emitter changes do not reach that theme.** After
changing the emitter, report which `tools/theme-overrides/*/` files hardcode what
you just changed, so the difference is visible — but treat that as information,
not a to-do list. Those themes keep their own treatment by design; see the
override note above. As of this writing `ayu-dark`, `ayu-mirage`, `carbonfox`,
`catppuccin-{frappe,latte}` keep achromatic workspaces, and `gruvbox-{dark,light}`
give the workspaces and switcher a shared hue — all deliberate.

**Verify by rendering, not by reading the file.** `starship prompt --status=0
--path=<dir>` prints real escape sequences — parse them to confirm which colours
actually resolved. For waybar/btop, `grim -o <output>` then sample pixels with
ImageMagick/PIL; note `hyprctl clients` reports **global** coordinates, so
subtract the monitor's `x`/`y` before cropping. For btop and walker, diff the
generated key set against the previous one — a typo'd key falls back silently
instead of erroring.

**Durable gotchas:**
- **A conflict anywhere in the plan must never abort a theme switch.**
  `df_apply_plan` returns 1 when the plan holds a CONFLICT, but by then the
  theme's links are already applied. Under `set -euo pipefail` a bare call
  therefore killed `theme set` *between* the relink and the reload — every tool
  kept the old colors, and Hyprland stayed stuck in the transient error state its
  autoreload hit while `current-theme.conf` was momentarily missing (`source=
  globbing error` + three `failed to parse $active_border as a color`). Symptom:
  "theme switching does nothing and hyprctl shows 4 errors"; `hyprctl reload`
  alone clears it, which is the tell that the config is fine and the *reload*
  never ran. `theme set`/`unset` and `df_autotheme_apply` capture the status
  (`df_apply_plan || apply_rc=$?`), reload, then `return "$apply_rc"`.
- **`tools/build-themes.sh` must reproduce `themes/` byte-for-byte.** It is the
  only thing standing between the generator and silently reverting committed
  theme work — which it did for months: the emitter never learned
  `@define-color ws-glow`, so every re-run dropped it from all 40 themes, along
  with the polished themes' pill/starship/base16 tuning.
  `tests/theme-build.bats` runs the real script against a throwaway copy of the
  repo and diffs the result, so any drift fails the suite. When it does, either
  teach the emitter the difference (if it generalises) or record it in
  `tools/theme-overrides/<theme>/` (if it doesn't) — never re-edit `themes/`.
- **Every theme must ship every seam.** A missing seam silently falls back to the
  home layer — and for `btop` it also changes which layers own `.config/btop`,
  which is what made the fold described above possible. `tests/repo.bats` asserts
  the full seam set for every `themes/*/` (except the generated `auto`), so a
  theme added by hand instead of via `tools/build-themes.sh` fails the suite.
- **`_df_theme_reload` must not fire in tests.** The sandbox sets
  `DF_TARGET==HOME`, so the `!= HOME` guard is insufficient; `test_helper`
  exports `DF_NO_RELOAD=1` and the reloader honours it. Scripted use can set it.
- **The waybar switcher pill (`scripts/thememenu`) runs the switch detached
  (`setsid`).** The reload sequence hits waybar (`killall -SIGUSR2 waybar`)
  *before* the terminals (kitty/ghostty come later), and reloading waybar kills
  its on-click child tree — a plain `&` background job dies mid-reload, so the
  terminals never recolour (theme switched but ghostty stale). `setsid` detaches
  it into its own session so it always completes. (CLI `theme set` isn't a
  waybar child, so it was never affected — a classic "reload killed the
  reloader".)
- **hyprpaper/hyprlock DO expand `$HOME`** in `path` values (unlike hyprland's
  `source=`), so `path = $HOME/.config/background` is correct and portable.
- **hyprpaper 0.8.x IPC** dropped `preload`/`unload`/`listloaded`/`reload` (the
  `invalid hyprpaper request` error lives in `hyprctl`, not the daemon; NOT a
  version skew — 0.55.4 hyprctl ↔ 0.8.4 hyprpaper is a matched pair). Only
  `wallpaper "<mon>,<abspath>"` (loads+applies in one shot) and `listactive`
  survive. It takes a **bare path only** — a `cover:`/`contain:`/`tile:` prefix
  is rejected outright (`error: bad path: cover:/home/…`), so the fit mode comes
  from `hyprpaper.conf` and cannot be set per-push. `_df_theme_reload`
  pushes the new wallpaper live per-monitor
  (`hyprctl monitors | awk '/^Monitor /{print $2}'`, `wallpaper "$mon,$HOME/.config/background"`)
  — no daemon restart, works for both the systemd-service (stationzebra) and
  exec-once (Fedora) setups. Persistence is via `hyprpaper.conf`'s `path=` (read
  on start); there is no config-reload IPC, so only a structural `hyprpaper.conf`
  change needs `systemctl --user restart hyprpaper.service`.
- **`fit_mode = fill` means STRETCH in hyprpaper, not "fill the screen".** Its
  parser is `if (sv.starts_with("fill")) return IMAGE_FIT_MODE_STRETCH;`
  (`src/ui/UI.cpp`), and the accepted set is `contain` / `cover` / `tile` /
  `fill`, defaulting to `cover`. The shared config said `fill` for a long time
  and therefore threw aspect ratio away on any output whose ratio differs from
  the image's. It was invisible on the 16:9 externals — the wallpapers are 16:9 —
  and only showed on eDP-1 at 16:10, where it distorts by 1.111x. Nothing warns:
  `fill` is a *valid* value, just the wrong one. Use **`cover`**, which crops the
  overflow instead. Verify with a round object: the dracula moon measures
  836x844 in the source and 618x624 on eDP-1, i.e. h/w 1.010 both, distortion
  1.000.

**Brave is aligned, not themed** (`_df_theme_brave_apply` in
`lib/commands/theme.sh` + `lib/theme-brave.py`). Chromium's custom-color theme is
a *seed*, not a palette: it derives the whole chrome from one colour via Material
You, so the bar accent (`@define-color pill-brand-bg`) plus the theme's polarity
is the entire input. This deliberately has **no seam of its own** — the accent is
read back out of the linked `waybar/colors.css` and the polarity out of
`nvim/lua/dotfiles_theme.lua` (`background = "dark"|"light"`), both of which every
theme including generated `auto` already ships. Adding a seam would mean an
emitter change plus regenerating all 41 themes for a cosmetic extra.
- Prefs live per profile in `~/.config/BraveSoftware/Brave-Browser/<Profile>/Preferences`
  (only `Default` is managed): `browser.theme.user_color2` is a **signed** 32-bit
  ARGB `SkColor`, `color_scheme2` is `1` light / `2` dark (`0` = system, verified
  by screenshotting both), `color_variant2` is the Material variant (left alone),
  and `extensions.theme.id = "user_color_theme_id"` is what selects custom-colour
  mode at all.
- **Brave must not be running when the write lands.** It holds prefs in memory,
  rewrites the file from that copy throughout the session *and on quit*, and never
  re-reads it — so a write while it is open is silently discarded, and there is no
  live-reload path like waybar/kitty. `_df_theme_brave_running` therefore checks
  `SingletonLock` (a symlink to `<host>-<pid>`, data-dir-specific, but it also
  outlives a crash → verify the pid is alive) and skips with a note; the change is
  reported as applying at the next launch.
- Neither key touched is in `Preferences`' `protection.macs` (which covers only
  `browser.show_home_button` and `extensions.install.*`, with no `super_mac`), so
  the external write does not trip Chromium's preference-tamper reset. Check this
  again if the set of keys ever widens.
- The `BrowserThemeColor` enterprise policy (`/etc/brave/policies/managed/`, and
  the string *is* in the shipped binary) is the alternative: it applies live and
  cannot be clobbered, but it needs a root-owned file outside `$HOME` — so outside
  the symlink farm — covers all profiles, and marks the browser "managed by your
  organization" with the picker disabled. Rejected for cosmetics.

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
