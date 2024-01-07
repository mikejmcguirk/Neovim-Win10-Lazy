local harpoon_map = "<cmd>lua require('harpoon.ui').toggle_quick_menu()<CR>"
vim.keymap.set("n", "<C-c>", harpoon_map, { silent = true, buffer = true })

vim.opt_local.colorcolumn = ""
