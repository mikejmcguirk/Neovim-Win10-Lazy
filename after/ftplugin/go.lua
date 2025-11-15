local new_lcs = Mjm_Lcs:gsub("tab:(.)(.?)(.?),", "tab:   ,")
vim.api.nvim_set_option_value("lcs", new_lcs, { scope = "local" })
vim.api.nvim_set_option_value("et", false, { scope = "local" })
vim.api.nvim_set_option_value("ts", Mjm_Sw, { scope = "local" })
vim.api.nvim_set_option_value("sw", Mjm_Sw, { scope = "local" })
vim.api.nvim_set_option_value("sts", 0, { scope = "local" })

vim.keymap.set("n", "<leader>-e", "oif err!= nil {<cr>}<esc>O//<esc>")
