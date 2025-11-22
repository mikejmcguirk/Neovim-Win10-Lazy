---@type vim.lsp.Config
return {
    settings = {
        ["rust-analyzer"] = {
            checkOnSave = true,
            check = { command = "clippy", extraArgs = { "--no-deps" } },
            procMacro = { enable = true },
        },
    },
}
