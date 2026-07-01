return {
  "nvim-treesitter/nvim-treesitter",
  build = ":TSUpdate",
  lazy = false, -- v1.x does not support lazy-loading
  config = function()
    -- In v1.x setup() only accepts install_dir; highlight/ensure_installed are gone
    require("nvim-treesitter").setup()

    -- Install parsers asynchronously (no-op if already installed)
    require("nvim-treesitter").install({
      "bash",
      "go",
      "rust",
      "python",
      "markdown",
      "markdown_inline",
      "lua",
      "vim",
      "vimdoc",
      "c",
      "yaml",
      "dockerfile",
      "json",
      "toml",
    })

    -- Enable treesitter highlighting per filetype (Neovim built-in since 0.9)
    -- pcall so it silently skips filetypes without an installed parser
    vim.api.nvim_create_autocmd("FileType", {
      group = vim.api.nvim_create_augroup("UserTreesitterHL", {}),
      callback = function(ev)
        pcall(vim.treesitter.start, ev.buf)
      end,
    })

    -- Enable treesitter-based indentation for supported filetypes
    vim.api.nvim_create_autocmd("FileType", {
      group = vim.api.nvim_create_augroup("UserTreesitterIndent", {}),
      pattern = { "bash", "sh", "go", "rust", "python", "lua", "c", "yaml", "json", "toml" },
      callback = function()
        vim.bo.indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
      end,
    })
  end,
}
