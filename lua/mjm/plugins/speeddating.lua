vim.api.nvim_create_autocmd({ "BufReadPre", "BufNewFile" }, {
    group = vim.api.nvim_create_augroup("load-speeddating", { clear = true }),
    once = true,
    callback = function()
        require("mjm.pack").post_load("vim-speeddating")
    end,
})
