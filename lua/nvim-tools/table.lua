local M = {}

-- Port of Neovim core logic since their table module is private
local has_new, new = pcall(require, "table.new")
if not has_new then
    ---@diagnostic disable-next-line: unused-local
    new = function(narray, nhash)
        return {}
    end
end

---@type fun(narray: integer, nhash: integer): table
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

---@generic T
---@type fun(t:T)
M.clear = clear

---Performs a shallow copy
---@generic T
---@param t table<T, T>
---@return table<any, any>
function M.copy(t)
    vim.validate("t", t, "table")

    local ret = {}
    for k, v in pairs(t) do
        ret[k] = v
    end

    return ret
end

---@generic T, V
---@param t table<T, V>
---@return uinteger
function M.keys_count(t)
    local count = 0
    for _, _ in pairs(t) do
        count = count + 1
    end

    return count
end

---@generic K, V, R
---@param t table<K, V>
---@param f fun(k:K, v:V): R|nil
function M.filter_map_to(t, f)
    local ret = {}
    for k, v in pairs(t) do
        local r = f(k, v)
        if r ~= nil then
            ret[k] = r
        end
    end

    return ret
end

---@generic T, V
---@param t table<T, V>
---@param f fun(k: T, v: V): boolean|nil
function M.filter(t, f)
    vim.validate("t", t, "table")
    vim.validate("f", f, "callable")

    for k, v in pairs(t) do
        if not f(k, v) then
            t[k] = nil
        end
    end
end

---@generic K, V, A, C, U
---@param t table<K, V>
---@param f fun(k:K, v:V, acc:A, acc2:C, acc3: U): A|nil, C|nil, U|nil
---@param init A?
---@param init2 C?
---@param init3? U
function M.fold3(t, f, init, init2, init3)
    local acc = init
    local acc2 = init2
    local acc3 = init3
    for k, v in pairs(t) do
        acc, acc2, acc3 = f(k, v, acc, acc2, acc3)
    end

    return acc, acc2, acc3
end

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

---Since vim.tbl_keys will be deprecated and maybe not replaced.
---@generic T
---@param t table<T, T>
---@return T[]
function M.keys(t)
    vim.validate("t", t, "table")

    local ret = {}
    for k, _ in pairs(t) do
        ret[#ret + 1] = k
    end

    return ret
end

---Bespoke version because of future tbl_ deprecation
---The tbl_ version also does not contain the o == nil guard.
---Like the built-in, will only return non-nil if it is able to traverse the specific path
---specified in the args to a non-nil value.
---@param t? table Table to index
---@param ... any Optional keys (0 or more, variadic) via which to index the table
---@return any # Nested value indexed by key (if it exists), else nil
function M.get(t, ...)
    vim.validate("t", t, "table", true)

    if t == nil then
        return nil
    end

    local nargs = select("#", ...)
    if nargs == 0 then
        return nil
    end

    for i = 1, nargs do
        t = t[select(i, ...)] --- @type any
        if t == nil then
            return nil
        elseif type(t) ~= "table" and i ~= nargs then
            return nil
        end
    end

    return t
end

---@param  ... any Table keys
---@return string
function M.keys_to_str(...)
    local nargs = select("#", ...)
    if nargs == 0 then
        return ""
    end

    local keys = {}
    for i = 1, nargs do
        local k = select(i, ...)
        keys[i] = type(k) == "string" and k or vim.inspect(k)
    end

    return table.concat(keys, ".")
end
-- TODO: Should be able to take a custom separator.
-- TODO: Is vim.inspect for non-strings really the right choice?

return M
