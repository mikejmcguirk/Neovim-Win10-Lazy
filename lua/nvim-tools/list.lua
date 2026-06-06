-- NOTE: The validators for t in this module only check if the param is a table. Like vim.list,
-- these functions should be able to operate on the list part of a table with a list and dict
-- component.
-- NOTE: These functions should all be pure Lua, not relying on vim.api or vim.fn calls

---@brief All functions in this module only operate on the |lua-list| portion of the table.

---@brief `_to` functions create a new list. Functions without the `_to` naming update the list
---in place. To get a new list from a function that modifies that target list in place, use
---the |list.copy()| function to create a shallow copy. `_to` functions may not be offered if
---they provide no performance advantage over just doing the shallow copy.

-- DOC: Add examples for the above.
-- - Or maybe, for examples without a `_to` function, show one copied example.

---@tag iter-indexing
---@brief For functions that take start and stop params:
---- Values greater than or equal to one operate according to standard Lua indexing.
---- A value of zero resolves to the length of the table.
---- A value less than zero will subtract that amount from the table length.
---
---Example: 1, 0 - Iterate from the first index to the end.
---Example: 1, -1 - Iterate from the first index to the second-to-last index.
---Example: -1, 0 - Iterate from the second-to-last to the end.

local M = {}

-----------------
-- MARK: Utils --
-----------------

---@generic T
---@param t T[]
---@param start integer
---@param stop integer
local function clear_exact(t, start, stop)
    for i = start, stop do
        t[i] = nil
    end
end
-- TODO: Remove this. Makes extracting functions a pain.

---Copied from Neovim core.
---@generic T
---@param key nil|string|fun(val:any): any
---@return fun(v: T): any
local function make_key_fn(key)
    if not key then
        return function(v)
            return v
        end
    end

    if type(key) == "string" then
        local field = key
        ---@param v any
        key = function(v)
            return v and v[field]
        end
    end

    return key
end

---@param val integer?
---@param len integer
---@param default integer
---@return integer
local function resolve_iter_index(val, len, default)
    val = math.min(val or default, len)
    return val > 0 and val or math.max(len + val, math.min(1, len))
end
-- TODO: Everywhere this is used needs to be looked at. The from 1 to 0 short circuit behavior
-- does not work with this I don't think.

---@param rev boolean?
---@param start integer
---@param stop integer
---@return integer start, integer stop, integer step
local function resolve_rev(rev, start, stop)
    if rev then
        return stop, start, -1
    else
        return start, stop, 1
    end
end

---@param key_fn fun(x:any): any
---@param ... any[]
---@return table<any, true> seen
local function seen_from_varargs(key_fn, ...)
    local nargs = select("#", ...)
    local seen = {} ---@type table<any, boolean>
    for i = 1, nargs do
        local tn = select(i, ...)
        local tn_len = #tn
        for j = 1, tn_len do
            local vh = key_fn(tn[j])
            if vh ~= nil then
                seen[vh] = true
            end
        end
    end

    return seen
end

---@param nargs integer
---@param key_fn fun(x: any): any
---@param ... any[]
---@return table<any, true>
local function seen_from_varargs_if_in_all(nargs, key_fn, ...)
    if nargs == 0 then
        return {}
    end

    if nargs == 1 then
        local seen = {} ---@type table<any, true>
        local t1 = select(1, ...)
        local t1_len = #t1
        for i = 1, t1_len do
            local vh = key_fn(t1[i])
            if vh ~= nil then
                seen[vh] = true
            end
        end

        return seen
    end

    local varargs = { ... } ---@type any[][]
    local min_idx, min_len = 1, #varargs[1]
    for i = 2, nargs do
        local vararg_len = #varargs[i]
        if vararg_len < min_len then
            min_len = vararg_len
            min_idx = i
        end
    end

    local seen = {} ---@type table<any, boolean|integer>
    local gen_prev = 0
    local gen = 1
    local t1 = varargs[min_idx]
    local t1_len = #t1
    for i = 1, t1_len do
        local vh = key_fn(t1[i])
        if vh ~= nil then
            seen[vh] = gen
        end
    end

    for i = 1, min_idx - 1 do
        gen_prev = gen
        gen = gen + 1
        local tn = varargs[i]
        local tn_len = #tn
        for j = 1, tn_len do
            local vh = key_fn(tn[j])
            if vh ~= nil and seen[vh] == gen_prev then
                seen[vh] = gen
            end
        end
    end

    for i = min_idx + 1, nargs do
        gen_prev = gen
        gen = gen + 1
        local tn = varargs[i]
        local tn_len = #tn
        for j = 1, tn_len do
            local vh = key_fn(tn[j])
            if vh ~= nil and seen[vh] == gen_prev then
                seen[vh] = gen
            end
        end
    end

    for k, last_gen in pairs(seen) do
        if last_gen == nargs then
            seen[k] = true
        else
            seen[k] = nil
        end
    end

    return seen --[[@as table<any, true>]]
end

---@param ... any[]|table<any, any>
local function validate_table_varargs(...)
    local nargs = select("#", ...)
    for i = 1, nargs do
        vim.validate("tn", select(i, ...), "table")
    end
end

-------------------------
-- MARK: List Creation --
-------------------------

---Appends n lists args to `t1`. Use |copy()| on t1 to get a new list.
---Performs a shallow copy of the appended lists.
---@generic T
---@param t1 T[] Modified in place!
---@param ... any[]
---@return any[] The original reference with the additional lists appended.
function M.chain(t1, ...)
    local nargs = select("#", ...)

    vim.validate("t1", t1, "table")
    for i = 1, nargs do
        local tn = select(i, ...)
        vim.validate("tn", tn, "table")
    end

    for i = 1, nargs do
        local tn = select(i, ...)
        local tn_len = #tn
        for j = 1, tn_len do
            t1[#t1 + 1] = tn[j]
        end
    end

    return t1
end
-- No "new table" version of this function because it would require a full copy of t1 anyway.

---Merge two unsorted lists into one sorted list. `t1` and `t2` are copied.
---
---If `t1` and `t2` are already sorted, use |merge_sorted()|.
---@generic T
---@param t1 T[]
---@param t2 T[]
---@param comp? fun(a: T, b: T): boolean Default: Ascending order. Compatible with |table.sort()|.
---@return T[] New list.
function M.collate(t1, t2, comp)
    vim.validate("t1", t1, "table")
    vim.validate("t2", t2, "table")
    vim.validate("comp", comp, "function", true)

    comp = comp or function(a, b)
        return a < b
    end

    local s1 = M.copy(t1)
    local s2 = M.copy(t2)
    table.sort(s1, comp)
    table.sort(s2, comp)

    return M.merge_sorted(s1, s2, comp)
end

---Performs a shallow copy of `t`.
---@generic T
---@param t T[]
---@return T[] Empty if table length is zero.
function M.copy(t)
    vim.validate("t", t, "table")

    local t_len = #t
    local ret = require("nvim-tools.table").new(t_len, 0)
    for i = 1, t_len do
        ret[i] = t[i]
    end

    return ret
end

---Merge two already sorted lists in order into a new list.
---
---Example:
---```lua
---    --- |collate()| behavior without copying:
---    local fo = merge_sorted(table.sort(t1), table.sort(t2))
---```
---@generic T
---@param t1 T[]
---@param t2 T[]
---@param comp? fun(a: T, b: T): boolean Default: Ascending order. Compatible with |table.sort()|.
---@return T[] Returns an empty table if `t1` and `t2` are empty.
function M.merge_sorted(t1, t2, comp)
    vim.validate("t1", t1, "table")
    vim.validate("t2", t2, "table")
    vim.validate("comp", comp, "function", true)

    local i = 1
    local j = 1
    local k = 1
    local len1 = #t1
    local len2 = #t2
    comp = comp or function(a, b)
        return a < b
    end

    local len_total = len1 + len2
    if len_total == 0 then
        return {}
    end

    local ret = require("nvim-tools.table").new(len_total, 0)
    while i <= len1 and j <= len2 do
        if comp(t1[i], t2[j]) then
            ret[k] = t1[i]
            i = i + 1
        else
            ret[k] = t2[j]
            j = j + 1
        end

        k = k + 1
    end

    while i <= len1 do
        ret[k] = t1[i]
        i = i + 1
        k = k + 1
    end

    while j <= len2 do
        ret[k] = t2[j]
        j = j + 1
        k = k + 1
    end

    return ret
end

---Create a new list containing `v` repeated `count` times.
---Does not copy table references.
---@generic T
---@param v T
---@param count integer Returns an empty table if count is zero.
---@return T[] Creates a new list.
function M.replicate(v, count)
    local nty = require("nvim-tools.types")
    vim.validate("v", v, nty.not_nil)
    vim.validate("count", count, nty.is_uint)

    if count == 0 then
        return {}
    end

    local ret = require("nvim-tools.table").new(count, 0)
    for i = 1, count do
        ret[i] = v
    end

    return ret
end
-- Repeat is a Lua keyword, so replicate.

---@generic T
---@param dst T[]
---@param t T[]
---@see |iter-indexing|
---@param start? integer
---@param stop? integer
---@return T[]
local function splice_do(dst, t, start, stop)
    local t_len = #t
    if t_len == 0 then
        return dst
    end

    start = resolve_iter_index(start, t_len, 1)
    stop = resolve_iter_index(stop, t_len, t_len)
    local to_new_list = t ~= dst
    if start > stop then
        return M.clear(dst)
    elseif start == 1 and stop == t_len then
        return to_new_list and M.copy(t) or t
    end

    if to_new_list or start > 1 then
        local j = 1
        for i = start, stop do
            dst[j] = t[i]
            j = j + 1
        end
    end

    if to_new_list then
        return dst
    end

    local new_len = stop - start + 1
    for i = new_len + 1, t_len do
        t[i] = nil
    end

    return dst
end

---Modifies `t` in place!
---
---Get a subset of `t` by start and stop indices.
---Splice `t` into a subset of its values defined by `start` and `stop` indices.
---
---Returns an empty table if `t` is length zero or the provided `start` and `stop` values resolve
---to an invalid iteration.
---@generic T
---@param t T[] Modified in place!
---@see |iter-indexing|
---@param start? integer
---@param stop? integer
---@return T[] Reference to `t`.
function M.splice(t, start, stop)
    vim.validate("t", t, "table")
    local is_int = require("nvim-tools.types").is_int
    vim.validate("start", start, is_int, true)
    vim.validate("stop", stop, is_int, true)

    return splice_do(t, t, start, stop)
end

---Get a new list containing a subset of `t` by `start` and `stop` indices.
---
---Returns an empty table if `t` is length zero or the provided `start` and `stop` values resolve
---to an invalid iteration.
---@generic T
---@param t T[]
---@see |iter-indexing|
---@param start? integer
---@param stop? integer
---@return T[] A new list.
function M.splice_to(t, start, stop)
    vim.validate("t", t, "table")
    local is_int = require("nvim-tools.types").is_int
    vim.validate("start", start, is_int, true)
    vim.validate("stop", stop, is_int, true)

    return splice_do({}, t, start, stop)
end

---Create a new list, using a transform function to iteratively mutate an initial seed value.
---
---Unlike |unfold()|, this does not provide a separate accumulator value. The input value is the
---previous value in the list, and the function output is the list's next value.
---
---Example:
---```lua
---local path = successors(5, function(x, len)
---    if x == 1 then
---        return nil
---    elseif x % 2 == 0 then
---        return x / 2
---    else
---        return (3 * x) + 1
---    end
---end)
----- Returns { 5, 16, 8, 4, 2, 1 }
---```
---@generic T
---@param init T First value of the list.
---@param f fun(last:T, idx:integer): T|nil Provides the current last value of the list and the
---     current list length.. The returned value is appended to the list. If the return is nil,
---     the list building ends.
---@return T[] The new table.
function M.successors(init, f)
    vim.validate("init", init, require("nvim-tools.types").not_nil)
    vim.validate("f", f, "callable")

    local ret = { init }
    while true do
        local ret_len = #ret
        local v = f(ret[ret_len], ret_len)
        if v ~= nil then
            ret[ret_len + 1] = v
        else
            break
        end
    end

    return ret
end
-- MID: Figure out a way to make this function early return without introducing another
-- variable.I don't want to undermine the simplicity of the interface.

---Create a new list, using a transform function to iteratively mutate an initial seed value.
---
---Unlike |successors()|, the initial seed does not become the first value of the list. It is
---instead provided to the transform function as an argument.
---@generic T
---@generic U
---@param init U
---@param f fun(acc:U, last:T, idx:integer): acc:U|nil, v:T|nil Accepts as arguments the
---     accumulator, the last table value, and the current table length. The returned `v` value
---     is written to the table, with `acc` stored for the next iteration. If the returned `acc`
---     value is nil, `v` is written to the new table and the function terminates. If `v` is
---     nil, the function terminates immediately.
---@return T[] The new table. Returns an empty table if the first call to `f` produces a nil value.
function M.unfold(init, f)
    vim.validate("init", init, require("nvim-tools.types").not_nil)
    vim.validate("f", f, "callable")

    local ret = {}
    local acc = init
    local v
    while true do
        local ret_len = #ret
        acc, v = f(acc, ret[ret_len], ret_len)
        if v == nil then
            break
        end

        ret[ret_len + 1] = v

        if acc == nil then
            break
        end
    end

    return ret
end

-----------------------------------
-- MARK: Direct Access Functions --
-----------------------------------

---Get a value from a list. Does not copy references.
---
---Returns nil if the table is empty.
---@generic T
---@param t T[]
---@param idx integer See |iter-indexing|
---@return T? The value at the index.
function M.at(t, idx)
    vim.validate("t", t, "table")
    vim.validate("idx", idx, require("nvim-tools.types").is_int)
    local t_len = #t
    return t[resolve_iter_index(idx, t_len, t_len)]
end

--- Returns an iterator that infinitely cycles through `t`.
--- Each step yields: `idx` (1-based index within the cycle), `value`, `cycle`
--- (0-based full cycles completed).
---@generic T
---@param t T[]
---@return fun(): integer|nil, T|nil, integer|nil Nil iter return if length of `t` is zero.
function M.cycle(t)
    vim.validate("t", t, "table")

    local t_len = #t
    if t_len == 0 then
        ---@return nil, nil, nil
        return function()
            return nil, nil, nil
        end
    end

    local i = 0
    ---@generic T
    ---@return integer, T, integer
    return function()
        i = i + 1
        local idx = ((i - 1) % t_len) + 1
        local cycle = math.floor((i - 1) / t_len)
        return idx, t[idx], cycle
    end
end

---Delete a value from `t` and return it.
---@generic T
---@param t T[] Modified in place!
---@param idx? integer See |iter-indexing|. If nil, removes the last element.
---@return T|nil `nil` if list length is zero.
function M.drain(t, idx)
    vim.validate("t", t, "table")
    local nty = require("nvim-tools.types")
    vim.validate("idx", idx, nty.is_int, true)

    local t_len = #t
    if t_len == 0 then
        return nil
    end

    local res_idx = resolve_iter_index(idx, t_len, t_len)
    local v = t[res_idx]
    for i = res_idx + 1, t_len do
        t[i - 1] = t[i]
    end

    t[t_len] = nil
    return v
end
-- TODO: Verify that this is faster than table.remove(). Probably worth writing a real test and
-- saving the code.

---Insert a new value `v` into table `t` at index `idx`.
---@generic T
---@param t T[] Modified in place!
---@param v T
---@param idx? integer See |iter-indexing|
---     If no index, append to the end like |table.insert()|
function M.insert_at(t, v, idx)
    vim.validate("t", t, "table")
    local nty = require("nvim-tools.types")
    vim.validate("v", v, nty.not_nil)
    vim.validate("idx", idx, nty.is_int, true)

    local t_len = #t
    if not idx then
        t[t_len + 1] = v
        return
    end

    local res_idx = resolve_iter_index(idx, t_len, t_len)
    local stop = res_idx + 1
    for i = t_len + 1, stop, -1 do
        t[i] = t[i - 1]
    end

    t[res_idx] = v
end
-- TODO: Verify that this is faster than table.insert. Maybe worth writing up some kind of
-- real test and saving the code.

---@see |drain()| to additionally return the deleted element.
---@generic T
---@param t T[] Modified in place!
---@param idx? integer See |iter-indexing|. If nil, removes the last element.
function M.rm_at(t, idx)
    vim.validate("t", t, "table")
    vim.validate("idx", idx, require("nvim-tools.types").is_int, true)

    local t_len = #t
    if t_len == 0 then
        return nil
    end

    local res_idx = resolve_iter_index(idx, t_len, t_len)
    for i = res_idx + 1, t_len do
        t[i - 1] = t[i]
    end

    t[t_len] = nil
end
-- TODO: Verify that this is faster than table.remove(). Probably worth writing a real test and
-- saving the code.

-----------------------------------
-- MARK: Filtering and Cleansing --
-----------------------------------

---Clears a table's array elements.
---@generic T
---@param t T[] Modified in place!
---@return T[] The original list reference.
function M.clear(t)
    vim.validate("t", t, "table")

    local t_len = #t
    for i = 1, t_len do
        t[i] = nil
    end

    return t
end

---@generic T
---@param t T[]
---@param f fun(x:T): boolean
---@return T[]
local function filter_do(dst, t, f)
    local t_len = #t
    if t_len == 0 then
        return dst
    end

    local j = 1
    for i = 1, t_len do
        local v = t[i]
        if f(v) then
            dst[j] = v
            j = j + 1
        end
    end

    if dst ~= t then
        return dst
    end

    clear_exact(dst, j, t_len)
    return dst
end

---Filter values from `t` based on predicate function `f`.
---@generic T
---@param t T[] Modified in place!
---@param f fun(x:T): boolean
---@return T[] The original list reference.
function M.filter(t, f)
    vim.validate("t", t, "table")
    vim.validate("f", f, "callable")
    return filter_do(t, t, f)
end

---Create a new table without values from `t` filtered by predicate `f`.
---@generic T
---@param t T[]
---@param f fun(x:T): boolean
---@return T[] New table. If `t` is empty, an empty table will be returned.
function M.filter_to(t, f)
    vim.validate("t", t, "table")
    vim.validate("f", f, "callable")
    return filter_do({}, t, f)
end

---Filter duplicates. See |vim.list.unique()| to do so in-place.
---@generic T
---@param t T[]
---@param key nil|string|fun(val:any): any See: |vim.list.unique()|.
---@return T[] New and de-duped table. Empty if `t` has a length of zero.
function M.unique_to(t, key)
    vim.validate("t", t, "table")
    vim.validate("key", key, { "callable", "string" }, true)

    local t_len = #t
    local ret = {}
    if t_len == 0 then
        return ret
    end

    local key_fn = make_key_fn(key)
    local seen = {} --- @type table<any,boolean>
    local j = 1

    for i = 1, t_len do
        local v = t[i]
        local vh = key_fn(v)
        if vh ~= nil and not seen[vh] then
            ret[j] = v
            j = j + 1
            seen[vh] = true
        end
    end

    return ret
end

---@generic T
---@param t T[]
---@param f fun(x:T): boolean
---@param rev? boolean
---@return integer|nil, integer|nil
local function get_keep_splice(t, f, rev)
    local t_len = #t
    if t_len == 0 then
        return nil, nil
    end

    local start, stop, step = resolve_rev(rev, 1, t_len)
    local pos
    for i = start, stop, step do
        if not f(t[i]) then
            pos = i
            break
        end
    end

    if not pos then
        return 1, t_len
    end

    local splice_start
    local splice_stop
    if rev then
        splice_start = pos + 1
        splice_stop = t_len
    else
        splice_start = 1
        splice_stop = pos - 1
    end

    if splice_start > splice_stop then
        return nil, nil
    end

    return splice_start, splice_stop
end

---Iterate over a list with a predicate. Keep values until the predicate returns false, then
---remove the rest in place from the source list.
---@generic T
---@param t T[] Modified in place!
---@param f fun(x:T): boolean
---@param rev? boolean (Default: `false`) If true, iterate from the end.
---@return T[] Original reference to `t`. Unchanged if the whole table passes the predicate.
function M.keep_while(t, f, rev)
    vim.validate("t", t, "table")
    vim.validate("f", f, "callable")
    vim.validate("rev", rev, "boolean", true)

    local splice_start, splice_stop = get_keep_splice(t, f, rev)
    if not (splice_start and splice_stop) then
        return M.clear(t)
    end

    return splice_do(t, t, splice_start, splice_stop)
end

---Iterate over a list with a predicate. Keep values until the predicate returns false, then
---remove the rest. Output to a new list.
---@generic T
---@param t T[]
---@param f fun(x:T): boolean
---@param rev? boolean (Default: `false`) If true, iterate from the end.
---@return T[] New list. Returns a copy of `t` if all items are kept.
function M.keep_while_to(t, f, rev)
    vim.validate("t", t, "table")
    vim.validate("f", f, "callable")
    vim.validate("rev", rev, "boolean", true)

    local splice_start, splice_stop = get_keep_splice(t, f, rev)
    if not (splice_start and splice_stop) then
        return {}
    end

    return splice_do({}, t, splice_start, splice_stop)
end

---@generic T
---@param t T[]
---@param f fun(x:T): boolean
---@param rev? boolean
---@return integer|nil, integer|nil
local function get_rm_splice(t, f, rev)
    local t_len = #t
    if t_len == 0 then
        return nil, nil
    end

    local start, stop, step = resolve_rev(rev, 1, t_len)
    local pos
    for i = start, stop, step do
        if not f(t[i]) then
            pos = i
            break
        end
    end

    if not pos then
        return nil, nil
    end

    local splice_start
    local splice_stop
    if rev then
        splice_start = 1
        splice_stop = pos
    else
        splice_start = pos
        splice_stop = t_len
    end

    if splice_start > splice_stop then
        return 1, t_len
    end

    return splice_start, splice_stop
end

---Iterate over a list with a predicate. Remove values until the predicate returns false, then
---splice `t` in place to retain the rest.
---@generic T
---@param t T[] Modified in place!
---@param f fun(x:T): boolean
---@param rev? boolean (Default: `false`) If true, iterate from the end.
---@return T[] Original reference to `t`. Empty if the whole table passes the predicate.
function M.rm_while(t, f, rev)
    vim.validate("t", t, "table")
    vim.validate("f", f, "callable")
    vim.validate("rev", rev, "boolean", true)

    local splice_start, splice_stop = get_rm_splice(t, f, rev)
    if not (splice_start and splice_stop) then
        return M.clear(t)
    end

    return splice_do(t, t, splice_start, splice_stop)
end

---Iterate over a list with a predicate. Skip values until the predicate returns false, then
---return a new list containing the rest.
---@generic T
---@param t T[]
---@param f fun(x:T): boolean
---@param rev? boolean (Default: `false`) If true, iterate from the end.
---@return T[] New list. Empty if the whole table passes the predicate.
function M.rm_while_to(t, f, rev)
    vim.validate("t", t, "table")
    vim.validate("f", f, "callable")
    vim.validate("rev", rev, "boolean", true)

    local splice_start, splice_stop = get_rm_splice(t, f, rev)
    if not (splice_start and splice_stop) then
        return {}
    end

    return splice_do({}, t, splice_start, splice_stop)
end

-----------------------------------
-- MARK: List and List Filtering --
-----------------------------------

---@generic T
---@param dst T[]
---@param key nil|string|fun(x:any): any
---@param t1 T[]
---@param ... any[]
---@return T[]
local function difference_do(dst, key, t1, ...)
    local key_fn = make_key_fn(key)
    local seen = seen_from_varargs(key_fn, ...)
    local t1_len = #t1
    local j = 1
    for i = 1, t1_len do
        local v = t1[i]
        local vh = key_fn(v)
        if vh ~= nil and not seen[vh] then
            dst[j] = v
            j = j + 1
            seen[vh] = true
        end
    end

    if dst == t1 then
        clear_exact(dst, j, t1_len)
    end

    return dst
end

---Remove elements from `t1` in place that are present in any of the varargs (set difference/XOR
---logic). `t1` is de-duplicated. Order is preserved.
---@generic T
---@param key nil|string|fun(x:any): any See: |vim.list.unique()|.
---@param t1 T[] Target list. Modified in place!
---@param ... any[]
---@return T[] The original reference to `t1`.
function M.difference(key, t1, ...)
    vim.validate("key", key, { "callable", "string" }, true)
    vim.validate("t1", t1, "table")
    validate_table_varargs(...)

    return difference_do(t1, key, t1, ...)
end

---Create a new list containing the elements of `t1` not present in any of the varargs (set
---difference/XOR logic). `t1` is de-duplicated. Order is preserved.
---@generic T
---@param key nil|string|fun(x:any): any See: |vim.list.unique()|.
---@param t1 T[] Source list.
---@param ... any[]
---@return T[] New list.
function M.difference_to(key, t1, ...)
    vim.validate("key", key, { "callable", "string" }, true)
    vim.validate("t1", t1, "table")
    validate_table_varargs(...)

    return difference_do({}, key, t1, ...)
end

---@generic T
---@param dst T[]
---@param key nil|string|fun(val:any): any See: |vim.list.unique()|.
---@param t1 T[]
---@param ... any[]
---@return T[]
local function intersect_do(dst, key, t1, ...)
    local nargs = select("#", ...)
    if nargs == 0 then
        -- If the function continues with no varargs, seen will contain no values, causing every
        -- value in `t1` to be removed.
        return dst
    end

    local key_fn = make_key_fn(key)
    local seen = seen_from_varargs_if_in_all(nargs, key_fn, ...)
    local t1_len = #t1
    local j = 1
    for i = 1, t1_len do
        local v = t1[i]
        local vh = key_fn(v)
        if vh ~= nil and seen[vh] then
            dst[j] = v
            j = j + 1
        end
    end

    if dst == t1 then
        clear_exact(dst, j, t1_len)
    end

    return dst
end

---Remove elements from `t1` in place if they are not present in all of the varargs (AND logic).
---Order in `t1` is preserved
---@generic T
---@param key nil|string|fun(val:any): any See: |vim.list.unique()|.
---@param t1 T[] Modified in place!
---@param ... any[]
---@return T[] Reference to `t1`.
function M.intersect(key, t1, ...)
    vim.validate("key", key, { "callable", "string" }, true)
    vim.validate("t1", t1, "table")
    validate_table_varargs(...)

    return intersect_do(t1, key, t1, ...)
end

---Create a new list containing the elements in `t1` present in every vararg (AND logic).
---Order in `t1` is preserved
---@generic T
---@param key nil|string|fun(val:any): any See: |vim.list.unique()|.
---@param t1 T[]
---@param ... any[]
---@return T[] New list.
function M.intersect_to(key, t1, ...)
    vim.validate("key", key, { "callable", "string" }, true)
    vim.validate("t1", t1, "table")
    validate_table_varargs(...)

    return intersect_do({}, key, t1, ...)
end

---@generic T
---@param dst T[]
---@param key nil|string|fun(val:any): any
---@param t1 T[]
---@param ... any[]
---@return T[]
local function intersection_do(dst, key, t1, ...)
    local nargs = select("#", ...)
    if nargs == 0 then
        -- If the function continues with no varargs, seen will contain no values, causing every
        -- value in `t1` to be removed.
        return dst
    end

    local key_fn = make_key_fn(key)
    local seen = seen_from_varargs_if_in_all(nargs, key_fn, ...)
    local t1_len = #t1
    local j = 1
    for i = 1, t1_len do
        local v = t1[i]
        local vh = key_fn(v)
        if vh ~= nil and seen[vh] then
            dst[j] = v
            j = j + 1
            seen[vh] = nil
        end
    end

    if dst == t1 then
        clear_exact(dst, j, t1_len)
    end

    return dst
end

---Remove list elements from `t1` if they are not present in all vararg lists (AND logic).
---De-duplicates elements from `t1`. Order is preserved
---@generic T
---@param key nil|string|fun(val:any): any See: |vim.list.unique()|.
---@param t1 T[] Modified in place!
---@param ... any[]
---@return T[] Reference to `t`.
function M.intersection(key, t1, ...)
    vim.validate("key", key, { "callable", "string" }, true)
    vim.validate("t1", t1, "table")
    validate_table_varargs(...)

    return intersection_do(t1, key, t1, ...)
end

---Create a new list from the elements in `t1` present in all vararg lists (AND logic).
---De-duplicates elements from `t1`. Order is preserved.
---@generic T
---@param key nil|string|fun(val:any): any See: |vim.list.unique()|.
---@param t1 T[] Original order is preserved.
---@param ... any[]
---@return T[] New list.
function M.intersection_to(key, t1, ...)
    vim.validate("key", key, { "callable", "string" }, true)
    vim.validate("t1", t1, "table")
    validate_table_varargs(...)

    return intersection_do({}, key, t1, ...)
end

---@generic T
---@param dst T[]
---@param key nil|string|fun(val:any): any See: |vim.list.unique()|.
---@param t1 T[]
---@param ... any[]
---@return T[] New list.
local function subtract_do(dst, key, t1, ...)
    local key_fn = make_key_fn(key)
    local seen = seen_from_varargs(key_fn, ...)
    local t1_len = #t1
    local j = 1
    for i = 1, t1_len do
        local v = t1[i]
        local vh = key_fn(v)
        if vh ~= nil and not seen[vh] then
            dst[j] = v
            j = j + 1
        end
    end

    if dst == t1 then
        clear_exact(dst, j, t1_len)
    end

    return dst
end

---Remove elements from `t1` in place that are present in any of the varargs (set difference/XOR
---logic). Order in `t1` is preserved.
---@generic T
---@param key nil|string|fun(val:any): any See: |vim.list.unique()|.
---@param t1 T[] Modified in place!
---@param ... any[]
---@return T[] Reference to `t1`.
function M.subtract(key, t1, ...)
    vim.validate("key", key, { "callable", "string" }, true)
    vim.validate("t1", t1, "table")
    validate_table_varargs(...)

    return subtract_do(t1, key, t1, ...)
end

---Create a new list containing the elements of `t1` not present in any of the varargs (set
---difference/XOR logic). Order in `t1` is preserved.
---@generic T
---@param key nil|string|fun(val:any): any See: |vim.list.unique()|.
---@param t1 T[] Source list.
---@param ... any[]
---@return T[] New list.
function M.subtract_to(key, t1, ...)
    vim.validate("key", key, { "callable", "string" }, true)
    vim.validate("t1", t1, "table")
    validate_table_varargs(...)

    return subtract_do({}, key, t1, ...)
end

---Creates a new list from all values in all lists (OR logic).
---Elements in are de-duped. Order is preserved.
---@param key nil|string|fun(val:any): any See: |vim.list.unique()|.
---@param ... any[]
---@return any[]
function M.union_to(key, ...)
    vim.validate("key", key, { "callable", "string" }, true)
    validate_table_varargs(...)

    local nargs = select("#", ...)
    local key_fn = make_key_fn(key)
    local seen = {} ---@type table<any, boolean>
    local ret = {}
    for i = 1, nargs do
        local tn = select(i, ...)
        local tn_len = #tn
        for j = 1, tn_len do
            local v = tn[j]
            local vh = key_fn(v)
            if vh ~= nil and not seen[vh] then
                ret[#ret + 1] = v
                seen[vh] = true
            end
        end
    end

    return ret
end

---Returns a new list of items that are only present in one of the lists. (XOR logic).
---All items are de-duped. Original ordering is preserved.
---@param key nil|string|fun(val:any): any See: |vim.list.unique()|.
---@param ... any[]
---@return any[]
function M.distinct(key, ...)
    vim.validate("key", key, { "callable", "string" }, true)
    validate_table_varargs(...)

    local nargs = select("#", ...)
    local key_fn = make_key_fn(key)
    local seen = {} ---@type table<any, integer>
    for i = 1, nargs do
        local tn = select(i, ...)
        local tn_len = #tn
        for j = 1, tn_len do
            local vh = key_fn(tn[j])
            if vh ~= nil then
                local was_seen = seen[vh]
                if was_seen == nil then
                    seen[vh] = i
                elseif not (was_seen == i) then
                    seen[vh] = 0
                end
            end
        end
    end

    local ret = {} ---@type any[]
    for i = 1, nargs do
        local tn = select(i, ...)
        local tn_len = #tn
        for j = 1, tn_len do
            local v = tn[j]
            local vh = key_fn(v)
            if vh ~= nil and seen[vh] == i then
                ret[#ret + 1] = v
                seen[vh] = nil
            end
        end
    end

    return ret
end

-------------------------------
-- MARK: List Info Functions --
-------------------------------

---Check if all items in a list match a value or the result of a predicate function.
---@generic T
---@param t T[]
---@param v T|fun(x: T): boolean
---@return boolean all_pass, integer? bad_idx, T? bad_item On failure, the problem index and
---     value are returned. Always `false` if the list length is zero.
function M.all(t, v)
    vim.validate("t", t, "table")
    vim.validate("v", v, require("nvim-tools.types").not_nil)

    local t_len = #t
    if t_len == 0 then
        return false, nil, nil
    end

    local predicate = type(v) == "function" and v or function(x)
        return x == v
    end

    for i = 1, t_len do
        if not predicate(t[i]) then
            return false, i, t[i]
        end
    end

    return true
end

---Compare elements of t1 and t2 using an optional predicate function. By default, checks for
---shallow equality. If t1 and t2 are of different lengths, the shorter length is used for
---iteration.
---
---This function can be used to create:
---- eq/ne
---- lt/gt
---@generic T
---@generic U
---@param t1 T[]
---@param t2 U[]
---@param f? fun(a:T, b:U): boolean
---@return boolean ok, integer? idx, T? v1, U? v2 On failure, returns the problem index and
---     values. Returns false if either table has length zero.
function M.cmp(t1, t2, f)
    vim.validate("t", t1, "table")
    vim.validate("t", t2, "table")
    vim.validate("f", f, "callable", true)

    f = f or function(a, b)
        return a == b
    end

    local len = math.min(#t1, #t2)
    if len == 0 then
        return false
    end

    for i = 1, len do
        if not f(t1[i], t2[i]) then
            return false, i, t1[i], t2[i]
        end
    end

    return true
end

---For two-dimensional array `tt`, get the highest index value for which all sub-lists share the
---same values.
---@generic T
---@param tt T[][]
---@return integer? `nil` if the first index's values does not match.
function M.common_prefix(tt)
    vim.validate("tt", tt, "table")

    local tt_len = #tt
    if tt_len == 0 then
        return
    elseif tt_len == 1 then
        local tt_len_one = #tt[1]
        return tt_len_one > 0 and tt_len_one or nil
    end

    local tt_len_min = math.huge
    for i = 1, tt_len do
        local tt_len_i = #tt[i]
        if tt_len_i == 0 then
            return nil
        end

        tt_len_min = math.min(tt_len_min, tt_len_i)
    end

    for col = 1, tt_len_min do
        local v = tt[1][col]
        for row = 2, tt_len do
            if tt[row][col] ~= v then
                local common_prefix_end = col - 1
                return common_prefix_end > 0 and common_prefix_end or nil
            end
        end
    end

    return tt_len_min
end

---Check if any item in a list matches a value or the result of a predicate function.
---@generic T
---@param t T[]
---@param v T|fun(x:T): boolean
---@return boolean `false` if the list length is zero.
function M.contains(t, v)
    vim.validate("t", t, "table")
    vim.validate("v", v, require("nvim-tools.types").not_nil)

    local t_len = #t
    local predicate = type(v) == "function" and v or function(x)
        return x == v
    end

    for i = 1, t_len do
        if predicate(t[i]) then
            return true
        end
    end

    return false
end

---Check if all elements in a list are different.
---@generic T
---@param t T[]
---@return boolean ok, integer? idx, T? v `false` if list length is zero or one. Returns the
---     duplicate index and value if it is seen.
function M.diverse(t)
    vim.validate("t", t, "table")

    local t_len = #t
    if t_len <= 1 then
        return false, nil, nil
    end

    local seen = {} ---@type table<any, true>
    seen[t[1]] = true
    for i = 2, t_len do
        local v = t[i]
        if seen[v] then
            return false, i, v
        end

        seen[v] = true
    end

    return true
end

---Find the value of a predicate function result.
---@generic T
---@param t T[]
---@param f fun(x:T): boolean
---@param rev? boolean (Default: `false`) If true, iterate from the end.
---@return T? val, integer? idx `nil` if not found. Additionally returns the index the value was
---     found at.
function M.find(t, f, rev)
    vim.validate("t", t, "table")
    vim.validate("f", f, require("nvim-tools.types").not_nil)
    vim.validate("rev", rev, "boolean", true)

    local t_len = #t
    if t_len == 0 then
        return
    end

    local start, stop, step = resolve_rev(rev, 1, t_len)
    for i = start, stop, step do
        if f(t[i]) then
            return t[i], i
        end
    end
end

---Get all indexes containing the value or predicate function result `v` within list `t`.
---@generic T
---@param t T[]
---@param v T|fun(x:T): boolean
---@return integer[]? `nil` if no results.
function M.indices(t, v)
    vim.validate("t", t, "table")
    vim.validate("v", v, require("nvim-tools.types").not_nil)

    local t_len = #t
    if t_len == 0 then
        return
    end

    local predicate = type(v) == "function" and v or function(x)
        return x == v
    end

    local ret = {} ---@type integer[]
    for i = 1, t_len do
        if predicate(t[i]) then
            ret[#ret + 1] = i
        end
    end

    return ret
end

---See if only one value within `t` contains value or predicate function result `v`.
---@generic T
---@param t T[]
---@param v T|fun(x:T): boolean
---@return boolean ok, integer? idx, T? val Returns `false` if length is only one. If a
---     duplicate is found, the problem value and index are returned.
function M.one(t, v)
    vim.validate("t", t, "table")
    vim.validate("v", v, require("nvim-tools.types").not_nil)

    local t_len = #t
    if t_len == 0 then
        return false, nil, nil
    elseif t_len == 1 then
        return true, nil, nil
    end

    local predicate = type(v) == "function" and v or function(x)
        return x == v
    end

    local seen = false
    for i = 1, t_len do
        if predicate(t[i]) then
            if seen then
                return false, i, t[i]
            end

            seen = true
        end
    end

    return seen
end

---Get the index of a value or the result of a predicate function `v`.
---
---Use |find()| to also return the value.
---@generic T
---@param t T[]
---@param v T|fun(x:T): boolean
---@param rev? boolean (Default: `false`) If true, iterate from the end.
---@return integer? Index of the found item. `nil` if not found.
function M.position(t, v, rev)
    vim.validate("t", t, "table")
    vim.validate("v", v, require("nvim-tools.types").not_nil)
    vim.validate("rev", rev, "boolean", true)

    local t_len = #t
    local start, stop, step = resolve_rev(rev, 1, t_len)
    local predicate = type(v) == "function" and v or function(x)
        return x == v
    end

    for i = start, stop, step do
        if predicate(t[i]) then
            return i
        end
    end
end

---Check if all elements in a list are the same.
---@generic T
---@param t T[]
---@return boolean, integer? idx, T? v `false` if list length is zero. If a unique value is
---     found, the index and value are returned.
function M.same(t)
    vim.validate("t", t, "table")

    local t_len = #t
    if t_len == 0 then
        return false, nil, nil
    end

    local v = t[1]
    for i = 2, t_len do
        if t[i] ~= v then
            return false, i, v
        end
    end

    return true, nil, nil
end

---Return a list of boolean values based on the presence of `v`.
---Example:
---```lua
---    local foo = { 1, 2, 3, 1, 2, 3 }
---    local foobar = selectors(foo, 1)
---    -- Returns { true, false, false, true, false, false }
---```
---
---Example:
---```lua
---    local foo = { 1, 2, 3, 1, 2, 3 }
---    local foobar = selectors(foo, function(n)
---        return n % 2 == 0
---    end)
---    -- Returns { false, true, false, false, true, false }
---```
---@generic T
---@param t T[]
---@param v T|fun(x:T): boolean
---@return boolean[]? `nil` if table length is zero.
function M.selectors(t, v)
    vim.validate("t", t, "table")
    vim.validate("v", v, require("nvim-tools.types").not_nil)

    local t_len = #t
    if t_len == 0 then
        return
    end

    local ret = {} ---@type boolean[]
    local predicate = type(v) == "function" and v or function(x)
        return x == v
    end

    for i = 1, t_len do
        ret[#ret + 1] = predicate(t[i]) and true or false
    end

    return ret
end

--------------------------------
-- MARK: List to New Value(s) --
--------------------------------

---Apply a function to a list's elements, transforming them into a single value.
---@generic T
---@generic U
---@param t T[]
---@param init U First accumulator value
---@param f fun(acc:U, x:T, idx:integer): acc:U|nil If the acc return is `nil`, early-exit and
---     return the last accumulator value.
---@see |iter-indexing|
---@param start integer? (Default: `1`)
---@param stop? integer Default: Length of `t`
---@param rev? boolean (Default: `false`) If true, iterate from the end.
---@return U `init` if `t` is length zero.
function M.fold(t, init, f, start, stop, rev)
    vim.validate("t", t, "table")
    vim.validate("init", init, require("nvim-tools.types").not_nil)
    vim.validate("f", f, "callable")
    local is_int = require("nvim-tools.types").is_int
    vim.validate("start", start, is_int, true)
    vim.validate("stop", stop, is_int, true)
    vim.validate("rev", rev, "boolean", true)

    local t_len = #t
    start = resolve_iter_index(start, t_len, 1)
    stop = resolve_iter_index(stop, t_len, t_len)
    if t_len == 0 or start > stop then
        return init
    end

    local step
    start, stop, step = resolve_rev(rev, start, stop)
    local acc_ret = init
    for i = start, stop, step do
        local acc = f(acc_ret, t[i], i)
        if acc ~= nil then
            acc_ret = acc
        else
            return acc_ret
        end
    end

    return acc_ret
end

---Apply a function to all elements of a list, transforming them into a single value.
---@generic T
---@generic U
---@param t T[]
---@param f fun(acc:U, x:T): acc:U Accumulator initializes to the first value of the table.
---@return T `nil` if table is length zero.
function M.reduce(t, f)
    vim.validate("t", t, "table")
    vim.validate("f", f, "callable")

    local t_len = #t
    if t_len == 0 then
        return nil
    end

    local acc = t[1]
    for i = 2, t_len do
        acc = f(acc, t[i])
    end

    return acc
end

---Apply a function to all elements of a list, transforming them into a running list of the
---accumulated values.
---
---Can be used to make any sort of cumulative sum/product/min/max function.
---
---@generic T
---@generic U
---@param t T[]
---@param init U First accumulator value.
---@param f fun(acc:U, x:T, idx:integer): acc:U|nil If the acc return is `nil`, early-exit and
---     return the new list gathered so far.
---@return U[] New list containing the running accumulator values. If `t` is nil, will only
---     contain init.
function M.scan(t, init, f)
    vim.validate("t", t, "table")
    vim.validate("init", init, require("nvim-tools.types").not_nil)
    vim.validate("f", f, "callable")

    local t_len = #t
    local acc = init
    ---@generic U
    local ret = { acc } ---@type U[]
    if t_len == 0 then
        return ret
    end

    for i = 1, t_len do
        acc = f(acc, t[i], i)
        if acc ~= nil then
            ret[#ret + 1] = acc
        else
            return ret
        end
    end

    return ret
end

---------------------------
-- MARK: List Transforms --
---------------------------

---@generic T
---@param t T[] Values to aggregate.
---@param key nil|string|fun(val:any): any See: |vim.list.unique()|. How should table values be
---     converted into hash keys for aggregation?
---@param val nil|fun(agg_val:any, val:any): any How should the table values be converted into
---     the aggregated values? Takes as params the current aggregated value and the currently
---     iterated table value. If nil, builds a list of the values matching the key (groupBy
---     behavior).
function M.aggregate(t, key, val)
    vim.validate("t", t, "table")
    vim.validate("key", key, { "callable", "string" }, true)
    vim.validate("val", val, "callable", true)

    local ret = {}
    local t_len = #t
    if t_len == 0 then
        return ret
    end

    local val_fn = type(val) == "function" and val
        or function(agg_v, v)
            agg_v = agg_v or {}
            agg_v[#agg_v + 1] = v
            return agg_v
        end

    local key_fn = make_key_fn(key)
    for i = 1, t_len do
        local v = t[i]
        local vh = key_fn(v)
        if vh ~= nil then
            local vm = val_fn(ret[vh], v)
            if vm ~= nil then
                ret[vh] = vm
            end
        end
    end

    return ret
end
-- TODO: Come back to this.

---Fills `t` in place with `v` from `start` to `stop` (entire list if `start` and `stop` are
---`nil`).
---@generic T
---@param t T[] Modified in place.
---@param v any Value to place.
---@see |iter-indexing|
---@param start integer? (Default: `1`)
---@param stop? integer Default: Length of `t`
---@return T[] Reference to `t`.
function M.fill(t, v, start, stop)
    vim.validate("t", t, "table")
    local is_int = require("nvim-tools.types").is_int
    vim.validate("start", start, is_int, true)
    vim.validate("stop", stop, is_int, true)

    local t_len = #t
    start = resolve_iter_index(start, t_len, 1)
    stop = resolve_iter_index(stop, t_len, t_len)
    if start > stop then
        return t
    end

    for i = start, stop do
        t[i] = v
    end

    return t
end

---Apply function `f` to the values of `t` in place.
---No-op if `t1` length is zero.
---@generic T
---@generic U
---@param t T[] Modified in place!
---@param f fun(x: T, idx:integer): U|nil Correct idx is preserved when filtering. `nil` returns
---     are filtered.
---@see |iter-indexing|
---@param start integer? (Default: `1`) Leave elements before start un-mapped.
---@param stop? integer Default: Length of `t`. Elements after `stop` will be un-mapped.
---@return U[] The original list reference. If `start` and `stop` produce an invalid range, the
---     function is a no-op.
function M.filter_map(t, f, start, stop)
    vim.validate("t", t, "table")
    vim.validate("f", f, "callable")
    local is_int = require("nvim-tools.types").is_int
    vim.validate("start", start, is_int, true)
    vim.validate("stop", stop, is_int, true)

    local t_len = #t
    start = resolve_iter_index(start, t_len, 1)
    stop = resolve_iter_index(stop, t_len, t_len)
    if t_len == 0 or start > stop then
        return t
    end

    local j = start
    for i = start, stop do
        local vm = f(t[i], i)
        if vm ~= nil then
            t[j] = vm
            j = j + 1
        end
    end

    for i = stop + 1, t_len do
        t[j] = t[i]
        j = j + 1
    end

    for i = j, t_len do
        t[i] = nil
    end

    return t
end

---Create a new list by applying function `f` to the values of `t`.
---@generic T
---@generic U
---@param t T[]
---@param f fun(x:T, idx:integer): U|nil `nil` returns are filtered.
---@see |iter-indexing|
---@param start integer? (Default: `1`) Leave elements before start un-mapped.
---@param stop? integer Default: Length of `t`. Elements after `stop` will be un-mapped.
---@return U[] New table. Empty if all elements are filtered or if `start` and `stop` produce an
---     invalid range.
function M.filter_map_to(t, f, start, stop)
    vim.validate("t", t, "table")
    vim.validate("f", f, "callable")
    local is_int = require("nvim-tools.types").is_int
    vim.validate("start", start, is_int, true)
    vim.validate("stop", stop, is_int, true)

    local t_len = #t
    start = resolve_iter_index(start, t_len, 1)
    stop = resolve_iter_index(stop, t_len, t_len)
    local ret = {}
    if t_len == 0 or start > stop then
        return ret
    end

    local before_start = start - 1
    for i = 1, before_start do
        ret[i] = t[i]
    end

    local j = start
    for i = start, stop do
        local vm = f(t[i], i)
        if vm ~= nil then
            ret[j] = vm
            j = j + 1
        end
    end

    for i = stop + 1, t_len do
        ret[j] = t[i]
        j = j + 1
    end

    return ret
end

---Create a new dictionary table by applying a function to elements of a list.
---@generic T
---@generic U
---@generic V
---@param t T[]
---@param f fun(x:T, idx:integer): key:U, val:V If either `key` or `val` is nil, the element will
---     be filtered.
---@return table<U, V> New table. Empty if all elements are filtered.
function M.filter_map_to_dict(t, f)
    vim.validate("t", t, "table")
    vim.validate("f", f, "callable")

    local t_len = #t
    local ret = {}
    for i = 1, t_len do
        local k, v = f(t[i], i)
        if k ~= nil and v ~= nil then
            ret[k] = v
        end
    end

    return ret
end
-- TODO: This has to be a subset of something else.

---Apply function `f` to the elements of `t` in place. An accumulator value is stored between
---iterations.
---@generic T
---@generic U
---@generic V
---@param t T[] Modified in place!
---@param init V Initial accumulator value.
---@param f fun(acc:V, value:T, idx:integer): V, U|nil Receives the current accumulator, the
---     currently iterated list value, and the currently iterated index. If `nil` is returned for
---     the list value, it will be filtered.
---@return T[] The original list reference.
function M.filter_map_accum(t, init, f)
    vim.validate("t", t, "table")
    vim.validate("init", init, require("nvim-tools.types").not_nil)
    vim.validate("f", f, "callable")

    local t_len = #t
    local acc = init
    local j = 1
    for i = 1, t_len do
        local a, vm = f(acc, t[i], i)
        acc = a
        if vm ~= nil then
            t[j] = vm
            j = j + 1
        end
    end

    for i = j, t_len do
        t[i] = nil
    end

    return t
end

---Convert values from list `t` into a list of new values based on a threaded accumulator and an
---optional finalization function.
---@generic T
---@generic U
---@generic V
---@param t T[] Values to transduce.
---@param init U Initial accumulator value
---@param f fun(acc:U, v:T, idx:integer): acc:U|nil, v:V|nil
---Takes as params the current accumulator value, the current list value, and the current list
---index. Returns the new accumulator value and the next value to add to the return list.
---If the `acc` return is nil, `v` is first appended to the table if not nil, then the finalize
---function (`z`) runs, and the transduced list returns.
---If the `v` return is nil, the accumulator is updated but the current value of `t` is skipped.
---@param b? fun(acc:U): acc:U|nil, v:V|nil
---Function to run before list iteration. If the `acc` return is nil, early-exit.
---@param z? fun(acc:U): v:V|nil
---Optional finalization function. Called once at the end and may emit one final value to append
---to the returned list. If called after an early exit, the previous stored accumulator will be
---provided.
---@see |iter-indexing|
---@param start integer? (Default: `1`)
---@param stop? integer Default: Length of `t`
---@param rev? boolean (Default: `false`) If true, iterate from the end.
---@return V[] New list of converted values. Empty if `start` and `stop` produce an invalid
---iteration.
function M.transduce(t, init, f, b, z, start, stop, rev)
    vim.validate("t", t, "table")
    vim.validate("init", init, require("nvim-tools.types").not_nil)
    vim.validate("f", f, "callable")
    vim.validate("z", z, "callable", true)
    local is_int = require("nvim-tools.types").is_int
    vim.validate("start", start, is_int, true)
    vim.validate("stop", stop, is_int, true)
    vim.validate("rev", rev, "boolean", true)

    local ret = {}
    local t_len = #t
    start = resolve_iter_index(start, t_len, 1)
    stop = resolve_iter_index(stop, t_len, t_len)
    if t_len == 0 or start > stop then
        return ret
    end

    local acc_stored = init
    if b then
        local acc, v = b(acc_stored)
        if v then
            ret[#ret + 1] = v
        end

        if acc == nil then
            return ret
        else
            acc_stored = acc
        end
    end

    local step
    start, stop, step = resolve_rev(rev, start, stop)
    for i = start, stop, step do
        local acc, v = f(acc_stored, t[i], i)
        if v ~= nil then
            ret[#ret + 1] = v
        end

        if acc == nil then
            break
        else
            acc_stored = acc
        end
    end

    if z then
        local v = z(acc_stored)
        if v ~= nil then
            ret[#ret + 1] = v
        end
    end

    return ret
end

---@generic T
---@generic U
---@generic V
---@param t1 T[]
---@param t2 T[]
---@param f fun(a:T, b:U, idx:integer): val:V|nil
---@return V[]
local function filter_map_two_do(dst, t1, t2, f)
    local t1_len = #t1
    local len = math.min(t1_len, #t2)
    local j = 1
    for i = 1, len do
        local vm = f(t1[i], t2[i], i)
        if vm ~= nil then
            dst[j] = vm
            j = j + 1
        end
    end

    if dst ~= t1 then
        return dst
    end

    for i = j, t1_len do
        dst[i] = nil
    end

    return dst
end
-- TODO: filter_map_two is a bad name because it doesn't establish t1 as the base table

---Transform `t1` in place by applying a function to the values of `t1` and `t2`.
---If `t1` and `t2` are different lengths, the length of the smaller list is used.
---@generic T
---@generic U
---@generic V
---@param t1 T[]
---@param t2 U[]
---@param f fun(a:T, b:U, idx:integer): val:V|nil If val is `nil`, it will be filtered.
---@return V[] Reference to `t1`.
function M.filter_map_two(t1, t2, f)
    vim.validate("t1", t1, "table")
    vim.validate("t2", t2, "table")
    vim.validate("f", f, "callable")

    return filter_map_two_do(t1, t1, t2, f)
end

---Apply a function to the values of `t1` and `t2` to create a new list.
---If `t1` and `t2` are different lengths, the length of the smaller list is used.
---@generic T
---@generic U
---@generic V
---@param t1 T[]
---@param t2 U[]
---@param f fun(a:T, b:U, idx:integer): val:V|nil If val is `nil`, it will be filtered.
---@return V[] New list. Empty if all elements are filtered.
function M.filter_map_two_to(t1, t2, f)
    vim.validate("t1", t1, "table")
    vim.validate("t2", t2, "table")
    vim.validate("f", f, "callable")

    return filter_map_two_do({}, t1, t2, f)
end

---@generic T
---@param dst T[]
---@param iter_len integer
---@param sep_count integer
---@param new_len integer
---@param t T[]
---@param sep T
---@param unit_size integer? (Default: `1`)
---@see |iter-indexing|
---@param start integer? (Default: `1`)
---@param stop? integer Default: Length of `t`
---@return T[]
local function intersperse_do(dst, iter_len, sep_count, new_len, t, sep, unit_size, start, stop)
    local t_len = #t -- Duplicate. Remove when inlining.

    local post_range_len = t_len - stop
    local last_group_size = iter_len - (sep_count * unit_size)
    local tail = post_range_len + last_group_size
    local i = new_len
    local j = t_len
    for _ = 1, tail do
        dst[i] = t[j]
        i = i - 1
        j = j - 1
    end

    for _ = 1, sep_count do
        dst[i] = sep
        i = i - 1
        for _ = 1, unit_size do
            dst[i] = t[j]
            i = i - 1
            j = j - 1
        end
    end

    -- Remove when inlining.
    if dst == t then
        return dst
    end

    local pre_intersperse_len = start - 1
    for _ = 1, pre_intersperse_len do
        dst[i] = t[i]
        i = i - 1
    end

    return dst
end

---Insert `sep` every `unit_size` elements into `t` in place.
---Use with |table.concat()| to get Haskell `intercalate` logic.
---If the length of `t` is not evenly divisible by `unit_size`, the remainder will be separated
---out at the end of the list.
---Example:
---```lua
---    intersperse({ 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 }, ",", 3)
---    -- Returns { 1, 2, 3, ",", 4, 5, 6, ",", 7, 8, 9, ",", 10 }
---```
---
---Use `start` and `stop` to specify ranges within the list to intersperse `sep`.
---Example:
---```lua
---    intersperse({ 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 }, ",", 1, 1, 5)
---    -- Returns { 1, ",", 2, ",", 3, ",", 4, ",", 5, 6, 7, 8, 9, 10 }
---```
---@generic T
---@param t T[] Modified in place!
---@param sep T
---@param unit_size integer? (Default: `1`)
---@see |iter-indexing|
---@param start integer? (Default: `1`)
---@param stop? integer Default: Length of `t`
---@return T[] Original list reference
function M.intersperse(t, sep, unit_size, start, stop)
    vim.validate("t", t, "table")
    vim.validate("sep", sep, require("nvim-tools.types").not_nil)
    vim.validate("unit_size", unit_size, "number", true)

    local t_len = #t
    start = resolve_iter_index(start, t_len, 1)
    stop = resolve_iter_index(stop, t_len, t_len)
    if t_len == 0 or start >= stop then
        return t
    end

    unit_size = math.max(unit_size or 1, 1)
    local iter_len = stop - start + 1
    -- Discard unit_size >= t_len, because `sep` would be appended.
    local sep_count = math.floor((iter_len - 1) / unit_size)
    if sep_count < 1 then
        return t
    end

    local new_len = t_len + sep_count
    return intersperse_do(t, iter_len, sep_count, new_len, t, sep, unit_size, start, stop)
end
-- MID:DEP: For uneven unit sizes, you can add a `rev` boolean to put the extra group before or
-- after the main group loop. Don't do this though without a concrete use case, as it makes the
-- code more complicated.

---Create a new list with `sep` inserted into `t` every `unit_size` elements.
---Use with |table.concat()| to get Haskell `intercalate` logic.
---If the length of `t` is not evenly divisible by `unit_size`, the remainder will be separated
---out at the end of the list.
---Example:
---```lua
---    intersperse({ 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 }, ",", 3)
---    -- Returns { 1, 2, 3, ",", 4, 5, 6, ",", 7, 8, 9, ",", 10 }
---```
---
---Use `start` and `stop` to specify ranges within the list to intersperse `sep`.
---Example:
---```lua
---    intersperse({ 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 }, ",", 1, 1, 5)
---    -- Returns { 1, ",", 2, ",", 3, ",", 4, ",", 5, 6, 7, 8, 9, 10 }
---```
---@generic T
---@param t T[] Modified in place!
---@param sep T
---@param unit_size integer? (Default: `1`)
---@see |iter-indexing|
---@param start integer? (Default: `1`)
---@param stop? integer Default: Length of `t`
---@return T[] Original list reference
function M.intersperse_to(t, sep, unit_size, start, stop)
    vim.validate("t", t, "table")
    vim.validate("sep", sep, require("nvim-tools.types").not_nil)
    vim.validate("unit_size", unit_size, "number", true)

    local t_len = #t
    start = resolve_iter_index(start, t_len, 1)
    stop = resolve_iter_index(stop, t_len, t_len)
    if t_len == 0 or start >= stop then
        return M.copy(t)
    end

    unit_size = math.max(unit_size or 1, 1)
    local iter_len = stop - start + 1
    -- Discard unit_size >= t_len, because `sep` would be appended.
    local sep_count = math.floor((iter_len - 1) / unit_size)
    if sep_count < 1 then
        return M.copy(t)
    end

    local new_len = t_len + sep_count
    local res = require("nvim-tools.table").new(new_len, 0)
    return intersperse_do(res, iter_len, sep_count, new_len, t, sep, unit_size, start, stop)
end
-- MID:DEP: For uneven unit sizes, you can add a `rev` boolean to put the extra group before or
-- after the main group loop. Don't do this though without a concrete use case, as it makes the
-- code more complicated.

---Reverse the order of the items in list `t` in place.
---@generic T
---@param t T[] Modified in place!
function M.reverse(t)
    vim.validate("t", t, "table")

    local t_len = #t
    local stop = math.floor(t_len / 2)
    for i = 1, stop do
        local j = t_len + 1 - i
        t[i], t[j] = t[j], t[i]
    end
end

---Create a new list from the reversed elements of `t`.
---@generic T
---@param t T[]
---@return T[] Empty table if `t` is empty.
function M.reverse_to(t)
    vim.validate("t", t, "table")

    local t_len = #t
    if t_len == 0 then
        return {}
    end

    local ret = require("nvim-tools.table").new(t_len, 0)
    local t_len_plus_one = t_len + 1
    for i = 1, t_len do
        ret[i] = t[t_len_plus_one - i]
    end

    return ret
end

---Shift the elements of `t` in place based on `n` (the amount to shift) and `dir` (shift forward
---or backwards.)
---@generic T
---@param t T[] Modified in place.
---@param n integer Cyclically clamped at length of `t`.
---@param dir? -1|1 (Default: `-1`) -1 shifts elements left, 1 to the right.
---@return T Reference to the original list.
function M.rotate(t, n, dir)
    vim.validate("t", t, "table")
    local nty = require("nvim-tools.types")
    vim.validate("n", n, nty.is_uint)
    vim.validate("dir", dir, nty.is_int, true)

    local len = #t
    if len <= 1 then
        return t
    end

    local steps = math.abs(n) % len
    if steps == 0 then
        return t
    end

    if dir and dir > 0 then
        steps = len - steps
    end

    ---@param left integer
    ---@param right integer
    local function reverse(left, right)
        while left < right do
            t[left], t[right] = t[right], t[left]
            left = left + 1
            right = right - 1
        end
    end

    reverse(1, steps)
    reverse(steps + 1, len)
    reverse(1, len)

    return t
end

---Create a new list from the shifted elements of `t1`.
---@generic T
---@param t T[]
---@param n integer Amount of indices to shift the list. Cyclically clamped at length of `t`.
---@param dir? -1|1 (Default: `-1`) -1 shifts elements left, 1 to the right.
---@return T[] New list. Copy of the original if `n` is zero.
function M.rotate_to(t, n, dir)
    vim.validate("t", t, "table")
    local nty = require("nvim-tools.types")
    vim.validate("n", n, nty.is_uint)
    vim.validate("dir", dir, nty.is_int, true)

    local len = #t
    if len <= 1 then
        return M.copy(t)
    end

    local steps = math.abs(n) % len
    if steps == 0 then
        return M.copy(t)
    end

    if dir and dir > 0 then
        steps = len - steps
    end

    local ret = {}
    local j = 1

    for i = steps + 1, len do
        ret[j] = t[i]
        j = j + 1
    end

    for i = 1, steps do
        ret[j] = t[i]
        j = j + 1
    end

    return ret
end

---Combine `t1` and `t2` into a new list of tuples. Iteration stops at the shorter table.
---@generic T
---@generic U
---@param t1 T[]
---@param t2 U[]
---@return { [1]: T, [2]: U }[] New list. Empty if either table is length zero.
function M.zip(t1, t2)
    local len = math.min(#t1, #t2)
    local ret = {}
    for i = 1, len do
        ret[i] = { t1[i], t2[i] }
    end

    return ret
end

---Combine `t1` and `t2` into a new list of tuples. Iteration continues past the shorter list,
---using `fill` for the missing values.
---@generic T
---@generic U
---@param t1 T[]
---@param t2 U[]
---@param fill any
---@return { [1]: T, [2]: U }[] New list.
function M.zip_longest(t1, t2, fill)
    local ret = {}
    local t1_len = #t1
    local t2_len = #t2
    local len_min = math.min(t1_len, t2_len)

    for i = 1, len_min do
        ret[i] = { t1[i], t2[i] }
    end

    if t1_len > t2_len then
        for i = len_min + 1, t1_len do
            ret[i] = { t1[i], fill }
        end
    else
        for i = len_min + 1, t2_len do
            ret[i] = { fill, t2[i] }
        end
    end

    return ret
end

---Combine `t1` and `t2` into a new list of tuples, applying function `f` to their values.
---Iteration stops at the shorter table.
---@generic T
---@generic U
---@param t1 T[]
---@param t2 U[]
---@param f fun(x:T, y:U): any, any
---@return { [1]: any, [2]: any }[] New list. Empty table if either input has a length of zero.
function M.zip_with(t1, t2, f)
    local len = math.min(#t1, #t2)
    local ret = {}
    for i = 1, len do
        local v1, v2 = f(t1[i], t2[i])
        ret[i] = { v1, v2 }
    end

    return ret
end

return M
