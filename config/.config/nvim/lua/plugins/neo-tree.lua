return {
  "nvim-neo-tree/neo-tree.nvim",
  branch = "v3.x",
  dependencies = {
    "nvim-lua/plenary.nvim",
    "nvim-tree/nvim-web-devicons",
    "MunifTanjim/nui.nvim",
  },
  config = function()
    require("neo-tree").setup({
      close_if_last_window = true,
      popup_border_style = "rounded",
      window = {
        width = 30,
        mappings = {
          -- Unmap space so <leader> works globally while tree is focused
          ["<space>"] = "none",
        },
      },
      filesystem = {
        filtered_items = {
          visible = true,
          hide_dotfiles = false,
          hide_gitignored = false,
          never_show = {},
        },
        follow_current_file = { enabled = true },
        hijack_netrw_behavior = "open_default",
        use_libuv_file_watcher = true,
      },
      default_component_configs = {
        git_status = {
          symbols = {
            added     = " ",
            modified  = " ",
            deleted   = "✖ ",
            renamed   = "󰁕 ",
            untracked = " ",
            ignored   = " ",
            unstaged  = "󰄱 ",
            staged    = " ",
            conflict  = " ",
          },
        },
      },
    })

    -- Auto-open on startup when no file argument is given
    vim.api.nvim_create_autocmd("VimEnter", {
      callback = function()
        if vim.fn.argc() == 0 then
          require("neo-tree.command").execute({
            action = "show",
            source = "filesystem",
            position = "left",
          })
        end
      end,
    })

    -- Keybindings
    vim.keymap.set("n", "<leader>ee", "<cmd>Neotree toggle<cr>", { desc = "Toggle explorer" })
    vim.keymap.set("n", "<leader>ef", "<cmd>Neotree reveal<cr>", { desc = "Reveal current file" })
    vim.keymap.set("n", "<leader>ec", "<cmd>Neotree close<cr>", { desc = "Close explorer" })
    vim.keymap.set("n", "<leader>er", "<cmd>Neotree refresh<cr>", { desc = "Refresh explorer" })
  end,
}
