-- TODO: Some version of this from mfussenegger:
-- setlocal keywordprg=:sp\ term://sdcv\ -n\ -c
-- setlocal spell
-- setlocal complete+=kspell

vim.opt_local.colorcolumn = ""
vim.opt_local.wrap = true
vim.opt_local.sidescrolloff = 12
vim.opt_local.spell = true

vim.keymap.set("i", ",", ",<C-g>u", { silent = true, buffer = true })
vim.keymap.set("i", ".", ".<C-g>u", { silent = true, buffer = true })
vim.keymap.set("i", ":", ":<C-g>u", { silent = true, buffer = true })
vim.keymap.set("i", "-", "-<C-g>u", { silent = true, buffer = true })
vim.keymap.set("i", "?", "?<C-g>u", { silent = true, buffer = true })
vim.keymap.set("i", "!", "!<C-g>u", { silent = true, buffer = true })

local ut = require("mjm.utils")
vim.api.nvim_create_autocmd("BufWritePre", {
    group = vim.api.nvim_create_augroup("text_save", { clear = true }),
    pattern = "*.txt",
    callback = function(ev)
        ut.fallback_formatter(ev.buf)
    end,
})
