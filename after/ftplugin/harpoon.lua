-- TODO: Should be setup somehow so that you can do rnu jumps. Right now numbers just select the
-- item. If I wanted to that, I would just use my normal mode maps
vim.keymap.set("n", "<C-c>", function()
    require("harpoon").ui:close_menu()
end, { buffer = true })
