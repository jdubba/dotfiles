# fedora-handoff.md — TEMPORARY handoff (stationzebra agent → fedora agent)

> **Do not merge to `main`.** Working document for the `fedora-hyprland-setup`
> branch. Delete this and `fedora-changes.md` once the branch is finalized and
> ready to land. Everything below was done on this branch by the stationzebra
> agent, reconciling your changes so the branch can eventually land on `main`
> without regressing stationzebra.

## TL;DR

Your analysis was excellent and your §5 "recommended resolution" was exactly
right — I implemented it. The **shared layer is now byte-safe for stationzebra**,
and the Fedora/GDM-specific glue is **host-scoped under `hosts/fedora/`**. The one
change beyond your plan: PATH is now **additive** (a new `path.d` system), so the
`env = PATH,…` rewrite is gone entirely. Your remaining task is the real
root-cause fix — make the **session launch** give the compositor the additive
PATH (details in "Your remaining work").

---

## 1. What I changed on this branch

### Additive PATH (new — replaces the `env = PATH` rewrite)
- `home/.config/shell/env.sh` now sources `~/.config/shell/path.d/*.sh` instead of
  a hardcoded list. Each fragment calls `_pathadd` (append IFF the dir exists and
  isn't already present) — so PATH is **never rewritten**, only extended.
- `home/.config/shell/path.d/00-core.sh` — the core additions (`~/.local/bin`,
  `~/.cargo/bin`, `~/go/bin`, `~/.opencode/bin`, `~/.local/app/azure-cli/bin`).
- Per-platform/per-host additions: drop a `*.sh` fragment in a profile/host layer
  (`profiles/<name>/.config/shell/path.d/…` or `hosts/<host>/.config/shell/path.d/…`).
- **Why:** `env = PATH,<fixed list>` clobbered stationzebra's PATH — it dropped
  `/opt/bin` (Gentoo), `/usr/lib/llvm/*/bin`, `~/.opencode/bin`, azure-cli. PATH
  must be core + additive per machine/platform.

### `home/.config/hypr/hyprland.conf` (shared) — reverted to be machine-agnostic
- Removed the `env = PATH,…` line.
- Restored `exec-once = elephant` and `exec-once = walker --gapplication-service`
  (your §5 option — with the PATH fixed at the session level, exec-once works and
  supervision isn't required).
- Removed the Fedora-only `hyprpaper` / `hyprpolkitagent` autostarts and the
  `dbus-update-activation-environment` prefix from the shared file.
- Added `source = ~/.config/hypr/local.conf` (before the session target) — a
  **per-host Hyprland include**. Every host ships one; Fedora's carries the glue.

### Host-scoped to `hosts/fedora/`
- `.config/hypr/local.conf` — the env import (`dbus-update-activation-environment
  --systemd --all`, so the guards can see `XDG_CURRENT_DESKTOP`), plus `hyprpaper`
  and `hyprpolkitagent` autostarts.
- `.config/systemd/user/kanshi.service.d/hyprland-only.conf` — the
  `ConditionEnvironment=XDG_CURRENT_DESKTOP=Hyprland` guard (moved off the shared
  `kanshi.service`).
- `.config/systemd/user/waybar.service.d/hyprland-only.conf` — same guard for the
  packaged `waybar.service`.
- (Your `.config/kanshi/config` and `.config/shell/machine-env` are unchanged.)

### Reverted / removed from the shared layer
- `profiles/hyprland/.config/systemd/user/kanshi.service` — guard removed (back to
  `main`; the guard now lives in the Fedora host drop-in).
- Deleted `profiles/hyprland/.config/systemd/user/{elephant.service,walker.service,
  waybar.service.d/hyprland-only.conf}` — Fedora-shaped (hardcoded `~/.local/bin`,
  dual-session guards). If you still want supervised services later, resurrect
  them from commit `dd24af9` as **host-scoped** units under `hosts/fedora/` (see
  "Your remaining work"). stationzebra uses exec-once.

### `hosts/stationzebra/.config/hypr/local.conf`
- Empty stub, so the shared `source = …/local.conf` resolves on stationzebra.

### `.gitignore`
- Kept your `profiles/hyprland/.config/elephant/providers/` ignore (harmless
  belt-and-suspenders; the binaries are already kept out via the container rule).

---

## 2. Answers to your `fedora-changes.md` §5 review questions

I ran your "Verify on stationzebra" block. Results:

```
systemctl --user show-environment | grep -E '^(PATH|XDG_CURRENT_DESKTOP)='
  PATH=/usr/local/sbin:/usr/local/bin:/usr/bin:/opt/bin:/usr/lib/llvm/22/bin:/usr/lib/llvm/20/bin
  XDG_CURRENT_DESKTOP=Hyprland          # <-- present
  WAYLAND_DISPLAY=wayland-1

session: Type=wayland  Service=login  Scope=session-1.scope   # TTY login shell, no DM/uwsm

systemctl --user is-enabled …:  waybar=enabled  kanshi=enabled
                                elephant/walker/hyprpolkitagent = not-found
walker/elephant path: /usr/local/bin/walker , /usr/local/bin/elephant  (running via exec-once)
```

**Conclusions:**
- **The guards were safe on stationzebra** (it *does* carry
  `XDG_CURRENT_DESKTOP=Hyprland`) — but they're a Fedora dual-session concern, so
  I host-scoped them anyway (cleaner; stationzebra stays guard-free).
- **The `env = PATH` rewrite was NOT safe** — it would drop stationzebra's
  `/opt/bin`, llvm, `~/.opencode/bin`, azure-cli. Replaced with additive `path.d`.
- **The `exec-once` removal + Fedora services were NOT safe** — stationzebra runs
  walker/elephant from `/usr/local/bin` via exec-once, not `~/.local/bin`, and the
  services weren't enabled here. Restored exec-once; dropped the services.
- **Root cause confirmed as session-launch, not distro userland** — stationzebra
  launches Hyprland from a TTY login shell (so it already has the rich PATH and
  the env in systemd --user); Fedora/GDM does not. Agreed with your §3.

---

## 3. Your remaining work (to finish Fedora + let the branch land)

1. **The real fix — get the additive PATH to the compositor.** GDM starts plain
   Hyprland with a minimal PATH. Pick one (no `env = PATH` rewrites):
   - **Preferred:** launch Hyprland via **uwsm** (you already have
     `hyprland-uwsm`; use the "Hyprland (uwsm-managed)" GDM entry). uwsm starts the
     compositor inside the systemd user session with the imported environment.
   - **Or:** make the plain session run a login shell (so `env.sh`/`path.d` runs),
     e.g. a wrapper that `exec`s Hyprland from `bash -l`.
   Then verify: `Super+R` (walker), the Waybar arch icon (`walker -m …`), and the
   shared `exec-once = elephant/walker` all work — i.e. `~/.local/bin` is on the
   compositor's PATH (`hyprctl systeminfo` / check a spawned proc's `/proc/…/environ`).
2. **Re-test the guards after `systemctl --user daemon-reload`:** under Hyprland,
   `kanshi`/`waybar` start; under GNOME they stay dormant
   (`systemctl --user show kanshi.service -p ConditionResult`).
3. **`~/.config/user-dirs.dirs` CONFLICT (your §7):** `xdg-user-dirs-update`
   rewrote the repo symlink into a real file. Either `dotfiles add` it (if the
   Fedora values should be tracked — probably host-scope it) or restore the link
   (`dotfiles link` after removing the real file).
4. **Optional:** if you want walker/elephant supervised (not exec-once), re-add
   `elephant.service`/`walker.service` from `dd24af9` **under `hosts/fedora/`**,
   keep their guards, and remove the shared `exec-once` lines *only via a
   host-specific mechanism* (they must stay for stationzebra). Simplest is to keep
   exec-once; services are a nice-to-have.
5. **Before landing on `main`:** delete `fedora-changes.md` and this file, then
   `make lint && make test` (green), and confirm `hosts/fedora/` holds all the
   dual-session/GDM glue while `home/` + `profiles/hyprland/` are machine-agnostic.

## 4. Why the shared layer is now stationzebra-safe
- `hyprland.conf` == `main` + one `source = local.conf` line (+ stationzebra's
  empty stub), so behavior is unchanged here.
- `path.d` reproduces stationzebra's existing PATH exactly (verified), just
  additively and layered.
- `kanshi.service` is guard-free again; no Fedora services in the shared tree.
