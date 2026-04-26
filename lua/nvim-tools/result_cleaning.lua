local api = vim.api

local M = {}

---This function assumes zero-based row indexing since that's how match_area() returns
---@param win? integer Window context for foldclosed
---@param results nvim-tools.Results Edited in place
function M.filter_folded_all(win, results)
    local is_uint = require("nvim-tools.types").is_uint
    vim.validate("win", win, is_uint, true)
    vim.validate("results", results, "table")

    local fc_cache = {} ---@type table<integer, integer>
    -- Do it this way to keep Lua_Ls happy
    if win == nil or win == 0 then
        win = api.nvim_get_current_win()
    end

    local ntw = require("nvim-tools.win")
    local cur_win = api.nvim_get_current_win()
    ntw.call_in(cur_win, win, function()
        results:filter_pos(false, false, function(row, _)
            local cached = fc_cache[row]
            if cached then
                return cached == -1
            end

            local foldclosed = vim.call("foldclosed", row + 1)
            fc_cache[row] = foldclosed
            return foldclosed == -1
        end)
    end)
end

---This function assumes zero-based row indexing since that's how match_area() returns
---@param win? integer Window context for foldclosed
---@param results nvim-tools.Results Edited in place
function M.filter_folded_except_first(win, results)
    local is_uint = require("nvim-tools.types").is_uint
    vim.validate("win", win, is_uint, true)
    vim.validate("results", results, "table")

    local fc_cache = {} ---@type table<integer, integer>
    -- Do it this way to keep Lua_Ls happy
    if win == nil or win == 0 then
        win = api.nvim_get_current_win()
    end

    local ntw = require("nvim-tools.win")
    local cur_win = api.nvim_get_current_win()
    ntw.call_in(cur_win, win, function()
        results:filter_pos(false, false, function(row, _)
            local row_1 = row + 1
            local cached = fc_cache[row_1]
            if cached then
                return cached == -1 or cached == row_1
            end

            local foldclosed = vim.call("foldclosed", row_1)
            fc_cache[row_1] = foldclosed
            return foldclosed == -1 or foldclosed == row_1
        end)
    end)
end

---This function assumes zero-based row indexing since that's how match_area() returns
---Also assumes no zero length lines.
---@param win? integer Window context for foldclosed
---@param results nvim-tools.Results Edited in place
function M.filter_folded_keep_stub(win, results)
    local is_uint = require("nvim-tools.types").is_uint
    vim.validate("win", win, is_uint, true)
    vim.validate("results", results, "table")

    local fc_cache = {} ---@type table<integer, integer>
    -- Do it this way to keep Lua_Ls happy
    if win == nil or win == 0 then
        win = api.nvim_get_current_win()
    end

    local cur_win = api.nvim_get_current_win()
    local ntw = require("nvim-tools.win")
    ntw.call_in(cur_win, win, function()
        results:filter_map_pos(false, function(row, col)
            local row_1 = row + 1

            local cached = fc_cache[row_1]
            if cached then
                if cached == -1 then
                    return row, col
                else
                    return nil, nil
                end
            end

            local foldclosed = vim.call("foldclosed", row_1)
            fc_cache[row_1] = foldclosed
            if foldclosed == -1 then
                return row, col
            elseif foldclosed == row_1 then
                return row, 1
            else
                return nil, nil
            end
        end)
    end)
end

---Assumes that no zero length lines are included in the results, since match_area() skips them.
---Also assumes that match_area() cleans or rejects OOB start_col results
---@param results nvim-tools.Results Edited in place
function M.fix_zero_width(results)
    vim.validate("results", results, "table")

    results:map_both_pos(1, 0, function(sr, sc, fr, fc)
        if not (sr == fr and sc == fc) then
            return sr, sc, fr, fc
        end

        return sr, sc, fr, fc + 1
    end)
end

---@param desc? boolean
---@param fin? boolean
---@param results nvim-tools.Results Edited in place
function M.sort_by_pos(desc, fin, results)
    vim.validate("desc", desc, "boolean")
    vim.validate("fin", fin, "boolean", true)
    vim.validate("results", results, "table")

    local ntp = require("nvim-tools.pos")
    local cmp = desc and ntp.gt or ntp.lt
    results:sort_by_pos(fin, function(row_a, col_a, row_b, col_b)
        return cmp(row_a, col_a, row_b, col_b)
    end)
end

---@param row integer
---@param col integer
---@param fin? boolean
---@param results nvim-tools.Results Edited in place
function M.sort_by_pythagorean_dist(row, col, fin, results)
    local is_uint = require("nvim-tools.types").is_uint
    vim.validate("row", row, is_uint)
    vim.validate("col", col, is_uint)
    vim.validate("fin", fin, "boolean", true)
    vim.validate("results", results, "table")

    local py_dist = require("nvim-tools.pos").pythagorean_dist
    results:sort_by_pos(fin, function(row_a, col_a, row_b, col_b)
        return py_dist(row, col, row_a, col_a) < py_dist(row, col, row_b, col_b)
    end)
end

return M
