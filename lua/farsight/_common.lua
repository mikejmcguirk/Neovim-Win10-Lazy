local api = vim.api
local fn = vim.fn

---@class farsight.common.SearchResults
---@field [1] boolean Upward? True if going up from cursor
---@field [2] integer Length valid indexes
---@field [3] integer[] Valid indexes
---@field [4] integer[] Start rows (0 based, inclusive)
---@field [5] integer[] Start cols (0 based, inclusive)
---@field [6] integer[] Fin rows (0 based, inclusive)
---@field [7] integer[] Fin cols (0 based, exclusive)

-- MAYBE: Use dir -2/2 for cursor to top of the buffer and 2 for cursor to the bottom of the
-- buffer. A wrapscan search could then be -3/3. Note that redraw valid needs to be checked for
-- any search >= 0.
-- MAYBE: Have an opt for searching line ranges.

---@class farsight.common.SearchOpts
---alloc_size
---How many fields to initially allocate in the results lists.
---@field [1] integer
---allow_folds
---`0`: Allow all results in folded lines.
---`1`: Allow results from the first line of each folded block
---`2`: Allow only the first result from each folded block. From any line.
---`3`: Reject all folded results.
---@field [2] integer
---dir
---`-1`: From the window to the top of the cursor
---`0`: The entire window
---`1`: From the cursor to the bottom of the window
---@field [3] integer
---handle_count
---If true, results will be eliminated based on the value of vim.v.count1.
---Example: If vcount1 == 2, the first result would be rejected, since it would not be used.
---@field [4] boolean
---Timeout in ms.
---@field [5] integer
---upward
---Should results be interpreted such that the "closest" result is the last result or the first?
---This flag is necessary because, even if dir is -1, searching is always performed forward for
---performance reasons.
---@field [6] boolean
---wins
---Which wins to search.
---@field [7] integer[]

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

local M = {}

local did_setup_repeat_tracking = false
local is_repeating = 0 ---@type 0|1

function M.get_is_repeating()
    return is_repeating
end

local function setup_repeat_tracking()
    if did_setup_repeat_tracking then
        return
    end

    if has_ffi then
        -- Dot repeats move their text from the repeat buffer to the stuff buffer for execution.
        -- When chars are processed from that buffer, the KeyStuffed global is set to 1.
        -- searchc in search.c checks this value for redoing state.
        if pcall(ffi.cdef, "int KeyStuffed;") then
            M.get_is_repeating = function()
                return ffi.C.KeyStuffed --[[@as 0|1]]
            end

            return
        end
    end

    -- Credit folke/flash
    vim.on_key(function(key)
        if key == "." and fn.reg_executing() == "" and fn.reg_recording() == "" then
            is_repeating = 1
            vim.schedule(function()
                is_repeating = 0
            end)
        end
    end)

    did_setup_repeat_tracking = true
end

setup_repeat_tracking()

---Edits res in place
---@param res farsight.common.SearchResults 1 indexed, exclusive
local function set_api_indexes(res)
    local len_res = res[2]
    if len_res < 1 then
        return
    end

    local res_idxs = res[3]
    local res_rows = res[4]
    local res_cols = res[5]
    local res_fin_rows = res[6]
    local res_fin_cols = res[7]

    for i = 1, len_res do
        local idx = res_idxs[i]
        res_rows[idx] = res_rows[idx] - 1
        res_cols[idx] = res_cols[idx] - 1
        res_fin_rows[idx] = res_fin_rows[idx] - 1
        res_fin_cols[idx] = res_fin_cols[idx] - 1
    end
end

---Edits res in place
---@param res farsight.common.SearchResults 1 indexed, inclusive
local function clear_fold_rows_rev(res)
    local len_res = res[2]
    if len_res < 1 then
        return
    end

    local res_idxs = res[3]
    local res_rows = res[4]

    local last_row = 0
    local last_fold_row = -1
    local candidate_i = 0
    local j = 1
    for i = 1, len_res do
        local row = res_rows[res_idxs[i]]
        local same_row = last_row == row
        local fold_line = same_row and last_fold_row or vim.call("foldclosed", row)
        last_row = row
        if fold_line == -1 then
            if candidate_i > 0 then
                res_idxs[j] = res_idxs[candidate_i]
                j = j + 1
                candidate_i = 0
            end

            res_idxs[j] = res_idxs[i]
            j = j + 1
            last_fold_row = -1
        else
            if fold_line ~= last_fold_row then
                if candidate_i > 0 then
                    res_idxs[j] = res_idxs[candidate_i]
                    j = j + 1
                end

                candidate_i = i
                last_fold_row = fold_line
            else
                candidate_i = i
            end
        end
    end

    if candidate_i > 0 then
        res_idxs[j] = res_idxs[candidate_i]
        j = j + 1
    end

    res[2] = j - 1
end

---Edits res in place
---@param res farsight.common.SearchResults 1 indexed, inclusive
local function clear_fold_rows_fwd(res)
    local len_res = res[2]
    if len_res < 1 then
        return
    end

    local res_idxs = res[3]
    local res_rows = res[4]

    local last_row = 0
    local last_fold_row = -1
    local j = 0
    for i = 1, len_res do
        local row = res_rows[res_idxs[i]]
        local fold_row = last_row == row and last_fold_row or vim.call("foldclosed", row)
        last_row = row
        if fold_row == -1 then
            j = j + 1
            res_idxs[j] = res_idxs[i]
            last_fold_row = -1
        else
            if last_fold_row ~= fold_row then
                j = j + 1
                res_idxs[j] = res_idxs[i]
                last_fold_row = fold_row
            end
        end
    end

    res[2] = j
end

---Edits res in place
---@param res farsight.common.SearchResults 1 indexed, inclusive
---@param f fun(fold_row: integer, row: integer):boolean
local function remove_folded_by_condition(res, f)
    local len_res = res[2]
    if len_res < 1 then
        return
    end

    local res_idxs = res[3]
    local res_rows = res[4]

    local last_row = 0
    local last_fold_row = -1
    local j = 0
    for i = 1, len_res do
        local row = res_rows[res_idxs[i]]
        local same_row = last_row == row
        local fold_row = same_row and last_fold_row or vim.call("foldclosed", row)
        last_row = row
        last_fold_row = fold_row

        if f(fold_row, row) then
            j = j + 1
            res_idxs[j] = res_idxs[i]
        end
    end

    res[2] = j
end

---Edits res in place
---@param res farsight.common.SearchResults 1 indexed, inclusive
---@param opts farsight.common.SearchOpts
local function clear_fold_rows(res, opts)
    if opts[2] <= 0 then
        return
    end

    if opts[2] == 1 then
        remove_folded_by_condition(res, function(fold_row, row)
            return fold_row == -1 or fold_row == row
        end)
    elseif opts[2] == 2 then
        if res[1] then
            clear_fold_rows_rev(res)
        else
            clear_fold_rows_fwd(res)
        end
    else
        remove_folded_by_condition(res, function(fold_row, _)
            return fold_row ~= -1
        end)
    end
end

---Edits res in place
---@param cursor [integer, integer, integer, integer, integer] 1 indexed, inclusive
---@param res farsight.common.SearchResults 1 indexed, inclusive
local function trim_upward_res(cursor, res)
    local len_res = res[2]
    if len_res < 1 then
        return
    end

    local res_idxs = res[3]
    local res_rows = res[4]
    local res_cols = res[5]
    local cur_row = cursor[2]
    local cur_col = cursor[3]

    -- Searching from the top to the cursor row might cause results to spill over the cursor
    -- column.
    for i = len_res, 1, -1 do
        local idx = res_idxs[i]
        local start_row = res_rows[idx]
        local start_above = start_row < cur_row
        if start_above or (start_row == cur_row and res_cols[idx] < cur_col) then
            break
        else
            res[2] = res[2] - 1
        end
    end

    -- Adjust for vcount1 now. Because the entries closest to the cursor are searched last, they
    -- cannot be skipped when running search().
    res[2] = res[2] - (vim.v.count1 - 1)
end

---@param buf integer
---@param res farsight.common.SearchResults 1 indexed, inclusive
---@param cache table<integer, table<integer, string>>
---@param cursor [integer, integer, integer, integer, integer]
---@param opts farsight.common.SearchOpts
local function adjust_res_values(buf, res, cache, cursor, opts)
    local len_res = res[2]
    local res_idxs = res[3]
    local res_rows = res[4]
    local res_cols = res[5]

    cache[buf] = cache[buf] or {}
    local buf_cache = cache[buf]

    local last_row = -1
    local line
    for i = 1, len_res do
        local idx = res_idxs[i]
        local row = res_rows[idx]
        if row ~= last_row then
            last_row = row
            line = buf_cache[row]
            if not line then
                line = api.nvim_buf_get_lines(buf, row - 1, row, false)[1]
                buf_cache[row] = line
            end
        end

        -- Handle OOB results from \n chars and zero length lines
        res_cols[idx] = math.min(res_cols[idx], #line)
    end

    -- These changes only rely on rows/cols, so trim now.
    if res[1] and cursor then
        trim_upward_res(cursor, res)
    end

    -- Fold handling only relies on start rows and proper count adjustment
    clear_fold_rows(res, opts)

    len_res = res[2] -- Update after potentially compacting changes above.
    local res_fin_rows = res[6]
    local res_fin_cols = res[7]

    for i = 1, len_res do
        local idx = res_idxs[i]
        -- Handle |zero-width| results
        if res_rows[idx] == res_fin_rows[idx] and res_fin_cols[idx] < res_cols[idx] then
            res_fin_cols[idx] = res_cols[idx]
        end

        -- So that string.byte doesn't return invalid results
        res_fin_cols[idx] = math.max(res_fin_cols[idx], 1) -- Don't make end-exclusive yet
    end

    local get_utf_codepoint = require("farsight._util_char")._get_utf_codepoint

    for i = 1, len_res do
        local idx = res_idxs[i]
        local fin_row = res_fin_rows[idx]
        if fin_row ~= last_row then
            last_row = fin_row
            line = buf_cache[fin_row]
            if not line then
                line = api.nvim_buf_get_lines(buf, fin_row - 1, fin_row, false)[1]
                buf_cache[fin_row] = line
            end
        end

        local len_line = #line
        if len_line > 0 then
            local fin_col = math.min(res_fin_cols[idx], len_line)
            local b1 = string.byte(line, fin_col)
            local _, len_char = get_utf_codepoint(line, b1, fin_col)
            res_fin_cols[idx] = fin_col + len_char -- Make end-exclusive
        else
            res_fin_cols[idx] = 2 -- Will be adjusted down to 1
        end
    end
end
--
-- MID: The double cache iteration feels like a lot, but I'm not sure how to get around the
-- path dependency of what needs to be fixed.

---@param err string
---@param win integer
---@param pattern string
---@param res farsight.common.SearchResults
local function fmt_res_err(err, win, pattern, res)
    local err_tbl = {}

    err_tbl[#err_tbl + 1] = err .. ": "
    err_tbl[#err_tbl + 1] = "Win: " .. win
    err_tbl[#err_tbl + 1] = ", Upward?: " .. tostring(res[1])
    err_tbl[#err_tbl + 1] = ", Pattern: " .. pattern
    err_tbl[#err_tbl + 1] = ", Total length: " .. res[2]
    err_tbl[#err_tbl + 1] = ", Indexes: " .. #res[3]
    err_tbl[#err_tbl + 1] = ", #Start rows: " .. #res[4]
    err_tbl[#err_tbl + 1] = ", #Start cols: " .. #res[5]
    err_tbl[#err_tbl + 1] = ", #Fin Rows: " .. #res[6]
    err_tbl[#err_tbl + 1] = ", #Fin Cols: " .. #res[7]

    return table.concat(err_tbl, "")
end

---@param win integer
---@param buf integer
---@return integer, boolean
local function get_checked_wrap_fill_and_valid(win, buf)
    local wS = vim.call("line", "w$") ---@type integer
    if api.nvim_get_option_value("wrap", { win = win }) then
        if wS < api.nvim_buf_line_count(buf) then
            local fill_row = wS + 1
            if vim.call("screenpos", win, fill_row, 1).row >= 1 then
                return fill_row, false
            end
        end
    end

    return wS, true
end

---Edits res in place
---@param win integer
---@param buf integer
---@param cursor [integer, integer, integer, integer, integer]
---@param opts farsight.common.SearchOpts
---@return integer, boolean
local function get_stop_row_and_valid(win, buf, cursor, opts)
    if opts[3] < 0 then
        -- The fill line does not need to be checked here because the cursor can never be in it.
        return cursor[2], true
    end

    return get_checked_wrap_fill_and_valid(win, buf)
end
--
-- MID: It would be better if nvim_buf_line_count were not ephemeral.

---Edits res and cache in place
---@param buf integer
---@param res farsight.common.SearchResults 1 indexed, inclusive
---@param cache table<integer, table<integer, string>>
local function fix_jit_search_res(buf, res, cache)
    local len_res = res[2]
    local res_idxs = res[3]
    local res_rows = res[4]
    local res_fin_rows = res[6]

    -- Convert search_match_lines to end rows
    for i = 1, len_res do
        local idx = res_idxs[i]
        res_fin_rows[idx] = res_rows[idx] + res_fin_rows[idx]
    end

    local buf_cache = cache[buf]
    local line_count = api.nvim_buf_line_count(buf)
    local res_fin_cols = res[8]

    local line

    -- For searches ending in "\n", search_match_lines will be at least 1. If this kind of result
    -- is on the last line, this puts the fin_row OOB.
    for i = len_res, 1, -1 do
        local idx = res_idxs[i]
        local fin_row = res_fin_rows[idx]
        if fin_row <= line_count then
            break
        end

        res_fin_rows[idx] = line_count
        if not line then
            line = api.nvim_buf_get_lines(buf, line_count - 1, line_count, false)[1]
            buf_cache[line_count] = line
        end

        res_fin_cols[idx] = #line
    end
end

---Edits res and cache in place
---If win is not the current window, must be run with nvim_win_call
---Does not handle folds because it would be prohibitively difficult with PUC Lua searching.
---@param win integer WinID
---@param buf integer BufID
---@param pattern string
---@param cursor [integer, integer, integer, integer, integer]
---@param res farsight.common.SearchResults
---@param cache table<integer, table<integer, string>>
---@param opts farsight.common.SearchOpts See class definition.
---@return boolean, boolean, string|nil, string|nil
local function perform_search_jit(win, buf, pattern, cursor, res, cache, opts)
    local stop_row, valid = get_stop_row_and_valid(win, buf, cursor, opts)
    local count1 = (opts[4] and not res[1]) and vim.v.count1 or 1
    if opts[3] <= 0 then
        -- Use the vimfn because nvim_win_set_cursor updates the view and stages a redraw
        vim.call("cursor", vim.call("line", "w0"), 1, 0)
    end

    local res_idxs = res[3]
    local res_rows = res[4]
    local res_cols = res[5]
    local res_fin_rows = res[6]
    local res_fin_cols = res[7]
    local ffi_c = require("ffi").C

    local ok, err = pcall(vim.call, "search", pattern, "nWz", stop_row, opts[5], function()
        if count1 <= 1 then
            res_rows[#res_rows + 1] = vim.call("line", ".")
            res_cols[#res_cols + 1] = vim.call("col", ".")
            res_fin_rows[#res_fin_rows + 1] = ffi_c.search_match_lines --[[ @as integer ]]
            res_fin_cols[#res_fin_cols + 1] = ffi_c.search_match_endcol --[[ @as integer ]]

            local new_res_len = res[2] + 1
            res[2] = new_res_len
            res_idxs[#res_idxs + 1] = new_res_len
            return 1
        else
            count1 = count1 - 1
            return 1
        end
    end)

    if opts[3] <= 0 then
        vim.call("cursor", { cursor[2], cursor[3], cursor[4], cursor[5] })
    end

    if ok then
        fix_jit_search_res(buf, res, cache)
        return ok, valid, nil, nil
    else
        local err_str = fmt_res_err(err, win, pattern, res)
        return ok, valid, err_str, "ErrorMsg"
    end
end
--
-- LOW: For handling count, I'd hope that branch prediction kicks in once it's <= 1. Could try
-- profiling checked vs. not checked.

---Edits res and cache in place
---If win is not the current window, must be run with nvim_win_call
---Does not handle folds because it would be prohibitively difficult with PUC Lua searching.
---@param win integer WinID
---@param buf integer BufID
---@param pattern string
---@param cursor [integer, integer, integer, integer, integer]
---@param res farsight.common.SearchResults
---@param _ table<integer, table<integer, string>>
---@param opts farsight.common.SearchOpts See class definition.
---@return boolean, boolean, string|nil, string|nil
local function perform_search_puc(win, buf, pattern, cursor, res, _, opts)
    local stop_row, valid = get_stop_row_and_valid(win, buf, cursor, opts)
    local base_count = (opts[4] and not res[1]) and vim.v.count1 or 1
    local count1 = base_count
    if opts[3] <= 0 then
        -- Use the vimfn because nvim_win_set_cursor updates the view and stages a redraw
        vim.call("cursor", vim.call("line", "w0"), 1, 0)
    end

    local res_idxs = res[3]
    local res_rows = res[4]
    local res_cols = res[5]

    local ok_s, err = pcall(vim.call, "search", pattern, "nWz", stop_row, opts[5], function()
        if count1 <= 1 then
            res_rows[#res_rows + 1] = vim.call("line", ".")
            res_cols[#res_cols + 1] = vim.call("col", ".")

            local new_res_len = res[2] + 1
            res[2] = new_res_len
            res_idxs[#res_idxs + 1] = new_res_len
            return 1
        else
            count1 = count1 - 1
            return 1
        end
    end)

    if not ok_s then
        if opts[3] <= 0 then
            vim.call("cursor", { cursor[2], cursor[3], cursor[4], cursor[5] })
        end

        return ok_s, valid, err, "ErrorMsg"
    end

    local res_fin_rows = res[6]
    local res_fin_cols = res[7]

    count1 = base_count
    local ok_f, _ = pcall(vim.call, "search", pattern, "nWze", stop_row, opts[5], function()
        if count1 <= 1 then
            res_fin_rows[#res_fin_rows + 1] = vim.call("line", ".")
            res_fin_cols[#res_fin_cols + 1] = vim.call("col", ".")
            return 1
        else
            count1 = count1 - 1
            return 1
        end
    end)

    if opts[3] <= 0 then
        vim.call("cursor", { cursor[2], cursor[3], cursor[4], cursor[5] })
    end

    if ok_f then
        local len_res = res[2]
        -- Verify both loops captured the same number of results.
        local count_res = #res
        for i = 3, count_res do
            if #res[i] ~= len_res then
                local err_str = "Result lengths do not match after search"
                local err_msg = fmt_res_err(err_str, win, pattern, res)
                return false, valid, err_msg, "ErrorMsg"
            end
        end
    end

    return ok_f, valid, nil, nil
end
--
-- MID: This function is too long.

local perform_search = (function()
    if has_ffi_search_globals() then
        return perform_search_jit
    else
        return perform_search_puc
    end
end)()

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

---@param opts farsight.common.SearchOpts See class definition.
---@return farsight.common.SearchResults
local function create_empty_results(opts)
    local size = opts[1]
    local tn = require("farsight.util")._table_new
    ---@type farsight.common.SearchResults
    local hl_info = {
        opts[6],
        0,
        tn(size, 0),
        tn(size, 0),
        tn(size, 0),
        tn(size, 0),
        tn(size, 0),
    }

    return hl_info
end

---Edits cache in place
---@param win integer WinID
---@param pattern string
---@param cache table<integer, table<integer, string>>
---@param opts farsight.common.SearchOpts See class definition.
---@return boolean, boolean, farsight.common.SearchResults|string, string|nil
local function search_win(win, cur_win, pattern, cache, opts)
    local buf = api.nvim_win_get_buf(win)

    local cursor = vim.call("getcurpos", win)
    local res = create_empty_results(opts)
    ---@type boolean, boolean, string|nil, string|nil
    local ok_s, valid, err, err_hl = win_call_others(win, cur_win, function()
        return perform_search(win, buf, pattern, cursor, res, cache, opts)
    end)

    if not ok_s then
        local err_msg = err or ("Error searching win " .. 1000)
        return ok_s, valid, err_msg, err_hl
    end

    if res[2] == 0 then
        return ok_s, valid, res, nil
    end

    adjust_res_values(buf, res, cache, cursor, opts)
    set_api_indexes(res)

    return true, valid, res, nil
end

---ok == false should only be returned for invalid results. Potentially undesirable, but valid,
---results need to be handled gracefully here and dealt with by callers. This mostly applies for
---an empty pattern or empty results. The user entering an empty pattern or the buffer not
---containing the result are both valid behavior.
---
---The hash key for the second result is the WinID.
---
---The third result is cached string lines gathered by this function. The outer table key is the
---buffer ID. The inner table key is the one-indexed line number.
---@param pattern string
---@param opts farsight.common.SearchOpts See class definition.
---@return boolean
---@return table<integer, boolean>
---@return table<integer, farsight.common.SearchResults>|string
---@return table<integer, table<integer, string>>|string
function M.search(pattern, opts)
    local win_res = {} ---@type table<integer, farsight.common.SearchResults>
    local cache = {} ---@type table<integer, table<integer, string>>
    if pattern == "" then
        -- TODO: Should compute redraw valid somehow
        return true, {}, win_res, cache
    end

    local cur_win = api.nvim_get_current_win()
    local win_valid = {} ---@type table<integer, boolean>

    local wins = opts[7]
    local len_wins = #wins
    for i = 1, len_wins do
        local win = wins[i]
        local ok_w, valid, res, err_hl = search_win(win, cur_win, pattern, cache, opts)
        win_valid[win] = valid
        if ok_w and type(res) == "table" then
            win_res[win] = res
        else
            -- TODO: Another issue where incomplete valid status can be returned
            return false, win_valid, res, err_hl or "ErrorMsg"
        end
    end

    return true, win_valid, win_res, cache
end
--
-- LOW: Ticky tack optimization - Pass current win as a param
--
-- MAYBE: How would wrapscan searches be checked? Should it be implicit based on the option, or
-- would we need to check it explicitly for the purposes of other bookkeeping?
-- MAYBE: Because we always search forward, how would backward wrap scan searches be performed?

---@param wins integer[]
---@return table<integer, boolean>
function M.get_win_valid(wins)
    local win_valid = {} ---@type table<integer, boolean>
    return win_valid
end

return M

-- TODO: Because the calling module needs a complete picture of redraw state on its terms, that
-- logic needs to be parted out so it can be used as the callers wish. Because redraw valid is
-- coupled with with stop row, callers also need to own that. This also means that callers need
-- to own the cursor state. Because this module owns the search system, and that system must be
-- able to accomodate multiple windows, this means the data must be hashed. Unless we do a
-- search single win function, which I am not necessarily against, as it would save perf. Getting
-- vimfn returns multiple times is the wrong/slowest choice regardless.
-- TODO: Dimming should be shared logic across all three modules
-- TODO: Folding and counts are not working the way I'd think they would. Hidden fold results are
-- being considered as part of the count. Fine if I was just mis-understanding, but need to be
-- sure.
-- TODO: Use the index row on the list
-- TODO: Need to look at how to handle overlapping results, for multi-line searches and single-line
-- searches if cpo-c is off. For search highlighting you can merge the extmarks, but for labeling
-- I'm less sure what to do. I don't think you can have results with overlapping starts, as they
-- are incremented. But you can have results with overlapping ends if you don't start from the end
-- of the last search.
--
-- MID: If search results return with an error, the valid value is lost. Redrawing with
-- valid = false on error is not a showstopper, but is sub-optimal.
--
-- MAYBE: A specific flag to reject blank lines or all-whitespace lines. This would be most
-- relevant when dealing with multi-line results, as the end of a result might be on a blank line.
-- I guess you'd have to look for results on a blank line, and either move the start/end points to
-- non-blanks or just remove them. But that risks creating overlapping results. This feels
-- secretly complicated and should be avoided without a concrete use case.
