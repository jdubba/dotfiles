# Theme system — manual validation runbook

A hands-on checklist to validate the theming deliverables on a live machine
(reference host: **stationzebra**, Gentoo + Hyprland + hyprpaper). Work through
the phases in order; each step lists the command(s) and what to expect.

Related docs: `docs/auto-theming.md` (auto-theme internals + DE backlog),
AGENTS.md "Theming" section.

## Phase 0 — Deploy the new seams (one-time)

The theme work added managed files (`tui.json`, `theme-env.sh`,
`dotfiles_theme.lua`, `current-theme.conf`, per-theme wallpapers, the watcher
unit) and two new nvim plugins.

```bash
dotfiles link                    # link all new seam files
systemctl --user daemon-reload   # pick up the new dotfiles-autotheme.service unit
```

- Open a **fresh terminal** so `theme-env.sh` (`BAT_THEME` / `FZF_DEFAULT_OPTS`)
  is sourced.
- Launch **nvim once** and run `:Lazy sync` so `catppuccin`, `gruvbox.nvim`, and
  `base16-nvim` are installed. Quit.

**Expected:** `dotfiles link` succeeds with no CONFLICTs.

## Phase 1 — Baseline inspection (no visual needed)

```bash
dotfiles theme status      # active theme + all 11 seams
dotfiles theme list        # both themes listed, one marked * active
dotfiles theme auto status # disabled; palette backend: wallust
```

**Expected:** `theme: catppuccin-mocha (repo default)`; every seam line reads
`yes`; backend `wallust`.

Spot-check a couple of seams actually point into the active theme:

```bash
readlink -f ~/.config/kitty/current-theme.conf          # -> themes/catppuccin-mocha/...
grep -E '^background' ~/.config/kitty/current-theme.conf # #1e1e2e
echo "$BAT_THEME"                                        # Catppuccin Mocha (fresh shell)
hyprctl hyprpaper listactive                             # -> ~/.config/background (salty_mountains)
```

## Phase 2 — Switch to Gruvbox

```bash
dotfiles theme set gruvbox-dark
```

`theme set` relinks and live-reloads hyprland / waybar / kitty / ghostty / tmux /
hyprpaper. **nvim, opencode, walker, and new shells need a manual restart** (the
command prints this reminder).

Per-app checklist (observe the switch to warm brown/orange):

| App | How to check | Expected (gruvbox) |
|---|---|---|
| kitty | new window / existing reloads | warm dark bg `#282828`, cream fg |
| ghostty | open new window | same warm palette |
| waybar | look at the bar | bg / workspaces recolor warm |
| hyprland borders | focus/unfocus a window | active-border gradient changes |
| tmux | attach a session | status bar warm bg/fg |
| starship | next prompt | warm palette (new prompt line) |
| wallpaper | glance / `hyprctl hyprpaper listactive` | pilot_mountains painting |
| bat | **new shell** -> `bat ~/.tmux.conf` | `echo $BAT_THEME` = `gruvbox-dark` |
| fzf | **new shell** -> `fzf` | warm selection colors |
| walker | restart: `killall walker; walker --gapplication-service &` then Super+R | warm window bg/accent |
| nvim | restart nvim | `:colorscheme` -> `gruvbox` |
| opencode | restart opencode | gruvbox TUI (or `/theme` shows it) |
| hyprlock | `hyprlock` (Esc / password to exit) | wallpaper + warm accents |

## Phase 3 — Switch back to Catppuccin

```bash
dotfiles theme set catppuccin-mocha
```

Repeat the table. **Expected:** everything flips to dark blue-purple `#1e1e2e`
with mauve/blue accents; `BAT_THEME` = `Catppuccin Mocha` (new shell); nvim
`:colorscheme` -> `catppuccin`; wallpaper -> salty_mountains.

## Phase 4 — Auto-theme (one-off)

Derive a theme from an arbitrary image (pass one with strong colors for an
obvious result):

```bash
dotfiles theme auto now ~/pictures/temp-wallpaper.jpg
dotfiles theme auto status
dotfiles theme status
```

**Expected:**
- Prints `palette backend: wallust` and generates `themes/auto/`.
- `theme status` -> `theme: auto (wallpaper-derived)`, all seams `yes`.
- Wallpaper changes to the image you passed; kitty/ghostty/waybar/tmux/starship
  recolor to the derived palette.
- Distinguishers: **new shell** `echo $BAT_THEME` -> `ansi`; restart nvim ->
  `:colorscheme` shows `base16`; opencode -> `system` theme (follows terminal).

Quick confirm the generated tree:

```bash
readlink -f ~/.config/waybar/colors.css   # -> themes/auto/...
ls ~/.config/background                    # resolves into themes/auto
```

## Phase 5 — Auto-theme (continuous watcher)

```bash
dotfiles theme auto enable
systemctl --user status dotfiles-autotheme.service   # active (running)
```

Trigger a change and watch it regenerate:

Trigger a change and watch it regenerate:

> **Note (hyprpaper 0.8.x):** the `preload`/`unload`/`reload` IPC verbs were
> removed; only `hyprctl hyprpaper wallpaper "<mon>,<abspath>"` and `listactive`
> remain. To change the wallpaper live use `dotfiles theme auto now <image>` (or
> the per-monitor `wallpaper` push the tooling now uses); external switchers that
> rely on `preload` won't work.

- Watch the service log, then change the wallpaper via `dotfiles theme auto now
  <image>` in another terminal:
  ```bash
  journalctl --user -u dotfiles-autotheme.service -f
  ```
- Or simulate one tick against a different image (no wallpaper change needed):
  ```bash
  DF_WALLPAPER=~/some-other-image.jpg dotfiles theme auto watch-tick
  ```

**Expected:** log shows "wallpaper changed; regenerating..."; palette and
wallpaper update automatically.

## Phase 6 — Disable & restore

```bash
dotfiles theme auto disable          # stops watcher, reverts to previous theme
systemctl --user status dotfiles-autotheme.service   # inactive/dead
dotfiles theme set catppuccin-mocha  # (or `dotfiles theme unset` -> repo default)
dotfiles theme auto status           # disabled
```

**Expected:** watcher stopped; active theme back to catppuccin-mocha; seams
resolve to `themes/catppuccin-mocha`.

## Notes / known rough edges

- **Setting the wallpaper (hyprpaper 0.8.x):** the `preload`/`unload`/`reload`
  IPC verbs were removed (an intentional redesign, not a version skew — the
  `invalid hyprpaper request` error comes from `hyprctl`). Set the wallpaper via
  the theme system: `dotfiles theme auto now <image>` (wallpaper + matching
  palette), or replace a theme's `themes/<name>/.config/background` and run
  `dotfiles link`. Live application is a per-monitor `hyprctl hyprpaper wallpaper
  "<mon>,$HOME/.config/background"` push (what the tooling does now — no daemon
  restart). A structural `hyprpaper.conf` change still needs
  `systemctl --user restart hyprpaper.service`.
- **Manual-restart apps:** nvim, opencode, walker, and shells
  (`BAT_THEME` / `FZF_DEFAULT_OPTS`) do not hot-reload - restart them after a
  switch. Everything else reloads automatically.
- **Live wallpaper apply** is a per-monitor `hyprctl hyprpaper wallpaper` IPC
  push — no daemon restart, no flash.
- **wallust** is the preferred palette backend; without it you'll see the
  "install wallust" notice and the bundled python+Pillow fallback is used.
- Generated `themes/auto/` is gitignored (won't appear in `git status`).
