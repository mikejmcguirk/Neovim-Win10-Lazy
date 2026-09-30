require("mjm.utils").set_buf_space_indent(0, 2)
---@diagnostic disable-next-line: param-type-mismatch
require("mjm.lsp").start(vim.lsp.config["html"], { bufnr = 0 })
---@diagnostic disable-next-line: param-type-mismatch
require("mjm.lsp").start(vim.lsp.config["superhtml"], { bufnr = 0 })
---@diagnostic disable-next-line: param-type-mismatch
require("mjm.lsp").start(vim.lsp.config["biome"], { bufnr = 0 })
