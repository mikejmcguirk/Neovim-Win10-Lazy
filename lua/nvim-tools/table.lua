-- local api = vim.api

local M = {}

---@type fun(narray: integer, nhash: integer): table
M.table_new = (function()
    local t_new = require("table.new")
    if t_new then
        ---@diagnostic disable-next-line: undefined-field
        return table.new
    else
        return function()
            return {}
        end
    end
end)()

---@generic T
---@param t table<T, T>
function M.clear(t)
    vim.validate("t", t, "table")

    for k, _ in pairs(t) do
        t[k] = nil
    end
end

---Performs a shallow copy
---@generic T
---@param t table<T, T>
---@return table<any, any>
function M.copy(t)
    local ret = {}
    for k, v in pairs(t) do
        ret[k] = v
    end

    return ret
end

---@generic T
---@param t table<T, T>
---@param f fun(k: T, v: T): boolean|nil
function M.filter(t, f)
    vim.validate("t", t, "table")
    vim.validate("f", f, "callable")

    for k, v in pairs(t) do
        if not f(k, v) then
            t[k] = nil
        end
    end
end

---@generic T
---@param t table<T, T>
---@param k T
---@param v T
function M.get_or_set(t, k, v)
    vim.validate("t", t, "table")
    local not_nil = require("nvim-tools.types").not_nil
    vim.validate("k", k, not_nil)
    vim.validate("v", v, not_nil)

    local ret = t[k]
    if ret then
        return ret
    end

    t[k] = v
    return v
end

---Since vim.tbl_keys will be deprecated and maybe not replaced.
---@generic T
---@param t table<T, T>
---@return T[]
function M.keys(t)
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
-- FUTURE: If this function is kept in vim.table/vim.dict, consider doing a PR there to address the
-- nil table case so the bespoke version can be deleted.

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

return M
