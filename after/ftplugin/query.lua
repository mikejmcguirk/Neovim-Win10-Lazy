local width = 2
vim.bo.tabstop = width
vim.bo.softtabstop = width
vim.bo.shiftwidth = width

vim.cmd("wincmd =")
vim.opt_local.colorcolumn = ""
Map("n", "q", "<cmd>bd<cr>", { buffer = true })
