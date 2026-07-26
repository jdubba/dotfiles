#!/usr/bin/env python3
"""tools/build-palette-pages.py - render docs/palettes/<theme>.html for every theme.

A swatch page per theme: the 16-colour palette with its slot names, the seams
the emitter derives from it, and every text pair measured. The slot names are
the point -- "c11 for the inactive dot" is a usable instruction in a way that
"#c47b28 for the inactive dot" is not, and these pages exist so a theming
session has that vocabulary in front of it.

Everything is read from the shipped theme, so a page never drifts from what is
actually installed:

    .config/kitty/current-theme.conf   the palette (bg, fg, c0..c15)
    .config/waybar/colors.css          the bar seams
    .config/starship.toml              the prompt seams

Two metrics, and they are not interchangeable (see AGENTS.md):

    WCAG contrast  for TEXT   -- relative luminance only
    CIELAB dE      for SHAPES -- the powerline separators are filled glyphs,
                                 and WCAG rates amber-on-plum at 1.39:1 while
                                 it is plainly visible at ~79 dE

This is a docs generator, so unlike the emitter it may use python freely; it is
not on any runtime path.

Usage: tools/build-palette-pages.py [name ...]   (no args = all)
"""
import html
import os
import re
import sys

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
THEMES = os.path.join(REPO, "themes")
OUTDIR = os.path.join(REPO, "docs", "palettes")

SLOT_NAMES = ["black", "red", "green", "yellow", "blue", "magenta", "cyan", "white",
              "br black", "br red", "br green", "br yellow", "br blue", "br magenta",
              "br cyan", "br white"]

# Colours a theme's upstream spec defines that the 16 ANSI slots cannot carry.
#
# The seams split into two groups. kitty/ghostty publish an ANSI palette and
# bat/fzf follow it, so those are locked to the sixteen. Everything else --
# waybar and walker (GTK CSS), hypr and hyprlock (raw hex), starship and tmux
# (truecolor escapes) -- takes any colour at all, so a theme with roles outside
# its ANSI mapping can still use them there. Recording them here puts them in
# front of the eye during a tuning session instead of buried in a vendor repo.
#
# Rose Pine is the clearest case: a ROLE-based spec of nineteen colours squeezed
# into sixteen slots, so upstream's own kitty port duplicates all seven
# normal/bright pairs and six roles never appear at all -- including `leaf`, a
# whole accent hue, and a three-step highlight ramp that is exactly what a bar
# wants for surfaces. Dracula is the same shape (#44475a, #ffb86c) and could be
# added here; its overrides currently carry those by hand.
OFF_SLOT = {
    "rose-pine": [
        ("surface", "#1f1d2e", "panel ground, one step above base"),
        ("highlight_low", "#21202e", "subtlest row highlight"),
        ("highlight_med", "#403d52", "selection — upstream kitty uses this"),
        ("highlight_high", "#524f67", "borders and dividers"),
        ("subtle", "#908caa", "dim ink between muted and text"),
        ("leaf", "#95b1ac", "a seventh accent — the palette's only green"),
    ],
    "rose-pine-moon": [
        ("surface", "#2a273f", "panel ground, one step above base"),
        ("highlight_low", "#2a283e", "subtlest row highlight"),
        ("highlight_med", "#44415a", "selection"),
        ("highlight_high", "#56526e", "borders and dividers"),
        ("subtle", "#908caa", "dim ink between muted and text"),
        ("leaf", "#95b1ac", "a seventh accent — the palette's only green"),
    ],
    "rose-pine-dawn": [
        ("surface", "#fffaf3", "panel ground, one step above base"),
        ("highlight_low", "#f4ede8", "subtlest row highlight"),
        ("highlight_med", "#dfdad9", "selection"),
        ("highlight_high", "#cecacd", "borders and dividers"),
        ("subtle", "#797593", "dim ink between muted and text"),
        ("leaf", "#6d8f89", "a seventh accent — the palette's only green"),
    ],
}


# --- colour maths -----------------------------------------------------------

def rgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def _lin(c):
    c /= 255
    return c / 12.92 if c <= 0.03928 else ((c + 0.055) / 1.055) ** 2.4


def lum(h):
    r, g, b = (_lin(x) for x in rgb(h))
    return 0.2126 * r + 0.7152 * g + 0.0722 * b


def contrast(a, b):
    la, lb = lum(a), lum(b)
    hi, lo = max(la, lb), min(la, lb)
    return (hi + 0.05) / (lo + 0.05)


def lab(h):
    def f(u):
        u = u / 255
        return u / 12.92 if u <= 0.04045 else ((u + 0.055) / 1.055) ** 2.4
    r, g, b = (f(x) for x in rgb(h))
    x = (0.4124 * r + 0.3576 * g + 0.1805 * b) / 0.95047
    y = 0.2126 * r + 0.7152 * g + 0.0722 * b
    z = (0.0193 * r + 0.1192 * g + 0.9505 * b) / 1.08883

    def q(t):
        return t ** (1 / 3) if t > 0.008856 else 7.787 * t + 16 / 116
    fx, fy, fz = q(x), q(y), q(z)
    return (116 * fy - 16, 500 * (fx - fy), 200 * (fy - fz))


def delta_e(a, b):
    return sum((x - y) ** 2 for x, y in zip(lab(a), lab(b))) ** 0.5


# --- readers ----------------------------------------------------------------

def read_kitty(d):
    """Palette: {'bg':…, 'fg':…, 'c0'..'c15'}."""
    p = {}
    for line in open(os.path.join(d, ".config/kitty/current-theme.conf")):
        m = re.match(r"^(background|foreground)\s+(#\w{6})", line)
        if m:
            p["bg" if m.group(1) == "background" else "fg"] = m.group(2).lower()
        m = re.match(r"^color(\d+)\s+(#\w{6})", line)
        if m:
            p["c" + m.group(1)] = m.group(2).lower()
    return p


def read_waybar(d):
    f = os.path.join(d, ".config/waybar/colors.css")
    out = {}
    if not os.path.exists(f):
        return out
    for m in re.finditer(r"^@define-color\s+(\S+)\s+(.+?);", open(f).read(), re.M):
        out[m.group(1)] = m.group(2).strip()
    return out


def read_starship(d):
    f = os.path.join(d, ".config/starship.toml")
    if not os.path.exists(f):
        return {}
    return dict(re.findall(r"^(color_\w+) = '(#\w{6})'", open(f).read(), re.M))


def is_hex(v):
    return bool(v) and re.fullmatch(r"#\w{6}", v)


# --- rendering --------------------------------------------------------------

def swatch(hexv, label, sub=""):
    """A swatch tile. Ink is whichever of fg/bg reads better on the colour."""
    ink = "#141414" if lum(hexv) > 0.18 else "#f0f0f0"
    return f"""<div class="sw" style="background:{hexv};color:{ink}">
  <span class="sw-label">{html.escape(label)}</span>
  <span class="sw-hex">{hexv.upper()}</span>
  <span class="sw-sub">{html.escape(sub)}</span>
</div>"""


def ratio_cls(r, target):
    if r >= target:
        return "ok"
    if r >= target * 0.66:
        return "warn"
    return "bad"


def pair_row(role, fg, bg, target):
    r = contrast(fg, bg)
    return f"""<tr>
  <td class="role">{html.escape(role)}</td>
  <td><span class="chip" style="background:{bg};color:{fg}">Ag sample</span></td>
  <td class="mono">{fg.upper()}</td>
  <td class="mono">{bg.upper()}</td>
  <td class="ratio {ratio_cls(r, target)}">{r:.2f}:1</td>
  <td class="target">{target:.1f}</td>
</tr>"""


def sep_row(role, glyph, on):
    """Separators are filled shapes: judge by dE, and show WCAG only for reference."""
    r = contrast(glyph, on)
    d = delta_e(glyph, on)
    cls = "ok" if d >= 25 else ("warn" if d >= 12 else "bad")
    verdict = "distinct" if d >= 25 else ("subtle" if d >= 12 else "merges")
    return f"""<tr>
  <td class="role">{html.escape(role)}</td>
  <td><span class="chip" style="background:{on};color:{glyph}">&#xe0b0;&#xe0b0;</span></td>
  <td class="mono">{glyph.upper()}</td>
  <td class="mono">{on.upper()}</td>
  <td class="ratio {cls}">{d:.0f}</td>
  <td class="target">{r:.2f}:1</td>
  <td class="verdict {cls}">{verdict}</td>
</tr>"""


CSS = """
  :root {
    --bg: %(page_bg)s; --fg: %(page_fg)s; --line: %(line)s;
    --mono: ui-monospace, "JetBrainsMono Nerd Font", "SFMono-Regular", Menlo, monospace;
  }
  body {
    margin: 0; padding: 2.5rem clamp(1rem, 4vw, 3rem) 5rem;
    background: var(--bg); color: var(--fg);
    font: 15px/1.55 ui-sans-serif, "DM Sans", system-ui, sans-serif;
  }
  header { margin-bottom: 2.5rem; }
  h1 { font-size: 2rem; margin: 0 0 .35rem; letter-spacing: -.02em; }
  .lede { opacity: .75; max-width: 60ch; margin: 0; }
  h2 {
    font-size: .82rem; text-transform: uppercase; letter-spacing: .12em;
    opacity: .6; margin: 2.75rem 0 .9rem; font-weight: 600;
  }
  h2 + .note { margin-top: -.5rem; }
  .note { font-size: .85rem; opacity: .7; margin: 0 0 1rem; max-width: 70ch; }
  .grid {
    display: grid; gap: .6rem;
    grid-template-columns: repeat(auto-fill, minmax(150px, 1fr));
  }
  .sw {
    border-radius: 10px; padding: .85rem .8rem 0.7rem;
    min-height: 78px; display: flex; flex-direction: column; gap: .1rem;
    border: 1px solid rgba(128,128,128,.35);
  }
  .sw-label { font-size: .8rem; font-weight: 600; }
  .sw-hex { font-family: var(--mono); font-size: .78rem; opacity: .9; }
  .sw-sub { font-family: var(--mono); font-size: .68rem; opacity: .72; margin-top: auto; }
  .tablewrap { overflow-x: auto; }
  table { border-collapse: collapse; width: 100%%; min-width: 560px; }
  th, td { text-align: left; padding: .4rem .7rem; border-bottom: 1px solid var(--line); }
  th {
    font-size: .7rem; text-transform: uppercase; letter-spacing: .09em;
    opacity: .55; font-weight: 600;
  }
  .role { font-weight: 500; }
  .mono, .ratio, .target, .verdict { font-family: var(--mono); font-size: .82rem; }
  .target { opacity: .45; }
  .chip {
    display: inline-block; padding: .18rem .7rem; border-radius: 999px;
    font-size: .82rem; white-space: nowrap;
  }
  .ratio.ok, .verdict.ok { color: %(ok)s; }
  .ratio.warn, .verdict.warn { color: %(warn)s; }
  .ratio.bad, .verdict.bad { color: %(bad)s; font-weight: 700; }
  .legend { font-size: .8rem; opacity: .7; margin-top: .6rem; }
"""


def build(name):
    d = os.path.join(THEMES, name)
    pal = read_kitty(d)
    if "bg" not in pal or "c15" not in pal:
        return None
    wb, st = read_waybar(d), read_starship(d)
    BG, FG = pal["bg"], pal["fg"]
    dark = lum(BG) < 0.18

    base = [swatch(BG, "background", f"vs fg {contrast(BG, FG):.2f}:1"),
            swatch(FG, "foreground", f"vs bg {contrast(FG, BG):.2f}:1")]
    normals, brights = [], []
    for i in range(16):
        h = pal["c%d" % i]
        sub = f"bg {contrast(h, BG):.2f} · fg {contrast(h, FG):.2f}"
        (normals if i < 8 else brights).append(swatch(h, f"c{i} · {SLOT_NAMES[i]}", sub))

    # Palette quirks worth stating outright -- these are the assumptions that
    # break formulas (AGENTS.md: "c0 IS the background in 8 of 41 palettes").
    quirks = []
    dupes = {}
    for k in ["fg"] + ["c%d" % i for i in range(16)]:
        dupes.setdefault(pal[k], []).append(k)
    for hexv, keys in dupes.items():
        if len(keys) > 1:
            quirks.append("<code>" + "</code>, <code>".join(keys) + f"</code> are all <code>{hexv}</code>")
    if delta_e(pal["c0"], BG) < 12:
        quirks.append(f"<code>c0</code> (<code>{pal['c0']}</code>) is all but the background")
    quirk_html = ("<p class=\"legend\">Note: " + "; ".join(quirks) + ".</p>") if quirks else ""

    wb_sw = [swatch(v, k, "") for k, v in wb.items() if is_hex(v)]

    wb_pairs = []
    if wb:
        def w(k):
            return wb.get(k, "")
        if is_hex(w("bar-fg")) and is_hex(w("bar-bg")):
            wb_pairs.append(("bar text", w("bar-fg"), w("bar-bg"), 4.5))
        for p in ("brand", "stats", "ctrl", "theme"):
            f, b = w(f"pill-{p}-fg"), w(f"pill-{p}-bg")
            if is_hex(f) and is_hex(b):
                wb_pairs.append((f"{p} pill", f, b, 4.5))
        for lbl, k in (("ws dot empty", "ws-fg"), ("ws dot occupied", "ws-fg-occupied"),
                       ("ws dot active", "ws-fg-active")):
            f, b = w(k), w("ws-bg")
            if is_hex(f) and is_hex(b):
                wb_pairs.append((lbl, f, b, 3.0))
        if is_hex(w("ws-bg")) and is_hex(w("bar-bg")):
            wb_pairs.append(("ws pill on bar", w("ws-bg"), w("bar-bg"), 3.0))

    st_pairs, sep_pairs = [], []
    if st:
        def s(k):
            return st.get(k, "")
        for lbl, f, b, t in (
            ("os / user / host", s("color_os_fg"), s("color_os_bg"), 4.5),
            ("directory path", s("color_dir_fg"), s("color_dir_bg"), 4.5),
            ("repo root", s("color_dir_repo_fg"), s("color_dir_bg"), 4.5),
            ("git branch", s("color_repo_fg"), s("color_repo_bg"), 4.5),
            ("git change counts", s("color_repo_change_fg"), s("color_repo_change_bg"), 4.5),
            ("git ahead/behind", s("color_repo_diverge_fg"), s("color_repo_diverge_bg"), 4.5),
            ("root-shell warning", s("color_root_fg"), s("color_os_bg"), 4.5),
            ("time / ip", s("color_fg_right"), BG, 4.5),
            ("separators (chrome)", s("color_fg_sep"), BG, 3.0),
        ):
            if is_hex(f) and is_hex(b):
                st_pairs.append((lbl, f, b, t))
        for lbl, g, o in (
            ("os cap → terminal", s("color_os_bg"), BG),
            ("os → directory", s("color_os_bg"), s("color_dir_bg")),
            ("directory cap → terminal", s("color_dir_bg"), BG),
            ("branch cap → terminal", s("color_repo_bg"), BG),
            ("branch → changes", s("color_repo_change_bg"), s("color_repo_bg")),
            ("changes → ahead/behind", s("color_repo_diverge_bg"), s("color_repo_change_bg")),
            ("ahead/behind cap → terminal", s("color_repo_diverge_bg"), BG),
        ):
            if is_hex(g) and is_hex(o):
                sep_pairs.append((lbl, g, o))

    theme_css = CSS % {
        "page_bg": BG, "page_fg": FG,
        "line": "rgba(255,255,255,.14)" if dark else "rgba(0,0,0,.12)",
        "ok": "#7fcf9a" if dark else "#2f6d3c",
        "warn": "#e0b070" if dark else "#a2620d",
        "bad": "#f08d8d" if dark else "#a5222f",
    }

    def section(title, body, note=""):
        return f"<h2>{title}</h2>\n{note}\n{body}\n"

    parts = [f"""<header>
  <h1>{html.escape(name)}</h1>
  <p class="lede">The {'dark' if dark else 'light'} palette as shipped in
  <code>themes/{html.escape(name)}/</code>, plus the seams derived from it.
  Slot names (<code>c0</code>&ndash;<code>c15</code>, <code>bg</code>,
  <code>fg</code>) are the vocabulary for talking about a theme &mdash; use them
  rather than hex. Text pairs are WCAG: 4.5:1 for text, 3.0:1 for chrome.</p>
</header>"""]
    parts.append(section("Base", f'<div class="grid">{"".join(base)}</div>'))
    parts.append(section("Normal (c0&ndash;c7)", f'<div class="grid">{"".join(normals)}</div>'))
    parts.append(section("Bright (c8&ndash;c15)",
                         f'<div class="grid">{"".join(brights)}</div>' + quirk_html))

    # Off-slot roles: usable everywhere except the terminal's ANSI palette.
    off = OFF_SLOT.get(name)
    if off:
        tiles = "".join(
            swatch(hexv, role, f"{contrast(hexv, BG):.2f} on bg") for role, hexv, _ in off)
        rows = "".join(
            f'<tr><td class="role">{html.escape(role)}</td>'
            f'<td><span class="chip" style="background:{hexv};color:'
            f'{FG if contrast(FG, hexv) >= contrast(BG, hexv) else BG}">&nbsp;Ag&nbsp;</span></td>'
            f'<td class="mono">{hexv.upper()}</td>'
            f'<td class="ratio">{contrast(hexv, BG):.2f}:1</td>'
            f'<td class="target">{delta_e(hexv, BG):.0f}</td>'
            f'<td>{html.escape(note)}</td></tr>'
            for role, hexv, note in off)
        note = ("""<p class="note">Roles this theme's upstream spec defines that the sixteen
  ANSI slots cannot carry. <strong>Usable in waybar, walker, hypr/hyprlock,
  starship and tmux</strong> &mdash; GTK CSS, raw hex and truecolor escapes take any
  colour. <strong>Not usable in kitty/ghostty</strong>, whose palette is the sixteen,
  nor in bat/fzf, which follow it. Using one means hand-maintaining that seam:
  the emitter derives only from the ANSI slots.</p>""")
        parts.append(section("Beyond the ANSI slots",
                             f'<div class="grid">{tiles}</div>'
                             f'<div class="tablewrap"><table>'
                             f'<tr><th>role</th><th>sample</th><th>hex</th>'
                             f'<th>vs bg</th><th>&Delta;E</th><th>intent</th></tr>'
                             f'{rows}</table></div>', note))
    if wb_sw:
        parts.append(section("Waybar seams", f'<div class="grid">{"".join(wb_sw)}</div>'))
    if wb_pairs:
        rows = "".join(pair_row(*p) for p in wb_pairs)
        parts.append(section("Waybar measured pairs", f"""<div class="tablewrap"><table>
  <tr><th>role</th><th>sample</th><th>fg</th><th>bg</th><th>ratio</th><th>target</th></tr>
  {rows}</table></div>"""))
    if st_pairs:
        rows = "".join(pair_row(*p) for p in st_pairs)
        parts.append(section("Starship measured pairs", f"""<div class="tablewrap"><table>
  <tr><th>segment</th><th>sample</th><th>fg</th><th>bg</th><th>ratio</th><th>target</th></tr>
  {rows}</table></div>"""))
    if sep_pairs:
        rows = "".join(sep_row(*p) for p in sep_pairs)
        note = ("""<p class="note">A separator is a filled glyph &mdash; one pill's background
  drawn on the next pill's &mdash; so it is judged by perceptual distance
  (CIELAB &Delta;E), not WCAG. WCAG measures luminance only and rates plainly
  visible pairs as failures: amber on plum is 1.39:1 and unmistakable at
  79&nbsp;&Delta;E. Under 12&nbsp;&Delta;E the two pills genuinely merge.</p>""")
        parts.append(section("Starship powerline separators", f"""<div class="tablewrap"><table>
  <tr><th>seam</th><th>sample</th><th>glyph</th><th>on</th><th>&Delta;E</th><th>WCAG</th><th>reads as</th></tr>
  {rows}</table></div>""", note))

    doc = f"""<!doctype html>
<html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{html.escape(name)} &mdash; palette &amp; seams</title>
<style>{theme_css}</style>
</head><body>
{''.join(parts)}
</body></html>
"""
    os.makedirs(OUTDIR, exist_ok=True)
    out = os.path.join(OUTDIR, f"{name}.html")
    with open(out, "w") as fh:
        fh.write(doc)
    return out


INDEX_CSS = """
  :root {
    --bg: #fbfbfc; --fg: #1c1c22; --card: #ffffff; --line: rgba(0,0,0,.10);
    --mono: ui-monospace, "JetBrainsMono Nerd Font", "SFMono-Regular", Menlo, monospace;
  }
  @media (prefers-color-scheme: dark) {
    :root:not([data-theme="light"]) {
      --bg: #16161a; --fg: #e8e8ee; --card: #1e1e24; --line: rgba(255,255,255,.12);
    }
  }
  :root[data-theme="dark"] {
    --bg: #16161a; --fg: #e8e8ee; --card: #1e1e24; --line: rgba(255,255,255,.12);
  }
  :root[data-theme="light"] {
    --bg: #fbfbfc; --fg: #1c1c22; --card: #ffffff; --line: rgba(0,0,0,.10);
  }
  body {
    margin: 0; padding: 2.5rem clamp(1rem, 4vw, 3rem) 5rem;
    background: var(--bg); color: var(--fg);
    font: 15px/1.55 ui-sans-serif, "DM Sans", system-ui, sans-serif;
  }
  header { margin-bottom: 2.5rem; }
  h1 { font-size: 2rem; margin: 0 0 .35rem; letter-spacing: -.02em; }
  .lede { opacity: .75; max-width: 62ch; margin: 0; }
  h2 {
    font-size: .82rem; text-transform: uppercase; letter-spacing: .12em;
    opacity: .6; margin: 2.75rem 0 .9rem; font-weight: 600;
  }
  .cards { display: grid; gap: .9rem; grid-template-columns: repeat(auto-fill, minmax(260px, 1fr)); }
  a.card {
    display: block; text-decoration: none; color: inherit; background: var(--card);
    border: 1px solid var(--line); border-radius: 12px; overflow: hidden;
    transition: transform .12s ease, border-color .12s ease;
  }
  a.card:hover { transform: translateY(-2px); border-color: currentColor; }
  .prev { display: block; height: 64px; position: relative; }
  .ramp { display: flex; height: 26px; }
  .ramp i { flex: 1 1 0; display: block; }
  .meta { display: flex; align-items: baseline; gap: .5rem; padding: .6rem .75rem .7rem; }
  .nm { font-weight: 600; font-size: .95rem; }
  .mode { font-family: var(--mono); font-size: .68rem; opacity: .5; margin-left: auto; }
  .legend { font-size: .8rem; opacity: .65; margin-top: 2rem; }
"""


def build_index(names):
    """A card per theme: its own bg/fg with the 16 slots as a ramp beneath."""
    groups = {"light": [], "dark": []}
    for name in names:
        pal = read_kitty(os.path.join(THEMES, name))
        if "bg" not in pal or "c15" not in pal:
            continue
        dark = lum(pal["bg"]) < 0.18
        ramp = "".join(f'<i style="background:{pal["c%d" % i]}"></i>' for i in range(16))
        card = f"""<a class="card" href="{html.escape(name)}.html">
  <span class="prev" style="background:{pal['bg']};color:{pal['fg']}">
    <span style="display:block;padding:.55rem .75rem;font-weight:600">Ag &mdash; {html.escape(name)}</span>
    <span class="ramp" style="position:absolute;bottom:0;left:0;right:0">{ramp}</span>
  </span>
  <span class="meta"><span class="nm">{html.escape(name)}</span>
  <span class="mode">{'dark' if dark else 'light'}</span></span>
</a>"""
        groups["dark" if dark else "light"].append(card)

    body = ""
    for mode in ("dark", "light"):
        if groups[mode]:
            body += (f'<h2>{mode} ({len(groups[mode])})</h2>\n'
                     f'<div class="cards">{"".join(groups[mode])}</div>\n')

    doc = f"""<!doctype html>
<html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Theme palettes</title>
<style>{INDEX_CSS}</style>
</head><body>
<header>
  <h1>Theme palettes</h1>
  <p class="lede">One swatch page per theme, generated from the shipped seams by
  <code>tools/build-palette-pages.py</code>. Each page names every colour by its
  slot (<code>c0</code>&ndash;<code>c15</code>, <code>bg</code>,
  <code>fg</code>) &mdash; that is the vocabulary for steering a theme, and it
  beats reading hex aloud.</p>
</header>
{body}<p class="legend">Cards show each theme's own background and foreground,
with its sixteen palette slots as the strip beneath. <code>themes/auto</code> is
wallpaper-derived and machine-local, so it has no page.</p>
</body></html>
"""
    os.makedirs(OUTDIR, exist_ok=True)
    out = os.path.join(OUTDIR, "index.html")
    with open(out, "w") as fh:
        fh.write(doc)
    return out


def main():
    want = sys.argv[1:]
    names = sorted(n for n in os.listdir(THEMES)
                   if os.path.isdir(os.path.join(THEMES, n)) and n != "auto")
    built = [n for n in names if (not want or n in want) and build(n)]
    # The index always covers every theme, not just the ones rebuilt, so a
    # single-theme run cannot silently drop the others from it.
    build_index(names)
    print(f"wrote {len(built)} palette pages + index to docs/palettes/")


if __name__ == "__main__":
    main()
