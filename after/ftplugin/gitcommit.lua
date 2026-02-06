local api = vim.api

api.nvim_set_option_value("cc", "73,100", { scope = "local" })

local set = vim.keymap.set
set("i", ",", ",<C-g>u", { buffer = 0 })
set("i", ".", ".<C-g>u", { buffer = 0 })
set("i", ":", ":<C-g>u", { buffer = 0 })
set("i", "-", "-<C-g>u", { buffer = 0 })
set("i", "?", "?<C-g>u", { buffer = 0 })
set("i", "!", "!<C-g>u", { buffer = 0 })

set("n", "gK", function()
    require("mjm.utils").check_word_under_cursor()
end)

api.nvim_create_autocmd("BufWritePre", {
    buffer = 0,
    callback = function(ev)
        require("mjm.utils").fallback_formatter(ev.buf)
    end,
})
