return {
  "numToStr/Comment.nvim",
  event = { "BufReadPre", "BufNewFile" },
  config = function()
    require("Comment").setup()

    local api = require("Comment.api")

    -- Match the old <leader>/ toggle behavior
    vim.keymap.set("n", "<leader>/", api.toggle.linewise.current, { desc = "Toggle comment" })
    vim.keymap.set("v", "<leader>/", function()
      vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<esc>", true, false, true), "nx", false)
      api.toggle.linewise(vim.fn.visualmode())
    end, { desc = "Toggle comment (visual)" })
  end,
}
