local api = vim.api

local M = {}

--------------------------
-- MARK: Dict Functions --
--------------------------

---@param val any
---@param typ string
---@return boolean
local function string_type_is_valid(val, typ)
    local val_type = type(val)
    if typ == "callable" then
        if val_type == "function" then
            return true
        end

        local mt = getmetatable(val)
        if mt == nil then
            return false
        end

        if type(rawget(mt, "__call")) == "function" then
            return true
        end

        return false
    end

    if val_type == typ then
        return true
    end

    return false
end

---@param v any
---@param s string|string[]|fun(val:any): boolean, string
---@return boolean, string
local function validator_check(v, s)
    if type(s) == "string" then
        local ok = string_type_is_valid(v, s)
        local err = ok and ""
            or "Expected " .. s .. ", got " .. type(v) .. " (" .. tostring(v) .. ")"
        return ok, err
    end

    if vim.islist(s) then
        local s_len = #s
        for i = 1, s_len do
            if string_type_is_valid(v, s[i]) then
                return true, ""
            end
        end

        local err = tostring(v) .. ". Expected " .. type(v) .. ". Actual: " .. vim.inspect(s)
        return false, err
    end

    if type(s) == "function" then
        return s(v)
    end

    return false, "Invalid validator for " .. tostring(v)
end

---@param t table
---@param s table
---@param prev table<table, true>
---@return boolean, string
local function matches_validator_with(t, s, prev)
    if prev[t] then
        return false, "Cyclic reference found in values."
    end

    prev[t] = true
    local ntt = require("nvim-tools.table")
    for k, v in pairs(t) do
        local vs = s[k]
        if vs == nil then
            prev[t] = nil
            return false, "[" .. tostring(k) .. "]" .. " has no validator."
        end

        local v_is_dict = ntt.is_dict(v) == 2
        local vs_is_dict = ntt.is_dict(vs) == 2
        if v_is_dict ~= vs_is_dict then
            prev[t] = nil
            return false, "[" .. tostring(k) .. "]" .. " sub-table mismatch."
        end

        if v_is_dict and vs_is_dict then
            local ok, err = matches_validator_with(v, vs, prev)
            if not ok then
                prev[t] = nil
                return false, "[" .. tostring(k) .. "]" .. err
            end
        else
            local ok, err = validator_check(v, vs)
            if not ok then
                prev[t] = nil
                return false, "[" .. tostring(k) .. "]" .. err
            end
        end
    end

    prev[t] = nil
    return true, ""
end

---Inspired by futil-js `matchesSignature`
---
---Compare a |lua-dict| of values with a |lua-dict| schema. Returns `true` if all
---validators pass. Returns `false` with an error `string` if not.
---
---Values from `t` are allowed to be missing. Values from `t` without a corresponding signature
---`s` will cause a failure.
---
---See |vim.validate()| for validation logic.
---@audited 2026-07-03
---@param t table
---@param s table
---@return boolean, string
local function matches_schema_with_run(t, s)
    local ntt = require("nvim-tools.table")
    if ntt.is_dict(t) == 0 then
        return false, "Config values are not a dictionary table."
    end

    if ntt.is_dict(s) < 2 then
        return false, "Schema values are not a dictionary table."
    end

    return matches_validator_with(t, s, {})
end

--------------------
-- MARK: Defaults --
--------------------

local default_config = {
    foo = 1,
    bar = "buzz",
    bazz = { 1, 2, 3, 4 },
    buzz = { "aldrin", "lightyear" },
    fizz = false,
    wow = nil,
    nested = {
        foo = 2,
        bar = "bazzite",
        deeper = {
            baz = "bill",
            fuzz = 4,
            fizz = "buzz",
        },
    },
}

local validators = {
    foo = "number",
    bar = "string",
    bazz = function(v)
        return require("nvim-tools.types").valid_list(v, { item_type = "number" })
    end,
    buzz = function(v)
        return require("nvim-tools.types").valid_list(v, { item_type = "string" })
    end,
    fizz = "boolean",
    wow = { "nil", "string" },
    nested = {
        foo = "number",
        bar = "string",
        deeper = {
            baz = "string",
            fuzz = "number",
            fizz = { "number", "string" },
        },
    },
}

------------------------
-- MARK: Config Class --
------------------------

---@class nvim-tools.ConfigRedux
---@field _config table
---@field _defaults table
local Config = {}

---@generic K, V
---@param self nvim-tools.ConfigRedux
---@param k K
---@return V
Config.__index = function(self, k)
    local _config = rawget(self, "_config")
    local v = rawget(_config, k)
    if v ~= nil then
        return v
    end

    return rawget(Config, k)
end

Config.__newindex = function(_, _, _)
    local msg = "Configs must be modified with setter methods. See help."
    api.nvim_echo({ { msg, "WarningMsg" } }, true, {})
end

---@param self nvim-tools.ConfigRedux
---@param t? table|nil
---@return table
function Config.__call(self, t)
    local _config = rawget(self, "_config")
    local ntt = require("nvim-tools.table")
    if t == nil then
        return ntt.deepcopy(_config)
    end

    local ok, err = matches_schema_with_run(t, validators)
    if not ok then
        api.nvim_echo({ { err, "ErrorMsg" } }, true, {})
        return ntt.deepcopy(_config)
    end

    ntt.merge_deep_right(_config, ntt.deepcopy(t))
    return ntt.deepcopy(_config)
end

---@param self nvim-tools.ConfigRedux
function Config:reset()
    local _defaults = rawget(self, "_defaults")
    rawset(self, "_config", require("nvim-tools.table").deepcopy(_defaults))
end
-- DOC: For normal configs, this goes back to defaults. For buf configs, this is a clear.

---@param keys table
function Config:unset_keys(keys)
    vim.validate("t", keys, "table")

    local _config = rawget(self, "_config")
    local ntt = require("nvim-tools.table")
    ntt.unset_keys(_config, keys)
    local _defaults = rawget(self, "_defaults")
    local defaults_zipped = ntt.zip_deep_with_to(keys, _defaults, function(_, dv)
        return dv
    end)

    ntt.defaults_deep(_config, defaults_zipped)
    return ntt.deepcopy(_config)
end

------------------------
-- MARK: Buf Accessor --
------------------------

---@class nvim-tools.configRedux.BufAccessor
---@field _configs table<uinteger, nvim-tools.ConfigRedux>
local Buf_Config_Accessor = {}

---@generic T
---@param self nvim-tools.configRedux.BufAccessor
---@param k T
---@return any
Buf_Config_Accessor.__index = function(self, k)
    if not require("nvim-tools.types").is_uint(k) then
        return rawget(Buf_Config_Accessor, k)
    end

    k = k == 0 and api.nvim_get_current_buf() or k
    ---@type table<integer, nvim-tools.ConfigRedux>
    local _configs = rawget(self, "_configs")
    if api.nvim_buf_is_valid(k) == false then
        _configs[k] = nil
        api.nvim_echo({ { k .. " is not valid", "WarningMsg" } }, true, {})
        return
    end

    return rawget(_configs, k)
end

Buf_Config_Accessor.__newindex = function(_, _, _)
    local msg = "Buf configs must be modified with setter methods. See help."
    api.nvim_echo({ { msg, "WarningMsg" } }, true, {})
end

---@param buf uinteger
---@return string
local function get_buf_augroup_name(buf)
    return "nvim-tools.buf_config." .. tostring(buf)
end

---@param buf uinteger
---@return boolean
function Buf_Config_Accessor:add(buf)
    vim.validate("buf", buf, require("nvim-tools.types").is_uint)

    ---@type table<uinteger, nvim-tools.ConfigRedux>
    local _configs = rawget(self, "_configs")
    if _configs[buf] ~= nil then
        local msg = "Config for buffer " .. buf .. " already exists."
        api.nvim_echo({ { msg, "WarningMsg" } }, true, {})
        return false
    end

    _configs[buf] = setmetatable({ _config = {}, _defaults = {} }, Config)

    -- Use BufWipeout because unloaded buffers can be reloaded with the same id.
    -- DOC: This behavior.
    api.nvim_create_autocmd("BufWipeout", {
        group = api.nvim_create_augroup(get_buf_augroup_name(buf), {}),
        -- TODO:DEP: Change this to "buf" when v0.14 comes out.
        buffer = buf,
        callback = function()
            _configs[buf] = nil
        end,
    })

    return true
end

---@param self nvim-tools.configRedux.BufAccessor
---@param bufs uinteger[]|nil
function Buf_Config_Accessor:clear(bufs)
    vim.validate("bufs", bufs, function()
        local nty = require("nvim-tools.types")
        return nty.valid_list(bufs, { item_type = "number" })
    end, true)

    local _configs = rawget(self, "_configs") ---@type table<uinteger, nvim-tools.ConfigRedux>
    if bufs == nil then
        for _, buf_config in pairs(_configs) do
            buf_config:reset()
        end

        return
    end

    for _, buf in ipairs(bufs) do
        _configs[buf]:reset()
    end
end

---@param self nvim-tools.configRedux.BufAccessor
---@param bufs uinteger[]|nil
function Buf_Config_Accessor:del(bufs)
    vim.validate("bufs", bufs, function()
        local nty = require("nvim-tools.type")
        return nty.valid_list(bufs, { item_type = "number" })
    end, true)

    local ntt = require("nvim-tools.table")
    local _configs = rawget(self, "_configs") ---@type table<uinteger, nvim-tools.ConfigRedux>
    if bufs == nil then
        ntt.clear(_configs)
        return
    end

    for _, buf in ipairs(bufs) do
        _configs[buf] = nil
    end
end

---@param self nvim-tools.init.config.BufAccessor
---@return integer[]
function Buf_Config_Accessor:list_bufs()
    return require("nvim-tools.table").keys(rawget(self, "_configs"))
end

------------------------
-- MARK: Startup Code --
------------------------

---@param t? table|nil Table of new values to merge in.
---@return table The current or updated config.
---@diagnostic disable-next-line: assign-type-mismatch
function M.config(t)
    local _ = t -- ignore unused
    -- dummy proto for docs
    return {}
end

---@return nvim-tools.ConfigRedux
local function config_create()
    local ntt = require("nvim-tools.table")
    local _config = ntt.deepcopy(default_config)
    local config = { _config = _config, _defaults = default_config }
    return setmetatable(config, Config)
end

M.config = config_create() ---@type nvim-tools.ConfigRedux

---@param buf uinteger Buf config to access.
---@return table The current or updated buf config.
---@diagnostic disable-next-line: assign-type-mismatch
function M.buf_config(buf)
    local _ = buf -- ignore unused
    -- dummy proto for docs
    return {}
end

---@return nvim-tools.configRedux.BufAccessor
local function buf_config_create()
    local buf_config = { _configs = {} }
    return setmetatable(buf_config, Buf_Config_Accessor)
end

M.buf_config = buf_config_create() ---@type nvim-tools.configRedux.BufAccessor

---@param buf uinteger
---@return nvim-tools.ConfigRedux
function M.get_merged_config(buf)
    buf = buf ~= 0 and buf or api.nvim_get_current_buf()
    local ntt = require("nvim-tools.table")
    local config = ntt.deepcopy(rawget(M.config, "_config"))
    -- TODO: how to rawget this
    local buf_config = M.buf_config[buf]
    if buf_config == nil then
        return ntt.deepcopy(config)
    end

    return ntt.merge_deep_right(config, ntt.deepcopy(buf_config))
end

---@param buf uinteger
---@param usr_config table?
---@param ... any
---@return table, string
function M._get_merged_config(buf, usr_config, ...)
    vim.validate("buf", buf, require("nvim-tools.types").is_uint)
    vim.validate("usr_config", usr_config, "table", true)

    buf = buf ~= 0 and buf or api.nvim_get_current_buf()

    local _config = rawget(M.config, "_config") ---@type table
    local ntt = require("nvim-tools.table")
    local config = ntt.deepcopy(ntt.get(_config, ...))
    if config == nil then
        return {}, "Invalid config path."
    end

    ---@type table<uinteger, nvim-tools.ConfigRedux>
    local _configs = rawget(M.buf_config, "_configs")
    local buf_raw = rawget(_configs, buf)
    if buf_raw ~= nil then
        local buf_inner = rawget(buf_raw, "_config")
        local buf_config = ntt.get(buf_inner, ...)
        if buf_config ~= nil then
            ntt.merge_deep_right(config, buf_config)
        end
    end

    if usr_config == nil then
        return config, ""
    end

    local sub_validators = ntt.get(validators, ...)
    if sub_validators == nil then
        return {}, "No validators for path."
    end

    local ok, err = matches_schema_with_run(usr_config, sub_validators)
    if not ok then
        return {}, err
    end

    ntt.merge_deep_right(config, usr_config)
    return config, ""
end

return M

-- TODO: Need better typing for like config types and such
