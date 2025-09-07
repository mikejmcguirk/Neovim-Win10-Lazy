---@type vim.lsp.Config
return {
    settings = {
        Lua = {
            codeLens = { enable = true },
            diagnostics = { disable = { "trailing-space" } },
            -- Use stylua
            format = { enable = false },
            hint = { enable = true },
            runtime = { version = "LuaJIT" },
        },
    },
}
