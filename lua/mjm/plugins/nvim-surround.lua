vim.api.nvim_create_autocmd({ "BufReadPre", "BufNewFile" }, {
    group = vim.api.nvim_create_augroup("load-nvim-surround", { clear = true }),
    once = true,
    callback = function()
        require("nvim-surround").setup({ move_cursor = "sticky" })
        vim.api.nvim_del_augroup_by_name("load-nvim-surround")
    end,
})
