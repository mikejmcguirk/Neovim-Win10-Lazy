local api = vim.api

---@class farsight.locator.SearchCtx
---How many fields to allocate to each sub-table in targets
---@field alloc_size integer
---@field allow_folds "all"|"first_row"|"none"
---Does a result need to be wholly within the search bounds? Or is it acceptable if it overlaps
---with the search bounds?
---Example? Start row is 2 and start col is 5. The first result is on row 2, from cols 4 to 6.
---With allow_overlap, this position would be accepted. It would be rejected otherwise.
---@field allow_intersect boolean
---@field start_row integer
---@field start_col integer
---@field stop_row integer
---@field stop_col integer
---@field timeout integer

local has_ffi, ffi = pcall(require, "ffi")

local function has_ffi_search_globals()
    if not has_ffi then
        return false
    end

    local cdef_ok = pcall(
        ffi.cdef,
        [[
            extern int search_match_endcol;
            extern int search_match_lines;
        ]]
    )

    if not cdef_ok then
        return false
    end

    local access_ok = pcall(function()
        local _ = ffi.C.search_match_endcol
        local _ = ffi.C.search_match_lines
    end)

    if not access_ok then
        return false
    end

    return true
end

-- TODO: This is fine until PUC Lua compatibility is added back in
has_ffi_search_globals()

local M = {}

---Edits targets in place
---@param targets farsight.targets.Targets 1 indexed, exclusive
local function set_api_indexing(targets)
    targets:map_both_pos(1, 0, false, function(start_row, start_col, fin_row, fin_col)
        return start_row - 1, start_col - 1, fin_row - 1, fin_col - 1
    end)
end

---Edits targets in place
---@param targets farsight.targets.Targets 1 indexed, inclusive
---@param ctx farsight.locator.SearchCtx
local function filter_folds(targets, ctx)
    local allow_folds = ctx.allow_folds
    if allow_folds == "all" then
        return
    end

    local last_row = 0
    local last_fold_row = -1

    targets:filter_start_row(1, 0, false, false, function(start_row)
        local fold_row = last_row == start_row and last_fold_row
            or vim.call("foldclosed", start_row)

        last_row = start_row
        last_fold_row = fold_row

        if allow_folds == "first_row" then
            return fold_row == -1 or fold_row == start_row
        else
            return fold_row == -1
        end
    end)
end

---Edits targets in place
---@param targets farsight.targets.Targets 1 indexed, inclusive
---@param ctx farsight.locator.SearchCtx
local function trim_ends(targets, ctx)
    local ut = require("farsight.util")

    local allow_intersect = ctx.allow_intersect
    local stop_row = ctx.stop_row
    local stop_col = ctx.stop_col
    -- Because search() only stops by row, handle results on the stop row past the stop col
    targets:filter_both_pos(1, 0, true, true, function(start_row, start_col, fin_row, fin_col)
        local keep = ut.pos_lt(fin_row, fin_col, stop_row, stop_col)
        if allow_intersect then
            keep = keep
                or ut.pos_contained(start_row, start_col, fin_row, fin_col, stop_row, stop_col)
        end

        return keep
    end)

    local cs_row = ctx.start_row
    local cs_col = ctx.start_col
    targets:filter_both_pos(1, 0, false, true, function(start_row, start_col, fin_row, fin_col)
        local keep = ut.pos_lt(cs_row, cs_col, start_row, start_col)
        if allow_intersect then
            keep = keep or ut.pos_contained(start_row, start_col, fin_row, fin_col, cs_row, cs_col)
        end

        return keep
    end)
end
--
-- MID: Filtering the beginning is reasonable for safety, but I'm not sure why it would ever be
-- able to happen. Perhaps keeping it would be masking some other underlying issue.

---Edits targets and cache in place
---@param targets farsight.targets.Targets
---@param buf integer
---@param cache table<integer, table<integer, string>> Buf ID, <1-indexed row, line>
---@param ctx farsight.locator.SearchCtx
local function fix_target_values(targets, buf, cache, ctx)
    local ut = require("farsight.util")
    local buf_cache = ut.dict_get_key_or_default(cache, buf, {})
    local last_row = -1
    local line

    -- Handle OOB results from \n chars and zero length lines
    targets:map_start_pos(1, 0, false, function(start_row, start_col)
        if start_row ~= last_row then
            last_row = start_row
            line = buf_cache[start_row]
            if not line then
                line = api.nvim_buf_get_lines(buf, start_row - 1, start_row, false)[1]
                buf_cache[start_row] = line
            end
        end

        local new_start_col = math.min(start_col, #line)
        return start_row, new_start_col
    end)

    trim_ends(targets, ctx)
    filter_folds(targets, ctx)

    -- Handle |zero-width| results
    targets:map_both_pos(1, 0, false, function(start_row, start_col, fin_row, fin_col)
        local new_fin_col = fin_col
        if start_row == fin_row and fin_col < start_col then
            new_fin_col = start_col
        end

        return start_row, start_col, fin_row, new_fin_col
    end)

    local get_utf_codepoint = require("farsight._util_char")._get_utf_codepoint
    targets:map_fin_pos(1, 0, false, function(fin_row, fin_col)
        if fin_row ~= last_row then
            last_row = fin_row
            line = buf_cache[fin_row]
            if not line then
                line = api.nvim_buf_get_lines(buf, fin_row - 1, fin_row, false)[1]
                buf_cache[fin_row] = line
            end
        end

        local new_fin_col = math.max(fin_col, 1) -- Don't make end-exclusive yet
        local len_line = #line
        if len_line > 0 then
            new_fin_col = math.min(new_fin_col, len_line)
            local b1 = string.byte(line, new_fin_col)
            local _, len_char = get_utf_codepoint(line, b1, fin_col)
            new_fin_col = new_fin_col + len_char -- Make end-exclusive
        else
            new_fin_col = 2 -- Will be adjusted down to 1
        end

        return fin_row, new_fin_col
    end)
end
--
-- TODO: I don't love how the logic flows in here. It feels like we've over-optimized for speed
-- at the expense of accuracy. If the fin_rows aren't right, how can we be sure trim_ends will
-- be correct? It would also seem, somewhat sadly, that the max_fin_col to 1 correct needs to be
-- moved back up so we have the correct end-inclusive value for pos comparison

---@param targets farsight.targets.Targets
---@param buf integer
---@param cache table<integer, table<integer, string>> Buf ID, <1-indexed row, line>
local function fix_results_jit(targets, buf, cache)
    local ut = require("farsight.util")
    local buf_cache = ut.dict_get_key_or_default(cache, buf, {})
    local line_count = api.nvim_buf_line_count(buf)
    local line = buf_cache[line_count]
    if not line then
        line = api.nvim_buf_get_lines(buf, line_count - 1, line_count, false)[1]
        buf_cache[line_count] = line
    end

    for i, fin_row in targets:iter_fin_rows() do
        if fin_row <= line_count then
            break
        end

        targets:set_fin_pos(i, line_count, #line)
    end
end
-- TODO: Add iter_fin_rows
-- MID: You could add a map_fin_pos with stoppage if it doesn't change.

---@param move_cursor boolean
---@param cursor [integer, integer, integer, integer, integer]
local function checked_restore_cursor(move_cursor, cursor)
    if move_cursor then
        vim.call("cursor", { cursor[2], cursor[3], cursor[4], cursor[5] })
    end
end

---@param targets farsight.targets.Targets
---@return 1
local function add_search_result_jit(targets)
    local ffi_c = require("ffi").C

    local row = vim.call("line", ".")
    local col = vim.call("col", ".")

    local match_lines = ffi_c.search_match_lines --[[ @as integer ]]
    local fin_row = row + match_lines
    local fin_col = ffi_c.search_match_endcol --[[ @as integer ]]

    targets:add_new_target(row, col, fin_row, fin_col)

    return 1
end

---@param ctx farsight.locator.SearchCtx
---@return string
local function get_flags(ctx)
    local flags_tbl = { "nWz" }
    if ctx.allow_intersect then
        flags_tbl[#flags_tbl + 1] = "c"
    end

    return table.concat(flags_tbl, "")
end

---Edits targets and cache in place.
---I am unsure why now, but creating and returning targets here created problems with typing and
---error propagation.
---@param _ integer
---@param buf integer
---@param pattern string
---@param cursor [integer, integer, integer, integer, integer] See getcurpos()
---@param targets farsight.targets.Targets
---@param cache table<integer, table<integer, string>> Buf ID, <1-indexed row, line>
---@param ctx farsight.locator.SearchCtx
local function perform_search(_, buf, pattern, cursor, targets, cache, ctx)
    local flags = get_flags(ctx)
    local stop_row = ctx.stop_row
    local timeout = ctx.timeout

    local start_row = ctx.start_row
    local start_col = ctx.start_col

    local move_cursor = not (start_row == cursor[2] and start_col == cursor[3])
    if move_cursor then
        -- Use the vimfn because nvim_win_set_cursor updates the view and stages a redraw
        vim.call("cursor", start_row, start_col, 0)
    end

    local ok, err = pcall(vim.call, "search", pattern, flags, stop_row, timeout, function()
        return add_search_result_jit(targets)
    end)

    checked_restore_cursor(move_cursor, cursor)
    if ok then
        fix_results_jit(targets, buf, cache)
        return ok, nil, nil
    else
        -- TODO: Provide formatted target info. Targets should be able to provide data about
        -- itself that can be used
        -- These use the win var passed in
        return ok, err, "ErrorMsg"
    end
end

---@param win integer
---@param cur_win integer
---@param f function
---@return any, any, any
local function win_call_others(win, cur_win, f)
    if win == cur_win then
        return f()
    else
        return api.nvim_win_call(win, f)
    end
end

---@param win integer Win ID
---@param pattern string
---@param cursor [integer, integer, integer, integer, integer] See getcurpos()
---@param cache table<integer, table<integer, string>> Buf ID, <1-indexed row, line>
---@param ctx farsight.locator.SearchCtx
function M.search(win, pattern, cursor, cache, ctx)
    -- TODO: Validate pattern. Note that escaped \\ is fine
    if string.find(pattern, "\\c", 1, true) then
        return false, "Pattern cannot contain \\c", "ErrorMsg"
    end

    pattern = "\\C" .. pattern
    local cur_win = api.nvim_get_current_win()
    local buf = api.nvim_win_get_buf(win)
    local targets = require("farsight._targets").new(ctx.alloc_size)

    ---@type boolean, string|nil, string|nil
    local ok, err, err_hl = win_call_others(win, cur_win, function()
        return perform_search(win, buf, pattern, cursor, targets, cache, ctx)
    end)

    if not ok then
        local err_msg = err or ("Error searching win " .. 1000)
        return ok, err_msg, err_hl or "ErrorMsg"
    end

    if targets:get_len() == 0 then
        return ok, targets, nil
    end

    fix_target_values(targets, buf, cache, ctx)
    set_api_indexing(targets)

    return true, targets, nil
end
--
-- MAYBE: Pass cur_win and buf as params

return M

-- TODO: Want to handle boilerplate as much in _targets as possible. Trimming with overlap is
-- a good example

-- TODO: In the labeler, store the labels where they actually go. Saves redoing the cursor logic
-- multiple times.
-- TODO: Only semi-related, but consider setting dim to inlay hint, since dim on comments doesn't
-- do anything.
