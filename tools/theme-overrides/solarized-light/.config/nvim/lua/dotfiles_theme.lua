-- solarized-light: base16 palette consumed by lua/plugins/colorscheme.lua
--
-- The canonical base16 scheme (tinted-theming/schemes base16/solarized-light.yaml),
-- authored by Ethan Schoonover himself -- Solarized is one of the original
-- base16 schemes, so unlike most themes here there is a definitive answer and
-- no reason to derive one.
--
-- The emitter's remap of the sixteen ANSI slots collided in four places:
-- base02 and base03 were both #586e75, so the selection background and the
-- comment foreground were the same colour and selecting a comment erased it;
-- base09 duplicated base0A (no orange), base0F duplicated base08 (no magenta),
-- and base04 duplicated base06. The light variant was worse still -- it kept
-- base01 at #073642, a near-black surface step on a cream background.
--
-- Upstream's two variants are exact mirrors: base00-base07 swap in L*-symmetric
-- pairs and base08-base0F are identical, which is the same relationship the
-- wallpaper and every other seam in this pair are built on.
return {
  name = "solarized-light",
  colorscheme = "base16",
  background = "light",
  base16 = {
    base00 = "#fdf6e3", base01 = "#eee8d5", base02 = "#93a1a1", base03 = "#839496",
    base04 = "#657b83", base05 = "#586e75", base06 = "#073642", base07 = "#002b36",
    base08 = "#dc322f", base09 = "#cb4b16", base0A = "#b58900", base0B = "#859900",
    base0C = "#2aa198", base0D = "#268bd2", base0E = "#6c71c4", base0F = "#d33682",
  },
}
