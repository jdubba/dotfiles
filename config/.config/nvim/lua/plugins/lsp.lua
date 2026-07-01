return {
  -- LSP progress notifications
  {
    "j-hui/fidget.nvim",
    opts = {
      notification = { window = { winblend = 0 } },
    },
  },

  -- LSP server installer
  {
    "williamboman/mason.nvim",
    config = function()
      require("mason").setup({
        ui = { border = "rounded" },
      })
    end,
  },

  -- Ensures Mason installs the requested servers
  {
    "williamboman/mason-lspconfig.nvim",
    dependencies = { "williamboman/mason.nvim" },
    config = function()
      require("mason-lspconfig").setup({
        ensure_installed = {
          "bashls",
          "gopls",
          "rust_analyzer",
          "pyright",
          "lua_ls",
          "yamlls",
          "dockerls",
          "docker_compose_language_service",
        },
        automatic_installation = true,
      })
    end,
  },

  -- LSP client config — uses vim.lsp.config API (nvim 0.11+, lspconfig v2+)
  -- nvim-lspconfig is loaded as a dep so it registers default server definitions;
  -- we never call require('lspconfig').server.setup() directly.
  {
    "neovim/nvim-lspconfig",
    dependencies = {
      "williamboman/mason-lspconfig.nvim",
      "hrsh7th/cmp-nvim-lsp",
    },
    config = function()
      local capabilities = require("cmp_nvim_lsp").default_capabilities()

      -- Apply capabilities to every server
      vim.lsp.config("*", { capabilities = capabilities })

      -- Per-server overrides
      vim.lsp.config("gopls", {
        settings = {
          gopls = {
            analyses  = { unusedparams = true },
            staticcheck = true,
            gofumpt   = true,
          },
        },
      })

      vim.lsp.config("rust_analyzer", {
        settings = {
          ["rust-analyzer"] = {
            checkOnSave = { command = "clippy" },
          },
        },
      })

      vim.lsp.config("pyright", {
        settings = {
          python = {
            analysis = { typeCheckingMode = "basic" },
          },
        },
      })

      vim.lsp.config("lua_ls", {
        settings = {
          Lua = {
            diagnostics = {
              globals = { "vim", "it", "describe", "before_each", "after_each" },
            },
            workspace   = { checkThirdParty = false },
            telemetry   = { enable = false },
          },
        },
      })

      -- Start all servers (attaches when buffer filetype matches)
      vim.lsp.enable({
        "bashls",
        "gopls",
        "rust_analyzer",
        "pyright",
        "lua_ls",
        "yamlls",
        "dockerls",
        "docker_compose_language_service",
      })
    end,
  },

  -- Completion engine
  {
    "hrsh7th/nvim-cmp",
    dependencies = {
      "hrsh7th/cmp-nvim-lsp",
      "hrsh7th/cmp-buffer",
      "hrsh7th/cmp-path",
      "hrsh7th/cmp-cmdline",
      "L3MON4D3/LuaSnip",
      "saadparwaiz1/cmp_luasnip",
    },
    config = function()
      local cmp     = require("cmp")
      local luasnip = require("luasnip")

      cmp.setup({
        snippet = {
          expand = function(args)
            luasnip.lsp_expand(args.body)
          end,
        },
        window = {
          completion    = cmp.config.window.bordered(),
          documentation = cmp.config.window.bordered(),
        },
        mapping = cmp.mapping.preset.insert({
          ["<C-p>"]     = cmp.mapping.select_prev_item({ behavior = cmp.SelectBehavior.Select }),
          ["<C-n>"]     = cmp.mapping.select_next_item({ behavior = cmp.SelectBehavior.Select }),
          ["<C-y>"]     = cmp.mapping.confirm({ select = true }),
          ["<C-Space>"] = cmp.mapping.complete(),
          ["<C-b>"]     = cmp.mapping.scroll_docs(-4),
          ["<C-f>"]     = cmp.mapping.scroll_docs(4),
          ["<CR>"]      = cmp.mapping.confirm({ behavior = cmp.ConfirmBehavior.Replace, select = true }),
        }),
        sources = cmp.config.sources({
          { name = "nvim_lsp" },
          { name = "luasnip" },
        }, {
          { name = "buffer" },
          { name = "path" },
        }),
      })

      -- Buffer-word completion in search
      cmp.setup.cmdline({ "/", "?" }, {
        mapping = cmp.mapping.preset.cmdline(),
        sources = { { name = "buffer" } },
      })

      -- Path + command completion in cmdline
      cmp.setup.cmdline(":", {
        mapping = cmp.mapping.preset.cmdline(),
        sources = cmp.config.sources(
          { { name = "path" } },
          { { name = "cmdline" } }
        ),
      })
    end,
  },
}
