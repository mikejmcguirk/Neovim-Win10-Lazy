print(vim.api.nvim_buf_get_name(0))
require("mjm.utils").set_buf_space_indent(0, 2)
---@diagnostic disable-next-line: undefined-field
mjm.lsp.start(vim.lsp.config["html"], { bufnr = 0 })
---@diagnostic disable-next-line: undefined-field
mjm.lsp.start(vim.lsp.config["ts_ls"], { bufnr = 0 })
---@diagnostic disable-next-line: undefined-field
mjm.lsp.start(vim.lsp.config["vtsls"], { bufnr = 0 })
