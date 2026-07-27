-- duskfox: base16 palette consumed by lua/plugins/colorscheme.lua
--
-- Nightfox's own published scheme (EdenEast/nightfox.nvim
-- extra/duskfox/base16.yaml), not the emitter's remapping of the 16 ANSI
-- slots. The remapping gave base02 and base03 the same #47407d -- selection
-- background and comment foreground identical, so selecting a comment made it
-- vanish -- and spent base04..base06 on copies of `text`. Upstream uses those
-- slots for real surface steps that have no ANSI slot of their own.
return {
  name = "duskfox",
  colorscheme = "base16",
  background = "dark",
  base16 = {
    base00 = "#232136", base01 = "#2d2a45", base02 = "#373354", base03 = "#47407d",
    base04 = "#6e6a86", base05 = "#e0def4", base06 = "#cdcbe0", base07 = "#e2e0f7",
    base08 = "#eb6f92", base09 = "#ea9a97", base0A = "#f6c177", base0B = "#a3be8c",
    base0C = "#9ccfd8", base0D = "#569fba", base0E = "#c4a7e7", base0F = "#eb98c3",
  },
}
