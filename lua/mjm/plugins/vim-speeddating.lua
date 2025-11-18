return {
    "tpope/vim-speeddating",
    init = function()
        vim.api.nvim_set_var("speeddating_no_mappings", true)

        vim.keymap.set("n", "<C-a>", "<Plug>SpeedDatingUp", { silent = true })
        vim.keymap.set("n", "<C-x>", "<Plug>SpeedDatingDown", { silent = true })
        vim.keymap.set("n", "d<C-a>", "<Plug>SpeedDatingNowUTC", { silent = true })
        vim.keymap.set("n", "d<C-x>", "<Plug>SpeedDatingNowLocal", { silent = true })

        vim.keymap.set("x", "<C-a>", function()
            vim.api.nvim_feedkeys("\27", "nix", false)
            vim.fn["speeddating#incrementvisual"](vim.v.count1)
            vim.api.nvim_feedkeys("gv", "nix", false)
        end, { silent = true })

        vim.keymap.set("x", "<C-x>", function()
            vim.api.nvim_feedkeys("\27", "nix", false)
            vim.fn["speeddating#incrementvisual"](-vim.v.count1)
            vim.api.nvim_feedkeys("gv", "nix", false)
        end, { silent = true })
    end,
}
