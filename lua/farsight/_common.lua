local api = vim.api
local fn = vim.fn

---@class farsight.common.SearchResults
---@field [1] boolean Upward? True if going up from cursor
---@field [2] boolean Valid? Flag for nvim__redraw
---@field [3] integer Results length
---@field [4] integer[] Start rows (0 based, inclusive)
---@field [5] integer[] Start cols (0 based, inclusive)
---@field [6] integer[] Fin rows (0 based, inclusive)
---@field [7] integer[] Fin cols (0 based, exclusive)

-- MAYBE: Use dir -2/2 for cursor to top of the buffer and 2 for cursor to the bottom of the
-- buffer. A wrapscan search could then be -3/3. Note that redraw valid needs to be checked for
-- any search >= 0.
-- MAYBE: Have an opt for searching line ranges.
---@class farsight.common.SearchOpts
---How many fields to initially allocate in the results lists. Note that Lua tables automatically
---allocate based on powers of 2.
---Default: `32`
---@field alloc_size integer
---`0`: Allow all results in folded lines.
---`1`: Allow only the first result from each folded block.
---`2`: Allow results from the first line of each folded block
---`3`: Reject all folded results.
---Default: `1`
---@field allow_folds integer
---`-1`: From the window to the top of the cursor
---`0`: The entire window
---`1`: From the cursor to the bottom of the window
---Default: `0`.
---@field dir integer
---If true, results will be eliminated based on the value of vim.v.count1.
---Example: If vcount1 == 2, the first result would be rejected, since it would not be used.
---Default: `false`
---@field handle_count boolean
---In ms.
---Default: `500`.
---@field timeout integer
---Should results be interpreted such that the "closest" result is the last result or the first?
---This flag is necessary because, even if dir is -1, searching is always performed forward for
---performance reasons.
---This affects:
---- Count handling. If upward is true, discarded results will be removed from the end of the
---results, rather than being filtered while searching.
---- Fold handling. The internal logic needs to know if upward is true to properly handle
---folded results.
---Default: If dir is negative, `true`. Otherwise `false`.
---@field upward boolean
---Which wins to search.
---Default: Current win.
---@field wins integer[]

-- TODO_DOC: I don't know how much of this is internal vs. user-facing documentation, but - The
-- general attitude toward any Puc Lua compatibility function should be: It should handle typical
-- cases, and effort might be made to support edge cases, but the design of the overal module
-- cannot be compromised to handle it. LuaJIT support/performance takes priority.

local M = {}

local has_ffi, ffi = pcall(require, "ffi")

local did_setup_repeat_tracking = false
local is_repeating = 0 ---@type 0|1

function M.get_is_repeating()
    return is_repeating
end

function M.setup_repeat_tracking()
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

-- MAYBE: If another module uses this info, setup a var so it isn't run twice

function M.has_ffi_search_globals()
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

---Edits res and cache in place
---@param buf integer
---@param res farsight.common.SearchResults 1 indexed, inclusive
---@param cache table<integer, table<integer, string>>
local function fix_jit_search_res(buf, res, cache)
    local len_res = res[3]
    local res_rows = res[4]
    local res_fin_rows = res[6]
    local res_fin_cols = res[7]

    -- Convert search_match_lines to end rows
    for i = 1, len_res do
        res_fin_rows[i] = res_rows[i] + res_fin_rows[i]
    end

    local buf_cache = cache[buf]
    local line_count = api.nvim_buf_line_count(buf)
    local nvim_buf_get_lines = api.nvim_buf_get_lines

    local line

    -- For searches ending in "\n", search_match_lines will be at least 1. If this kind of result
    -- is on the last line, this puts the fin_row OOB.
    for i = len_res, 1, -1 do
        local fin_row = res_fin_rows[i]
        if fin_row <= line_count then
            break
        end

        res_fin_rows[i] = line_count
        if not line then
            line = nvim_buf_get_lines(buf, line_count - 1, line_count, false)[1]
            buf_cache[line_count] = line
        end

        res_fin_cols[i] = #line
    end
end

---Edits res in place
---@param res farsight.common.SearchResults
---@param cursor [integer, integer, integer, integer, integer]
---@param opts farsight.common.SearchOpts
---@return integer
local function get_stop_row_and_valid(win, buf, res, cursor, opts)
    if opts.dir < 0 then
        -- The fill line does not need to be checked here because the cursor can never be in it.
        return cursor[2]
    end

    local stop_row, valid = M.get_checked_stop_row(win, buf, fn.line("w$"))
    res[2] = valid
    return stop_row
end

---Edits res and cache in place
---Does not handle folds because it would be prohibitively difficult with PUC Lua searching.
---@param win integer WinID
---@param buf integer BufID
---@param pattern string
---@param res farsight.common.SearchResults
---@param cache table<integer, table<integer, string>>
---@param opts farsight.common.SearchOpts See class definition.
---@return boolean, string|nil, string|nil
local function perform_search(win, buf, pattern, res, cache, opts)
    local upward = res[1]
    local res_rows = res[4]
    local res_cols = res[5]
    local res_fin_rows = res[6]
    local res_fin_cols = res[7]
    local call = vim.call
    local ffi_c = require("ffi").C

    local cursor = fn.getcurpos(win)
    local stop_row = get_stop_row_and_valid(win, buf, res, cursor, opts)
    local count1 = (opts.handle_count and not upward) and vim.v.count1 or 1
    if opts.dir <= 0 then
        -- Use the vimfn because nvim_win_set_cursor updates the view and stages a redraw
        fn.cursor(fn.line("w0"), 1, 0)
    end

    -- TODO: Outline the actual searching for JIT vs. PUC Lua purposes.
    local ok, err = pcall(call, "search", pattern, "nWz", stop_row, opts.timeout, function()
        if count1 <= 1 then
            res_rows[#res_rows + 1] = call("line", ".")
            res_cols[#res_cols + 1] = call("col", ".")
            res_fin_rows[#res_fin_rows + 1] = ffi_c.search_match_lines --[[ @as integer ]]
            res_fin_cols[#res_fin_cols + 1] = ffi_c.search_match_endcol --[[ @as integer ]]

            res[3] = res[3] + 1
            return 1
        else
            count1 = count1 - 1
            return 1
        end
    end)

    if opts.dir <= 0 then
        fn.cursor({ cursor[2], cursor[3], cursor[4], cursor[5] })
    end

    if ok then
        fix_jit_search_res(buf, res, cache)
        return ok, err, nil
    else
        return ok, err, "ErrorMsg"
    end
end
--
-- TODO: For multi-window searching, the win needs to be checked against the current win, and this
-- needs to be wrapped in win_call if it's not. Do you get cur_win once per win? Or do you pass
-- it in as a variable. Depends on what level of abstraction the multi-window search operates.
-- LOW: For handling count, I'd hope that branch prediction kicks in once it's <= 1. Could try
-- profiling checked vs. not checked.

---@param opts farsight.common.SearchOpts See class definition.
---@return farsight.common.SearchResults
local function create_empty_results(opts)
    local size = opts.alloc_size
    local tn = require("farsight.util")._table_new
    local hl_info = {
        opts.upward,
        true,
        0,
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
---@return boolean, farsight.common.SearchResults, string|nil
local function search_win(win, pattern, cache, opts)
    local buf = api.nvim_win_get_buf(win)

    local res = create_empty_results(opts)
    local ok_s, err, err_hl = perform_search(win, buf, pattern, res, cache, opts)

    -- TODO: Remove this dummy return.
    return true, {}, ""
end

---@param opts farsight.common.SearchOpts See class definition.
local function resolve_search_opts(opts)
    vim.validate("opts", opts, "table")

    opts.alloc_size = opts.alloc_size and opts.alloc_size or 32
    opts.allow_folds = opts.allow_folds and opts.allow_folds or 1
    opts.dir = opts.dir and opts.dir or 1
    opts.timeout = opts.timeout or 500
    opts.wins = opts.wins or { api.nvim_get_current_win() }

    local resolve_bool_opt = require("farsight.util")._resolve_bool_opt
    opts.handle_count = resolve_bool_opt(opts.handle_count, false)
    if opts.upward == nil then
        if opts.dir < 0 then
            opts.upward = true
        else
            opts.upward = false
        end
    end
end

-- TODO: It should be possible to make common tools for merging the search results and getting
-- dim rows. This is easiest for search/jump, because you use all the filtered results.
-- For csearch, you would have to remove unwanted results first I think.

-- For now, focus on making this work for a single window. Then on how to make a multi-win
-- interface for jump.
-- Should line_cache be persisted? For csearch, it would be useful not to have to re-get the lines
-- after they're acquired here.
-- upward should be a separate flag from search region
-- TODO: While the data-types are module/plugin defined, the string pattern can come from user
-- input and must be handled. Empty patterns should be gracefully skipped. Invalid/error patterns
-- need to handle not ok results.

---Because this is an internal function, data is resolved but not validated. Mistakes can cause
---errors and undefined behavior.
---
---ok == false should only be returned for invalid results. Potentially undesirable, but valid,
---results need to be handled gracefully here and dealt with by callers. This mostly applies for
---an empty pattern or empty results. The user entering an empty pattern or the buffer not
---containing the result are both valid behavior.
---
---The hash key for the second result is the WinID.
---
---The third result is cached string lines gathered by this function. The outer table key is the
---buffer ID. The inner table key is the one-indexed line number.
---The returned line cache is one-indexed.
---@param pattern string
---@param opts farsight.common.SearchOpts See class definition.
---@return boolean
---@return table<integer, farsight.common.SearchResults>|string
---@return table<integer, table<integer, string>>|string|nil
function M.search(pattern, opts)
    resolve_search_opts(opts)

    local win_res = {} ---@type table<integer, farsight.common.SearchResults>
    local cache = {} ---@type table<integer, table<integer, string>>
    if pattern == "" then
        return true, win_res, cache
    end

    local wins = opts.wins
    local len_wins = #wins
    for i = 1, len_wins do
        local win = wins[i]
        local ok_w, res, err_hl = search_win(win, pattern, cache, opts)
        if ok_w and type(res) == "table" then
            win_res[win] = res
        else
            return false, res, err_hl
        end
    end

    return true, win_res, cache
end
---
---MAYBE: Pass the result of getcurpos() as a param.
---MAYBE: How would wrapscan searches be checked? Should it be implicit based on the option, or
---would we need to check it explicitly for the purposes of other bookkeeping?
---MAYBE: Because we always search forward, how would backward wrap scan searches be performed?

-- TODO: Use this in all modules
-- TODO: In search, we need nvim_buf_line_count for other purposes, so it needs to be an input
-- param here

---@param win integer
---@param buf integer
---@param wS integer One indexed
---@return integer, boolean Adjusted row (one indexed), redraw valid
function M.get_checked_stop_row(win, buf, wS)
    if api.nvim_get_option_value("wrap", { win = win }) then
        if wS < api.nvim_buf_line_count(buf) then
            local fill_row = wS + 1
            if fn.screenpos(win, fill_row, 1).row >= 1 then
                return fill_row, false
            end
        end
    end

    return wS, true
end
--
--TODO: This should be localized once all the searching logic is moved into here.

return M

-- TODO: This module can be useful for outlining pieces of logic common to csearch, search, and
-- jump. Wait though until all three modules are completed before doing such a conceptual refactor.
-- Ideas:
-- - The backward cursor correction + visual entrance for omode jumps. If/when it's outlined, put
-- a comment talking about how the use of that code assumes that we have already early-exited from
-- invalid backward jumps.
-- TODO: Need to look at how to handle overlapping results, for multi-line searches and single-line
-- searches if cpo-c is off. For search highlighting you can merge the extmarks, but for labeling
-- I'm less sure what to do. I don't think you can have results with overlapping starts, as they
-- are incremented. But you can have results with overlapping ends if you don't start from the end
-- of the last search.
--
-- MAYBE: A specific flag to reject blank lines or all-whitespace lines. This would be most
-- relevant when dealing with multi-line results, as the end of a result might be on a blank line.
-- I guess you'd have to look for results on a blank line, and either move the start/end points to
-- non-blanks or just remove them. But that risks creating overlapping results. This feels
-- secretly complicated and should be avoided without a concrete use case.
