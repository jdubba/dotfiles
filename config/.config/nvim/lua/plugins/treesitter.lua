return {
  "nvim-treesitter/nvim-treesitter",
  build = "TSUpdate",
  config = function()
    local configs = require("nvim-treesitter.configs")
    configs.setup({
      ensure_installed = { "c", "c_sharp", "diff", "dockerfile", "git_config", "json", "json5", "lua", "rust", "sql", "toml", "typescript", "xml", "yaml"},
      sync_install = false,
      highlight = { enable = true },
      indent = { enable = true }
    })
  end
}
