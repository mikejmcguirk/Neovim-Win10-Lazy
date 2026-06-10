local M = {}

---@param str string
---@param new_items string[]
---@param sep string
---@return string
function M.append_if_missing(str, new_items, sep)
    vim.validate("str", str, "string")
    vim.validate("new_items", new_items, "table")
    vim.validate("sep", sep, "string")

    local new = { (#str > 0 and str or nil) } ---@type string[]
    for _, item in ipairs(new_items) do
        if string.find(str, item, 1, true) == nil then
            new[#new + 1] = item
        end
    end

    return table.concat(new, sep)
end

---Inclusive
---`a` and `b` must be in the correct order.
---@param a any
---@param b any
---@param x any
---@return boolean
function M.between(x, a, b)
    return a <= x and x <= b
end

---@param a any
---@param b any
---@param x any
---@return boolean
function M.between_(a, b, x)
    return a < x and x < b
end

---@param str string
---@param new_items string[]
---@param sep string
function M.prepend_if_missing(str, new_items, sep)
    vim.validate("str", str, "string")
    vim.validate("new_items", new_items, "table")
    vim.validate("sep", sep, "string")

    local new = {} ---@type string[]
    for _, item in ipairs(new_items) do
        if string.find(str, item, 1, true) == nil then
            new[#new + 1] = item
        end
    end

    new[#new + 1] = (#str > 0 and str or nil)
    return table.concat(new, sep)
end

---@diagnostic disable-next-line: deprecated
M.nonnil = vim.not_nil or vim.F.if_nil
-- DEPRECATE: Nvim 0.15 released

---@param timer uv.uv_timer_t|nil
---@return nil
function M.close_timer(timer)
    if timer and not timer:is_closing() then
        timer:stop()
        timer:close()
    end

    return nil
end

---@param x integer
---@param y integer
---@param min integer
---@param max integer
---@return integer
function M.wrapping_add(x, y, min, max)
    vim.validate("x", x, "number")
    vim.validate("y", y, "number")
    vim.validate("min", min, "number")
    vim.validate("max", max, "number")

    local period = max - min + 1
    return ((x - min + y) % period) + min
end

---@param x integer
---@param y integer
---@param min integer
---@param max integer
---@return integer
function M.wrapping_sub(x, y, min, max)
    vim.validate("x", x, "number")
    vim.validate("y", y, "number")
    vim.validate("min", min, "number")
    vim.validate("max", max, "number")

    local period = max - min + 1
    return ((x - y - min) % period) + min
end

return M
