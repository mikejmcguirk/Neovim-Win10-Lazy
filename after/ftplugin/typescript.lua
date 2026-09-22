---@diagnostic disable-next-line: param-type-mismatch
require("mjm.lsp").start(vim.lsp.config["ts_ls"], { bufnr = 0 })
---@diagnostic disable-next-line: param-type-mismatch
require("mjm.lsp").start(vim.lsp.config["vtsls"], { bufnr = 0 })
