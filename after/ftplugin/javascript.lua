---@diagnostic disable-next-line: param-type-mismatch
require("mjm.lsp").start(vim.lsp.config["tsc"], { bufnr = 0 })
---@diagnostic disable-next-line: param-type-mismatch
require("mjm.lsp").start(vim.lsp.config["biome"], { bufnr = 0 })
