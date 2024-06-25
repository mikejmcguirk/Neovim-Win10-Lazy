vim.api.nvim_win_set_height(0, 9)

vim.keymap.set("n", "<C-c>", function()
    require("harpoon").ui:close_menu()
end, { buffer = true })
