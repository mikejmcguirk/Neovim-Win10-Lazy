local api = vim.api
local util = vim.lsp.util

---@alias farsight.aos_buf_match.Folds "all"|"first"|"none"

---@alias farsight.aos_buf_match.MatchStart "zero"|"on"|"after"

---@alias farsight.aos_buf_match.MatchEnd "before"|"on"

---Internally uses nvim_win_call
---@param win uinteger
---@param ranges [uinteger, uinteger, uinteger, uinteger][] Modified in place!
local function folds_rm_all(win, ranges)
    api.nvim_win_call(win, function()
        require("nvim-tools.table").i_keep(ranges, function(target)
            return vim.call("foldclosed", target[1]) == -1
        end)
    end)
end

---Internally uses nvim_win_call
---@param win uinteger
---@param ranges [uinteger, uinteger, uinteger, uinteger][] Modified in place!
local function folds_keep_first(win, ranges)
    api.nvim_win_call(win, function()
        local ntt = require("nvim-tools.table")
        ntt.i_filter_modify_accum(ranges, {}, function(fold_rows, target)
            local fold_row = vim.call("foldclosed", target[1])
            if fold_row == -1 then
                return fold_rows, target
            end

            local fold_row_0 = fold_row - 1 ---@cast fold_row_0 uinteger
            if fold_rows[fold_row_0] == nil then
                target[1] = fold_row_0
                target[2] = 0
                target[3] = fold_row_0
                target[4] = 0

                fold_rows[fold_row_0] = true
                return fold_rows, target
            else
                return fold_rows, nil
            end
        end)
    end)
end

---Internally uses nvim_win_call
---@param folds farsight.aos_buf_match.Folds
---@param win uinteger
---@param ranges [uinteger, uinteger, uinteger, uinteger][] Modified in place!
local function folds_handle(folds, win, ranges)
    if folds == "none" then
        folds_rm_all(win, ranges)
    elseif folds == "first" then
        folds_keep_first(win, ranges)
    end
end
-- TODO: Worth making the "first" logic more clear somehow. I had to do an investigation into
-- the old code to re-discover what it was doing and why.

---@param buf integer
---@param start_row integer
---@param lines table<integer, string> 0 indexed. Modified in place!
local function add_lines(buf, start_row, end_row_, lines)
    local new_lines = api.nvim_buf_get_lines(buf, start_row, end_row_, false)
    for i = 1, #new_lines do
        lines[start_row + i - 1] = new_lines[i]
    end
end

---@param start_row uinteger Assumed to be <= end_row.
---@param end_row uinteger
---@param buf integer
---@param lines table<integer, string> 0 indexed. Modified in place!
---@return table<integer, string> Reference to `lines`.
local function add_missing_lines(start_row, end_row, buf, lines)
    local start_missing = -1
    for i = start_row, end_row - 1 do
        if lines[i] == nil then
            if start_missing == -1 then
                start_missing = i
            end
        else
            if start_missing ~= -1 then
                add_lines(buf, start_missing, i, lines)
                start_missing = -1
            end
        end
    end

    if start_missing ~= -1 then
        add_lines(buf, start_missing, end_row, lines)
    end

    return lines
end

---@param stop_col_ uinteger
---@param re vim.regex
---@param buf uinteger
---@param row uinteger 0 indexed
---@param init uinteger 0 indexed
---@param res [uinteger, uinteger, uinteger, uinteger][] Modified in place!
local function match_line(init, stop_col_, re, buf, row, res)
    while init < stop_col_ do
        local sc, ec_ = re:match_line(buf, row, init, stop_col_)
        if sc == nil or ec_ == nil then
            break
        end

        sc = sc + init
        ec_ = ec_ + init
        -- Handle |/zero-width| expressions
        if sc < ec_ then
            res[#res + 1] = { row, sc, row, ec_ }
            init = ec_
        else
            init = ec_ + 1
        end
    end
end

---@param buf uinteger Assumes the buf is loaded.
---@param range [uinteger, uinteger, uinteger, uinteger] 0,0,0,0 indexed, end exclusive. Assumes
---the range is valid within the buf.
---@param re vim.regex
---@return [uinteger, uinteger, uinteger, uinteger][]
local function match_area(range, buf, lines, re)
    local sr = range[1]
    local er = range[3]
    lines = add_missing_lines(sr, er, buf, lines)
    -- Alloc 16 to avoid initial thrashing.
    local targets = require("nvim-tools.table").new(16, 0)

    if sr == er then
        match_line(range[2], range[4], re, buf, sr, targets)
    else
        match_line(range[2], #lines[sr], re, buf, sr, targets)
        for i = sr + 1, er - 1 do
            match_line(0, #lines[i], re, buf, i, targets)
        end

        match_line(0, range[4], re, buf, er, targets)
    end

    return targets
end

---@param win uinteger
---@param buf uinteger
---@param dir -1|0|1
---@param match_end "before"|"on"
---@param match_start "zero"|"on"|"after"
---@return [uinteger, uinteger, uinteger, uinteger]
local function match_range_get(win, buf, dir, match_start, match_end)
    local top_0 = vim.call("line", "w0", win) - 1 ---@cast top_0 uinteger
    local cursor_ext = require("nvim-tools.win").cursor_ext_get(win)

    local range = { 0, 0, 0, 0 }
    if dir <= 0 then
        range[1] = top_0
        range[2] = 0
    else
        range[1] = cursor_ext[1]
        if match_start == "zero" then
            range[2] = 0
        elseif match_start == "after" then
            local cur_row_0 = cursor_ext[1]
            local cursor_line = api.nvim_buf_get_lines(buf, cur_row_0, cur_row_0 + 1, false)[1]
            -- TODO: Unsure how to handle if this clamps to the last byte.
            -- TODO: This also needs to handle multiline chars
            range[2] = math.min(cursor_ext[2] + 1, #cursor_line)
        else
            range[2] = cursor_ext[2]
        end
    end

    if 0 <= dir then
        local bot_0 = vim.call("line", "w$", win) - 1 ---@cast bot_0 uinteger
        range[3] = bot_0
        range[4] = #api.nvim_buf_get_lines(buf, bot_0, bot_0 + 1, false)[1]
    else
        range[3] = cursor_ext[1]
        if match_end == "before" then
            range[4] = math.max(cursor_ext[2] - 1, 0)
        else
            range[4] = cursor_ext[2]
        end
    end

    return range
end
-- MID: If you add to `lines` here, you add three API calls in this function and two in
-- `add_missing_lines`. Questionable trade for only three strings.

local M = {}

---@class farsight.aos_match.Ctx
---@field dir -1|0|1
---@field folds farsight.aos_buf_match.Folds
---@field match_end "before"|"on"
---@field match_start "zero"|"on"|"after"

---@class farsight.aos_win_match.Ret
---@field buf uinteger
---@field targets [uinteger, uinteger, uinteger, uinteger][]

---@param win uinteger
---@param buf uinteger
---@param lines table<uinteger, string> Modified in place!
---@param re vim.regex
---@param ctx farsight.aos_match.Ctx
---@return farsight.aos_win_match.Ret
---@return table<uinteger, string>
---@return [uinteger, uinteger, uinteger, uinteger]
local function win_targets_get(win, buf, lines, re, ctx)
    local dir = ctx.dir
    local match_start = ctx.match_start
    local match_end = ctx.match_end

    local match_range = match_range_get(win, buf, dir, match_start, match_end)
    local targets = match_area(match_range, buf, lines, re)
    folds_handle(ctx.folds, win, targets)

    return { buf = buf, targets = targets }, lines, match_range
end

---@param range [uinteger, uinteger, uinteger, uinteger]
---@param win uinteger
---@param buf uinteger
---@param lines table<uinteger, string> Modified in place!
---@param re vim.regex
---@return [uinteger, uinteger, uinteger, uinteger][]
function M.res_live_get(range, win, buf, lines, re)
    local ranges = match_area(range, buf, lines, re)
    folds_handle("none", win, ranges)
    return ranges
end
-- TODO: Applies to this whole module, but the incoming lines need to be correct here. We need to
-- get back to the "return or side effect, but not both" rule.

---@param pattern string
---@return string
function pattern_resolve(pattern)
    return (string.find(pattern, "^\\$") or string.find(pattern, "[^\\]\\$")) and "" or pattern
end

---@param win uinteger
---@param pattern string
---@param ctx farsight.aos_match.Ctx
---@return boolean, uinteger, vim.regex, [uinteger, uinteger, uinteger, uinteger], string
function M.live_info_get(win, pattern, ctx)
    pattern = pattern_resolve(pattern)
    if pattern == "" then
        -- TODO: More informative output once we better understand how this is used.
        return false, 0, vim.regex(pattern), { 0, 0, 0, 0 }, ""
    end

    local ok, re = pcall(vim.regex, pattern)
    if not ok then
        return false, 0, vim.regex(""), { 0, 0, 0, 0 }, re
    end

    local win_buf = api.nvim_win_get_buf(win)

    local dir = ctx.dir
    local match_start = ctx.match_start
    local match_end = ctx.match_end
    local match_range = match_range_get(win, win_buf, dir, match_start, match_end)

    return true, win_buf, re, match_range, ""
end
-- TODO-DEP: The common logic with this and targets_get needs to be outlined.
-- Blocker: I'm not sure what the csearch interface is yet.
-- TODO: This need more informative outputs.

---@param wins uinteger[]
---@param pattern string
---@param ctx farsight.aos_match.Ctx
---@return boolean Valid results?
---@return table<uinteger, farsight.aos_win_match.Ret> Results by win.
---@return table<uinteger, [uinteger, uinteger, uinteger, uinteger]>
---@return string
function M.targets_get(wins, pattern, ctx)
    local win_targets = {} ---@type table<uinteger, farsight.aos_win_match.Ret>
    pattern = pattern_resolve(pattern)
    if pattern == "" then
        -- TODO: More informative output once we better understand how this is used.
        return true, win_targets, { 0, 0, 0, 0 }, ""
    end

    local ok, re = pcall(vim.regex, pattern)
    if not ok then
        return false, win_targets, { 0, 0, 0, 0 }, re
    end

    local ntt = require("nvim-tools.table")
    local buf_lines = {} ---@type table<uinteger, table<uinteger, string>>
    local match_ranges = {} ---@type table<uinteger, [uinteger, uinteger, uinteger, uinteger]>
    for _, win in ipairs(wins) do
        local win_buf = api.nvim_win_get_buf(win)
        local win_buf_lines = ntt.get_or_set_subtable(buf_lines, win_buf)
        local targets, _, match_range = win_targets_get(win, win_buf, win_buf_lines, re, ctx)
        win_targets[win] = targets
        match_ranges[win] = match_range
    end

    return true, win_targets, match_ranges, ""
end
-- TODO: This interface feels right for static but I'm not sure about csearch, where we always
-- know we are only doing one win.

return M

-- TODO: Unsure what to do about nomatch scenario.
