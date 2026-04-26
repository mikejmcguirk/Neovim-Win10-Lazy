local api = vim.api

local M = {}

---@param opt boolean|nil
---@param default boolean
---@return boolean
function M.resolve_bool_opt(opt, default)
    vim.validate("default", default, "boolean")
    if type(opt) == "nil" then
        return default
    else
        vim.validate("opt", opt, "boolean")
        return opt
    end
end

---Happens enough in some functions that it saves non-trivial screen real-estate
---set_option_value performs non-trivial work under the hood, so this check is worth running
---@generic T
---@param opt string
---@param old T
---@param new T
---@param scope vim.api.keyset.option
---@return boolean
function M.set_if_new(opt, old, new, scope)
    vim.validate("opt", opt, "string")
    local not_nil = require("nvim-tools.types").not_nil
    vim.validate("old", old, not_nil)
    vim.validate("new", new, not_nil)
    vim.validate("scope", scope, "table")

    if old ~= new and new ~= nil then
        api.nvim_set_option_value(opt, new, scope)
        return true
    end

    return false
end

return M
