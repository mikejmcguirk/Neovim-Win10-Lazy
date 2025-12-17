vim.api.nvim_set_option_value("cc", "", { scope = "local" })
vim.api.nvim_set_option_value("list", false, { scope = "local" })
vim.keymap.set("n", "q", "<cmd>bwipe<cr>", { buffer = 0 })
