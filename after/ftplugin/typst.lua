---@diagnostic disable-next-line: param-type-mismatch
require("mjm.lsp").start(vim.lsp.config["tinymist"], { bufnr = 0 })

-- MAYBE: Additionally run my formatter since typstyle doesn't do stuff like get rid of trailing
-- blanks
