---@type vim.lsp.Config
return {
    settings = {
        pylsp = {
            plugins = {
                pylsp_mypy = {
                    enabled = true,
                    -- Updates on textDocument/didChange. Otherwise, only updates on
                    -- textDocument/didSave
                    live_mode = true,
                    dmypy = false, -- Optional: Use dmypy daemon for faster checks in large projects
                    -- Apparently quite strict. Will keep off while I'm learning, and see what I
                    -- think with more experience
                    strict = false,
                },
                flake8 = { enabled = false }, -- Re-implemented in ruff
                pycodestyle = { enabled = false }, -- Re-implemented in ruff
            },
        },
    },
}
