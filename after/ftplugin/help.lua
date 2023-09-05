-- Make help open to the right
vim.cmd.wincmd("L")

-- Close buffer with q
vim.keymap.set("n", "q", ":bd<cr>", { buffer = 0 })
