local api = vim.api
local set = vim.keymap.set

require("mjm.utils").set_buf_space_indent(0, 2)

-- "r" in Markdown treats lines like "- some text" as comments and indents them
mjm.opt.flag_rm("fo", { "r" }, { buf = 0 })

local local_scope = { scope = "local" }
api.nvim_set_option_value("colorcolumn", "", local_scope)
api.nvim_set_option_value("cursorlineopt", "screenline", local_scope)
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

-- MAYBE: Use prettier instead
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

mjm.lsp.start(vim.lsp.config["markdown_oxide"], { bufnr = 0 })

-- MAYBE: Potential friction point: Bullets overrides autopairs <cr> mapping
