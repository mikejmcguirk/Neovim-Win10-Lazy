vim.api.nvim_set_option_value("cc", "", { scope = "local" })
vim.api.nvim_set_option_value("nu", true, { scope = "local" })
vim.api.nvim_set_option_value("rnu", true, { scope = "local" })
vim.keymap.set("n", "q", "<cmd>bwipe<cr>", { buffer = true })
