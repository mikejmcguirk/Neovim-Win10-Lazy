-- NOTE: Do not require other modules in here during initialization or configuration. It should be
-- possible for users to pass config during startup without eager loading more of the plugin.

local M = {}

-- TODO: Because metatables only consider the current key depth, if you want to have nested
-- options, you need nested validation layers. So far farsight, if you wanted to modify a csearch
-- option, the outer validation would need to verify that you have hit a valid table index, then
-- the inner validation would need to verify that the inner key is a valid type.
-- It would seem then that the Config_Meta class should be re-usable per level, but take different
-- groups of validators.
-- This leads to silly things like being able to do:
-- require("farsight").config.csearch({ token_depth = 3 })
-- and
-- require("farsight").config({ csearch = { token_depth = 3 }})
-- But I'm not sure this is actually bad

local default_config = {
    foo = 1,
    bar = "baz",
    buzz = { "aldrin", "lightyear" },
}

local validators = {
    foo = "number",
    bar = "string",
    buzz = function(v)
        if type(v) == "table" then
            for _, item in ipairs(v) do
                if type(item) ~= "string" then
                    return false
                end
            end

            return true
        else
            return type(v) == "string"
        end
    end,
}

---@param validator string|string[]|fun(val:any): valid:boolean
---@param val any
---@return boolean
local function validate(validator, val)
    local validator_type = type(validator)
    if validator_type == "table" then
        for _, v in ipairs(validator) do
            if type(val) == v then
                return true
            end
        end

        return false
    end

    if validator_type == "function" then
        return validator(val)
    end

    return type(val) == validator
end
-- TODO: Look at vim.validate
-- TODO: Optimize ordering for common case

local Config_Meta = {}

function Config_Meta.__index(self, k)
    local _config_item = rawget(rawget(self, "_config"), k)
    return _config_item and _config_item or Config_Meta[k]
end

function Config_Meta.__newindex(self, k, v)
    local validator = validators[k]
    if not validator then
        return
    end

    if validate(validator, v) then
        rawset(rawget(self, "_config"), k, v)
    end
end

---@param new_tbl nvim-tools.init.Config
function Config_Meta:__call(new_tbl)
    if type(new_tbl) ~= "table" then
        return
    end

    local _config = rawget(self, "_config") ---@type nvim-tools.init.Config
    for k, v in pairs(new_tbl) do
        local validator = validators[k]
        if validator and validate(validator, v) then
            rawset(_config, k, v)
        end
    end
end

---@return nvim-tools.init.Config
function Config_Meta:get()
    return vim.deepcopy(rawget(self, "_config"))
end

local function create_config()
    ---@type nvim-tools.init.ConfigMeta
    ---@diagnostic disable-next-line: missing-fields
    local config = {}
    config._config = vim.deepcopy(default_config, true)
    setmetatable(config, Config_Meta)
    return config
end

M.config = create_config()

function M.reset_config()
    M.config = create_config()
end

return M

-- TODO: Add proper typing to the functions.
