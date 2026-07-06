#!/usr/bin/env python3
# wallpaper.py - generate a subtle diagonal gradient wallpaper from a theme's
# palette. A dependency-light default so every theme has a matching wallpaper;
# drop a real image in themes/<name>/.config/background to override.
#
# usage: wallpaper.py <out.png> <bg-hex> <accent-hex> [accent2-hex] [dark|light]
import sys

try:
    from PIL import Image
except ModuleNotFoundError:
    sys.stderr.write("wallpaper.py: Pillow (PIL) is required\n")
    sys.exit(2)

W, H = 2560, 1440
S = 96  # small canvas; bicubic-upscaled to WxH for a smooth, tiny-cost gradient


def hx(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def mix(a, b, t):
    return tuple(round(a[i] + (b[i] - a[i]) * t) for i in range(3))


def scale(c, f):
    return tuple(max(0, min(255, round(x * f))) for x in c)


def main():
    if len(sys.argv) < 4:
        sys.stderr.write("usage: wallpaper.py <out> <bg> <accent> [accent2] [dark|light]\n")
        return 2
    out = sys.argv[1]
    bg = hx(sys.argv[2])
    accent = hx(sys.argv[3])
    mode = sys.argv[5] if len(sys.argv) > 5 else "dark"

    if mode == "light":
        c0, c1, c2 = scale(bg, 1.05), bg, mix(bg, accent, 0.12)
    else:
        c0, c1, c2 = scale(bg, 0.66), bg, mix(bg, accent, 0.16)

    small = Image.new("RGB", (S, S))
    px = small.load()
    for y in range(S):
        for x in range(S):
            t = (x + y) / (2 * (S - 1))  # diagonal 0..1
            px[x, y] = mix(c0, c1, t / 0.5) if t < 0.5 else mix(c1, c2, (t - 0.5) / 0.5)
    small.resize((W, H), Image.BICUBIC).save(out, format="PNG")
    return 0


if __name__ == "__main__":
    sys.exit(main())
