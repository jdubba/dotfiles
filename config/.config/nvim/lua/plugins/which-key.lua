return {
  "folke/which-key.nvim",
  event = "VeryLazy",
  opts = {
    delay = 500,
    icons = { mappings = true },
    spec = {
      -- Group labels for <leader> prefixes
      { "<leader>e", group = "Explorer" },
      { "<leader>f", group = "Find" },
      { "<leader>b", group = "Buffers" },
      { "<leader>v", group = "LSP" },
      { "<leader>h", group = "Git hunks" },
      -- Built-in 0.12 LSP binds (informational — not redefined here)
      { "gr",        group = "LSP (built-in)" },
    },
  },
}
