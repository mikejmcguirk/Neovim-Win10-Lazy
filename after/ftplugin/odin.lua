local api = vim.api

api.nvim_set_option_value("et", false, { buf = 0 })
api.nvim_set_option_value("ts", mjm.v.shiftwidth, { buf = 0 })
api.nvim_set_option_value("sts", 0, { buf = 0 })
api.nvim_set_option_value("sw", mjm.v.shiftwidth, { buf = 0 })

---@diagnostic disable-next-line: undefined-field
mjm.lsp.start(vim.lsp.config["ols"], { bufnr = 0 })
