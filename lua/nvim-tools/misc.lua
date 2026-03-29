local M = {}

---@param str string
---@param new_items string[]
---@param sep string
---@return string
function M.append_if_missing(str, new_items, sep)
    local new = { (#str > 0 and str or nil) } ---@type string[]
    for _, item in ipairs(new_items) do
        if string.find(str, item, 1, true) == nil then
            new[#new + 1] = item
        end
    end

    return table.concat(new, sep)
end

---@param str string
---@param new_items string[]
---@param sep string
function M.prepend_if_missing(str, new_items, sep)
    local new = {} ---@type string[]
    for _, item in ipairs(new_items) do
        if string.find(str, item, 1, true) == nil then
            new[#new + 1] = item
        end
    end

    new[#new + 1] = (#str > 0 and str or nil)
    return table.concat(new, sep)
end

---Copy-paste of vim.F.if_nil since the future of that module is uncertain
---https://github.com/neovim/neovim/pull/34633
---@generic T
---@param ... T
---@return T
function M.if_not_nil(...)
    local nargs = select("#", ...)
    for i = 1, nargs do
        local v = select(i, ...)
        if v ~= nil then
            return v
        end
    end

    return nil
end

return M
