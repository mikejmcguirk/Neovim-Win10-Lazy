local api = vim.api

api.nvim_set_option_value("lcs", Mjm_Lcs_Tab, { scope = "local" })

api.nvim_set_option_value("et", false, { buf = 0 })
api.nvim_set_option_value("ts", Mjm_Sw, { buf = 0 })
api.nvim_set_option_value("sts", 0, { buf = 0 })
api.nvim_set_option_value("sw", Mjm_Sw, { buf = 0 })

vim.keymap.set("n", "<leader>-e", "oif err!= nil {<cr>}<esc>O//<esc>", { buffer = 0 })

mjm.lsp.start(vim.lsp.config["golangci_lint_ls"], { bufnr = 0 })
mjm.lsp.start(vim.lsp.config["gopls"], { bufnr = 0 })
