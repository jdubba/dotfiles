return {
    "nvim-tree/nvim-tree.lua",
    version = "*",
    lazy = false,
    requires = {
        "nvim-tree/nvim-web-devicons",
    },
    config = function()
        require("nvim-tree").setup()

        --Tree view
        vim.keymap.set("n", "<leader>ee", ":NvimTreeToggle<cr>")
        vim.keymap.set("n", "<leader>ef", ":NvimTreeFindFileToggle<cr>")
        vim.keymap.set("n", "<leader>ec", ":NvimTreeCollapse<cr>")
        vim.keymap.set("n", "<leader>er", ":NvimTreeRefresh<cr>")

    end
}
