-- Overwrite ftplugin
vim.api.nvim_set_option_value("fo", "r", { buf = 0, operation = "append" })

---@diagnostic disable-next-line: param-type-mismatch
require("mjm.lsp").start(vim.lsp.config["pylsp"], { bufnr = 0 })
---@diagnostic disable-next-line: param-type-mismatch
-- This is the Rust implementation
require("mjm.lsp").start(vim.lsp.config["ruff"], { bufnr = 0 })
---@diagnostic disable-next-line: param-type-mismatch
require("mjm.lsp").start(vim.lsp.config["ty"], { bufnr = 0 })
