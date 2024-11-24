-- Not in Python by default. I'm guessing the runtime ftplugin file removes it
vim.opt.formatoptions:append("r")

local bp = require("mjm.backplacer")
vim.keymap.set("i", "<backspace>", function()
    bp.insert_backspace_fix({ allow_blank = true })
end, { silent = true, buffer = true })
