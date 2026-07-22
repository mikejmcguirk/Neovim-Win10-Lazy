local api = vim.api
-- TODO: When cutting this plugin off, inline any functions that are only used here. We want to
-- require as few exterior modules as possible for plugin init. Exterior util functions should be
-- consolidated into as few modules as is reasonable.
local ntt = require("nvim-tools.table")

---------------------
-- MARK: Functions --
---------------------

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

---@param val any
---@return boolean, string
local function is_lower_string(val)
    local ok = type(val) == "string" and val == string.lower(val)
    return ok, ok and "" or validator_err_make("string", val)
end

---@class qf-herder.config.Schema
local schema = {
    auto_open_changes = "boolean",
    default_cmds_set = "boolean",
    default_keymaps_set = "boolean",
    keymap = {
        key_diags = is_lower_string,
        key_filename = is_lower_string,
        prefix_ll = is_lower_string,
        prefix_qf = is_lower_string,
        sort_key = "string",
        stack_clear = is_lower_string,
        stack_newer = "string",
        stack_older = "string",
        win_close = "string",
        win_open = is_lower_string,
    },
    stack = {
        update_list_wins = "boolean",
        spk = function(val)
            local spk = { "", "cursor", "screen", "topline" }
            local ok = ntt.i_includes(spk, val)
            return ok, ok and "" or validator_err_make(vim.inspect(spk), val)
        end,
    },
    sort = {
        goto_after = "boolean",
    },
    window = {
        auto_height = "boolean",
        ll_split = function(val)
            local ll_splits = {
                "abo",
                "aboveleft",
                "bel",
                "belowright",
                "lefta",
                "leftabove",
                "rightb",
                "rightbelow",
            }

            local ok = ntt.i_includes(ll_splits, val)
            return ok, ok and "" or validator_err_make(vim.inspect(ll_splits), val)
        end,
        -- TODO: These should be split_qf and split_ll
        qf_split = function(val)
            local qf_splits = {
                "bo",
                "botright",
                "to",
                "topleft",
            }

            local ok = ntt.i_includes(qf_splits, val)
            return ok, ok and "" or validator_err_make(vim.inspect(qf_splits), val)
        end,
        silent = "boolean",
        spk = function(val)
            local spk = { "", "cursor", "screen", "topline" }
            local ok = ntt.i_includes(spk, val)
            return ok, ok and "" or validator_err_make(vim.inspect(spk), val)
        end,
    },
}

---@alias qf-herder.window.llSplit "abo"|"aboveleft"|"bel"|"belowright"|"lefta"|"leftabove"|"rightb"|"rightbelow"

---@alias qf-herder.window.qfSplit "bo"|"botright"|"to"|"topleft"

---@class qf-herder.Config
local default_config = {
    default_cmds_set = true, ---@type boolean -- Only checked on startup.
    default_keymaps_set = true, ---@type boolean -- Only checked on startup.
    -- Only checked on startup
    ---@class qf-herder.keymap.Cfg
    keymap = {
        key_diags = "i", ---@type string -- Must be lowercase
        key_filename = "f", ---@type string -- Must be lowercase
        prefix_ll = "<leader>l", ---@type string -- Must be lowercase
        prefix_qf = "<leader>q", ---@type string -- Must be lowercase
        sort_key = "t", ---@type string
        stack_clear = "e", ---@type string
        stack_newer = "]", ---@type string
        stack_older = "[", ---@type string
        win_close = "o", ---@type string
        win_open = "p", ---@type string
    },
    ---@class qf-herder.sort.Cfg
    sort = {
        -- TODO: history_after?
        goto_after = true, ---@type boolean
    },
    ---@class qf-herder.stack.Cfg
    stack = {
        spk = "topline", ---@type ""|"cursor"|"screen"|"topline"
        -- Resizes the list after running history cmds. Closes the list if the stack is freed.
        update_list_wins = true, ---@type boolean
    },
    ---@class qf-herder.window.Cfg
    window = {
        auto_height = true, ---@type boolean
        ll_split = "belowright", ---@type qf-herder.window.llSplit
        qf_split = "botright", ---@type qf-herder.window.qfSplit
        -- TODO: Remove this as a Cfg option
        silent = false, ---@type boolean
        spk = "topline", ---@type ""|"cursor"|"screen"|"topline"
    },
}

---@class qf-herder.keymap.cfg.Partial
---@field ll_prefix? string
---@field qf_prefix? string
---@field win_close? string
---@field win_open? string

---@class qf-herder.sort.cfg.Partial
---@field goto_after? boolean

---@class qf-herder.stack.cfg.Partial
---@field autosize_changes? boolean
---@field spk? ""|"cursor"|"screen"|"topline"

---@class qf-herder.window.cfg.Partial
---@field auto_height? boolean
---@field ll_split? qf-herder.window.llSplit
---@field qf_split? qf-herder.window.qfSplit
---@field silent? boolean
---@field spk? ""|"cursor"|"screen"|"topline"

---@class qf-herder.config.Partial
---@field default_cmds_set? boolean
---@field default_keymaps_set? boolean
---@field ll_map_prefix? string
---@field qf_map_prefix? string
---@field window? qf-herder.window.cfg.Partial

------------------
-- MARK: Config --
------------------

local config = ntt.deepcopy(default_config)
---@cast config qf-herder.Config

local M = {}

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

-- TODO: Add an unset def that just has boolean values for everything.

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
local function config_merged_get(buf, usr_config, ...)
    buf = buf ~= 0 and buf or api.nvim_get_current_buf()

    local cfg = ntt.deepcopy(ntt.get(config, ...))
    if cfg == nil then
        error("Invalid config path")
    end

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

---@nodoc
---@param ... any
---@return uinteger, uinteger, table
function M._config_merged_from_win(win, ...)
    win = win ~= 0 and win or api.nvim_get_current_win()
    local buf = api.nvim_win_get_buf(win)
    return win, buf, config_merged_get(buf, nil, ...)
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
    return win, buf, config_merged_get(buf, opts, key)
end

M.window = {}

---@class qf-herder.window.qfOpen.Opts
---@field auto_height? boolean
---@field qf_split? qf-herder.window.qfSplit
---@field spk? "cursor"|"screen"|"topline"|""

---@param opts? qf-herder.window.qfOpen.Opts
function M.window.qf_open(opts)
    local _, _, ctx = cfg_get_from_opts(opts, "window")
    require("qf-herder._window").qf_open(vim.v.count, ctx)
end

---@class qf-herder.window.qfClose.Opts
---@field spk? "cursor"|"screen"|"topline"|""

---@param opts? qf-herder.window.qfClose.Opts
function M.window.qf_close(opts)
    local _, _, ctx = cfg_get_from_opts(opts, "window")
    require("qf-herder._window").qf_close({ 0 }, ctx)
end

---@class qf-herder.window.qfToggle.Opts
---@field auto_height? boolean
---@field qf_split? qf-herder.window.qfSplit
---@field spk? "cursor"|"screen"|"topline"|""

---@param opts? qf-herder.window.qfToggle.Opts
function M.window.qf_toggle(opts)
    local _, _, ctx = cfg_get_from_opts(opts, "window")
    require("qf-herder._window").qf_toggle(vim.v.count, ctx)
end

---@class qf-herder.window.qfResize.Opts
---@field spk? "cursor"|"screen"|"topline"|""

---@param opts? qf-herder.window.qfResize.Opts
function M.window.qf_resize(opts)
    local _, _, ctx = cfg_get_from_opts(opts, "window")
    require("qf-herder._window").qf_resize(0, vim.v.count, ctx)
end

---@class qf-herder.window.llOpen.Opts
---@field auto_height? boolean
---@field ll_split? qf-herder.window.llSplit
---@field silent? boolean
---@field spk? "cursor"|"screen"|"topline"|""

---@param opts? qf-herder.window.llOpen.Opts
function M.window.ll_open(opts)
    local _, _, ctx = cfg_get_from_opts(opts, "window")
    require("qf-herder._window").ll_open(vim.v.count, ctx)
end

---@class qf-herder.window.llClose.Opts
---@field silent? boolean
---@field spk? "cursor"|"screen"|"topline"|""

---@param opts? qf-herder.window.llClose.Opts
function M.window.ll_close(opts)
    local _, _, ctx = cfg_get_from_opts(opts, "window")
    require("qf-herder._window").ll_close(api.nvim_get_current_win(), ctx)
end

---@class qf-herder.window.llToggle.Opts
---@field auto_height? boolean
---@field ll_split? qf-herder.window.llSplit
---@field silent? boolean
---@field spk? "cursor"|"screen"|"topline"|""

---@param opts? qf-herder.window.llToggle.Opts
function M.window.ll_toggle(opts)
    local _, _, ctx = cfg_get_from_opts(opts, "window")
    require("qf-herder._window").ll_toggle(vim.v.count, ctx)
end

---@class qf-herder.window.llResize.Opts
---@field silent? boolean
---@field spk? "cursor"|"screen"|"topline"|""

---@param opts? qf-herder.window.llResize.Opts
function M.window.ll_resize(opts)
    local _, _, ctx = cfg_get_from_opts(opts, "window")
    require("qf-herder._window").ll_resize(0, vim.v.count, ctx)
end

M.sort = {}

---@class qf-herder.sort.Opts
---@field goto_after? boolean

---@param opts? qf-herder.sort.Opts
function M.sort.qf_fname_asc(opts)
    local _, _, cfg = cfg_get_from_opts(opts, "sort")
    local qfr_sort = require("qf-herder._sort")
    qfr_sort.sort(nil, vim.v.count, qfr_sort.fname_asc, cfg)
end

---@param opts? qf-herder.sort.Opts
function M.sort.qf_fname_desc(opts)
    local _, _, cfg = cfg_get_from_opts(opts, "sort")
    local qfr_sort = require("qf-herder._sort")
    qfr_sort.sort(nil, vim.v.count, qfr_sort.fname_desc, cfg)
end

---@param opts? qf-herder.sort.Opts
function M.sort.qf_severity_asc(opts)
    local _, _, cfg = cfg_get_from_opts(opts, "sort")
    local qfr_sort = require("qf-herder._sort")
    qfr_sort.sort(nil, vim.v.count, qfr_sort.severity_asc, cfg)
end

---@param opts? qf-herder.sort.Opts
function M.sort.qf_severity_desc(opts)
    local _, _, cfg = cfg_get_from_opts(opts, "sort")
    local qfr_sort = require("qf-herder._sort")
    qfr_sort.sort(nil, vim.v.count, qfr_sort.severity_desc, cfg)
end

---@param f fun(a:vim.quickfix.entry, b:vim.quickfix.entry): boolean
---@param opts? qf-herder.sort.Opts
function M.sort.qf_by(f, opts)
    local _, _, cfg = cfg_get_from_opts(opts, "sort")
    require("qf-herder._sort").sort(nil, vim.v.count, f, cfg)
end

---@param opts? qf-herder.sort.Opts
function M.sort.ll_fname_asc(opts)
    local win, _, cfg = cfg_get_from_opts(opts, "sort")
    local qfr_sort = require("qf-herder._sort")
    qfr_sort.sort(win, vim.v.count, qfr_sort.fname_asc, cfg)
end

---@param opts? qf-herder.sort.Opts
function M.sort.ll_fname_desc(opts)
    local win, _, cfg = cfg_get_from_opts(opts, "sort")
    local qfr_sort = require("qf-herder._sort")
    qfr_sort.sort(win, vim.v.count, qfr_sort.fname_desc, cfg)
end

---@param opts? qf-herder.sort.Opts
function M.sort.ll_severity_asc(opts)
    local win, _, cfg = cfg_get_from_opts(opts, "sort")
    local qfr_sort = require("qf-herder._sort")
    qfr_sort.sort(win, vim.v.count, qfr_sort.severity_asc, cfg)
end

---@param opts? qf-herder.sort.Opts
function M.sort.ll_severity_desc(opts)
    local win, _, cfg = cfg_get_from_opts(opts, "sort")
    local qfr_sort = require("qf-herder._sort")
    qfr_sort.sort(win, vim.v.count, qfr_sort.severity_desc, cfg)
end

---@param f fun(a:vim.quickfix.entry, b:vim.quickfix.entry): boolean
---@param opts? qf-herder.sort.Opts
function M.sort.ll_by(f, opts)
    local win, _, cfg = cfg_get_from_opts(opts, "sort")
    require("qf-herder._sort").sort(win, vim.v.count, f, cfg)
end

M.stack = {}

---@class qf-herder.stack.Opts
---@field autosize_changes? boolean
---@field spk? ""|"cursor"|"screen"|"topline"

---@param opts? qf-herder.stack.Opts
function M.stack.q_older(opts)
    local _, _, cfg = cfg_get_from_opts(opts, "stack")
    require("qf-herder._stack").q_older(false, vim.v.count1, cfg)
end

---@param opts? qf-herder.stack.Opts
function M.stack.q_newer(opts)
    local _, _, cfg = cfg_get_from_opts(opts, "stack")
    require("qf-herder._stack").q_newer(false, vim.v.count1, cfg)
end

---@param opts? qf-herder.stack.Opts
function M.stack.q_history(opts)
    local _, _, cfg = cfg_get_from_opts(opts, "stack")
    local vcount = vim.v.count
    require("qf-herder._stack").q_history(false, vcount > 0 and vcount or nil, cfg)
end

---@param opts? qf-herder.stack.Opts
function M.stack.q_clear(opts)
    local _, _, cfg = cfg_get_from_opts(opts, "stack")
    require("qf-herder._stack").q_clear(vim.v.count, cfg)
end

---@param opts? qf-herder.stack.Opts
function M.stack.q_free(opts)
    local _, _, cfg = cfg_get_from_opts(opts, "stack")
    require("qf-herder._stack").q_free(cfg)
end

---@param opts? qf-herder.stack.Opts
function M.stack.l_older(opts)
    local win, _, cfg = cfg_get_from_opts(opts, "stack")
    require("qf-herder._stack").l_older(win, false, vim.v.count1, cfg)
end

---@param opts? qf-herder.stack.Opts
function M.stack.l_newer(opts)
    local win, _, cfg = cfg_get_from_opts(opts, "stack")
    require("qf-herder._stack").l_newer(win, false, vim.v.count1, cfg)
end

---@param opts? qf-herder.stack.Opts
function M.stack.l_history(opts)
    local win, _, cfg = cfg_get_from_opts(opts, "stack")
    local vcount = vim.v.count
    require("qf-herder._stack").l_history(win, false, vcount > 0 and vcount or nil, cfg)
end

---@param opts? qf-herder.stack.Opts
function M.stack.l_clear(opts)
    local win, _, cfg = cfg_get_from_opts(opts, "stack")
    require("qf-herder._stack").l_clear(win, vim.v.count, false, cfg)
end

---@param opts? qf-herder.stack.Opts
function M.stack.l_free(opts)
    local win, _, cfg = cfg_get_from_opts(opts, "stack")
    require("qf-herder._stack").l_free(win, false, cfg)
end

return M
