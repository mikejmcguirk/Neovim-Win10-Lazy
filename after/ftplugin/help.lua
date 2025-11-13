vim.api.nvim_set_option_value("cc", "", { scope = "local" })
vim.api.nvim_set_option_value("nu", "", { scope = "local" })
vim.keymap.set("n", "q", "<cmd>bd<cr>", { buffer = true })
