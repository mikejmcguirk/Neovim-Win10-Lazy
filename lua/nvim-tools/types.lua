local M = {}

---Added even though vim._assert_integer exists because it's a private function and it performs
---conversion in addition to validation.
---@param n any
---@return boolean
function M.is_int(n)
    if type(n) ~= "number" then
        return false
    end

    return n % 1 == 0
end

---@param n any
---@return boolean
function M.is_uint(n)
    if M.is_int(n) == false then
        return false
    end

    return n >= 0
end

---@generic T
---@param v T
---@return boolean
function M.not_nil(v)
    return v ~= nil
end

---@class nvim-tools.types.ValidateListOpts
---@field func? fun(t:any[]):boolean, string?
---@field item_type? string|string[]
---@field len? integer
---@field max_len? integer
---@field min_len? integer

---@generic T
---@param t any
---@param opts nvim-tools.types.ValidateListOpts
---@return boolean, string|nil
function M.valid_list(t, opts)
    if not vim.islist(t) then
        return false, "Not a valid list"
    end

    local list_len = #t
    local len = opts.len
    if len and list_len ~= len then
        return false, "List length must be " .. len
    end

    local min_len = opts.min_len
    if min_len and list_len < min_len then
        return false, "List length must be at least" .. min_len
    end

    local max_len = opts.max_len
    if max_len and list_len > max_len then
        return false, "List length must be at most" .. max_len
    end

    local item_type = opts.item_type
    if item_type then
        local find = require("nvim-tools.list").find
        local predicate = type(item_type) == "table"
                and function(v)
                    return find(item_type, type(v)) == nil
                end
            or function(v)
                return type(v) ~= item_type
            end

        local bad_idx = find(t, predicate)
        if bad_idx then
            return false, "Item at index " .. bad_idx .. " is not type " .. vim.inspect(item_type)
        else
            return true, nil
        end
    end

    local func = opts.func
    if func then
        return func(t)
    end

    return true
end

return M
