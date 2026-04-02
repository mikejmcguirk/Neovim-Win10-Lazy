local M = {}

---@class nvim-tools.explicit.ConfigProxy
local Config_Proxy = {}

Config_Proxy.__index = function(self, key)
    if key == "_validators" then
        return rawget(self, "_validators")
    end

    local config = rawget(self, "_config")
    if key == "_config" then
        return config
    end

    local value = rawget(config, key)
    if value ~= nil then
        return value
    else
        return rawget(Config_Proxy, key)
    end
end

---@param validator string|function|table
---@param val any
---@return boolean
local function validate(validator, val)
    if type(validator) == "string" then
        return type(val) == validator
    elseif type(validator) == "function" then
        return validator(val)
    else
        return false
    end
end
-- TODO: for table validators, iterate through them

Config_Proxy.__newindex = function(self, key, value)
    local data = rawget(self, "_config")
    local validators = rawget(self, "_validators")
    local validator = validators[key]

    if validator and validate(validator, value) then
        rawset(data, key, value)
    end
end
-- TODO: This does not properly handle setting subtables. If you overwrite the table, I think
-- it's fine because it performs the valid_list function on the new value. But if you edit the
-- sub-table directly, then I think what happens is it calls __index at the proxy level then
-- goes to the subtable to edit/add the element directly. Should not allow for naked writes.
-- Perhaps __indexes to non-meta tables always return deep copies.

function Config_Proxy.__call(self, new_tbl)
    vim.validate("new_tbl", new_tbl, "table")
    if type(new_tbl) ~= "table" then
        return
    end

    local data = rawget(self, "_config")
    local validators = rawget(self, "_validators")

    for k, v in pairs(new_tbl) do
        local validator = validators[k]
        if validator and validate(validator, v) then
            rawset(data, k, v)
        end
    end
end
-- TODO: I'm not sure this is falling through the way I'm expecting it to. Getting a string error
-- if I do this on nested configs. I think hat you need to do is check the key, and if it's for
-- a proxy table then run it without rawset, or something.
-- TODO: What happens is this is run with a nil table arg? Empty tables should of course be
-- a no-op.

local function create_config()
    return {
        foo = 1,
        bar = "buzz",
        bazz = { 1, 2, 3, 4 },
        buzz = { "aldrin", "lightyear" },
        nested = setmetatable({
            _config = {
                foo = 2,
                bar = "bazzite",
                deeper = {
                    baz = "bill",
                    fuzz = 4,
                },
            },
            _validators = {
                foo = "number",
                bar = "string",
                deeper = {
                    baz = "string",
                    fuzz = "number",
                },
            },
        }, Config_Proxy),
    }
end
-- TODO: fill this out so that the sub-tabling is explicit
-- We do not want to have the _config and _validator nags *within* the table structure, so maybe
-- that requires adjusting the __index and __newindex methods to run explicit checks for the
-- Config_Proxy metatable.

M.config = create_config()

return M
