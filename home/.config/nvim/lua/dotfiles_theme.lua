-- Active dotfiles theme descriptor (consumed by the nvim config).
--
-- This is the fallback shipped in the home layer. The active dotfiles theme
-- layer overrides this file at themes/<name>/.config/nvim/lua/dotfiles_theme.lua
-- so `require("dotfiles_theme")` always reflects the currently linked theme.
--
--   name        human-readable theme id (matches themes/<name>/)
--   colorscheme argument passed to :colorscheme (must be a bundled plugin)
--   background  value for vim.o.background ("dark" | "light")
return {
  name = "catppuccin-mocha",
  colorscheme = "catppuccin",
  background = "dark",
}
