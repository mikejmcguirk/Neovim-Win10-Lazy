local M = {}

---Added even though vim._assert_integer exists because it's a private function and it performs
---conversion in addition to validation.
---@param n any
---@return boolean
function M.is_int(n)
    return type(n) == "number" and n % 1 == 0
end

---@param n any
---@return boolean
function M.is_uint(n)
    return M.is_int(n) and n >= 0
end

---@param ... any
---@return boolean
function M.not_nil(...)
    local v = require("nvim-tools.misc").nonnil(...)
    return v ~= nil
end

---@class nvim-tools.types.ValidateListOpts
---@field item_type? string|string[]
---@field len? integer Takes precedence over max and min len.
---@field max_len? integer
---@field min_len? integer

---@generic T
---@param t any
---@param opts nvim-tools.types.ValidateListOpts
---@return boolean, string
function M.valid_list(t, opts)
    if not vim.islist(t) then
        return false, "Not a valid list"
    end

    local list_len = #t
    local len = opts.len
    if len ~= nil then
        if list_len ~= len then
            return false, "List length must be " .. len
        end
    else
        local min_len = opts.min_len
        if min_len and list_len < min_len then
            return false, "List length must be at least" .. min_len
        end

        local max_len = opts.max_len
        if max_len and list_len > max_len then
            return false, "List length must be at most" .. max_len
        end
    end

    local item_type = opts.item_type
    if item_type == nil then
        return true, ""
    end

    local ntt = require("nvim-tools.table")
    local predicate = type(item_type) == "table"
            and function(v)
                return ntt.i_includes(item_type, type(v))
            end
        or function(v)
            return type(v) == item_type
        end

    if ntt.i_all(t, predicate) then
        return true, ""
    end

    local ntm = require("nvim-tools.misc")
    local bad_val, bad_idx = ntt.i_find(t, ntm.complement(predicate))
    local fmt_str = "Invalid: Idx: %d, Val: %s, Type: %s, Expected: %s"
    local bad_val_str = tostring(bad_val)
    local bad_type = type(bad_val)
    local expected = vim.inspect(item_type)
    local msg = string.format(fmt_str, bad_idx, bad_val_str, bad_type, expected)

    return false, msg
end

return M
