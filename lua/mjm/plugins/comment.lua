vim.api.nvim_create_autocmd({ "BufReadPre", "BufNewFile" }, {
    group = vim.api.nvim_create_augroup("load-comment", { clear = true }),
    once = true,
    callback = function()
        require("mjm.pack").post_load("Comment.nvim")

        --- @diagnostic disable: missing-fields
        require("Comment").setup({
            ignore = "^$",
        })
    end,
})
