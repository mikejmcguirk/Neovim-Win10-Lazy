local ut = require("mjm.utils")
vim.api.nvim_create_autocmd("BufWritePre", {
    group = vim.api.nvim_create_augroup("ghostty_save", { clear = true }),
    pattern = "config",
    callback = function(ev)
        if vim.api.nvim_get_option_value("filetype", { buf = ev.buf }) == "ghostty" then
            ut.fallback_formatter(ev.buf)
        end
    end,
})
