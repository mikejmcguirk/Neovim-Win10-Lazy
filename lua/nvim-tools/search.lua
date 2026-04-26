local api = vim.api
local fn = vim.fn

local M = {}

-- Based on profiling while developing Farsight, the fastest method for searching text is actually
-- pure Lua. But this comes with caveats:
-- - Some non-trivial amount of the time savings likely comes from simply not having to cross the
-- C/Lua bridge.
-- - string.byte needs to be used where possible to save allocations.
-- - For any particular search case, you need to write code that is specifically optimized for it.
-- - This requires making bespoke recreations of subsets of Neovim's text parsing, including
-- UTF-8 codepoint conversion.
-- - This is costly to maintain, adds points of failure, and is inflexible.
--
-- Therefore, except as a learning experience, the Lua method is best avoided.
--
-- search(), surprisingly, is slow. My guess is that this comes from the cost of continuously
-- passing the callback in and out of Lua space (both because of the inherent cost of doing so as
-- well as re-marshalling the arguments each time). Running virtually no code inside the callback
-- does little to take down the overall time it takes to run.
--
-- regex:match_string and the various match eval functions do okay. I have not compared them with
-- search() directly, but my memory is that they are comparable or a bit faster. Both methods
-- are slowed down though due to allocations. The match evals must do argument marshalling.
--
-- This leaves us with match_line. While the bridge tax still applies, only numbers are passed
-- across. Because it is a direct access to Neovim's regex engine, there is no marshalling.
-- Of Neovim's built-in methods, this is the fastest I've seen. The tradeoff of only being able
-- to search one line at a time is more than acceptable.

---@param buf integer
---@param pattern string
---@param range_4 Range4 0,0,0,0 indexed, end exclusive
---@param opts nvim-tools.search.AreaOpts
---@return nvim-tools.Results
local function match_area_run(buf, pattern, range_4, opts)
    local results = require("nvim-tools.results").new(opts.alloc_size or 16)
    local active_idxs, _, next_idx = results:get_active_idx_info()
    local start_rows, start_cols, fin_rows, fin_cols = results:get_both_pos()

    local i_row = range_4[1]
    local last_row = range_4[3]

    local lines = api.nvim_buf_get_lines(buf, i_row, last_row + 1, false)
    local i_line = 1
    local line = lines[i_line]
    local last_col_ = range_4[4]
    -- To avoid guard code in the loop, last_col_ should already be clamped at 0 if #line is 0
    local stop_col_ = i_row == last_row and last_col_ or #line

    local regex = vim.regex(pattern)
    local init = range_4[2]
    while true do
        -- Typically, regex:match_line({buf}, {lnum}, #line, #line) returns nil, nil
        -- However, |/zero-width| expressions return 0,0
        -- Therefore, the manual init advance on those results needs to be checked.
        -- This also prevents any OOB start_cols and skips any zero length lines.
        while init < stop_col_ do
            local start, fin = regex.match_line(regex, buf, i_row, init, stop_col_)
            if not (start and fin) then
                break
            end

            local start_col = init + start
            local fin_col_ = init + fin

            -- Don't force the user to allocate heap to check line lengths again.
            if start_col < stop_col_ then
                start_rows[next_idx] = i_row
                start_cols[next_idx] = start_col
                fin_rows[next_idx] = i_row
                fin_cols[next_idx] = fin_col_
                active_idxs[next_idx] = next_idx
                next_idx = next_idx + 1
            end

            -- Handle |/zero-width| expressions
            init = math.max(fin_col_, start_col + 1)
        end

        i_row = i_row + 1
        if i_row > last_row then
            break
        end

        i_line = i_line + 1
        line = lines[i_line]
        stop_col_ = i_row == last_row and last_col_ or #line
        init = 0
    end

    results.next_idx = next_idx
    return results
end

---@param win integer
---@param buf integer
---Range4 is 1,1,1,1 indexed, end inclusive
---@param range -2|-1|0|nil|1|2|Range4
---@param opts nvim-tools.search.AreaOpts
---@return Range4 1,1,1,1 indexed, end inclusive
local function match_area_resolve_range(win, buf, range, opts)
    if type(range) == "table" then
        -- Do all this now so the matching can proceed without error checking.
        local nty = require("nvim-tools.types")
        nty.valid_list(range, { item_type = "number", len = 4 })

        local line_count = api.nvim_buf_line_count(buf)
        range[1] = math.min(math.max(range[1], 1), line_count)
        range[3] = math.min(math.max(range[3], 1), line_count)

        local sr = range[1]
        local fr = range[3]
        assert(sr <= fr, "Start row " .. sr .. " > fin row " .. fr)

        local start_line = api.nvim_buf_get_lines(buf, sr - 1, sr, false)[1]
        range[2] = math.min(math.max(range[2], #start_line), 1)
        local fin_line = api.nvim_buf_get_lines(buf, fr - 1, fr, false)[1]
        range[4] = math.min(math.max(range[4], #fin_line), 1)

        return range
    end

    local curpos = opts.curpos or fn.getcurpos(win)
    local range_4 = { 0, 0, 0, 0 }

    if range <= 0 or range == nil then
        range_4[1] = (range == -2 or range == nil) and 1 or vim.call("line", "w0", win)
        range_4[2] = 1
    else
        range_4[1] = curpos[2]
        range_4[2] = curpos[3]
    end

    if range >= 0 or range == nil then
        local row
        if range == 2 or range == nil then
            row = api.nvim_buf_line_count(buf)
        else
            row = vim.call("line", "w$", win) ---@type integer
        end

        range_4[3] = row

        local line = api.nvim_buf_get_lines(buf, row - 1, row, false)[1]
        range_4[4] = #line
    else
        range_4[3] = curpos[2]
        range_4[4] = curpos[3]
    end

    return range_4
end

---@class nvim-tools.search.CommonOpts
---Use a pre-existing cursor position. See |getcurpos()|
---@field curpos? [integer, integer, integer, integer, integer]
---Filter applied to the pattern.
---@field pattern_filter? fun(pattern:string): filtered_pattern:string

---@class nvim-tools.search.AreaOpts : nvim-tools.search.CommonOpts
---For LuaJIT builds, set the default size of table.new in the results lists.
---(default: `16`)
---@field alloc_size? integer
---(default: `math.huge`)
---@field max_results? integer

---Runs |regex:match_line()| over a range of lines.
---@param win integer The |window-ID| to search within
---@param pattern string Vim |regexp|
---Area to search:
---- -2: Upward from the cursor to the beginning of the buffer
---- -1: Upward from the cursor to the top of the visible buffer
---- 0: Visible buffer area
---- nil: Entire buffer
---- 1: Downward from the cursor to the bottom of the visible buffer
---- 2: Downward from the cursor to the end of the buffer
---- Range4: 1,1,1,1 indexed, end inclusive range to search
---@param range -2|-1|0|nil|1|2|Range4
---@param opts nvim-tools.search.AreaOpts
---@return nvim-tools.Results results 0,0,0,0 indexed, exclusive end
function M.match_area(win, pattern, range, opts)
    local nty = require("nvim-tools.types")
    vim.validate("win", win, nty.is_uint)
    vim.validate("pattern", pattern, "string")
    vim.validate("opts", opts, "table", true)
    vim.validate("range", range, function()
        return (nty.is_int(range) and range >= -2 or range <= 2)
            or nty.valid_list(range, { item_type = "number", len = 4 })
    end, true)

    win = win == 0 and api.nvim_get_current_win() or win
    opts = opts or {}
    if opts.pattern_filter then
        pattern = opts.pattern_filter(pattern)
    end

    local buf = api.nvim_win_get_buf(win)

    local range_4 = match_area_resolve_range(win, buf, range, opts)
    require("nvim-tools.range").eval_to_ts(range_4, buf)
    local results = match_area_run(buf, pattern, range_4, opts)

    return results
end

---@param win integer
---@param pattern string
---@param flags string
---@param opts nvim-tools.search.SingleOpts
---@return integer, integer
local function search_single_run(win, pattern, flags, opts)
    local old_cursor
    local curpos = opts.curpos
    if curpos then
        old_cursor = fn.getcurpos()
        fn.cursor({ curpos[2], curpos[3], curpos[4], curpos[5] })
    end

    local count = opts.count or 1
    local matches = 0
    local row = 0
    local col = 0

    fn.search(pattern, flags, 0, opts.timeout or 500, function()
        local cur_pos = api.nvim_win_get_cursor(win)
        row = cur_pos[1]
        col = cur_pos[2] + 1

        matches = matches + 1
        if matches >= count then
            return 0
        else
            return 1
        end
    end)

    if old_cursor then
        fn.cursor({ old_cursor[2], old_cursor[3], old_cursor[4], old_cursor[5] })
    end

    if (not opts.min_one) and matches < count then
        return 0, 0
    end

    return row, col
end

---@param win integer
---@param pattern string
---@param upward boolean
---@param opts nvim-tools.search.SingleOpts
---@return integer, integer
local function search_single_setup(win, pattern, upward, opts)
    local flags_tbl = { "n" }
    flags_tbl[#flags_tbl] = opts.wrapscan and "w" or "W"
    flags_tbl[#flags_tbl] = upward and "b" or "z"
    local flags = table.concat(flags_tbl)

    local cur_win = api.nvim_get_current_win()
    local row, col = require("nvim-tools.win").call_in(cur_win, win, function()
        return search_single_run(win, pattern, flags, opts)
    end)

    return row, col
end
-- The 'c' flag is not supported because, when searching backward, the search can get stuck.
-- The 'e' flag is not supported because I have seen it produce unexpected behavior.
-- Wrapscan is always set to avoid conflicting sources of truth with the opt.

---@class nvim-tools.search.SingleOpts : nvim-tools.search.CommonOpts
---Begin collecting results at [count] matches..
---(default: `1`)
---@field count? integer
---If the search expires before reaching `count`, return the last result.
---Example: Neovim's default bracket navigation will return the best available result if count
---is larger than the available results. (Leaving this behavior disabled mimics csearch, which
---will simply no-op)
---(default: `false`)
---@field min_one? boolean
---In ms.
---(default: `500`)
---@field timeout? integer
---Sets the `w` flag in the search. Otherwise `W` is used.
---(default: `false`)
---@field wrapscan? boolean

---Perform a |search()| for a |pattern| with a count.
---Flags are controlled within the function opts. The `wrapscan` opt is overridden.
---
---@param win integer Context |window_ID|
---@param pattern string See |pattern|
---@param upward boolean If true, the `b` search flag will be used instead of `z`.
---@param opts nvim-tools.search.SingleOpts
---@return integer row, integer col 1,1 indexed, inclusive. 0,0 if no result.
function M.search_single(win, pattern, upward, opts)
    local nty = require("nvim-tools.types")
    vim.validate("win", win, nty.is_uint)
    vim.validate("pattern", pattern, "string")
    vim.validate("upward", upward, "boolean")
    vim.validate("opts", opts, "table", true)

    opts = opts or {}
    local pattern_filter = opts.pattern_filter
    if pattern_filter then
        pattern = pattern_filter(pattern)
    end

    return search_single_setup(win, pattern, upward, opts)
end

return M
