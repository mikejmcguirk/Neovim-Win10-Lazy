vim.api.nvim_create_autocmd({ "BufReadPre", "BufNewFile" }, {
    group = vim.api.nvim_create_augroup("load-nvim-surround", { clear = true }),
    once = true,
    callback = function()
        require("mjm.pack").post_load("nvim-surround")
        require("nvim-surround").setup({})
    end,
})
