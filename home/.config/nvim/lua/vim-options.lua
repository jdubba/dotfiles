-- Line numbers
vim.opt.number = true
vim.opt.relativenumber = true

-- Indentation
vim.opt.tabstop = 4
vim.opt.softtabstop = 4
vim.opt.shiftwidth = 4
vim.opt.expandtab = true
vim.opt.smartindent = true

-- Display
vim.opt.wrap = false
vim.opt.signcolumn = "yes"
vim.opt.colorcolumn = "120"
vim.opt.scrolloff = 8
vim.opt.termguicolors = true

-- Search
vim.opt.hlsearch = false
vim.opt.incsearch = true

-- Performance
vim.opt.updatetime = 50

-- Disable netrw (neo-tree replaces it)
vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1

-- Transparent background (override after colorscheme loads)
vim.api.nvim_create_autocmd("ColorScheme", {
  callback = function()
    vim.api.nvim_set_hl(0, "Normal", { bg = "none" })
    vim.api.nvim_set_hl(0, "NormalFloat", { bg = "none" })
    vim.api.nvim_set_hl(0, "NonText", { bg = "none" })
  end,
})
