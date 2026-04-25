local api = vim.api

local M = {}

---This function assumes zero-based row indexing since that's how search_area() returns
---@param win integer Window context for foldclosed
---@param results nvim-tools.Results Edited in place
function M.filter_all_folded(win, results)
    local last_row = 0
    local last_foldclosed = false

    local cur_win = api.nvim_get_current_win()
    local ntw = require("nvim-tools.win")
    ntw.call_in(cur_win, win, function()
        results:filter_pos(false, function(row, _)
            local row_1 = row + 1
            if row_1 ~= last_row then
                last_foldclosed = vim.call("foldclosed", row_1)
                last_row = row_1
            end

            return last_foldclosed == -1
        end)
    end)
end

---This function assumes zero-based row indexing since that's how search_area() returns
---@param win integer Window context for foldclosed
---@param results nvim-tools.Results Edited in place
function M.filter_folded_except_first(win, results)
    local last_row = 0
    local last_foldclosed = false

    local cur_win = api.nvim_get_current_win()
    local ntw = require("nvim-tools.win")
    ntw.call_in(cur_win, win, function()
        results:filter_pos(false, function(row, _)
            local row_1 = row + 1
            if row_1 ~= last_row then
                last_foldclosed = vim.call("foldclosed", row_1)
                last_row = row_1
            end

            return last_foldclosed == -1 or last_foldclosed == row_1
        end)
    end)
end

-- Need one to fix zero width. You need to check them all against the line length so I guess
-- caching everything is fine. If you ban blank lines I guess you don't need to check line
-- length. Otherwise, the reason the old check doesn't have it is because it's rationalized
-- later (and I'm not totally sure it was correct anyway)

-- And then I'll omit the start col fix because (a) blank line ban (b) not sure if \n searches
-- work

-- Weird but maybe true - Do you store them as one indexed and then change them back to API
-- You can make cache zero based though and that should fix most issues. Only one that needs
-- one indexed then is fold no?

-- Don't get results on \n at all

-- And then it doesn't look like match_line does anything on zero length lines at all

-- You could actually ban search_area from blank lines now since it's not search() (no multiline
-- capability at all)

return M
