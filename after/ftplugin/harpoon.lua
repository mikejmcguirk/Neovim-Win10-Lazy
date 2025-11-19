for _, map in ipairs({ "q", "<C-c>" }) do
    vim.keymap.set("n", map, function()
        require("harpoon").ui:close_menu()
    end, { buffer = true })
end
