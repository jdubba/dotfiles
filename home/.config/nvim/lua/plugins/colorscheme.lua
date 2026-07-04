return {
  "catppuccin/nvim",
  name = "catppuccin",
  priority = 1000, -- Load before all other plugins
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
    require("catppuccin").setup(opts)
    vim.cmd.colorscheme("catppuccin")
  end,
}
