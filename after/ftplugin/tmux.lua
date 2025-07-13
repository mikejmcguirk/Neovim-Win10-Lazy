local ut = require("mjm.utils")
vim.api.nvim_create_autocmd("BufWritePre", {
    group = vim.api.nvim_create_augroup("tmux_save", { clear = true }),
    pattern = "*", -- Since you can have .tmux and tmux.conf files
    callback = function(ev)
        if vim.api.nvim_get_option_value("filetype", { buf = ev.buf }) == "tmux" then
            ut.fallback_formatter(ev.buf)
        end
    end,
})
