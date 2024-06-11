vim.opt_local.wrap = true
vim.opt_local.spell = true
vim.opt_local.colorcolumn = ""
vim.opt_local.sidescrolloff = 12

local km = require("mjm.keymap_mod")
vim.keymap.set("i", "<backspace>", function()
    km.insert_backspace_fix({ allow_blank = true })
end, { silent = true, buffer = true })
