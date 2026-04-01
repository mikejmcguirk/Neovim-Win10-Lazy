local M = {}

local default_config = {
    foo = 1,
    bar = "buzz",
    bazz = { 1, 2, 3, 4 },
    buzz = { "aldrin", "lightyear" },
    nested = {
        foo = 2,
        bar = "bazzite",
        deeper = {
            baz = "bill",
            fuzz = 4,
        },
    },
}

local config_schema = {
    foo = "number",
    bar = "string",
    bazz = function(v)
        return require("nvim-tools.types").valid_list(v, { item_type = "number" })
    end,
    buzz = function(v)
        return require("nvim-tools.types").valid_list(v, { item_type = "string" })
    end,
    nested = {
        __config = true,
        foo = "number",
        bar = "string",
        deeper = {
            __config = true,
            baz = "string",
            fuzz = "number",
        },
    },
}

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

---@class nvim-tools.init.ConfigProxy
local Config_Proxy = {}

local function clean_config(value)
    if type(value) ~= "table" then
        return value
    end

    if getmetatable(value) == Config_Proxy then
        value = rawget(value, "_config")
    end

    local clean = {}
    for k, v in pairs(value) do
        clean[k] = clean_config(v)
    end

    return clean
end

Config_Proxy.__index = function(self, key)
    local data = rawget(self, "_config")
    local value = rawget(data, key)

    if value ~= nil then
        return value
    else
        return rawget(Config_Proxy, key)
    end
end

Config_Proxy.__newindex = function(self, key, value)
    local data = rawget(self, "_config")
    local validators = rawget(self, "_validators")
    local validator = validators[key]

    if validator and validate(validator, value) then
        rawset(data, key, value)
    end
end
-- TODO: Unsure what you do when you newindex a subtable. I think it just fails validation. Should
-- call __call() to merge in

function Config_Proxy.__call(self, new_tbl)
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

function Config_Proxy:get()
    return clean_config(self)
end

local function clean_schema(schema)
    local clean = {}
    for k, v in pairs(schema) do
        if k ~= "__config" then
            clean[k] = v
        end
    end

    return clean
end

local function build_proxy(data, schema)
    local proxy = {}
    rawset(proxy, "_config", data)
    rawset(proxy, "_validators", clean_schema(schema))
    setmetatable(proxy, Config_Proxy)
    return proxy
end

local function create_config()
    local root_data = vim.deepcopy(default_config)
    local root_proxy = build_proxy(root_data, config_schema)

    local function build_sub_proxies(sub_data, sub_schema)
        for k, v in pairs(sub_schema) do
            if type(v) == "table" and v.__config then
                local child_data = sub_data[k]
                sub_data[k] = build_proxy(child_data, v)
                build_sub_proxies(child_data, v)
            end
        end
    end

    build_sub_proxies(root_data, config_schema)
    return root_proxy
end

M.config = create_config()

function M.reset_config()
    M.config = create_config()
end

-- setmetatable(M, {
--
-- })

return M
