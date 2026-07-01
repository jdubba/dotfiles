return {
  "lewis6991/gitsigns.nvim",
  event = { "BufReadPre", "BufNewFile" },
  opts = {
    signs = {
      add          = { text = "│" },
      change       = { text = "│" },
      delete       = { text = "󰍵" },
      topdelete    = { text = "‾" },
      changedelete = { text = "~" },
      untracked    = { text = "┆" },
    },
    on_attach = function(bufnr)
      local gs = package.loaded.gitsigns
      local opts = function(desc) return { buffer = bufnr, desc = desc } end

      vim.keymap.set("n", "<leader>hs", gs.stage_hunk,                              opts("Stage hunk"))
      vim.keymap.set("n", "<leader>hr", gs.reset_hunk,                              opts("Reset hunk"))
      vim.keymap.set("n", "<leader>hS", gs.stage_buffer,                            opts("Stage buffer"))
      vim.keymap.set("n", "<leader>hu", gs.undo_stage_hunk,                         opts("Undo stage hunk"))
      vim.keymap.set("n", "<leader>hR", gs.reset_buffer,                            opts("Reset buffer"))
      vim.keymap.set("n", "<leader>hp", gs.preview_hunk,                            opts("Preview hunk"))
      vim.keymap.set("n", "<leader>hb", function() gs.blame_line({ full = true }) end, opts("Blame line"))
      vim.keymap.set("n", "<leader>hd", gs.diffthis,                                opts("Diff this"))

      -- Navigate hunks
      vim.keymap.set("n", "]h", gs.next_hunk, opts("Next hunk"))
      vim.keymap.set("n", "[h", gs.prev_hunk, opts("Prev hunk"))
    end,
  },
}
