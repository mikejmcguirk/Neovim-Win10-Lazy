-- PR: This should be in the official ftplugin file
SetOpt("cc", "", { scope = "local" })
-- PR: This as well, because doing vim.cmd.close does not delete the buf
Map("n", "q", "<cmd>bd<cr>", { buffer = true })
