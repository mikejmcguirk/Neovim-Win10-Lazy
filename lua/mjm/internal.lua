require("farsight.plugin")

local api = vim.api
local set = vim.keymap.set

api.nvim_set_hl(0, "FarsightJump", { reverse = true })
api.nvim_set_hl(0, "FarsightJumpAhead", { underdouble = true })
api.nvim_set_hl(0, "FarsightJumpTarget", { reverse = true })

api.nvim_set_hl(0, "FarsightCsearch1st", { reverse = true })
api.nvim_set_hl(0, "FarsightCsearch2nd", { undercurl = true })
api.nvim_set_hl(0, "FarsightCsearch3rd", { underdouble = true })

-- local function sneak_locator(sneak_text, row, line)
--     -- Valid since the locator function is called in the proper window context
--     if vim.fn.prevnonblank(row) ~= row or vim.fn.foldclosed(row) ~= -1 then
--         return {}
--     end
--
--     local cols = {}
--     local start = 1
--
--     while true do
--         local from, to = string.find(line, sneak_text, start, true)
--         if from == nil or to == nil then
--             break
--         end
--
--         cols[#cols + 1] = from - 1 -- Make zero indexed
--         start = to + 1
--     end
--
--     return cols
-- end
--
-- local function get_two_chars()
--     vim.cmd("redraw")
--     local prompt = "Sneak: "
--     vim.api.nvim_echo({ { prompt } }, false, {})
--
--     local c1 = vim.fn.getcharstr()
--     if c1 == "\27" or c1 == "\3" then
--         return nil
--     end
--
--     vim.api.nvim_echo({ { prompt .. c1 } }, false, {})
--     local c2 = vim.fn.getcharstr()
--     if c2 == "\27" or c2 == "\3" then
--         return nil
--     end
--
--     vim.api.nvim_echo({ { prompt .. c1 .. c2 } }, false, {})
--     return c1 .. c2
-- end
--
-- set("n", "<cr>", function()
--     local sneak_text = get_two_chars()
--     if not sneak_text then
--         vim.api.nvim_echo({ { "" } }, false, {})
--         return
--     end
--
--     require("farsight.jump").jump({
--         locator = function(_, row, line, _, _)
--             return sneak_locator(sneak_text, row, line)
--         end,
--     })
--
--     vim.api.nvim_echo({ { "" } }, false, {})
-- end)

-- vim.keymap.set("n", "<cr>", function()
--     require("farsight.jump").jump({ wins = api.nvim_tabpage_list_wins(0) })
-- end)
--
--
-- vim.keymap.set({ "x", "o" }, "<cr>", function()
--     require("farsight.jump").jump({})
-- end)

-- local actions_forward = {
--
--     ["\r"] = function()
--         require("farsight.jump").jump({ all_wins = false, dir = 1 })
--     end,
-- }
--
-- local actions_backward = {
--
--     ["\r"] = function()
--         require("farsight.jump").jump({ all_wins = false, dir = -1 })
--     end,
-- }

-- vim.keymap.set({ "n", "x" }, "f", function()
--     require("farsight.csearch").csearch({ actions = actions_forward })
-- end)
--
-- vim.keymap.set({ "n", "x" }, "t", function()
--     require("farsight.csearch").csearch({
--         t_cmd = true,
--         actions = actions_forward,
--     })
-- end)
--
-- vim.keymap.set({ "n", "x" }, "F", function()
--     require("farsight.csearch").csearch({
--         forward = false,
--         actions = actions_backward,
--     })
-- end)
--
-- vim.keymap.set({ "n", "x" }, "T", function()
--     require("farsight.csearch").csearch({
--         actions = actions_backward,
--         forward = false,
--         t_cmd = true,
--     })
-- end)
--
-- vim.keymap.set({ "n", "x" }, ";", function()
--     require("farsight.csearch").rep()
-- end)
--
-- vim.keymap.set({ "n", "x" }, ",", function()
--     require("farsight.csearch").rep({ reverse = true })
-- end)

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
