-- Overwrite autopairs plugins since " is a comment
vim.keymap.set("i", '"', '"', { buffer = 0 })
