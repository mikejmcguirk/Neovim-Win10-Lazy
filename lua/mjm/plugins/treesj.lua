local function setup_treesj()
    require("treesj").setup({
        use_default_keymaps = false,
        max_join_length = 99,
        notify = false,
    })

    Map("n", "gs", require("treesj").toggle)
    Map("n", "gS", function() require("treesj").split({ split = { recursive = true } }) end)
end

vim.api.nvim_create_autocmd({ "BufReadPre", "BufNewFile" }, {
    group = vim.api.nvim_create_augroup("setup-treesj", { clear = true }),
    once = true,
    callback = function()
        setup_treesj()
        vim.api.nvim_del_augroup_by_name("setup-treesj")
    end,
})
