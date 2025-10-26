-- PR: This should be in the official ftplugin file
vim.api.nvim_set_option_value("cc", "", { scope = "local" })
-- PR: This as well, because doing vim.cmd.close does not delete the buf
vim.keymap.set("n", "q", "<cmd>bd<cr>", { buffer = true })
