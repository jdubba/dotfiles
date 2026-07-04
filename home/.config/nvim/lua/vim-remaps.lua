local map = vim.keymap.set

-- Visual line movement
map("v", "J", ":m '>+1<CR>gv=gv", { desc = "Move selection down" })
map("v", "K", ":m '<-2<CR>gv=gv", { desc = "Move selection up" })

-- Better join (keep cursor position)
map("n", "J", "mzJ`z", { desc = "Join line, keep cursor" })

-- Centered scroll
map("n", "<C-d>", "<C-d>zz", { desc = "Half page down, centered" })
map("n", "<C-u>", "<C-u>zz", { desc = "Half page up, centered" })

-- Centered search results
map("n", "n", "nzzzv", { desc = "Next result, centered" })
map("n", "N", "Nzzzv", { desc = "Prev result, centered" })

-- Paste without clobbering the yank register
map({ "v", "x" }, "<leader>p", [["_dP]], { desc = "Paste without overwriting register" })

-- Yank to system clipboard
map("n", "<leader>y", [["+y]], { desc = "Yank to clipboard" })
map("v", "<leader>y", [["+y]], { desc = "Yank selection to clipboard" })
map("n", "<leader>Y", [["+Y]], { desc = "Yank to end of line to clipboard" })

-- Split navigation
map("n", "<C-j>", "<C-w>j", { desc = "Move to split below" })
map("n", "<C-k>", "<C-w>k", { desc = "Move to split above" })
map("n", "<C-h>", "<C-w>h", { desc = "Move to split left" })
map("n", "<C-l>", "<C-w>l", { desc = "Move to split right" })

-- Search and replace word under cursor
map("n", "<leader>s", [[:%s/\<<C-r><C-w>\>/<C-r><C-w>/gI<Left><Left><Left>]], { desc = "Search & replace word under cursor" })

-- Buffer navigation
map("n", "<leader>n", "<cmd>bnext<cr>", { desc = "Next buffer" })
map("n", "<leader>p", "<cmd>bprev<cr>", { desc = "Previous buffer" })
map("n", "<leader>x", "<cmd>bdelete<cr>", { desc = "Close buffer" })

-- Indentation
map({ "n", "v" }, "<leader>>", ">>", { desc = "Indent right" })
map({ "n", "v" }, "<leader><", "<<", { desc = "Indent left" })

-- Word wrap toggle
map({ "n", "v" }, "<leader>w", function()
  vim.opt.wrap = not vim.opt.wrap:get()
end, { desc = "Toggle word wrap" })
