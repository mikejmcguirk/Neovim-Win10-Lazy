local km = require("mjm.keymap_mod")

local harpoon_opts = vim.deepcopy(km.opts)
harpoon_opts.buffer = true
local harpoon_map = "<cmd>lua require('harpoon.ui').toggle_quick_menu()<CR>"
vim.keymap.set("n", "<C-c>", harpoon_map, harpoon_opts)

vim.opt_local.colorcolumn = ""
