require("farsight.plugin")

local api = vim.api
local set = vim.keymap.set

api.nvim_set_hl(0, "FarsightJump", { reverse = true })
api.nvim_set_hl(0, "FarsightJumpAhead", { underdouble = true })
api.nvim_set_hl(0, "FarsightJumpTarget", { reverse = true })

api.nvim_set_hl(0, "FarsightCsearch1st", { reverse = true })
api.nvim_set_hl(0, "FarsightCsearch2nd", { undercurl = true })
api.nvim_set_hl(0, "FarsightCsearch3rd", { underdouble = true })

set({ "n", "x", "o" }, "/", function()
    return require("farsight.search").search(1)
end, { expr = true })

set({ "n", "x", "o" }, "?", function()
    return require("farsight.search").search(-1)
end, { expr = true })

api.nvim_set_var("farsight_csearch_all_tokens", true)

--------------

set({ "n", "x" }, "y", function()
    return require("specops").yank()
end, { expr = true })

set({ "n", "x" }, "Y", function()
    return require("specops").yank() .. "$"
end, { expr = true })

set({ "n", "x" }, "<M-y>", function()
    return '"+' .. require("specops").yank()
end, { expr = true })

set({ "n", "x" }, "<M-Y>", function()
    return '"+' .. require("specops").yank() .. "$"
end, { expr = true })

set("x", "p", "P")
set("x", "P", "p")
set("n", "<M-p>", '"+p')
set("n", "<M-P>", '"+P')
set("x", "<M-p>", '"+P')
set("x", "<M-P>", '"+p')

set("n", "[p", '<Cmd>exe "iput! " . v:register<CR>')
set("n", "]p", '<Cmd>exe "iput "  . v:register<CR>')

set({ "n", "x" }, "<M-d>", '"_d')
set({ "n", "x" }, "<M-D>", '"_D')
set({ "n", "x" }, "<M-c>", '"_c')
set({ "n", "x" }, "<M-C>", '"_C')
