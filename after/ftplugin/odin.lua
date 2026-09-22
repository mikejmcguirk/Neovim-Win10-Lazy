local api = vim.api

api.nvim_set_option_value("et", false, { buf = 0 })
api.nvim_set_option_value("ts", Mjm_Shiftwidth, { buf = 0 })
api.nvim_set_option_value("sts", 0, { buf = 0 })
api.nvim_set_option_value("sw", Mjm_Shiftwidth, { buf = 0 })

api.nvim_set_option_value("fo", "r", { buf = 0, operation = "append" })

---@diagnostic disable-next-line: param-type-mismatch
require("mjm.lsp").start(vim.lsp.config["ols"], { bufnr = 0 })
