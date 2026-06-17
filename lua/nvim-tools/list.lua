---@brief All functions in this module only operate on the |lua-list| portion of the table.

---@brief `_to` functions create a new list. Functions without the `_to` naming update the list
---in place. To get a new list from a function that modifies that target list in place, use
---the |list.copy()| function to create a shallow copy. `_to` functions may not be offered if
---they provide no performance advantage over just doing the shallow copy.
---
---If the list is modified in place, any hash elements are unaltered (|vim.list.unique()|
---behavior). If a new list is created, the hash elements are not transferred over.

-- TODO: Verify that hash element handling holds.

-- DOC: Add examples for the above.
-- - Or maybe, for examples without a `_to` function, show one copied example.

---@tag iter-indexing
---@brief For functions that take start and stop params:
---- Values greater than or equal to one operate according to standard Lua indexing.
---- Values will be clamped to the table length.
---- A value of zero resolves to the length of the table.
---- A value less than zero will subtract that amount from the table length.
---
---Example: 1, 0 - Iterate from the first index to the end.
---Example: 1, -1 - Iterate from the first index to the second-to-last index.
---Example: -1, 0 - Iterate from the second-to-last to the end.

-- TODO: This prompts allowing for the docgen to allow types into briefs so you can do something
-- like this.

---@tag key_fn
---@type string|fun(x:any): any?
---@brief Like |vim.list.unique()| and |vim.list.bisect()|, multiple functions in this module
---take a `key` argument. The key is called on each processed value of the list. If the key is
---a string, it is used as the field name to index each value. If the key is an anonymous
---function, it can be used to arbitrarily convert the list value.
---Example:
---```lua
---    local t = { { 1, 2 }, { 3, 4 }, { 5, 6 } }
---    unique_to(t, function(x)
---        return (x[1] * 10) + x[2]
---    end)
---```
---
---If the key is nil, the raw value will be used.

local M = {}

-----------------
-- MARK: Utils --
-----------------

---Assumes start and stop are valid and resolved.
---@generic T
---@param t T[]
---@param start uinteger
---@param stop uinteger
local function copy_exact(t, start, stop)
    local ret = require("nvim-tools.table").new(stop - start + 1, 0)
    local j = 1
    for i = start, stop do
        ret[j] = t[i]
        j = j + 1
    end

    return ret
end

---@generic T
---@param t T[] Modified in place!
---@param t_len uinteger
---@param key_fn fun(val:any): any
---@param seen table<any, true>
local function filter_in_place_from_seen(t, t_len, key_fn, seen)
    local j = 1
    for i = 1, t_len do
        local v = t[i]
        local vh = key_fn(v)
        if vh ~= nil and not seen[vh] then
            t[j] = v
            j = j + 1
        end
    end

    for i = j, t_len do
        t[i] = nil
    end
end

---@generic T
---@param t T[] Modified in place!
---@param t_len uinteger
---@param key_fn fun(val:any): any
---@param seen table<any, true>
---@return T[]
local function filter_to_from_seen(t, t_len, key_fn, seen)
    local ret = {}
    local j = 1
    for i = 1, t_len do
        local v = t[i]
        local vh = key_fn(v)
        if vh ~= nil and seen[vh] then
            ret[j] = v
            j = j + 1
        end
    end

    return ret
end

---@generic T
---@param t T[] Modified in place!
---@param t_len uinteger
---@param key_fn fun(val:any): any
---@param seen table<any, true>
local function first_in_place_from_seen(t, t_len, key_fn, seen)
    local j = 1
    for i = 1, t_len do
        local v = t[i]
        local vh = key_fn(v)
        if vh ~= nil and seen[vh] then
            t[j] = v
            j = j + 1
            seen[vh] = nil
        end
    end

    for i = j, t_len do
        t[i] = nil
    end
end

---@generic T
---@param t T[]
---@param t_len uinteger
---@param key_fn fun(val:any): any
---@param seen table<any, true>
---@return T[]
local function first_to_from_seen(t, t_len, key_fn, seen)
    local ret = {}
    local j = 1
    for i = 1, t_len do
        local v = t[i]
        local vh = key_fn(v)
        if vh ~= nil and seen[vh] then
            ret[j] = v
            j = j + 1
            seen[vh] = nil
        end
    end

    return ret
end

---Will clamp at zero for lists of those length. Zero case must be manually handled.
---@param idx integer?
---@param len uinteger
---@param default integer
---@return uinteger
local function iter_idx_resolve(idx, len, default)
    local res_idx = math.min(idx or default, len)
    if res_idx > 0 then
        return res_idx
    end

    return len - math.min(len, res_idx * -1)
end

-- TODO: Verify callers properly handle zero length.

---Will clamp at zero for lists of those length. Zero case must be manually handled.
---@param idx integer
---@param len uinteger
---@return uinteger
local function iter_idx_resolve_no_default(idx, len)
    local res_idx = math.min(idx, len)
    if res_idx > 0 then
        return res_idx
    end

    return len - math.min(len, res_idx * -1)
end

---Credit: Nvim core.
---@generic T
---@param key nil|string|fun(v:T): any
---@return fun(v: T): any
local function key_fn_from_key(key)
    if not key then
        return function(v)
            return v
        end
    end

    if type(key) == "string" then
        local field = key
        key = function(v)
            return v and v[field]
        end
    end

    return key
end

---Assumes that count is > 0 and valid.
---@generic T
---@param v T
---@param count uinteger
---@return T[]
local function replicate_do(v, count)
    local ret = require("nvim-tools.table").new(count, 0)
    for i = 1, count do
        ret[i] = v
    end

    return ret
end

---@param start uinteger
---@param stop uinteger
---@param rev? boolean
---@return uinteger start, uinteger stop, uinteger step
local function resolve_rev(start, stop, rev)
    if not rev then
        return start, stop, 1
    end

    return stop, start, -1
end

---@generic T
---@param nargs uinteger
---@param lists T[]
---@param key_fn fun(v:T): any
---@return table<any, true> seen
local function seen_from_varargs_if_in_any(nargs, lists, key_fn)
    local seen = {} ---@type table<any, true>
    for i = 1, nargs do
        local tn = lists[i]
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

---@generic T
---@param nargs uinteger
---@param lists T[]
---@param key_fn fun(v:T): any
---@return table<T, true>
local function seen_from_varargs_if_in_all(nargs, lists, key_fn)
    if nargs == 0 then
        return {}
    end

    if nargs == 1 then
        local seen = {} ---@type table<any, true>
        local t = lists[1]
        local t_len = #t
        for i = 1, t_len do
            local vh = key_fn(t[i])
            if vh ~= nil then
                seen[vh] = true
            end
        end

        return seen
    end

    if nargs == 2 then
        local t1 = lists[1]
        local t2 = lists[2]
        if #t1 < #t2 then
            local swap = t1
            t1 = t2
            t2 = swap
        end

        local seen_2 = {} ---@type table<any, true>
        for i = 1, #t2 do
            local vh = key_fn(t2[i])
            if vh ~= nil then
                seen_2[vh] = true
            end
        end

        local seen = {} ---@type table<any, true>
        for i = 1, #t1 do
            local vh = key_fn(t1[i])
            if vh ~= nil and seen_2[vh] then
                seen[vh] = true
            end
        end

        return seen
    end

    local idx_min = 1
    local len_min = #lists[idx_min]
    for i = 2, nargs do
        local varg_len = #lists[i]
        if varg_len < len_min then
            len_min = varg_len
            idx_min = i
        end
    end

    local n_seen = {} ---@type table<any, uinteger>
    local n_prev = 0
    local n = 1
    local t1 = lists[idx_min]
    local t1_len = #t1
    for i = 1, t1_len do
        local vh = key_fn(t1[i])
        if vh ~= nil then
            n_seen[vh] = n
        end
    end

    local idx_before_min = idx_min - 1
    for i = 1, idx_before_min do
        n_prev = n
        n = n + 1
        local tn = lists[i]
        local tn_len = #tn
        for j = 1, tn_len do
            local vh = key_fn(tn[j])
            if vh ~= nil and n_seen[vh] == n_prev then
                n_seen[vh] = n
            end
        end
    end

    for i = idx_min + 1, nargs do
        n_prev = n
        n = n + 1
        local tn = lists[i]
        local tn_len = #tn
        for j = 1, tn_len do
            local vh = key_fn(tn[j])
            if vh ~= nil and n_seen[vh] == n_prev then
                n_seen[vh] = n
            end
        end
    end

    local seen = {} ---@type table<any, true>
    for vh, x in pairs(n_seen) do
        if x == n then
            seen[vh] = true
        end
    end

    return seen
end
-- NON: Don't abstract this logic because you're already multiple function calls deep.

---Assumes:
---- t_len > 0.
---- start and stop are already resolved and valid.
---@generic T
---@param t T[] Modified in place!
---@param t_len uinteger
---@param start uinteger
---@param stop uinteger
local function shift_down(t, t_len, start, stop)
    if start > 1 then
        local j = 1
        for i = start, stop do
            t[j] = t[i]
            j = j + 1
        end

        for i = j, t_len do
            t[i] = nil
        end

        return
    end

    for i = stop + 1, t_len do
        t[i] = nil
    end
end

---@generic T
---@param t T[] Modified in place!
---@param t_len uinteger
---@param key_fn fun(val:any): any
---@param seen table<any, true>
local function unique_in_place_from_seen(t, t_len, key_fn, seen)
    local j = 1
    for i = 1, t_len do
        local v = t[i]
        local vh = key_fn(v)
        if vh ~= nil and not seen[vh] then
            t[j] = v
            seen[vh] = true
            j = j + 1
        end
    end

    for i = j, t_len do
        t[i] = nil
    end
end

---@generic T
---@param t T[]
---@param t_len uinteger
---@param key_fn fun(val:any): any
---@param seen table<any, true>
local function unique_to_from_seen(t, t_len, key_fn, seen)
    local ret = {}
    local j = 1
    for i = 1, t_len do
        local v = t[i]
        local vh = key_fn(v)
        if vh ~= nil and not seen[vh] then
            ret[j] = v
            seen[vh] = true
            j = j + 1
        end
    end

    return ret
end

-------------------------
-- MARK: List Creation --
-------------------------

---Creates a shallow copy of `t`.
---
---@see |splice_to()| for copying a sub-section of the list.
---@generic T
---@param t T[]
---@return T[]
function M.copy(t)
    local t_len = #t
    if t_len == 0 then
        return {}
    end

    return copy_exact(t, 1, t_len)
end

---Creates a new |lua-list| containing `v` repeated `count` times. If `v` is a reference, it is
---shallow-copied.
---
---Example:
---```lua
---    local foo = replicate(0, 4)
---    -- foo == { 0, 0, 0, 0 }
---```
---@see |successors()| or |unfold()| for creating a new list with evolving values.
---@generic T
---@param val T
---@param count uinteger If `count` is zero, an empty table is returned.
---@return T[]
function M.replicate(val, count)
    if count == 0 then
        return {}
    end

    return replicate_do(val, count)
end
-- Named `replicate` because `repeat` is a Lua keyword.

---Splice `t` in-place into a subset of its values. Clears `t` if the resolved value of `start`
---is greater than `stop`.
---
---Example:
---```lua
---    local foo = { 1, 2, 3, 4, 5, 6 }
---    splice(foo, 3, 5)
---    -- foo == { 3, 4, 5 }
---```
---@generic T
---@param t T[] Modified in place!
---@param start integer See |iter-indexing|.
---@param stop integer See |iter-indexing|.
---@return T[] Reference to `t`.
function M.splice(t, start, stop)
    local t_len = #t
    start = iter_idx_resolve(start, t_len, 1)
    stop = iter_idx_resolve(stop, t_len, t_len)
    if t_len == 0 or (start == 1 and stop == t_len) then
        return t
    end

    if start <= stop then
        shift_down(t, t_len, start, stop)
        return t
    end

    M.clear(t)
    return t
end

---Creates a new |lua-list| containing a subset of `t` defined by `start` and `stop`. References
---are shallow-copied.
---
---Returns an empty table if `t` is length zero or `start` resolves to a value greater than
---`stop`.
---
---Example:
---```lua
---    local foo = { 1, 2, 3, 4, 5, 6 }
---    local bar = splice_to(foo, 3, 5)
---    -- bar == { 3, 4, 5 }
---    -- foo = { 1, 2, 3, 4, 5, 6 }
---```
---@see |copy()| to copy the entire list.
---@generic T
---@param t T[]
---@param start integer See |iter-indexing|.
---@param stop integer See |iter-indexing|.
---@return T[]
function M.splice_to(t, start, stop)
    local t_len = #t
    start = iter_idx_resolve(start, t_len, 1)
    stop = iter_idx_resolve(stop, t_len, t_len)
    if t_len == 0 or (start > stop) then
        return {}
    end

    return copy_exact(t, start, stop)
end

---Create a new |lua-list|, using function `f` to iteratively mutate an initial seed value.
---
---`init` becomes the new list's first value. Each call to `f` will provide the most recently
---added value. The return value from `f` will then be appended. If `f` returns `nil`, list
---building ends.
---
---Example:
---```lua
---local path = successors(5, function(x)
---    if x == 1 then
---        return nil
---    elseif x % 2 == 0 then
---        return x / 2
---    else
---        return (3 * x) + 1
---    end
---end)
----- path = { 5, 16, 8, 4, 2, 1 }
---```
---@see |unfold()| to build using an accumulator.
---@generic T
---@param init T Passing `nil` is undefined behavior.
---@param f fun(x:T): T|nil
---@return T[]
function M.successors(init, f)
    local ret = { init }
    local j = 1
    while true do
        local v = f(ret[j])
        if v == nil then
            return ret
        end

        j = j + 1
        ret[j] = v
    end
end

---Create a new |lua-list|, creating an accumulator from `init` then threading it through
---function `f`.
---
---`f` returns the next accumulator and the next value to append to the list. If the returned
---value is nil, list building ends.
---
---Example:
---```lua
---local foo = unfold(1, function(acc, len)
---    if acc <= 5 then
---        return acc + 1, tostring(acc)
---    end
---
---    return acc, nil
---end)
----- foo = { "1", "2", "3", "4", "5" }
---```
---@see |successors()| to build off of the list values.
---@generic T, A
---@param init A Passing `nil` is undefined behavior.
---@param f fun(acc:A): A, T|nil Returning a `nil` value for A will set a `nil` accumulator.
---@return T[]
function M.unfold(init, f)
    local ret = {}
    local acc = init
    local v
    local j = 0
    while true do
        acc, v = f(acc)
        if v == nil then
            return ret
        end

        j = j + 1
        ret[j] = v
    end
end

------------------------
-- MARK: List Joining --
------------------------

---@generic T
---@param lists_len uinteger
---@param lists T[][]
---@param dst T[] Modified in place!
local function lists_append(lists_len, lists, dst)
    local j = #dst + 1
    for i = 1, lists_len do
        local tn = lists[i]
        local tn_len = #tn
        for k = 1, tn_len do
            dst[j] = tn[k]
            j = j + 1
        end
    end
end

---@generic T
---@param nargs uinteger
---@param comp fun(a:T, b:T): boolean
---@param lists T[][]
---@return T[]
local function merge_sorted_do(nargs, comp, lists)
    local ntt = require("nvim-tools.table")
    local t_lens = ntt.new(nargs, 0)
    local len_total = 0
    for i = 1, nargs do
        local len = #lists[i]
        t_lens[i] = len
        len_total = len_total + len
    end

    if len_total == 0 then
        return {}
    end

    local ret = ntt.new(len_total, 0)
    local cur_idxs = replicate_do(1, nargs)
    local lists_active = ntt.new(nargs, 0)
    for i = 1, nargs do
        lists_active[i] = i
    end

    local active_count = #lists_active
    local k = 1
    while active_count > 0 do
        local list_sel_idx = 1
        local list_sel = lists_active[1]
        local val_sel = lists[list_sel][cur_idxs[list_sel]]
        for j = 2, active_count do
            local list_idx = lists_active[j]
            local val = lists[list_idx][cur_idxs[list_idx]]
            if comp(val, val_sel) then
                list_sel_idx = j
                list_sel = list_idx
                val_sel = val
            end
        end

        ret[k] = val_sel
        k = k + 1

        local new_idx = cur_idxs[list_sel] + 1
        cur_idxs[list_sel] = new_idx
        if new_idx > t_lens[list_sel] then
            lists_active[list_sel_idx] = lists_active[active_count]
            active_count = active_count - 1
        end
    end

    return ret
end

---Create a new |lua-list| of de-duplicated and sorted items from `...`. References are
---shallow-copied.
---
---Example:
---```lua
---local foo = catalog_to(nil, nil, { 1, 2, 2, 3 }, { 2, 3, 3, 4 }, { 3, 4, 4, 5 })
----- foo = { 1, 2, 3, 4, 5 }
---```
---@see |collate_to()| if to merge with sorting only.
---@see |union_to()| to merge with de-duplication only.
---@generic T
---@param key nil|string|fun(v:T): any See: |key_fn|.
---@param comp (fun(a:T, b:T): boolean)? (Default: Ascending order) Compatible with |table.sort()|.
---@param ... T[]
---@return T[]
function M.catalog_to(key, comp, ...)
    local nargs = select("#", ...)
    if nargs == 0 then
        return {}
    end

    local old_lists = { ... }
    local key_fn = key_fn_from_key(key)
    local seen = {}
    local lists = {}
    comp = comp or function(a, b)
        return a < b
    end

    for i = 1, nargs do
        local tn = old_lists[i]
        local tn_len = #tn
        local tn_filtered = unique_to_from_seen(tn, tn_len, key_fn, seen)
        table.sort(tn_filtered, comp)
        lists[i] = tn_filtered
    end

    if #lists == 1 then
        return lists[1]
    end

    return merge_sorted_do(nargs, comp, lists)
end

---Append each list in `...`, in order, to `t1`. References are shallow-copied.
---
---Example:
---```lua
---local foo = { 1, 2, 2, 3 }
---chain(nil, foo, { 2, 3, 3, 4 }, { 3, 4, 4, 5 })
----- foo = { 1, 2, 2, 3, 2, 3, 3, 4, 3, 4, 4, 5 }
---```
---@generic T
---@param t1 T[] Modified in place!
---@param ... T[]
---@return T[] Reference to `t1`.
function M.chain(t1, ...)
    local nargs = select("#", ...)
    if nargs == 0 then
        return t1
    end

    lists_append(nargs, { ... }, t1)
    return t1
end

---Create a new |lua-list| by appending each list in `...` in order. References are
---shallow-copied.
---
---Example:
---```lua
---local foo = chain(nil, { 1, 2, 2, 3 }, { 2, 3, 3, 4 }, { 3, 4, 4, 5 })
----- foo = { 1, 2, 2, 3, 2, 3, 3, 4, 3, 4, 4, 5 }
---```
---@generic T
---@param ... T[]
---@return T[]
function M.chain_to(...)
    local nargs = select("#", ...)
    if nargs == 0 then
        return {}
    end

    local lists = { ... }
    local len_total = 0
    for i = 1, nargs do
        len_total = len_total + #lists[i]
    end

    if len_total == 0 then
        return {}
    end

    local ret = require("nvim-tools.table").new(len_total, 0)
    lists_append(nargs, lists, ret)
    return ret
end

---Merge each list in `...` into a new, sorted |lua-list|. Each list is shallow-copied.
---
---Example:
---```lua
---local foo = collate_to(nil, { 1, 2, 3, 4, 5 }, { 5, 4, 3, 2, 1 })
----- foo = { 1, 1, 2, 2, 3, 3, 4, 4, 5, 5 }
---```
---@see |catalog_to()| to merge with sorting and de-duping.
---@see |merge_sorted()| if the lists are already sorted.
---@see |union_to()| to only merge with de-duping.
---@generic T
---@param comp (fun(a:T, b:T): boolean)? Default: Ascending order. Compatible with |table.sort()|.
---@param ... T[]
---@return T[]
function M.collate_to(comp, ...)
    local nargs = select("#", ...)
    if nargs == 0 then
        return {}
    end

    local old_lists = { ... }
    local lists = {}
    comp = comp or function(a, b)
        return a < b
    end

    for i = 1, nargs do
        local tn = old_lists[i]
        local tn_copy = copy_exact(tn, 1, #tn)
        table.sort(tn_copy, comp)
        lists[i] = tn_copy
    end

    if #lists == 1 then
        return lists[1]
    end

    return merge_sorted_do(nargs, comp, lists)
end

---Create a new |lua-list| of items present in only one of the `...` varargs. Items can
---optionally be compared against a `key`.
---- All items are de-duped.
---- Original ordering is preserved.
---- References are shallow-copied.
---
---Example:
---```lua
---local foo = distinct_to(nil, { 1, 2 }, { 2, 3, 4 }, { 4, 5 })
----- foo = { 1, 3, 5 }
---```
---@generic T
---@param key nil|string|fun(v:T): any See: |key_fn|.
---@param ... T[]
---@return T[]
function M.distinct_to(key, ...)
    local nargs = select("#", ...)
    if nargs == 0 then
        return {}
    end

    local lists = { ... }
    local key_fn = key_fn_from_key(key)
    local seen = {} ---@type table<any, uinteger>
    for i = 1, nargs do
        local tn = lists[i]
        local tn_len = #tn
        for j = 1, tn_len do
            local vh = key_fn(tn[j])
            if vh ~= nil then
                local was_seen = seen[vh]
                if was_seen == nil then
                    seen[vh] = i
                elseif not was_seen ~= i then
                    seen[vh] = 0
                end
            end
        end
    end

    local ret = {}
    local j = 1
    for i = 1, nargs do
        local tn = lists[i]
        local tn_len = #tn
        for k = 1, tn_len do
            local v = tn[k]
            local vh = key_fn(v)
            if vh ~= nil and seen[vh] == i then
                ret[j] = v
                j = j + 1
                seen[vh] = nil
            end
        end
    end

    return ret
end

---Combines multiple sorted vararg `...` lists into a new sorted |lua-list|. References are
---shallow-copied.
---
---All input lists must already be sorted according to the comparator.
---
---Example:
---```lua
---local foo = merge_sorted_to(nil, { 1, 3, 5 }, { 2, 4, 6 })
----- foo = { 1, 2, 3, 4, 5, 6 }
---```
---@see |collate_to()| if the lists are not already sorted.
---@generic T
---@param comp? fun(a:T, b:T): boolean (Default: Ascending order) Compatible with |table.sort()|.
---@param ... T[]
---@return T[]
function M.merge_sorted_to(comp, ...)
    local nargs = select("#", ...)
    if nargs == 0 then
        return {}
    end

    if nargs == 1 then
        local t1 = select(1, ...)
        return copy_exact(t1, 1, #t1)
    end

    comp = comp or function(a, b)
        return a < b
    end

    return merge_sorted_do(nargs, comp, { ... })
end

---Creates a new |lua-list| from the de-duplicated values in `...`, optionally compared using a
---`key`.
---- References are shallow-copied.
---- No re-ordering is performed.
---
---Example:
---```lua
---local foo = distinct_to(nil, { 1, 2, 2 }, { 5, 5, 4, 3 })
----- foo = { 1, 2, 5, 4, 3 }
---```
---@see |catalog()| to additionally sort the results.
---@see |chain()| to append lists without de-duplication.
---@generic T
---@param key nil|string|fun(v:T): any See: |key_fn|.
---@param ... T[]
---@return T[]
function M.union_to(key, ...)
    local nargs = select("#", ...)
    if nargs == 0 then
        return {}
    end

    local lists = { ... }
    local key_fn = key_fn_from_key(key)
    local seen = {}
    local ret = {}
    local j = 1
    for i = 1, nargs do
        local tn = lists[i]
        local tn_len = #tn
        for k = 1, tn_len do
            local v = tn[k]
            local vh = key_fn(v)
            if vh ~= nil and not seen[vh] then
                ret[j] = v
                j = j + 1
                seen[vh] = true
            end
        end
    end

    return ret
end

-----------------------------------
-- MARK: Direct Access Functions --
-----------------------------------

---Gets the value from `t` at index `idx`. Does not copy references.
---@generic T
---@param t T[]
---@param idx integer See |iter-indexing|.
---@return T? `nil` if the table is empty.
function M.at(t, idx)
    local t_len = #t
    if t_len == 0 then
        return nil
    end

    return t[iter_idx_resolve_no_default(idx, t_len)]
end

---Deletes a value from `t` at `idx` and returns it.
---
---Slower than |table.remove()| at less than 100 items. Prefer that unless you need the index
---ergonomics.
---@see |rm_at()| to remove without returning a value.
---@generic T
---@param t T[] Modified in place!
---@param idx integer See |iter-indexing|.
---@return T|nil `nil` if list length is zero.
function M.drain(t, idx)
    local t_len = #t
    if t_len == 0 then
        return nil
    end

    local res_idx = iter_idx_resolve_no_default(idx, t_len)
    local v = t[res_idx]
    for i = res_idx + 1, t_len do
        t[i - 1] = t[i]
    end

    t[t_len] = nil
    return v
end

---Inserts a new `val` into table `t` at `idx`.
---
---Slower than |table.insert()| at < 100 items. Prefer that unless you need the index ergonomics.
---@generic T
---@param t T[] Modified in place!
---@param val T
---@param idx? integer See |iter-indexing| If no index, append to the end like |table.insert()|.
function M.insert_at(t, val, idx)
    local t_len = #t
    if not idx or t_len == 0 then
        t[t_len + 1] = val
        return
    end

    local res_idx = iter_idx_resolve_no_default(idx, t_len)
    local stop = res_idx + 1
    for i = t_len + 1, stop, -1 do
        t[i] = t[i - 1]
    end

    t[res_idx] = val
end

---Removes an element from list `t` at `idx`.
---
---Slower than |table.remove()| at < 100 items. Prefer that unless you need the index ergonomics.
---@see |drain()| to additionally return the deleted element.
---@generic T
---@param t T[] Modified in place!
---@param idx integer See |iter-indexing|.
function M.rm_at(t, idx)
    local t_len = #t
    if t_len == 0 then
        return
    end

    for i = iter_idx_resolve_no_default(idx, t_len) + 1, t_len do
        t[i - 1] = t[i]
    end

    t[t_len] = nil
end

-----------------------------------
-- MARK: Filtering and Cleansing --
-----------------------------------

---Clears all array elements in `t`.
---@generic T
---@param t T[] Modified in place!
---@return T[] Reference to `t`.
function M.clear(t)
    local t_len = #t
    for i = 1, t_len do
        t[i] = nil
    end

    return t
end

---Remove values from `t` that fail predicate `f`.
---
---Example:
---```lua
---    local foo = { 1, 2, 3, 4, 5, 6 }
---    filter(foo, function(x)
---        return x % 2 == 0
---    end)
---    -- foo = { 2, 4, 6 }
---```
---@generic T
---@param t T[] Modified in place!
---@param f fun(x:T): boolean
---@return T[] Reference to `t`.
function M.filter(t, f)
    local t_len = #t
    if t_len == 0 then
        return t
    end

    local j
    for i = 1, t_len do
        if not f(t[i]) then
            j = i
            for k = i + 1, t_len do
                local v = t[k]
                if f(v) then
                    t[j] = v
                    j = j + 1
                end
            end

            for k = j, t_len do
                t[k] = nil
            end

            break
        end
    end

    return t
end

---Create a new |lua-list| of values from `t` that pass predicate `f`.
---
---Example:
---```lua
---    local foo = { 1, 2, 3, 4, 5, 6 }
---    local bar = filter_to(foo, function(x)
---        return x % 2 == 0
---    end)
---
---    -- bar = { 2, 4, 6 }
---    -- foo = { 1, 2, 3, 4, 5, 6 }
---```
---@generic T
---@param t T[]
---@param f fun(x:T): boolean
---@return T[]
function M.filter_to(t, f)
    local t_len = #t
    local ret = {}
    if t_len == 0 then
        return ret
    end

    local j = 1
    for i = 1, t_len do
        local v = t[i]
        if f(v) then
            ret[j] = v
            j = j + 1
        end
    end

    return ret
end

---Iterate over `t` with predicate `f`. Keep values until one fails, then remove the rest in place.
---
---Example:
---```lua
---    local foo = { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 }
---    keep_while(foo, function(x)
---        return x <= 3
---    end)
---    -- foo = { 1, 2, 3 }
---```
---```lua
---    local foo = { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 }
---    keep_while(foo, function(x)
---        return x >= 8
---    end)
---    -- foo = { 8, 9, 10 }
---```
---@generic T
---@param t T[] Modified in place!
---@param f fun(x:T): boolean
---@param rev? boolean (Default: `false`) If true, iterate from the end.
---@return T[] Reference to `t`.
function M.keep_while(t, f, rev)
    local t_len = #t
    if t_len == 0 then
        return t
    end

    if not rev then
        for i = 1, t_len do
            if not f(t[i]) then
                for j = i, t_len do
                    t[j] = nil
                end

                return t
            end
        end

        return t
    end

    for i = t_len, 1, -1 do
        if not f(t[i]) then
            if i ~= t_len then
                shift_down(t, t_len, i + 1, t_len)
                return t
            end

            M.clear(t)
            return t
        end
    end

    return t
end

---Iterate over `t` with predicate `f`. Shallow copy the values to a new list until the
---predicate fails.
---
---Example:
---```lua
---    local foo = { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 }
---    local bar = keep_while_to(foo, function(x)
---        return x <= 3
---    end)
---    -- bar = { 1, 2, 3 }
---    -- foo = { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 }
---```
---```lua
---    local foo = { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 }
---    local bar = keep_while_to(foo, function(x)
---        return x >= 8
---    end)
---    -- bar = { 8, 9, 10 }
---    -- foo = { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 }
---```
---@generic T
---@param t T[]
---@param f fun(x:T): boolean
---@param rev? boolean (Default: `false`) If `true`, iterate from the end.
---@return T[]
function M.keep_while_to(t, f, rev)
    local t_len = #t
    if t_len == 0 then
        return {}
    end

    if not rev then
        for i = 1, t_len do
            if not f(t[i]) then
                return copy_exact(t, 1, i - 1)
            end
        end

        return copy_exact(t, 1, t_len)
    end

    for i = t_len, 1, -1 do
        if not f(t[i]) then
            return copy_exact(t, i + 1, t_len)
        end
    end

    return copy_exact(t, 1, t_len)
end

---Iterate over `t` with predicate `f`. Remove values in place until one passes the predicate.
---Shift the remaining elements down so they start at index one.
---
---Example:
---```lua
---    local foo = { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 }
---    rm_while(foo, function(x)
---        return x <= 3
---    end)
---    -- foo = { 4, 5, 6, 7, 8, 9, 10 }
---```
---```lua
---    local foo = { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 }
---    rm_while(foo, function(x)
---        return x >= 8
---    end)
---    -- foo = { 1, 2, 3, 4, 5, 6, 7 }
---```
---@generic T
---@param t T[] Modified in place!
---@param f fun(x:T): boolean
---@param rev? boolean (Default: `false`) If `true`, iterate from the end.
---@return T[] Reference to `t`.
function M.rm_while(t, f, rev)
    local t_len = #t
    if t_len == 0 then
        return t
    end

    if not rev then
        for i = 1, t_len do
            if not f(t[i]) then
                shift_down(t, t_len, i, t_len)
                return t
            end
        end

        M.clear(t)
        return t
    end

    for i = t_len, 1, -1 do
        if not f(t[i]) then
            for j = i + 1, t_len do
                t[j] = nil
            end

            return t
        end
    end

    M.clear(t)
    return t
end

---Iterate over `t` with predicate `f`. Skip values until the predicate fails, then copy the
---remaining values into a new list.
---
---Example:
---```lua
---    local foo = { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 }
---    local bar = rm_while_to(foo, function(x)
---        return x <= 3
---    end)
---    -- bar = { 4, 5, 6, 7, 8, 9, 10 }
---    -- foo = { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 }
---```
---```lua
---    local foo = { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 }
---    local bar = rm_while_to(foo, function(x)
---        return x >= 8
---    end)
---    -- bar = { 1, 2, 3, 4, 5, 6, 7 }
---    -- foo = { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 }
---```
---@generic T
---@param t T[]
---@param f fun(x:T): boolean
---@param rev? boolean (Default: `false`) If `true`, iterate from the end.
---@return T[]
function M.rm_while_to(t, f, rev)
    local t_len = #t
    if t_len == 0 then
        return {}
    end

    if not rev then
        for i = 1, t_len do
            if not f(t[i]) then
                return copy_exact(t, i, t_len)
            end
        end

        return {}
    end

    for i = t_len, 1, -1 do
        if not f(t[i]) then
            return copy_exact(t, 1, i)
        end
    end

    return {}
end

---Create a new |lua-list| of unique items from `t`, optionally compared using `key`.
---@see |vim.list.unique()| to filter in-place.
---@generic T
---@param t T[]
---@param key nil|string|fun(v:T): any See: |key_fn|.
---@return T[]
function M.unique_to(t, key)
    local t_len = #t
    if t_len == 0 then
        return {}
    end

    local key_fn = key_fn_from_key(key)
    return unique_to_from_seen(t, t_len, key_fn, {})
end

-----------------------------------
-- MARK: List and List Filtering --
-----------------------------------

---Remove elements from `t1` that are present in any of the varargs `...`. Optionally
---compare using `key`. `t1` is de-duplicated, and item order is preserved.
---@generic T
---@param key nil|string|fun(v:T): any See: |key_fn|.
---@param t1 T[] Target list. Modified in place!
---@param ... T[] No-op if no additional lists are provided.
---@return T[] Reference to `t1`.
function M.difference(key, t1, ...)
    local nargs = select("#", ...)
    local t1_len = #t1
    if t1_len == 0 or nargs == 0 then
        return t1
    end

    local key_fn = key_fn_from_key(key)
    local seen = seen_from_varargs_if_in_any(nargs, { ... }, key_fn)
    unique_in_place_from_seen(t1, t1_len, key_fn, seen)
    return t1
end

---Create a new list containing the elements of `t1` not present in any of the varargs
---(XOR logic).
---- `t1` is de-duplicated. Order is preserved.
---- No-op if no varargs are provided.
---@generic T
---@param key nil|string|fun(v:T): any See: |key_fn|.
---@param t1 T[] Source list.
---@param ... T[] No-op if no additional lists are provided.
---@return T[] New list.
function M.difference_to(key, t1, ...)
    local nargs = select("#", ...)
    local t1_len = #t1
    if nargs == 0 or t1_len == 0 then
        return M.copy(t1)
    end

    local key_fn = key_fn_from_key(key)
    local seen = seen_from_varargs_if_in_any(nargs, { ... }, key_fn)
    return unique_to_from_seen(t1, t1_len, key_fn, seen)
end

---Keep elements in `t1` if they are present in all varargs (AND logic).
---Order in `t1` is preserved
---@generic T
---@param key nil|string|fun(v:T): any See: |key_fn|.
---@param t1 T[] Modified in place!
---@param ... T[] No-op if no additional lists are provided.
---@return T[] Reference to `t1`.
function M.intersect(key, t1, ...)
    local nargs = select("#", ...)
    local t1_len = #t1
    if nargs == 0 or t1_len == 0 then
        return t1
    end

    local key_fn = key_fn_from_key(key)
    local seen = seen_from_varargs_if_in_all(nargs, { ... }, key_fn)
    filter_in_place_from_seen(t1, t1_len, key_fn, seen)
    return t1
end

---Create a new list of elements in `t1` if they are present in all varargs (AND logic).
---Order in `t1` is preserved
---@generic T
---@param key nil|string|fun(v:T): any See: |key_fn|.
---@param t1 T[]
---@param ... T[] No-op if no additional lists are provided.
---@return T[] New list.
function M.intersect_to(key, t1, ...)
    local nargs = select("#", ...)
    local t1_len = #t1
    if nargs == 0 then
        return M.copy(t1)
    end

    local key_fn = key_fn_from_key(key)
    local seen = seen_from_varargs_if_in_all(nargs, { ... }, key_fn)
    return filter_to_from_seen(t1, t1_len, key_fn, seen)
end

---Remove list elements from `t1` if they are not present in all vararg lists (AND logic).
---De-duplicates elements from `t1`. Order is preserved
---@generic T
---@param key nil|string|fun(v:T): any See: |key_fn|.
---@param t1 T[] Modified in place!
---@param ... T[] No-op if no additional lists are provided.
---@return T[] Reference to `t`.
function M.intersection(key, t1, ...)
    local nargs = select("#", ...)
    local t1_len = #t1
    if t1_len == 0 or nargs == 0 then
        return t1
    end

    local key_fn = key_fn_from_key(key)
    local seen = seen_from_varargs_if_in_all(nargs, { ... }, key_fn)
    first_in_place_from_seen(t1, t1_len, key_fn, seen)
    return t1
end

---Create a new list from the elements in `t1` present in all vararg lists (AND logic).
---De-duplicates elements from `t1`. Order is preserved.
---@generic T
---@param key nil|string|fun(v:T): any See: |key_fn|.
---@param t1 T[] Original order is preserved.
---@param ... T[] No-op if no additional lists are provided.
---@return T[] New list.
function M.intersection_to(key, t1, ...)
    local t1_len = #t1
    local nargs = select("#", ...)
    if t1_len == 0 or nargs == 0 then
        return M.copy(t1)
    end

    local key_fn = key_fn_from_key(key)
    local seen = seen_from_varargs_if_in_all(nargs, { ... }, key_fn)
    return first_to_from_seen(t1, t1_len, key_fn, seen)
end

---Remove elements from `t1` in place that are present in any of the varargs (set difference/XOR
---logic). Order in `t1` is preserved.
---@generic T
---@param key nil|string|fun(v:T): any See: |key_fn|.
---@param t1 T[] Modified in place!
---@param ... T[] No-op if no additional lists are provided.
---@return T[] Reference to `t1`.
function M.subtract(key, t1, ...)
    local nargs = select("#", ...)
    local t1_len = #t1
    if t1_len == 0 or nargs == 0 then
        return t1
    end

    local key_fn = key_fn_from_key(key)
    local seen = seen_from_varargs_if_in_any(nargs, { ... }, key_fn)
    filter_in_place_from_seen(t1, t1_len, key_fn, seen)
    return t1
end

---Create a new list containing the elements of `t1` not present in any of the varargs (set
---difference/XOR logic). Order in `t1` is preserved.
---@generic T
---@param key nil|string|fun(v:T): any See: |key_fn|.
---@param t1 T[] Source list.
---@param ... T[] No-op if no additional lists are provided.
---@return T[] New list.
function M.subtract_to(key, t1, ...)
    local nargs = select("#", ...)
    local t1_len = #t1
    if t1_len == 0 or nargs == 0 then
        return M.copy(t1)
    end

    local key_fn = key_fn_from_key(key)
    local seen = seen_from_varargs_if_in_any(nargs, { ... }, key_fn)
    return filter_to_from_seen(t1, t1_len, key_fn, seen)
end

-------------------------------
-- MARK: List Eval Functions --
-------------------------------

---Check if all items in a list satisfy predicate function `f`.
---To check by key, see |same()|.
---@generic T
---@param t T[]
---@param f fun(x:T): boolean
---@return boolean False if length of `t` is zero.
function M.all(t, f)
    local t_len = #t
    if t_len == 0 then
        return false
    end

    for i = 1, t_len do
        if not f(t[i]) then
            return false
        end
    end

    return true
end

---Check if any items in `t` satisfy predicate function `f`.
---To check by key, see |contains()|.
---@generic T
---@param t T[]
---@param f fun(x:T): boolean
---@return boolean False if length of `t` is zero.
function M.any(t, f)
    local t_len = #t
    if t_len == 0 then
        return false
    end

    for i = 1, t_len do
        if f(t[i]) then
            return true
        end
    end

    return false
end

---Compare elements of `t1` and `t2`. If t1 and t2 are of different lengths, the shorter length
---is used. Return `false` if any of the element comparisons fail.
---Optionally provide a `key` to filter the values.
---Optionally provide a custom `comp` function.
---
---Iterate through `t1` and `t2`, comparing their elements by index. If they are different
---lengths, the shorter one is used for comparison. Optionally provide either a `key` to
---process the value or a comparison function `comp`.
---@generic T
---@generic U
---@param t1 T[]
---@param t2 U[]
---@param key nil|string|fun(v:T): any See: |key_fn|.
---@param comp? fun(a:T, b:U): boolean (Default: Shallow equality) Compatible with |table.sort()|.
---@return boolean Returns false if list table has length zero.
function M.cmp(t1, t2, key, comp)
    local len = math.min(#t1, #t2)
    if len == 0 then
        return false
    end

    local key_fn = key_fn_from_key(key)
    comp = comp or function(a, b)
        return a == b
    end

    for i = 1, len do
        if not comp(key_fn(t1[i]), key_fn(t2[i])) then
            return false
        end
    end

    return true
end

---For two-dimensional array `tt`, get the highest index value for which all sub-lists share the
---same values. Optionally compare with `key`.
---@generic T
---@param tt T[][]
---@param key nil|string|fun(v:T): any See: |key_fn|.
---@return uinteger? `nil` if the first index's values does not match. Or if one of the lists has
---     a zero length.
function M.common_prefix(tt, key)
    local tt_len = #tt
    if tt_len == 0 then
        return
    end

    if tt_len == 1 then
        local tt_len_one = #tt[1]
        return tt_len_one > 0 and tt_len_one or nil
    end

    local tt_len_min = math.floor(math.huge)
    for i = 1, tt_len do
        local tt_len_i = #tt[i]
        if tt_len_i == 0 then
            return nil
        end

        tt_len_min = math.min(tt_len_min, tt_len_i)
    end

    local key_fn = key_fn_from_key(key)
    for col = 1, tt_len_min do
        local vh = key_fn(tt[1][col])
        for row = 2, tt_len do
            local vnh = key_fn(tt[row][col])
            if vnh ~= vh then
                local common_prefix_end = col - 1
                return common_prefix_end > 0 and common_prefix_end or nil
            end
        end
    end

    return tt_len_min
end

---Check if all of or none of the items in `t` satisfy predicate function `f`.
---To check by key, see |uniform()|.
---@generic T
---@param t T[]
---@param f fun(x:T): boolean
---@return boolean `false` if length of `t` is zero.
function M.consistent(t, f)
    local t_len = #t
    if t_len == 0 then
        return false
    end

    local expected = f(t[1])
    for i = 2, t_len do
        if f(t[i]) ~= expected then
            return false
        end
    end

    return true
end

---Check if any item in `t` matches `v`, optionally comparing based on `key`.
---To check with a predicate function, see |any()|.
---@generic T
---@param t T[]
---@param val T
---@param key nil|string|fun(v:T): any See: |key_fn|.
---@return boolean
---`false` if:
---- `v` is not found.
---- `key` generates a `nil` value for `v`.
---- Length of `t` is zero.
function M.contains(t, val, key)
    local t_len = #t
    if t_len == 0 then
        return false
    end

    local key_fn = key_fn_from_key(key)
    local vh_target = key_fn(val)
    if vh_target == nil then
        return false
    end

    for i = 1, t_len do
        if key_fn(t[i]) == vh_target then
            return true
        end
    end

    return false
end

---Check if all elements in `t` are unique, optionally compared based on `key`.
---@generic T
---@param t T[]
---@param key nil|string|fun(v:T): any See: |key_fn|.
---@return boolean
---Returns false if:
---- A duplicate is found
---- `key` produces a nil value
---- Length of `t` is zero.
function M.diverse(t, key)
    local t_len = #t
    if t_len == 0 then
        return false
    end

    local seen = {} ---@type table<any, true>
    local key_fn = key_fn_from_key(key)
    for i = 1, t_len do
        local vh = key_fn(t[i])
        if vh == nil or seen[vh] ~= nil then
            return false
        end

        seen[vh] = true
    end

    return true
end

---See if all items in `t` match `val`, optionally comparing with `key`. To check with a
---predicate function, use |all()|.
---@generic T
---@param t T[]
---@param val T
---@param key nil|string|fun(v:T): any See: |key_fn|.
---@return boolean
---`false` if:
---- An item not matching `val` is found.
---- `key` produces a `nil` value.
---- Length of `t` is zero.
function M.every(t, val, key)
    local t_len = #t
    if t_len == 0 then
        return false
    end

    local key_fn = key_fn_from_key(key)
    local valh = key_fn(val)
    if valh == nil then
        return false
    end

    for i = 1, t_len do
        if key_fn(t[i]) ~= valh then
            return false
        end
    end

    return true
end

---Check if no items in `t` match `v`, optionally compared based on `key`.
---To check with a predicate function, see |none()|.
---@generic T
---@param t T[]
---@param val T
---@param key nil|string|fun(v:T): any See: |key_fn|.
---@return boolean
---`false` if:
---- `v` is found.
---- `key` generates a `nil` value for `v`.
function M.excluded(t, val, key)
    local t_len = #t
    if t_len == 0 then
        return true
    end

    local key_fn = key_fn_from_key(key)
    local vh_target = key_fn(val)
    if vh_target == nil then
        return false
    end

    for i = 1, t_len do
        if key_fn(t[i]) == vh_target then
            return false
        end
    end

    return true
end

---Get the first item from `t` that satisfies predicate function `f`.
---
---- Use |position()| to return the index.
---- Use |seek()| to search based on a key.
---@generic T
---@param t T[]
---@param f fun(x:T): boolean
---@param rev? boolean (Default: `false`) If true, iterate from the end.
---@return T? The found item.
function M.find(t, f, rev)
    local t_len = #t
    if t_len == 0 then
        return
    end

    local start, stop, step = resolve_rev(1, t_len, rev)
    for i = start, stop, step do
        local v = t[i]
        if f(v) then
            return v
        end
    end
end

---Get a new table of all indexes in `t` containing `val`, optionally filtered with `key`.
---@generic T
---@param t T[]
---@param val T
---@param key nil|string|fun(v:T): any See: |key_fn|.
---@return uinteger[]? Empty table if no results.
function M.indices(t, val, key)
    local t_len = #t
    local ret = {} ---@type uinteger[]
    if t_len == 0 then
        return ret
    end

    local key_fn = key_fn_from_key(key)
    local vh_target = key_fn(val)
    if vh_target == nil then
        return ret
    end

    local j = 1
    for i = 1, t_len do
        if key_fn(t[i]) == vh_target then
            ret[j] = i
            j = j + 1
        end
    end

    return ret
end

---Locate the first index containing `val` in `t`, optionally comparing with `key`.
---To locate with a predicate function, use |position()|.
---To return the value, use |seek()|.
---@generic T
---@param t T[]
---@param val T
---@param key nil|string|fun(v:T): any See: |key_fn|.
---@param rev? boolean (Default: `false`) If true, iterate from the end.
---@return uinteger?
---`nil` if:
---- `val` is not found
---- Length of `t` is zero
---- `key` applied to `val` is nil.
function M.locate(t, val, key, rev)
    local t_len = #t
    if t_len == 0 then
        return
    end

    local key_fn = key_fn_from_key(key)
    local valh = key_fn(val)
    if valh == nil then
        return
    end

    local start, stop, step = resolve_rev(1, t_len, rev)
    for i = start, stop, step do
        if key_fn(t[i]) == valh then
            return i
        end
    end
end

---Get the maximum value from `t`, optionally filtering with `key`.
---To calculate based on function logic, use |reduce()|.
---@generic T
---@param t T[]
---@param key nil|string|fun(v:T): any See: |key_fn|.
---@return T? Nil if `t` is empty or if `key` returns a nil.
function M.max(t, key)
    local t_len = #t
    if t_len == 0 then
        return
    end

    local key_fn = key_fn_from_key(key)
    local v_max = t[1]
    local vh_max = key_fn(v_max)
    if not vh_max then
        return
    end

    for i = 2, t_len do
        local v = t[i]
        local vh = key_fn(v)
        if not vh then
            return
        end

        if vh_max < vh then
            v_max = v
        end
    end

    return v_max
end

---Get the minimum value from `t`, optionally filtering with `key`.
---To calculate based on function logic, use |reduce()|.
---@generic T
---@param t T[]
---@param key nil|string|fun(v:T): any See: |key_fn|.
---@return T? Nil if `t` is empty or if `key` returns a nil.
function M.min(t, key)
    local t_len = #t
    if t_len == 0 then
        return
    end

    local key_fn = key_fn_from_key(key)
    local v_min = t[1]
    local vh_min = key_fn(v_min)
    if not vh_min then
        return
    end

    for i = 2, t_len do
        local v = t[i]
        local vh = key_fn(v)
        if not vh then
            return
        end

        if vh < vh_min then
            v_min = v
        end
    end

    return v_min
end

---Check if no items in `t` satisfy predicate function `f`.
---
---To check with a key, use |excluded()|.
---@generic T
---@param t T[]
---@param f fun(x:T): boolean
---@return boolean Return false if the predicate is satisfied or if the list length is zero.
function M.none(t, f)
    local t_len = #t
    if t_len == 0 then
        return true
    end

    for i = 1, t_len do
        if f(t[i]) then
            return false
        end
    end

    return true
end

---See if `f` is satisfied exactly once within `t`. To check based on a key, use |only()|.
---@generic T
---@param t T[]
---@param f fun(x:T): boolean
---@return boolean ok
---`false` if:
---- A duplicate predicate success is found.
---- Length of `t` is zero.
function M.one(t, f)
    local t_len = #t
    if t_len == 0 then
        return false
    end

    local seen = false
    for i = 1, t_len do
        if f(t[i]) then
            if seen then
                return false
            end

            seen = true
        end
    end

    return seen
end

---See if `val` occurs exactly once within `t`, optionally filtering with `key`. To check with
---a predicate function, see |one()|.
---@generic T
---@param t T[]
---@param val T
---@param key nil|string|fun(v:T): any See: |key_fn|.
---@return boolean
---`false` if:
---- A duplicate of `v` is found.
---- `key` produces a `nil` value for `v`.
---- Length of `t` is zero.
function M.only(t, val, key)
    local t_len = #t
    if t_len == 0 then
        return false
    end

    local key_fn = key_fn_from_key(key)
    local valh = key_fn(val)
    if valh == nil then
        return false
    end

    local seen = false
    for i = 1, t_len do
        if key_fn(t[i]) == valh then
            if seen then
                return false
            end

            seen = true
        end
    end

    return seen
end

---Get the first index of `t` that satisfies predicate function `f`.
---
---- Use |find()| to return the value.
---- Use |locate()| to search based on a key.
---@generic T
---@param t T[]
---@param f fun(x:T): boolean
---@param rev? boolean (Default: `false`) If true, iterate from the end.
---@return uinteger? Index of the found item. `nil` if not found.
function M.position(t, f, rev)
    local t_len = #t
    if t_len == 0 then
        return
    end

    local start, stop, step = resolve_rev(1, t_len, rev)
    for i = start, stop, step do
        if f(t[i]) then
            return i
        end
    end
end

---Get a new list of indices satisfying predicate function `f`.
---
---- Use |select()| to return the values.
---- Use |indices()| to compare based on a key.
---@generic T
---@param t T[]
---@param f fun(x:T): boolean
---@return uinteger[] Returns an empty table if no items found.
function M.positions(t, f)
    local t_len = #t
    local ret = {}
    if t_len == 0 then
        return ret
    end

    local j = 1
    for i = 1, t_len do
        if f(t[i]) then
            ret[j] = i
            j = j + 1
        end
    end

    return ret
end

---Check if all elements in `t` are the same, optionally using a `key`.
---
---To check with a predicate function, see |all()|.
---@generic T
---@param t T[]
---@param key nil|string|fun(v:T): any See: |key_fn|.
---@return boolean
---`false` if:
---- A unique value is found.
---- Table length is zero.
---- `key` generates a `nil` value.
function M.same(t, key)
    local t_len = #t
    if t_len == 0 then
        return false
    end

    if t_len == 1 then
        return true
    end

    local key_fn = key_fn_from_key(key)
    local vh1 = key_fn(t[1])
    if vh1 == nil then
        return false
    end

    for i = 2, t_len do
        if key_fn(t[i]) ~= vh1 then
            return false
        end
    end

    return true
end

---Return the first occurrence of `val` in `t`, optionally filtering with `key` (recommended.
---Otherwise, prefer |contains()| for a simple boolean check).
---To use a predicate function, use |find()|.
---To get the relevant index, use |locate()|.
---@generic T
---@param t T[]
---@param val T
---@param key nil|string|fun(v:T): any See: |key_fn|.
---@param rev? boolean If `true`, start from the end of the list.
---@return T?
---`nil` if:
---- `val` is not found
---- Length of `t` is zero
---- `key` applied to `val` is nil.
function M.seek(t, val, key, rev)
    local t_len = #t
    if t_len == 0 then
        return
    end

    local key_fn = key_fn_from_key(key)
    local valh = key_fn(val)
    if valh == nil then
        return
    end

    local start, stop, step = resolve_rev(1, t_len, rev)
    for i = start, stop, step do
        local v = t[i]
        if key_fn(v) == valh then
            return v
        end
    end
end

---Create a new list with a copy of every occurrence of `val` in `t`, optinally filtered by `key`.
---- Use |indices()| to return the indices.
---- Use |filter_to()| to search based on a predicate function.
---@generic T
---@param val T
---@param key nil|string|fun(v:T): any See: |key_fn|.
---@return T[] Returns an empty table if no items found or `key` produces a `nil` value from
---     `val`.
function M.select(t, val, key)
    local t_len = #t
    local ret = {}
    if t_len == 0 then
        return ret
    end

    local key_fn = key_fn_from_key(key)
    local valh = key_fn(val)
    if valh == nil then
        return ret
    end

    local j = 1
    for i = 1, t_len do
        local v = t[i]
        if key_fn(v) == valh then
            ret[j] = v
            j = j + 1
        end
    end

    return ret
end

---Return a list of boolean values based on the presence of `val`.
---To generate selectors from predicate logic, use |filter_map_to()|.
---@generic T
---@param t T[]
---@param val T
---@param key nil|string|fun(v:T): any See: |key_fn|.
---@return boolean[]? `nil` if table length is zero.
function M.selectors(t, val, key)
    local t_len = #t
    if t_len == 0 then
        return
    end

    local ret = {} ---@type boolean[]
    local key_fn = key_fn_from_key(key)
    local vh_target = key_fn(val)
    if vh_target == nil then
        return ret
    end

    for i = 1, t_len do
        ret[#ret + 1] = key_fn(t[i]) == vh_target
    end

    return ret
end

---See if all of or none of the values in `t` match `val`, optionally filtering with `key`.
---To check with a predicate, use |consistent()|.
---@generic T
---@param t T[]
---@param val T
---@param key nil|string|fun(v:T): any See: |key_fn|.
---@return boolean
---`false` if:
---- More than one of, but not all items match `val`.
---- `key` produces a `nil` value.
---- Length of `t` is zero.
function M.uniform(t, val, key)
    local t_len = #t
    if t_len == 0 then
        return false
    end

    local key_fn = key_fn_from_key(key)
    local valh = key_fn(val)
    if valh == nil then
        return false
    end

    local vh1 = key_fn(t[1])
    local expected = vh1 == valh
    for i = 1, t_len do
        if (key_fn(t[i]) == valh) ~= expected then
            return false
        end
    end

    return true
end

--------------------------------
-- MARK: List to New Value(s) --
--------------------------------

---Apply a function to a list's elements, transforming them into a single value.
---@generic T
---@param t T[]
---@param f fun(acc:any, x:T, idx:uinteger): acc:any  Takes as inputs the accumulator,
---     current list value, and current list index. Returns the next accumulator.
---     Returning a `nil` accumulator value will be accepted and overwrite the previous value.
---@param init any First accumulator value. If `nil`, the first value of `t`.
---@see |iter-indexing|
---@param start integer? (Default: `1`)
---@param stop integer? Default: Length of `t`
---@param rev? boolean (Default: `false`) If true, iterate from the end.
---@return any `init` if `t` is length zero.
function M.fold(t, f, init, start, stop, rev)
    local t_len = #t
    start = iter_idx_resolve(start, t_len, 1)
    stop = iter_idx_resolve(stop, t_len, t_len)
    if t_len == 0 or start > stop then
        return init
    end

    local step
    start, stop, step = resolve_rev(start, stop, rev)
    local acc = init
    if acc == nil then
        acc = t[start]
        start = start + step
    end

    for i = start, stop, step do
        acc = f(acc, t[i], i)
    end

    return acc
end

---Apply a function to a list's elements, transforming them into two values.
---@generic T
---@param t T[]
---@param f fun(acc:any, acc2:any, x:T, idx:uinteger): acc:any, acc2:any  Takes as inputs the
---     accumulators, current list value, and current list index. Returns the next accumulators.
---     `nil` values will overwrite the previous accumulators.
---@param init any First accumulator value. Value at the `start` index if nil.
---@param init2 any Second accumulator value. Accepts a `nil` value without additional
---     transformation.
---@see |iter-indexing|
---@param start integer? (Default: `1`)
---@param stop integer? Default: Length of `t`
---@param rev? boolean (Default: `false`) If true, iterate from the end.
---@return any, any `init`, `init2` if `t` is length zero.
function M.fold2(t, f, init, init2, start, stop, rev)
    local t_len = #t
    start = iter_idx_resolve(start, t_len, 1)
    stop = iter_idx_resolve(stop, t_len, t_len)
    if t_len == 0 or start > stop then
        return init, init2
    end

    local step
    start, stop, step = resolve_rev(start, stop, rev)
    local acc = init
    if acc == nil then
        acc = t[start]
        start = start + step
    end

    local acc2 = init2
    for i = start, stop, step do
        acc, acc2 = f(acc, acc2, t[i], i)
    end

    return acc, acc2
end

---Apply a function to all elements of a list, transforming them into a single value.
---@generic T
---@param t T[]
---@param f fun(acc:any): acc:any `nil` returns are accepted.
---@param init? any Initial accumulator value. If nil, the first element of the list is used.
---@return any `init` if table is length zero.
function M.reduce(t, f, init)
    local t_len = #t
    if t_len == 0 then
        return nil
    end

    local acc = init
    local start = 1
    if acc == nil then
        acc = t[1]
        start = 2
    end

    for _ = start, t_len do
        local new_acc = f(acc)
        if new_acc == nil then
            return acc
        end

        acc = new_acc
    end

    return acc
end
-- TODO: Use these for docgen min and max rather than fold.

---Apply a function to all elements of a list, transforming them into a running list of the
---accumulated values.
---
---Can be used to make any sort of cumulative sum/product/min/max function.
---
---@generic T
---@param t T[]
---@param f fun(acc:any, x:T, idx:uinteger): acc:any `nil` returns will be accepted. The returned
---     list will not have a skipped index. The next iteration will return a nil accumulator.
---@param init any First accumulator value. If `nil`, the value of `t` at `start` will be used.
---@see |iter-indexing|
---@param start integer? (Default: `1`)
---@param stop integer? Default: Length of `t`
---@param rev? boolean (Default: `false`) If true, iterate from the end.
---@return any[] New list containing the running accumulator values. If `t` is nil, will only
---     contain init.
function M.scan(t, f, init, start, stop, rev)
    local t_len = #t
    start = iter_idx_resolve(start, t_len, 1)
    stop = iter_idx_resolve(stop, t_len, t_len)
    if t_len == 0 or start > stop then
        return init
    end

    local step
    start, stop, step = resolve_rev(start, stop, rev)
    local acc = init
    if acc == nil then
        acc = t[start]
        start = start + step
    end

    local ret = { acc } ---@type any[]

    for i = 1, t_len do
        acc = f(acc, t[i], i)
        if acc ~= nil then
            ret[#ret + 1] = acc
        end
    end

    return ret
end

---------------------------
-- MARK: List Transforms --
---------------------------

---Combine values in `t` based on function `f`.
---The list is traversed linearly, rather than product-wise. If you're trying to do something like
---find overlapping ranges, the list needs to be sorted.
---@generic T
---@param t T[] Modified in place!
---@param f fun(x:T, y:T): v:T|nil If `nil` is returned, `y` is kept.
---If a value is returned, it replaces `x` and `y` is discarded.
---@return T[] The original list reference.
function M.combine(t, f)
    local t_len = #t
    if t_len <= 1 then
        return t
    end

    local j = 1
    for i = 2, t_len do
        local v2 = t[i]
        local vm = f(t[j], v2)
        if vm == nil then
            j = j + 1
            t[j] = v2
        else
            t[j] = vm
        end
    end

    for i = j + 1, t_len do
        t[i] = nil
    end

    return t
end

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
    local t_len = #t
    start = iter_idx_resolve(start, t_len, 1)
    stop = iter_idx_resolve(stop, t_len, t_len)
    -- TODO: need to properly handle zero length tables here.
    if start > stop then
        return t
    end

    for i = start, stop do
        t[i] = v
    end

    return t
end

---@generic T
---@param t T[] Modified in place!
---@param f fun(x: T): T|nil `nil` returns are filtered.
---@return T[]
function M.filter_map(t, f)
    local t_len = #t
    if t_len == 0 then
        return t
    end

    local j = 1
    for i = 1, t_len do
        local vm = f(t[i])
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

---Create a new list by applying function `f` to the values of `t`.
---@generic T, U
---@param t T[]
---@param f fun(x:T, idx:uinteger): U|nil `nil` returns are filtered.
---@param start integer? (Default: `1`) Leave elements before start un-mapped.
---@param stop? integer Default: Length of `t`. Elements after `stop` will be un-mapped.
---@return U[] New table. Empty if all elements are filtered or if `start` and `stop` produce an
---     invalid range.
---@see |iter-indexing|
function M.filter_map_to(t, f, start, stop)
    local t_len = #t
    start = iter_idx_resolve(start, t_len, 1)
    stop = iter_idx_resolve(stop, t_len, t_len)
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

---Apply function `f` to the elements of `t` in place. An accumulator value is stored between
---iterations.
---@generic T
---@generic U
---@generic V
---@param t T[] Modified in place!
---@param init V Initial accumulator value.
---@param f fun(acc:V, value:T, idx:uinteger): V, U|nil Receives the current accumulator, the
---     currently iterated list value, and the currently iterated index. If `nil` is returned for
---     the list value, it will be filtered.
---@return T[] The original list reference.
function M.filter_map_accum(t, init, f)
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

---@generic T
---@param t T[] Values to aggregate.
---@param key nil|string|fun(v:T): any See: |key_fn|.
function M.group_by(t, key)
    local ret = {}
    local t_len = #t
    if t_len == 0 then
        return ret
    end

    local ntt = require("nvim-tools.table")
    local key_fn = key_fn_from_key(key)
    for i = 1, t_len do
        local v = t[i]
        local vh = key_fn(v)
        if vh ~= nil then
            local ret_vh = ntt.get_or_set_subtable(ret, vh)
            ret_vh[#ret_vh + 1] = v
        end
    end

    return ret
end

---Convert values from list `t` into a list of new values based on a threaded accumulator and an
---optional finalization function.
---@generic T
---@generic U
---@generic V
---@param t T[] Values to transduce.
---@param init U Initial accumulator value
---@param f fun(acc:U, v:T, idx:uinteger): acc:U|nil, v:V|nil
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
    local ret = {}
    local t_len = #t
    start = iter_idx_resolve(start, t_len, 1)
    stop = iter_idx_resolve(stop, t_len, t_len)
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
    start, stop, step = resolve_rev(start, stop, rev)
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
-- TODO: I think you remove the early return from here.

---Transform `t1` in place by applying a function to the values of `t1` and `t2`.
---If `t1` and `t2` are different lengths, the length of the smaller list is used.
---
---This can be used to filter `t1` based on selectors, or to implement a choose() function
---between `t1` and `t2`.
---@generic T
---@generic U
---@generic V
---@param t1 T[]
---@param t2 U[]
---@param f fun(a:T, b:U): val:V|nil If val is `nil`, it will be filtered.
---@return V[] Reference to `t1`.
function M.filter_map_two(t1, t2, f)
    local t1_len = #t1
    local len = math.min(t1_len, #t2)
    local j = 1
    for i = 1, len do
        local vm = f(t1[i], t2[i])
        if vm ~= nil then
            t1[j] = vm
            j = j + 1
        end
    end

    for i = j, t1_len do
        t1[i] = nil
    end

    return t1
end

---Apply a function to the values of `t1` and `t2` to create a new list.
---If `t1` and `t2` are different lengths, the length of the smaller list is used.
---@generic T
---@generic U
---@generic V
---@param t1 T[]
---@param t2 U[]
---@param f fun(a:T, b:U): val:V|nil If val is `nil`, it will be filtered.
---@return V[] New list. Empty if all elements are filtered.
function M.filter_map_two_to(t1, t2, f)
    local len = math.min(#t1, #t2)
    if len == 0 then
        return M.copy(t1)
    end

    local ret = {}
    local j = 1
    for i = 1, len do
        local vm = f(t1[i], t2[i])
        if vm ~= nil then
            ret[j] = vm
            j = j + 1
        end
    end

    return ret
end

---@generic T
---@param dst T[]
---@param iter_len uinteger
---@param sep_count uinteger
---@param new_len uinteger
---@param t T[]
---@param sep T
---@param unit_size uinteger? (Default: `1`)
---@see |iter-indexing|
---@param start uinteger? (Default: `1`)
---@param stop? uinteger Default: Length of `t`
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
---@param unit_size uinteger? (Default: `1`)
---@see |iter-indexing|
---@param start integer? (Default: `1`)
---@param stop? integer Default: Length of `t`
---@return T[] Original list reference
function M.intersperse(t, sep, unit_size, start, stop)
    local t_len = #t
    start = iter_idx_resolve(start, t_len, 1)
    stop = iter_idx_resolve(stop, t_len, t_len)
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
---@param unit_size uinteger? (Default: `1`)
---@see |iter-indexing|
---@param start integer? (Default: `1`)
---@param stop? integer Default: Length of `t`
---@return T[] Original list reference
function M.intersperse_to(t, sep, unit_size, start, stop)
    local t_len = #t
    start = iter_idx_resolve(start, t_len, 1)
    stop = iter_idx_resolve(stop, t_len, t_len)
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
---@param n uinteger Cyclically clamped at length of `t`.
---@param dir? -1|1 (Default: `-1`) -1 shifts elements left, 1 to the right.
---@return T Reference to the original list.
function M.rotate(t, n, dir)
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

    ---@param left uinteger
    ---@param right uinteger
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
---@param n uinteger Amount of indices to shift the list. Cyclically clamped at length of `t`.
---@param dir? -1|1 (Default: `-1`) -1 shifts elements left, 1 to the right.
---@return T[] New list. Copy of the original if `n` is zero.
function M.rotate_to(t, n, dir)
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

-------------------------
-- MARK: Uncategorized --
-------------------------

-- TODO: Categorize these

--- Returns an iterator that infinitely cycles through `t`.
--- Each step yields: `idx` (1-based index within the cycle), `value`, `cycle`
--- (0-based full cycles completed).
---@generic T
---@param t T[]
---@return fun(): uinteger|nil, T|nil, uinteger|nil Nil iter return if length of `t` is zero.
function M.cycle(t)
    local t_len = #t
    if t_len == 0 then
        ---@return nil, nil, nil
        return function()
            return nil, nil, nil
        end
    end

    local i = 0
    ---@generic T
    ---@return uinteger, T, uinteger
    return function()
        i = i + 1
        local idx = ((i - 1) % t_len) + 1
        local cycle = math.floor((i - 1) / t_len)
        return idx, t[idx], cycle
    end
end

return M

-- TODO: More specifically scope utils (biggest ones - The list unique utils.)
