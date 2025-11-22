---@type vim.lsp.Config
return {
    settings = {
        Lua = {
            diagnostics = { disable = { "trailing-space" } },
            -- Use stylua
            format = { enable = false },
            hint = { arrayIndex = "Enable" },
            runtime = { version = "LuaJIT" },
        },
    },
}
