local harpoon = require("harpoon")

vim.keymap.set("n", "<C-c>", function()
    harpoon.ui:close_menu()
end, { buffer = true })
vim.keymap.set("n", "a", "<nop>", { buffer = true })
