local new_lcs = Mjm_Lcs:gsub("tab:(.)(.?)(.?),", "tab:   ,")
vim.api.nvim_set_option_value("lcs", new_lcs, { scope = "local" })

vim.api.nvim_set_option_value("et", false, { scope = "local" })
vim.api.nvim_set_option_value("ts", Mjm_Sw, { scope = "local" })
vim.api.nvim_set_option_value("sw", Mjm_Sw, { scope = "local" })
vim.api.nvim_set_option_value("sts", 0, { scope = "local" })

vim.keymap.set("n", "<leader>-e", "oif err!= nil {<cr>}<esc>O//<esc>")

mjm.lsp.start(vim.lsp.config["golangci_lint_ls"], { bufnr = 0 })
mjm.lsp.start(vim.lsp.config["gopls"], { bufnr = 0 })
