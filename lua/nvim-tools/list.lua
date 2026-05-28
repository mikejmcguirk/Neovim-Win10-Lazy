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

---Copied from Neovim core.
---@generic T
---@param key? string|fun(val: T): any
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
        return start, stop, 1
    else
        return stop, start, -1
    end
end

-------------------------
-- MARK: List Creation --
-------------------------

---Performs a shallow copy of `t`.
---
---@generic T
---@param t T[]
---@see |iter-indexing|
---@param start integer? (Default: `1`)
---@param stop? integer Default: Length of `t`
---@return T[] Empty if table length is zero or the provided `start` and `stop` values resolve
---     to an invalid iteration.
function M.copy(t, start, stop)
    vim.validate("t", t, "table")
    local is_int = require("nvim-tools.types").is_int
    vim.validate("start", start, is_int, true)
    vim.validate("stop", stop, is_int, true)

    local t_len = #t
    if t_len == 0 then
        return {}
    end

    start = resolve_iter_index(start, t_len, 1)
    stop = resolve_iter_index(stop, t_len, t_len)
    if start > stop then
        return {}
    end

    local ret = require("nvim-tools.table").new(stop - start + 1, 0)
    local j = 1
    for i = start, stop do
        ret[j] = t[i]
        j = j + 1
    end

    return ret
end
-- TODO: `t` should be the last var.

---Splits `t` at the resolved index.
---Modifies `t` in place so it becomes the left side (elements up to and including `idx`).
---Returns the right side (elements after `idx`) as a new table.
---@generic T
---@see |iter-indexing|
---@param idx integer
---@param t T[] Modified in place!
---@return T[] t, T[] right `t` references the original input variable. `right` is a new table.
function M.split_at(idx, t)
    local is_int = require("nvim-tools.types").is_int
    vim.validate("idx", idx, is_int, true)
    vim.validate("t", t, "table")

    local t_len = #t
    if t_len == 0 then
        return t, {}
    end

    local pos = resolve_iter_index(idx, t_len, t_len)
    if pos >= t_len then
        return t, {}
    end

    if pos < 1 then
        local right = M.copy(t)
        for i = 1, t_len do
            t[i] = nil
        end

        return t, right
    end

    local right = require("nvim-tools.table").new(t_len - pos, 0)
    local j = 1
    for i = pos + 1, t_len do
        right[j] = t[i]
        j = j + 1
    end

    for i = pos + 1, t_len do
        t[i] = nil
    end

    return t, right
end

---Returns two new tables split at the resolved index.
---@generic T
---@param idx integer
---@param t T[]
---@return T[], T[] left side, right side
function M.split_at_to(idx, t)
    vim.validate("t", t, "table")
    local is_int = require("nvim-tools.types").is_int
    vim.validate("idx", idx, is_int, true)

    local t_len = #t
    if t_len == 0 then
        return {}, {}
    end

    local pos = resolve_iter_index(idx, t_len, t_len)
    local ntl = require("nvim-tools.table")
    local left = ntl.new(pos, 0)
    local j = 1
    for i = 1, pos do
        left[j] = t[i]
        j = j + 1
    end

    local right = ntl.new(t_len - pos, 0)
    j = 1
    for i = pos + 1, t_len do
        right[j] = t[i]
        j = j + 1
    end

    return left, right
end

---Creates a new list.
---Merges two already sorted lists in order.
---@generic T
---@param t1 T[]
---@param t2 T[]
---@param comp? fun(a: T, b: T): boolean Default: Ascending order. Compatible with |table.sort()|.
---@return T[]
function M.merge_sorted(t1, t2, comp)
    vim.validate("t1", t1, "table")
    vim.validate("t2", t2, "table")
    vim.validate("comp", comp, "function", true)

    local i, j, k = 1, 1, 1
    local len1 = #t1
    local len2 = #t2
    local ret = {}
    comp = comp or function(a, b)
        return a < b
    end

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

---@generic T
---@param t T[]
---@param predicate fun(val: T): boolean
---@return T[] passing
---@return T[] failing
local function partition_do(dst, t, predicate)
    local t_len = #t
    local j = 1
    local failing = {}
    for i = 1, t_len do
        local v = t[i]
        if predicate(v) then
            dst[j] = v
            j = j + 1
        else
            failing[#failing + 1] = v
        end
    end

    if dst == t then
        for i = j, t_len do
            t[i] = nil
        end
    end

    return dst, failing
end

---Create new lists based on elements that pass and fail a predicate function.
---Relative order is preserved.
---@generic T
---@param t T[] Modified in place
---@param predicate fun(val: T): boolean
---@return T[] passing
---Original reference to the modified list of passing elements.
---@return T[] failing
---Elements that failed the predicate.
function M.partition_to(t, predicate)
    vim.validate("t", t, "table")
    vim.validate("predicate", predicate, "callable")
    return partition_do(t, t, predicate)
end

---The original list is modified in place to contain only the passing elements.
---The failing elements are returned in a new list.
---Relative order is preserved in both resulting lists.
---@generic T
---@param t T[] Modified in place
---@param predicate fun(val: T): boolean
---@return T[] passing Original reference to the modified list of passing elements.
---@return T[] failing Elements that failed the predicate.
function M.partition(t, predicate)
    vim.validate("t", t, "table")
    vim.validate("predicate", predicate, "callable")
    return partition_do(t, t, predicate)
end

---Does not copy table references.
---@generic T
---@param v T
---@param count integer
---@return T[] New table.
function M.replicate(v, count)
    vim.validate("v", v, vim.nonnil)
    vim.validate("count", count, require("nvim-tools.types").is_uint)

    local t = require("nvim-tools.table").new(count, 0)
    for i = 1, count do
        t[i] = v
    end

    return t
end

---@generic T
---@param dst T[]
---@param t T[]
---@see |iter-indexing|
---@param start integer?
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
        return dst
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
        dst[i] = nil
    end

    return dst
end

---Get a subset of `t` by start and stop indices.
---
---No-op if `t` is length zero or the provided `start` and `stop` values resolve to an invalid
---iteration.
---
---@generic T
---@param t T[] Modified in place
---@see |iter-indexing|
---@param start integer?
---@param stop? integer
---@return T[] Reference to `t`.
function M.splice(t, start, stop)
    vim.validate("t", t, "table")
    local is_int = require("nvim-tools.types").is_int
    vim.validate("start", start, is_int, true)
    vim.validate("stop", stop, is_int, true)

    return splice_do(t, t, start, stop)
end

---Get a subset of `t` by start and stop indices.
---
---Creates a new list.
---
---Returns an empty table if `t` is length zero or the provided `start` and `stop` values resolve
---to an invalid iteration.
---
---@generic T
---@param t T[] Modified in place
---@see |iter-indexing|
---@param start integer?
---@param stop? integer
---@return T[] Reference to `t`.
function M.splice_to(t, start, stop)
    vim.validate("t", t, "table")
    local is_int = require("nvim-tools.types").is_int
    vim.validate("start", start, is_int, true)
    vim.validate("stop", stop, is_int, true)

    return splice_do({}, t, start, stop)
end

---Create a new list, starting from a seed value.
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
---@param f fun(last:T): T|nil Provides the current last value of the list. The return value is
---     appended to the list. If the return is nil, the list building ends.
---@return T[] The new table.
function M.successors(init, f)
    vim.validate("init", init, vim.nonnil)
    vim.validate("f", f, "callable")

    local t = { init }
    while true do
        local t_len = #t
        local v = f(t[t_len])
        if v ~= nil then
            t[t_len + 1] = v
        else
            return t
        end
    end
end

---@generic T
---@generic U
---@param init U
---@param f fun(acc:U, last:T|nil): acc:U, v:T|nil Exits the function if `v` is nil.
---@return T[] The new table. Returns an empty table if the first call to `f` produces a nil value.
function M.unfold(init, f)
    vim.validate("init", init, vim.nonnil)
    vim.validate("f", f, "callable")

    local acc = init
    local v
    local t = {}
    acc, v = f(acc, nil)
    if v == nil then
        return t
    end

    t[1] = v
    while true do
        local t_len = #t
        acc, v = f(acc, t[t_len])
        if v == nil then
            return t
        end

        t[t_len + 1] = v
    end
end

------------------------------
-- MARK: Indexing Functions --
------------------------------

---@see |iter-indexing|
---@generic T
---@param t T[]
---@param idx integer
---@return any The value at the index.
function M.at(t, idx)
    vim.validate("t", t, "table")
    local nty = require("nvim-tools.types")
    vim.validate("idx", idx, nty.is_int)

    local t_len = #t
    local res_idx = resolve_iter_index(idx, t_len, t_len)
    return t[res_idx]
end

--- Returns an iterator that infinitely cycles through `t`.
--- Each step yields: `idx` (1-based index within the cycle), `value`, `cycle`
--- (0-based full cycles completed).
---@generic T
---@param t T[]
---@return fun(): integer, T, integer
function M.cycle(t)
    vim.validate("t", t, "table")

    local len = #t
    if len == 0 then
        return function()
            return nil
        end
    end

    local i = 0
    return function()
        i = i + 1
        local idx = ((i - 1) % len) + 1
        local cycle = math.floor((i - 1) / len)
        return idx, t[idx], cycle
    end
end

---@generic T
---@param t T[]
---@param idx integer
function M.drain(t, idx)
    vim.validate("t", t, "table")
    vim.validate("idx", idx, "number")

    local t_len = #t
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

---@see |iter-indexing|
---@generic T
---@param t T[]
---@param v T
---@param idx? integer If no index, append to the end like |table.insert()|
function M.insert_at(t, v, idx)
    vim.validate("t", t, "table")
    local nty = require("nvim-tools.types")
    vim.validate("v", v, nty.nonnil)
    vim.validate("idx", idx, nty.is_int)

    local t_len = #t
    if not idx then
        t[t_len + 1] = idx
        return
    end

    local res_idx = resolve_iter_index(idx, t_len, t_len)
    local stop = res_idx + 1
    t[t_len + 1] = t[t_len]
    for i = t_len, stop, -1 do
        t[i] = t[i - 1]
    end

    t[res_idx] = v
end
-- TODO: Verify that this is faster than table.insert. Maybe worth writing up some kind of
-- real test and saving the code.

---Example:
---```lua
----- Re-create `delete()` functionality:
---local foo = { 1, 2, 3, 4, 5 }
---remove(foo, position(foo, 3))
----- foo is now { 1, 2, 4, 5 }
---```
---
---@see |drain()| to additionally return the deleted element.
---@generic T
---@param t T[]
---@param idx integer
function M.remove_at(t, idx)
    vim.validate("t", t, "table")
    vim.validate("idx", idx, "number")

    local t_len = #t
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

---Clear the array element of a table only.
---@generic T
---@param t T[]
function M.clear(t)
    vim.validate("t", t, "table")

    local len = #t
    for i = 1, len do
        t[i] = nil
    end
end

---@generic T
---@param dst T[]
---@param t T[]
---@param key? string|fun(val: T): any
local function dedup_consecutive_do(dst, t, key)
    local src_len = #t
    if src_len <= 1 then
        return dst
    end

    local key_fn = make_key_fn(key)
    dst[1] = t[1]
    local prev_vh = key_fn(dst[1])
    local j = 1
    for i = 2, src_len do
        local v = t[i]
        local vh = key_fn(v)
        if vh ~= prev_vh then
            dst[j] = v
            j = j + 1
            prev_vh = vh
        end
    end

    if t == dst then
        for i = j, src_len do
            t[i] = nil
        end
    end

    return dst
end

---Filter duplicates only if they're consecutive.
---@generic T
---@param t T[] Modified in place.
---@param key? string|fun(val: T): any
---@return T[] Original reference to `t`
function M.dedup_consecutive(t, key)
    vim.validate("t", t, "table")
    vim.validate("key", key, { "callable", "string" }, true)
    return dedup_consecutive_do(t, t, key)
end

---Filter duplicates only if they're consecutive.
---@generic T
---@param t T[]
---@param key? string|fun(val: T): any
---@return T[] New and de-duped list.
function M.dedup_consecutive_to(t, key)
    vim.validate("t", t, "table")
    vim.validate("key", key, { "callable", "string" }, true)
    return dedup_consecutive_do({}, t, key)
end

---Modifies `t` in place!
---@generic T
---@see |iter-indexing|
---@param start integer? (Default: `1`)
---@param stop? integer Default: Length of `t`
---@param t T[] Modified in place!
---@param predicate fun(x: T): boolean
---@return T[] The original list reference
function M.filter(start, stop, t, predicate)
    local is_int = require("nvim-tools.types").is_int
    vim.validate("start", start, is_int, true)
    vim.validate("stop", stop, is_int, true)
    vim.validate("t", t, "table")
    vim.validate("predicate", predicate, "callable")

    local t_len = #t
    if t_len == 0 then
        return t
    end

    start = resolve_iter_index(start, t_len, 1)
    stop = resolve_iter_index(stop, t_len, t_len)
    if start > stop then
        return t
    end

    local j = start
    for i = start, stop do
        local v = t[i]
        if predicate(v) then
            t[j] = v
            j = j + 1
        end
    end

    local stop_after = stop + 1
    if j == stop_after then
        return t
    end

    for i = stop_after, t_len do
        t[j] = t[i]
        j = j + 1
    end

    for i = j, t_len do
        t[i] = nil
    end

    return t
end

---@generic T
---@see |iter-indexing|
---@param start integer? (Default: `1`)
---@param stop? integer Default: Length of `t`
---@param t T[]
---@param predicate fun(x: T): boolean
---@return T[] New table
function M.filter_to(start, stop, t, predicate)
    local is_int = require("nvim-tools.types").is_int
    vim.validate("start", start, is_int, true)
    vim.validate("stop", stop, is_int, true)
    vim.validate("t", t, "table")
    vim.validate("predicate", predicate, "callable")

    local t_len = #t
    if t_len == 0 then
        return {}
    end

    start = resolve_iter_index(start, t_len, 1)
    stop = resolve_iter_index(stop, t_len, t_len)
    if start > stop then
        return M.copy(t)
    end

    local ret = {}
    for i = 1, start - 1 do
        ret[i] = t[i]
    end

    local j = start
    for i = start, stop do
        local v = t[i]
        if predicate(v) then
            ret[j] = v
            j = j + 1
        end
    end

    for i = stop + 1, t_len do
        ret[j] = t[i]
        j = j + 1
    end

    return ret
end

---Filter duplicates. See |vim.list.unique()| for the in-place version.
---@generic T
---@param t T[]
---@param key? string|fun(val:T): any See: |vim.list.unique()|.
---@return T[] New and de-duped table.
function M.unique_to(t, key)
    vim.validate("t", t, "table")
    vim.validate("key", key, { "callable", "string" }, true)

    local t_len = #t
    local key_fn = make_key_fn(key)
    local seen = {} --- @type table<any,boolean>
    local ret = {}
    local j = 1

    for i = 1, t_len do
        local v = t[i]
        local vh = key_fn(v)
        if not seen[vh] then
            ret[j] = v
            if vh ~= nil then
                seen[vh] = true
            end
            j = j + 1
        end
    end

    return ret
end

---Modifies `t` in place!
---@generic T
---@param t T[] Modified in place!
---@param f fun(x:T): boolean
---@param r? boolean (Default: `false`) If true, iterate from the end.
---@return T[] Original reference to `t`.
function M.keep_while(t, f, r)
    vim.validate("t", t, "table")
    vim.validate("f", f, "callable")
    vim.validate("r", r, "boolean", true)

    local t_len = #t
    if t_len == 0 then
        return t
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
        return t
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

    return splice_do(t, t, splice_start, splice_stop)
end

---@generic T
---@param t T[]
---@param f fun(x:T): boolean
---@param r? boolean (Default: `false`) If true, iterate from the end.
---@return T[] New list.
function M.keep_while_to(t, f, r)
    vim.validate("t", t, "table")
    vim.validate("f", f, "callable")
    vim.validate("r", r, "boolean", true)

    local t_len = #t
    if t_len == 0 then
        return {}
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
        return M.copy(t)
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

    return splice_do({}, t, splice_start, splice_stop)
end

---Modifies `t` in place!
---@generic T
---@param t T[] Modified in place!
---@param f fun(x:T): boolean
---@param r? boolean (Default: `false`) If true, iterate from the end.
---@return T[] Original reference to `t`.
function M.rm_while(t, f, r)
    vim.validate("t", t, "table")
    vim.validate("f", f, "callable")
    vim.validate("r", r, "boolean", true)

    local t_len = #t
    if t_len == 0 then
        return t
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
        return t
    end

    local splice_start
    local splice_stop
    if r then
        splice_start = 1
        splice_stop = pos - 1
    else
        splice_start = pos + 1
        splice_stop = t_len
    end

    return splice_do(t, t, splice_start, splice_stop)
end

---@generic T
---@param t T[]
---@param f fun(x:T): boolean
---@param r? boolean (Default: `false`) If true, iterate from the end.
---@return T[] New list.
---@overload fun(t:any[], r:fun(x:any): boolean): any[]
function M.rm_while_to(t, f, r)
    vim.validate("t", t, "table")
    vim.validate("f", f, "callable")
    vim.validate("r", r, "boolean", true)

    local t_len = #t
    if t_len == 0 then
        return {}
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
        return M.copy(t)
    end

    local splice_start
    local splice_stop
    if r then
        splice_start = 1
        splice_stop = pos - 1
    else
        splice_start = pos + 1
        splice_stop = t_len
    end

    return splice_do({}, t, splice_start, splice_stop)
end

-----------------------------------
-- MARK: List and List Filtering --
-----------------------------------

---Appends n lists args to `t1`. (OR logic).
---Performs a shallow copy of the appended lists.
---@generic T
---@param t1 T[] Modified in place.
---@param ... any[]
---@return any[] All lists chained together.
function M.chain(t1, ...)
    vim.validate("t1", t1, "table")

    local nargs = select("#", ...)
    for i = 1, nargs do
        local tn = select(i, ...)
        vim.validate("tn", tn, "table")

        local tn_len = #tn
        for j = 1, tn_len do
            t1[#t1 + 1] = tn[j]
        end
    end

    return t1
end

---@generic T
---@param dst T[]
---@param t1 T[]
---@param ... any[]
---@param key? string|fun(val:any): any
---@return any[]
local function difference_do(dst, key, t1, ...)
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
        if not seen[vh] then
            dst[j] = v
            j = j + 1
            seen[vh] = true
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
---`t1` is de-duplicated. Order is preserved.
---@generic T
---@generic U
---@param key? string|fun(val:any): any See: |vim.list.unique()|.
---@param t1 T[] Target list. Modified in place.
---@param ... any[]
---@return T[] The original reference to `t1`.
function M.difference(key, t1, ...)
    vim.validate("key", key, { "callable", "string" }, true)
    vim.validate("t1", t1, "table")
    local nargs = select("#", ...)
    for i = 1, nargs do
        local tn = select(i, ...)
        vim.validate("tn", tn, "table")
    end

    return difference_do(t1, key, t1, ...)
end

---Get a new list containing the elements of `t1` not present in any of the varargs (XOR logic).
---`t1` is de-duplicated. Order is preserved.
---@generic T
---@param t1 T[] Source list.
---@param ... any[]
---@param key? string|fun(val:any): any See: |vim.list.unique()|.
---@return any[] New list.
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
---@param key? string|fun(val:any): any
---@param t1 T[]
---@param ... any[]
---@return T[]
local function intersect_do(dst, key, t1, ...)
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
        if seen[key_fn(v)] then
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
---Keep elements in `t1` if they are present in `t2` (AND logic).
---Does not de-duplicate elements from `t1`. Order is preserved
---@generic T
---@param key? string|fun(val:any): any See: |vim.list.unique()|.
---@param t1 T[] Modified in place. Original order is preserved.
---@param ... any[]
---@return T[] t1 Reference to the table param.
function M.intersect(key, t1, ...)
    vim.validate("key", key, { "callable", "string" }, true)
    vim.validate("t1", t1, "table")
    local nargs = select("#", ...)
    for i = 1, nargs do
        local tn = select(i, ...)
        vim.validate("tn", tn, "table")
    end

    return intersect_do(t1, key, t1, ...)
end

---Create a new list from the elements in `t1` present in `t2` (AND logic).
---Does not de-duplicate elements from `t1`. Order is preserved.
---@generic T
---@param key? string|fun(val:any): any See: |vim.list.unique()|.
---@param t1 T[] Original order is preserved.
---@param ... any[]
---@return T[] New list.
function M.intersect_to(key, t1, ...)
    vim.validate("key", key, { "callable", "string" }, true)
    vim.validate("t1", t1, "table")
    local nargs = select("#", ...)
    for i = 1, nargs do
        local tn = select(i, ...)
        vim.validate("tn", tn, "table")
    end

    return intersect_do({}, key, t1, ...)
end

---@generic T
---@param dst T[]
---@param key? string|fun(val:any): any
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
---@param key? string|fun(val:any): any See: |vim.list.unique()|.
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
---@param key? string|fun(val:any): any See: |vim.list.unique()|.
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
---@param key? string|fun(val:any): any See: |vim.list.unique()|.
---@return any[] New list.
local function subtract_do(dst, key, t1, ...)
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
---@param key? string|fun(val:any): any See: |vim.list.unique()|.
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
---@param key? string|fun(val:any): any See: |vim.list.unique()|.
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
---@param key (string|fun(val:any): any)?
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
                seen[vh] = true
            end
        end
    end

    return ret
end

---Returns a new list of items that are only present in one of the lists. (XOR logic).
---Duplicates are kept. Original ordering is preserved.
---@param key (string|fun(val:any): any)?
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
---@param key (string|fun(val:any): any)?
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
    vim.validate("v", v, vim.nonnil)

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
    vim.validate("v", v, require("nvim-tools.types").nonnil)
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

---Returns `true` if the list is sorted according to a given comparator.
---@generic T
---@param t T[]
---@param comp? fun(a: T, b: T): boolean Default: `a < b`. Compatible with |table.sort()|.
---@return boolean
function M.is_sorted(t, comp)
    vim.validate("t", t, "table")
    vim.validate("comp", comp, "function", true)

    comp = comp or function(a, b)
        return a < b
    end

    local len = #t
    for i = 2, len do
        if not comp(t[i - 1], t[i]) then
            return false
        end
    end

    return true
end

---@generic T
---@param t T[]
---@param v T|fun(x:T): boolean
---@return boolean
function M.one(t, v)
    vim.validate("t", t, "table")
    vim.validate("v", v, vim.nonnil)

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
    vim.validate("v", v, require("nvim-tools.types").nonnil)
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

-----------------------------
-- MARK: List to New Value --
-----------------------------

---Apply a function to all elements of a list, transforming them into a single value.
---The first accumulator value will be the first value of the list.
---
---This function can be used to make:
---- min/max
---- sum/product
---
---@generic T
---@generic U
---@param t T[]
---@param reducer fun(acc:U,x:T): U
---@return U `nil` if `t` is length zero.
function M.reduce(t, reducer)
    vim.validate("t", t, "table")
    vim.validate("reducer", reducer, "callable")

    local t_len = #t
    if t_len == 0 then
        return nil
    end

    local acc = t[1]
    for i = 1, t_len do
        acc = reducer(acc, t[i])
    end

    return acc
end

---Apply a function to all elements of a list, transforming them into a single value.
---
---@generic T
---@generic U
---@param t T[]
---@param init U? First accumulator value.
---@param folder fun(acc:U, x:T): U
---@return U `init` if `t` is length zero.
function M.fold(t, init, folder)
    vim.validate("t", t, "table")
    vim.validate("folder", folder, "callable")

    local t_len = #t
    if t_len == 0 then
        return init
    end

    local acc = init
    for i = 1, t_len do
        acc = folder(acc, t[i])
    end

    return acc
end

---Returns a new table.
---Counts how many times each key appears in the list.
---@generic T
---@param t T[]
---@param key? string|fun(val: T): any
---@return table<any, integer>
function M.count_by(t, key)
    vim.validate("t", t, "table")
    vim.validate("key", key, { "callable", "string" }, true)

    local t_len = #t
    local key_fn = make_key_fn(key)
    local counts = {} ---@type table<any, integer>
    for i = 1, t_len do
        local vh = key_fn(t[i])
        counts[vh] = (counts[vh] or 0) + 1
    end

    return counts
end

---Returns a new table.
---Groups elements of the list by the result of `key`.
---Returns a new table where each key maps to a list of all matching elements. Within each group,
---order is preserved.
---@generic T
---@param t T[]
---@param key? string|fun(val: T): any
---@return table<any, T[]>
function M.group_by(t, key)
    vim.validate("t", t, "table")
    vim.validate("key", key, { "callable", "string" }, true)

    local t_len = #t
    local key_fn = make_key_fn(key)
    ---@generic T
    local groups = {} ---@type table<any, T[]>
    for i = 1, t_len do
        local v = t[i]
        local vh = key_fn(v)

        local group = groups[vh]
        if not group then
            group = {}
            groups[vh] = group
        end

        group[#group + 1] = v
    end

    return groups
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

---Example: `intersperse({ 1,2,3,4,5 }, ",", )` → `{ 1,,",",3,4,",",5 }`
---Use with |table.concat()| to get Haskell `intercalate` logic.
---@generic T
---@param t T[] Modified in place.
---@param sep T
---@param unit_size? integer Insert every x elements. Default 1.
---@return T[] Original list reference
function M.intersperse(t, sep, unit_size)
    vim.validate("t", t, "table")
    vim.validate("sep", sep, require("nvim-tools.types").nonnil)
    vim.validate("unit_size", unit_size, "number", true)

    local len = #t
    if len <= 1 then
        return t
    end

    unit_size = unit_size or 1
    if unit_size < 1 then
        unit_size = 1
    end

    local num_seps = math.floor((len - 1) / unit_size)
    if num_seps == 0 then
        return t
    end

    for i = len, 1, -1 do
        local shift = math.floor((i - 1) / unit_size)
        local final_pos = i + shift
        t[final_pos] = t[i]
    end

    local pos = unit_size + 1
    for _ = 1, num_seps do
        t[pos] = sep
        pos = pos + unit_size + 1
    end

    return t
end
-- MID: Is there a way to pre-grow or pre-size the array?
-- MID: I'm not convinced that doing floor division every element is the fastest way to do this.

---@generic T
---@param t T[]
---@param sep T
---@param unit_size? integer
---@return T[]
function M.intersperse_to(t, sep, unit_size)
    vim.validate("t", t, "table")
    vim.validate("sep", sep, require("nvim-tools.types").nonnil)
    vim.validate("unit_size", unit_size, "number", true)

    local len = #t
    if len <= 1 then
        return M.copy(t) -- reuse your existing copy function
    end

    unit_size = unit_size or 1
    if unit_size < 1 then
        unit_size = 1
    end

    local num_seps = math.floor((len - 1) / unit_size)
    if num_seps == 0 then
        return M.copy(t)
    end

    local ret = {}
    local j = 1

    for i = 1, len do
        ret[j] = t[i]
        j = j + 1

        if i % unit_size == 0 and i < len then
            ret[j] = sep
            j = j + 1
        end
    end

    return ret
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
function M.filter_map_accum(init, t, f)
    vim.validate("t", t, "table")
    vim.validate("init", init, vim.nonnil)
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
function M.filter_map_accum_to(init, t, f)
    vim.validate("init", init, vim.nonnil)
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
