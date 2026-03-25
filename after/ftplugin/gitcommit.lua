local api = vim.api
local set = vim.keymap.set

api.nvim_set_option_value("cc", "73,100", { scope = "local" })

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
    require("mjm.utils").fallback_formatter(0, { retab = false })
end, buf_0)

api.nvim_create_autocmd("BufWritePre", {
    buffer = 0,
    callback = function(ev)
        require("mjm.utils").fallback_formatter(ev.buf, { retab = false })
    end,
})

-- TODO: Why do I have this in addition to the BufWritePre autocmd?
set("n", "ZZ", function()
    require("mjm.utils").fallback_formatter(0, { retab = false })
    api.nvim_cmd({ cmd = "norm", args = { "w" }, mods = { lockmarks = true, silent = true } }, {})
end, { buf = 0 })
