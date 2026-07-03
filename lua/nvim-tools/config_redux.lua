-- Ideally, config would live in vim.g, and the `/plugin` file should be used to load
-- all config to metatables without performing a require. But, as of 2026-07-02, Nvim's
-- global var tables do not store metatable information. While using `vim.g` is _possible_,
-- it creates poor ergonomics for the user.
--
-- To prevent unnecessary requires during startup, all config code should be centralized here.

local api = vim.api

local M = {}

--------------------------
-- MARK: Dict Functions --
--------------------------

---@param t any
---@return boolean
local function is_dict(t)
    if type(t) ~= "table" then
        return false
    end

    local t_len = #t
    for k in pairs(t) do
        if type(k) ~= "number" or k < 1 or k > t_len or k ~= math.floor(k) then
            return true
        end
    end

    return false
end

---@param val any
---@param typ string
---@return boolean
local function string_type_is_valid(val, typ)
    if typ == "callable" then
        if type(val) == "function" then
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

    local val_type = type(val)
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
        local err = ok and "" or tostring(v) .. ". Expected " .. type(v) .. ". Actual: " .. s
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
---@param prev_t table<table, true>
---@param prev_s table<table, true>
---@return boolean, string
local function matches_validator_with(t, s, prev_t, prev_s)
    if prev_t[t] then
        return false, "Cyclic reference found in values."
    end

    if prev_s[s] then
        return false, "Cyclic reference found in validators."
    end

    prev_t[t] = true
    prev_s[s] = true
    for k, v in pairs(t) do
        local vs = s[k]
        if vs == nil then
            prev_t[t] = nil
            prev_s[s] = nil
            return false, "[" .. tostring(k) .. "]" .. " has no validator."
        end

        if is_dict(v) and is_dict(vs) then
            local ok, err = matches_validator_with(v, vs, prev_t, prev_s)
            if not ok then
                prev_t[t] = nil
                prev_s[s] = nil
                return false, "[" .. tostring(k) .. "]" .. err
            end
        end

        local ok, err = validator_check(v, vs)
        if ok == false then
            prev_t[t] = nil
            prev_s[s] = nil
            return false, "[" .. tostring(k) .. "]" .. err
        end
    end

    prev_t[t] = nil
    prev_s[s] = nil
    return true, ""
end

---Inspired by futil-js `matchesSignature`
---
---Compare a |lua-dict| of values with a |lua-dict| of validators. Returns `true` if all
---validators pass. Returns `false` with an error `string` if not.
---
---Values from `t` are allowed to be missing. Values from `t` without a corresponding signature
---`s` will cause a failure.
---
---See |vim.validate()| for validation logic.
---@param t table
---@param s table
---@return boolean, string
local function matches_schema_with_run(t, s)
    if is_dict(t) == false then
        return false, "Value table is not a dict."
    end

    if is_dict(s) == false then
        return false, "Schema table is not a dict."
    end

    return matches_validator_with(t, s, {}, {})
end

---@generic T
---@param t T
---@param prev table<T, true>
---@return any
local function deepcopy(t, prev)
    local t_type = type(t)
    if t_type == "userdata" or t_type == "thread" then
        return
    end

    if t_type ~= "table" then
        return t
    end

    if prev[t] == true then
        return
    end

    prev[t] = true

    local copy = {}
    for k, v in pairs(t) do
        local dk = deepcopy(k, prev)
        if dk ~= nil then
            local dv = deepcopy(v, prev)
            if dv ~= nil then
                copy[dk] = dv
            end
        end
    end

    prev[t] = nil
    return copy
end

---@generic K, V
---@param t table<K, V>
---@return table<K, V>
local function deepcopy_run(t)
    return deepcopy(t, {})
end
-- Used here because of safer cyclic redundancy handling.

---@generic K, V
---@param t table<K, V> Modified in place!
---@param keys table<K, true|table>
---@param prev table<table, true>
local function unset_keys(t, keys, prev)
    if prev[keys] == true then
        return
    end

    prev[keys] = true

    for k, v in pairs(keys) do
        local v_type = type(v)
        if v_type == "boolean" then
            if v == true then
                t[k] = nil
            end
        end

        if v_type == "table" then
            local tv = t[k]
            if M.is_dict(tv) then
                unset_keys(tv, v, prev)
            end
        end
    end

    prev[keys] = nil
end

---For each `true` value in `keys`, set the accompanying key/value pair in `t` to `nil`.
---Sub-tables in `keys` will be skipped if they are not |lua-dict|s.
---@generic K, V
---@param t table<K, V> Modified in place!
---@param keys table<K, true|table>
---@return table<K, V> Reference to `t`.
local function unset_keys_run(t, keys)
    unset_keys(t, keys, {})
    return t
end

--------------------
-- MARK: Defaults --
--------------------

-- TODO: For something like rename LSP name, we would want to have that in buf config so you
-- can use an autocmd to assign an LSP name per buffer, but we would not want that in
-- global config. So for the validators, you would want the "nil" type along with "string" to
-- specify that it's optional. And then the default should be nil (type it explicitly for
-- documentation, but it won't write to the table). So like I'm not exactly sure how the
-- interfaces shake out but they need to recognize that unless rename LSP name is explicitly
-- set by the user, we don't want to impose it.

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
    return v and v or rawget(Config, k)
end

Config.__newindex = function(_, _, _) end
-- TODO: This needs to tell the user something informative.

---@param self nvim-tools.ConfigRedux
---@param t? table|nil
---@return table
function Config.__call(self, t)
    local _config = rawget(self, "_config")
    if t == nil then
        return deepcopy_run(_config)
    end

    local ok, err = matches_schema_with_run(t, validators)
    if not ok then
        api.nvim_echo({ { err, "ErrorMsg" } }, true, {})
        return deepcopy_run(_config)
    end

    local t_copy = deepcopy_run(t)
    vim.tbl_deep_extend("force", _config, t_copy)
    return deepcopy_run(_config)
end

---@param self nvim-tools.ConfigRedux
function Config:defaults_get()
    return deepcopy_run(rawget(self, "_defaults"))
end

---@param self nvim-tools.ConfigRedux
function Config:defaults_set()
    rawset(self, "_config", deepcopy_run(rawget(self, "_defaults")))
end

---@param t table
function Config:unset_keys(t)
    vim.validate("t", t, "table")

    local _config = rawget(self, "_config")
    unset_keys_run(_config, t)
    local defaults_copy = deepcopy_run(rawget(self, "_defaults"))
    vim.tbl_deep_extend("keep", _config, defaults_copy)

    return deepcopy_run(_config)
end
-- MID: Slow/hacky to re-copy and re-assign the entire defaults. Should use `t` to filter for
-- needed keys.

---@param t? table|nil Table of new values to merge in.
---@return table The current or updated config.
function M.config(t)
    local _ = t -- ignore unused
    -- dummy proto for docs
    return {}
end

local function config_create()
    local _config = deepcopy_run(default_config)
    local config = { _config = _config, _defaults = deepcopy_run(_config) }
    M.config = setmetatable(config, Config)
end

config_create()

function M.config_reset()
    config_create()
end

return M
