require("mjm.utils").set_buf_space_indent(0, 2)

vim.keymap.set("n", Mjm_Format_Lhs, function()
    require("mjm.utils").fallback_formatter(0)
end, { buf = 0 })

vim.api.nvim_create_autocmd("BufWritePre", {
    buf = 0,
    callback = function(ev)
        require("mjm.utils").fallback_formatter(ev.buf)
    end,
})
