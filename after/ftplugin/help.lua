-- Make help open to the right
vim.cmd.wincmd("L")

vim.keymap.set("n", "q", ":bd<cr>", { buffer = 0 })
