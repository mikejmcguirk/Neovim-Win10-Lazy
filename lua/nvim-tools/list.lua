-- NOTE: The validators for t in this module only check if the param is a table. Like vim.list,
-- these functions should be able to operate on the list part of a table with a list and dict
-- component.
-- NOTE: These functions should all be pure Lua, not relying on vim.api or vim.fn calls

local M = {}

---@generic T
---@param t T[]
---@return boolean
---@param f fun(x: T): boolean
function M.all(t, f)
    vim.validate("t", t, "table")
    vim.validate("f", f, "callable")

    local len = #t
    for i = 1, len do
        if not f(t[i]) then
            return false
        end
    end

    return true
end

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
---@param t T[]
function M.copy(t)
    vim.validate("t", t, "table")

    local len = #t
    local ret = require("nvim-tools.table").new(len, 0)
    for i = 1, len do
        ret[i] = t[i]
    end

    return ret
end

---Shallow comparison only.
---@generic T
---@param t1 T[]
---@param t2 T[]
---@return boolean
function M.equal(t1, t2)
    vim.validate("t", t1, "table")
    vim.validate("t", t2, "table")

    local len = #t1
    local len_t2 = #t2
    if len ~= len_t2 then
        return false
    end

    for i = 1, len do
        if t1[i] ~= t2[i] then
            return false
        end
    end

    return true
end

---@generic T: table
---@param dst T List which will be modified and appended to
---@param src table List from which values will be inserted
---@param start integer? Start index on src. Defaults to 1
---@param finish integer? Final index on src. Defaults to `#src`
function M.extend(dst, src, start, finish)
    vim.validate("dst", dst, "table")
    vim.validate("src", src, "table")
    vim.validate("start", start, "number", true)
    vim.validate("finish", finish, "number", true)

    start = start or 1
    finish = finish or #src
    for i = start, finish do
        dst[#dst + 1] = src[i]
    end

    -- return dst
end

---@generic T
---@param t T[]
---@param f fun(x: T): boolean
function M.filter(t, f)
    vim.validate("t", t, "table")
    vim.validate("f", f, "callable")

    local len = #t
    local j = 1

    for i = 1, len do
        local v = t[i]
        if f(v) then
            t[j] = v
            j = j + 1
        end
    end

    for i = j, len do
        t[i] = nil
    end
end

---@generic T
---@param t T[]
---@param f fun(x: T): boolean
function M.filter_from_end(t, f)
    vim.validate("t", t, "table")
    vim.validate("f", f, "callable")

    local len = #t
    local j = len
    for i = len, 1, -1 do
        if f(t[i]) then
            t[j] = t[i]
            j = j - 1
        end
    end

    local len_after = len - j
    for i = 1, len_after do
        t[i] = t[j + i]
    end

    for i = len_after + 1, len do
        t[i] = nil
    end
end

---@generic T
---@param t T[]
---@param v T | fun(x: T): boolean
---@return integer|nil
function M.find(t, v)
    vim.validate("t", t, "table")
    vim.validate("v", v, require("nvim-tools.types").not_nil)

    local predicate = type(v) == "function" and v or function(x)
        return x == v
    end

    for i = 1, #t do
        if predicate(t[i]) then
            return i
        end
    end

    return nil
end

---@generic T
---@param t T[]
---@param v T
---@param idx integer
function M.insert(t, v, idx)
    vim.validate("t", t, "table")
    vim.validate("v", v, require("nvim-tools.types").not_nil)
    vim.validate("idx", idx, "number")

    local len = #t
    t[len + 1] = t[len]
    for i = len, idx + 1, -1 do
        t[i] = t[i - 1]
    end

    t[idx] = v
end

---@generic T
---@param t T[]
---@param f fun(x: T, idx: integer): any
function M.map(t, f)
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
end

---@generic T
---@param t T[]
---@param idx integer
function M.remove(t, idx)
    vim.validate("t", t, "table")
    vim.validate("idx", idx, "number")

    local len = #t
    local j = idx
    for i = idx + 1, len do
        t[j] = t[i]
        j = j + 1
    end

    t[len] = nil
end

---`start` and `fin` are handled as passed in without clamping.
---@generic T
---@param t T[]
---@param start integer
---@param fin integer
function M.slice(t, start, fin)
    vim.validate("t", t, "table")
    vim.validate("start", start, "number")
    vim.validate("fin", fin, "number")

    local len_t = #t
    for i = fin + 1, len_t do
        t[i] = nil
    end

    if start == 1 then
        return
    end

    len_t = #t
    local j = 1
    for i = start, len_t do
        t[j] = t[i]
        j = j + 1
    end

    for i = j + 1, len_t do
        t[i] = nil
    end
end

return M
