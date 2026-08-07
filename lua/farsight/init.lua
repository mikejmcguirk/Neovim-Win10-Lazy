local api = vim.api
-- TODO: When cutting this plugin off, inline any functions that are only used here. We want to
-- require as few exterior modules as possible for plugin init. Exterior util functions should be
-- consolidated into as few modules as is reasonable.
local ntt = require("nvim-tools.table")

---------------------
-- MARK: Functions --
---------------------

local M = {}

---@param expected string
---@param actual any
---@return string
local function validator_err_make(expected, actual)
    return "Expected " .. expected .. ", found " .. type(actual)
end

---@param val any
---@param typ string
---@return boolean, string
local function string_type_is_valid(val, typ)
    if typ ~= "callable" then
        local ok = type(val) == typ
        return ok, ok and "" or validator_err_make(typ, val)
    end

    if type(val) == "function" then
        return true, ""
    end

    local mt = getmetatable(val)
    local ok = mt ~= nil and type(rawget(mt, "__call")) == "function"
    return ok, ok and "" or "Not a callable metatable"
end

---@param val any
---@param validator string|string[]|fun(val:any): boolean, string
---@return boolean, string
local function validator_check(val, validator)
    if type(validator) == "string" then
        return string_type_is_valid(val, validator)
    end

    if vim.islist(validator) then
        for i = 1, #validator do
            ---@diagnostic disable-next-line: param-type-mismatch
            if string_type_is_valid(val, validator[i]) then
                return true, ""
            end
        end

        return false, validator_err_make(vim.inspect(validator), val)
    end

    if type(validator) == "function" then
        return validator(val)
    end

    return false, "Invalid validator for " .. tostring(val)
end

---@param t table
---@param s table
---@param prev table<table, true>
---@return boolean, string
local function matches_schema_checked(t, s, prev)
    if prev[t] ~= nil then
        return false, "Cyclic reference detected in values."
    end

    prev[t] = true
    for k, v in pairs(t) do
        local vs = s[k]
        if vs == nil then
            prev[t] = nil
            return false, "[" .. tostring(k) .. "]" .. " has no validator."
        end

        local v_is_dict = ntt.is_dict(v) == 2
        local vs_is_dict = ntt.is_dict(vs) == 2
        if (not v_is_dict) and not vs_is_dict then
            local ok, err = validator_check(v, vs)
            if not ok then
                prev[t] = nil
                return false, "[" .. tostring(k) .. "]" .. err
            end
        elseif v_is_dict and vs_is_dict then
            local ok, err = matches_schema_checked(v, vs, prev)
            if not ok then
                prev[t] = nil
                return false, "[" .. tostring(k) .. "]" .. err
            end
        else
            prev[t] = nil
            return false, "[" .. tostring(k) .. "]" .. " sub-table mismatch."
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
local function matches_schema(t, s)
    if ntt.is_dict(t) == 0 then
        return false, "Config values are not a dictionary table."
    end

    if ntt.is_dict(s) < 2 then
        return false, "Schema values are not a dictionary table."
    end

    return matches_schema_checked(t, s, {})
end

---------------------------
-- MARK: Defaults/Schema --
---------------------------

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

---@class farsight.Config
local default_config = {
    default_keymaps_set = true, ---@type boolean -- Only checked on startup.
    ---@class farsight.csearch.Cfg
    csearch = {
        -- `cancel_keys` is compared against the `typed` param from |vim.on_key()| after being
        -- run through |keytrans()|. Cancel keys will stop continuation mode in any mode other
        -- than cmd mode.
        -- `<Esc>`/`<C-C>` will always exit continuation mode from any mode other than normal,
        -- visual, and cmd mode.
        cancel_keys = { "<CR>", ";", "," }, ---@type string[]
        dim = true, ---@type boolean
        keepjumps = false, ---@type boolean
        ---@type  fun(win:uinteger, buf:uinteger, pos:[uinteger, uinteger])
        on_jump = function(_, _, _) end,
        pattern = "\\k\\+", ---@type string
        unfold = "zv", ---@type ""|"zv"|"zO"|"zx"|"zR"
    },
    ---@class farsight.live.Cfg
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
    ---@class farsight.static.Cfg
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

---@return boolean, string
function M.__default_schema_check()
    return matches_schema(default_config, schema)
end

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

---@class farsight.config.Partial
---@field default_keymaps_set? boolean
---@field csearch? farsight.csearch.Opts
---@field live? farsight.live.Opts
---@field static? farsight.static.Opts

------------------
-- MARK: Config --
------------------

local config = ntt.deepcopy(default_config)
---@cast config qf-herder.Config

---@param new_config? qf-herder.config.Partial
---@return qf-herder.Config
function M.config(new_config)
    if new_config == nil then
        ---@diagnostic disable-next-line: return-type-mismatch
        return ntt.deepcopy(config)
    end

    local ok, err = matches_schema(new_config, schema)
    if not ok then
        if vim.v.vim_did_enter == 1 then
            error(err)
        end

        api.nvim_echo({ { err, "ErrorMsg" } }, true, {})
        ---@diagnostic disable-next-line: return-type-mismatch
        return ntt.deepcopy(config)
    end

    ntt.merge_deep_right(config, new_config)
    ---@diagnostic disable-next-line: return-type-mismatch
    return ntt.deepcopy(config)
end

function M.config_reset()
    ---@diagnostic disable-next-line: assign-type-mismatch
    config = ntt.deepcopy(default_config)
end

---@param keys table
---@return qf-herder.Config
function M.unset_keys(keys)
    vim.validate("keys", keys, "table")

    ntt.unset_keys(config, keys)
    local defaults_zipped = ntt.zip_deep_with_to(keys, default_config, function(_, dv)
        return dv
    end)

    ntt.defaults_deep(config, defaults_zipped)
    ---@diagnostic disable-next-line: return-type-mismatch
    return ntt.deepcopy(config)
end

function M._config_get()
    return config
end

----------------------
-- MARK: Buf Config --
----------------------

local buf_configs = {} ---@type table<uinteger, qf-herder.config.Partial>

local function get_buf_augroup_name(buf)
    return "qf-herder.buf_config." .. tostring(buf)
end

---@param buf uinteger
---@return qf-herder.config.Partial
local function buf_config_add(buf)
    api.nvim_create_autocmd("BufWipeout", {
        group = api.nvim_create_augroup(get_buf_augroup_name(buf), {}),
        -- TODO-DEP: Change this to "buf" when v0.14 comes out.
        buffer = buf,
        callback = function()
            buf_configs[buf] = nil
        end,
    })

    local buf_config = {}
    buf_configs[buf] = buf_config
    return buf_config
end

---@param buf uinteger
---@return qf-herder.config.Partial
local function buf_configs_get(buf)
    local buf_config = buf_configs[buf]
    if buf_config == nil then
        buf_config = buf_config_add(buf)
    end

    return buf_config
end

---@param new_config qf-herder.config.Partial?
---@param buf? uinteger
---@return qf-herder.config.Partial
function M.buf_config(new_config, buf)
    vim.validate("buf", buf, require("nvim-tools.types").is_uint, true)
    buf = (buf ~= nil and buf ~= 0) and buf or api.nvim_get_current_buf()
    if not api.nvim_buf_is_valid(buf) then
        buf_configs[buf] = nil
        error(buf .. " is not valid")
    end

    local buf_config = buf_configs_get(buf)
    if new_config == nil then
        ---@diagnostic disable-next-line: return-type-mismatch
        return ntt.deepcopy(buf_config)
    end

    local ok, err = matches_schema(new_config, schema)
    if not ok then
        api.nvim_echo({ { err, "ErrorMsg" } }, true, {})
        ---@diagnostic disable-next-line: return-type-mismatch
    else
        ntt.merge_deep_right(buf_config, new_config)
    end

    ---@diagnostic disable-next-line: return-type-mismatch
    return ntt.deepcopy(buf_config)
end

---@param bufs uinteger[]|nil
function M.buf_config_clear(bufs)
    vim.validate("bufs", bufs, function()
        local nty = require("nvim-tools.types")
        return nty.valid_list(bufs, { item_type = "number" })
    end, true)

    if bufs == nil then
        for _, cfg in pairs(buf_configs) do
            ntt.clear(cfg)
        end

        return
    end

    for _, buf in ipairs(bufs) do
        local buf_config = buf_configs[buf]
        if buf_config ~= nil then
            ntt.clear(buf_config)
        end
    end
end

---@return uinteger[]
function M.buf_config_list_bufs()
    local keys = ntt.keys(buf_configs)
    table.sort(keys)
    return keys
end

-----------------------
-- MARK: API Helpers --
-----------------------

---@param buf uinteger
---@param usr_config table?
---@param ... any
---@return table
function M._config_merged_get(buf, usr_config, ...)
    local cfg = ntt.deepcopy(ntt.get(config, ...))
    if cfg == nil then
        error("Invalid config path")
    end

    buf = buf ~= 0 and buf or api.nvim_get_current_buf()
    local buf_config = buf_configs[buf]
    if buf_config ~= nil then
        local buf_cfg = ntt.get(buf_config, ...)
        if buf_cfg ~= nil then
            ntt.merge_deep_right(cfg, buf_cfg)
        end
    end

    if usr_config == nil then
        return cfg
    end

    local sub_schema = ntt.get(schema, ...)
    local ok, err = matches_schema(usr_config, sub_schema)
    if not ok then
        error(err)
    end

    ntt.merge_deep_right(cfg, usr_config)
    return cfg
end

---@param win uinteger
---@param ... any
---@return uinteger, uinteger, table
function M._config_merged_from_win(win, ...)
    win = win ~= 0 and win or api.nvim_get_current_win()
    local buf = api.nvim_win_get_buf(win)
    return win, buf, M._config_merged_get(buf, nil, ...)
end

---------------
-- MARK: API --
---------------

---@param opts table?
---@param key string
---@return uinteger, uinteger, table
local function cfg_get_from_opts(opts, key)
    vim.validate("opts", opts, "table", true)
    opts = opts or {}

    local win = api.nvim_get_current_win()
    local buf = api.nvim_win_get_buf(win)
    return win, buf, M._config_merged_get(buf, opts, key)
end

M.csearch = {}

---@param opts? farsight.csearch.Opts
function M.csearch.fwd(opts)
    local win, win_buf, cfg = cfg_get_from_opts(opts, "csearch")
    require("farsight._csearch").csearch(win, win_buf, vim.v.count1, false, false, cfg)
end

---@param opts? farsight.csearch.Opts
function M.csearch.rev(opts)
    local win, win_buf, cfg = cfg_get_from_opts(opts, "csearch")
    require("farsight._csearch").csearch(win, win_buf, vim.v.count1, true, false, cfg)
end

---@param opts? farsight.csearch.Opts
function M.csearch.fwd_till(opts)
    local win, win_buf, cfg = cfg_get_from_opts(opts, "csearch")
    require("farsight._csearch").csearch(win, win_buf, vim.v.count1, false, true, cfg)
end

---@param opts? farsight.csearch.Opts
function M.csearch.rev_till(opts)
    local win, win_buf, cfg = cfg_get_from_opts(opts, "csearch")
    require("farsight._csearch").csearch(win, win_buf, vim.v.count1, true, true, cfg)
end

function M.csearch.is_in_continuation_mode()
    return require("farsight._csearch").is_in_continuation_mode()
end

M.live = {}

---@param opts? farsight.live.Opts
function M.live.fwd(opts)
    local win, win_buf, cfg = cfg_get_from_opts(opts, "live")
    require("farsight._live").live(win, win_buf, false, cfg)
end

---@param opts? farsight.live.Opts
function M.live.rev(opts)
    local win, win_buf, cfg = cfg_get_from_opts(opts, "live")
    require("farsight._live").live(win, win_buf, true, cfg)
end

---@param opts? farsight.static.Opts
function M.static(opts)
    local win, _, cfg = cfg_get_from_opts(opts, "static")
    require("farsight._static").static(win, cfg)
end

return M
