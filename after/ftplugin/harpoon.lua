vim.opt_local.colorcolumn = ""

local harpoon_opts = vim.deepcopy(Opts)
harpoon_opts.buffer = true

vim.keymap.set(
    "n",
    "<C-c>",
    "<cmd>lua require('harpoon.ui').toggle_quick_menu()<CR>",
    harpoon_opts
)
