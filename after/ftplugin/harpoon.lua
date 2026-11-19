for _, map in ipairs({ "<C-w><C-c>", "<C-w>c", "<C-c>" }) do
    vim.keymap.set("n", map, function()
        require("harpoon").ui:close_menu()
    end, { buf = 0, nowait = true })
end
