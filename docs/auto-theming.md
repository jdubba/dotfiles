# Auto-theming (wallpaper-derived themes)

`dotfiles theme auto` derives a colour palette from the current wallpaper and
generates a full theme (`themes/auto/`, gitignored) that feeds every themed
tool, then activates it. This document covers how it works and what remains to
implement for desktops other than Hyprland.

## Commands

```bash
dotfiles theme auto now [IMAGE]   # one-off: generate from IMAGE (or the current
                                  # wallpaper) and make "auto" the active theme
dotfiles theme auto enable [IMG]  # same as `now`, plus start the wallpaper
                                  # watcher (systemd user service) for continuous
                                  # regeneration on wallpaper change
dotfiles theme auto disable       # stop watching, clear the flag, revert to the
                                  # previously-resolved theme
dotfiles theme auto status        # show enabled state, palette backend, source
dotfiles theme auto watch         # the poll loop run by the systemd service
dotfiles theme auto watch-tick    # a single watch iteration (debug/testing)
```

`DF_WALLPAPER=/path/to/image` overrides wallpaper detection for a single run —
useful on desktops without a detector yet (see below).

## Pipeline

1. **Detect** the current wallpaper (`df_autotheme_current_wallpaper`).
2. **Extract** a normalized, always-dark palette (`background`, `foreground`,
   `cursor`, `color0..color15`) via `df_palette_extract`.
3. **Generate** every seam file into `themes/auto/.config/**` and copy the
   wallpaper to `themes/auto/.config/background` (`df_autotheme_generate`).
4. **Activate**: mark auto the active theme (machine-local flag), `dotfiles
   link`, reload running tools (`df_autotheme_apply`).

### Palette backends (preference order)

`wallust` → `pywal` (`wal`) → bundled `python3` + Pillow
(`lib/theme-auto/palette.py`). The active backend is reported by `theme auto
status`; when a lesser backend is in use, a notice recommends installing
`wallust` (`cargo install wallust`). The core `dotfiles` tool stays
dependency-free; auto-theming is the one feature with an (advertised) optional
dependency.

- **wallust**: rendered through wallust's own templating into an isolated temp
  config dir (`wallust run … -s -n -k -d <dir>`), so the user's real wallust
  config, cache, and terminal are untouched.
- **pywal**: reads `~/.cache/wal/colors.json`.
- **python/Pillow**: median-cut quantisation + luminance/saturation mapping to a
  legible dark base16-ish palette.

### Per-tool coverage under an auto theme

Raw generated colours: kitty, ghostty, hypr (+ hyprlock vars), waybar, walker,
tmux, starship (palette block swapped into the shared structure), fzf (via
`theme-env.sh`). Follow-the-terminal: **bat** (`BAT_THEME=ansi`), **opencode**
(`theme: system`). **nvim** via a generated base16 palette consumed by
`RRethy/base16-nvim` (`lua/plugins/colorscheme.lua`). Wallpaper copied into the
theme.

### State (machine-local, never committed)

Under `$XDG_STATE_HOME/dotfiles/`:

- `auto-theme` — present ⇒ auto is the active theme (`df_theme_name` returns
  `auto`, ahead of the per-host override and repo default).
- `auto-theme.watch` — continuous mode requested.
- `auto-theme.source` / `auto-theme.hash` — last processed wallpaper path/hash
  (the watcher's loop guard).

### Loop guard

The generated theme copies the source image to `~/.config/background`; its
content hash equals the last-processed source, so re-applying (which reloads
hyprpaper to show `~/.config/background`) does not re-trigger the watcher.

## Desktop support

| Desktop            | Wallpaper detection            | Reload on switch                | Status |
|--------------------|--------------------------------|---------------------------------|--------|
| Hyprland+hyprpaper | `hyprctl hyprpaper listactive` | `hyprctl hyprpaper wallpaper` per output (live) | **done** |
| GNOME              | —                              | —                               | backlog |
| KDE Plasma         | —                              | —                               | backlog |

> hyprpaper 0.8.x removed `preload`/`unload`/`listloaded`/`reload`; only
> `wallpaper "<mon>,<abspath>"` (loads+applies in one shot) and `listactive`
> remain. `_df_theme_reload` pushes the new wallpaper live to every monitor via
> IPC — no daemon restart. `hyprpaper.conf`'s `path=` provides persistence on
> next start (refreshed by the linker); there is no config-reload IPC.

The watcher is a systemd user service
(`profiles/hyprland/.config/systemd/user/dotfiles-autotheme.service`), guarded to
the Hyprland session on the dual-session Fedora host via a drop-in. It is only
enabled by `theme auto enable`; after linking a new unit run `systemctl --user
daemon-reload` (the `enable` path does this).

## Backlog — detection/reload for other desktops

Both are extension points in `df_autotheme_current_wallpaper` (detection) plus a
per-DE reload branch (currently hyprpaper-only in `_df_theme_reload`).

### GNOME

- **Detect**: `gsettings get org.gnome.desktop.background picture-uri` (and
  `picture-uri-dark` for the dark scheme); strip the `file://` prefix and
  URL-decode.
- **Watch**: `gsettings monitor org.gnome.desktop.background picture-uri` emits
  on change — a cleaner, event-driven alternative to polling. A GNOME watcher
  unit should gate on `XDG_CURRENT_DESKTOP` containing `GNOME`.
- **Apply/reload**: GNOME itself is never modified (repo rule). Auto-theming
  under GNOME would only theme the cross-desktop tools (terminal, nvim, etc.),
  not GNOME shell/GTK. Decide scope before implementing.

### KDE Plasma

- **Detect**: wallpaper lives in
  `~/.config/plasma-org.kde.plasma.desktop-appletsrc` (per-containment `Image=`
  keys); parsing is fiddly. Alternatively read the active containment via
  `qdbus org.kde.plasmashell`.
- **Set/reload**: `plasma-apply-wallpaperimage` sets wallpaper; there is no
  simple "current wallpaper" CLI, so detection likely needs the appletsrc parse
  or a D-Bus query.
- **Watch**: no inotify dependency is assumed; a systemd `.path` unit on the
  appletsrc file, or polling the D-Bus query, are the options.

### wallust adapter

Implemented against wallust 3.5.x templating. If a future wallust changes its
template variable names or config schema, `_df_palette_wallust` may need
updating; it fails soft (returns non-zero) and the chain falls back to pywal or
Pillow, so auto-theming keeps working meanwhile.
