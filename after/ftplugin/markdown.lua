local api = vim.api
local ut = Mjm_Defer_Require("mjm.utils") ---@type MjmUtils

require("mjm.utils").set_buf_space_indent(0, 2)

-- "r" in Markdown treats lines like "- some text" as comments and indents them
mjm.opt.str_rm("fo", "r", { buf = 0 })

api.nvim_set_option_value("cc", "", { scope = "local" })
api.nvim_set_option_value("culopt", "number,screenline", { scope = "local" })
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
    ut.check_word_under_cursor()
end, { buffer = 0 })

-- MID: Create a localleader mapping in Conform for prettier, keep this for running on save

api.nvim_create_autocmd("BufWritePre", {
    buffer = 0,
    callback = function(ev)
        ut.fallback_formatter(ev.buf)
    end,
})

-- Traditional, since the Obsidian plugin uses gf as its multi-function key
-- Since markdown-oxide uses goto definition for link nav, we don't need gf for that purpose
vim.keymap.set("n", "gf", function()
    local tt = require("nvim-text-tools")
    tt.toggle_checkbox()
end, { buffer = 0 })

mjm.lsp.start(vim.lsp.config["markdown_oxide"], { bufnr = 0 })

-- MAYBE: Potential friction point: Bullets overrides autopairs <cr> mapping
