-- dawnfox: base16 palette consumed by lua/plugins/colorscheme.lua
--
-- Upstream's own published scheme (EdenEast/nightfox.nvim extra/dawnfox/
-- base16.yaml), not the emitter's derivation from the 16 ANSI slots. Nightfox
-- publishes a base16 that is not a remapping of those slots -- its greens,
-- reds and magentas (#618774, #b4637a, #907aa9) appear nowhere in the terminal
-- palette -- so the derived version was a different theme wearing the name.
return {
  name = "dawnfox",
  colorscheme = "base16",
  background = "light",
  base16 = {
    base00 = "#faf4ed", base01 = "#ebe0df", base02 = "#ebdfe4", base03 = "#5f5695",
    base04 = "#a8a3b3", base05 = "#575279", base06 = "#625c87", base07 = "#e6ebf3",
    base08 = "#b4637a", base09 = "#d7827e", base0A = "#ea9d34", base0B = "#618774",
    base0C = "#56949f", base0D = "#286983", base0E = "#907aa9", base0F = "#d685af",
  },
}
