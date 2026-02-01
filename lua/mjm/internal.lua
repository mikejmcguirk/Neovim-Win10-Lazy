local api = vim.api
local set = vim.keymap.set

api.nvim_set_hl(0, "FarsightJump", { reverse = true })
api.nvim_set_hl(0, "FarsightJumpAhead", { underdouble = true })
api.nvim_set_hl(0, "FarsightJumpTarget", { reverse = true })

api.nvim_set_hl(0, "FarsightCsearch1st", { reverse = true })
api.nvim_set_hl(0, "FarsightCsearch2nd", { undercurl = true })
api.nvim_set_hl(0, "FarsightCsearch3rd", { underdouble = true })

vim.keymap.set("n", "<cr>", function()
    require("farsight.jump").jump({ wins = api.nvim_tabpage_list_wins(0) })
end)

vim.keymap.set({ "x", "o" }, "<cr>", function()
    require("farsight.jump").jump({})
end)

local actions_forward = {

    ["\r"] = function()
        require("farsight.jump").jump({ all_wins = false, dir = 1 })
    end,
}

local actions_backward = {

    ["\r"] = function()
        require("farsight.jump").jump({ all_wins = false, dir = -1 })
    end,
}

vim.keymap.set({ "n", "x" }, "f", function()
    require("farsight.csearch").csearch({ actions = actions_forward })
end)

vim.keymap.set({ "n", "x" }, "t", function()
    require("farsight.csearch").csearch({
        t_cmd = true,
        actions = actions_forward,
    })
end)

vim.keymap.set({ "n", "x" }, "F", function()
    require("farsight.csearch").csearch({
        forward = false,
        actions = actions_backward,
    })
end)

vim.keymap.set({ "n", "x" }, "T", function()
    require("farsight.csearch").csearch({
        actions = actions_backward,
        forward = false,
        t_cmd = true,
    })
end)

vim.keymap.set({ "n", "x" }, ";", function()
    require("farsight.csearch").rep()
end)

vim.keymap.set({ "n", "x" }, ",", function()
    require("farsight.csearch").rep({ reverse = true })
end)

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

set("n", "[p", '<Cmd>exe "iput! " . v:register<CR>')
set("n", "]p", '<Cmd>exe "iput "  . v:register<CR>')

-- set({ "n", "x" }, "d", function()
--     return require("specops").delete()
-- end, { expr = true })
--
-- set({ "n", "x" }, "D", function()
--     return require("specops").delete() .. "$"
-- end, { expr = true })
--
-- set({ "n", "x" }, "<M-d>", function()
--     return '"_' .. require("specops").delete()
-- end, { expr = true })
--
-- set({ "n", "x" }, "<M-D>", function()
--     return '"_' .. require("specops").delete() .. "$"
-- end, { expr = true })
--
-- set({ "n", "x" }, "c", function()
--     return require("specops").change()
-- end, { expr = true })
--
-- set({ "n", "x" }, "C", function()
--     return require("specops").change() .. "$"
-- end, { expr = true })
--
-- set({ "n", "x" }, "<M-c>", function()
--     return '"_' .. require("specops").change()
-- end, { expr = true })
--
-- set({ "n", "x" }, "<M-C>", function()
--     return '"_' .. require("specops").change() .. "$"
-- end, { expr = true })
