local api = vim.api
local fn = vim.fn

local M = {}

---@class nvim-tools.init.Config
---@field _config table
---@field _validators table
---@overload fun(t?: table|nil, ): table?
---@type nvim-tools.init.Config
local Config = {}
-- FUTURE: I'm not sure if this class definition + its functions will or should be pulled by the
-- docgen.

---@generic T
---@param self nvim-tools.init.Config
---@param k T
---@return any
Config.__index = function(self, k)
    local data = rawget(self, "_config")
    local value = rawget(data, k)
    return value and value or rawget(Config, k)
end

---@generic T
---@param validator string|string[]|fun(v:T): boolean
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
---@param self nvim-tools.init.Config
---@param k T
---@param v any
Config.__newindex = function(self, k, v)
    local data = rawget(self, "_config") ---@type table
    local validators = rawget(self, "_validators") ---@type table

    ---@generic T
    local validator = validators[k] ---@type (string|string[]|fun(v:T): boolean)?
    if validator and validate(validator, v) then
        rawset(data, k, v)
    elseif getmetatable(data[k]) == Config and type(v) == "table" then
        data[k](v)
    elseif v == nil and validators._allow_nil then
        rawset(data, k, v) -- Do this after the metatable check to avoid overwriting.
    end
end
-- DOCUMENT: This method is needed to set nils in buf configs.
-- DOCUMENT: For non-config subtables, full replacements are required for validation. Direct
-- editing of those tables is free-form.

---Assumes that t has been validated.
---@param config nvim-tools.init.Config
---@param t table
local function set_config_from_t(config, t)
    local data = rawget(config, "_config")
    local validators = rawget(config, "_validators")
    for k, v in pairs(t) do
        if validators[k] then
            rawset(data, k, v)
        elseif type(v) == "table" and getmetatable(data[k]) == Config then
            set_config_from_t(data[k], v)
        end
    end
end

---Get a copy of config data with the metatable and proxy structure removed.
---@generic T
---@param val T
---@return T
local function get_clean_config(val)
    if type(val) ~= "table" then
        return val
    end

    ---@type table
    local t = getmetatable(val) == Config and rawget(val, "_config") or val
    ---@generic T
    local clean = {} ---@type table<T, T>
    for k, v in pairs(t) do
        clean[k] = get_clean_config(v)
    end

    return clean
end

---@param self nvim-tools.init.Config
---@param t? table|nil
---@return table? clean_config
function Config.__call(self, t)
    vim.validate("t", t, "table", true)

    if t == nil then
        return get_clean_config(self)
    end

    self:validate(t, false) -- Hard error on failure
    set_config_from_t(self, t)
end

---@param self nvim-tools.init.Config
---@return boolean
function Config:has_config()
    local data = rawget(self, "_config")
    if type(data) ~= "table" then
        return false
    end

    for _, v in pairs(data) do
        if type(v) == "table" and getmetatable(v) == Config then
            if v:has_config() then
                return true
            end
        elseif v ~= nil then
            return true
        end
    end

    return false
end
-- DOCUMENT: This function. Use a dummy if needed.

---Outlined to avoid exposing the error table and path implementation details.
---@param config nvim-tools.init.Config
---@param t table|nil
---@param errors string[] Collected list of validation errors
---@param path string The table path being validated within.
---@return string[] errors
local function validate_config(config, t, errors, path)
    local data = rawget(config, "_config") ---@type table
    local validators = rawget(config, "_validators") ---@type table

    local iter_t = t and t or config
    for k, v in pairs(iter_t) do
        local cur_key = (path == "") and tostring(k) or path .. "." .. tostring(k)

        ---@generic T
        ---@type (string|string[]|fun(v:T): boolean)?
        local validator = validators[k]
        if validator then
            if not validate(validator, v) then
                local err = cur_key .. ": validation failed on field " .. tostring(v)
                errors[#errors + 1] = err
            end
        elseif type(v) == "table" and getmetatable(data[k]) == Config then
            errors = validate_config(data[k], v, errors, cur_key)
        elseif t == nil then
            rawset(config, k, nil)
        end
    end

    return errors
end

---@param self nvim-tools.init.Config
---@param t table|nil (default: `nil`) New config to validate. If nil, perform self-validation.
---     If the config is being validated, and an extra value is found, it will be deleted.
---@param return_errors? boolean (default: `true`) Return collected errors upon completion. If
---     `false`, hard error on failure.
---@return string[] errors List of validation errors.
function Config:validate(t, return_errors)
    local errors = validate_config(self, t, {}, "")
    if #errors > 0 and return_errors == false then
        error("Config validation failed:\n" .. table.concat(errors, "\n"), 2)
    end

    return errors
end
-- MID: Interesting point from Mitch Hashimoto - The success case should be fast path. The error
-- case can be allowed to be slow (assuming the success case is distinctly more common, which
-- in this case it would be since the metatable screens writes). So here, we would not collect
-- errors on first pass. If a boolean true returns, we know the config is good and return nil
-- (no allocation). If we get a boolean false, we know we have errors, and can do a re-traversal
-- to collect them.
-- DOCUMENT: This function. Use a dummy if needed.

---@class nvim-tools.init.DefaultConfig
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
-- FUTURE: Use this to test the docgen's ability to pull literals. That will also signify that this
-- table needs to remain un-disturbed.

local reference_validators = {
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

---@param defaults table|nil
---@param validators table
---@param allow_nil boolean
---@return nvim-tools.init.Config
local function create_config(defaults, validators, allow_nil)
    local _validators = { _allow_nil = allow_nil }
    local _config = {}

    for k, validator in pairs(validators) do
        ---Validators must be strings, lists of strings, or functions.
        if type(validator) == "table" and (not vim.islist(validator)) then
            local sub_defaults = type(defaults) == "table" and defaults[k] or nil
            _config[k] = create_config(sub_defaults, validator, allow_nil)
        else
            _validators[k] = validator
            _config[k] = type(defaults) == "table" and defaults[k] or nil
        end
    end

    return setmetatable({ _config = _config, _validators = _validators }, Config)
end
-- LOW: I would like if this were not recursion.

---@param use_defaults boolean
---@param allow_nil boolean
---@return nvim-tools.init.Config
local function get_new_config(use_defaults, allow_nil)
    local defaults = use_defaults and vim.deepcopy(default_config) or nil
    local validators = vim.deepcopy(reference_validators)
    return create_config(defaults, validators, allow_nil)
end

---@tag nvim-tools-config
---@brief Set global configuration options for your plugin.

-- FUTURE: Figure out the max length of the doc lines before hover K wraps them. This issue
-- probably explains a lot of why the Nvim function docs are wrapped so tight. But this is not
-- always the case, which is confusing.
-- NOTE: The function docs here are used by Lua_Ls in addition to docgen.

---@param t? table|nil Table of new values to merge in.
---@return table? clean_config If t is nil, a copy of the config without metatable data is
---     returned.
---@diagnostic disable-next-line: assign-type-mismatch
function M.config(t)
    local _ = t -- ignore unused
    -- dummy proto for docs
end

-- Explicitly document type to resolve after dummy function

M.config = get_new_config(true, false) ---@type nvim-tools.init.Config

---Get a clean copy of the default config.
function M.get_default_config()
    return vim.deepcopy(default_config)
end

--- Set the config back to the default.
function M.reset_config()
    M.config = get_new_config(true, false)
end

---@param buf integer
---@return string
local function get_buf_augroup_name(buf)
    return "nvim-tools-buf-config-" .. tostring(buf)
end

---@param buf integer
local function del_buf_autocmds(buf)
    local group = get_buf_augroup_name(buf)
    if fn.exists("#" .. group) == 1 then
        api.nvim_del_augroup_by_name(group)
    end
end

---@param configs table<integer, nvim-tools.init.Config>
---@param buf integer
---@param err boolean
local function clear_buf_config(configs, buf, err)
    rawset(configs, buf, nil)
    del_buf_autocmds(buf)
    if err then
        error("Invalid buffer id: " .. buf)
    end
end

---@class nvim-tools.init.config.BufAccessor
---@field _configs table<integer, nvim-tools.init.DefaultConfig>
local Buf_Config_Accessor = {}

---@generic T
---@param self nvim-tools.init.config.BufAccessor
---@param k T
---@return any
Buf_Config_Accessor.__index = function(self, k)
    if not require("nvim-tools.types").is_uint(k) then
        return rawget(Buf_Config_Accessor, k)
    end

    k = k == 0 and api.nvim_get_current_buf() or k
    ---@type table<integer, nvim-tools.init.Config>
    local configs = rawget(self, "_configs")
    if not api.nvim_buf_is_valid(k) then
        clear_buf_config(configs, k, true) -- Hard error
    end

    return rawget(configs, k)
end
-- DOCUMENT: Failure on read is the same as vim.b

---@generic T
---@param self nvim-tools.init.config.BufAccessor
---@param k integer
---@param v any
Buf_Config_Accessor.__newindex = function(self, k, v)
    vim.validate("k", k, require("nvim-tools.types").is_uint)
    vim.validate("v", v, "table", true)

    k = k == 0 and api.nvim_get_current_buf() or k
    ---@type table<integer, nvim-tools.init.Config>
    local configs = rawget(self, "_configs")
    if not api.nvim_buf_is_valid(k) then
        clear_buf_config(configs, k, true) -- Hard error
    elseif type(v) == "nil" then
        clear_buf_config(configs, k, false)
        return
    end

    local config = rawget(configs, k) ---@type nvim-tools.init.Config
    local base_config = config and config or get_new_config(false, true)
    base_config(v)
    if config then
        return
    end

    rawset(configs, k, base_config)
    -- Do not use BufDelete because deleted buffers can be reloaded under the same buf id
    api.nvim_create_autocmd("BufWipeout", {
        group = api.nvim_create_augroup(get_buf_augroup_name(k), {}),
        buffer = k,
        callback = function()
            M.buf_config[k] = nil
        end,
    })
end

---@param self nvim-tools.init.config.BufAccessor
---@return integer[]
function Buf_Config_Accessor:list_bufs()
    return require("nvim-tools.table").keys(rawget(self, "_configs"))
end

---Clear buf configs.
---
---Example:
---
---```lua
---     buf_config:clear() -- Clear all empty configs.
---```
---@param self nvim-tools.init.config.BufAccessor
---@param bufs integer[]|nil Buf configs to clear.
---     If bufs is nil, all configs will be cleared.
---     An empty table is a no-op.
---@param force? boolean (default: `false`) If false or nil, only clear configs without values.
---     If true, clear all listed configs.
function Buf_Config_Accessor:clear(bufs, force)
    vim.validate("buf", bufs, function()
        local nty = require("nvim-tools.types")
        return bufs == nil or nty.valid_list(bufs, { item_type = "number" })
    end, true)

    ---@type table<integer, nvim-tools.init.Config>
    local configs = rawget(self, "_configs")
    local ntt = require("nvim-tools.table")
    bufs = bufs or ntt.keys(configs)

    for _, b in ipairs(bufs) do
        local this_buf_config = M.buf_config[b] ---@type nvim-tools.init.Config
        if this_buf_config then
            if force or (not this_buf_config:has_config()) then
                -- Must explicitly use buf_config to pass through its __newindex
                M.buf_config[b] = nil
            end
        end
    end
end
-- DOCUMENT: As noted in this function, in order to nil buf configs, you cannot save the
-- reference to a variable then nil the reference, you must nil through buf_config to utilize
-- its __newindex function

---@type nvim-tools.init.config.BufAccessor
M.buf_config = setmetatable({ _configs = {} }, Buf_Config_Accessor)

M.reset_buf_config = function()
    M.buf_config = setmetatable({ _configs = {} }, Buf_Config_Accessor)
end

---Buf config to merge in. Defaults to current buf.
---@param buf? integer
---@param usr_cfg? nvim-tools.init.DefaultConfig
---Config keys. Gets root config if none are provided. Must resolve to the root config or a
---sub-config table.
---See also |vim.tbl_get()|
---@param ... any
---@return table
function M.get_merged_config(buf, usr_cfg, ...)
    local ntt = require("nvim-tools.types")
    vim.validate("buf", buf, ntt.is_uint, true)
    vim.validate("usr_cfg", usr_cfg, "table", true)

    local has_keys = select("#", ...) > 0
    local nta = require("nvim-tools.table")
    local cfg = has_keys and nta.get(M.config, ...) or M.config
    if (not cfg) or getmetatable(cfg) ~= Config then
        local keys_str = nta.keys_to_str(...)
        error(string.format("Invalid config path: '%s'", keys_str), 2)
    end

    if usr_cfg then
        cfg:validate(usr_cfg, false) -- hard error on invalid user config
    end

    buf = (buf and buf ~= 0) and buf or api.nvim_get_current_buf()
    local this_buf_config = M.buf_config[buf] ---@type nvim-tools.init.Config
    ---@type nvim-tools.init.Config?
    local buf_cfg = (this_buf_config and has_keys) and nta.get(this_buf_config, ...) or nil
    if buf_cfg and getmetatable(buf_cfg) ~= Config then
        local keys_str = nta.keys_to_str(...)
        error(string.format("Invalid buf config path for buffer %d: '%s'", buf, keys_str), 2)
    end

    local clean_cfg = get_clean_config(cfg)
    if buf_cfg then
        vim.tbl_deep_extend("force", clean_cfg, get_clean_config(buf_cfg))
    end

    if usr_cfg then
        vim.tbl_deep_extend("force", clean_cfg, usr_cfg)
    end

    return clean_cfg
end
-- META: Keep keys as the last arg so it's easier to turn into an arg list.
-- MID: Keys could be an argslist like table.get().
-- LOW: Is it possible for the return type to be more specific?
-- MAYBE: Allow skipping validation. Depends on perf cost
-- NON: Don't allow skipping buf_config. I feel like that turns using this function into a
-- free-for-all. Any scenario where that option might be used feels like a case where a more
-- fundamental design issue needs resolved.

return M
