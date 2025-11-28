mjm.lsp.start(vim.lsp.config["pylsp"], { bufnr = 0 })
-- NOTE: This is the Rust implementation
mjm.lsp.start(vim.lsp.config["ruff"], { bufnr = 0 })

mjm.opt.str_append("fo", "r", { buf = 0 })
