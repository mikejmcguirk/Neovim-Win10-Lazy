---@class farsight.Util
local M = {}

---@param opt boolean|nil
---@param default boolean
---@return boolean
function M._resolve_bool_opt(opt, default)
    if type(opt) == "nil" then
        return default
    else
        vim.validate("opt", opt, "boolean")
        return opt
    end
end

---If a found var is a table, return with vim.deepcopy
---@param opt any
---@param var string
---@param buf integer
---@return any
function M._use_gb_if_nil(opt, var, buf)
    if opt ~= nil then
        return opt
    end

    if vim.b[buf][var] ~= nil then
        if type(vim.b[buf][var]) == "table" then
            return vim.deepcopy(vim.b[buf][var])
        else
            return vim.b[buf][var]
        end
    end

    if vim.g[var] ~= nil then
        if type(vim.g[var]) == "table" then
            return vim.deepcopy(vim.g[var])
        else
            return vim.g[var]
        end
    end

    return nil
end

---@param n integer
---@return boolean
function M._is_int(n)
    if type(n) ~= "number" then
        return false
    end

    return n % 1 == 0
end

---@param n integer
---@return boolean
function M._is_uint(n)
    if M._is_int(n) == false then
        return false
    end

    return n >= 0
end

return M
