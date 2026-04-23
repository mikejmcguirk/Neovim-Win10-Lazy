local api = vim.api
local fn = vim.fn

local has_ffi_search_globals = (function()
    local has_ffi, ffi = pcall(require, "ffi")
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

    return cdef_ok
end)()

local M = {}

-- TODO: nvim_win_call should be run within the search functions, rather than being a wrapper
-- TODO: The area functions need to explicitly dis-allow wrapscan

---Assumes proper window context
---@param curpos [integer, integer, integer, integer, integer] See |getcurpos()|
---@param range_4 Range4
---@return boolean
local function checked_set_cursor(curpos, range_4)
    local start_row = range_4[1]
    local start_col = range_4[2]
    if start_row ~= curpos[2] or start_col ~= curpos[3] then
        -- Use the vimfn because nvim_win_set_cursor updates the view and stages a redraw
        fn.cursor(start_row, start_col)
        return true
    end

    return false
end

---Assumes proper window context
---@param win integer
---@param pattern string
---@param curpos [integer, integer, integer, integer, integer] See |getcurpos()|
---@param range_4 Range4
---@param results nvim-tools.Results Modified in place
---@param opts nvim-tools.search.AreaOpts
---@return boolean, integer|string|nil, string|nil
local function run_search_area_jit(win, pattern, curpos, range_4, results, opts)
    -- Do this first since it's not relevant to the loop.
    local moved_cursor = checked_set_cursor(curpos, range_4)

    local active_idxs = results.active_idxs
    -- In theory, these should be newly initialized results and it should be possible to add to
    -- active_idxs based on next_idx. But, in the interest of robustness, track separately.
    local len_active_idxs = #active_idxs
    local next_idx = results.next_idx

    local ffi_c = require("ffi").C
    local start_rows = results.start_rows
    local start_cols = results.start_cols
    local fin_rows = results.fin_rows
    local fin_cols = results.fin_cols

    -- TODO: Make sure this is set to 1 in resolve opts
    -- NOTE: Don't handle vcount here. The caller should pass that if it wants that.
    local count1 = opts.count or 1
    local total_results = 0
    -- TODO: This should also be handled in resolve opts
    -- TODO: max_results = 0 shouldn't be invalid but... why would you ever do it?
    local max_results = opts.max_results or math.huge
    local ok, err = pcall(fn.search, pattern, "nWz", range_4[3], opts.timeout, function()
        if count1 <= 1 and total_results < max_results then
            local cur_pos = api.nvim_win_get_cursor(win)
            local row = cur_pos[1]
            start_rows[next_idx] = row
            start_cols[next_idx] = cur_pos[2] + 1
            fin_rows[next_idx] = row + ffi_c.search_match_lines --[[ @as integer ]]
            fin_cols[next_idx] = ffi_c.search_match_endcol --[[ @as integer ]]

            len_active_idxs = len_active_idxs + 1
            active_idxs[len_active_idxs] = next_idx
            next_idx = next_idx + 1
            total_results = total_results + 1

            return 1
        end

        count1 = count1 - 1
        return 1
    end)

    results.next_idx = next_idx
    if moved_cursor then
        fn.cursor({ curpos[2], curpos[3], curpos[4], curpos[5] })
    end

    if ok then
        return ok, nil, nil
    else
        return ok, err, "ErrorMsg"
    end
end
-- NOTE: nvim_win_get_cursor is ~2.5x faster in isolation than vim.call("line", ".") plus
-- vim.call("col", ".") (second fastest method). Also produces non-trivial perf improvement in
-- the actual search() callback.

---@param win integer
---@param pattern string
---@param curpos [integer, integer, integer, integer, integer] See |getcurpos()|
---@param range_4 Range4
---@param results nvim-tools.Results Edited in place
---@param opts nvim-tools.search.AreaOpts
---@return boolean, integer|string|nil, string|nil
local function search_area_jit(win, pattern, curpos, range_4, results, opts)
    local cur_win = api.nvim_get_current_win()
    local start_time = vim.uv.hrtime()
    local ok, err, hl = require("nvim-tools.win").call_in(cur_win, win, function()
        return run_search_area_jit(win, pattern, curpos, range_4, results, opts)
    end)
    local end_time = vim.uv.hrtime()
    local duration_ms = (end_time - start_time) / 1e6
    print(string.format("hl_forward took %.2f ms", duration_ms))

    if not ok then
        return ok, err, hl
    end

    -- Perform JIT-specific corrections

    return true, nil, nil
end

---@param win integer
---@param pattern string
---@param curpos [integer, integer, integer, integer, integer] See |getcurpos()|
---@param range_4 Range4
---@param results nvim-tools.Results Edited in place
---@param opts nvim-tools.search.AreaOpts
---@return boolean, integer|string|nil, string|nil
local function search_area_puc(win, pattern, curpos, range_4, results, opts)
    local cur_win = api.nvim_get_current_win()
    local ok, err, hl = require("nvim-tools.win").call_in(cur_win, win, function()
        -- TODO: Change to PUC function
        return run_search_area_jit(win, pattern, curpos, range_4, results, opts)
    end)

    if not ok then
        return ok, err, hl
    end

    -- Perform PUC-specific corrections

    return true, nil, nil
end

local search_area = (function()
    if has_ffi_search_globals then
        return search_area_jit
    else
        return search_area_puc
    end
end)()

---@param pattern string
---@param opts nvim-tools.search.SingleOpts
local function search_single_jit(pattern, opts)
    local _ = pattern
    local _ = opts
end

---@param pattern string
---@param opts nvim-tools.search.SingleOpts
local function search_single_puc(pattern, opts)
    local _ = pattern
    local _ = opts
end
-- TODO: For count, if looking for at least one, store the cursor result on every hit, but only
-- exit the search function when count is hit. Use temp ints or the same table.

local search_single = (function()
    if has_ffi_search_globals then
        return search_single_jit
    else
        return search_single_puc
    end
end)()

---@param buf integer
---@param curpos [integer, integer, integer, integer, integer]
---@param cache table<integer, string> Edited in place
---@param range -2|-1|0|nil|1|2|Range4
---@return Range4
local function resolve_search_range(buf, curpos, cache, range)
    if type(range) == "table" then
        return range
    end

    local range_4 = { 0, 0, 0, 0 }

    if range <= 0 or range == nil then
        range_4[1] = (range == -2 or range == nil) and 1 or fn.line("w0")
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
---Filter applied to the pattern.
---TODO: Document examples of forcing case or forcing fixed strings
---@field pattern_filter? fun(pattern:string): filtered_pattern:string
---In ms.
---(default: `500`)
---@field timeout? integer
---@field win? integer Window to search within

---@class nvim-tools.search.AreaOpts : nvim-tools.search.CommonOpts
---For LuaJIT builds, set the default size of table.new in the results lists.
---(default: `16`)
---@field alloc_size? integer
---Pass in the cursor by reference if it's already been pulled from Neovim.
---@field cursor? [integer, integer, integer, integer, integer]
---@field max_results? integer

---@param opts nvim-tools.search.CommonOpts
local function resolve_common_search_opts(opts)
    local _ = opts
end

---@param opts nvim-tools.search.SingleOpts
local function resolve_single_search_opts(opts)
    local _ = opts
    resolve_common_search_opts(opts)
end

---@param opts nvim-tools.search.AreaOpts
local function resolve_area_search_opts(opts)
    local _ = opts
    resolve_common_search_opts(opts)
end

---@param win integer Window to search within
---@param pattern string
---Area to search:
---- -2: Upward from the cursor to the beginning of the buffer
---- -1: Upward from the cursor to the top of the visible buffer
---- 0: Visible buffer area
---- nil: Entire buffer
---- 1: Downward from the cursor to the bottom of the visible buffer
---- 2: Downward from the cursor to the end of the buffer
---- Range4: 1 indexed, end inclusive range to search
---@param range -2|-1|0|nil|1|2|Range4
---@param opts nvim-tools.search.AreaOpts
---@return nvim-tools.Results results 1,1,1,1 indexed, inclusive ends
---@return table<integer, string> cache Lines gathered during search. One indexed rows as keys.
function M.search_area(win, pattern, range, opts)
    vim.validate("pattern", pattern, "string")
    vim.validate("opts", opts, "table", true)
    -- TODO: Should be more specific
    vim.validate("dir", range, function()
        return range >= -2 or range <= 2 or type(range) == "table"
    end)

    opts = opts or {}
    resolve_area_search_opts(opts)

    if opts.pattern_filter then
        pattern = opts.pattern_filter(pattern)
    end

    local curpos = opts.cursor or fn.getcurpos(win)
    local buf = api.nvim_win_get_buf(win)
    local cache = {} ---@type table<integer, string>

    local range_4 = resolve_search_range(buf, curpos, cache, range)

    -- TODO: SHouldn't this be in resolve opts?
    local size = opts.alloc_size or 16
    local results = require("nvim-tools.results").new(size)
    search_area(win, pattern, curpos, range_4, results, opts)

    return results, cache
end
-- TODO: Since we are now using match_line, We do need external buffer context. We might not need
-- window context.
-- TODO: Take cache as an opt since you might multi-win search using the same buffer

---@class nvim-tools.search.SingleOpts : nvim-tools.search.CommonOpts
---If the search expires before reaching `count`, return the last result.
---(default: `false`)
---@field min_one? boolean
---(default: `false`)
---@field upward? boolean
---(default: `false`)
---@field wrapscan? boolean

---@param pattern string
---@param opts nvim-tools.search.SingleOpts
---@return integer row, integer col 1,1 indexed, inclusive
function M.search_single(pattern, opts)
    vim.validate("pattern", pattern, "string")
    vim.validate("opts", opts, "table", true)

    opts = opts or {}

    resolve_single_search_opts(opts)
    search_single(pattern, opts)

    return 1, 1
end
-- NON: This function should not jump itself or set a pcmark, since that makes it less useful to
-- any calling code. Should only be getting position.

return M
