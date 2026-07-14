local api = vim.api

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
-- TODO: Yeet this when the old buf open stuff is gone.

---`a` and `b` must be in the correct order.
---@audited 2026-07-03
---@param a any
---@param b any
---@param x any
---@return boolean
function M.between(x, a, b)
    return a <= x and x <= b
end

---`a` and `b` must be in the correct order.
---@audited 2026-07-03
---@param a any
---@param b any
---@param x any
---@return boolean
function M.between_(a, b, x)
    return a < x and x < b
end

---@param a any
---@param b any
---@return -1|0|1
function M.cmp(a, b)
    if a < b then
        return -1
    elseif b < a then
        return 1
    else
        return 0
    end
end

---@audited 2026-07-03
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

---@param mode string Potentially multi-character mode.
---@return boolean
function M.is_omode(mode)
    return #mode >= 2 and string.byte(mode, 1) == 110 and string.byte(mode, 2) == 111
end

---@audited 2026-07-03
---@param f fun(...:any): boolean
---@return fun(...:any): boolean
function M.complement(f)
    return function(...)
        return not f(...)
    end
end

---@audited 2026-07-03
local function target_colors_get()
    if api.nvim_get_option_value("bg", { scope = "global" }) == "dark" then
        return "#1E1E1E", "#EFEFEF"
    else
        return "#EFEFEF", "#1E1E1E"
    end
end

---@audited 2026-07-03
function M.cursor_hl_get()
    local normal = api.nvim_get_hl(0, { name = "Normal", link = false }) or {}
    local orig_fg = normal.fg
    local orig_bg = normal.bg
    local target_fg, target_bg = target_colors_get()

    return orig_bg or target_fg, orig_fg or target_bg
end
-- LOW: You could be fancier about not pulling in `bg` but this is not hot code.

---@audited 2026-07-03
---@diagnostic disable-next-line: deprecated
M.nonnil = vim.not_nil or vim.F.if_nil
-- TODO-DEP: Nvim 0.15 released

return M

-- TODO: Misc. should be distinguished between misc vim interactions and misc pure Lua
