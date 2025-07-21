local ut = require("mjm.utils")
vim.api.nvim_create_autocmd("BufWritePre", {
    group = vim.api.nvim_create_augroup("tmux_save", { clear = true }),
    pattern = { "*.tmux", "tmux.conf" },
    callback = function(ev)
        print(ev.match)
        if vim.api.nvim_get_option_value("filetype", { buf = ev.buf }) == "tmux" then
            ut.fallback_formatter(ev.buf)
        end
    end,
})
