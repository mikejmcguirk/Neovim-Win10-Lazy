vim.keymap.set("n", "q", "<cmd>bd<cr>")
vim.keymap.set("n", "<C-c>", function()
    require("harpoon").ui:close_menu()
end, { buffer = true })
