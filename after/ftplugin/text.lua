local ut = Mjm_Defer_Require("mjm.utils") ---@type MjmUtils

vim.opt_local.colorcolumn = ""
vim.opt_local.cursorlineopt = "screenline"
vim.opt_local.wrap = true
vim.opt_local.sidescrolloff = 12
vim.opt_local.spell = true

vim.keymap.set("i", ",", ",<C-g>u", { silent = true, buffer = true })
vim.keymap.set("i", ".", ".<C-g>u", { silent = true, buffer = true })
vim.keymap.set("i", ":", ":<C-g>u", { silent = true, buffer = true })
vim.keymap.set("i", "-", "-<C-g>u", { silent = true, buffer = true })
vim.keymap.set("i", "?", "?<C-g>u", { silent = true, buffer = true })
vim.keymap.set("i", "!", "!<C-g>u", { silent = true, buffer = true })

-- LOW: Broader idea here:
-- This might not work in markdown files because of those LSPs. Semi-obvious solution, use gK
-- But then consider - Why does there only have to be only one floating window option per buf?
-- Why is gT (Inspect) a cmd popup? Why can't it be a float?
vim.keymap.set("n", "K", function()
    ut.check_word_under_cursor()
end)

vim.api.nvim_create_autocmd("BufWritePre", {
    buffer = vim.api.nvim_get_current_buf(),
    callback = function(ev)
        ut.fallback_formatter(ev.buf)
    end,
})
