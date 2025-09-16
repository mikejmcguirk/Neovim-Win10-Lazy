local width = 2
vim.bo.tabstop = width
vim.bo.softtabstop = width
vim.bo.shiftwidth = width

local ut = require("mjm.utils")
vim.api.nvim_create_autocmd("BufWritePre", {
    group = vim.api.nvim_create_augroup("xml_save", { clear = true }),
    pattern = "*.xml",
    callback = function(ev)
        ut.fallback_formatter(ev.buf)
    end,
})
