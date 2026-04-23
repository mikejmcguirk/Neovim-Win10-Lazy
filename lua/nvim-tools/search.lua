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

---@param pattern string
---@param range_4 Range4
---@param opts nvim-tools.search.AreaOpts
local function search_area_jit(pattern, range_4, opts)
    local _ = pattern
    local _ = range_4
    local _ = opts

    ---@type nvim-tools.search.Results
    local res = { idxs = {}, rows = {}, cols = {}, fin_rows = {}, fin_cols = {} }
    return res
end

---@param pattern string
---@param range_4 Range4
---@param opts nvim-tools.search.AreaOpts
local function search_area_puc(pattern, range_4, opts)
    local _ = pattern
    local _ = range_4
    local _ = opts

    ---@type nvim-tools.search.Results
    local res = { idxs = {}, rows = {}, cols = {}, fin_rows = {}, fin_cols = {} }
    return res
end

local search_area = (function()
    if has_ffi_search_globals then
        return search_area_jit
    else
        return search_area_puc
    end
end)()
-- TODO: This also needs to the FFI checks
-- Those should probably be done once so then the same result can be used for resolving the area
-- and single functions.

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

---@class nvim-tools.search.Results
---@field idxs integer[]
---@field rows integer[]
---@field cols integer[]
---@field fin_rows integer[]
---@field fin_cols integer[]

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
---@field win? integer Window to search within

---@class nvim-tools.search.AreaOpts : nvim-tools.search.CommonOpts
---For LuaJIT builds, set the default size of table.new in the results lists.
---(default: `16`)
---@field alloc_size? integer
---Pass in the cursor by reference if it's already been pulled from Neovim.
---@field cursor? [integer, integer, integer, integer, integer]
---@field max_results? integer
---How to handle results that run past the search range
---- 0: No handling
---- 1: Crop results to be within the range
---- 2: Remove overflow results
---@field spill_handling? 0|1|2

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
---@return nvim-tools.search.Results results 1,1,1,1 indexed, inclusive ends
---@return table<integer, string> cache Lines gathered during search. One indexed rows as keys.
function M.search_area(win, pattern, range, opts)
    vim.validate("pattern", pattern, "string")
    vim.validate("opts", opts, "table", true)
    vim.validate("dir", range, function()
        return range == -1 or range == 0 or range == 1 or type(range) == "table"
    end)

    opts = opts or {}
    resolve_area_search_opts(opts)

    pattern = opts.pattern_filter(pattern)
    local curpos = opts.cursor or fn.getcurpos(win)
    local buf = api.nvim_win_get_buf(win)
    local cache = {} ---@type table<integer, string>

    local range_4 = resolve_search_range(buf, curpos, cache, range)

    search_area(pattern, range_4, opts)

    return {}, cache
end
-- TODO: Use table.new here

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
