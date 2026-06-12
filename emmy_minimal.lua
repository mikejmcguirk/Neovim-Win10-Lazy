vim.lsp.config('emmylua_ls', {
    cmd = { 'emmylua_ls' },
    filetypes = { 'lua' },
    root_markers = { { '.emmyrc.json', '.luarc.json' }, '.git' },
    --- TODO: missing @type lspconfig.settings.emmylua_ls
    settings = {
      emmylua = {
        -- runtime = {
        --   version = 'LuaJIT',
        -- },
        workspace = {
          library = {
            vim.env.VIMRUNTIME,
            -- For LSP Settings Type Annotations: https://github.com/neovim/nvim-lspconfig#lsp-settings-type-annotations
            vim.api.nvim_get_runtime_file('lua/lspconfig', false)[1],
          },
        },
        diagnostics = {
          -- globals = { 'vim' },
        },
      },
    },
  })
  vim.lsp.enable('emmylua_ls')
