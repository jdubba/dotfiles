-- Colorscheme plugins.
--
-- Both candidate colorschemes are installed and configured; the one named by
-- the active dotfiles theme (lua/dotfiles_theme.lua, provided by the linked
-- theme layer) is the one actually applied via :colorscheme. Switching themes
-- with `dotfiles theme set <name>` relinks that data file, so the next nvim
-- launch picks up the new colorscheme.

local ok, theme = pcall(require, "dotfiles_theme")
if not ok then
  theme = { name = "catppuccin-mocha", colorscheme = "catppuccin", background = "dark" }
end

return {
  -- Catppuccin
  {
    "catppuccin/nvim",
    name = "catppuccin",
    priority = 1000, -- Load before all other plugins
    lazy = false,
    opts = {
      flavour = "mocha",
      transparent_background = true,
      integrations = {
        treesitter = true,
        telescope = { enabled = true },
        neotree = true,
        bufferline = true,
        gitsigns = true,
        which_key = true,
        mason = true,
        cmp = true,
        native_lsp = {
          enabled = true,
          virtual_text = {
            errors = { "italic" },
            hints = { "italic" },
            warnings = { "italic" },
            information = { "italic" },
          },
          underlines = {
            errors = { "underline" },
            hints = { "underline" },
            warnings = { "underline" },
            information = { "underline" },
          },
        },
      },
    },
    config = function(_, opts)
      -- Catppuccin family (mocha/macchiato/frappe/latte) drives the flavour
      -- from the active dotfiles theme.
      if theme.colorscheme == "catppuccin" then
        opts.flavour = theme.flavour or "mocha"
      end
      require("catppuccin").setup(opts)
      if theme.colorscheme == "catppuccin" then
        vim.o.background = theme.background or "dark"
        vim.cmd.colorscheme("catppuccin")
      end
    end,
  },

  -- Gruvbox
  {
    "ellisonleao/gruvbox.nvim",
    priority = 1000,
    lazy = false,
    opts = {
      transparent_mode = true,
    },
    config = function(_, opts)
      require("gruvbox").setup(opts)
      if theme.colorscheme == "gruvbox" then
        vim.o.background = theme.background or "dark"
        vim.cmd.colorscheme("gruvbox")
      end
    end,
  },

  -- base16: used by wallpaper-derived "auto" themes, which supply a generated
  -- 16-colour palette in dotfiles_theme.base16 (see `dotfiles theme auto`).
  {
    "RRethy/base16-nvim",
    priority = 1000,
    lazy = false,
    config = function()
      if theme.colorscheme == "base16" and theme.base16 then
        vim.o.background = theme.background or "dark"
        require("base16-colorscheme").setup(theme.base16)
      end
    end,
  },
}
