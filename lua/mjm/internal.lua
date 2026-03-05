require("farsight.plugin")

local api = vim.api
local set = vim.keymap.set

api.nvim_set_hl(0, "FarsightJump", { reverse = true })
api.nvim_set_hl(0, "FarsightJumpAhead", { underdouble = true })
api.nvim_set_hl(0, "FarsightJumpTarget", { reverse = true })

api.nvim_set_hl(0, "FarsightCsearch1st", { reverse = true })
api.nvim_set_hl(0, "FarsightCsearch2nd", { undercurl = true })
api.nvim_set_hl(0, "FarsightCsearch3rd", { underdouble = true })

-- set({ "n", "x", "o" }, "/", function()
--     return require("farsight.search").search(1)
-- end, { expr = true })
--
-- set({ "n", "x", "o" }, "?", function()
--     return require("farsight.search").search(-1)
-- end, { expr = true })

set("n", "s", function()
    require("farsight.live").live_jump()
end)

-- foobar

api.nvim_set_var("farsight_csearch_all_tokens", true)
-- local test_ns = api.nvim_create_namespace("test-ns")
--
-- api.nvim_create_autocmd({ "CmdlineEnter", "CmdlineChanged" }, {
--     group = api.nvim_create_augroup("search-testing", { clear = true }),
--     callback = function()
--         vim.schedule(function()
--             -- vim.fn.histadd("input", vim.fn.getcmdprompt())
--             -- vim.fn.confirm("hey")
--             local cmd_type = vim.fn.getcmdtype()
--             if not (cmd_type == "/" or cmd_type == "?") then
--                 return
--             end
--             -- local old_cursor = vim.fn.getcurpos()
--             -- vim.fn.cursor({ 1, 1, 0, 0 })
--             local pattern = vim.fn.getcmdline()
--             local pos = vim.fn.searchpos(pattern, "zWn", 0, 500)
--
--             -- vim.fn.cursor({ old_cursor[2], old_cursor[3], old_cursor[4], old_cursor[5] })
--             if pos[1] == 0 then
--                 return
--             end
--
--             api.nvim_echo({ { vim.inspect(vim.fn.getcurpos()) } }, true, {})
--             api.nvim_buf_set_extmark(0, test_ns, pos[1] - 1, 0, {
--                 end_row = pos[1],
--                 end_col = 0,
--                 hl_eol = true,
--                 hl_group = "Comment",
--                 priority = 1000,
--             })
--             api.nvim__redraw({ valid = true, win = api.nvim_get_current_win() })
--         end)
--     end,
-- })
--
-- api.nvim_create_autocmd("CmdlineLeave", {
--     callback = function()
--         api.nvim_buf_clear_namespace(0, test_ns, 0, -1)
--     end,
-- })

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
