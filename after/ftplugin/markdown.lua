local width = 2
vim.bo.tabstop = width
vim.bo.softtabstop = width
vim.bo.shiftwidth = width

vim.opt_local.wrap = true
vim.opt_local.spell = true
vim.opt_local.colorcolumn = ""
vim.opt_local.sidescrolloff = 12

vim.keymap.set("i", ",", ",<C-g>u", { silent = true, buffer = true })
vim.keymap.set("i", ".", ".<C-g>u", { silent = true, buffer = true })
vim.keymap.set("i", ":", ":<C-g>u", { silent = true, buffer = true })
vim.keymap.set("i", "-", "-<C-g>u", { silent = true, buffer = true })
vim.keymap.set("i", "?", "?<C-g>u", { silent = true, buffer = true })
vim.keymap.set("i", "!", "!<C-g>u", { silent = true, buffer = true })

local ut = require("mjm.utils")
vim.api.nvim_create_autocmd("BufWritePre", {
    group = vim.api.nvim_create_augroup("md_save", { clear = true }),
    pattern = "*.md",
    callback = function(ev)
        ut.fallback_formatter(ev.buf)
    end,
})
