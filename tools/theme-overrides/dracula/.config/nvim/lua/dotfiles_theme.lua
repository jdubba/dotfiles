-- dracula: base16 palette consumed by lua/plugins/colorscheme.lua
--
-- Dracula's own published base16 scheme (tinted-theming/schemes
-- base16/dracula.yaml, derived from the upstream spec), not the emitter's
-- remapping of the 16 ANSI slots. The remapping gave base02 and base03 the
-- same #6272a4 -- selection background and comment foreground identical, so
-- selecting a comment made it vanish. It also could not reach #44475A
-- (Dracula's Selection) or #FFB86C (its Orange), neither of which is in the
-- ANSI-16; both are colours the btop override already reaches for by hand.
return {
  name = "dracula",
  colorscheme = "base16",
  background = "dark",
  base16 = {
    base00 = "#282a36", base01 = "#21222c", base02 = "#44475a", base03 = "#6272a4",
    base04 = "#9ea8c7", base05 = "#f8f8f2", base06 = "#f8f8f2", base07 = "#ffffff",
    base08 = "#ff5555", base09 = "#ffb86c", base0A = "#f1fa8c", base0B = "#50fa7b",
    base0C = "#8be9fd", base0D = "#bd93f9", base0E = "#ff79c6", base0F = "#993333",
  },
}
