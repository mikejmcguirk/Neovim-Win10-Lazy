local M = {}

local function search_jit(pattern, dir, opts)
    ---@type nvim-tools.search.Results
    local res = { idxs = {}, rows = {}, cols = {}, fin_rows = {}, fin_cols = {} }
    return res
end

local function search_puc(pattern, dir, opts)
    ---@type nvim-tools.search.Results
    local res = { idxs = {}, rows = {}, cols = {}, fin_rows = {}, fin_cols = {} }
    return res
end

local do_search = (function()
    if jit then
        return search_jit
    else
        return search_puc
    end
end)()
-- TODO: This also needs to the FFI checks

---@class nvim-tools.search.Results
---@field idxs integer[]
---@field rows integer[]
---@field cols integer[]
---@field fin_rows integer[]
---@field fin_cols integer[]

-- TODO: Need search functions to trim X results, with the option to leave at least one. For
-- supporting count with minimum amount.
-- TODO: You can't really get the perf benefit of the SoA if every op on the result forces a
-- table scan and modification. So for the various result ops, we want to alter the idxs only.
-- The canned version of search results here should perform a final compact step before sending
-- results. Both for demo and RAM management purposes
-- TODO: Needs to be some amount of intelligence about what transformations need to be done
-- where. I mean, I would think.
-- TODO: Use table.new here
-- TODO: Need the following iterators to work with results:
-- - Sort
-- - filter (both ways)
-- - map
-- - compact
-- MAYBE: Cut search result functions into their own file. Want to actually hit that pain point
-- first though.
-- - Part of it too is, what conceptually goes where
-- - There are fixes for JIT and Puc results that have to be done for baseline accuracy. They
-- should be done here unless it's absolutely prohibitive to do so.
-- - On the other hand, something like fold management, while a baseline modification for
-- results, isn't necessary for the basic production of them.
-- - The problem, as I remember from doing this before, is that you want to be cutting results
-- aggressively to avoid the amount of iterating. So like, there are baseline things you need to
-- be able to do in order to make other modifications, but then you want to get those removals
-- in there when you can.
-- - Directionally, it is useful for these modules to provide as meaningful a baseline as possible.
-- Handling fold results is only one layer above fundamental.
-- - This is also a case where, because of how inter-twined everything is, the "reference impl"
-- philosophy doesn't work as well. As if we deliberately introduce slowness here, it's hard to
-- unwind.
-- - We need to make some trade offs here for accuracy, flexibility, and conceptual sanity:
--   - This module can only be concerned with getting the search results, making sure they are
--   correct, and returning the results metatable
--   - The _results farsight module kinda already does this, but the iterators over results need
--   to only be focused on iteration structure, not what the iteration does
--   - The thing that, of course, sticks out here is folds, because they can be path dependent
-- NON: Because the results are meant to be portable across applications, should not add more
-- fields
-- NON: Unless it's absolutely necessary, don't do the position hashing here. Goes against this
-- being a minimal implementation.

---@class nvim-tools.search.Opts
---For LuaJIT builds, set the default size of table.new in the results lists.
---(default: `16`)
---@field alloc_size? integer
---At which occurrence should results begin to be collected? count 0 or count 1 will start
---from the first result. count 2 will start from the second result, and so on. Useful if you
---want to use search to find a jump location, but jump to [count] occurrence.
---Note that this can mean, if for example, count 2 is specified but there is only one result, that
---no results return.
---@field count? integer
---@field max_results? integer
---Filter applied to the pattern.
---TODO: Document examples of forcing case or forcing fixed strings
---@field pattern_filter? fun(pattern:string): filtered_pattern:string
---@field win? integer Window to search within
---(default: `false`)
---@field wrapscan? boolean

local function resolve_search_opts(opts)
    local _ = opts
end

---@param pattern string
---@param dir -1|0|1
---@param opts nvim-tools.search.Opts
function M.search(pattern, dir, opts)
    vim.validate("pattern", pattern, "string")
    vim.validate("opts", opts, "table", true)
    vim.validate("dir", dir, function()
        return dir == -1 or dir == 0 or dir == 1
    end)

    opts = opts or {}
    resolve_search_opts(opts)

    pattern = opts.pattern_filter(pattern)

    -- TODO: My hope here is that do_search can do its pattern bookkeeping outside of
    -- nvim_win_call then only run that for the actual search op
    do_search(pattern, dir, opts)
end
-- DOCUMENT: The flags table cannot be passed in literally due to behavioral wrapping.
-- - Results gathering/management
-- - FFI usage/PUC-Lua compatibility
-- - Search region handling

-- TODO: How is pcmark handled?
-- TODO: Must address use cases:
-- - csearch movement
-- - bracket buffer navigation
-- - live search (up or down)
-- - static search (whole buffer, visible)
-- - whole buffer (not just visible parts, no wrapscan)

-- DOCUMENT: PUC-Lua compatibility is best-effort but not prioritized. LuaJIT recommended.

-- NON: The `dir` param should only handle search direction. Do not make it implicitly handle
-- other things. This was a pain point in prior implementations.

return M
