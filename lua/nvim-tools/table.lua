local MAX_INT = math.floor(math.huge)

---@brief Pure Lua functions to operate on lists and tables.
---
---@mod Naming Conventions
---@brief Functions starting with `i_` only operate on the |lua-list| portion of the table. If
---the list is modified in place, the hash elements are unaltered. If a new list is created, the
---hash elements are not transferred over.
---
---Functions ending in `_to` will send their results to a copy. Functions without `_to` modify
---the table in place. Additional specification might be after `_to`.
---
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
---
---@tag key_fn
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

---------------------------
-- MARK: Data Management --
---------------------------

---@brief These functions interact with tables in some low-level way.

-- Port of Neovim core logic since their table module is private
local has_new, new = pcall(require, "table.new")
if not has_new then
    new = function(_narray, _nhash)
        return {}
    end
end

---Create a new table. Runs `table.new` on LuaJIT builds.
---@mark data-management
---@type fun(narray:integer, nhash:integer): table
M.new = new

-- Port of Neovim core logic since their table module is private
local has_clear, clear = pcall(require, "table.clear")
if not has_clear then
    clear = function(t)
        for k in pairs(t) do
            t[k] = nil
        end
    end
end
-- TODO: When I run this it actually nils the table.

---Clear all list and dict data from a table. Runs `table.clear` on LuaJIT builds.
---@mark data-management
---@type fun(tab:table)
M.clear = clear

---Clears all |lua-list| elements in `t`.
---@mark data-management
---@generic T
---@param t T[] Modified in place!
---@return T[] Reference to `t`.
function M.i_clear(t)
    local t_len = #t
    for i = 1, t_len do
        t[i] = nil
    end

    return t
end

---Creates a copy of `t`. References are shallow-copied.
---@nodiscard
---@mark creation
---@mark data-management
---@generic K, V
---@param t table<K, V>
---@return table<K, V>
function M.copy(t)
    local ret = {}
    for k, v in pairs(t) do
        ret[k] = v
    end

    return ret
end

---Creates a shallow copy of the |lua-list| elements of `t`.
---@nodiscard
---@mark creation
---@mark data-management
---@generic T
---@param t T[]
---@return T[]
function M.i_copy(t)
    local t_len = #t
    if t_len == 0 then
        return {}
    end

    return require("nvim-tools._table").i_copy_exact(t, 1, t_len)
end

---@generic T
---@param t T
---@param prev table<T, true>
---@return any
local function deepcopy(t, prev)
    local t_type = type(t)
    if t_type == "userdata" or t_type == "thread" then
        return
    end

    if t_type ~= "table" then
        return t
    end

    if prev[t] == true then
        return
    end

    prev[t] = true

    local copy = {}
    for k, v in pairs(t) do
        local dk = deepcopy(k, prev)
        if dk ~= nil then
            local dv = deepcopy(v, prev)
            if dv ~= nil then
                copy[dk] = dv
            end
        end
    end

    prev[t] = nil
    return copy
end

---Differences from |vim.deepcopy()|:
---- `userdata` and `thread` values are discarded rather than erroring. Beware that, if either
---data type is used as a table key, the table value will be lost.
---- No special handling for `vim.NIL`.
---- Always "noref" behavior, meaning that repeated references to the same table each get a
---new copy. If a cyclic reference is detected, it is discarded.
---- Assumes that neither table has a metatable.
---@param t table<any, any>
---@return table<any, any>
function M.deepcopy(t)
    return deepcopy(t, {})
end
-- TODO-DEP: Handle metatables if a use case comes up.

---Deep copies the list elements only.
---@generic T
---@param t T[]
---@return T[]
function M.i_deepcopy(t)
    local t_len = #t
    if t_len == 0 then
        return {}
    end

    local ret = {}
    local prev = {}
    local j = 1
    for i = 1, t_len do
        ret[j] = deepcopy(t[i], prev)
        j = j + 1
    end

    return ret
end

---Evaluate if `t` is a |lua-dict|.
---@audited 2026-07-03
---@param t any
---@return 0|1|2
---- 0: Not a |lua-table|, or a |lua-list|.
---- 1: An empty |lua-table|.
---- 2: A |lua-dict|.
function M.is_dict(t)
    if type(t) ~= "table" then
        return 0
    end

    if next(t) == nil then
        return 1
    end

    local len = #t
    if len == 0 then
        return 2
    end

    local count = 0
    for k in pairs(t) do
        count = count + 1
        if type(k) ~= "number" or k < 1 or k > len or k ~= math.floor(k) then
            return 2
        end
    end

    return (count == len) and 0 or 2
end
-- TODO: Go over usages

----------------------------
-- MARK: Table Properties --
----------------------------

---@brief Get basic information about a table.

---Get a |lua-list| of all keys from `t`.
---@mark table-properties
---@audited 2026-07-05
---@generic K, V
---@param t table<K, V>
---@return K[]
function M.keys(t)
    local ret = {}
    local i = 1
    for k, _ in pairs(t) do
        ret[i] = k
        i = i + 1
    end

    return ret
end

---Get the amount of keys in a table.
---@mark table-properties
---@generic K, V
---@param t table<K, V>
---@return uinteger
function M.keys_count(t)
    local count = 0
    for _, _ in pairs(t) do
        count = count + 1
    end

    return count
end

--------------------------
-- MARK: Table Creation --
--------------------------

---Removes values from `t` in-place from `start` to `stop`.
---
---NOTE: `stop` is inclusive.
---
---No-op if the resolved value of `start` is greater than `stop`.
---@mark cleansing
---@mark table-creation
---@generic T
---@param t T[] Modified in place!
---@param start integer See |iter-indexing|.
---@param stop integer See |iter-indexing|.
---@return T[] Reference to `t`.
function M.i_expel(t, start, stop)
    local t_len = #t
    local _ntt = require("nvim-tools._table")
    start = _ntt.iter_idx_resolve(start, 1, t_len)
    stop = _ntt.iter_idx_resolve(stop, t_len, t_len)
    if t_len == 0 or (start == 1 and stop == t_len) then
        return M.i_clear(t)
    end

    if start <= stop then
        require("nvim-tools._table").shift_down_exact(t, t_len, stop + 1, t_len, start)
        return t
    end

    return t
end

---Creates a new |lua-list| of values from `t` excluding those between `start` and `end`
---inclusive. References are shallow-copied.
---
---NOTE: `stop` is inclusive.
---
---If the resolved value of `start` is greater than `stop`, copy the whole table.
---@mark cleansing
---@mark table-creation
---@generic T
---@param t T[] Modified in place!
---@param start integer See |iter-indexing|.
---@param stop integer See |iter-indexing|.
---@return T[]
function M.i_expel_to(t, start, stop)
    local t_len = #t
    local _ntt = require("nvim-tools._table")
    start = _ntt.iter_idx_resolve(start, 1, t_len)
    stop = _ntt.iter_idx_resolve(stop, t_len, t_len)
    if t_len == 0 or (start == 1 and stop == t_len) then
        return {}
    elseif start > stop then
        return require("nvim-tools._table").i_copy_exact(t, 1, t_len)
    end

    local stop_first = start - 1
    local start_second = stop + 1
    local len_end = t_len - start_second + 1
    local ret = M.new(stop_first + len_end, 0)

    local j = 1
    for i = 1, stop_first do
        ret[j] = t[i]
        j = j + 1
    end

    j = stop + 1
    for i = start_second, t_len do
        ret[j] = t[i]
        j = j + 1
    end

    return t
end

---Creates a new |lua-list| containing `val` repeated `count` times. References are shallow-copied.
---
---If `count` is zero, an empty table is returned.
---@mark table-creation
---@generic T
---@param val T
---@param count uinteger
---@return T[]
function M.i_replicate(val, count)
    if count == 0 then
        return {}
    end

    return require("nvim-tools._table").i_replicate_to_do(val, count)
end
-- Named `replicate` because `repeat` is a Lua keyword.

---Splice `t` in-place into a subset of its values.
---
---NOTE: `stop` is inclusive.
---
---Clears `t` if the resolved value of `start` is greater than `stop`.
---@mark cleansing
---@mark table-creation
---@generic T
---@param t T[] Modified in place!
---@param start integer See |iter-indexing|.
---@param stop integer See |iter-indexing|.
---@return T[] Reference to `t`.
function M.i_splice(t, start, stop)
    local t_len = #t
    local _ntt = require("nvim-tools._table")
    start = _ntt.iter_idx_resolve(start, 1, t_len)
    stop = _ntt.iter_idx_resolve(stop, t_len, t_len)
    if t_len == 0 or (start == 1 and stop == t_len) then
        return t
    end

    if start <= stop then
        require("nvim-tools._table").shift_down_exact(t, t_len, start, stop, 1)
        return t
    end

    M.i_clear(t)
    return t
end

---Creates a new |lua-list| containing a subset of `t` defined by `start` and `stop`. References
---are shallow-copied.
---
---NOTE: `stop` is inclusive.
---
---Returns an empty table if `t` is length zero or `start` resolves to a value greater than
---`stop`.
---@mark cleansing
---@mark table-creation
---@generic T
---@param t T[]
---@param start integer See |iter-indexing|.
---@param stop integer See |iter-indexing|.
---@return T[]
function M.i_splice_to(t, start, stop)
    local t_len = #t
    local _ntt = require("nvim-tools._table")
    start = _ntt.iter_idx_resolve(start, 1, t_len)
    stop = _ntt.iter_idx_resolve(stop, t_len, t_len)
    if t_len == 0 or (start > stop) then
        return {}
    end

    return require("nvim-tools._table").i_copy_exact(t, start, stop)
end

---Create a new |lua-list|, using function `f` to iteratively mutate an initial seed value.
---@mark creation
---@generic T
---@param init T Becomes the new list's first value. Empty table if `nil` is passed.
---@param f fun(x:T, idx:uinteger): T|nil Receives the tail value of the return list and its
---index. Returns the next list value. If the return is `nil`, list building ends and the
---current results are returned.
---@param limit? uinteger (Default: Lua max int) Max results to write.
---@return T[]
function M.i_successors(init, f, limit)
    local ret = { init }
    if #ret == 0 then
        return ret
    end

    limit = limit or MAX_INT
    local i = 1
    local j = 2
    while j <= limit do
        local v = f(ret[i], i)
        if v == nil then
            return ret
        end

        ret[j] = v
        i = i + 1
        j = j + 1
    end

    return ret
end
-- TODO: Is `tail` value the correct terminology?

---Create a new |lua-list| that unfolds an accumulator starting from `init` using function `f`.
---@mark creation
---@generic T, A
---@param init A Returns an empty table if `nil`.
---@param f fun(acc:A, idx:uinteger): A|nil, T|nil Receives the current accumulator and index
---to be written. Returns the next accumulator and the value to be written. If either value is
---nil, unfolding ends and the current results are returned.
---@param limit? uinteger (Default: Lua max int) Max results to write.
---@return T[], A The new list and final accumulator.
function M.i_unfold(init, f, limit)
    local ret = {}
    local acc = init
    if acc == nil then
        return ret, init
    end

    limit = limit or MAX_INT
    local v
    local i = 1
    while i <= limit do
        acc, v = f(acc, i)
        if acc == nil or v == nil then
            return ret, acc
        end

        ret[i] = v
        i = i + 1
    end

    return ret, acc
end

-----------------------------------
-- MARK: Direct Access Functions --
-----------------------------------

---@brief Functions for directly accessing tables.

---Deletes a value from `t` at `idx` and returns it.
---
---Prefer |table.remove()| unless the index ergonomics are required.
---@mark direct-access
---@generic T
---@param t T[] Modified in place!
---@param idx integer See |iter-indexing|.
---@return T|nil `nil` if list length is zero.
function M.i_drain(t, idx)
    local t_len = #t
    if t_len == 0 then
        return nil
    end

    local res_idx = require("nvim-tools._table").iter_idx_resolve_no_default(idx, t_len)
    local v = t[res_idx]
    for i = res_idx + 1, t_len do
        t[i - 1] = t[i]
    end

    t[t_len] = nil
    return v
end

---Wrap `t` in a metatable that prevents it from being written to.
---@audited 2026-07-03
---@param t table
---@return table
function M.freeze(t)
    return setmetatable({}, {
        __index = t,
        __newindex = function(_, _)
            error("Attempt to modify read-only config table")
        end,
        __metatable = false, -- prevents getmetatable() from revealing the real table
    })
end

---Bespoke version because of future tbl_ deprecation
---The tbl_ version also does not contain the t == nil guard.
---Like the built-in, will only return non-nil if it is able to traverse the specific path
---specified in the args to a non-nil value.
---If no args, just return the table.
---@mark direct-access
---@param t? table Table to index
---@param ... any Optional keys (0 or more, variadic) via which to index the table
---@return any # Nested value indexed by key (if it exists), else nil
function M.get(t, ...)
    if t == nil then
        return nil
    end

    local nargs = select("#", ...)
    if nargs == 0 then
        return t
    end

    local v = t
    local args = { ... }
    for i = 1, nargs do
        v = v[args[i]]
        if v == nil then
            return nil
        elseif type(v) ~= "table" and i ~= nargs then
            return nil
        end
    end

    return v
end

---@mark direct-access
---@generic K
---@param t table<K, table>
---@param k K
---@return table
function M.get_or_set_subtable(t, k)
    local ret = t[k]
    if ret ~= nil then
        return ret
    end

    local v = {}
    t[k] = v
    return v
end

---Inserts a new `val` into |lua-list| `t` at `idx`.
---
---If `idx` is nil, append to the end of the table.
---
---If the list is < 100 items, prefer |table.insert()| unless the index ergonomics are required.
---@mark direct-access
---@generic T
---@param t T[] Modified in place!
---@param val T
---@param idx? integer See |iter-indexing| If no index, append to the end like |table.insert()|.
function M.i_insert_at(t, val, idx)
    local t_len = #t
    if not idx or t_len == 0 then
        t[t_len + 1] = val
        return
    end

    local res_idx = require("nvim-tools._table").iter_idx_resolve_no_default(idx, t_len)
    local stop = res_idx + 1
    for i = t_len + 1, stop, -1 do
        t[i] = t[i - 1]
    end

    t[res_idx] = val
end
-- TODO: set? adjust? Doesn't adjust typically apply a function though?

---Gets the value from `t` at index `idx`. Does not copy references.
---@mark direct-access
---@generic T
---@param t T[]
---@param idx uinteger See |iter-indexing|.
---@return T? `nil` if the table is empty.
function M.i_nth(t, idx)
    local t_len = #t
    if t_len == 0 then
        return nil
    end

    return t[require("nvim-tools._table").iter_idx_resolve_no_default(idx, t_len)]
end

---Removes an element from |lua-list| `t` at `idx`.
---
---Prefer |table.remove()| unless the index ergonomics are required.
---@mark direct-access
---@generic T
---@param t T[] Modified in place!
---@param idx uinteger See |iter-indexing|.
function M.i_rm_at(t, idx)
    local t_len = #t
    if t_len == 0 then
        return
    end

    for i = require("nvim-tools._table").iter_idx_resolve_no_default(idx, t_len) + 1, t_len do
        t[i - 1] = t[i]
    end

    t[t_len] = nil
end
-- TODO: del or delete?

----------------------
-- MARK: Evaluation --
----------------------

-- |-------|----------|-----------|------------|---------
-- | Logic | key      | val       | predicate  | vacuous
-- |-------|----------|-----------|------------|---------
-- | AND   | same     | every     | all        | yes
-- | OR    | amiss    | includes  | any        | no
-- | XOR   | diverse  | ???       | ???        | ???
-- | NAND  | amiss    | deficient | incomplete | no
-- | NOR   | diverse? | excludes  | none       | no
-- | XNOR  | same     | uniform   | consistent | yes
-- | ONE   | ???      | only      | one        | no
-- |-------|----------|-----------|------------|---------
-- MID: Should at "at least one, but not all"/XOR logic
-- LOW: No "ONE" logic for key only.
-- LOW: Unsure if diverse is correct for NOR.

---@generic K, V
---@param t table<K, V>
---@param f fun(k:K, v:V): boolean
---@return boolean
local function all_do(t, f)
    for k, v in pairs(t) do
        if not f(k, v) then
            return false
        end
    end

    return true
end

---Check if all items in |lua-table| `t` satisfy predicate function `f`.
---@mark eval
---@audited 2026-07-08
---@generic K, V
---@param t table<K, V>
---@param f fun(k:K, v:V): boolean
---@return boolean `True` if table has no keys.
function M.all(t, f)
    return all_do(t, f)
end

---Check if a |lua-table| `t` is non-empty and all elements satisfy predicate function `f`.
---@mark eval
---@audited 2026-07-08
---@generic K, V
---@param t table<K, V>
---@param f fun(k:K, v:V): boolean
---@return boolean `False` if table has no keys.
function M.all_nonempty(t, f)
    if next(t) == nil then
        return false
    end

    return all_do(t, f)
end

---@generic T
---@param t T[]
---@param f fun(x:T): boolean
---@return boolean
local function i_all_do(t_len, t, f)
    for i = 1, t_len do
        if not f(t[i]) then
            return false
        end
    end

    return true
end

---Checks if all items in |lua-list| `t` satisfy predicate function `f`.
---@mark evaluation
---@generic T
---@param t T[]
---@param f fun(x:T): boolean
---@return boolean `True` if length of `t` is zero.
function M.i_all(t, f)
    return i_all_do(#t, t, f)
end

---Checks if |lua-list| `t` is non-empty and all items satisfy predicate function `f`.
---@mark evaluation
---@generic T
---@param t T[]
---@param f fun(x:T): boolean
---@return boolean `False` if length of `t` is zero.
function M.i_all_nonempty(t, f)
    local t_len = #t
    if t_len == 0 then
        return false
    end

    return i_all_do(t_len, t, f)
end

---Check if at least one element in `t` is different from the others, optionally using a `key`.
---@mark evaluation
---@generic T
---@param t T[]
---@param key nil|string|fun(v:T): any See: |key_fn|.
---@return boolean `False` if length of `t` is <=1 or `key` generates any `nil` values.
function M.i_amiss(t, key)
    local t_len = #t
    if t_len <= 1 then
        return false
    end

    local key_fn = require("nvim-tools._table").key_fn_from_key(key)
    local vh1 = key_fn(t[1])
    if vh1 == nil then
        return false
    end

    for i = 2, t_len do
        local vh = key_fn(t[i])
        if vh == nil then
            return false
        end

        if vh ~= vh1 then
            return true
        end
    end

    return false
end

---Check if any items in |lua-table| `t` satisfy predicate function `f`.
---@mark eval
---@audited 2026-07-08
---@generic K, V
---@param t table<K, V>
---@param f fun(k:K, v:V): boolean
---@return boolean `False` if table has no values.
function M.any(t, f)
    for k, v in pairs(t) do
        if f(k, v) then
            return true
        end
    end

    return false
end

---Checks if any items in |lua-list| `t` satisfy predicate function `f`.
---@mark eval
---@generic T
---@param t T[]
---@param f fun(x:T): boolean
---@return boolean `False` if `t` is empty.
function M.i_any(t, f)
    local t_len = #t
    for i = 1, t_len do
        if f(t[i]) then
            return true
        end
    end

    return false
end

---For a two-dimensional array `tt`, gets the highest index where all sub-|lua-lists| share the
---same values. Optionally compare with `key`.
---
---Returns `nil` if the first indices do not share a value or if one of the lists has a length of
---zero.
---@mark evaluation
---@generic T
---@param tt T[][]
---@param key nil|string|fun(v:T): any See: |key_fn|.
---@return uinteger?
function M.i_common_prefix(tt, key)
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
            return
        end

        tt_len_min = math.min(tt_len_min, tt_len_i)
    end

    local key_fn = require("nvim-tools._table").key_fn_from_key(key)
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

---Checks if a single |lua-table| `t` passes predicate `f`.
---@mark evaluation
---@generic K, V
---@param t table<K, V>
---@param f fun(t:table<K, V>): boolean
---@return boolean
function M.conforms(t, f)
    return f(t)
end

---@generic T
---@param t T[]
---@param f fun(x:T): boolean
---@return boolean
local function i_consistent_do(t_len, t, f)
    local expected = f(t[1])
    for i = 2, t_len do
        if f(t[i]) ~= expected then
            return false
        end
    end

    return true
end

---Check if all of or none of the items in |lua-list| `t` satisfy predicate function `f`.
---@mark evaluation
---@generic T
---@param t T[]
---@param f fun(x:T): boolean
---@return boolean `True` if `t` is length zero.
function M.i_consistent(t, f)
    return i_consistent_do(#t, t, f)
end

---Check if |lua-list| `t` is non-empty and all of or none of the items satisfy predicate
---function `f`.
---@mark evaluation
---@generic T
---@param t T[]
---@param f fun(x:T): boolean
---@return boolean `False` if `t` is length zero.
function M.i_consistent_nonempty(t, f)
    local t_len = #t
    if t_len == 0 then
        return false
    end

    return i_consistent_do(t_len, t, f)
end

---Checks if at least one item in |lua-list| `t` does not match `val`, optionally comparing with
---`key`.
---@mark evaluation
---@generic T
---@param t T[]
---@param val T
---@param key nil|string|fun(v:T): any See: |key_fn|.
---@return boolean `False` if `t` is empty or `key` produces any `nil` values.
function M.i_deficient(t, val, key)
    local key_fn = require("nvim-tools._table").key_fn_from_key(key)
    local valh = key_fn(val)
    if valh == nil then
        return false
    end

    local t_len = #t
    for i = 1, t_len do
        local vh = key_fn(t[i])
        if vh == nil then
            return false
        end

        if vh ~= valh then
            return true
        end
    end

    return false
end

---Check if all elements in `t` are unique, optionally compared based on `key`.
---@generic T
---@param t T[]
---@param key nil|string|fun(v:T): any See: |key_fn|.
---@return boolean `True` if `t` is empty. `False` if `key` produces any `nil` value.
function M.i_diverse(t, key)
    local t_len = #t
    local seen = {} ---@type table<any, true>
    local key_fn = require("nvim-tools._table").key_fn_from_key(key)
    for i = 1, t_len do
        local vh = key_fn(t[i])
        if vh == nil or seen[vh] ~= nil then
            return false
        end

        seen[vh] = true
    end

    return true
end

---@generic T
---@param t_len uinteger
---@param t T[]
---@param val T
---@param key nil|string|fun(v:T): any
---@return boolean
local function i_every_do(t_len, t, val, key)
    local key_fn = require("nvim-tools._table").key_fn_from_key(key)
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

---Check if all items in |lua-list| `t` match `val`, optionally comparing with `key`.
---@mark evaluation
---@generic T
---@param t T[]
---@param val T
---@param key nil|string|fun(v:T): any See: |key_fn|.
---@return boolean `True` if `t` is empty, `false` if `key` produces any `nil` values.
function M.i_every(t, val, key)
    return i_every_do(#t, t, val, key)
end

---Check if |lua-list| `t` has at least one element, and if all elements match `val`, optionally
---compared with `key`.
---@mark evaluation
---@generic T
---@param t T[]
---@param val T
---@param key nil|string|fun(v:T): any See: |key_fn|.
---@return boolean `False` if `t` is empty or if `key` produces any `nil` values.
function M.i_every_nonempty(t, val, key)
    local len_t = #t
    if len_t == 0 then
        return false
    end

    return i_every_do(#t, t, val, key)
end

---Iterate through `t1` and `t2`, comparing their elements by index. Optionally provide a `key`
---to process the values.
---
---True if both tables are length zero. Always `false` if the tables are different lengths.
---@mark evaluation
---@generic T, U
---@param t1 T[]
---@param t2 U[]
---@param key nil|string|fun(v:T): any See: |key_fn|.
---@return boolean
function M.i_equals(t1, t2, key)
    local len = #t1
    local t2_len = #t2
    if len ~= t2_len then
        return false
    end

    local key_fn = require("nvim-tools._table").key_fn_from_key(key)
    for i = 1, len do
        if key_fn(t1[i]) ~= key_fn(t2[i]) then
            return false
        end
    end

    return true
end

---Checks if no items in `t` match `val`, optionally compared based on `key`.
---@mark eval
---@generic T
---@param t T[]
---@param val T
---@param key nil|string|fun(v:T): any See: |key_fn|.
---@return boolean `True` if `t` is empty. `False` if `key` returns any `nil` values.
function M.i_excludes(t, val, key)
    local t_len = #t
    local key_fn = require("nvim-tools._table").key_fn_from_key(key)
    local vh_target = key_fn(val)
    if vh_target == nil then
        return false
    end

    for i = 1, t_len do
        local vh = key_fn(t[i])
        if vh == vh_target then
            return false
        elseif vh == nil then
            return false
        end
    end

    return true
end

---Check if any item in `t` matches `val`, optionally comparing based on `key`.
---@mark eval
---@generic T
---@param t T[]
---@param val T
---@param key nil|string|fun(v:T): any See: |key_fn|.
---@return boolean `False` if `t` is empty or `key` returns any `nil` values.
function M.i_includes(t, val, key)
    local key_fn = require("nvim-tools._table").key_fn_from_key(key)
    local vh_target = key_fn(val)
    if vh_target == nil then
        return false
    end

    local t_len = #t
    for i = 1, t_len do
        local vh = key_fn(t[i])
        if vh == vh_target then
            return true
        elseif vh == nil then
            return false
        end
    end

    return false
end

---Checks if at least one item in `t` does not satisfy predicate function `f`.
---@mark evaluation
---@generic T
---@param t T[]
---@param f fun(x:T): boolean
---@return boolean `False` if length of `t` is zero.
function M.i_incomplete(t, f)
    local t_len = #t
    for i = 1, t_len do
        if not f(t[i]) then
            return true
        end
    end

    return false
end

---Check if no items in |lua-list| `t` satisfy predicate function `f`.
---@mark eval
---@generic T
---@param t T[]
---@param f fun(x:T): boolean
---@return boolean `True` if `t` is empty.
function M.i_none(t, f)
    local t_len = #t
    for i = 1, t_len do
        if f(t[i]) then
            return false
        end
    end

    return true
end

---Checks if `f` is satisfied exactly once within `t`.
---@mark evaluation
---@generic T
---@param t T[]
---@param f fun(x:T): boolean
---@return boolean False if length of `t` is zero.
function M.i_one(t, f)
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

---Checks if `val` occurs exactly once within `t`, optionally filtering with `key`.
---@mark evaluation
---@generic T
---@param t T[]
---@param val T
---@param key nil|string|fun(v:T): any See: |key_fn|.
---@return boolean
function M.i_only(t, val, key)
    local t_len = #t
    if t_len == 0 then
        return false
    end

    local key_fn = require("nvim-tools._table").key_fn_from_key(key)
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

---@generic T
---@param t T[]
---@param key nil|string|fun(v:T): any See: |key_fn|.
---@return boolean
local function i_same_do(t_len, t, key)
    local key_fn = require("nvim-tools._table").key_fn_from_key(key)
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

---Check if all elements in `t` are the same, optionally using a `key`.
---
---Returns `false` if length of `t` is zero or `key` generates a `nil` value.
---@mark evaluation
---@generic T
---@param t T[]
---@param key nil|string|fun(v:T): any See: |key_fn|.
---@return boolean `True` if `t` is empty. `False` if `key` produces any `nil` values.
function M.i_same(t, key)
    local t_len = #t
    if t_len == 0 then
        return true
    end

    return i_same_do(t_len, t, key)
end

---Check if |lua-list| `t` is non-empty and all elements are the same, optionally comparing with
---a `key`.
---@mark evaluation
---@generic T
---@param t T[]
---@param key nil|string|fun(v:T): any See: |key_fn|.
---@return boolean `False` if `t` is empty or `key` produces any `nil` values.
function M.i_same_nonempty(t, key)
    local t_len = #t
    if t_len == 0 then
        return false
    end

    return i_same_do(t_len, t, key)
end

---@generic T
---@param t T[]
---@param val T
---@param key nil|string|fun(v:T): any
---@return boolean
local function i_uniform_do(t_len, t, val, key)
    local key_fn = require("nvim-tools._table").key_fn_from_key(key)
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

---Check if all of or none of the values in `t` match `val`, optionally comparing with `key`.
---@mark evaluation
---@generic T
---@param t T[]
---@param val T
---@param key nil|string|fun(v:T): any See: |key_fn|.
---@return boolean `True` if `t` is empty. `False` if `key` produces any `nil` values.
function M.i_uniform(t, val, key)
    return i_uniform_do(#t, t, val, key)
end

---Check if `t` is non-empty and either all or none of the values match `val`. Optionally
---compare with a `key`.
---@mark evaluation
---@generic T
---@param t T[]
---@param val T
---@param key nil|string|fun(v:T): any See: |key_fn|.
---@return boolean `False` if `t` is empty or `key` produces any `nil` values.
function M.i_uniform_nonempty(t, val, key)
    local t_len = #t
    if t_len == 0 then
        return false
    end

    return i_uniform_do(t_len, t, val, key)
end

----------------------
-- MARK: Extractors --
----------------------

---Get the first item and its index from `t` that satisfies predicate function `f`.
---
---@mark extractors
---@generic T
---@param t T[]
---@param f fun(x:T): boolean
---@param rev? boolean (Default: `false`) If true, iterate from the end.
---@return T?, uinteger?
function M.i_find(t, f, rev)
    local t_len = #t
    if t_len == 0 then
        return
    end

    local start, stop, step = require("nvim-tools._table").resolve_rev(1, t_len, rev)
    for i = start, stop, step do
        local v = t[i]
        if f(v) then
            return v, i
        end
    end
end

---Get a new |lua-list| of all indices in `t` containing `val`, optionally filtered with `key`.
---@mark extractors
---@generic T
---@param t T[]
---@param val T
---@param key nil|string|fun(v:T): any See: |key_fn|.
---@return uinteger[] Empty table if no results.
function M.i_indices(t, val, key)
    local t_len = #t
    local ret = {} ---@type uinteger[]
    if t_len == 0 then
        return ret
    end

    local key_fn = require("nvim-tools._table").key_fn_from_key(key)
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

---Locates the first index containing `val` in `t`, optionally comparing with `key`.
---
---Returns `nil` if length of `t` is zero or `key` returns a `nil` result for `val`.
---@mark extractors
---@generic T
---@param t T[]
---@param val T
---@param key nil|string|fun(v:T): any See: |key_fn|.
---@param rev? boolean (Default: `false`) If true, iterate from the end.
---@return uinteger?
function M.i_locate(t, val, key, rev)
    local t_len = #t
    if t_len == 0 then
        return
    end

    local key_fn = require("nvim-tools._table").key_fn_from_key(key)
    local valh = key_fn(val)
    if valh == nil then
        return
    end

    local start, stop, step = require("nvim-tools._table").resolve_rev(1, t_len, rev)
    for i = start, stop, step do
        if key_fn(t[i]) == valh then
            return i
        end
    end
end

---Get the first index of `t` that satisfies predicate function `f`.
---@mark extractors
---@generic T
---@param t T[]
---@param f fun(x:T): boolean
---@param rev? boolean (Default: `false`) If true, iterate from the end.
---@return uinteger? Index of the found item. `nil` if not found.
function M.i_position(t, f, rev)
    local t_len = #t
    if t_len == 0 then
        return
    end

    local start, stop, step = require("nvim-tools._table").resolve_rev(1, t_len, rev)
    for i = start, stop, step do
        if f(t[i]) then
            return i
        end
    end
end

---Get a new |lua-list| of indices in `t` satisfying predicate function `f`.
---@mark extractors
---@generic T
---@param t T[]
---@param f fun(x:T): boolean
---@return uinteger[] Returns an empty table if no items found.
function M.i_positions(t, f)
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

--------------------
-- MARK: Grouping --
--------------------

---Append each list in `...`, in order, to `t1`. References are shallow-copied.
---@mark grouping
---@generic T
---@param t1 T[] Modified in place!
---@param ... T[]
---@return T[] Reference to `t1`.
function M.i_append(t1, ...)
    local nargs = select("#", ...)
    if nargs == 0 then
        return t1
    end

    require("nvim-tools._table").lists_append(nargs, { ... }, t1)
    return t1
end

---Create a new |lua-list| by appending each list in `...` in order. References are
---shallow-copied.
---@mark grouping
---@generic T
---@param ... T[]
---@return T[]
function M.i_append_to(...)
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

    local ret = M.new(len_total, 0)
    require("nvim-tools._table").lists_append(nargs, lists, ret)
    return ret
end

---Create a new |lua-list| of de-duplicated and sorted items from `...`. References are
---shallow-copied.
---@mark grouping
---@generic T
---@param key nil|string|fun(v:T): any See: |key_fn|.
---@param comp (fun(a:T, b:T): boolean)? (Default: Ascending order) Compatible with |table.sort()|.
---@param ... T[]
---@return T[]
function M.i_catalog_to(key, comp, ...)
    local nargs = select("#", ...)
    if nargs == 0 then
        return {}
    end

    local old_lists = { ... }
    local key_fn = require("nvim-tools._table").key_fn_from_key(key)
    local seen = {}
    local lists = {}
    comp = comp or function(a, b)
        return a < b
    end

    local _ntt = require("nvim-tools._table")
    for i = 1, nargs do
        local tn = old_lists[i]
        local tn_len = #tn
        local tn_filtered = _ntt.filter_keep_not_seen_unique_to(tn, tn_len, key_fn, seen)
        table.sort(tn_filtered, comp)
        lists[i] = tn_filtered
    end

    if #lists == 1 then
        return lists[1]
    end

    return _ntt.merge_sorted_do(nargs, comp, lists)
end

---Merge each list in `...` into a new, sorted |lua-list|. Each list is shallow-copied.
---@mark grouping
---@generic T
---@param comp (fun(a:T, b:T): boolean)? Default: Ascending order. Compatible with |table.sort()|.
---@param ... T[]
---@return T[]
function M.i_collate_to(comp, ...)
    local nargs = select("#", ...)
    if nargs == 0 then
        return {}
    end

    local old_lists = { ... }
    local lists = {}
    comp = comp or function(a, b)
        return a < b
    end

    local _ntt = require("nvim-tools._table")
    for i = 1, nargs do
        local tn = old_lists[i]
        local tn_copy = _ntt.i_copy_exact(tn, 1, #tn)
        table.sort(tn_copy, comp)
        lists[i] = tn_copy
    end

    if #lists == 1 then
        return lists[1]
    end

    return _ntt.merge_sorted_do(nargs, comp, lists)
end

---Aggregate all values in `t` into a |lua-dict|. Optionally use a `key` to determine which
---dictionary key each value should be placed in. Order is preserved.
---@generic T, V
---@param t T[]
---@param key nil|string|fun(v:T): V See: |key_fn|.
---@return table<any, T[]>
function M.i_group_by(t, key)
    local ret = {}
    local t_len = #t
    if t_len == 0 then
        return ret
    end

    local _ntt = require("nvim-tools._table")
    local key_fn = _ntt.key_fn_from_key(key)
    local ntt = require("nvim-tools.table")
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

---Creates a new |lua-list| from the values in `...` excluding those present in every
---vararg. Optionally compare using `key`.
---
---Order is preserved and results are de-duplicated (first appearance wins). References are
---shallow-copied.
---@mark list-and-list-filtering
---@generic T
---@param key nil|string|fun(v:T): any See: |key_fn|.
---@param ... T[]
---@return T[]
function M.i_impasse_to(key, ...)
    local nargs = select("#", ...)
    if nargs == 0 then
        return {}
    end

    local lists = { ... }
    local _ntt = require("nvim-tools._table")
    local key_fn = _ntt.key_fn_from_key(key)
    local seen = _ntt.seen_from_vargs_if_in_all(nargs, lists, key_fn)
    local ret = {}
    local j = 1
    for i = 1, nargs do
        local tn = lists[i]
        local tn_len = #tn
        for k = 1, tn_len do
            local v = tn[k]
            local vh = key_fn(v)
            if vh ~= nil and seen[vh] == nil then
                ret[j] = v
                j = j + 1
                seen[vh] = true
            end
        end
    end

    return ret
end
-- MID: Outline the loop into a helper

---@param t1 table<any, any> Modified in place!
---@param t2 table<any, any>
---@param prev table<table<any, any>, true>
local function merge_deep_left(t1, t2, prev)
    if prev[t2] == true then
        return
    end

    prev[t2] = true

    for k, v2 in pairs(t2) do
        if M.is_dict(v2) == 2 then
            local v1 = t1[k]
            if v1 == nil then
                v1 = {}
                t1[k] = v1
            end

            if M.is_dict(v1) >= 1 then
                merge_deep_left(v1, v2, prev)
            end
        elseif t1[k] == nil then
            t1[k] = deepcopy(v2, {})
        end
    end

    prev[t2] = nil
end

---Recursively merges all values from `t2` into `t1`. Values from `t1` take precedence.
---
---All values are deep-copied. If a circular reference is detected, merging at that sub-table is
---aborted.
---@audited 2026-07-03
---@param t1 table<any, any> Modified in place!
---@param t2 table<any, any>
---@return table<any, any> Reference to `t1`.
function M.merge_deep_left(t1, t2)
    merge_deep_left(t1, t2, {})
    return t1
end

---@param t1 table<any, any> Modified in place!
---@param t2 table<any, any>
---@param prev table<table<any, any>, true>
local function merge_deep_right(t1, t2, prev)
    if prev[t2] == true then
        return
    end

    prev[t2] = true

    for k, v2 in pairs(t2) do
        if M.is_dict(v2) == 2 then
            local v1 = t1[k]
            if M.is_dict(v1) == 0 then
                v1 = {}
                t1[k] = v1
            end

            merge_deep_right(v1, v2, prev)
        else
            t1[k] = deepcopy(v2, {})
        end
    end

    prev[t2] = nil
end

---Recursively merges all values from `t2` into `t1`. Values from `t2` take precedence.
---
---All values are deep-copied. If a circular reference is detected, merging at that sub-table is
---aborted.
---@audited 2026-07-03
---@param t1 table<any, any> Modified in place!
---@param t2 table<any, any>
---@return table<any, any> Reference to `t1`.
function M.merge_deep_right(t1, t2)
    merge_deep_right(t1, t2, {})
    return t1
end
-- TODO: Maybe name this `merge_deepc_right`. So that way you can have `deep` vs `deepc` as a
-- convention for shallow vs deep copy.

---Combines multiple sorted vararg `...` lists into a new sorted |lua-list|. References are
---shallow-copied.
---
---All input lists must already be sorted according to the comparator.
---@mark grouping
---@generic T
---@param comp? fun(a:T, b:T): boolean (Default: Ascending order) Compatible with |table.sort()|.
---@param ... T[]
---@return T[]
function M.i_merge_sorted_to(comp, ...)
    local nargs = select("#", ...)
    if nargs == 0 then
        return {}
    end

    local _ntt = require("nvim-tools._table")
    if nargs == 1 then
        local t1 = select(1, ...)
        return _ntt.i_copy_exact(t1, 1, #t1)
    end

    return _ntt.merge_sorted_do(nargs, comp or function(a, b)
        return a < b
    end, { ... })
end

---Create a new |lua-list| of items present in only one of the `...` varargs. Items can
---optionally be compared against a `key`. Ordering is preserved. References are shallow-copied.
---@generic T
---@param key nil|string|fun(v:T): any See: |key_fn|.
---@param ... T[]
---@return T[]
function M.i_symmetric_difference_to(key, ...)
    local nargs = select("#", ...)
    if nargs == 0 then
        return {}
    end

    local lists = { ... }
    local key_fn = require("nvim-tools._table").key_fn_from_key(key)
    local seen = {} ---@type table<any, uinteger>
    for i = 1, nargs do
        local tn = lists[i]
        local tn_len = #tn
        for j = 1, tn_len do
            local vh = key_fn(tn[j])
            if vh ~= nil then
                local seen_vh = seen[vh]
                if seen_vh == nil then
                    seen[vh] = i
                elseif not seen_vh ~= i then
                    seen[vh] = 0
                end
            end
        end
    end
    -- TODO: seen from varargs if in one

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
-- MID: Outline the loops into helpers.
-- LOW: make de-duping optional

---Creates a new |lua-list| from the de-duplicated values in `...`, optionally compared using a
---`key`.
---- References are shallow-copied.
---- No re-ordering is performed.
---@mark grouping
---@generic T
---@param key nil|string|fun(v:T): any See: |key_fn|.
---@param ... T[]
---@return T[]
function M.i_union_to(key, ...)
    local nargs = select("#", ...)
    if nargs == 0 then
        return {}
    end

    local lists = { ... }
    local key_fn = require("nvim-tools._table").key_fn_from_key(key)
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
-- MID: Outline the loop into a helper.
-- LOW: Add `union()` if needed.

---------------------
-- MARK: Filtering --
---------------------

---Remove values from `t` that pass predicate function `f`.
---@mark filtering
---@generic K, V
---@param t table<K, V> Modified in place!
---@param f fun(k:K, v:V): boolean
---@return table<K, V> Reference to `t`.
function M.discard(t, f)
    for k, v in pairs(t) do
        if f(k, v) then
            t[k] = nil
        end
    end

    return t
end

---Create a new table of values from `t` excluding those that pass predicate function `f`.
---@mark filtering
---@generic K, V
---@param t table<K, V>
---@param f fun(k:K, v:V): boolean
---@return table<K, V>
function M.discard_to(t, f)
    local ret = {}
    for k, v in pairs(t) do
        if not f(k, v) then
            ret[k] = v
        end
    end

    return ret
end

---Remove values from |lua-list| `t` that pass predicate function `f`.
---@mark filtering
---@generic T
---@param t T[] Modified in place!
---@param f fun(x:T): boolean
---@return T[] Reference to `t`.
function M.i_discard(t, f)
    local t_len = #t
    if t_len == 0 then
        return t
    end

    local j = require("nvim-tools._table").i_discard_do(t, t_len, t, f)
    for i = j, t_len do
        t[i] = nil
    end

    return t
end

---Create a new |lua-list| of values from `t` excluding those that pass predicate `f`.
---@mark filtering
---@generic T
---@param t T[]
---@param f fun(x:T): boolean
---@return T[]
function M.i_discard_to(t, f)
    local t_len = #t
    local ret = {}
    if t_len == 0 then
        return ret
    end

    require("nvim-tools._table").i_discard_do(t, t_len, ret, f)
    return ret
end

---Iterate over `t` with predicate `f`. Remove values in place until one passes the predicate.
---Shift the remaining elements down so they start at index one.
---@mark filtering
---@generic T
---@param t T[] Modified in place!
---@param f fun(x:T): boolean
---@param rev? boolean (Default: `false`) If `true`, iterate from the end.
---@return T[] Reference to `t`.
function M.i_discard_while(t, f, rev)
    local t_len = #t
    if t_len == 0 then
        return t
    end

    local _ntt = require("nvim-tools._table")
    if not rev then
        local first = _ntt.discard_while_find_first(1, t_len, 1, t, f, 0)
        if first >= 1 then
            require("nvim-tools._table").shift_down_exact(t, t_len, first, t_len, 1)
            return t
        else
            return M.i_clear(t)
        end
    end

    local first = _ntt.discard_while_find_first(t_len, 1, -1, t, f, t_len + 1)
    if first <= t_len then
        _ntt.shift_down_exact(t, t_len, 1, first, 1)
        return t
    else
        return M.i_clear(t)
    end
end

---Iterate over `t` with predicate `f`. Skip values until the predicate fails, then copy the
---remaining values into a new list.
---@mark filtering
---@generic T
---@param t T[]
---@param f fun(x:T): boolean
---@param rev? boolean (Default: `false`) If `true`, iterate from the end.
---@return T[]
function M.i_discard_while_to(t, f, rev)
    local t_len = #t
    if t_len == 0 then
        return {}
    end

    local _ntt = require("nvim-tools._table")
    if not rev then
        local first = _ntt.discard_while_find_first(1, t_len, 1, t, f, 0)
        if first >= 1 then
            return _ntt.i_copy_exact(t, first, t_len)
        end

        return {}
    end

    local first = _ntt.discard_while_find_first(t_len, 1, -1, t, f, t_len + 1)
    if first <= t_len then
        return _ntt.i_copy_exact(t, 1, first)
    end

    return {}
end

---Keep values from `t` that pass predicate function `f`.
---@mark filtering
---@generic K, V
---@param t table<K, V> Modified in place!
---@param f fun(k:K, v:V): boolean
---@return table<K, V> Reference to `t`.
function M.keep(t, f)
    for k, v in pairs(t) do
        if not f(k, v) then
            t[k] = nil
        end
    end

    return t
end

---Create a new table of values from `t` that pass predicate function `f`.
---@mark filtering
---@generic K, V
---@param t table<K, V>
---@param f fun(k:K, v:V): boolean
---@return table<K, V>
function M.keep_to(t, f)
    local ret = {}
    for k, v in pairs(t) do
        if f(k, v) then
            ret[k] = v
        end
    end

    return ret
end

---Keep only values from |lua-list| `t` that pass predicate function `f`.
---@mark filtering
---@generic T
---@param t T[] Modified in place!
---@param f fun(x:T): boolean
---@return T[] Reference to `t`.
function M.i_keep(t, f)
    local t_len = #t
    if t_len == 0 then
        return t
    end

    local j = require("nvim-tools._table").keep_do(t, t_len, t, f)
    for i = j, t_len do
        t[i] = nil
    end

    return t
end

---Create a new |lua-list| of values from `t` that pass predicate `f`.
---@mark filtering
---@generic T
---@param t T[]
---@param f fun(x:T): boolean
---@return T[]
function M.i_keep_to(t, f)
    local t_len = #t
    local ret = {}
    if t_len == 0 then
        return ret
    end

    require("nvim-tools._table").keep_do(t, t_len, ret, f)
    return ret
end

---Iterate over `t` with predicate `f`. Keep values until one fails, then remove the rest in place.
---@mark filtering
---@generic T
---@param t T[] Modified in place!
---@param f fun(x:T): boolean
---@param rev? boolean (Default: `false`) If true, iterate from the end.
---@return T[] Reference to `t`.
function M.i_keep_while(t, f, rev)
    local t_len = #t
    if t_len == 0 then
        return t
    end

    local _ntt = require("nvim-tools._table")
    if not rev then
        local last = _ntt.keep_while_find_last(1, t_len, 1, t, f, 0)
        for i = last + 1, t_len do
            t[i] = nil
        end

        return t
    end

    local last = _ntt.keep_while_find_last(t_len, 1, -1, t, f, t_len + 1)
    if last > t_len then
        M.i_clear(t)
    else
        _ntt.shift_down_exact(t, t_len, last, t_len, 1)
    end

    return t
end

---Iterate over `t` with predicate `f`. Shallow copy the values to a new list until the
---predicate fails.
---@mark filtering
---@generic T
---@param t T[]
---@param f fun(x:T): boolean
---@param rev? boolean (Default: `false`) If `true`, iterate from the end.
---@return T[]
function M.i_keep_while_to(t, f, rev)
    local t_len = #t
    if t_len == 0 then
        return {}
    end

    local _ntt = require("nvim-tools._table")
    if not rev then
        local last = _ntt.keep_while_find_last(1, t_len, 1, t, f, 0)
        if last > 0 then
            return _ntt.i_copy_exact(t, 1, last)
        end

        return {}
    end

    local last = _ntt.keep_while_find_last(t_len, 1, -1, t, f, t_len + 1)
    if last <= t_len then
        return _ntt.i_copy_exact(t, last, t_len)
    end

    return {}
end

---Remove elements from `t` in place not matching `val`, optionally filtered by `key`.
---
---No-op if `key` returns `nil`.
---
---Optionally use `limit` to cap the number of successful matches. Any remaining matches will be
---removed from `t`.
---@generic T
---@param t T[] Modified in place!
---@param val T
---@param key nil|string|fun(v:T): any See: |key_fn|.
---@param limit? uinteger (Default: Length of `t`)
---@return T[] Reference to `t`.
function M.i_select(t, val, key, limit)
    local t_len = #t
    if t_len == 0 then
        return t
    end

    local _ntt = require("nvim-tools._table")
    local key_fn = _ntt.key_fn_from_key(key)
    local valh = key_fn(val)
    if valh == nil then
        return t
    end

    local j = _ntt.select_do(t, t_len, limit, t, valh, key_fn)
    while j <= t_len do
        t[j] = nil
        j = j + 1
    end

    return t
end

---Create a new list with a copy of every occurrence of `val` in `t`, optionally filtered by
---`key`.
---
---Returns an empty table if `key` returns `nil` for `val`.
---
---Optionally use `limit` to cap the number of successful matches. Remaining matches will be
---ignored.
---@generic T, U
---@param t T[]
---@param val T
---@param key nil|string|fun(v:T): U See: |key_fn|.
---@param limit? uinteger (Default: Length of `t`)
---@return T[]
function M.i_select_to(t, val, key, limit)
    local t_len = #t
    local ret = {}
    if t_len == 0 then
        return ret
    end

    local _ntt = require("nvim-tools._table")
    local key_fn = _ntt.key_fn_from_key(key)
    local valh = key_fn(val)
    if valh == nil then
        return ret
    end

    _ntt.select_do(t, t_len, limit, ret, valh, key_fn)
    return ret
end

---Create a new |lua-list| of unique items from `t`, optionally compared using `key`.
---@generic T
---@param t T[]
---@param key nil|string|fun(v:T): any See: |key_fn|.
---@return T[]
function M.i_unique_to(t, key)
    local t_len = #t
    if t_len == 0 then
        return {}
    end

    local _ntt = require("nvim-tools._table")
    local key_fn = _ntt.key_fn_from_key(key)
    return _ntt.filter_keep_not_seen_unique_to(t, t_len, key_fn, {})
end

---@param t table<any, any> Modified in place!
---@param keys table<any, true>
---@param prev table<table<any, any>, true>
local function unset_keys(t, keys, prev)
    if prev[keys] == true then
        return
    end

    prev[keys] = true

    for k, v in pairs(keys) do
        if v == true then
            t[k] = nil
        elseif M.is_dict(v) == 2 then
            local tv = t[k]
            if M.is_dict(tv) == 2 then
                unset_keys(tv, v, prev)
            end
        end
    end

    prev[keys] = nil
end

---Recursively set values in `t` to `nil` if the matching key/value pair in `keys` is true. If
---a value in `keys` is a |lua-dict|, iterate recursively.
---
---If a circular reference is detected, iteration at that sub-table is aborted.
---@audited 2026-07-03
---@param t table<any, any> Modified in place!
---@param keys table<any, true>
---@return table<any, any> Reference to `t`.
function M.unset_keys(t, keys)
    unset_keys(t, keys, {})
    return t
end

-----------------------------------
-- MARK: List and List Filtering --
-----------------------------------

---Remove elements from `t1` present in any of the varargs `...`. Optionally compare using `key`.
---Order is preserved.
---
---If `dedup` is true, the results are de-duplicated.
---@mark list-and-list-filtering
---@generic T
---@param key nil|string|fun(v:T): any See: |key_fn|.
---@param dedup boolean? (Default: `false`)
---@param t1 T[] Target list. Modified in place!
---@param ... T[] No-op if no additional lists are provided.
---@return T[] Reference to `t1`.
function M.i_difference(key, dedup, t1, ...)
    local nargs = select("#", ...)
    local t1_len = #t1
    if t1_len == 0 or nargs == 0 then
        return t1
    end

    local _ntt = require("nvim-tools._table")
    local key_fn = _ntt.key_fn_from_key(key)
    local seen = _ntt.seen_from_varargs_if_in_any(nargs, { ... }, key_fn)
    if not dedup then
        _ntt.filter_keep_not_seen_in_place(t1, t1_len, key_fn, seen)
    else
        _ntt.filter_keep_not_seen_unique_in_place(t1, t1_len, key_fn, seen)
    end

    return t1
end

---Create a new |lua-list| of elements from `t1` that are not present in any of the varargs `...`.
---Optionally compare using a `key`. Order in `t1` is preserved.
---
---If `dedup` is true, qualifying elements are de-duplicated.
---@mark list-and-list-filtering
---@generic T
---@param key nil|string|fun(v:T): any See: |key_fn|.
---@param dedup boolean? (Default: `false`)
---@param t1 T[] Source list.
---@param ... T[] No-op if no additional lists are provided.
---@return T[]
function M.i_difference_to(key, dedup, t1, ...)
    local nargs = select("#", ...)
    local t1_len = #t1
    local _ntt = require("nvim-tools._table")
    if nargs == 0 or t1_len == 0 then
        return _ntt.i_copy_exact(t1, 1, t1_len)
    end

    local key_fn = _ntt.key_fn_from_key(key)
    local seen = _ntt.seen_from_varargs_if_in_any(nargs, { ... }, key_fn)
    if not dedup then
        return _ntt.filter_keep_not_seen_to(t1, t1_len, key_fn, seen)
    else
        return _ntt.filter_keep_not_seen_unique_to(t1, t1_len, key_fn, seen)
    end
end

---Keep elements in `t1` if they are present in every vararg `...`. Optionally compare using a
---`key`. Order is preserved.
---
---If `dedup` is `true`, items are de-duplicated.
---
---Prefer |overlap()| if only one vararg `...`.
---@mark list-and-list-filtering
---@generic T
---@param key nil|string|fun(v:T): any See: |key_fn|.
---@param dedup boolean? (Default: `false`)
---@param t1 T[] Modified in place!
---@param ... T[] No-op if no additional lists are provided.
---@return T[] Reference to `t1`.
function M.i_intersection(key, dedup, t1, ...)
    local nargs = select("#", ...)
    local t1_len = #t1
    if t1_len == 0 or nargs == 0 then
        return t1
    end

    local _ntt = require("nvim-tools._table")
    local key_fn = _ntt.key_fn_from_key(key)
    local seen = _ntt.seen_from_vargs_if_in_all(nargs, { ... }, key_fn)
    if not dedup then
        _ntt.filter_keep_seen_in_place(t1, t1_len, key_fn, seen)
    else
        _ntt.filter_keep_seen_unique_in_place(t1, t1_len, key_fn, seen)
    end

    return t1
end

---Create a new |lua-list| of elements from `t1` that are present in every vararg `...`.
---Optionally compare using a `key`. Order in `t1` is preserved.
---
---If `dedup` is `true`, items are de-duplicated.
---
---Prefer |overlap_to()| if only one vararg `...`.
---@mark list-and-list-filtering
---@generic T
---@param key nil|string|fun(v:T): any See: |key_fn|.
---@param dedup boolean? (Default: `false`)
---@param t1 T[] Original order is preserved.
---@param ... T[] No-op if no additional lists are provided.
---@return T[]
function M.i_intersection_to(key, dedup, t1, ...)
    local t1_len = #t1
    local nargs = select("#", ...)
    local _ntt = require("nvim-tools._table")
    if t1_len == 0 or nargs == 0 then
        return _ntt.i_copy_exact(t1, 1, t1_len)
    end

    local key_fn = _ntt.key_fn_from_key(key)
    local seen = _ntt.seen_from_vargs_if_in_all(nargs, { ... }, key_fn)
    if not dedup then
        return _ntt.filter_keep_seen_to(t1, t1_len, key_fn, seen)
    else
        return _ntt.filter_keep_seen_unique_to(t1, t1_len, key_fn, seen)
    end
end

---Remove elements from `t1` present in all or none of the varargs `...`. Optionally compare
---using `key`. Order is preserved.
---
---If `dedup` is true, the results are de-duplicated.
---
---Clears `t1` if one or fewer varargs `...` are provided.
---@mark list-and-list-filtering
---@generic T
---@param key nil|string|fun(v:T): any See: |key_fn|.
---@param dedup boolean? (Default: `false`)
---@param t1 T[] Target list. Modified in place!
---@param ... T[]
---@return T[] Reference to `t1`.
function M.i_mixed(key, dedup, t1, ...)
    local nargs = select("#", ...)
    local t1_len = #t1
    if t1_len == 0 or nargs <= 1 then
        M.i_clear(t1)
        return t1
    end

    local _ntt = require("nvim-tools._table")
    local key_fn = _ntt.key_fn_from_key(key)
    local seen = _ntt.seen_from_varargs_if_in_some(nargs, { ... }, key_fn)
    if not dedup then
        _ntt.filter_keep_seen_in_place(t1, t1_len, key_fn, seen)
    else
        _ntt.filter_keep_seen_unique_in_place(t1, t1_len, key_fn, seen)
    end

    return t1
end

---Create a new |lua-list| of elements from `t1` that are present in at least one of, but not all
---of the varargs `...`. Optionally compare using a `key`. Order in `t1` is preserved.
---
---If `dedup` is true, qualifying elements are de-duplicated.
---
---Returns an empty table if one or fewer varargs `...` are provided.
---@mark list-and-list-filtering
---@generic T, U
---@param key nil|string|fun(v:T): U See: |key_fn|.
---@param dedup boolean? (Default: `false`)
---@param t1 T[] Source list.
---@param ... T[]
---@return T[]
function M.i_mixed_to(key, dedup, t1, ...)
    local nargs = select("#", ...)
    local t1_len = #t1
    local _ntt = require("nvim-tools._table")
    if nargs <= 1 or t1_len == 0 then
        return {}
    end

    local key_fn = _ntt.key_fn_from_key(key)
    local seen = _ntt.seen_from_varargs_if_in_some(nargs, { ... }, key_fn)
    if not dedup then
        return _ntt.filter_keep_seen_to(t1, t1_len, key_fn, seen)
    else
        return _ntt.filter_keep_seen_unique_to(t1, t1_len, key_fn, seen)
    end
end

---Remove elements from `t1` present in at least one of but not all of the varargs `...`.
---Optionally compare using `key`. Order is preserved.
---
---If `dedup` is true, the results are de-duplicated.
---
---No-op if one or fewer varargs `...` are provided.
---@mark list-and-list-filtering
---@generic T
---@param key nil|string|fun(v:T): any See: |key_fn|.
---@param dedup boolean? (Default: `false`)
---@param t1 T[] Target list. Modified in place!
---@param ... T[]
---@return T[] Reference to `t1`.
function M.i_monochrome(key, dedup, t1, ...)
    local nargs = select("#", ...)
    local t1_len = #t1
    if t1_len == 0 or nargs == 0 then
        return t1
    end

    local _ntt = require("nvim-tools._table")
    local key_fn = _ntt.key_fn_from_key(key)
    local seen = _ntt.seen_from_varargs_if_in_some(nargs, { ... }, key_fn)
    if not dedup then
        _ntt.filter_keep_not_seen_in_place(t1, t1_len, key_fn, seen)
    else
        _ntt.filter_keep_not_seen_unique_in_place(t1, t1_len, key_fn, seen)
    end

    return t1
end

---Create a new |lua-list| of elements from `t1` that are present in all or none of the
---varargs `...`. Optionally compare using a `key`. Order in `t1` is preserved.
---
---If `dedup` is true, qualifying elements are de-duplicated.
---
---If one or fewer varargs `...` are provided, simply shallow-copy the original list.
---@mark list-and-list-filtering
---@generic T, U
---@param key nil|string|fun(v:T): U See: |key_fn|.
---@param dedup boolean? (Default: `false`)
---@param t1 T[] Source list.
---@param ... T[]
---@return T[]
function M.i_monochrome_to(key, dedup, t1, ...)
    local nargs = select("#", ...)
    local t1_len = #t1
    local _ntt = require("nvim-tools._table")
    if nargs <= 1 or t1_len == 0 then
        return _ntt.i_copy_exact(t1, 1, t1_len)
    end

    local key_fn = _ntt.key_fn_from_key(key)
    local seen = _ntt.seen_from_varargs_if_in_some(nargs, { ... }, key_fn)
    if not dedup then
        return _ntt.filter_keep_not_seen_to(t1, t1_len, key_fn, seen)
    else
        return _ntt.filter_keep_not_seen_unique_to(t1, t1_len, key_fn, seen)
    end
end

---Keep elements from `t1` present in any of the varargs `...`. Optionally compare using `key`.
---Order is preserved.
---
---If `dedup` is true, the results are de-duplicated.
---@mark list-and-list-filtering
---@generic T
---@param key nil|string|fun(v:T): any See: |key_fn|.
---@param dedup boolean? (Default: `false`)
---@param t1 T[] Target list. Modified in place!
---@param ... T[] No-op if no additional lists are provided.
---@return T[] Reference to `t1`.
function M.i_overlap(key, dedup, t1, ...)
    local nargs = select("#", ...)
    local t1_len = #t1
    if t1_len == 0 or nargs == 0 then
        return t1
    end

    local _ntt = require("nvim-tools._table")
    local key_fn = _ntt.key_fn_from_key(key)
    local seen = _ntt.seen_from_varargs_if_in_any(nargs, { ... }, key_fn)
    if not dedup then
        _ntt.filter_keep_seen_in_place(t1, t1_len, key_fn, seen)
    else
        _ntt.filter_keep_seen_unique_in_place(t1, t1_len, key_fn, seen)
    end

    return t1
end

---Create a new |lua-list| of elements from `t1` that are present in any of the varargs `...`.
---Optionally compare using a `key`. Order in `t1` is preserved.
---
---If `dedup` is true, qualifying elements are de-duplicated.
---@mark list-and-list-filtering
---@generic T
---@param key nil|string|fun(v:T): any See: |key_fn|.
---@param dedup boolean? (Default: `false`)
---@param t1 T[] Source list.
---@param ... T[] No-op if no additional lists are provided.
---@return T[]
function M.i_overlap_to(key, dedup, t1, ...)
    local nargs = select("#", ...)
    local t1_len = #t1
    local _ntt = require("nvim-tools._table")
    if nargs == 0 or t1_len == 0 then
        return _ntt.i_copy_exact(t1, 1, t1_len)
    end

    local key_fn = _ntt.key_fn_from_key(key)
    local seen = _ntt.seen_from_varargs_if_in_any(nargs, { ... }, key_fn)
    if not dedup then
        return _ntt.filter_keep_seen_to(t1, t1_len, key_fn, seen)
    else
        return _ntt.filter_keep_seen_unique_to(t1, t1_len, key_fn, seen)
    end
end

---Remove elements in `t1` if they are present in every vararg `...`. Optionally compare using a
---`key`. Order is preserved.
---
---If `dedup` is `true`, items are de-duplicated.
---
---Prefer |difference()| if only one vararg `...`.
---@mark list-and-list-filtering
---@generic T
---@param key nil|string|fun(v:T): any See: |key_fn|.
---@param dedup boolean? (Default: `false`)
---@param t1 T[] Modified in place!
---@param ... T[] No-op if no additional lists are provided.
---@return T[] Reference to `t1`.
function M.i_stroke(key, dedup, t1, ...)
    local nargs = select("#", ...)
    local t1_len = #t1
    if t1_len == 0 or nargs == 0 then
        return t1
    end

    local _ntt = require("nvim-tools._table")
    local key_fn = _ntt.key_fn_from_key(key)
    local seen = _ntt.seen_from_vargs_if_in_all(nargs, { ... }, key_fn)
    if not dedup then
        _ntt.filter_keep_not_seen_in_place(t1, t1_len, key_fn, seen)
    else
        _ntt.filter_keep_not_seen_unique_in_place(t1, t1_len, key_fn, seen)
    end

    return t1
end

---Create a new |lua-list| of elements in `t1` excluding those in all of the varargs `...`.
---Optionally compare using a `key`. Order is preserved.
---
---If `dedup` is `true`, items are de-duplicated.
---
---Prefer |difference_to()| if only one vararg `...`.
---@mark list-and-list-filtering
---@generic T
---@param key nil|string|fun(v:T): any See: |key_fn|.
---@param dedup boolean? (Default: `false`)
---@param t1 T[]
---@param ... T[] No-op if no additional lists are provided.
---@return T[]
function M.i_stroke_to(key, dedup, t1, ...)
    local nargs = select("#", ...)
    local t1_len = #t1
    if t1_len == 0 or nargs == 0 then
        return t1
    end

    local _ntt = require("nvim-tools._table")
    local key_fn = _ntt.key_fn_from_key(key)
    local seen = _ntt.seen_from_vargs_if_in_all(nargs, { ... }, key_fn)
    if not dedup then
        _ntt.filter_keep_not_seen_to(t1, t1_len, key_fn, seen)
    else
        _ntt.filter_keep_not_seen_unique_to(t1, t1_len, key_fn, seen)
    end

    return t1
end

--------------------------------
-- MARK: List to New Value(s) --
--------------------------------

---Same as |i_fold()|, but returns all intermediate accumulator values.
---
---The first value in the result is `init` (if the list is non-empty).
---Returns an empty table if `t` is length zero or `init` is `nil`.
---@generic A, T
---@param t T[]
---@param init A First accumulator value.
---@param f fun(acc:A, x:T, idx:uinteger): A If `nil` is returned, accumulation stops and
---the current list of intermediates is returned.
---@param rev? boolean (Default: `false`) If true, iterate from the end.
---@return A[] List of successive accumulator values.
function M.i_accumulate(t, init, f, rev)
    local t_len = #t
    local ret = {}
    if t_len == 0 or init == nil then
        return ret
    end

    local _ntt = require("nvim-tools._table")
    local start, stop, step = _ntt.resolve_rev(1, t_len, rev)
    local acc = init
    ret[1] = acc
    local j = 2
    for i = start, stop, step do
        local next_acc = f(acc, t[i], i)
        if next_acc == nil then
            return ret
        end

        acc = next_acc
        ret[j] = acc
        j = j + 1
    end

    return ret
end

---Transform the elements of `t` into a single value using an accumulator.
---@see |i_reduce()| to initialize with the first value of the list.
---@generic T, A
---@param t T[]
---@param init A First accumulator value. No-op if this is `nil`.
---@param f fun(acc:A, x:T, idx:uinteger): A|nil If `nil` is returned, folding stops and the
---current accumulator is returned.
---@param rev? boolean (Default: `false`) If true, iterate from the end.
---@return A `init` if `t` is length zero.
function M.i_fold(t, init, f, rev)
    local t_len = #t
    if t_len == 0 or init == nil then
        return init
    end

    local _ntt = require("nvim-tools._table")
    local start, stop, step = _ntt.resolve_rev(1, t_len, rev)
    local acc_ret = init
    for i = start, stop, step do
        local acc = f(acc_ret, t[i], i)
        if acc == nil then
            return acc_ret
        end

        acc_ret = acc
    end

    return acc_ret
end

---Apply a function to all elements of a list, transforming them into a single value. The first
---accumulator will be the first element of the list (last if iterating in reverse).
---@see |i_fold()| to specify an initial accumulator.
---@generic T
---@param t T[]
---@param f fun(acc:T, v:T, idx:uinteger): T If `nil` is returned, reducing stops and the current
---accumulator is returned.
---@param rev? boolean (Default: `false`) If true, iterate from the end.
---@return T `nil` if `t` is length zero.
function M.i_reduce(t, f, rev)
    local t_len = #t
    if t_len == 0 then
        return nil
    end

    local _ntt = require("nvim-tools._table")
    local start, stop, step = _ntt.resolve_rev(1, t_len, rev)
    local acc_ret = t[start]
    for i = start + step, stop, step do
        local acc = f(acc_ret, t[i], i)
        if acc == nil then
            return acc_ret
        end

        acc_ret = acc
    end

    return acc_ret
end

---Same as reduce, but also return all intermediate values.
---
---Returns an empty table if `t` is length zero.
---@generic T
---@param t T[]
---@param f fun(acc:T, v:T, idx:uinteger): T If `nil` is returned, reducing stops and the current
---list of intermediates is returned.
---@param rev? boolean (Default: `false`) If true, iterate from the end.
---@return T[]
function M.i_reductions(t, f, rev)
    local t_len = #t
    local ret = {}
    if t_len == 0 then
        return ret
    end

    local _ntt = require("nvim-tools._table")
    local start, stop, step = _ntt.resolve_rev(1, t_len, rev)
    local acc = t[start]
    ret[1] = acc
    local j = 2
    for i = start + step, stop, step do
        acc = f(acc, t[i], i)
        if acc == nil then
            return ret
        end

        ret[j] = acc
        j = j + 1
    end

    return ret
end

---------------------------
-- MARK: Transformations --
---------------------------

---Combine values in `t` based on function `f`.
---The list is traversed linearly, rather than product-wise. An operation such as combining
---overlapping ranges requires that `t` be pre-sorted.
---
---Example:
---```lua
---    local foo = { { 1, 3 }, { 2, 4 }, { 5, 6 } }
---    combine(foo, function(a, b)
---        return b[1] < a[2] and { a[1], b[2] } or nil
---    end)
---    -- foo = { { 1, 4 }, { 5, 6 } }
---```
---@generic T
---@param t T[] Modified in place!
---@param f fun(v1:T, v2:T): T|nil
---- If `nil` is returned, `v2` is kept and will be provided as `v1` on the next iteration.
---- If a value is returned, `v1` is replaced and `v2` is discarded. The new value will be
---provided as `v1` on the next iteration.
---@return T[] Reference to `t`.
function M.i_combine(t, f)
    local t_len = #t
    if t_len <= 1 then
        return t
    end

    local j = 1
    for i = 2, t_len do
        local v1 = t[j]
        local v2 = t[i]
        local vm = f(v1, v2)
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

---@generic K, V
---@param t table<any, any> Modified in place!
---@param defaults table<any, any>
---@param prev_defaults table<table<K, V>, true>
local function defaults_deep(t, defaults, prev_defaults)
    if prev_defaults[defaults] == true then
        return
    end

    prev_defaults[defaults] = true

    for k, vd in pairs(defaults) do
        if M.is_dict(vd) == 2 then
            local v = t[k]
            if M.is_dict(v) == 0 then
                v = {}
                t[k] = v
            end

            defaults_deep(v, vd, prev_defaults)
        elseif t[k] == nil then
            t[k] = deepcopy(vd, {})
        end
    end

    prev_defaults[defaults] = nil
end

---Recursively merges values from `t2` into `t1` if they are missing in `t1`. |lua-dict| values in
---`t2` will overwrite any non-dict value in `t1`.
---
---All values are deep-copied. If a circular reference is detected, merging at that sub-table is
---aborted.
---@generic K, V
---@param t table<any, any> Modified in place!
---@param defaults table<any, any>
---@return table<any, any> Reference to `t`.
function M.defaults_deep(t, defaults)
    defaults_deep(t, defaults, {})
    return t
end

---Fills all indices of `t` in place with `v`.
---@generic T
---@param t T[] Modified in place.
---@param val any
---@return T[] Reference to `t`.
function M.i_fill(t, val)
    local t_len = #t
    if t_len == 0 then
        return t
    end

    for i = 1, t_len do
        t[i] = val
    end

    return t
end

---@generic K, V, M
---@param t table<K, V>
---@param f fun(k:K, v:V): M|nil
---@return table<K, M>
function M.filter_map_to(t, f)
    local ret = {}
    for k, v in pairs(t) do
        local m = f(k, v)
        if m ~= nil then
            ret[k] = m
        end
    end

    return ret
end
-- TODO: considering the stuff out there like map keys, do we just make this all inclusive and
-- have it also return the key? What I think is probably better though is to keep this simple and
-- then have another kitchen sink function, since there's no ergonomic way to deal with not
-- wanting to map k.

---Create a new |lua-list| by applying function `f` to the values of `t`.
---@generic T, U
---@param t T[]
---@param f fun(x:T): U|nil `nil` returns are filtered.
---@return U[] New table. Empty if all elements are filtered.
function M.i_filter_map_to(t, f)
    local ret = {}
    require("nvim-tools._table").i_filter_map_do(#t, t, f, ret)
    return ret
end
-- LOW: Add limit.

---If `t1` is longer than `t2`, any additional items in `t1` will be ignored.
---@generic T, U
---@param t1 T[] Modified in place!
---@param t2 U[]
---@param f fun(x:T, y:U): T|nil
---@return T[] Reference to `t1`.
function M.i_filter_map2_to(t1, t2, f)
    local len = math.min(#t1, #t2)
    local ret = {}
    if len == 0 then
        return ret
    end

    require("nvim-tools._table").i_filter_map2_do(len, t1, t2, f, ret)
    return ret
end

---Create a new |lua-dict| from mapped values of `t` with an accumulator.
---@generic K, V, R, M, A
---@param t table<K, V>
---@param init A No-op if `nil`.
---@param f fun(acc:A, k:K, v:V): A?, M
---@return table<R, M>, A
---Reference to `t` and final accumulator.
function M.filter_map_accum_to(t, init, f)
    local ret = {}
    local acc = init
    if acc == nil then
        return ret, acc
    end

    for k, v in pairs(t) do
        local acc_new, vm = f(acc, k, v)
        if acc_new == nil then
            return ret, acc
        end

        acc = acc_new
        if vm ~= nil then
            ret[k] = vm
        end
    end

    return ret, acc
end

---Create a new |lua-list| by threading an accumulator through function `f` to modify the values
---of `t`.
---@generic T, A, U
---@param t T[] No-op if length zero.
---@param init A No-op if `nil`.
---@param f fun(acc:A, x:T, idx:uinteger): A|nil, U|nil Takes as arguments the current
---accumulator, list value, and index. Returns the next accumulator and list value. If the
---returned accumulator is nil, mapping aborts and the current accumulator and results are
---returned. If the returned value is `nil`, it is filtered.
---@param limit uinteger? (Default: Length of `t`) Maximum number of results to return. Inclusive.
---@param rev? boolean (Default: `false`)
---@return U[], A
---The results and ending accumulator.
function M.i_filter_map_accum_to(t, init, f, limit, rev)
    local t_len = #t
    local acc_ret = init
    local ret = {}
    if t_len == 0 or acc_ret == nil then
        return ret, acc_ret
    end

    local _ntt = require("nvim-tools._table")
    local start, stop, step = _ntt.resolve_rev(1, t_len, rev)
    limit = limit or t_len
    local ret_len = 0
    for i = start, stop, step do
        if ret_len >= limit then
            return ret, acc_ret
        end

        local acc, vm = f(acc_ret, t[i], i)
        if acc == nil then
            return ret, acc_ret
        end

        acc_ret = acc
        if vm ~= nil then
            ret_len = ret_len + 1
            ret[ret_len] = vm
        end
    end

    return ret, acc_ret
end

---@generic T
---@param t T[] Modified in place!
---@param f fun(x: T): T|nil `nil` returns are filtered.
---@return T[]
function M.i_filter_modify(t, f)
    local t_len = #t
    if t_len == 0 then
        return t
    end

    local j = require("nvim-tools._table").i_filter_map_do(t_len, t, f, t)
    for i = j, t_len do
        t[i] = nil
    end

    return t
end
-- LOW: Add limit

---If `t1` is longer than `t2`, any additional items in `t1` will be truncated.
---@generic T, U
---@param t1 T[] Modified in place!
---@param t2 U[]
---@param f fun(x:T, y:U): T|nil
---@return T[] Reference to `t1`.
function M.i_filter_modify2(t1, t2, f)
    local len = math.min(#t1, #t2)
    if len == 0 then
        return t1
    end

    local j = require("nvim-tools._table").i_filter_map2_do(len, t1, t2, f, t1)
    for i = j, len do
        t1[i] = nil
    end

    return t1
end

---Modify values of `t` in place with an accumulator.
---@generic K, V, A
---@param t table<K, V>
---@param init A No-op if `nil`.
---@param f fun(acc:A, k:K, v:V): A, V
---@return table<K, V>, A
---Reference to `t` and final accumulator.
function M.filter_modify_accum(t, init, f)
    local acc = init
    if acc == nil then
        return t, acc
    end

    for k, v in pairs(t) do
        local acc_new, vm = f(acc, k, v)
        if acc_new == nil then
            return t, acc
        end

        acc = acc_new
        t[k] = vm
    end

    return t, acc
end
-- TODO: The pairs iteration logic is the same as filter_map_accum_to. Outline

---Modify `t` in place by threading an accumulator through function `f`.
---@generic T, A
---@param t T[] Modified in place! No-op if length zero.
---@param init A No-op if `nil`.
---@param f fun(acc:A, x:T, idx:uinteger): A|nil, T|nil Takes as arguments the current
---accumulator, list value, and index. Returns the next accumulator and list value. If the
---returned accumulator is nil, mapping aborts and the current accumulator and results are
---returned. If the returned value is `nil`, it is filtered.
---@param limit uinteger? (Default: Length of `t`) Maximum number of results to return. Inclusive.
---@return T[], A
---The results and ending accumulator.
function M.i_filter_modify_accum(t, init, f, limit)
    local t_len = #t
    local acc_ret = init
    if t_len == 0 or acc_ret == nil then
        return t, acc_ret
    end

    limit = limit or t_len
    local j = 0
    for i = 1, t_len do
        if j >= limit then
            return t, acc_ret
        end

        local acc, vm = f(acc_ret, t[i], i)
        if acc == nil then
            return t, acc_ret
        end

        acc_ret = acc
        if vm ~= nil then
            j = j + 1
            t[j] = vm
        end
    end

    for i = j + 1, t_len do
        t[i] = nil
    end

    return t, acc_ret
end
-- LOW: Add rev option (can't be the same algorithm)

---@generic T
---@param dst T[]
---@param iter_len uinteger
---@param sep_count uinteger
---@param new_len uinteger
---@param t T[]
---@param sep T
---@param unit_size uinteger (Default: `1`)
---@see |iter-indexing|
---@param start uinteger (Default: `1`)
---@param stop uinteger Default: Length of `t`
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
---@generic T
---@param t T[] Modified in place!
---@param sep T
---@param unit_size uinteger? (Default: `1`)
---@see |iter-indexing|
---@param start integer? (Default: `1`)
---@param stop? integer Default: Length of `t`
---@return T[] Original list reference
function M.i_intersperse(t, sep, unit_size, start, stop)
    local t_len = #t
    local _ntt = require("nvim-tools._table")
    start = _ntt.iter_idx_resolve(start, 1, t_len)
    stop = _ntt.iter_idx_resolve(stop, t_len, t_len)
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
---If the length of `t` is not evenly divisible by `unit_size`, the remainder will be separated
---out at the end of the list.
---@generic T
---@param t T[] Modified in place!
---@param sep T
---@param unit_size uinteger? (Default: `1`)
---@see |iter-indexing|
---@param start integer? (Default: `1`)
---@param stop? integer Default: Length of `t`
---@return T[] Original list reference
function M.i_intersperse_to(t, sep, unit_size, start, stop)
    local t_len = #t
    local _ntt = require("nvim-tools._table")
    start = _ntt.iter_idx_resolve(start, 1, t_len)
    stop = _ntt.iter_idx_resolve(stop, t_len, t_len)
    if t_len == 0 or start >= stop then
        return M.i_copy(t)
    end

    unit_size = math.max(unit_size or 1, 1)
    local iter_len = stop - start + 1
    -- Discard unit_size >= t_len, because `sep` would be appended.
    local sep_count = math.floor((iter_len - 1) / unit_size)
    if sep_count < 1 then
        return M.i_copy(t)
    end

    local new_len = t_len + sep_count
    local res = require("nvim-tools.table").new(new_len, 0)
    return intersperse_do(res, iter_len, sep_count, new_len, t, sep, unit_size, start, stop)
end
-- MID-DEP: For uneven unit sizes, you can add a `rev` boolean to put the extra group before or
-- after the main group loop. Don't do this though without a concrete use case, as it makes the
-- code more complicated.

---Create a new |lua-table| by iterating through `t` and using funciton `f` to return arbitrary
---new key/value pairs.
---@generic K, V, R, M
---@param t table<K, V>
---@param f fun(k:K, v:V): R|nil, M|nil
---@return table<R, M>
function M.rebuild_to(t, f)
    local ret = {} ---@type table<R, M>
    for k, v in pairs(t) do
        local km, vm = f(k, v)
        if km ~= nil and vm ~= nil then
            ret[km] = vm
        end
    end

    return ret
end

---Reverse the order of the items in list `t` in place.
---@generic T
---@param t T[] Modified in place!
function M.i_reverse(t)
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
function M.i_reverse_to(t)
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

---@param left uinteger
---@param right uinteger
local function reverse_do(t, left, right)
    while left < right do
        t[left], t[right] = t[right], t[left]
        left = left + 1
        right = right - 1
    end
end

---https://www.youtube.com/watch?v=mLnkKNDs9DE
---Shift the elements of `t` in place based on `n` (the amount to shift) and `dir` (shift forward
---or backwards.)
---@generic T
---@param t T[] Modified in place.
---@param n uinteger Cyclically clamped at length of `t`.
---@param dir? -1|1 (Default: `-1`) -1 shifts elements left, 1 to the right.
---@return T Reference to the original list.
function M.i_rotate(t, n, dir)
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

    reverse_do(t, 1, steps)
    reverse_do(t, steps + 1, len)
    reverse_do(t, 1, len)

    return t
end

---Create a new list from the shifted elements of `t1`.
---@generic T
---@param t T[]
---@param n uinteger Amount of indices to shift the list. Cyclically clamped at length of `t`.
---@param dir? -1|1 (Default: `-1`) -1 shifts elements left, 1 to the right.
---@return T[] New list. Copy of the original if `n` is zero.
function M.i_rotate_to(t, n, dir)
    local len = #t
    if len <= 1 then
        return M.i_copy(t)
    end

    local steps = math.abs(n) % len
    if steps == 0 then
        return M.i_copy(t)
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

---@generic T, U, M
---@param ret table<any, M>
---@param t1 table<any, any>
---@param t2 table<any, any>
---@param f fun(v1:T, v2:U): M
---@param prev table<table<any, any>, true>
local function zip_deep_with(ret, t1, t2, f, prev)
    if prev[t1] == true then
        return
    end

    prev[t1] = true

    for k, v1 in pairs(t1) do
        local v2 = t2[k]
        if v2 ~= nil then
            local v1_is_dict = M.is_dict(v1) == 2
            local v2_is_dict = M.is_dict(v2) == 2
            if v1_is_dict == true and v2_is_dict == true then
                local v_new = {}
                zip_deep_with(v_new, v1, v2, f, prev)
                ret[k] = v_new
            elseif v1_is_dict == false and v2_is_dict == false then
                ret[k] = f(v1, v2)
            end
        end
    end

    prev[t1] = nil
end

---Recursively zip `t1` and `t2` into a new |lua-dict| based on the results of `f`.
---
---Only keys present in both tables are included (intersection). Structural mis-matches are
---dropped.
---@audited 2026-07-03
---@generic T, U, M
---@param t1 table<any, any>
---@param t2 table<any, any>
---@param f fun(v1:T, v2:U): M
function M.zip_deep_with_to(t1, t2, f)
    local ret = {}
    zip_deep_with(ret, t1, t2, f, {})
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
function M.i_zip_longest(t1, t2, fill)
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

return M
