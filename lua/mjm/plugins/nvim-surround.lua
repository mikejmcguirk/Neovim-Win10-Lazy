vim.api.nvim_create_autocmd({ "BufReadPre", "BufNewFile" }, {
    group = vim.api.nvim_create_augroup("load-textmanip-normal", { clear = true }),
    once = true,
    callback = function()
        require("nvim-surround").setup({})
    end,
})
