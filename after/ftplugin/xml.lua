local width = 2
vim.bo.tabstop = width
vim.bo.softtabstop = width
vim.bo.shiftwidth = width

vim.api.nvim_create_autocmd("BufWritePre", {
    buffer = vim.api.nvim_get_current_buf(),
    callback = function(ev)
        require("mjm.utils").fallback_formatter(ev.buf)
    end,
})
