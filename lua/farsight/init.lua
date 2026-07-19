local api = vim.api

------------------
-- MARK: Schema --
------------------

---@param val any
---@param typ string
---@return boolean
local function string_type_is_valid(val, typ)
    if typ ~= "callable" then
        return type(val) == typ
    end

    if type(val) == "function" then
        return true
    end

    local mt = getmetatable(val)
    return mt ~= nil and type(rawget(mt, "__call")) == "function"
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
            ---@diagnostic disable-next-line: param-type-mismatch
            if string_type_is_valid(v, s[i]) then
                return true, ""
            end
        end

        local err = tostring(v) .. ". Expected " .. vim.inspect(s) .. ". Actual: " .. type(v)
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
    if prev[t] ~= nil then
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

---@param val string
---@return boolean
local function try_regex(val)
    local ok, _ = pcall(vim.regex, val)
    return ok
end

---@param val string
---@return boolean, string
local function fold_cmd_check(val)
    local has = val == "" or val == "zv" or val == "zO" or val == "zx" or val == "zR"
    return has, has and "" or "Invalid unfold cmd"
end

---@class farsight.config.Schema
local schema = {
    default_keymaps_set = "boolean",
    csearch = {
        cancel_keys = function(val)
            local nty = require("nvim-tools.types")
            return nty.valid_list(val, {
                item_type = "string",
                func = function(v)
                    return vim.call("strcharlen", v) == 1
                end,
            })
        end,
        dim = "boolean",
        keepjumps = "boolean",
        on_jump = "callable",
        pattern = try_regex,
        unfold = fold_cmd_check,
    },
    live = {
        dim = "boolean",
        keepjumps = "boolean",
        cmdline_modifier = "callable",
        on_jump = "callable",
        prompt = "string",
        tokens = function(val)
            local nty = require("nvim-tools.types")
            return nty.valid_list(val, {
                item_type = "string",
                func = function(v)
                    return v ~= "\\" and vim.call("strcharlen", v) == 1
                end,
            })
        end,
        unfold = function(val)
            local has = val == "" or val == "zv" or val == "zO" or val == "zx" or val == "zR"
            return has, has and "" or "Invalid unfold cmd"
        end,
    },
    static = {
        dim = "boolean",
        folds = function(val)
            return val == "first" or val == "none"
        end,
        keepjumps = "boolean",
        label_start = "boolean",
        omode_aware = "boolean",
        on_jump = "callable",
        pattern = try_regex,
        tokens = function(val)
            local nty = require("nvim-tools.types")
            return nty.valid_list(val, {
                item_type = "string",
                min_len = 2,
                func = function(v)
                    return vim.call("strcharlen", v) == 1
                end,
            })
        end,
        unfold = fold_cmd_check,
        vmode_aware = "boolean",
    },
}

--------------------
-- MARK: Defaults --
--------------------

---@class farsight.config.Config
local default_config = {
    default_keymaps_set = true, ---@type boolean -- Only checked on startup.
    ---@class farsight.csearch.Ctx
    csearch = {
        cancel_keys = { "\3", "\27", "\r", ";", "," }, ---@type string[]
        dim = true, ---@type boolean
        keepjumps = false, ---@type boolean
        ---@type  fun(win:uinteger, buf:uinteger, pos:[uinteger, uinteger])
        on_jump = function(_, _, _) end,
        pattern = "\\k\\+", ---@type string
        unfold = "zv", ---@type ""|"zv"|"zO"|"zx"|"zR"
    },
    ---@class farsight.live.Ctx
    live = {
        ---Example:
        ---```lua
        ---    -- Search with literals. See `:h |/\M`
        ---    function(cmdline)
        ---        return "\\M" .. cmdline
        ---    end
        ---```
        ---Example:
        ---```lua
        ---    -- Search with smartcase See `:h |/\C`
        ---    function(cmdline)
        ---        if string.find(cmdline, "%u") or string.find(cmdline, "^\\?[cC]") then
        ---            return cmdline
        ---        else
        ---            return "\\c" .. cmdline
        ---        end
        ---    end
        ---```
        ---@type fun(cmdline:string): string
        cmdline_modifier = function(cmdline)
            return cmdline
        end,
        dim = true, ---@type boolean
        keepjumps = false, ---@type boolean
        ---@type fun(win:uinteger, buf:uinteger, pos:[uinteger, uinteger])
        on_jump = function(_, _, _) end,
        prompt = "⬢", ---@type string
        tokens = vim.split("kdjfls;aiemvtnurowghby,c.x/zpq", ""), ---@type string[]
        unfold = "zv", ---@type ""|"zv"|"zO"|"zx"|"zR"
    },
    ---@class farsight.static.Ctx
    static = {
        dim = true, ---@type boolean
        -- If `first` is selected, a target will be placed on the first col of the folded line.
        folds = "first", ---@type "first"|"none"
        keepjumps = false, ---@type boolean
        -- `True` to label the start of the result. `False` to label the end.
        label_start = true, ---@type boolean
        omode_aware = true, ---@type boolean
        ---@type fun(win:uinteger, buf:uinteger, pos:[uinteger, uinteger])
        on_jump = function(_, _, _) end,
        pattern = "\\k\\+", ---@type string
        tokens = vim.split("abcdefghijklmnopqrstuvwxyz;,./", ""), ---@type string[]
        unfold = "zv", ---@type ""|"zv"|"zO"|"zx"|"zR"
        vmode_aware = true, ---@type boolean
    },
}

---@class farsight.csearch.Opts
---@field cancel_keys? string[]
---@field dim? boolean
---@field keepjumps? boolean
---@field on_jump? fun(win:uinteger, buf:uinteger, pos:[uinteger, uinteger])
---@field pattern? string
---@field unfold? ""|"zv"|"zO"|"zx"|"zR"

---@class farsight.live.Opts
---@field cmdline_modifier? fun(cmdline:string): string
---@field dim? boolean
---@field keepjumps? boolean
---@field on_jump? fun(win:uinteger, buf:uinteger, pos:[uinteger, uinteger])
---@field prompt? string
---@field tokens? string[]
---@field unfold? ""|"zv"|"zO"|"zx"|"zR"

---@class farsight.static.Opts
---@field dim? boolean
---@field folds? "first"|"none"
---@field keepjumps? boolean
---@field label_start? boolean
---@field omode_aware? true
---@field on_jump? fun(win:uinteger, buf:uinteger, pos:[uinteger, uinteger])
---@field pattern? string
---@field tokens? string[]
---@field unfold? ""|"zv"|"zO"|"zx"|"zR"
---@field vmode_aware? boolean

---@class farsight.config.Input
---@field default_keymaps_set? boolean
---@field csearch? farsight.csearch.Opts
---@field live? farsight.live.Opts
---@field static? farsight.static.Opts

------------------------
-- MARK: Config Class --
------------------------

local M = {}

---@nodoc
---@class farsight.Config
---@field _config farsight.config.Config
---@field _defaults farsight.config.Schema
local Config = {}

---Store global plugin config.
---
---Get config:
---```lua
---   config()
---```
---```lua
---   config().foo
---```
---
---Set config:
---```lua
---    config({ foo = "bar" })
---```
---@param t farsight.config.Input? Table of new values to merge in.
---@return farsight.config.Config The current or updated config.
---@diagnostic disable-next-line: assign-type-mismatch
function M.config(t)
    local _ = t -- ignore unused
    ---@diagnostic disable-next-line: return-type-mismatch
    -- dummy proto for docs
    return {}
end

---@return farsight.Config
local function config_create()
    local ntt = require("nvim-tools.table")
    local _config = ntt.deepcopy(default_config)
    local config = { _config = _config, _defaults = default_config }
    return setmetatable(config, Config)
end

---@diagnostic disable-next-line: assign-type-mismatch
---@nodoc
M.config = config_create()

---@nodoc
---Alias so lazy.nvim can load with its `opts` key.
M.setup = M.config
--TODO: Test. If this doesn't work then just document that it doesn't.

---@generic K, V
---@param self farsight.Config
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

---@param self farsight.Config
---@param t? farsight.config.Input
---@return farsight.config.Config
function Config.__call(self, t)
    local _config = rawget(self, "_config")
    local ntt = require("nvim-tools.table")
    if t == nil then
        ---@diagnostic disable-next-line: return-type-mismatch
        return ntt.deepcopy(_config)
    end

    local ok, err = matches_schema_with_run(t, schema)
    if not ok then
        api.nvim_echo({ { err, "ErrorMsg" } }, true, {})
        ---@diagnostic disable-next-line: return-type-mismatch
        return ntt.deepcopy(_config)
    end

    ntt.merge_deep_right(_config, ntt.deepcopy(t))
    ---@diagnostic disable-next-line: return-type-mismatch
    return ntt.deepcopy(_config)
end

---Set all config values back to default. This clears buffer-specific configs.
function Config:reset()
    local _defaults = rawget(self, "_defaults")
    rawset(self, "_config", require("nvim-tools.table").deepcopy(_defaults))
end

---Set a key back to its default. This clears buffer config values.
---```lua
---   -- foo = { foo = "bar" } -- Default: "buzz"
---   foo:unset_keys({ foo = true })
---   -- foo - { foo = "buzz" }
---```
---@param keys table
function Config:unset_keys(keys)
    vim.validate("t", keys, "table")

    local _config = rawget(self, "_config")
    local ntt = require("nvim-tools.table")
    ntt.unset_keys(_config, keys)
    local defaults_zipped = ntt.zip_deep_with_to(keys, rawget(self, "_defaults"), function(_, dv)
        return dv
    end)

    ntt.defaults_deep(_config, defaults_zipped)
    return ntt.deepcopy(_config)
end

---@return boolean, string
function Config:validate()
    local _config = rawget(self, "_config")
    return matches_schema_with_run(_config, schema)
end

------------------------
-- MARK: Buf Accessor --
------------------------

---@nodoc
---@class farsight.config.BufAccessor
---@field _configs table<uinteger, farsight.Config>
local Buf_Config_Accessor = {}

---Store buffer-specific configuration. When the plugin accesses config data, buffer-specific
---config will be merged over global config.
---
---```lua
---    buf_config[0] -- Gets config for current buffer. Creates if needed.
---```
---
---Buffer configs are interacted with the same as as the global config.
---
---Configs cannot be created or accessed for invalid buffers. If a buffer is wiped, its config
---will be deleted.
---@param buf uinteger Buffer config to access.
---@return farsight.config.BufAccessor The current or updated buf config.
---@diagnostic disable-next-line: assign-type-mismatch
function M.buf_config(buf)
    local _ = buf -- ignore unused
    -- dummy proto for docs
    ---@diagnostic disable-next-line: return-type-mismatch
    return {}
end

---@return farsight.config.BufAccessor
local function buf_config_create()
    local buf_config = { _configs = {} }
    return setmetatable(buf_config, Buf_Config_Accessor)
end

---@diagnostic disable-next-line: assign-type-mismatch
---@nodoc
M.buf_config = buf_config_create() ---@type farsight.config.BufAccessor

---@param buf uinteger
---@return string
local function get_buf_augroup_name(buf)
    return "nvim-tools.buf_config." .. tostring(buf)
end

---Assumes new buf is valid.
---@side-effect Creates BufWipeout autocmd.
---@param buf uinteger
---@param _configs table<uinteger, farsight.Config> Modified in place!
local function add_buf_to__configs(buf, _configs)
    local buf_config = setmetatable({ _config = {}, _defaults = {} }, Config)
    api.nvim_create_autocmd("BufWipeout", {
        group = api.nvim_create_augroup(get_buf_augroup_name(buf), {}),
        -- TODO-DEP: Change this to "buf" when v0.14 comes out.
        buffer = buf,
        callback = function()
            _configs[buf] = nil
        end,
    })

    _configs[buf] = buf_config
    return buf_config
end

---@generic T
---@param self farsight.config.BufAccessor
---@param k T
---@return any
Buf_Config_Accessor.__index = function(self, k)
    if not require("nvim-tools.types").is_uint(k) then
        return rawget(Buf_Config_Accessor, k)
    end

    k = k ~= 0 and k or api.nvim_get_current_buf()

    ---@type table<integer, farsight.Config>
    local _configs = rawget(self, "_configs")
    ---@diagnostic disable-next-line: param-type-mismatch
    if api.nvim_buf_is_valid(k) == false then
        _configs[k] = nil
        api.nvim_echo({ { k .. " is not valid", "WarningMsg" } }, true, {})
        return
    end

    ---@diagnostic disable-next-line: assign-type-mismatch
    local buf_config = rawget(_configs, k) ---@type farsight.Config
    if buf_config == nil then
        buf_config = add_buf_to__configs(k, _configs)
    end

    return buf_config ---@type table
end

Buf_Config_Accessor.__newindex = function(_, _, _)
    local msg = "Buf configs must be modified with setter methods. See help."
    api.nvim_echo({ { msg, "WarningMsg" } }, true, {})
end

---Add a new config for a buffer. Warns if one already exists. This creates the autocmd to
---remove the config on |BufWipeout|.
---@param buf uinteger
---@return boolean `True` if the new config was created.
function Buf_Config_Accessor:add(buf)
    vim.validate("buf", buf, require("nvim-tools.types").is_uint)

    buf = buf ~= 0 and buf or api.nvim_get_current_buf()
    if api.nvim_buf_is_valid(buf) == false then
        api.nvim_echo({ { buf .. " is not valid", "WarningMsg" } }, true, {})
        return false
    end

    ---@type table<uinteger, farsight.Config>
    local _configs = rawget(self, "_configs")
    if _configs[buf] ~= nil then
        local msg = "Config for buffer " .. buf .. " already exists."
        api.nvim_echo({ { msg, "WarningMsg" } }, true, {})
        return false
    end

    add_buf_to__configs(buf, _configs)
    return true
end

---Clear buffer configs for `bufs`. If `bufs` is `nil`, clear all buffer configs.
---@param bufs uinteger[]|nil
function Buf_Config_Accessor:clear(bufs)
    vim.validate("bufs", bufs, function()
        local nty = require("nvim-tools.types")
        return nty.valid_list(bufs, { item_type = "number" })
    end, true)

    local _configs = rawget(self, "_configs") ---@type table<uinteger, farsight.Config>
    if bufs == nil then
        for _, buf_config in pairs(_configs) do
            buf_config:reset()
        end
    else
        for _, buf in ipairs(bufs) do
            local resolved_buf = buf ~= 0 and buf or api.nvim_get_current_buf()
            local b_cfg = _configs[resolved_buf]
            if b_cfg ~= nil then
                b_cfg:reset()
            end
        end
    end
end

---Delete buffer configs for `bufs`. If `bufs` is `nil`, delete all buffer configs.
---@param bufs uinteger[]|nil
function Buf_Config_Accessor:del(bufs)
    vim.validate("bufs", bufs, function()
        local nty = require("nvim-tools.types")
        return nty.valid_list(bufs, { item_type = "number" })
    end, true)

    local _configs = rawget(self, "_configs") ---@type table<uinteger, farsight.Config>
    if bufs == nil then
        require("nvim-tools.table").clear(_configs)
    else
        for _, buf in ipairs(bufs) do
            local resolved_buf = buf ~= 0 and buf or api.nvim_get_current_buf()
            _configs[resolved_buf] = nil
        end
    end
end

---List buffers with active configs.
---@return integer[]
function Buf_Config_Accessor:list_bufs()
    local keys = require("nvim-tools.table").keys(rawget(self, "_configs"))
    table.sort(keys)
    return keys
end

------------------------
-- MARK: Merging Code --
------------------------

---@param buf uinteger
---@param usr_config table?
---@param ... any
---@return boolean, table, string
function M._get_merged_config(buf, usr_config, ...)
    vim.validate("buf", buf, require("nvim-tools.types").is_uint)
    vim.validate("usr_config", usr_config, "table", true)

    buf = buf ~= 0 and buf or api.nvim_get_current_buf()

    local _config = rawget(M.config, "_config") ---@type table
    local ntt = require("nvim-tools.table")
    local config = ntt.deepcopy(ntt.get(_config, ...))
    if config == nil then
        return false, {}, "Invalid config path."
    end

    ---@type table<uinteger, farsight.Config>
    local _configs = rawget(M.buf_config, "_configs")
    local buf_config_get = rawget(_configs, buf) ---@type farsight.Config
    if buf_config_get ~= nil then
        local _buf_config = rawget(buf_config_get, "_config") ---@type table
        local buf_config = ntt.get(_buf_config, ...)
        if buf_config ~= nil then
            ntt.merge_deep_right(config, buf_config)
        end
    end

    if usr_config == nil then
        return true, config, ""
    end

    local validators = ntt.get(schema, ...)
    if validators == nil then
        return false, {}, "No validators for path."
    end

    local ok, err = matches_schema_with_run(usr_config, validators)
    if not ok then
        return false, {}, err
    end

    ntt.merge_deep_right(config, usr_config)
    return true, config, ""
end

---------------
-- MARK: API --
---------------

---@param opts table?
---@param key string
local function ctx_get(opts, key)
    vim.validate("opts", opts, "table", true)
    opts = opts or {}

    local cur_win = api.nvim_get_current_win()
    local cur_win_buf = api.nvim_win_get_buf(cur_win)
    return cur_win, cur_win_buf, M._get_merged_config(cur_win_buf, opts, key)
end

M.csearch = {}

---@param opts? farsight.csearch.Opts
function M.csearch.fwd(opts)
    local win, win_buf, ok, ctx, err = ctx_get(opts, "csearch")
    if not ok then
        api.nvim_echo({ { err, "ErrorMsg" } }, true, {})
        return
    end

    ---@cast ctx farsight.csearch.Ctx
    require("farsight._csearch").csearch(win, win_buf, vim.v.count1, false, false, ctx)
end

---@param opts? farsight.csearch.Opts
function M.csearch.rev(opts)
    local win, win_buf, ok, ctx, err = ctx_get(opts, "csearch")
    if not ok then
        api.nvim_echo({ { err, "ErrorMsg" } }, true, {})
        return
    end

    ---@cast ctx farsight.csearch.Ctx
    require("farsight._csearch").csearch(win, win_buf, vim.v.count1, true, false, ctx)
end

---@param opts? farsight.csearch.Opts
function M.csearch.fwd_till(opts)
    local win, win_buf, ok, ctx, err = ctx_get(opts, "csearch")
    if not ok then
        api.nvim_echo({ { err, "ErrorMsg" } }, true, {})
        return
    end

    ---@cast ctx farsight.csearch.Ctx
    require("farsight._csearch").csearch(win, win_buf, vim.v.count1, false, true, ctx)
end

---@param opts? farsight.csearch.Opts
function M.csearch.rev_till(opts)
    local win, win_buf, ok, ctx, err = ctx_get(opts, "csearch")
    if not ok then
        api.nvim_echo({ { err, "ErrorMsg" } }, true, {})
        return
    end

    ---@cast ctx farsight.csearch.Ctx
    require("farsight._csearch").csearch(win, win_buf, vim.v.count1, true, true, ctx)
end

function M.csearch.is_in_continuation_mode()
    return require("farsight._csearch").is_in_continuation_mode()
end

M.live = {}

---@param opts? farsight.live.Opts
function M.live.fwd(opts)
    local win, win_buf, ok, ctx, err = ctx_get(opts, "live")
    if not ok then
        api.nvim_echo({ { err, "ErrorMsg" } }, true, {})
        return
    end

    ---@cast ctx farsight.live.Ctx
    require("farsight._live").live(win, win_buf, false, ctx)
end

---@param opts? farsight.live.Opts
function M.live.rev(opts)
    local win, win_buf, ok, ctx, err = ctx_get(opts, "live")
    if not ok then
        api.nvim_echo({ { err, "ErrorMsg" } }, true, {})
        return
    end

    ---@cast ctx farsight.live.Ctx
    require("farsight._live").live(win, win_buf, true, ctx)
end

---@param opts? farsight.static.Opts
function M.static(opts)
    local cur_win, _, ok, ctx, err = ctx_get(opts, "static")
    if not ok then
        api.nvim_echo({ { err, "ErrorMsg" } }, true, {})
        return
    end

    ---@cast ctx farsight.static.Ctx
    require("farsight._static").static(cur_win, ctx)
end

return M
