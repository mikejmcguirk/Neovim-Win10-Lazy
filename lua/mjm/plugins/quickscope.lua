vim.api.nvim_create_autocmd({ "BufReadPre", "BufNewFile" }, {
    group = vim.api.nvim_create_augroup("load-quickscope", { clear = true }),
    once = true,
    callback = function()
        vim.g.qs_highlight_on_keys = { "f", "F", "t", "T" }
        vim.g.qs_max_chars = 9999

        require("mjm.pack").post_load("quick-scope")
    end,
})
