local exits = { "<leader>zz", "<C-w>c", "<C-w><C-c>" }
for _, exit in ipairs(exits) do
    vim.keymap.set("n", exit, "<cmd>q<cr>", { buf = 0 })
end
