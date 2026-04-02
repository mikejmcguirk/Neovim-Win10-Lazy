local api = vim.api
local fn = vim.fn

local M = {}

---@class nvim-tools.init.ConfigProxy
---@operator call(table): nil
---@operator call(): table
local Config_Proxy = {}

---@generic T
---@param self nvim-tools.init.ConfigProxy
---@param k T
---@return any
Config_Proxy.__index = function(self, k)
    if k == "_validators" then
        return rawget(self, "_validators")
    end

    local config = rawget(self, "_config")
    if k == "_config" then
        return config
    end

    local value = rawget(config, k)
    if value ~= nil then
        return value
    else
        return rawget(Config_Proxy, k)
    end
end

---@generic T
---@param validator string|function|table
---@param v T
---@return boolean
local function validate(validator, v)
    if type(validator) == "string" then
        return type(v) == validator
    elseif type(validator) == "function" then
        return validator(v)
    elseif type(validator) == "table" then
        return require("nvim-tools.list").find(validator, type(v)) ~= nil
    else
        return false
    end
end

---@generic T
---@param self nvim-tools.init.ConfigProxy
---@param k T
---@param v any
Config_Proxy.__newindex = function(self, k, v)
    local data = rawget(self, "_config")
    local validators = rawget(self, "_validators")
    if v == nil then
        if validators._allow_nil then
            rawset(data, k, v)
        end

        return
    end

    local validator = validators[k]
    if validator and validate(validator, v) then
        rawset(data, k, v)
    elseif getmetatable(data[k]) == Config_Proxy and type(v) == "table" then
        data[k](v)
    end
end
-- DOCUMENT: This method is necessary to set values to nil.
-- DOCUMENT: For non-config subtables, full replacements are required for validation. Direct
-- editing of those tables is free-form.

---@generic T
---@param val T
---@return T
local function get_clean_config(val)
    if type(val) ~= "table" then
        return val
    end

    ---@type table
    local t = getmetatable(val) == Config_Proxy and rawget(val, "_config") or val
    local clean = {}
    for k, v in pairs(t) do
        clean[k] = get_clean_config(v)
    end

    return clean
end

---@param self nvim-tools.init.ConfigProxy
---@param t nvim-tools.init.Config
function Config_Proxy.__call(self, t)
    vim.validate("t", t, "table", true)
    if type(t) == "nil" then
        return get_clean_config(self)
    end

    local data = rawget(self, "_config")
    local validators = rawget(self, "_validators")

    for k, v in pairs(t) do
        local validator = validators[k]
        if validator and validate(validator, v) then
            rawset(data, k, v)
        elseif type(v) == "table" and getmetatable(data[k]) == Config_Proxy then
            data[k](v)
        end
    end
end

---@param self nvim-tools.init.ConfigProxy
---@return boolean
function Config_Proxy:has_config()
    local config = rawget(self, "_config")
    if type(config) ~= "table" then
        return false
    end

    for _, v in pairs(config) do
        if type(v) == "table" and getmetatable(v) == Config_Proxy then
            if v:has_config() then
                return true
            end
        elseif v ~= nil then
            return true
        end
    end

    return false
end

---@class nvim-tools.init.Config
local default_config = {
    foo = 1,
    bar = "buzz",
    bazz = { 1, 2, 3, 4 },
    buzz = { "aldrin", "lightyear" },
    fizz = false,
    nested = {
        foo = 2,
        bar = "bazzite",
        deeper = {
            baz = "bill",
            fuzz = 4,
        },
    },
}

---@param use_defaults boolean
---@param allow_nil boolean
---@return nvim-tools.init.ConfigProxy
local function get_new_config(use_defaults, allow_nil)
    local d = use_defaults and vim.deepcopy(default_config) or {}
    local d_nested = d.nested and d.nested or nil
    local d_deeper = (d_nested and d.nested.deeper) and d_nested.deeper or nil

    return setmetatable({
        _validators = {
            _allow_nil = allow_nil,
            foo = "number",
            bar = "string",
            bazz = function(v)
                return require("nvim-tools.types").valid_list(v, { item_type = "number" })
            end,
            buzz = function(v)
                return require("nvim-tools.types").valid_list(v, { item_type = "string" })
            end,
            fizz = "boolean",
        },
        _config = {
            foo = d.foo,
            bar = d.bar,
            bazz = d.bazz,
            buzz = d.buzz,
            fizz = d.fizz,
            nested = setmetatable({
                _validators = {
                    _allow_nil = allow_nil,
                    foo = "number",
                    bar = "string",
                },
                _config = {
                    foo = d.nested and d.nested.foo,
                    bar = d.nested and d.nested.bar,
                    deeper = setmetatable({
                        _validators = {
                            _allow_nil = allow_nil,
                            baz = "string",
                            fuzz = "number",
                        },
                        _config = {
                            baz = d_deeper and d_deeper.baz,
                            fuzz = d_deeper and d_deeper.fuzz,
                        },
                    }, Config_Proxy),
                },
            }, Config_Proxy),
        },
    }, Config_Proxy)
end
-- TEST: Get the default config. Make sure config/validator keys are the same in all proxy tables

local function set_default_config()
    M.config = get_new_config(true, false)
end

set_default_config()

function M.get_default_config()
    return vim.deepcopy(default_config)
end

function M.reset_config()
    set_default_config()
end

local INVALID_BUF_ERR = "Invalid buffer id: "

---@class nvim-tools.init.BufConfigAccessor
---@field _configs table<integer, nvim-tools.init.Config>
local Buf_Config_Accessor = {}

---@generic T
---@param self nvim-tools.init.BufConfigAccessor
---@param k T
---@return any
Buf_Config_Accessor.__index = function(self, k)
    local configs = rawget(self, "_configs")
    if k == "_configs" then
        return configs
    end

    if not require("nvim-tools.types").is_uint(k) then
        return rawget(Buf_Config_Accessor, k)
    end

    if not api.nvim_buf_is_valid(k) then
        rawset(configs, k, nil)
        error(INVALID_BUF_ERR .. k)
    end

    return rawget(configs, k)
end

---@param buf integer
---@return string
local function get_buf_augroup_name(buf)
    local group_prefix = "nvim-tools-buf-config-"
    return group_prefix .. tostring(buf)
end

local function del_buf_autocmds(buf)
    local group = get_buf_augroup_name(buf)
    local exists = fn.exists("#" .. group) == 1
    if exists then
        api.nvim_del_augroup_by_name(group)
    end
end

---@param configs table<integer, nvim-tools.init.Config>
---@param buf integer
local function clear_buf_config(configs, buf)
    rawset(configs, buf, nil)
    del_buf_autocmds(buf)
end

---@generic T
---@param self nvim-tools.init.BufConfigAccessor
---@param k integer
---@param v any
Buf_Config_Accessor.__newindex = function(self, k, v)
    vim.validate("k", k, require("nvim-tools.types").is_uint)
    vim.validate("v", v, "table", true)

    local configs = rawget(self, "_configs")
    if not api.nvim_buf_is_valid(k) then
        rawset(configs, k, nil)
        error(INVALID_BUF_ERR .. k)
    elseif type(v) == "nil" then
        clear_buf_config(configs, k)
        return
    end

    local config = rawget(configs, k)
    if config then
        config(v)
        if not config:has_config() then
            clear_buf_config(configs, k)
        end

        return
    end

    local new_config = get_new_config(false, true)
    new_config(v)
    if not new_config:has_config() then
        return
    end

    rawset(configs, k, new_config)
    local buf_group = get_buf_augroup_name(k)
    -- Do not use BufDelete because deleted buffers can be reloaded under the same buf id
    api.nvim_create_autocmd("BufWipeout", {
        group = buf_group,
        buffer = k,
        callback = function()
            M.buf_config:clear(k)
        end,
    })
end

---@param self nvim-tools.init.BufConfigAccessor
---@return nvim-tools.init.Config[]
Buf_Config_Accessor.__call = function(self)
    local ret = {} ---@type nvim-tools.init.Config[]
    local configs = rawget(self, "_configs") ---@type table<integer, nvim-tools.init.Config>
    local bufs = require("nvim-tools.table").keys(configs) ---@type integer[]
    if #bufs < 1 then
        return ret
    end

    for _, buf in ipairs(bufs) do
        ret[buf] = configs[buf]()
    end

    return ret
end

---@param self nvim-tools.init.BufConfigAccessor
---@return integer[]
function Buf_Config_Accessor:list_bufs()
    local configs = rawget(self, "_configs") ---@type table<integer, nvim-tools.init.Config>
    return require("nvim-tools.table").keys(configs)
end

---@param self nvim-tools.init.BufConfigAccessor
---@param buf? integer
function Buf_Config_Accessor:clear(buf)
    vim.validate("buf", buf, require("nvim-tools.types").is_uint, true)

    local configs = rawget(self, "_configs") ---@type table<integer, nvim-tools.init.Config>

    if buf ~= nil then
        clear_buf_config(configs, buf)
        return
    end

    local bufs = require("nvim-tools.table").keys(configs) ---@type integer[]
    for _, b in ipairs(bufs) do
        clear_buf_config(configs, b)
    end
end

local function set_new_buf_config()
    M.buf_config = setmetatable({ _configs = {} }, Buf_Config_Accessor)
end

set_new_buf_config()

M.reset_buf_config = function()
    set_new_buf_config()
end

return M
