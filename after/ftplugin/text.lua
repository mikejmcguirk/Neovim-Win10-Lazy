local api = vim.api
local set = vim.keymap.set

local local_scope = { scope = "local" }
api.nvim_set_option_value("colorcolumn", "", local_scope)
api.nvim_set_option_value("cursorlineopt", "screenline,number", local_scope)
api.nvim_set_option_value("sidescrolloff", 12, local_scope)
api.nvim_set_option_value("spell", true, local_scope)
api.nvim_set_option_value("wrap", true, local_scope)

local buf_0 = { buf = 0 }
set("i", ",", ",<C-g>u", buf_0)
set("i", ".", ".<C-g>u", buf_0)
set("i", ":", ":<C-g>u", buf_0)
set("i", "-", "-<C-g>u", buf_0)
set("i", "?", "?<C-g>u", buf_0)
set("i", "!", "!<C-g>u", buf_0)

set("n", "gK", function()
    require("mjm.utils").check_word_under_cursor()
end, buf_0)

set("n", mjm.v.fmt_lhs, function()
    require("mjm.utils").fallback_formatter(0)
end, buf_0)

api.nvim_create_autocmd("BufWritePre", {
    buffer = 0,
    callback = function(ev)
        require("mjm.utils").fallback_formatter(ev.buf)
    end,
})
