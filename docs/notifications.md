# Notifications (swaync) — dependency and per-distro install

The notification daemon is **[swaync](https://github.com/ErikReider/SwayNotificationCenter)**
(SwayNotificationCenter) v0.12.x. It replaced **mako**, which had been running
un-managed — its config was a real, untracked file with a Catppuccin Mocha
palette hardcoded in it, so it stayed that colour through every theme switch.

This doc covers what swaync costs to install and what each distro needs. The
theming seam is documented in `AGENTS.md`; the behavioural traps that cost real
debugging time are at the bottom here.

## Why swaync and not mako

mako can do most of what we want, and it is a far smaller dependency (a handful
of C files against swaync's GTK4 + Vala stack). One requirement decided it:

> a brief notification that leaves on its own, plus a separate view to review
> everything unacknowledged and clear it one at a time or all at once.

mako has a history **buffer** (`max-history`, `makoctl history`) but no panel,
and `makoctl restore` only pops the **most recent** entry — there is no
restore-by-id and no list UI. That half is not a configuration gap, it is
absent by design and will not appear. swaync *is* a notification centre
(`swaync-client --toggle-panel`, per-row close, `--close-all`, DND).

Two secondary wins: swaync styles with **GTK CSS**, so it rides the same
`colors.css` seam waybar and walker already use; and it can pin its output per
monitor, which mako cannot do usefully here (mako's only knob is a hardcoded
`output=<connector>`, and this dock's connector names are not stable).

## Dependency footprint

swaync is Vala/GTK4 and pulls in elementary's **granite**, which is the one
genuinely surprising dependency:

| | |
|---|---|
| runtime | GTK4, gtk4-layer-shell, libadwaita, libhandy, granite, json-glib, libgee |
| build | valac (+vapigen), meson, blueprint-compiler, sassc, scdoc |
| optional | libpulse (`pulseaudio` USE — the volume/backlight widgets) |

Six packages on a machine that already ran Hyprland + walker. Not free, but not
the heavyweight a "GTK4 + libadwaita + granite" list suggests.

## Gentoo (verified on stationzebra)

swaync is in the **guru** overlay, not the main tree. Three config files, all
following conventions already in `/etc/portage`:

```bash
# 1. keyword — guru ships ~amd64 only
/etc/portage/package.accept_keywords/swaync
    gui-apps/swaync ~amd64

# 2. USE — swaync's Vala bindings need these from a walker dependency
/etc/portage/package.use/swaync
    gui-libs/gtk4-layer-shell introspection vala

# 3. QA relaxation for granite (see below)
/etc/portage/package.env/granite
    dev-libs/granite granite-warn-disable.conf
/etc/portage/env/granite-warn-disable.conf
    FEATURES="${FEATURES} -stricter"

sudo emerge -a gui-apps/swaync
```

Notes on each:

- **The `gtk4-layer-shell` USE change forces a rebuild of a package walker
  depends on.** `introspection` and `vala` are purely additive, and walker was
  verified still running after the rebuild — but it is a rebuild, so do not be
  surprised by it in the emerge plan.
- **granite fails Portage's QA check without the relaxation.** It dies with
  `install aborted due to severe warnings`, from `-Wincompatible-pointer-types`
  (`GtkWidget *` assigned to `GtkBox *`, `void **` to `gchar **`) in
  **valac-generated C**, not in granite's own source. GCC >= 14 promoted that
  class to severe. The `-stricter` escape mirrors the existing `boost` entry.
  It is deliberately **unpinned**: this is a standing property of valac's
  codegen, not of one granite release.

## Fedora (partly verified — read before trusting)

**Verified:** `SwayNotificationCenter` is in the **Fedora repos proper** —
0.12.6 on F43 and F44, 0.12.5 on F42, i.e. the same version Gentoo's guru
ships. So unlike Hyprland/walker/elephant there is **no COPR and no manual
build**:

```bash
sudo dnf install SwayNotificationCenter
# shell completions are separate subpackages:
#   SwayNotificationCenter-{bash,fish,zsh}-completion
```

That also means none of the Gentoo work above has a Fedora analogue — no
keywording, no USE flags, and no granite QA problem, because the distro built
it already.

**Not verified — expected to be needed, confirm on the box:**

1. **A dual-session guard is almost certainly required**, and this is the one
   thing likely to bite. On Fedora hosts GNOME and Hyprland are both selectable
   at GDM and both reach `graphical-session.target`, which is exactly why
   `kanshi` and `waybar` carry
   `ConditionEnvironment=XDG_CURRENT_DESKTOP=Hyprland` drop-ins there. The
   shipped `swaync.service` is `WantedBy=graphical-session.target` and guards
   only on `ExecCondition=[ -n "$WAYLAND_DISPLAY" ]` — which **GNOME also
   satisfies**, GNOME being Wayland. Worse, GNOME provides
   `org.freedesktop.Notifications` itself, so an unguarded swaync would fight
   GNOME's own daemon for the bus name. Expect to need:

   ```ini
   # hosts/<fedora-host>/.config/systemd/user/swaync.service.d/hyprland-only.conf
   [Unit]
   ConditionEnvironment=XDG_CURRENT_DESKTOP=Hyprland
   ```

   Same shape and same reason as the existing `kanshi`/`waybar` drop-ins. Keep
   the guard in the **host** layer, not in a shared profile.
2. **Install paths are assumed standard** (`/usr/lib/systemd/user/swaync.service`,
   `/etc/xdg/swaync/{config.json,style.css,configSchema.json}`) but were **not**
   confirmed — Fedora's spec file could not be read (bot protection on
   src.fedoraproject.org). The user stylesheet path is resolved from
   `Environment.get_user_config_dir()` in swaync's own source, so
   `~/.config/swaync/style.css` is portable regardless.
3. **The monitor pin is stationzebra-specific.** `dock-layout.sh` rewrites it
   for the twin-LG dock; a single-display Fedora host wants the pin set to its
   own connector (`eDP-1`) or left out entirely.
4. `notify-send` on Fedora comes from `libnotify`, which GNOME already pulls in.

## Amazon Linux / headless

Nothing. `ai-workstation` has no desktop, so any swaync config in the shared
layers is linked and inert, which is the outcome the layering already assumes.

## Behaviour worth knowing before touching this

Findings that cost real time, each verified by rendering or by reading swaync's
source rather than inferred:

- **Critical notifications cannot be made to expire via `timeout-critical`.**
  The freedesktop spec says critical never expires and swaync honours it, which
  is why Brave's web notifications (sent as `Urgency: Critical`) used to sit on
  screen until acked under mako too. The escape hatch is a
  `notification-visibility` rule with **`override-urgency`**, which rewrites the
  urgency so the normal `timeout` applies. Note the sibling `urgency` key is a
  *matcher* defaulting to `Normal`, so it must be stated explicitly to catch
  Critical.
- **An unset `notification-window-preferred-output` is not "follow focus".**
  `try_get_monitor()` returns null, the compositor picks once, and
  `notificationWindow.vala` then caches that connector in a **static** and
  reuses it. So the default is consistent but arbitrary. Pin it explicitly.
  Descriptor matching (`manufacturer model description`) does not help on this
  dock — both LG TVs report an identical `LG Electronics LG TV SSCR2
  0x01010101`.
- **User CSS is additive, but ties do not go to you.** `load_css()` adds the
  packaged sheet as one provider and yours as a second at *equal* priority, so
  untouched rules keep upstream styling and nothing needs vendoring — but a
  same-specificity override of a shipped rule loses. Out-specify it.
- **Two shipped rules use `--noti-bg-focus`, and the one that fires is
  `.notification-group:focus`** — swaync wraps every notification in a
  `.notification-group` even with `notification-grouping: false`, so overriding
  `.notification-row:focus` alone silently does nothing.
- **`swaync-client -rs` is reliable for a theme switch but was not for an edit
  to `style.css` itself.** It reported `CSS reload success: true` while an
  appended rule did not render; a `systemctl --user restart swaync.service`
  applied it. Iterate on the stylesheet with a restart.
- **`--text-color` is hardcoded white in the shipped sheet** and used in places
  a partial override does not enumerate (e.g. `.widget-dnd label`), which is
  invisible on any light theme.
- **Verify by rendering.** `grim -o <output>` then sample pixels; `hyprctl
  clients` reports *global* coordinates, so subtract the monitor origin before
  cropping. A pixel sample identified the focus box by arithmetic
  (`rgba(68,68,68,.6)` over `#002b36` = `srgb(41,58,62)`) when reading the
  stylesheet had produced the wrong answer twice.

## Status

The daemon, the waybar bell pill (`custom/notifications` +
`@pill-notify-bg/-fg`) and the `dock-layout.sh` output pin are in the repo.
**swaync's own `config.json` and `style.css` are not yet adopted** — they are
still machine-local under `~/.config/swaync/`.

One thing to resolve when they are adopted: `dock-layout.sh`'s
`pin_notifications()` writes to `~/.config/swaync/config.json`, which is fine
while that file is untracked, but once it is a symlink into the repo every
redock becomes tracked-file churn. The clean shape is a repo-tracked template
plus a generated machine-local config passed to swaync via `-c` (a
`swaync.service` drop-in).
