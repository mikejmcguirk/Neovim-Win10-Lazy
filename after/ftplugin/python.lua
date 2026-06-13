---@diagnostic disable-next-line: undefined-field
mjm.lsp.start(vim.lsp.config["pylsp"], { bufnr = 0 })
---@diagnostic disable-next-line: undefined-field
-- NOTE: This is the Rust implementation
mjm.lsp.start(vim.lsp.config["ruff"], { bufnr = 0 })

mjm.opt.flag_add("fo", { "r" }, { buf = 0 })
