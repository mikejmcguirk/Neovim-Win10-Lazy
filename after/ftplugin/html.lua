require("mjm.utils").set_buf_space_indent(0, 2)
mjm.lsp.start(vim.lsp.config["html"], { bufnr = 0 })
mjm.lsp.start(vim.lsp.config["vtsls"], { bufnr = 0 })
mjm.lsp.start(vim.lsp.config["ts_ls"], { bufnr = 0 })
