-- local api = vim.api

local M = {}

---@generic T
---@param t T[]
function M.clear(t)
    local len = #t
    for i = 1, len do
        t[i] = nil
    end
end

---@generic T
---@param t T[]
function M.copy(t)
    local len = #t
    local ret = require("nvim-tools.table").table_new(len, 0)
    for i = 1, len do
        ret[i] = t[i]
    end

    return ret
end

---@generic T
---@param t T[]
---@param f fun(x: T): boolean
function M.filter(t, f)
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
---@param v T
---@param idx integer
function M.insert(t, v, idx)
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
    local len = #t
    local j = idx
    for i = idx + 1, len do
        t[j] = t[i]
        j = j + 1
    end

    t[len] = nil
end

return M
