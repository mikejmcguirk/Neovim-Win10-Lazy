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

-- set("n", "s", function()
--     require("farsight.live").live_jump()
-- end)

api.nvim_set_var("farsight_csearch_all_tokens", true)

--------------

require("annotator.plugin")
set("n", "<leader>-k", "<Plug>(annotator-add-mark)")
set("n", "<leader>-K", "<Plug>(annotator-add-borders)")
set("n", "<leader>fnk", "<Plug>(annotator-fzf-lua-grep-curbuf)")
set("n", "<leader>fnK", "<Plug>(annotator-fzf-lua-grep-cwd)")
set("n", "<leader>qgk", "<Plug>(annotator-rancher-grep-cwd)")
set("n", "<leader>lgk", "<Plug>(annotator-rancher-grep-curbuf)")

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
set("n", "[<M-p>", '<Cmd>exe "iput! " . "+"<CR>')
set("n", "]<M-p>", '<Cmd>exe "iput "  . "+"<CR>')

set({ "n", "x" }, "<M-d>", '"_d')
set({ "n", "x" }, "<M-D>", '"_D')
set({ "n", "x" }, "<M-c>", '"_c')
set({ "n", "x" }, "<M-C>", '"_C')

local did_open_help = false

local function HelpCurwin(subject)
    local mods = "silent noautocmd keepalt"

    if not did_open_help then
        vim.cmd(mods .. " help")
        vim.cmd(mods .. " helpclose")
        did_open_help = true
    end

    -- Only prepare the current buffer as a help buffer if the subject is a valid help topic
    if #vim.fn.getcompletion(subject or "", "help") > 0 then
        vim.cmd(mods .. " edit " .. vim.o.helpfile)
        vim.bo.buftype = "help"
    end

    return "help " .. (subject or "")
end

vim.api.nvim_create_user_command("HelpCurwin", function(opts)
    local subject = opts.args
    local cmd = HelpCurwin(subject)
    vim.cmd(cmd)
end, { nargs = "?", complete = "help", bar = true })

--- Collects all `\k\+` (keyword) matches starting from the current cursor position
--- to the end of the buffer using `vim.regex:match_line`. Returns two tables:
--- `rows` (1-based line numbers) and `cols` (0-based byte columns).
--- Times the operation with `vim.uv.hrtime()`.
-- local function collect_keywords_from_cursor()
--     local start_time = vim.uv.hrtime()
--
--     local re = vim.regex([[\k\+]])
--
--     local buf = vim.api.nvim_get_current_buf()
--     local cursor = vim.api.nvim_win_get_cursor(0) -- {1-based lnum, 0-based byte col}
--     local start_lnum = cursor[1] - 1 -- convert to 0-based for API
--     local start_col = cursor[2]
--
--     local rows = {}
--     local cols = {}
--
--     local last_lnum = vim.api.nvim_buf_line_count(buf) - 1
--
--     for lnum = start_lnum, last_lnum do
--         local search_start = (lnum == start_lnum) and start_col or 0
--
--         while true do
--             -- match_line(bufnr, lnum_0based, start_byte?, end_byte?)
--             -- Returns match_start / match_end RELATIVE to `search_start`
--             local rel_start, rel_end = re:match_line(buf, lnum, search_start)
--             if not rel_start then
--                 break
--             end
--
--             local abs_col = search_start + rel_start
--
--             table.insert(rows, lnum + 1) -- store as 1-based row
--             table.insert(cols, abs_col)
--
--             -- Advance past this match (rel_end is also relative to search_start)
--             search_start = search_start + rel_end
--
--             -- Safety: \k\+ never produces zero-width matches, but guard anyway
--             if rel_end <= 0 then
--                 break
--             end
--         end
--     end
--
--     local duration_ms = (vim.uv.hrtime() - start_time) / 1e6
--
--     vim.notify(
--         string.format("Collected %d keywords from cursor in %.2f ms", #rows, duration_ms),
--         vim.log.levels.INFO
--     )
--
--     return rows, cols
-- end
--
-- vim.keymap.set("n", "<leader><leader>", function()
--     collect_keywords_from_cursor()
-- end)
