local api = vim.api
local set = vim.keymap.set
local set_opt = api.nvim_set_option_value

local local_scope = { scope = "local" }
set_opt("colorcolumn", "", local_scope)
set_opt("cursorlineopt", "screenline,number", local_scope)
set_opt("sidescrolloff", 12, local_scope)
set_opt("spell", true, local_scope)
set_opt("wrap", true, local_scope)

local buf_0 = { buf = 0 }
set("i", ",", ",<C-g>u", buf_0)
set("i", ".", ".<C-g>u", buf_0)
set("i", ":", ":<C-g>u", buf_0)
set("i", "-", "-<C-g>u", buf_0)
set("i", "?", "?<C-g>u", buf_0)
set("i", "!", "!<C-g>u", buf_0)

-- MID: For text, K would actually be most logical for this. But having dictionary checking on
-- different keys for text and markdown is also silly, since K in markdown would be LSP hover.
-- Thinking very generally, there should be multiple hover keys available. gK as a "secondary"
-- hover key feels reasonable. And zS for highlight info feels like a convention because of the
-- tpope plugin.
-- I also wonder if there's merit for a switch hover windows convention. <C-s> to cycle through
-- signature windows doesn't feel the most intuitive, though it's also kinda necessary because
-- that happens in insert mode.
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

-- Traditional, since the Obsidian plugin uses gf as its multi-function key
-- Since markdown-oxide uses goto definition for link nav, we don't need gf for that purpose
set("n", "gf", function()
    require("nvim-text-tools").toggle_checkbox()
end, { buf = 0 })

set("n", "gF", function()
    require("nvim-text-tools").remove_checkbox()
end, { buf = 0 })
