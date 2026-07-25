#!/usr/bin/env python3
"""Point Brave's custom theme color at the active dotfiles theme.

Brave stores the color as a signed 32-bit ARGB SkColor under
``browser.theme.user_color2`` in a profile's ``Preferences`` JSON, and treats it
as a Material You *seed*: the rendered chrome is a tonal derivation of it, not
the literal value. ``extensions.theme.id`` selects the custom-color theme, the
same way the in-browser color picker does.

Neither key appears in ``protection.macs``, so writing them from outside the
browser does not trip Chromium's preference-tamper detection. Brave does keep
its preferences in memory and rewrite this file from that copy throughout a
session without ever re-reading it, so the caller must only invoke this while
the browser is closed.

usage: theme-brave.py <Preferences> <#rrggbb> <light|dark>
exit:  0 wrote a change, 2 already aligned (file untouched), 1 error
"""

import json
import os
import sys

CUSTOM_THEME_ID = "user_color_theme_id"
USAGE = "usage: theme-brave.py <Preferences> <#rrggbb> <light|dark>"


def sk_color(hex_rgb):
    """#RRGGBB -> the signed 32-bit opaque ARGB integer Chromium stores."""
    text = hex_rgb.lstrip("#")
    if len(text) != 6:
        raise ValueError(f"expected #RRGGBB, got {hex_rgb!r}")
    argb = 0xFF000000 | int(text, 16)
    return argb - 2**32 if argb >= 2**31 else argb


def subdict(parent, key):
    """parent[key], created when missing; None when it holds a non-object."""
    value = parent.setdefault(key, {})
    return value if isinstance(value, dict) else None


def main(argv):
    if len(argv) != 4:
        print(USAGE, file=sys.stderr)
        return 1
    path, accent, polarity = argv[1], argv[2], argv[3]

    try:
        color = sk_color(accent)
    except ValueError as exc:
        print(f"theme-brave: {exc}", file=sys.stderr)
        return 1

    try:
        with open(path, encoding="utf-8") as fh:
            prefs = json.load(fh)
    except (OSError, ValueError) as exc:
        print(f"theme-brave: cannot read {path}: {exc}", file=sys.stderr)
        return 1
    if not isinstance(prefs, dict):
        print(f"theme-brave: {path} is not a preferences object", file=sys.stderr)
        return 1

    browser = subdict(prefs, "browser")
    theme = subdict(browser, "theme") if browser is not None else None
    extensions = subdict(prefs, "extensions")
    ext_theme = subdict(extensions, "theme") if extensions is not None else None
    if theme is None or ext_theme is None:
        print(f"theme-brave: unexpected structure in {path}", file=sys.stderr)
        return 1

    want = {
        "user_color2": color,
        "color_scheme2": 1 if polarity == "light" else 2,
        # The Material variant is how the seed gets expanded, i.e. the user's
        # choice rather than part of the palette -- keep whatever is set.
        "color_variant2": theme.get("color_variant2", 1),
    }
    aligned = all(theme.get(k) == v for k, v in want.items())
    if aligned and ext_theme.get("id") == CUSTOM_THEME_ID:
        return 2

    theme.update(want)
    ext_theme["id"] = CUSTOM_THEME_ID

    # Same write discipline as Chromium's own: a temp file beside the original,
    # then an atomic rename over it, so an interrupted run cannot truncate the
    # profile's preferences.
    tmp = f"{path}.dotfiles-tmp"
    try:
        with open(tmp, "w", encoding="utf-8") as fh:
            json.dump(prefs, fh, separators=(",", ":"))
        os.replace(tmp, path)
    except OSError as exc:
        print(f"theme-brave: cannot write {path}: {exc}", file=sys.stderr)
        try:
            os.unlink(tmp)
        except OSError:
            pass
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
