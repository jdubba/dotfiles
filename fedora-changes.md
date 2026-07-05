# fedora-changes.md — TEMPORARY working document

> **Do not merge to `main`.** This file exists only to give the stationzebra
> agent full context while reviewing the `fedora-hyprland-setup` branch. Delete
> it once the changes are reconciled/host-scoped.

This branch contains everything done to bring up **Hyprland alongside GNOME** on
the `fedora` host, plus root-cause analysis. The review question is: **which of
these shared-layer changes are safe to land on `main`, and which must be
host-scoped so they don't regress stationzebra?**

---

## 1. The machine

- **Host:** `fedora` — Fedora Linux 43 Workstation; GNOME 49 on Wayland via **GDM**.
- **Hardware:** Intel Core Ultra 7 258V (Lunar Lake), Intel Arc 140V (Xe2),
  32 GB RAM, single internal panel **eDP-1 @ 2880×1800**. Mesa 25.3.6, kernel 7.0.10.
- **Goal:** pick GNOME *or* Hyprland at the GDM login screen. GNOME left untouched.

## 2. What was installed (system packages — NOT in dotfiles)

- **COPR:** `solopasha/hyprland` is effectively unmaintained for F43 (last builds
  ~Oct 2025). Used **`lionheartp/Hyprland`** instead (actively maintained, daily builds).
- **dnf (COPR):** hyprland 0.55.4, hyprlock, hypridle, hyprpaper, hyprpolkitagent,
  hyprcursor, xdg-desktop-portal-hyprland. Note: this also pulls `uwsm` +
  `hyprland-uwsm` (adds a second "Hyprland (uwsm-managed)" GDM entry — we use the
  plain "Hyprland" one).
- **dnf (Fedora):** waybar, Thunar, kanshi, mako, grim, slurp, swappy, playerctl,
  brightnessctl, blueman, pavucontrol.
- **Built from source into `~/.local/bin` (this is the crux — see §3):**
  - **walker v2.16.2** — now a **Rust/GTK4** app (not Go). Needed `cargo` +
    `gtk4-layer-shell-devel` + `poppler-glib-devel`. Its `build.rs` declares
    `protoc-bin-vendored` but doesn't wire it in, so `protoc` must be on PATH at
    build time (used the vendored one via a temp PATH entry).
  - **elephant** (Go) + 8 provider plugins (`.so`, `go build -buildmode=plugin`)
    into `~/.config/elephant/providers/`: calc, clipboard, desktopapplications,
    files, providerlist, runner, symbols, websearch.
    (`~/.config/elephant/` is a real dir; only `providers.list` is a repo symlink,
    so the built `.so` stay out of the repo.)

## 3. Root cause of the runtime breakage — READ THIS FIRST

**Fedora/GDM launches the plain "Hyprland" session (`/usr/bin/start-hyprland`,
a crash-restart watchdog) inside a PAM `session.scope` — not under `user@.service`.**
That launch:

1. **does not run a login shell**, so `home/.config/shell/env.sh` (which adds
   `~/.local/bin` to PATH) never runs → the session PATH is a bare
   `/usr/local/bin:/usr/bin`; and
2. **does not import the session environment into the systemd `--user` manager**
   (so units don't see `WAYLAND_DISPLAY` / `XDG_CURRENT_DESKTOP`).

Because **only `walker` and `elephant` live in `~/.local/bin`** (everything else
the configs call — ghostty, thunar, hyprlock, wpctl, grim, … — is in `/usr/bin`),
the fallout was confined to walker/elephant:

- `exec-once = elephant` / `exec-once = walker --gapplication-service` silently
  failed (binaries not on Hyprland's PATH) → neither started at login.
- `Super+R` (`walker`) and the Waybar arch icon (`walker -m …`) couldn't find `walker`.
- Once walker ran as a service, its `has_elephant()` = `which("elephant")` returned
  false (elephant not on the service's PATH) → it printed `Please install elephant.`
  and exited on every activation.

**On stationzebra the identical configs work** because its launch mechanism
(system-level, not tracked in the repo — no `uwsm`, login-shell exec, or DM config
is in the dotfiles) evidently provides a **login-shell PATH** (`~/.local/bin`
present) and imports the env into systemd. **So this is a session-launch
difference, not a Gentoo-vs-Fedora userland difference.** The distro-specific part
is only *packaging* (Rust walker, COPR, source builds).

## 4. Changes on this branch, by layer

### `hosts/fedora/` — host-only, safe for stationzebra ✅
- `.config/kanshi/config` — single-display profile for `eDP-1` (2880×1800@60,
  scale 1.6). stationzebra keeps its own dock profile.
- `.config/shell/machine-env` — `AWS_PROFILE=idkey`.

### `home/` + `profiles/hyprland/` — SHARED, will affect stationzebra ⚠️
1. **`home/.config/hypr/hyprland.conf`:**
   - Added `env = PATH,$HOME/.local/bin:$HOME/.cargo/bin:$HOME/go/bin:/usr/local/bin:/usr/bin:/usr/local/sbin:/usr/sbin`
     — compensates for GDM's minimal session PATH; the existing
     `dbus-update-activation-environment` line then propagates it to systemd.
     ⚠️ **Overrides stationzebra's PATH** (could drop Gentoo/`/opt` entries).
   - Prepended `dbus-update-activation-environment --systemd --all && ` to the
     `systemctl --user start hyprland-session.target` line — imports the session
     env into systemd `--user` (needed for Wayland services + the guards below).
     Idempotent; likely benign on stationzebra.
   - Added `exec-once = hyprpaper` and
     `exec-once = systemctl --user start hyprpolkitagent.service` (neither was
     autostarted before).
   - **Removed** `exec-once = elephant` and `exec-once = walker --gapplication-service`
     (replaced by the services below). ⚠️ **stationzebra relied on these.**
2. **`profiles/hyprland/.config/systemd/user/elephant.service`** (new) —
   `ExecStart=%h/.local/bin/elephant`, `After=graphical-session.target`,
   `Restart=on-failure`, **`ConditionEnvironment=XDG_CURRENT_DESKTOP=Hyprland`**.
3. **`profiles/hyprland/.config/systemd/user/walker.service`** (new) —
   `ExecStart=%h/.local/bin/walker --gapplication-service`,
   `After=/Wants=elephant.service`, **`ConditionEnvironment=XDG_CURRENT_DESKTOP=Hyprland`**.
4. **`profiles/hyprland/.config/systemd/user/kanshi.service`** — **added**
   `ConditionEnvironment=XDG_CURRENT_DESKTOP=Hyprland` (it was guard-free before).
5. **`profiles/hyprland/.config/systemd/user/waybar.service.d/hyprland-only.conf`**
   (new) — drop-in adding `ConditionEnvironment=XDG_CURRENT_DESKTOP=Hyprland` to
   Fedora's packaged `waybar.service`.
6. **`.gitignore`** — ignore `profiles/hyprland/.config/elephant/providers/`.

## 5. ⚠️ Cross-machine impact — the actual review focus

The **`ConditionEnvironment=XDG_CURRENT_DESKTOP=Hyprland` guards** (items 2–5) plus
the **removal of the `exec-once` elephant/walker fallbacks** are the risky changes.

- They exist because `fedora` runs **both GNOME and Hyprland via GDM**, and both
  reach `graphical-session.target`. Without the guards, waybar/kanshi/elephant/walker
  would also start *inside the GNOME session*. (Verified on fedora: guard makes them
  start under Hyprland and stay dormant under GNOME.)
- On stationzebra they are only safe **if `XDG_CURRENT_DESKTOP=Hyprland` is present
  in stationzebra's systemd `--user` environment.** If it is **not**, these services
  become `Condition`-blocked and won't start — and with the `exec-once` fallbacks
  removed there is no backup. That would regress a currently-working machine (kanshi
  drives stationzebra's dual-external-monitor dock).

### Verify on stationzebra before landing on `main`
```bash
# 1. Is the guard variable present in the systemd user env, and is PATH rich?
systemctl --user show-environment | grep -E '^(PATH|XDG_CURRENT_DESKTOP)='
# 2. How is Hyprland launched here? (DM? uwsm? TTY login-shell exec?)
loginctl                       # find the session, then:
# loginctl show-session <id> -p Type -p Service -p Scope
# 3. How do elephant/walker/waybar currently start on stationzebra?
systemctl --user is-enabled elephant.service walker.service waybar.service 2>&1
grep -nE 'elephant|walker|hyprpaper|PATH|dbus-update' ~/.config/hypr/hyprland.conf
```

### Recommended resolution (NOT yet applied)
Host-scope the Fedora/GDM glue so `main`/stationzebra stays byte-for-byte unchanged:
- Keep base units (`elephant`/`walker`/`kanshi`) **guard-free** in `profiles/hyprland/`.
- Put the `ConditionEnvironment` guards, `env=PATH`, and the env-import in
  **`hosts/fedora/`** — systemd drop-ins under
  `hosts/fedora/.config/systemd/user/<unit>.service.d/` and a small
  `hosts/fedora` Hyprland include `source`d from the shared `hyprland.conf`.
- Optionally revert elephant/walker to `exec-once` (matching stationzebra), since
  `env=PATH` already fixes the real root cause; keep them as services only if
  supervision is wanted (then the guards live in the host layer).

## 6. Current live state on fedora (all working)

GNOME and Hyprland both selectable at GDM. Under Hyprland: Waybar, wallpaper
(hyprpaper), kanshi (eDP-1), walker (`Super+R` = centered default theme; Waybar
arch icon = top-left via the `topleft` theme), hyprlock, screenshots, media/
brightness keys. GNOME session verified unaffected (guards keep the Hyprland
services dormant there).

## 7. Known follow-ups (separate from this branch)
- `~/.config/user-dirs.dirs` became a real file (a session tool,
  `xdg-user-dirs-update`, rewrote the repo symlink) → `dotfiles link` reports a
  CONFLICT. Reconcile with `dotfiles add` or restore the link.
- Optional: `libqalculate` (`qalc`) for elephant's `calc` provider.
- User mentioned additional "broken items" not yet triaged (the PATH root cause is
  now understood and only affected walker/elephant; other items TBD).
