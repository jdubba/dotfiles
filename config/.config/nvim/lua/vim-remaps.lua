vim.keymap.set("n", "<leader>ft", vim.cmd.Ex, {})

vim.keymap.set("v", "J", ":m '>+1<CR>gv=gv")
vim.keymap.set("v", "K", ":m '<-2<CR>gv=gv")

vim.keymap.set("n", "J", "mzJ`z")
vim.keymap.set("n", "<C-d>", "<C-d>zz")
vim.keymap.set("n", "<C-u>", "<C-u>zz")
vim.keymap.set("n", "n", "nzzzv")
vim.keymap.set("n", "N", "Nzzzv")

vim.keymap.set("x", "<leader>p", "\"_dP")

--Quick copy to system keyboard
vim.keymap.set("n", "<leader>y", "\"+y")
vim.keymap.set("v", "<leader>y", "\"+y")
vim.keymap.set("n", "<leader>Y", "\"+Y")

--Split Navigation
vim.keymap.set("n", "<C-j>", ":wincmd j<cr>")
vim.keymap.set("n", "<C-k>", ":wincmd k<cr>")
vim.keymap.set("n", "<C-h>", ":wincmd h<cr>")
vim.keymap.set("n", "<C-l>", ":wincmd l<cr>")

--Search
vim.keymap.set("n", "<leader>s", ":%s/\\<<C-r><C-w>\\>/<C-r><C-w>/gI<Left><Left>")

--Buffer Navigation
vim.keymap.set("n", "<leader>n", ":bn<cr>")
vim.keymap.set("n", "<leader>p", ":bp<cr>")
vim.keymap.set("n", "<leader>x", ":bd<cr>")

--Comment Toggle
vim.keymap.set({"n", "v"}, "<leader>/", ":CommentToggle<cr>")

--Indentation
vim.keymap.set({"n", "v"}, "<leader>>", ":><cr>")
vim.keymap.set({"n", "v"}, "<leader><", ":<<cr>")

--Word wrap Toggle
vim.keymap.set({"n", "v"}, "<leader>w", ":set wrap!<cr>", { noremap = true })
