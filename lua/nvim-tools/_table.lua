local M = {}

---@generic T
---@param lists_len uinteger
---@param lists T[][]
---@param dst T[] Modified in place!
function M.lists_append(lists_len, lists, dst)
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

---Assumes:
---- Length of `t` > 0
---- `start` and `stop` are valid.
---@generic T
---@param t T[]
---@param start uinteger
---@param stop uinteger
function M.i_copy_exact(t, start, stop)
    local ret = require("nvim-tools.table").new(stop - start + 1, 0)
    local j = 1
    for i = start, stop do
        ret[j] = t[i]
        j = j + 1
    end

    return ret
end

---@generic T
---@param t T[]
---@param t_len uinteger
---@param dst T[] Modified in place!
---@param f fun(x:T): boolean
---@return uinteger
function M.i_discard_do(t, t_len, dst, f)
    local j = 1
    for i = 1, t_len do
        local v = t[i]
        if not f(v) then
            dst[j] = v
            j = j + 1
        end
    end

    return j
end

---@generic T
---@param init uinteger
---@param fin uinteger
---@param step -1|1
---@param t T[]
---@param f fun(x:T): boolean
---@param first uinteger
---@return uinteger
function M.discard_while_find_first(init, fin, step, t, f, first)
    for i = init, fin, step do
        if not f(t[i]) then
            return i
        end
    end

    return first
end

---@generic T
---@param t T[] Modified in place!
---@param t_len uinteger
---@param key_fn fun(val:any): any
---@param seen table<any, true>
function M.filter_keep_not_seen_in_place(t, t_len, key_fn, seen)
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
---@param t T[]
---@param t_len uinteger
---@param key_fn fun(val:any): any
---@param seen table<any, true>
function M.filter_keep_not_seen_to(t, t_len, key_fn, seen)
    local ret = {}
    local j = 1
    for i = 1, t_len do
        local v = t[i]
        local vh = key_fn(v)
        if vh ~= nil and not seen[vh] then
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
function M.filter_keep_not_seen_unique_in_place(t, t_len, key_fn, seen)
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
function M.filter_keep_not_seen_unique_to(t, t_len, key_fn, seen)
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

---@generic T
---@param t T[] Modified in place!
---@param t_len uinteger
---@param key_fn fun(val:any): any
---@param seen table<any, true>
function M.filter_keep_seen_in_place(t, t_len, key_fn, seen)
    local j = 1
    for i = 1, t_len do
        local v = t[i]
        local vh = key_fn(v)
        if vh ~= nil and seen[vh] then
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
function M.filter_keep_seen_to(t, t_len, key_fn, seen)
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
function M.filter_keep_seen_unique_in_place(t, t_len, key_fn, seen)
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
function M.filter_keep_seen_unique_to(t, t_len, key_fn, seen)
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
---@param default integer
---@param len uinteger
---@return uinteger
function M.iter_idx_resolve(idx, default, len)
    local res_idx = math.min(idx or default, len)
    if res_idx > 0 then
        return res_idx
    end

    return len - math.min(len, res_idx * -1)
end

---Will clamp at zero for lists of those length. Zero case must be manually handled.
---@param idx integer
---@param len uinteger
---@return uinteger
function M.iter_idx_resolve_no_default(idx, len)
    local res_idx = math.min(idx, len)
    if res_idx > 0 then
        return res_idx
    end

    return len - math.min(len, res_idx * -1)
end

---@generic T
---@param t T[]
---@param t_len uinteger
---@param dst T[] Modified in place!
---@param f fun(x:T): boolean
---@return uinteger
function M.keep_do(t, t_len, dst, f)
    local j = 1
    for i = 1, t_len do
        local v = t[i]
        if f(v) then
            dst[j] = v
            j = j + 1
        end
    end

    return j
end

---@generic T
---@param init uinteger
---@param fin uinteger
---@param step -1|1
---@param t T[]
---@param f fun(x:T): boolean
---@param last uinteger
---@return uinteger
function M.keep_while_find_last(init, fin, step, t, f, last)
    for i = init, fin, step do
        if f(t[i]) then
            last = i
        else
            return last
        end
    end

    return last
end

---Credit: Nvim core.
---@generic T
---@param key nil|string|fun(v:T): any
---@return fun(v: T): any
function M.key_fn_from_key(key)
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

---@generic T, U
---@param t_len uinteger
---@param t T[]
---@param f fun(x:T): T|nil
---@param dst T[] Modified in place!
---@return uinteger
function M.i_filter_map_do(t_len, t, f, dst)
    local j = 1
    for i = 1, t_len do
        local vm = f(t[i])
        if vm ~= nil then
            dst[j] = vm
            j = j + 1
        end
    end

    return j
end

---@generic T, U
---@param len uinteger
---@param t1 T[]
---@param t2 U[]
---@param f fun(x:T, y:U): T|nil
---@param dst T[] Modified in place!
---@return uinteger
function M.i_filter_map2_do(len, t1, t2, f, dst)
    local j = 1
    for i = 1, len do
        local vm = f(t1[i], t2[i])
        if vm ~= nil then
            dst[j] = vm
            j = j + 1
        end
    end

    return j
end

---@generic T
---@param nargs uinteger
---@param comp fun(a:T, b:T): boolean
---@param lists T[][]
---@return T[]
function M.merge_sorted_do(nargs, comp, lists)
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
    local cur_idxs = M.i_replicate_to_do(1, nargs)
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

---Assumes that count is > 0 and valid.
---@generic T
---@param v T
---@param count uinteger
---@return T[]
function M.i_replicate_to_do(v, count)
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
function M.resolve_rev(start, stop, rev)
    if not rev then
        return start, stop, 1
    end

    return stop, start, -1
end

---@generic T, U
---@param t T[]
---@param key_fn fun(v:T): U
---@param seen table<U, true> Modified in place!
local function seen_from_varargs_if_in_any_iter(t, key_fn, seen)
    local t_len = #t
    for j = 1, t_len do
        local vh = key_fn(t[j])
        if vh ~= nil then
            seen[vh] = true
        end
    end
end

---Assumes at least one list.
---@generic T
---@param lists T[][]
---@param lists_len uinteger
---@return uinteger len_max, uinteger idx_max
local function lists_max_len_get(lists, lists_len)
    local idx_max = 1
    local len_max = #lists[1]
    for i = 2, lists_len do
        local len = #lists[i]
        if len > len_max then
            len_max = len
            idx_max = i
        end
    end

    return len_max, idx_max
end

---@generic T, U
---@param t T[]
---@param t_len uinteger
---@param key_fn fun(v:T): U
---@return table<U, uinteger>
local function seen_from_varargs_counts_init(t, t_len, key_fn)
    local counts = {} ---@type table<any, uinteger>
    for i = 1, t_len do
        local vh = key_fn(t[i])
        if vh ~= nil then
            counts[vh] = 1
        end
    end

    return counts
end

---@generic T
---@param t T[]
---@param key_fn fun(v:T): any
---@param counts table<any, uinteger> Modified in place!
---@param t_last uinteger
---@param t_current uinteger
local function seen_from_varargs_if_in_all_iter(t, key_fn, counts, t_last, t_current)
    local t_len = #t
    for j = 1, t_len do
        local vh = key_fn(t[j])
        if vh ~= nil and counts[vh] == t_last then
            counts[vh] = t_current
        end
    end
end

---@generic T, U
---@param nargs uinteger
---@param lists T[][]
---@param key_fn fun(v:T): U
---@return table<U, true>
function M.seen_from_vargs_if_in_all(nargs, lists, key_fn)
    if nargs == 0 then
        return {}
    end

    if nargs == 1 then
        local seen = {} ---@type table<any, true>
        seen_from_varargs_if_in_any_iter(lists[1], key_fn, seen)
        return seen
    end

    local len_max, idx_max = lists_max_len_get(lists, nargs)
    local counts = seen_from_varargs_counts_init(lists[idx_max], len_max, key_fn)
    local t_last = 0
    local t_current = 1
    local idx_before_min = idx_max - 1
    for i = 1, idx_before_min do
        seen_from_varargs_if_in_all_iter(lists[i], key_fn, counts, t_last, t_current)
        t_last = t_last + 1
        t_current = t_current + 1
    end

    for i = idx_max + 1, nargs do
        seen_from_varargs_if_in_all_iter(lists[i], key_fn, counts, t_last, t_current)
        t_last = t_last + 1
        t_current = t_current + 1
    end

    local seen = {} ---@type table<any, true>
    for vh, count in pairs(counts) do
        if count == nargs then
            seen[vh] = true
        end
    end

    return seen
end

---@generic T, U
---@param nargs uinteger
---@param lists T[][]
---@param key_fn fun(v:T): U
---@return table<U, true>
function M.seen_from_varargs_if_in_any(nargs, lists, key_fn)
    local seen = {} ---@type table<any, true>
    for i = 1, nargs do
        seen_from_varargs_if_in_any_iter(lists[i], key_fn, seen)
    end

    return seen
end

---@generic T
---@param t T[]
---@param key_fn fun(v:T): any
---@param counts table<any, uinteger> Modified in place!
---@param t_last uinteger
---@param t_current uinteger
local function seen_from_varargs_if_in_some_list_iter(t, key_fn, counts, t_last, t_current)
    local t_len = #t
    for j = 1, t_len do
        local vh = key_fn(t[j])
        if vh ~= nil then
            local count = counts[vh]
            if count == t_last then
                counts[vh] = t_current
            elseif count == nil then
                counts[vh] = 1
            end
        end
    end
end

---@generic T, U
---@param nargs integer
---@param lists T[]
---@param key_fn fun(v: T): U
---@return table<U, true>
function M.seen_from_varargs_if_in_some(nargs, lists, key_fn)
    if nargs <= 1 then
        return {}
    end

    local len_max, idx_max = lists_max_len_get(lists, nargs)
    local counts = seen_from_varargs_counts_init(lists[idx_max], len_max, key_fn)
    local t_last = 1
    local t_current = 2
    for i = 1, idx_max - 1 do
        seen_from_varargs_if_in_some_list_iter(lists[i], key_fn, counts, t_last, t_current)
        t_last = t_last + 1
        t_current = t_current + 1
    end

    for i = idx_max + 1, nargs do
        seen_from_varargs_if_in_some_list_iter(lists[i], key_fn, counts, t_last, t_current)
        t_last = t_last + 1
        t_current = t_current + 1
    end

    local seen = {} ---@type table<any, true>
    for vh, count in pairs(counts) do
        if count < nargs then
            seen[vh] = true
        end
    end

    return seen
end

---@generic T, U
---@param t T[]
---@param t_len uinteger
---@param limit? uinteger
---@param dst T[] Modified in place!
---@param key_fn fun(v:T): U
---@return uinteger
function M.select_do(t, t_len, limit, dst, valh, key_fn)
    local j = 1
    local i = 1
    limit = limit or t_len
    while i <= t_len and j <= limit do
        local v = t[i]
        if key_fn(v) == valh then
            dst[j] = v
            j = j + 1
        end

        i = i + 1
    end

    return j
end

---Assumes:
---- t_len > 0.
---- start and stop are already resolved and valid.
---- landing <= start
---@generic T
---@param t T[] Modified in place!
---@param t_len uinteger
---@param start uinteger
---@param stop uinteger
---@param landing uinteger
function M.shift_down_exact(t, t_len, start, stop, landing)
    if start > 1 then
        local j = landing
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

return M
