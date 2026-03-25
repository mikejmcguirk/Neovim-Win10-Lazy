vim.keymap.set("n", mjm.v.fmt_lhs, function()
    require("mjm.utils").fallback_formatter(0)
end, { buf = 0 })

vim.api.nvim_create_autocmd("BufWritePre", {
    buf = 0,
    callback = function(ev)
        require("mjm.utils").fallback_formatter(ev.buf)
    end,
})
