local bp = require("mjm.backplacer")
vim.keymap.set("i", "<backspace>", function()
    bp.insert_backspace_fix({ allow_blank = true })
end, { silent = true, buffer = true })
