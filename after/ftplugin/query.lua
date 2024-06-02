vim.keymap.set("n", "q", "<cmd>bd<cr>", { buffer = 0 })
vim.api.nvim_exec2("wincmd =", {})
