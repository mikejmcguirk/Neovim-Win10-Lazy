require("mjm.utils").set_buf_space_indent(0, 2)
mjm.lsp.start(vim.lsp.config["cssls"], { bufnr = 0 })
