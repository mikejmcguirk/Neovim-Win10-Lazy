local ut = Mjm_Defer_Require("mjm.utils") ---@type MjmUtils

vim.api.nvim_set_option_value("cc", "", { scope = "local" })
vim.api.nvim_set_option_value("culopt", "screenline", { scope = "local" })
vim.api.nvim_set_option_value("siso", 12, { scope = "local" })
vim.api.nvim_set_option_value("spell", true, { scope = "local" })
vim.api.nvim_set_option_value("wrap", true, { scope = "local" })

vim.keymap.set("i", ",", ",<C-g>u", { silent = true, buffer = true })
vim.keymap.set("i", ".", ".<C-g>u", { silent = true, buffer = true })
vim.keymap.set("i", ":", ":<C-g>u", { silent = true, buffer = true })
vim.keymap.set("i", "-", "-<C-g>u", { silent = true, buffer = true })
vim.keymap.set("i", "?", "?<C-g>u", { silent = true, buffer = true })
vim.keymap.set("i", "!", "!<C-g>u", { silent = true, buffer = true })

vim.keymap.set("n", "gK", function()
    ut.check_word_under_cursor()
end)

vim.api.nvim_create_autocmd("BufWritePre", {
    buffer = 0,
    callback = function(ev)
        ut.fallback_formatter(ev.buf)
    end,
})
