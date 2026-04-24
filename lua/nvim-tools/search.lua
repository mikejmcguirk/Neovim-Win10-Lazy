local api = vim.api
local fn = vim.fn

local M = {}

---@param buf integer
---@param pattern string
---@param range_4 Range4
---@param opts nvim-tools.search.AreaOpts
---@return nvim-tools.Results
local function run_match_area(buf, pattern, range_4, opts)
    local results = require("nvim-tools.results").new(opts.alloc_size)
    local max_results = opts.max_results
    if max_results < 1 then
        return results
    end

    local regex = vim.regex(pattern)

    local active_idxs = results.active_idxs
    local next_idx = results.next_idx
    local start_rows = results.start_rows
    local start_cols = results.start_cols
    local fin_rows = results.fin_rows
    local fin_cols = results.fin_cols

    local i = range_4[1]
    local init_col = range_4[2]
    local last_row = range_4[3]
    local last_col = range_4[4]
    local stop_col = i == last_row and last_col or nil

    local count1 = opts.count
    local total_results = 0
    local at_max_results = false
    while i <= last_row and not at_max_results do
        while true and not at_max_results do
            local start, fin
            if not stop_col then
                start, fin = regex.match_line(regex, buf, i, init_col)
            else
                start, fin = regex.match_line(regex, buf, i, init_col, stop_col)
            end

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

            init_col = fin_col
        end

        i = i + 1
        init_col = 0
        stop_col = i == last_row and last_col or nil
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

local function run_search_single(win, pattern, curpos, flags, opts)
    local old_cursor = fn.getcurpos()
    fn.cursor({ curpos[2], curpos[3], curpos[4], curpos[5] })

    local count = opts.count
    local matches = 0
    local row = 0
    local col = 0

    fn.search(pattern, flags, 0, opts.timeout, function()
        local cur_pos = api.nvim_win_get_cursor(win)
        row = cur_pos[1]
        col = cur_pos[2]
        col = col + 1
        matches = matches + 1
        if matches >= count then
            return 0
        else
            return 1
        end
    end)
    fn.cursor({ old_cursor[2], old_cursor[3], old_cursor[4], old_cursor[5] })
end
-- TODO: We do need a way to handle like at least one vs not in order to address csearch +
-- bracket nav. On the other hand, flags should just be passed in literally, probably. But on
-- the other hand we can't allow jumping so iunno. The thing I really want is to wrap the
-- counting code.

---@param win integer
---@param pattern string
---@param upward boolean
---@param opts nvim-tools.search.SingleOpts
local function search_single(win, pattern, upward, curpos, opts)
    local _ = pattern
    local _ = opts

    local cur_win = api.nvim_get_current_win()
    local flags = upward and "bws" or "zws"
    local row, col = require("nvim-tools.win").call_in(cur_win, win, function()
        return run_search_single(curpos, flags)
    end)
end
-- TODO: For count, if looking for at least one, store the cursor result on every hit, but only
-- exit the search function when count is hit. Use temp ints or the same table.

---@param buf integer
---@param curpos [integer, integer, integer, integer, integer]
---@param cache table<integer, string> Edited in place
---@param range -2|-1|0|nil|1|2|Range4
---@return Range4 1,1,1,1 indexed, end inclusive
local function resolve_search_range(buf, curpos, cache, range)
    if type(range) == "table" then
        return range
    end

    local range_4 = { 0, 0, 0, 0 }

    if range <= 0 or range == nil then
        range_4[1] = (range == -2 or range == nil) and 1 or (fn.line("w0"))
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
            row = fn.line("w$")
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

---@class nvim-tools.search.CommonOpts
---At which occurrence should results begin to be collected? count 0 or count 1 will start
---from the first result. count 2 will start from the second result, and so on. Useful if you
---want to use search to find a jump location, but jump to [count] occurrence.
---Note that this can mean, if for example, count 2 is specified but there is only one result, that
---no results return.
---@field count? integer
---Use a pre-existing cursor position
---@field cursor? [integer, integer, integer, integer, integer]
---Filter applied to the pattern.
---TODO: Document examples of forcing case or forcing fixed strings
---@field pattern_filter? fun(pattern:string): filtered_pattern:string

---@class nvim-tools.search.AreaOpts : nvim-tools.search.CommonOpts
---For LuaJIT builds, set the default size of table.new in the results lists.
---(default: `16`)
---@field alloc_size? integer
---@field max_results? integer

---@param opts nvim-tools.search.CommonOpts
local function resolve_common_search_opts(opts)
    local _ = opts
end
-- NON: Handling v:count1. The caller should pass that if it wants to.

---@param opts nvim-tools.search.SingleOpts
local function resolve_single_search_opts(opts)
    local _ = opts
    resolve_common_search_opts(opts)
end

---@param opts nvim-tools.search.AreaOpts
local function resolve_area_search_opts(opts)
    opts.alloc_size = opts.alloc_size or 16
    opts.count = opts.count or 1
    opts.max_results = opts.max_results or math.huge
    resolve_common_search_opts(opts)
end
-- TODO: Move common opts to common opts
-- TODO: Do actual validation in here

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
    vim.validate("dir", range, function()
        return (nty.is_int(range) and range >= -2 or range <= 2)
            or nty.valid_list(range, { item_type = "number", len = 4 })
    end, true)

    opts = opts or {}
    resolve_area_search_opts(opts)

    if opts.pattern_filter then
        pattern = opts.pattern_filter(pattern)
    end

    local curpos = opts.cursor or fn.getcurpos(win)
    local buf = api.nvim_win_get_buf(win)
    local cache = {} ---@type table<integer, string>

    local range_4 = resolve_search_range(buf, curpos, cache, range)
    require("nvim-tools.range").eval_to_ts(range_4, buf)
    local results = run_match_area(buf, pattern, range_4, opts)

    return results, cache
end
-- TODO: Take cache as an opt since you might multi-win search using the same buffer

---@class nvim-tools.search.SingleOpts : nvim-tools.search.CommonOpts
---If the search expires before reaching `count`, return the last result.
---(default: `false`)
---@field min_one? boolean
---In ms.
---(default: `500`)
---@field timeout? integer
---(default: `false`)
---@field upward? boolean
---(default: `false`)
---@field wrapscan? boolean

---@param win integer
---@param pattern string
---@param opts nvim-tools.search.SingleOpts
---@return integer row, integer col 1,1 indexed, inclusive
function M.search_single(win, pattern, opts)
    local nty = require("nvim-tools.types")
    vim.validate("win", win, nty.is_uint)
    vim.validate("pattern", pattern, "string")
    vim.validate("opts", opts, "table", true)

    opts = opts or {}

    resolve_single_search_opts(opts)
    local curpos = opts.cursor or fn.getcurpos(win)
    search_single(pattern, opts)

    return 1, 1
end
-- NON: This function should not jump itself or set a pcmark, since that makes it less useful to
-- any calling code. Should only be getting position.

return M
