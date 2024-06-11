vim.keymap.set("n", "<C-c>", function()
    require("harpoon").ui:close_menu()
end, { buffer = true })
vim.keymap.set("n", "a", "<nop>", { buffer = true })
