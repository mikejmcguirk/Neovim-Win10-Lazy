vim.api.nvim_create_autocmd({ "BufReadPre", "BufNewFile" }, {
    group = vim.api.nvim_create_augroup("load-comment", { clear = true }),
    once = true,
    callback = function()
        require("Comment").setup()
    end,
})
