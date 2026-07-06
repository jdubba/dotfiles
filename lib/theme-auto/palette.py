#!/usr/bin/env python3
# palette.py - derive a normalized dark colour palette from an image.
#
# Part of dotfiles auto-theming (the fallback backend, used when neither
# `wallust` nor `pywal` is installed). Reads an image with Pillow, extracts
# dominant colours, and prints a normalized, always-dark palette as
# `KEY=#RRGGBB` lines on stdout:
#
#   background, foreground, cursor, color0 .. color15
#
# The Bash generator (lib/theme-auto.sh) consumes these keys and templates
# them into every themed tool. Determinism and legible contrast on a dark
# background are prioritised over artistic accuracy (wallust is the "nice"
# backend; this is the dependency-light fallback).
#
# Usage: palette.py <image>
import colorsys
import sys

try:
    from PIL import Image
except ModuleNotFoundError:
    sys.stderr.write("palette.py: Pillow (PIL) is required for the fallback backend\n")
    sys.exit(2)


def clamp(x, lo=0.0, hi=1.0):
    return max(lo, min(hi, x))


def hls_to_hex(h, l, s):
    r, g, b = colorsys.hls_to_rgb(h % 1.0, clamp(l), clamp(s))
    return "#{:02x}{:02x}{:02x}".format(round(r * 255), round(g * 255), round(b * 255))


def rgb_to_hls(rgb):
    r, g, b = (c / 255.0 for c in rgb)
    h, l, s = colorsys.rgb_to_hls(r, g, b)
    return h, l, s


def dominant_colors(path, n=16):
    img = Image.open(path).convert("RGB")
    img.thumbnail((400, 400))
    # Median-cut quantisation gives stable, representative clusters.
    q = img.quantize(colors=n, method=Image.MEDIANCUT).convert("RGB")
    counts = q.getcolors(img.width * img.height) or []
    # Most frequent first.
    counts.sort(key=lambda c: c[0], reverse=True)
    return [rgb for _, rgb in counts]


# ANSI slots 1..6 target hues (red, green, yellow, blue, magenta, cyan).
TARGET_HUES = {
    1: 0.0,      # red
    2: 120 / 360,  # green
    3: 60 / 360,   # yellow
    4: 220 / 360,  # blue
    5: 300 / 360,  # magenta
    6: 180 / 360,  # cyan
}


def hue_dist(a, b):
    d = abs(a - b) % 1.0
    return min(d, 1.0 - d)


def pick_accents(colors):
    """Choose a saturated colour per target hue, synthesising if none fits."""
    hls = [rgb_to_hls(c) for c in colors]
    accents = {}
    for slot, target in TARGET_HUES.items():
        best = None
        best_score = -1.0
        for (h, l, s) in hls:
            if s < 0.18 or l < 0.12 or l > 0.9:
                continue
            score = s - hue_dist(h, target) * 2.0
            if score > best_score:
                best_score = score
                best = (h, l, s)
        if best is None or hue_dist(best[0], target) > 0.12:
            # Synthesise a legible colour at the target hue.
            accents[slot] = hls_to_hex(target, 0.62, 0.55)
        else:
            h, l, s = best
            # Normalise for visibility on a dark background.
            accents[slot] = hls_to_hex(h, clamp(l, 0.55, 0.72), clamp(s, 0.45, 0.9))
    return accents


def main():
    if len(sys.argv) < 2:
        sys.stderr.write("usage: palette.py <image>\n")
        return 2
    colors = dominant_colors(sys.argv[1])
    if not colors:
        sys.stderr.write("palette.py: no colours extracted\n")
        return 1

    # Base hue: from the most dominant reasonably-saturated colour.
    base_h, base_s = 0.0, 0.0
    for c in colors:
        h, l, s = rgb_to_hls(c)
        if s > base_s:
            base_h, base_s = h, s

    # Always-dark background/foreground derived from the dominant hue.
    background = hls_to_hex(base_h, 0.075, min(base_s, 0.25))
    foreground = hls_to_hex(base_h, 0.85, 0.08)
    cursor = foreground

    accents = pick_accents(colors)

    pal = {}
    pal["background"] = background
    pal["foreground"] = foreground
    pal["cursor"] = cursor

    # color0/8 greys anchored to the background hue; 7/15 light greys.
    pal["color0"] = hls_to_hex(base_h, 0.16, min(base_s, 0.22))
    pal["color8"] = hls_to_hex(base_h, 0.35, min(base_s, 0.15))
    pal["color7"] = hls_to_hex(base_h, 0.78, 0.06)
    pal["color15"] = hls_to_hex(base_h, 0.93, 0.05)

    # Normal accents 1..6, bright accents 9..14 (lightened).
    for slot in range(1, 7):
        pal["color%d" % slot] = accents[slot]
        h, l, s = rgb_to_hls(tuple(int(accents[slot][i:i + 2], 16) for i in (1, 3, 5)))
        pal["color%d" % (slot + 8)] = hls_to_hex(h, clamp(l + 0.12), s)

    for k in ["background", "foreground", "cursor"] + ["color%d" % i for i in range(16)]:
        print("%s=%s" % (k, pal[k]))
    return 0


if __name__ == "__main__":
    sys.exit(main())
