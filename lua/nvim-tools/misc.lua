local api = vim.api
local uv = vim.uv

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

---@param val boolean?
---@param default boolean
---@return boolean
function M.bool_or_default(val, default)
    if type(val) == "boolean" then
        return val
    else
        return default
    end
end

---@param mode string Potentially multi-character mode.
---@return boolean
function M.is_insert_mode(mode)
    local byte_one = string.byte(mode, 1)
    if byte_one == 82 or byte_one == 105 then
        return true
    end

    if 2 <= #mode and byte_one == 110 and string.byte(mode, 2) == 105 then
        return true
    end

    return false
end

---@param f fun(...:any): boolean
---@return fun(...:any): boolean
function M.complement(f)
    return function(...)
        return not f(...)
    end
end
-- TODO: Use this for the valid_list function in types

local function target_colors_get()
    if api.nvim_get_option_value("bg", { scope = "global" }) == "dark" then
        return "#1E1E1E", "#EFEFEF"
    else
        return "#EFEFEF", "#1E1E1E"
    end
end

function M.cursor_hl_get()
    local normal = api.nvim_get_hl(0, { name = "Normal", link = false }) or {}
    local orig_fg = normal.fg
    local orig_bg = normal.bg
    local target_fg, target_bg = target_colors_get()

    return orig_bg or target_fg, orig_fg or target_bg
end
-- LOW: You could be fancier about not pulling in `bg` but this is not hot code.

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
    if timer and not uv.is_closing(timer) then
        uv.timer_stop(timer)
        uv.close(timer)
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

-- TODO: Misc. should be distinguished between misc vim interactions and misc pure Lua
