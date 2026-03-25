local M = {}

local default_config = {
    foo = 1,
    bar = "buzz",
    bazz = { 1, 2, 3, 4 }, -- leaf list (function validator)
    buzz = { "aldrin", "lightyear" }, -- leaf list (function validator)
    nested = { -- "owned" hash table layer (explicit marker)
        foo = 2,
        bar = "bazzite",
    },
}

local validators = {
    foo = "number",
    bar = "string",
    bazz = function(v)
        return vim.islist(v)
            and vim.tbl_all(v, function(n)
                return type(n) == "number"
            end)
    end,
    buzz = function(v)
        return vim.islist(v)
            and vim.tbl_all(v, function(s)
                return type(s) == "string"
            end)
    end,

    -- "owned" hash table layer — explicitly marked so we know it gets its own validation layer
    nested = {
        __config = true, -- ← this is the explicit "owned" marker
        foo = "number",
        bar = "string",
    },
}

---@param validator string|function|table
---@param val any
---@return boolean
local function validate(validator, val)
    if type(validator) == "function" then
        return validator(val)
    end
    if type(validator) == "string" then
        return type(val) == validator
    end
    return false
end

---@class nvim-tools.init.Config
---@field foo? integer

---@class nvim-tools.init.ConfigMeta
---@field _config nvim-tools.init.Config
local Config_Meta = {}

-- Per-level decision: does this key point to an "owned" hash table layer?
Config_Meta.__index = function(proxy, key)
    local data = rawget(proxy, "_config")
    local value = rawget(data, key)

    local field_validator = (rawget(proxy, "_validator") or validators)[key]

    -- Explicit "owned" hash table layer: create a sub-proxy so writes inside it are validated
    if
        type(value) == "table"
        and type(field_validator) == "table"
        and field_validator.__config
    then
        local sub_proxy = {}
        rawset(sub_proxy, "_config", value) -- share the real data slice
        rawset(sub_proxy, "_validator", field_validator) -- sub-validator (minus the marker)
        setmetatable(sub_proxy, Config_Meta)
        return sub_proxy
    end

    -- Leaf case (scalar, list, or any plain table)
    -- → return the raw value/table so the caller never sees a proxy
    if value ~= nil then
        return value
    end

    return rawget(Config_Meta, key) -- class methods
end

Config_Meta.__newindex = function(proxy, key, value)
    local data = rawget(proxy, "_config")
    local validator = rawget(proxy, "_validator") or validators
    local field_validator = validator[key]

    if not field_validator then
        return -- unknown key → silent
    end

    if validate(field_validator, value) then
        rawset(data, key, value)
    end
    -- invalid → silently ignored
end

---@param new_tbl nvim-tools.init.Config
function Config_Meta:__call(new_tbl)
    if type(new_tbl) ~= "table" then
        return
    end

    local data = rawget(self, "_config")
    local validator = rawget(self, "_validator") or validators

    for k, v in pairs(new_tbl) do
        local field_validator = validator[k]
        if field_validator and validate(field_validator, v) then
            rawset(data, k, v)
        end
    end
    -- empty table or unknown keys → silent no-op
end
-- TODO: If no argument is passed, return the table

function Config_Meta:get()
    return vim.deepcopy(rawget(self, "_config"))
end

function Config_Meta:reset()
    rawset(self, "_config", vim.deepcopy(default_config))
end

local function create_config()
    local proxy = {}
    rawset(proxy, "_config", vim.deepcopy(default_config))
    setmetatable(proxy, Config_Meta)
    return proxy
end

M.config = create_config()

function M.reset_config()
    M.config = create_config()
end

return M
