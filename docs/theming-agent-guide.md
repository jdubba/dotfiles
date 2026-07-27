# Running a theme-polishing session (agent guide)

How to work through a theme with the user, seam by seam. This is the **process**
doc: the loop, the vocabulary, what to ask at each seam, and how to prove a
change landed.

It does **not** repeat the durable facts — the emitter's internals, the
palette-slot traps, the per-tool seam mechanics and the accumulated gotchas all
live in AGENTS.md's **Theming** section, which is the reference. Read that
first; read this to know what to *do*.

Related: `docs/auto-theming.md` (wallpaper-derived themes),
`docs/theme-validation.md` (post-change validation runbook),
`docs/palettes/index.html` (one swatch page per theme).

---

## 0. Before you start

```bash
xdg-open docs/palettes/<theme>.html   # ALWAYS. see "Speaking in slots" below
dotfiles theme name                   # is this theme actually live?
git status --short                    # start clean; you will commit per seam
find tools/theme-overrides/<theme> -type f    # what is already pinned by hand
```

The palette page is not optional politeness — it is what makes the session
possible. It gives both sides the same names for the same colours, and it
already lists the seams derived from the palette, every text pair measured, and
that palette's own quirks.

If the theme is **not** the active one, say so and offer to switch, because
almost every verification step below needs it live. Do not assert either way
before checking; that error has been made more than once.

Check what is already overridden before proposing anything. A pinned file does
not track the emitter, so "the emitter does X" may be false for this theme.

---

## 1. The loop

Every change goes through the same six steps. Do not skip the middle two.

1. **Propose** — in slot names, with the trade-off stated in one line.
2. **Measure** — WCAG or ΔE, *before* applying. Report the number, including
   when it fails. Never say "this should read fine".
3. **Apply** — to `tools/theme-overrides/<theme>/`, then
   `./tools/build-themes.sh <theme>`, then `dotfiles link` if it is live.
4. **Verify by rendering** — see the cookbook in §7. Reading the file back
   proves only that you wrote it.
5. **Discuss** — the user reviews on screen and either adjusts or locks it in.
   Expect several rounds per seam. This is the point of the session.
6. **Commit** — one commit per seam, message explaining *why* (§9).

The user drives. When they name colours, **apply their spec as given first**,
then report what it measures. Do not silently substitute a "better" colour, and
do not pre-empt the choice with a lecture. If a spec measures badly, apply it,
say so with the number, and offer the nearest fix — they will often keep it
anyway for reasons the meter cannot see, and that is a legitimate call.

---

## 2. Speaking in slots

The whole session runs on palette-slot names. `c11` is an instruction;
`#c47b28` is not. Steering a theme by hex is miserable, which is exactly why
`docs/palettes/` exists.

**The user will say things like:**

> "c3 for the primary pills with background for the text, c15 for the workspace
> bg, c6 for occupied, c4 for empty, c5 for active, c9 for the active glow"

That is a complete seam spec. `background` and `foreground` mean the palette's
`bg`/`fg`, not a literal word. Read it as a list of assignments and apply all of
them in one pass.

**Answer in the same language.** A good reply is a table of
`role → slot → hex → measured ratio → verdict`, not prose. Flag only the pairs
that miss their target, and say what the nearest passing alternative is.

Some themes have **role names** as well as slots — rose-pine's `pine`, `rose`,
`love`, `gold`, `iris`, `foam`, `muted`, `subtle`, plus off-slot roles the ANSI
sixteen cannot carry. The user will mix the two freely ("pine for the primary
pills, but move the ws background to the rose"). **Map role → `cN` explicitly
when you answer**, because the mapping is not obvious and getting it wrong
silently derails a round. Off-slot roles are listed under "Beyond the ANSI
slots" on the palette page; they are usable in waybar, walker, hypr, starship
and tmux, but **not** in kitty/ghostty, whose palette *is* the sixteen.

**Shorthand that recurs, and what it means:**

| They say | You do |
|---|---|
| "go" / "do it" | proceed with what you just proposed, no further confirmation |
| "at spec'd" / "just apply my first pass as is" | apply verbatim, measure after, do not improve it |
| "let me see B" | render that option and stop |
| "commit it" / "commit" | commit *this seam only*, then wait |
| "commit everything pending" | commit the outstanding work, still split by concern |
| "push it" | push — and only then, never on your own initiative |
| "leave it" / "leave them as is" | close the item, do not revisit |
| "what's next" / "what's remaining" | list the untouched seams for this theme |
| "roll again" / "roll one more" | regenerate the wallpaper, same brief, new seed |
| "pin this one" | keep that candidate as the base for further work |
| "ship it" | move that candidate into `themes/<name>/.config/background` |

---

## 3. Which instrument for which question

Getting this wrong has produced wrong conclusions that survived for months.

| Question | Instrument | Target |
|---|---|---|
| Is this text legible on that background? | `_dfa_contrast` (WCAG) | **4500** (4.5:1) |
| Is this large/bold text or a dot legible? | `_dfa_contrast` | **3000** (3.0:1) |
| Are these two filled shapes distinguishable? | `_dfa_rgb_dist` (ΔE proxy) | **≥ 144** (≈ ΔE 20) |
| Should this chrome recede? | `_dfa_contrast` | deliberately **< 3000** |
| Which near-black/near-white ink? | `_dfa_contrast_fg` | — |

All of these are in `lib/theme-auto.sh` and are integer bash — source it and
call them directly rather than reimplementing:

```bash
bash -c 'source lib/core.sh; source lib/theme-auto.sh; _dfa_contrast d3b8f2 47407d'
# 5183   -> 5.18:1
```

**Never use WCAG on powerline separators or pill-against-pill adjacency.** A
separator is a filled shape drawn in one pill's background over the next pill's
background. WCAG measures luminance only — correct for text, badly wrong for
"can I tell these two blocks apart". Over the 240 shipped adjacencies, 108 fail
WCAG 3:1 but only 35 fail ΔE 20. Reporting the WCAG figure hid a real bug inside
the noise for a long time.

**Structural vs content.** Chrome that should recede — btop's `meter_bg` and
`div_line`, empty workspace dots, inactive borders — belongs *below* 3:1 on
purpose. Only content has to clear AA. Judge each pair by its role; a blanket
"raise everything" is as wrong as leaving a real failure in place.

**Mid-luminance surfaces admit no AA ink.** On a saturated accent around
luminance 110–150, nothing reaches 4.5:1 — not the palette fg, not the bg, not
near-black or near-white. When that happens, say so plainly and give the
ceiling ("`pine` tops out at 3.95:1 with any ink") rather than silently picking
the least-bad option. A vivid highlight and a legible one can be mutually
exclusive; that is the user's trade to make.

---

## 4. Order of seams, and what to ask at each

Wallpaper first, then in roughly this order. The order matters: waybar and
starship are the most-looked-at surfaces and they set the accent language the
rest of the theme follows.

Open each seam by **listing the decisions**, with the current value and its
measurement, and a recommendation. Do not ask them one at a time — the user
specs a whole seam in a sentence and it wastes rounds to drip-feed.

### Wallpaper (§5 has the full workflow)

### waybar — `.config/waybar/colors.css`

Ask for:

- **primary pill** bg + fg — left pills *and* the primary right pill share one
  accent. This is the theme's dominant accent and usually the first thing named.
- **stats pill** and **ctrl pill** — normally the same accent as primary; ask
  only whether they should diverge.
- **theme switcher pill** bg + fg — traditionally its own hue, distinct from
  primary.
- **workspaces surface** (`ws-bg`) — the group is a *pill*, not chrome. If every
  hue goes to the other pills and this stays achromatic, the bar's centrepiece
  is the one module with no colour. That is the single biggest cause of themes
  feeling alike.
- **the three dot states** — empty / occupied / active, plus the **active
  glow**. Targets: occupied and active ≥ 3:1 against `ws-bg`; empty is chrome
  and stays faint deliberately.
- **slider fill** (`slider-fg`) — the volume/backlight fill inside the ctrl
  pill.
- **bar bg / bar text** — rarely changed. Note that `window#waybar` draws
  `alpha(@bar-bg, 0.6)`, so measuring a pill against nominal `bar-bg` overstates
  the problem.

Also check **state-against-state**, not just state-against-surface: two dots can
each clear the surface and still be invisible against *each other*. Hue
separation substitutes for luminance separation at dot size, so check the render
before calling it a defect.

The battery pill is **deliberately un-themed** — do not offer to theme it.

### starship — full-file `starship.toml` swap

Ask for:

- **os/user segment** bg + fg
- **directory pill** bg + fg
- **git-repo directory** ink (`color_dir_repo_fg`) and the **repo root name**
  (`color_root_fg`)
- **the three git pills, right to left** — repo, changes, diverge: bg + fg each.
  The user will usually give three backgrounds in one breath and one shared
  foreground.
- **connector** colour
- **time and IP** line ink, and the **IP brackets**

There is no include mechanism, so this is a whole-file override once touched.
Verify by rendering (§7) — the escape sequences are the only proof.

### walker — `.config/walker/colors.css`

Ask for:

- **window bg** + fg
- **highlight bar** bg + fg (the selected row)
- **quick-activation badge** bg + fg

Note GTK's `lighter()` is `shade(c, 1.3)` on HLS lightness. Walker paints
`lighter(@window_bg_color)` for **both** the list and the input, and `lighter³`
only for `.input selection` — so the input background is the same tone as the
list, and a "the search box has a different background" theory is wrong.

### tmux — `.config/tmux/current-theme.conf`

Ask for:

- **status bar** bg + fg
- **active pane chip** bg + fg (`window-status-current-format`)
- **active / inactive pane border**
- the **separator** and **date** accents in status-left/right

### hypr — `.config/hypr/current-theme.conf`

Ask for:

- **active window border** — a *gradient*, so two slots
- **inactive border** — chrome, stays faint
- **hyprlock** input highlight / glow

Be precise about which hyprlock element: "the glow" has meant both the outer
halo and the ring around the input field in the same session. Ask which if it is
not obvious.

### btop — `.config/btop/themes/current.theme`

Usually needs nothing. Check, and report rather than proposing:

- `meter_bg` / `div_line` / `inactive_fg` recede (below 3:1 is correct here)
- gradient **semantics**: `used` runs calm → mid → alarm and `available` runs
  the other way. A meter's gradient is drawn along its length, so the tip colour
  reports the level.
- box colours are distinguishable from each other

btop selects the theme by name once per machine (`color_theme = "current"` in
the gitignored `btop.conf` — press `t` in btop). It does not hot-reload.

### nvim — `lua/dotfiles_theme.lua`

Precedence:

1. an upstream-published **base16** for this theme (rose-pine, nightfox family,
   dracula all publish one) — take it
2. a **plugin flavour** where the colorscheme is bundled (catppuccin, gruvbox)
3. the emitter's **generated base16** from the ANSI sixteen

Prefer 1 whenever it exists. The generated remap has a recurring defect: it
tends to give `base02` (selection bg) and `base03` (comment fg) the same value,
so selecting a comment erases it. Measure that pair specifically. Upstream also
spends `base01`/`base04`/`base06` on real surface and dim-ink steps that the
sixteen do not carry.

Verify the file parses before committing:

```bash
nvim --headless -c 'lua print(vim.inspect(dofile("themes/<t>/.config/nvim/lua/dotfiles_theme.lua")))' -c q
```

### kitty / ghostty

The ANSI sixteen come from the registry and should match upstream **exactly** —
diff them against the vendor's own port rather than assuming. Chrome worth
checking: `selection_foreground`/`selection_background`, `url_color`, cursor,
active/inactive border.

Take upstream's chrome only where it beats ours *and* does not collide with a
job another seam has already given that slot. Say which you are declining and
why.

### opencode — `tui.json`

A built-in theme name if one exists for this palette, else `system`. One key.

### brave

Aligned, not themed: it derives its whole chrome from the waybar primary accent
plus the theme's polarity, so it has no seam of its own and follows whatever
waybar was set to. **Brave must be closed when the write lands** — it holds
prefs in memory and rewrites the file on quit, so a write while it is open is
silently discarded. Ask the user to close it, then re-run.

---

## 5. Wallpaper workflow

Wallpapers come from `new-wallpaper "<prompt>"` — a personal script on `PATH`,
**not** in this repo. Do not hand-source images, and do not confuse it with
`lib/theme-auto/wallpaper.py`, which only draws the gradient placeholder.

The loop:

1. **Propose 2–3 thematic directions** grounded in the palette, in one short
   paragraph each. Let the user pick and refine.
2. **Generate one**, set it live so they can see it full-screen, then **stop and
   wait**. Do not roll a batch — they review each one.
3. **Measure it against the palette** (nearest-slot per dominant colour, hue
   histogram, mean luma) and report what actually landed versus what was asked.
4. **Iterate on the brief.** When a specific muted hue will not appear, name it
   as a **pigment** ("ultramarine mixed with dioxazine purple") rather than a
   colour word — that has flipped a 3% hit rate to 96%.
5. **Kill unwanted elements structurally, not by negation.** Repeatedly telling
   the model "no sun" produces a sun. Removing the thing that implies it — no
   horizon, no layered ridges, "the sky has no lighter region" — works.
6. Once pinned, **grade rather than re-roll** if the composition is right and
   only the palette is off.
7. **Ship**: re-encode to ~1.5–2.0M (`magick <src> -quality 88..95`), write to
   `themes/<name>/.config/background`, commit.

**Grading discipline.** Per-channel *offsets* preserve local contrast; blending
toward a flat colour scales every local difference by (1−t) and flattens the
brushwork. Gate a tint by chroma (mask on max−min) so saturated accents are left
untouched while a near-neutral ground is corrected. Check shadow noise at 100%
before shipping — and report the measurement even when it contradicts what you
predicted.

**Replacing an existing wallpaper needs
`systemctl --user restart hyprpaper.service`** — the seam path is unchanged and
only the content differs, so the live push re-serves the cached decode and the
old image stays on screen. A theme *switch* is fine.

---

## 6. Overrides discipline

**Editing `themes/` directly is always wrong** — the next `build-themes.sh` run
silently reverts it. Hand-tuning goes in `tools/theme-overrides/<theme>/`, as a
whole file mirroring its path.

Adding an override is a decision to **maintain that file by hand forever**: it
stops tracking palette and seam-format changes. Add one deliberately. In
practice a polishing session will add several, and that is fine — that is what
polishing *is* — but say so when you create the first one for a seam.

**A diverging override is not drift.** The generated assignment is a default,
and a theme is free to want something else. When an emitter change lands, report
which overrides pin what you just changed so the difference is *visible*, then
leave them alone unless asked. Do not present that list as a to-do.

The exception is an override that inherited a **defect** rather than choosing a
treatment — same wrong direction, same unreadable pair. Those are worth
offering to fix, but still offer; do not sweep them in unasked.

---

## 7. Verification cookbook

Reading the file back proves nothing. Prove it rendered.

| Seam | How |
|---|---|
| starship | `starship prompt --status=0 --path=<dir>` — parse the real escape sequences to see which colours resolved |
| waybar / walker / btop | `grim -o <output>`, then sample pixels with ImageMagick or PIL |
| btop / walker key sets | diff the generated keys against the previous set — a typo'd key falls back **silently** instead of erroring |
| nvim | `nvim --headless` + `dofile` on the theme file |
| kitty / ghostty | `killall -SIGUSR1 kitty` / `-SIGUSR2 ghostty`; ghostty needs a `config-file` include, not `theme =` |
| tmux | **`tmux source-file ~/.tmux.conf`** — there is no signal reload; a stale bar is an unreloaded server, not a broken seam |
| hyprland | `hyprctl reload` |
| wallpaper | `hyprctl hyprpaper wallpaper "<mon>,<abspath>"` per monitor — bare path only, no `cover:` prefix |

`hyprctl clients` reports **global** coordinates — subtract the monitor's `x`/`y`
before cropping a screenshot.

After any seam change on the live theme: `dotfiles link`, then reload that tool.

---

## 8. Traps worth re-reading before a session

The full list is in AGENTS.md. The ones that bite *during* a session:

- **`c0` is the background** in 8 of 41 palettes, so anything using it as a
  distinct surface vanishes there.
- **A light palette's "bright" slots can be darker than its normal ones.**
- **`c7` is not reliably a light grey** on light palettes.
- **`hyprland/workspaces` has no `.occupied` class** — it marks the *empty* ones.
- **A conflict anywhere in the plan must never abort a theme switch** —
  `df_apply_plan` returns 1 after the links are already applied, which under
  `set -euo pipefail` kills the reload. Symptom: "theme switching does nothing
  and hyprctl shows 4 errors".
- **`build-themes.sh` must reproduce `themes/` byte-for-byte** —
  `tests/theme-build.bats` enforces it. When it fails, either teach the emitter
  the difference or record it in an override; never re-edit `themes/`.
- **The waybar switcher runs the switch detached** (`setsid`), because reloading
  waybar kills its on-click child tree mid-sequence.
- When adding a pairing to the emitter, **measure it across every palette**, not
  just the theme in front of you. A sweep over `themes/*/` takes seconds and has
  caught constants that looked right on one theme and failed on sixteen.

---

## 9. Finishing

Run the full gate before committing anything non-trivial:

```bash
./lint.sh && ./test.sh && ./tools/contrast-sweep.sh
```

`contrast-sweep.sh` reads `themes/*/` as committed and reports every pair below
target. Compare it **before and after** — a raw count is not evidence, a diff of
the two lists is.

**One commit per seam.** The message should say what changed, what it measures,
and *why the previous value was wrong* — future sessions read these to
understand a decision, and "tweak colours" tells them nothing. When a change
reaches the emitter, state the blast radius (how many themes moved) and name the
overrides it could not reach.

**Push only when explicitly asked.** Commits accumulate across a session and the
user pushes in batches.

Close by listing what is still open — untouched seams, known defects you chose
not to fix, and anything you deferred — so the next session has a starting
point.
