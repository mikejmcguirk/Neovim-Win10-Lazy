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
    val = val and math.min(val, len) or default
    return val > 0 and val or math.max(len + val, 1)
end

---@param r boolean?
---@param start integer
---@param stop integer
---@return integer start, integer stop, integer step
local function resolve_r(r, start, stop)
    if r then
        return stop, start, -1
    else
        return start, stop, 1
    end
end

---@param key_fn fun(x:any): any
---@param ... any[]
---@return table<any, true> seen
local function see_in_varargs(key_fn, ...)
    local nargs = select("#", ...)
    local seen = {} ---@type table<any, boolean>
    for i = 1, nargs do
        local tn = select(i, ...)
        local tn_len = #tn
        for j = 1, tn_len do
            seen[key_fn(tn[j])] = true
        end
    end

    return seen
end

---@param key_fn fun(x: any): any
---@param ... any[]
---@return table<any, true>
local function see_in_varargs_if_in_all(key_fn, ...)
    local nargs = select("#", ...)
    if nargs == 0 then
        return {}
    end

    if nargs == 1 then
        local seen = {} ---@type table<any, true>
        local t1 = select(1, ...)
        local t1_len = #t1
        for i = 1, t1_len do
            seen[key_fn(t1[i])] = true
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
        seen[key_fn(t1[i])] = gen
    end

    for i = 1, min_idx - 1 do
        gen_prev = gen
        gen = gen + 1
        local tn = varargs[i]
        local tn_len = #tn
        for j = 1, tn_len do
            local vh = key_fn(tn[j])
            if seen[vh] == gen_prev then
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
            if seen[vh] == gen_prev then
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

---Turns two, unsorted lists into one sorted list. If the lists are already sorted,
---use |merge_sorted()|.
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

    table.sort(t1, comp)
    table.sort(t2, comp)
    return M.merge_sorted(t1, t2, comp)
end

---Performs a shallow copy of `t`.
---@generic T
---@param t T[]
---@return T[] Empty if table length is zero.
function M.copy(t)
    vim.validate("t", t, "table")

    local t_len = #t
    if t_len == 0 then
        return {}
    end

    local ret = require("nvim-tools.table").new(t_len, 0)
    for i = 1, t_len do
        ret[i] = t[i]
    end

    return ret
end

---Creates a new list.
---Merges two already sorted lists in order.
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
    vim.validate("v", v, vim.not_nil)
    vim.validate("count", count, require("nvim-tools.types").is_uint)

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
    clear_exact(dst, new_len + 1, t_len)
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
    vim.validate("init", init, vim.not_nil)
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
---     accumulator, the last table value, and the current table length. If the returned `acc`
---     value is nil, `v` is written to the new table and the function terminates. If `v` is
---     nil, the function terminates immediately.
---@return T[] The new table. Returns an empty table if the first call to `f` produces a nil value.
function M.unfold(init, f)
    vim.validate("init", init, vim.not_nil)
    vim.validate("f", f, "callable")

    local ret = {}
    local acc = init
    local v
    while true do
        local ret_len = #ret
        acc, v = f(acc, ret[ret_len], ret_len)
        if v ~= nil then
            ret[ret_len + 1] = v
        end

        if acc == nil or v == nil then
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
    vim.validate("idx", idx, "number")

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

---Clear's a table's array element.
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
    vim.validate("predicate", f, "callable")
    return filter_do(t, t, f)
end

---Create a new table without values from `t` filtered by predicate `f`.
---@generic T
---@param t T[]
---@param f fun(x:T): boolean
---@return T[] New table. If `t` is empty, an empty table will be returned.
function M.filter_to(t, f)
    vim.validate("t", t, "table")
    vim.validate("predicate", f, "callable")
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
        if not seen[vh] then
            ret[j] = v
            j = j + 1
            if vh ~= nil then
                seen[vh] = true
            end
        end
    end

    return ret
end

---@generic T
---@param t T[]
---@param f fun(x:T): boolean
---@param r? boolean
---@return integer|nil, integer|nil
local function get_keep_splice(t, f, r)
    local t_len = #t
    if t_len == 0 then
        return nil, nil
    end

    local start, stop, step = resolve_r(r, 1, t_len)
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
    if r then
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
---@param r? boolean (Default: `false`) If true, iterate from the end.
---@return T[] Original reference to `t`. Unchanged if the whole table passes the predicate.
function M.keep_while(t, f, r)
    vim.validate("t", t, "table")
    vim.validate("f", f, "callable")
    vim.validate("r", r, "boolean", true)

    local splice_start, splice_stop = get_keep_splice(t, f, r)
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
---@param r? boolean (Default: `false`) If true, iterate from the end.
---@return T[] New list. Returns a copy of `t` if all items are kept.
function M.keep_while_to(t, f, r)
    vim.validate("t", t, "table")
    vim.validate("f", f, "callable")
    vim.validate("r", r, "boolean", true)

    local splice_start, splice_stop = get_keep_splice(t, f, r)
    if not (splice_start and splice_stop) then
        return {}
    end

    return splice_do({}, t, splice_start, splice_stop)
end

---@generic T
---@param t T[]
---@param f fun(x:T): boolean
---@param r? boolean
---@return integer|nil, integer|nil
local function get_rm_splice(t, f, r)
    local t_len = #t
    if t_len == 0 then
        return nil, nil
    end

    local start, stop, step = resolve_r(r, 1, t_len)
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
    if r then
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
---@param r? boolean (Default: `false`) If true, iterate from the end.
---@return T[] Original reference to `t`. Empty if the whole table passes the predicate.
function M.rm_while(t, f, r)
    vim.validate("t", t, "table")
    vim.validate("f", f, "callable")
    vim.validate("r", r, "boolean", true)

    local splice_start, splice_stop = get_rm_splice(t, f, r)
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
---@param r? boolean (Default: `false`) If true, iterate from the end.
---@return T[] New list. Empty if the whole table passes the predicate.
function M.rm_while_to(t, f, r)
    vim.validate("t", t, "table")
    vim.validate("f", f, "callable")
    vim.validate("r", r, "boolean", true)

    local splice_start, splice_stop = get_rm_splice(t, f, r)
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
    local seen = see_in_varargs(key_fn, ...)
    local t1_len = #t1
    local j = 1
    for i = 1, t1_len do
        local v = t1[i]
        local vh = key_fn(v)
        if not seen[vh] then
            dst[j] = v
            j = j + 1
            if vh ~= nil then
                seen[vh] = true
            end
        end
    end

    if dst == t1 then
        clear_exact(dst, j, t1_len)
    end

    return dst
end

---Modifies `t1` in place!
---Remove elements from `t1` that are present in any of the varargs (XOR logic).
---`t1` is de-duplicated. Order is preserved.
---@generic T
---@param key nil|string|fun(x:any): any See: |vim.list.unique()|.
---@param t1 T[] Target list. Modified in place!
---@param ... any[]
---@return T[] The original reference to `t1`.
function M.difference(key, t1, ...)
    vim.validate("key", key, { "callable", "string" }, true)
    vim.validate("t1", t1, "table")
    local nargs = select("#", ...)
    for i = 1, nargs do
        vim.validate("tn", select(i, ...), "table")
    end

    return difference_do(t1, key, t1, ...)
end

---Get a new list containing the elements of `t1` not present in any of the varargs (XOR logic).
---`t1` is de-duplicated. Order is preserved.
---@generic T
---@param key nil|string|fun(x:any): any See: |vim.list.unique()|.
---@param t1 T[] Source list.
---@param ... any[]
---@return T[] New list.
function M.difference_to(key, t1, ...)
    vim.validate("key", key, { "callable", "string" }, true)
    vim.validate("t1", t1, "table")
    local nargs = select("#", ...)
    for i = 1, nargs do
        local tn = select(i, ...)
        vim.validate("tn", tn, "table")
    end

    return difference_do({}, key, t1, ...)
end

---@generic T
---@param dst T[]
---@param key nil|string|fun(val:any): any See: |vim.list.unique()|.
---@param t1 T[]
---@param ... any[]
---@return T[]
local function intersect_do(dst, key, t1, ...)
    local key_fn = make_key_fn(key)
    local seen = see_in_varargs_if_in_all(key_fn, ...)
    local t1_len = #t1
    local j = 1
    for i = 1, t1_len do
        local v = t1[i]
        if seen[key_fn(v)] then
            dst[j] = v
            j = j + 1
        end
    end

    if dst == t1 then
        clear_exact(dst, j, t1_len)
    end

    return dst
end

---Modifies `t1` in place.
---Keep elements in `t1` if they are present in all vararg tables (AND logic).
---Does not de-duplicate elements from `t1`. Order is preserved
---@generic T
---@param key nil|string|fun(val:any): any See: |vim.list.unique()|.
---@param t1 T[] Modified in place!
---@param ... any[]
---@return T[] Reference to the original table.
function M.intersect(key, t1, ...)
    vim.validate("key", key, { "callable", "string" }, true)
    vim.validate("t1", t1, "table")
    local nargs = select("#", ...)
    for i = 1, nargs do
        vim.validate("tn", select(i, ...), "table")
    end

    return intersect_do(t1, key, t1, ...)
end

---Create a new list from the elements in `t1` present in every vararg (AND logic).
---Does not de-duplicate elements from `t1`. Order is preserved.
---@generic T
---@param key nil|string|fun(val:any): any See: |vim.list.unique()|.
---@param t1 T[]
---@param ... any[]
---@return T[] New list.
function M.intersect_to(key, t1, ...)
    vim.validate("key", key, { "callable", "string" }, true)
    vim.validate("t1", t1, "table")
    local nargs = select("#", ...)
    for i = 1, nargs do
        vim.validate("tn", select(i, ...), "table")
    end

    return intersect_do({}, key, t1, ...)
end

---@generic T
---@param dst T[]
---@param key nil|string|fun(val:any): any See: |vim.list.unique()|.
---@param t1 T[]
---@param ... any[]
---@return T[]
local function intersection_do(dst, key, t1, ...)
    local nargs = select("#", ...)
    local key_fn = make_key_fn(key)
    local seen = {} ---@type table<any, boolean>
    for i = 1, nargs do
        local tn = select(i, ...)
        vim.validate("tn", tn, "table")

        local tn_len = #tn
        for j = 1, tn_len do
            seen[key_fn(tn[j])] = true
        end
    end

    local t1_len = #t1
    local j = 1
    for i = 1, t1_len do
        local v = t1[i]
        local vh = key_fn(v)
        if seen[vh] then
            dst[j] = v
            j = j + 1
            seen[vh] = nil
        end
    end

    if dst == t1 then
        for i = j, t1_len do
            t1[i] = nil
        end
    end

    return dst
end

---Modifies `t1` in place.
---Keep elements in `t1` if they are present in `t2` (AND logic).
---De-duplicates elements from `t1`. Order is preserved
---@generic T
---@param key nil|string|fun(val:any): any See: |vim.list.unique()|.
---@param t1 T[] Modified in place. Original order is preserved.
---@param ... any[]
---@return T[] t1 Reference to the table param.
function M.intersection(key, t1, ...)
    vim.validate("key", key, { "callable", "string" }, true)
    vim.validate("t1", t1, "table")
    local nargs = select("#", ...)
    for i = 1, nargs do
        local tn = select(i, ...)
        vim.validate("tn", tn, "table")
    end

    return intersection_do(t1, key, t1, ...)
end

---Create a new list from the elements in `t1` present in `t2` (AND logic).
---De-duplicates elements from `t1`. Order is preserved.
---@generic T
---@param key nil|string|fun(val:any): any See: |vim.list.unique()|.
---@param t1 T[] Original order is preserved.
---@param ... any[]
---@return T[] New list.
function M.intersection_to(key, t1, ...)
    vim.validate("key", key, { "callable", "string" }, true)
    vim.validate("t1", t1, "table")
    local nargs = select("#", ...)
    for i = 1, nargs do
        local tn = select(i, ...)
        vim.validate("tn", tn, "table")
    end

    return intersection_do({}, key, t1, ...)
end

---@generic T
---@param dst T[]
---@param t1 T[] Source list.
---@param ... any[]
---@param key nil|string|fun(val:any): any See: |vim.list.unique()|.
---@return any[] New list.
local function subtract_do(dst, key, t1, ...)
    local nargs = select("#", ...)
    local key_fn = make_key_fn(key)
    local seen = {} ---@type table<any, boolean>
    for i = 1, nargs do
        local tn = select(i, ...)
        local tn_len = #tn
        for j = 1, tn_len do
            seen[key_fn(tn[j])] = true
        end
    end

    local t1_len = #t1
    local j = 1
    for i = 1, t1_len do
        local v = t1[i]
        if not seen[key_fn(v)] then
            dst[j] = v
            j = j + 1
        end
    end

    if dst == t1 then
        for i = j, t1_len do
            t1[i] = nil
        end
    end

    return dst
end

---Modifies `t1` in place.
---Remove elements from `t1` that are present in any of the varargs (XOR logic).
---No additional de-duplication in `t1`. Order is preserved.
---@generic T
---@param t1 T[] Target list. Modified in place.
---@param ... any[]
---@param key nil|string|fun(val:any): any See: |vim.list.unique()|.
---@return T[] The original reference to `t1`.
function M.subtract(key, t1, ...)
    vim.validate("key", key, { "callable", "string" }, true)
    vim.validate("t1", t1, "table")
    local nargs = select("#", ...)
    for i = 1, nargs do
        local tn = select(i, ...)
        vim.validate("tn", tn, "table")
    end

    return subtract_do(t1, key, t1, ...)
end

---Remove elements from `t1` that are present in any of the varargs (XOR logic).
---No additional de-duplication in `t1`. Order is preserved.
---@generic T
---@param key nil|string|fun(val:any): any See: |vim.list.unique()|.
---@param t1 T[] Source list.
---@param ... any[]
---@return T[] New list.
function M.subtract_to(key, t1, ...)
    vim.validate("t1", t1, "table")
    local nargs = select("#", ...)
    for i = 1, nargs do
        local tn = select(i, ...)
        vim.validate("tn", tn, "table")
    end

    vim.validate("key", key, { "callable", "string" }, true)
    return subtract_do({}, key, t1, ...)
end

--- Creates a new list based on the values in all lists (OR logic).
--- Elements in all lists are de-duped. Order is preserved.
---@param key nil|string|fun(val:any): any See: |vim.list.unique()|.
---@param ... any[]
---@return any[]
function M.union_to(key, ...)
    vim.validate("key", key, { "callable", "string" }, true)

    local nargs = select("#", ...)
    local key_fn = make_key_fn(key)
    local seen = {} ---@type table<any, boolean>
    local ret = {}

    for i = 1, nargs do
        local tn = select(i, ...)
        vim.validate("tn", tn, "table")

        local tn_len = #tn
        for j = 1, tn_len do
            local v = tn[j]
            local vh = key_fn(v)
            if not seen[vh] then
                ret[#ret + 1] = v
                if vh ~= nil then
                    seen[vh] = true
                end
            end
        end
    end

    return ret
end

---Returns a new list of items that are only present in one of the lists. (XOR logic).
---Duplicates are kept. Original ordering is preserved.
---@param key nil|string|fun(val:any): any See: |vim.list.unique()|.
---@param ... any[]
---@return any[]
function M.xor(key, ...)
    vim.validate("key", key, { "callable", "string" }, true)

    local nargs = select("#", ...)
    local key_fn = make_key_fn(key)
    local seen = {} ---@type table<any, integer>
    for i = 1, nargs do
        local tn = select(i, ...)
        vim.validate("tn", tn, "table")

        local tn_len = #tn
        for j = 1, tn_len do
            local vh = key_fn(tn[j])
            local was_seen = seen[vh]
            if was_seen == nil then
                seen[vh] = i
            elseif not (seen == i) then
                seen[vh] = 0
            end
        end
    end

    local ret = {} ---@type any[]
    for i = 1, nargs do
        local tn = select(i, ...)
        local tn_len = #tn
        for j = 1, tn_len do
            local v = tn[j]
            if seen[key_fn(v)] == i then
                ret[#ret + 1] = v
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

    local nargs = select("#", ...)
    local key_fn = make_key_fn(key)
    local seen = {} ---@type table<any, integer>
    for i = 1, nargs do
        local tn = select(i, ...)
        vim.validate("tn", tn, "table")

        local tn_len = #tn
        for j = 1, tn_len do
            local vh = key_fn(tn[j])
            local was_seen = seen[vh]
            if was_seen == nil then
                seen[vh] = i
            elseif not (seen == i) then
                seen[vh] = 0
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
            if seen[vh] == i then
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

---@generic T
---@param t T[]
---@param f fun(x: T): boolean
---@return boolean all_pass, integer? bad_idx, T? bad_item On failure, the problem index and
---     value are returned.
function M.all(t, f)
    vim.validate("t", t, "table")
    vim.validate("f", f, "callable")

    local len = #t
    for i = 1, len do
        if not f(t[i]) then
            return false, i, t[i]
        end
    end

    return true
end

---@generic T
---@param t T[]
---@param v T|fun(x:T): boolean
---@return boolean
function M.any(t, v)
    vim.validate("t", t, "table")
    vim.validate("v", v, require("nvim-tools.types").not_nil)

    local predicate = type(v) == "function" and v or function(x)
        return x == v
    end

    local t_len = #t
    for i = 1, t_len do
        if predicate(t[i]) then
            return true
        end
    end

    return false
end

---Compare elements of t1 and t2. By default, checks for shallow equality.
---If t1 and t2 are of different lengths, the shorter length is used for iteration.
---Returns false if either table has length zero.
---On failure, returns the problem index and values.
---
---This function can be used to create:
---- eq/ne
---- lt/gt
---@generic T
---@generic U
---@param t1 T[]
---@param t2 U[]
---@param predicate? fun(a:T, b:U): boolean
---@return boolean ok, integer? idx, T? v1, U? v2
function M.cmp(t1, t2, predicate)
    vim.validate("t", t1, "table")
    vim.validate("t", t2, "table")
    vim.validate("predicate", predicate, "callable", true)

    predicate = predicate or function(a, b)
        return a == b
    end

    local len = math.min(#t1, #t2)
    if len == 0 then
        return false
    end

    for i = 1, len do
        if not predicate(t1[i], t2[i]) then
            return false, i, t1[i], t2[i]
        end
    end

    return true
end

---@generic T
---@param t T[]
---@param v T|fun(x:T): boolean
---@param r? boolean (Default: `false`) If true, iterate from the end.
---@return T? `nil` if not found.
function M.find(t, v, r)
    vim.validate("t", t, "table")
    vim.validate("v", v, require("nvim-tools.types").not_nil)
    vim.validate("r", r, "boolean", true)

    local t_len = #t
    local start, stop, step = resolve_r(r, 1, t_len)
    local predicate = type(v) == "function" and v or function(x)
        return x == v
    end

    for i = start, stop, step do
        if predicate(t[i]) then
            return t[i]
        end
    end
end

---@generic T
---@param t T[]
---@param v T|fun(x:T): boolean
---@return integer[] Empty table if no results.
function M.indices(t, v)
    vim.validate("t", t, "table")
    vim.validate("v", v, require("nvim-tools.types").not_nil)

    local t_len = #t
    local ret = {} ---@type integer[]
    local predicate = type(v) == "function" and v or function(x)
        return x == v
    end

    for i = 1, t_len do
        if predicate(t[i]) then
            ret[#ret + 1] = i
        end
    end

    return ret
end

---@generic T
---@param t T[]
---@param v T|fun(x:T): boolean
---@return boolean
function M.one(t, v)
    vim.validate("t", t, "table")
    vim.validate("v", v, vim.not_nil)

    local predicate = type(v) == "function" and v or function(x)
        return x == v
    end

    local t_len = #t
    local seen = false
    for i = 1, t_len do
        if predicate(t[i]) then
            if seen then
                return false
            end

            seen = true
        end
    end

    return seen
end

---@generic T
---@param t T[]
---@param v T|fun(x:T): boolean
---@param r? boolean (Default: `false`) If true, iterate from the end.
---@return integer? Index of the found item.
function M.position(t, v, r)
    vim.validate("t", t, "table")
    vim.validate("v", v, require("nvim-tools.types").not_nil)
    vim.validate("r", r, "boolean", true)

    local t_len = #t
    local start, stop, step = resolve_r(r, 1, t_len)
    local predicate = type(v) == "function" and v or function(x)
        return x == v
    end

    for i = start, stop, step do
        if predicate(t[i]) then
            return i
        end
    end

    return 0
end

---Are all elements in the list the same?
---@generic T
---@param t T[]
---@return boolean
function M.same(t)
    vim.validate("t", t, "table")

    local t_len = #t
    if t_len == 0 then
        return false
    end

    local v = t[1]
    for i = 2, t_len do
        if t[i] ~= v then
            return false
        end
    end

    return true
end
-- TODO: Isn't this just "all"?

---@generic T
---@param t T[]
---@param v T|fun(x:T): boolean
---@return boolean[]
function M.selectors(t, v)
    vim.validate("t", t, "table")
    vim.validate("v", v, require("nvim-tools.types").not_nil)

    local t_len = #t
    local ret = {} ---@type boolean[]
    local predicate = type(v) == "function" and v or function(x)
        return x == v
    end

    for i = 1, t_len do
        ret[#ret + 1] = predicate(t[i]) and true or false
    end

    return ret
end

-----------------------------
-- MARK: List to New Value --
-----------------------------

---Apply a function to all elements of a list, transforming them into a single value.
---
---@generic T
---@generic U
---@param t T[]
---@param f fun(acc:U, x:T, idx:integer): acc:U|nil, v:T?
---     If the acc return is nil, the last accumulator value is returned.
---     If the v return has a value, the function is stopped and v is returned.
---     If the loop reaches the end of the list, the last acc value is returned.
---@param init U|nil First accumulator value. If nil, the first list item will be used
---(reduce behavior).
---@param r boolean|nil (Default: `false`) If true, iterate from the end.
---@return T|U `init` if `t` is length zero.
function M.fold(t, f, init, r)
    vim.validate("t", t, "table")
    vim.validate("f", f, "callable")
    vim.validate("r", r, "boolean", true)

    local t_len = #t
    if t_len == 0 then
        return init
    end

    local start, stop, step = resolve_r(r, 1, t_len)
    ---@generic U
    local acc_ret ---@type U
    if init ~= nil then
        acc_ret = init
    else
        acc_ret = t[1]
        start = start + step
    end

    for i = start, stop, step do
        local acc, v = f(acc_ret, t[i], i)
        if v ~= nil then
            return v
        elseif acc ~= nil then
            acc_ret = acc
        else
            return acc_ret
        end
    end

    return acc_ret
end

---Apply a function to all elements of a list, transforming them into a running list of the
---accumulated values.
---
---Can be used to make any sort of cumulative sum/product/min/max function.
---
---@generic T
---@generic U
---@param t T[]
---@param f fun(acc:U, x:T, idx:integer): acc:U|nil, v:T?
---     If acc is nil, `v` will be written and then the function will end
---     If `v` is nil, the function ends.
---accumulator at its present state.
---@param init U|nil First accumulator value. If nil, the first list item will be used
---(reduce behavior).
---@param r boolean|nil (Default: `false`) If true, iterate from the end.
---@return U `init` if `t` is length zero.
function M.scan(t, f, init, r)
    vim.validate("t", t, "table")
    vim.validate("f", f, "callable")
    vim.validate("r", r, "boolean", true)

    local t_len = #t
    if t_len == 0 then
        return init
    end

    local start, stop, step = resolve_r(r, 1, t_len)
    ---@generic U
    local ret ---@type U[]
    local acc
    local v
    if init ~= nil then
        ret = { init }
        acc = init
    else
        v = t[1]
        ret = { v }
        acc = v
        start = start + step
    end

    for i = start, stop, step do
        acc, v = f(ret[#ret], t[i], i)
        -- TODO: This makes no sense to begin with, and it also needs to act like "unfold".
        if acc == nil then
            ret[#ret + 1] = acc
            return ret
        elseif v == nil then
            return ret
        else
            ret[#ret + 1] = v
        end
    end

    return ret
end

---------------------------
-- MARK: List Transforms --
---------------------------

---@generic T: table
---@param dst T Modified in place. List appended to.
---@param src table
---@See Info on |iter-indexing|
---@param init integer? src start index. `1` if nil.
---@param fin? integer src end index. `len` if nil.
---@return T dst Reference to the original list.
function M.list_extend(dst, src, init, fin)
    vim.validate("dst", dst, "table")
    vim.validate("src", src, "table")
    local is_uint = require("nvim-tools.types").is_uint
    vim.validate("start", init, is_uint, true)
    vim.validate("finish", fin, is_uint, true)

    local src_len = #src
    if src_len == 0 then
        return dst
    end

    local start = resolve_iter_index(init, src_len, 1)
    local stop = resolve_iter_index(fin, src_len, src_len)
    if start > stop then
        return dst
    end

    for i = start, stop do
        dst[#dst + 1] = src[i]
    end

    return dst
end

---Modifies `t` in place.
---@generic T
---@param t T[] Modified in place.
---@param v any Value to place in all list indices.
---@param start integer? (Default: `1`)
---@param stop? integer Default: Length of `t`
function M.fill(t, v, start, stop)
    vim.validate("t", t, "table")
    local is_int = require("nvim-tools.types").is_int
    vim.validate("start", start, is_int, true)
    vim.validate("stop", stop, is_int, true)

    local t_len = #t
    start = resolve_iter_index(start, t_len, 1)
    stop = resolve_iter_index(stop, t_len, t_len)
    if start > stop then
        return {}
    end

    for i = start, stop do
        t[i] = v
    end
end

---Modifies `t` in place!
---@generic T
---@generic U
---@param t T[] Modified in place!
---@param f fun(x: T, idx:integer): U Correct idx is preserved when filtering.
---@return U[] The original list reference containing the new, possibly filtered, values.
function M.filter_map(t, f)
    vim.validate("t", t, "table")
    vim.validate("f", f, "callable")

    local len = #t
    local j = 1
    for i = 1, len do
        t[j] = f(t[i], i)
        if t[j] ~= nil then
            j = j + 1
        end
    end

    for i = j, len do
        t[i] = nil
    end

    return t
end

---Creates a new list.
---@generic T
---@generic U
---@param t T[]
---@param f fun(x:T, idx:integer): U
---@return U[] New table.
function M.filter_map_to(t, f)
    vim.validate("t", t, "table")
    vim.validate("f", f, "callable")

    local t_len = #t
    local ret = {}
    for i = 1, t_len do
        ret[#ret + 1] = f(t[i], i)
    end

    return ret
end

---Modifies `t` in place!
---@generic T
---@generic U
---@generic V
---@param t T[] Modified in place!
---@param init V
---@param f fun(acc:V, value:T, idx:integer): V, U|nil Receives the current accumulator, the
---     currently iterated list value, and the currently iterated index. If `nil` is returned for
---     the list value, it will be filtered.
---@return T[] The original list reference containing the new, possibly filtered, values.
function M.filter_map_accum(t, init, f)
    vim.validate("t", t, "table")
    vim.validate("init", init, vim.not_nil)
    vim.validate("f", f, "callable")

    local len = #t
    local j = 1
    local acc = init
    for i = 1, len do
        acc, t[j] = f(acc, t[i], i)
        if t[j] ~= nil then
            j = j + 1
        end
    end

    for i = j, len do
        t[i] = nil
    end

    return t
end

--- Maps over `t` while threading an accumulator, returning a new list.
---@generic T
---@generic U
---@generic V
---@param init V
---@param t T[]
---@param f fun(acc:V, value:T, idx:integer): V, U|nil Receives the current accumulator, the
---     currently iterated list value, and the currently iterated index. If `nil` is returned for
---     the list value, it will be filtered.
---@return U[] The newly mapped list.
function M.filter_map_accum_to(t, init, f)
    vim.validate("init", init, vim.not_nil)
    vim.validate("t", t, "table")
    vim.validate("f", f, "callable")

    local ret = {}
    local acc = init
    local t_len = #t
    for i = 1, t_len do
        acc, ret[i] = f(acc, t[i], i)
    end

    return ret
end

---Modifies `t1` in place.
---Can be used for:
---- Using booleans in `t` to filter `t1`.
---
---@generic T
---@generic U
---@generic V
---@param t1 T[] Modified in place. Truncated if longer than t.
---@param t2 U[]
---@param f fun(a: T, b: U): V
function M.filter_map_two(t1, t2, f)
    vim.validate("t1", t1, "table")
    vim.validate("t2", t2, "table")
    vim.validate("f", f, "callable")

    local len = math.min(#t1, #t2)
    local j = 1
    for i = 1, len do
        local v = f(t1[i], t2[i])
        if v ~= nil then
            t1[j] = v
            j = j + 1
        end
    end

    for i = len + 1, #t1 do
        t1[i] = nil
    end
end

---@generic T
---@generic U
---@generic V
---@param t1 T[] Modified in place. Truncated if longer than t2.
---@param t2 U[]
---@param f fun(a: T, b: U): V
---@return V[]
function M.filter_map_two_to(t1, t2, f)
    vim.validate("t1", t1, "table")
    vim.validate("t2", t2, "table")
    vim.validate("f", f, "callable")

    local len = math.min(#t1, #t2)
    local ret = {}
    for i = 1, len do
        ret[i] = f(t1[i], t2[i])
    end

    return ret
end

---@generic T
---@param t T[] Modified in place.
function M.reverse(t)
    vim.validate("t", t, "table")

    local t_len = #t
    local stop = math.floor(t_len / 2)
    for i = 1, stop do
        local j = t_len + 1 - i
        t[i], t[j] = t[j], t[i]
    end
end

---Creates a new list.
---@generic T
---@param t T[]
---@return T[]
function M.reverse_to(t)
    vim.validate("t", t, "table")

    local t_len = #t
    ---@generic T
    local ret = require("nvim-tools.table").new(t_len, 0) ---@type T[]
    for i = t_len, 1, -1 do
        ret[i] = t[i]
    end

    return ret
end

---@generic T
---@param t T[] Modified in place.
---@param n integer Cyclically clamped at length of `t`.
---@param dir? -1|1 (Default: `-1`) -1 shifts elements left, 1 to the right.
function M.rotate(t, n, dir)
    vim.validate("t", t, "table")
    local nty = require("nvim-tools.types")
    vim.validate("n", n, nty.is_uint)
    vim.validate("dir", dir, nty.is_int, true)

    local len = #t
    if len <= 1 then
        return
    end

    local steps = math.abs(n) % len
    if steps == 0 then
        return
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
end

---@generic T
---@param t T[]
---@param n integer Cyclically clamped at length of `t`.
---@param dir? -1|1 (Default: `-1`) -1 shifts elements left, 1 to the right.
---@return T[] Copy of the original table if `n` is zero.
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

---Creates a new list. Stops at the shorter of the two input lists.
---
---@generic T
---@generic U
---@param t1 T[]
---@param t2 U[]
---@return { [1]: T, [2]: U }[] New list.
function M.zip(t1, t2)
    local len = math.min(#t1, #t2)
    local ret = {}
    for i = 1, len do
        ret[i] = { t1[i], t2[i] }
    end

    return ret
end

---Creates a new list. Stops at the shorter of the two input lists.
---
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

---@generic T
---@generic U
---@param t1 T[]
---@param t2 U[]
---@param f fun(x:T, y:U): any, any
---@return { [1]: any, [2]: any }[] New list.
function M.zip_with(t1, t2, f)
    local len = math.min(#t1, #t2)
    local ret = {}
    for i = 1, len do
        local v1, v2 = f(t1[i], t2[i])
        ret[i] = { v1, v2 }
    end

    return ret
end
-- TODO: Want more sophistication around how different list lengths are handled. Do you have the
-- option to start the longer list later? Do you provide a func or opt to let the longer one
-- run?

return M
