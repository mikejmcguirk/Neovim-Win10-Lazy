-- Since Go uses tabs
vim.opt_local.listchars = { tab = "   ", extends = "»", precedes = "«", nbsp = "␣" }
vim.opt_local.expandtab = false
vim.opt_local.tabstop = 4
vim.opt_local.shiftwidth = 4
vim.opt_local.softtabstop = 0

vim.keymap.set("n", "<leader>-e", "oif err!= nil {<cr>}<esc>O//<esc>")
