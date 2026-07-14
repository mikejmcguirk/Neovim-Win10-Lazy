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

local schema = {
    default_keymaps_set = "boolean",
    document_highlight = {
        enabled = "boolean",
        jump_opts = {
            zzze = "boolean",
        },
    },
    lampshade = {
        action_filter = "callable",
        display = "callable",
        debounce = "number",
    },
    rename = {
        filter = "callable",
        new_name = "string",
        prompt_default = "boolean",
    },
}
-- TODO: Noted somewhere else, but we need to be able to handle custom datatypes here.

--------------------
-- MARK: Defaults --
--------------------

---@class catharsis.config.Config
local default_config = {
    default_keymaps_set = true, ---@type boolean -- Only checked on startup.
    ---@class catharsis.cmds.bkill.Ctx
    bkill = {
        confirm = true, ---@type boolean
    },
    ---@class catharsis.cmds.bmove.Ctx
    bmove = {
        confirm = true, ---@type boolean
    },
    ---@class catharsis.documentHighlight.Ctx
    document_highlight = {
        enabled = true, ---@type boolean
        ---@class catharsis.documentHighlight.JumpCtx
        jump_opts = {
            zzze = true, ---@type boolean -- For jumps.
        },
    },
    ---@class catharsis.lampshade.Ctx
    lampshade = {
        ---Predicate function to determine valid actions. Return true to count as valid.
        ---@param client vim.lsp.Client
        ---@param action (lsp.Command|lsp.CodeAction)
        ---@return boolean
        ---@diagnostic disable-next-line: unused-local
        action_filter = function(_, _)
            return true
        end,
        debounce = 150, ---@type uinteger
        ---@param buf uinteger
        ---@param row uinteger 0-indexed
        ---@param ns uinteger
        ---@param hl_id uinteger Id for the "CatharsisLampshade" hl group.
        display = function(buf, row, ns, hl_id)
            api.nvim_buf_set_extmark(buf, ns, row, 0, {
                virt_text = { { "󰌶", hl_id } },
                priority = 1000,
                strict = false,
            })
        end,
    },
    ---@class catharsis.rename.Ctx
    rename = {
        filter = nil, ---@type (fun(client:vim.lsp.Client): boolean)?
        new_name = nil, ---@type string?
        prompt_default = true, ---@type boolean
    },
}
-- LOW: It would be better to calculate lamp debounce from the client fields.
-- PR: Emmylua_Ls display issue here. "hl_id" semantic coloring in the display set extmark
-- statement is mis-aligned. This also shows in the document highlight.

------------------------
-- MARK: Config Class --
------------------------

local M = {}

-- TODO: Can you define this off the defaults with annotations?

---@nodoc
---@class catharsis.Config
---@field _config table
---@field _defaults table
---@field default_keymaps_set boolean
---@field document_highlight catharsis.documentHighlight.Ctx
---@field rename catharsis.rename.Ctx
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
---@param t? table|nil Table of new values to merge in.
---@return catharsis.config.Config The current or updated config.
---@diagnostic disable-next-line: assign-type-mismatch
function M.config(t)
    local _ = t -- ignore unused
    ---@diagnostic disable-next-line: return-type-mismatch
    -- dummy proto for docs
    return {}
end

---@return catharsis.Config
local function config_create()
    local ntt = require("nvim-tools.table")
    local _config = ntt.deepcopy(default_config)
    local config = { _config = _config, _defaults = default_config }
    return setmetatable(config, Config)
end

---@diagnostic disable-next-line: assign-type-mismatch
---@nodoc
M.config = config_create()

---@generic K, V
---@param self catharsis.Config
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

---@param self catharsis.Config
---@param t? table|nil
---@return table
function Config.__call(self, t)
    local _config = rawget(self, "_config")
    local ntt = require("nvim-tools.table")
    if t == nil then
        return ntt.deepcopy(_config)
    end

    local ok, err = matches_schema_with_run(t, schema)
    if not ok then
        api.nvim_echo({ { err, "ErrorMsg" } }, true, {})
        return ntt.deepcopy(_config)
    end

    ntt.merge_deep_right(_config, ntt.deepcopy(t))
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

---@nodoc
---@class catharsis.config.BufAccessor
---@field _configs table<uinteger, catharsis.Config>
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
---@return catharsis.config.BufAccessor The current or updated buf config.
---@diagnostic disable-next-line: assign-type-mismatch
function M.buf_config(buf)
    local _ = buf -- ignore unused
    -- dummy proto for docs
    ---@diagnostic disable-next-line: return-type-mismatch
    return {}
end

---@return catharsis.config.BufAccessor
local function buf_config_create()
    local buf_config = { _configs = {} }
    return setmetatable(buf_config, Buf_Config_Accessor)
end

---@diagnostic disable-next-line: assign-type-mismatch
---@nodoc
M.buf_config = buf_config_create() ---@type catharsis.config.BufAccessor

---@param buf uinteger
---@return string
local function get_buf_augroup_name(buf)
    return "nvim-tools.buf_config." .. tostring(buf)
end

---Assumes new buf is valid.
---@side-effect Creates BufWipeout autocmd.
---@param buf uinteger
---@param _configs table<uinteger, catharsis.Config> Modified in place!
local function add_buf_to__configs(buf, _configs)
    local buf_config = setmetatable({ _config = {}, _defaults = {} }, Config)
    api.nvim_create_autocmd("BufWipeout", {
        group = api.nvim_create_augroup(get_buf_augroup_name(buf), {}),
        -- TODO:DEP: Change this to "buf" when v0.14 comes out.
        buffer = buf,
        callback = function()
            _configs[buf] = nil
        end,
    })

    _configs[buf] = buf_config
    return buf_config
end

---@generic T
---@param self catharsis.config.BufAccessor
---@param k T
---@return any
Buf_Config_Accessor.__index = function(self, k)
    if not require("nvim-tools.types").is_uint(k) then
        return rawget(Buf_Config_Accessor, k)
    end

    k = k ~= 0 and k or api.nvim_get_current_buf()

    ---@type table<integer, catharsis.Config>
    local _configs = rawget(self, "_configs")
    ---@diagnostic disable-next-line: param-type-mismatch
    if api.nvim_buf_is_valid(k) == false then
        _configs[k] = nil
        api.nvim_echo({ { k .. " is not valid", "WarningMsg" } }, true, {})
        return
    end

    ---@diagnostic disable-next-line: assign-type-mismatch
    local buf_config = rawget(_configs, k) ---@type catharsis.Config
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

    ---@type table<uinteger, catharsis.Config>
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

    local _configs = rawget(self, "_configs") ---@type table<uinteger, catharsis.Config>
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

    local _configs = rawget(self, "_configs") ---@type table<uinteger, catharsis.Config>
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
-- MARK: Startup Code --
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

    ---@type table<uinteger, catharsis.Config>
    local _configs = rawget(M.buf_config, "_configs")
    local buf_config_get = rawget(_configs, buf) ---@type catharsis.Config
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

---@inlinedoc
---@class catharsis.rename.Opts
---(Default: `nil`) Predicate to filter clients. Clients matching the predicate are included.
---@field filter? fun(client:vim.lsp.Client): boolean
---(Default: `nil`) If provided, immediately send the rename request.
---@field new_name? string
---(Default: `true`) Provide a default name in the prompt? If true, the LSP suggestion will be
---used if provided, falling back to the |<cword>| under the cursor.
---@field prompt_default? boolean

---Rename all references to the symbol under the cursor. Highlight changed symbols.
---@param opts? catharsis.rename.Opts
function M.rename(opts)
    if opts == nil then
        opts = {}
    else
        vim.validate("opts", opts, "table")
    end

    local cur_win = api.nvim_get_current_win()
    local cur_buf = api.nvim_win_get_buf(cur_win)
    local ok, ctx, err = M._get_merged_config(cur_buf, opts, "rename")
    if not ok then
        error(err)
    end

    require("catharsis._rename")._dispatcher(cur_win, cur_buf, ctx)
end

---@nodoc
M.document_highlight = {}

---@param opts? catharsis.documentHightlight.JumpOpts
---@return uinteger, uinteger, boolean, catharsis.documentHighlight.JumpCtx, string
local function get_jump_ctx(opts)
    vim.validate("opts", opts, "table", true)
    opts = opts or {}

    local win = api.nvim_get_current_win()
    local buf = api.nvim_win_get_buf(win)
    return win, buf, M._get_merged_config(buf, opts, "document_highlight", "jump_opts")
end

---@class catharsis.documentHightlight.JumpOpts
---@field zzze? boolean

---@param opts? catharsis.documentHightlight.JumpOpts
function M.document_highlight.jump_fwd(opts)
    local win, buf, ok, ctx, err = get_jump_ctx(opts)
    if not ok then
        api.nvim_echo({ { err, "ErrorMsg" } }, true, {})
        return
    end

    require("catharsis._document_highlight").jump(win, buf, vim.v.count, false, false, ctx)
end

---@param opts? catharsis.documentHightlight.JumpOpts
function M.document_highlight.jump_rev(opts)
    local win, buf, ok, ctx, err = get_jump_ctx(opts)
    if not ok then
        api.nvim_echo({ { err, "ErrorMsg" } }, true, {})
        return
    end

    require("catharsis._document_highlight").jump(win, buf, vim.v.count, false, true, ctx)
end

---@param opts? catharsis.documentHightlight.JumpOpts
function M.document_highlight.jump_last(opts)
    local win, buf, ok, ctx, err = get_jump_ctx(opts)
    if not ok then
        api.nvim_echo({ { err, "ErrorMsg" } }, true, {})
        return
    end

    require("catharsis._document_highlight").jump(win, buf, vim.v.count, true, false, ctx)
end

---@param opts? catharsis.documentHightlight.JumpOpts
function M.document_highlight.jump_first(opts)
    local win, buf, ok, ctx, err = get_jump_ctx(opts)
    if not ok then
        api.nvim_echo({ { err, "ErrorMsg" } }, true, {})
        return
    end

    require("catharsis._document_highlight").jump(win, buf, vim.v.count, true, true, ctx)
end

-- TODO: You can probably outline most of the jump logic then just individually handle returning
-- on echo and the jump fn args.

return M

-- TODO-DEP: Unless a breaking issue is found, config development should stay centralized in the
-- nvim-tools project. When the time comes to cut this off, re-ingest changes from there.
