vim.keymap.set("n",
    "<C-c>",
    "<cmd>lua require('harpoon.ui').toggle_quick_menu()<CR>",
    { noremap = true, silent = true }
)
