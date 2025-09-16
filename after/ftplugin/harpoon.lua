-- LOW: Add Ctrl-v to open into a vsplit

Map("n", "q", "<cmd>bd<cr>", { buffer = true })
Map("n", "<C-c>", function()
    require("harpoon").ui:close_menu()
end, { buffer = true })
