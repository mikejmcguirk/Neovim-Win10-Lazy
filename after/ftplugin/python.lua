-- Overwrite ftplugin
vim.api.nvim_set_option_value("fo", "r", { buf = 0, operation = "append" })

mjm.lsp.start(vim.lsp.config["pylsp"], { bufnr = 0 })
-- This is the Rust implementation
mjm.lsp.start(vim.lsp.config["ruff"], { bufnr = 0 })
