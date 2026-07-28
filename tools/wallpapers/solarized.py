#!/usr/bin/env python3
"""Solarized wallpaper: a solarized (Sabattier) botanical, drawn to invert exactly.

Two facts about the scheme drive every choice here.

Sixteen of the eighteen palette slots are byte-identical between solarized-dark
and solarized-light; only bg and fg differ, and the base tones swap in
L*-symmetric pairs (base03 15.5 <-> base3 97.0, base02 20.3 <-> base2 92.0,
base01 45.0 <-> base1 65.2). So a composition whose GROUND is made only of base
tones and whose LINES are made only of accents inverts by definition: the tonal
ordering reverses end to end and not one accent pixel moves.

And the eight accents all sit inside an 11-point L* band, 49.1 to 60.1. They are
one lightness. Nothing modelled by light and shade can survive in this palette,
which is why this is flat contour work and not a render -- form is carried by
hue and edge alone.

The Sabattier effect is tone reversal from re-exposure, and its signature is the
Mackie line: a bright rim where two tonal regions meet. Here the Mackie lines are
the accents, so on the dark ground they are the brightest thing in the frame and
on the light ground they become the darkest. The lines solarize when the theme
does.

The two base-tone fields are the other half of the effect. Rather than one hard
division -- which read as a landscape horizon and had nothing to do with the
botanical -- g1 is a FAR layer of the same leaves, silhouetted and near-invisible
in both modes, and g2 is the midrib of each of those leaves.

Run it as `python3 tools/wallpapers/solarized.py <outdir>`; it writes
solarized-dark.jpg and solarized-light.jpg, and it is deterministic, so a rerun
reproduces both byte for byte.

Invertibility is structural, not a post-process. Geometry is built once into one
mask per palette role; render() takes the colour table as an argument and only
chooses what to paint through them. The two images cannot drift apart.
"""
import math
import random
import sys
from PIL import Image, ImageChops, ImageDraw

W, H = 3840, 2160
SS = 2  # supersample factor, for anti-aliased edges on flat colour

ACCENTS = {
    "red": "#dc322f", "orange": "#cb4b16", "yellow": "#b58900",
    "green": "#859900", "cyan": "#2aa198", "blue": "#268bd2",
    "violet": "#6c71c4", "magenta": "#d33682",
}
DARK = {"g0": "#002b36", "g1": "#073642", "g2": "#586e75", **ACCENTS}
LIGHT = {"g0": "#fdf6e3", "g1": "#eee8d5", "g2": "#93a1a1", **ACCENTS}

# painter order: the two base fields, then every contour on top of them
ORDER = ["g1", "g2", "yellow", "cyan", "violet", "orange", "blue", "green",
         "magenta", "red"]


def bez(p0, p1, p2, t):
    u = 1 - t
    return (u * u * p0[0] + 2 * u * t * p1[0] + t * t * p2[0],
            u * u * p0[1] + 2 * u * t * p1[1] + t * t * p2[1])


def bez_d(p0, p1, p2, t):
    u = 1 - t
    return (2 * u * (p1[0] - p0[0]) + 2 * t * (p2[0] - p1[0]),
            2 * u * (p1[1] - p0[1]) + 2 * t * (p2[1] - p1[1]))


def ribbon(p0, p1, p2, w_at, n=72):
    left, right = [], []
    for i in range(n + 1):
        t = i / n
        x, y = bez(p0, p1, p2, t)
        dx, dy = bez_d(p0, p1, p2, t)
        m = math.hypot(dx, dy) or 1.0
        nx, ny = -dy / m, dx / m
        w = w_at(t) / 2
        left.append((x + nx * w, y + ny * w))
        right.append((x - nx * w, y - ny * w))
    return left + right[::-1]


def leaflet(cx, cy, ang, length, width, curl=0.0, n=44):
    """Pointed oval leaflet, widest ~40% along, tapering to a tip. `curl` bends it."""
    pts = []
    for side in (1, -1):
        rng = range(n + 1) if side == 1 else range(n, -1, -1)
        for i in rng:
            t = i / n
            w = width * math.sin(math.pi * (t ** 0.72)) * (1 - t * 0.25)
            a = ang + curl * t
            ca, sa = math.cos(a), math.sin(a)
            u, v = t * length, side * w / 2
            pts.append((cx + u * ca - v * sa, cy + u * sa + v * ca))
    return pts


class Canvas:
    """One anti-aliased mask per palette role, drawn at SS and reduced."""

    def __init__(self):
        self.buf = {r: Image.new("L", (W * SS, H * SS), 0) for r in ORDER}
        self.d = {r: ImageDraw.Draw(self.buf[r]) for r in ORDER}

    def poly(self, role, pts):
        self.d[role].polygon([(x * SS, y * SS) for x, y in pts], fill=255)

    def outline(self, role, pts, width):
        p = [(x * SS, y * SS) for x, y in pts]
        self.d[role].line(p + [p[0]], fill=255, width=max(1, int(width * SS)),
                          joint="curve")

    def finish(self):
        return [(r, self.buf[r].resize((W, H), Image.LANCZOS)) for r in ORDER]


def build():
    rng = random.Random(20260727)
    c = Canvas()

    # ---- the two base fields ------------------------------------------------
    # A FAR layer of the same leaves, silhouetted, so the base tones read as
    # depth behind the sharp contour canopy rather than as a border.
    #
    # Two earlier attempts are worth recording as dead ends. Frame-sized leaves
    # left only their straight flanks in view and read as angular blocks, worse
    # than the chevron they replaced; a scalloped bank across the bottom read as
    # cartoon clouds, because uniform semicircles are not what a leaf edge does.
    # A leaf silhouette only reads as a leaf at a size where its taper and its
    # point are both inside the frame -- hence FAR_SCALE.
    #
    # g1 can hold a big field -- 60% here -- because it is near-invisible in both
    # modes (base02 on base03, base2 on base3). g2 cannot: it is conspicuous in
    # both (L*45 on L*15.5, L*65 on L*97) and takes the picture over. See the
    # note at the midrib below for how that tone ended up drawn rather than
    # derived from these overlaps.
    FAR_SCALE = 0.60
    acc = Image.new("L", (W * SS, H * SS), 0)
    FAR = [
        # cx,    cy,    angle,  length, width, curl
        (0.04, 0.30, 0.62, 0.52, 0.34, 0.30),
        (0.30, 0.10, 1.16, 0.46, 0.30, -0.26),
        (0.58, 0.16, 0.86, 0.54, 0.33, 0.22),
        (0.86, 0.06, 1.34, 0.44, 0.28, -0.30),
        (0.16, 0.66, 0.30, 0.48, 0.31, -0.20),
        (0.44, 0.74, -0.22, 0.56, 0.35, 0.26),
        (0.74, 0.62, 0.44, 0.50, 0.32, -0.24),
        (0.98, 0.52, 2.36, 0.46, 0.29, 0.28),
        (-0.02, 0.94, -0.34, 0.52, 0.30, 0.18),
        (0.62, 1.02, -0.86, 0.50, 0.33, -0.22),
        (0.92, 0.96, -1.42, 0.44, 0.28, 0.24),
        (0.24, 0.44, 1.60, 0.38, 0.24, -0.18),
    ]
    for cx, cy, ang, ln, wd, curl in FAR:
        one = Image.new("L", (W * SS, H * SS), 0)
        pts = leaflet(cx * W, cy * H, ang, ln * W * FAR_SCALE, wd * W * FAR_SCALE, curl)
        ImageDraw.Draw(one).polygon([(x * SS, y * SS) for x, y in pts], fill=60)
        acc = ImageChops.add(acc, one)
    # 60 per leaf, so the accumulator counts overlaps: >=1 paints g1, >=3 paints g2.
    #
    # A DOUBLE overlap was tried and measured a defensible 10.4% of the frame,
    # but the number was the wrong thing to look at. Two leaves crossing is
    # common, so the tone arrived in lower-half fields with straight torn-paper
    # edges where two silhouettes met at a shallow angle -- a pale lumpy mass on
    # the dark ground and, far worse, dirty grey blobs on the cream one. A triple
    # overlap is genuinely the exception, which is what makes it read as dapple
    # rather than as a third field.
    c.buf["g1"] = acc.point(lambda v: 255 if v >= 40 else 0)
    c.buf["g2"] = Image.new("L", (W * SS, H * SS), 0)
    c.d["g1"] = ImageDraw.Draw(c.buf["g1"])
    c.d["g2"] = ImageDraw.Draw(c.buf["g2"])
    # g2 is DRAWN, not emergent: the midrib of each far leaf. Deriving it from
    # overlaps was tried twice and failed in both directions -- a double overlap
    # gave 10.4% of the frame as lower-half fields with straight torn-paper edges
    # where two silhouettes met at a shallow angle, and a triple gave 1.8% as
    # three isolated angular shards that read as rendering glitches. The tone
    # wants a job, not a threshold. A vein follows the form it belongs to, is
    # sparse by construction, and puts the palette's most conspicuous base tone
    # exactly where the eye already is.
    for cx, cy, ang, ln, wd, curl in FAR:
        c.poly("g2", leaflet(cx * W, cy * H, ang, ln * W * FAR_SCALE * 0.90,
                             wd * W * FAR_SCALE * 0.018, curl))

    # ---- the canopy ---------------------------------------------------------
    # Denser and hanging deeper than before, and every bough is contour only --
    # the fill is g1, near enough to the ground that what you read is the line.
    HUES = ["yellow", "cyan", "violet", "orange", "blue", "green", "magenta",
            "red", "cyan", "yellow", "blue", "orange", "violet"]
    boughs = [
        # x0,   ctrl dx, ctrl dy, tip x, tip y, n_leaf, len, line
        (0.02, 0.16, 0.30, 0.31, 0.70, 15, 208, 5),
        (0.15, -0.11, 0.28, -0.02, 0.55, 11, 164, 4),
        (0.26, 0.14, 0.34, 0.49, 0.62, 14, 188, 5),
        (0.36, -0.13, 0.20, 0.16, 0.46, 10, 152, 4),
        (0.45, 0.17, 0.38, 0.72, 0.74, 16, 212, 6),
        (0.55, -0.16, 0.24, 0.34, 0.54, 12, 170, 4),
        (0.63, 0.12, 0.30, 0.85, 0.64, 13, 192, 5),
        (0.72, -0.14, 0.22, 0.52, 0.44, 10, 156, 4),
        (0.81, 0.13, 0.36, 1.02, 0.68, 15, 202, 5),
        (0.90, -0.12, 0.26, 0.70, 0.56, 12, 174, 4),
        (0.99, 0.08, 0.18, 1.09, 0.38, 9, 146, 4),
        (0.09, 0.06, 0.14, 0.19, 0.30, 8, 130, 3),
        (0.68, -0.06, 0.12, 0.60, 0.26, 8, 126, 3),
    ]
    for i, (x0, cdx, cdy, tx, ty, nleaf, llen, lw) in enumerate(boughs):
        p0 = (x0 * W, -H * 0.05)
        p2 = (tx * W, ty * H)
        p1 = ((x0 + cdx) * W, cdy * H)
        acc_name = HUES[i % len(HUES)]
        stem = ribbon(p0, p1, p2, lambda t: 22 * (1 - 0.78 * t))
        c.poly("g1", stem)
        c.outline(acc_name, stem, lw)
        for j in range(nleaf):
            t = 0.10 + 0.88 * (j / max(1, nleaf - 1))
            x, y = bez(p0, p1, p2, t)
            dx, dy = bez_d(p0, p1, p2, t)
            base = math.atan2(dy, dx)
            side = 1 if j % 2 == 0 else -1
            spread = math.radians(50 + 18 * math.sin(j * 1.7 + i))
            scale = (1 - 0.42 * t) * (0.84 + 0.30 * rng.random())
            lf = leaflet(x, y, base + side * spread, llen * scale,
                         llen * scale * 0.44, curl=side * (0.26 if i % 2 else -0.14))
            c.poly("g1", lf)
            c.outline(acc_name, lf, max(3, lw - 1))

    # ---- blades rising from the bottom edge ---------------------------------
    # Long open leaf loops closing the lower frame. These were in the first pass
    # and were cut when the canopy was made denser; the bottom third has read as
    # unfinished ever since. Contour only like everything else, leaning away from
    # each other so they do not stack up into a row.
    BLADES = [
        # x0,   lean,  height, line, accent
        (0.06, -0.04, 0.44, 4, "cyan"),
        (0.13, 0.04, 0.31, 3, "magenta"),
        (0.21, -0.02, 0.22, 3, "yellow"),
        (0.39, 0.03, 0.26, 3, "green"),
        (0.50, -0.03, 0.36, 4, "orange"),
        (0.58, 0.02, 0.19, 3, "blue"),
        (0.83, 0.05, 0.40, 4, "violet"),
        (0.90, -0.04, 0.28, 3, "red"),
        (0.97, 0.03, 0.34, 4, "cyan"),
    ]
    for bx, lean, ln, lw, acc_name in BLADES:
        p0 = (bx * W, H * 1.03)
        p2 = ((bx + lean) * W, (1 - ln) * H)
        p1 = ((bx + lean * 0.25) * W, (1 - ln * 0.45) * H)
        blade = ribbon(p0, p1, p2,
                       lambda t: 96 * math.sin(math.pi * (0.10 + 0.82 * t)) * (1 - 0.5 * t))
        c.poly("g1", blade)
        c.outline(acc_name, blade, lw)

    for r in ("g1", "g2"):
        cov = sum(c.buf[r].resize((480, 270)).point(lambda v: 1 if v > 127 else 0)
                  .getdata()) / (480 * 270) * 100
        print(f"    coverage {r}: {cov:5.1f}%")
    return c.finish()


def render(layers, table, path):
    im = Image.new("RGB", (W, H), table["g0"])
    for role, mask in layers:
        im.paste(Image.new("RGB", (W, H), table[role]), (0, 0), mask)
    im.save(path, quality=94, subsampling=0)
    return im


if __name__ == "__main__":
    layers = build()
    out = sys.argv[1] if len(sys.argv) > 1 else "."
    for name, table in (("dark", DARK), ("light", LIGHT)):
        p = f"{out}/solarized-{name}.jpg"
        im = render(layers, table, p)
        q = im.resize((320, 180)).quantize(colors=6)
        pal, tot = q.getpalette(), sum(c for c, _ in q.getcolors())
        print(f"  {p}")
        for cnt, i in sorted(q.getcolors(), reverse=True)[:5]:
            r, g, b = pal[i * 3:i * 3 + 3]
            print("      {:5.1f}%  #{:02x}{:02x}{:02x}".format(cnt / tot * 100, r, g, b))
