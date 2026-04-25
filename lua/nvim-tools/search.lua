local api = vim.api
local fn = vim.fn

local M = {}

-- Based on my experience developing Farsight, the fastest method for searching text is actually
-- pure Lua, even though its string parsing is slower. My guess is that this is because of
-- not having to pay the tax of crossing the Lua/C bridge. It also helps if string.byte is used
-- where possible, because that avoids new allocations.
--
-- That method has two problems though:
-- - It is less flexible. For any particular search you want to do, you have to work out the Lua
-- code to do so most optimally.
-- - You are stuck with the time and complication cost of writing bespoke versions of Neovim's
-- regex parsing.
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
local function run_match_area(buf, pattern, range_4, opts)
    local size = opts.alloc_size or 16
    local results = require("nvim-tools.results").new(size)
    local max_results = opts.max_results or math.huge
    if max_results < 1 then
        return results
    end

    local regex = vim.regex(pattern)

    local active_idxs = results.active_idxs
    local next_idx = results.next_idx
    local start_rows, start_cols, fin_rows, fin_cols = results:get_both_pos()

    local i = range_4[1]
    local init_col = range_4[2]
    local last_row = range_4[3]
    local last_col = range_4[4]
    local line = api.nvim_buf_get_lines(buf, i, i + 1, false)[1]
    local stop_col = #line
    if i == last_row then
        -- Stop col needs to be end exclusive so you can get a match if it's a one char
        -- search at the very end of the line
        stop_col = math.min(last_col + 1, #line - 1)
    end

    local count1 = opts.count or 1
    local total_results = 0
    local at_max_results = false
    while i <= last_row and not at_max_results do
        while true and not at_max_results do
            -- TODO: sloppy
            if init_col >= stop_col then
                break
            end

            local start, fin = regex.match_line(regex, buf, i, init_col, stop_col)
            if not (start and fin) then
                break
            end

            local start_col = init_col + start
            local fin_col = init_col + fin
            if count1 <= 1 then
                start_rows[next_idx] = i
                start_cols[next_idx] = start_col
                fin_rows[next_idx] = i
                fin_cols[next_idx] = fin_col
                active_idxs[next_idx] = next_idx
                next_idx = next_idx + 1

                total_results = total_results + 1
                at_max_results = total_results >= max_results
            else
                count1 = count1 - 1
            end

            -- Needed to handle zero-width expressions
            init_col = math.max(fin_col, init_col + 1)
        end

        i = i + 1
        -- TODO: Sloppy
        if i > last_row then
            break
        end

        init_col = 0
        -- TODO: Get these in bulk once
        line = api.nvim_buf_get_lines(buf, i, i + 1, false)[1]
        stop_col = #line - 1
        if i == last_row then
            stop_col = math.min(last_col, #line - 1)
        end
    end

    results.next_idx = next_idx
    return results
end
-- LOW: The stop_col and count1 checks on every iteration are not great since they only happen on
-- specific subsets of the search. max_results also does not necessarily matter, but is always
-- checked. I'm not sure if LuaJIT has smart enough branch prediction to handle this. The amount of
-- data being handled does not break up into sub-functions well.
-- PR: It would be beneficial if:
-- (a) regex:match_line could clamp arbitrarily large stop_col values
-- (b) It were possible to get the length of a line without pulling heap into Lua space

---@param win integer
---@param buf integer
---@param cache table<integer, string> Edited in place
---@param range -2|-1|0|nil|1|2|Range4
---@param opts nvim-tools.search.AreaOpts
---@return Range4 1,1,1,1 indexed, end inclusive
local function resolve_search_range(win, buf, cache, range, opts)
    if type(range) == "table" then
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
        cache[row] = line
        range_4[4] = #line
    else
        range_4[3] = curpos[2]
        range_4[4] = curpos[3]
    end

    return range_4
end
-- NOTE: vim.call used here because this function could be called multiple times in a multi-window
-- search.

---@class nvim-tools.search.CommonOpts
---Cache of buffer lines. One indexed
---@field cache? table<integer, string>
---Begin collecting results at [count] matches..
---(default: `1`)
---@field count? integer
---Use a pre-existing cursor position. See |getcurpos()|
---@field curpos? [integer, integer, integer, integer, integer]
---Filter applied to the pattern.
---TODO: Document examples of forcing case or forcing fixed strings
---Part of the blocker here is, can we use docgen to do it as Markdown? I think so.
---@field pattern_filter? fun(pattern:string): filtered_pattern:string

---@class nvim-tools.search.AreaOpts : nvim-tools.search.CommonOpts
---For LuaJIT builds, set the default size of table.new in the results lists.
---(default: `16`)
---@field alloc_size? integer
---(default: `math.huge`)
---@field max_results? integer

---Runs |regex:match_line()| over a range.
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
---@return table<integer, string> cache Lines gathered during search. One indexed rows as keys.
function M.search_area(win, pattern, range, opts)
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
    local cache = opts.cache or {} ---@type table<integer, string>

    local range_4 = resolve_search_range(win, buf, cache, range, opts)
    require("nvim-tools.range").eval_to_ts(range_4, buf)
    local results = run_match_area(buf, pattern, range_4, opts)

    return results, cache
end

---@param win integer
---@param pattern string
---@param flags string
---@param opts nvim-tools.search.SingleOpts
---@return integer, integer
local function run_search_single(win, pattern, flags, opts)
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
-- MID: It's not necessary to get row/col info if not opts.mine_one. I'm not sure how to section
-- off this behavior though without it getting bloated.

---@param win integer
---@param pattern string
---@param upward boolean
---@param opts nvim-tools.search.SingleOpts
---@return integer, integer
local function search_single(win, pattern, upward, opts)
    local flags_tbl = { "n" }
    flags_tbl[#flags_tbl] = opts.wrapscan and "w" or "W"
    flags_tbl[#flags_tbl] = upward and "b" or "z"
    local flags = table.concat(flags_tbl)

    local cur_win = api.nvim_get_current_win()
    local row, col = require("nvim-tools.win").call_in(cur_win, win, function()
        return run_search_single(win, pattern, flags, opts)
    end)

    return row, col
end
-- LOW: The 'c' flag is not supported because, when searching backward, the search can get stuck.
-- It might be helpful to make wrapper code that identifies and works around this.
-- LOW: The 'e' flag is not supported because I have seen it produce unexpected behavior. It would
-- be helpful to test the flag, document the problems, and either write workarounds or allow the
-- flag with documented limitations.

---@class nvim-tools.search.SingleOpts : nvim-tools.search.CommonOpts
---If the search expires before reaching `count`, return the last result.
---(default: `false`)
---@field min_one? boolean
---In ms.
---(default: `500`)
---@field timeout? integer
---(default: `false`)
---@field wrapscan? boolean

-- TODO: These opts are a good docgen thing. On one hand, it makes sense to do these as inlinedoc.
-- But then do you repeat the CommonOpts each time?

---@param win integer
---@param pattern string
---@param upward boolean
---@param opts nvim-tools.search.SingleOpts
---1,1 indexed, inclusive. 0,0 if no result.
---@return integer row, integer col
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

    return search_single(win, pattern, upward, opts)
end

return M
