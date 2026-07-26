-- rose-pine: base16 palette consumed by lua/plugins/colorscheme.lua
--
-- The official scheme (tinted-theming/schemes base16/rose-pine.yaml, by
-- Emilia Dunfelt), not the emitter's remapping of the 16 ANSI slots. The
-- remapping gave base02 and base03 the same #6e6a86 -- selection background
-- and comment foreground identical, so selecting a comment made it vanish --
-- and spent base04..base07 on four copies of `text`. The official scheme uses
-- those slots for the surface and highlight roles rose-pine actually defines,
-- none of which appear in its ANSI mapping.
return {
  name = "rose-pine",
  colorscheme = "base16",
  background = "dark",
  base16 = {
    base00 = "#191724", base01 = "#1f1d2e", base02 = "#26233a", base03 = "#6e6a86",
    base04 = "#908caa", base05 = "#e0def4", base06 = "#e0def4", base07 = "#524f67",
    base08 = "#eb6f92", base09 = "#f6c177", base0A = "#ebbcba", base0B = "#31748f",
    base0C = "#9ccfd8", base0D = "#c4a7e7", base0E = "#f6c177", base0F = "#524f67",
  },
}
