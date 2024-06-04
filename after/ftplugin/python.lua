local km = require("mjm.keymap_mod")

vim.keymap.set("i", "<backspace>", function()
    km.insert_backspace_fix({ allow_blank = true })
end, { silent = true, buffer = true })
