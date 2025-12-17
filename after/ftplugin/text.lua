local api = vim.api

api.nvim_set_option_value("cc", "", { scope = "local" })
api.nvim_set_option_value("culopt", "screenline", { scope = "local" })
api.nvim_set_option_value("siso", 12, { scope = "local" })
api.nvim_set_option_value("spell", true, { scope = "local" })
api.nvim_set_option_value("wrap", true, { scope = "local" })

vim.keymap.set("i", ",", ",<C-g>u", { buffer = 0 })
vim.keymap.set("i", ".", ".<C-g>u", { buffer = 0 })
vim.keymap.set("i", ":", ":<C-g>u", { buffer = 0 })
vim.keymap.set("i", "-", "-<C-g>u", { buffer = 0 })
vim.keymap.set("i", "?", "?<C-g>u", { buffer = 0 })
vim.keymap.set("i", "!", "!<C-g>u", { buffer = 0 })

vim.keymap.set("n", "gK", function()
    require("mjm.utils").check_word_under_cursor()
end)

api.nvim_create_autocmd("BufWritePre", {
    buffer = 0,
    callback = function(ev)
        require("mjm.utils").fallback_formatter(ev.buf)
    end,
})
