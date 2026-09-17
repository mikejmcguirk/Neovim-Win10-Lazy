local api = vim.api
local fn = vim.fn

local M = {}

---@param t any
---@param prev any
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

---Evaluate if `t` is a |lua-dict|.
---@param t any
---@return 0|1|2|3
---- 0: Not a |lua-table|.
---- 1: Empty |lua-table|.
---- 2: |lua-list|
---- 3: |lua-dict| (may contain a list element).
local function is_table(t)
    if type(t) ~= "table" then
        return 0
    end

    if next(t) == nil then
        return 1
    end

    local len = #t
    if len == 0 then
        return 3
    end

    local count = 0
    for k in pairs(t) do
        count = count + 1
        if type(k) ~= "number" or k < 1 or k > len or k ~= math.floor(k) then
            return 3
        end
    end

    return (count == len) and 2 or 3
end

---Differences from |vim.deepcopy()|:
---- `userdata` and `thread` values are discarded rather than erroring. If either type is used as
---  a table key, the value is discarded.
---- `vim.NIL` is handled the same as other data.
---- Always "noref" behavior. Repeated references to the same table each get a new copy. If a
---  cyclic reference is detected, it is discarded.
---- Assumes that neither table has a metatable.
---@param t any
---@return any
function M._deepcopy(t)
    return deepcopy(t, {})
end

---@param t table Modified in place!
---@param defaults table
---@param prev_defaults table<table, true>
local function defaults_deep_do(t, defaults, prev_defaults)
    if prev_defaults[defaults] == true then
        return
    end

    prev_defaults[defaults] = true
    for k, vd in pairs(defaults) do
        local vd_table_type = is_table(vd)
        if vd_table_type == 3 then
            local v = t[k]
            if is_table(v) ~= 3 then
                v = {}
                t[k] = v
            end

            defaults_deep_do(v, vd, prev_defaults)
        else
            local vd_type = type(vd)
            if vd_type ~= "userdata" and vd_type ~= "thread" and t[k] == nil then
                t[k] = deepcopy(vd, {})
            end
        end
    end

    prev_defaults[defaults] = nil
end

---Recursively merge values from `t2` into `t1` if they are missing in `t1`. Unlike
---|merge_deep_left()|, a |lua-dict| value in `t2` will overwrite a non-dict value in `t1`.
---
---All values are deep-copied. If a cyclic reference is detected, merging is aborted.
---@generic K, V
---@param t table Modified in place!
---@param defaults table
---@return table Reference to `t`.
local function defaults_deep(t, defaults)
    defaults_deep_do(t, defaults, {})
    return t
end

---Get a |lua-list| of all keys from `t`.
---@generic K, V
---@param t table<K, V>
---@return K[]
local function table_keys(t)
    local ret = {}
    local i = 1
    for k, _ in pairs(t) do
        ret[i] = k
        i = i + 1
    end

    return ret
end

---Bespoke version because of future tbl_ deprecation
---The tbl_ version also does not contain the t == nil guard.
---Like the built-in, will only return non-nil if it is able to traverse the specific path
---specified in the args to a non-nil value.
---If no args, just return the table.
---@param t? table Table to index
---@param ... any Optional keys (0 or more, variadic) via which to index the table
---@return any # Nested value indexed by key (if it exists), else nil
local function get(t, ...)
    if t == nil then
        return nil
    end

    local nargs = select("#", ...)
    if nargs == 0 then
        return t
    end

    local v = t
    local args = { ... }
    for i = 1, nargs do
        v = v[args[i]]
        if v == nil then
            return nil
        elseif type(v) ~= "table" and i ~= nargs then
            return nil
        end
    end

    return v
end

---@param expected string
---@param actual string
---@return string
local function validator_err_make(expected, actual)
    return "Expected " .. expected .. ", found " .. actual
end

---@param val any
---@return boolean
local function is_callable(val)
    local val_type = type(val)
    if val_type == "function" then
        return true
    end

    local mt = getmetatable(val)
    return mt ~= nil and type(rawget(mt, "__call")) == "function"
end

---@param val any
---@param typ string
---@return boolean, string
local function string_type_is_valid(val, typ)
    if typ ~= "callable" then
        local val_type = type(val)
        local ok = val_type == typ
        return ok, ok and "" or validator_err_make(typ, val_type)
    end

    local ok = is_callable(val)
    return ok, ok and "" or "Not callable: " .. vim.inspect(val)
end

---@param val any
---@param validator string|string[]|fun(val:any): boolean, string
---@return boolean, string
local function validator_check(val, validator)
    if type(validator) == "string" then
        return string_type_is_valid(val, validator)
    end

    if vim.islist(validator) then
        ---@cast validator string[]
        for i = 1, #validator do
            local ok, err = string_type_is_valid(val, validator[i])
            if ok then
                return ok, err
            end
        end

        return false, validator_err_make(vim.inspect(validator), type(val))
    end

    if is_callable(validator) then
        ---@cast validator function
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

    local ok = true
    local err = ""
    prev[t] = true
    for k, v in pairs(t) do
        local vs = s[k]
        if vs == nil then
            ok = false
            err = "[" .. tostring(k) .. "]" .. " has no validator."
        else
            local v_is_dict = is_table(v) == 3
            local vs_is_dict = is_table(vs) == 3
            if (not v_is_dict) and not vs_is_dict then
                local ok_vc, err_vc = validator_check(v, vs)
                if not ok_vc then
                    ok = ok_vc
                    err = "[" .. tostring(k) .. "]" .. err_vc
                end
            elseif v_is_dict and vs_is_dict then
                local ok_msc, err_msc = matches_schema_checked(v, vs, prev)
                if not ok_msc then
                    ok = ok_msc
                    err = "[" .. tostring(k) .. "]" .. err_msc
                end
            else
                ok = false
                err = "[" .. tostring(k) .. "]" .. " sub-table mismatch."
            end
        end
    end

    prev[t] = nil
    return ok, err
end

---Inspired by futil-js `matchesSignature`
---
---Compare a |lua-dict| of values with a |lua-dict| schema. Returns `true` if all
---validators pass. Returns `false` with an error `string` if not.
---
---Schema values should follow |vim.validate()| logic.

---Values from `t` are allowed to be missing. Values from `t` without a corresponding signature
---`s` will return false.
---@param t table
---@param s table
---@return boolean, string
local function matches_schema(t, s)
    local table_type_t = is_table(t)
    if table_type_t == 0 or table_type_t == 2 then
        return false, "Config values are not a dictionary table."
    end

    if is_table(s) < 3 then
        return false, "Schema values are not a dictionary table."
    end

    return matches_schema_checked(t, s, {})
end

---@param t1 table Modified in place!
---@param t2 table
---@param prev table<table, true>
local function merge_deep_right_do(t1, t2, prev)
    if prev[t2] == true then
        return
    end

    prev[t2] = true
    for k, v2 in pairs(t2) do
        local v2_table_type = is_table(v2)
        if v2_table_type == 0 then
            local v2_type = type(v2)
            if v2_type ~= "userdata" and v2_type ~= "thread" then
                t1[k] = deepcopy(v2, {})
            end
        elseif v2_table_type == 3 then
            local v1 = t1[k]
            if is_table(v1) == 3 then
                merge_deep_right_do(v1, v2, prev)
            else
                t1[k] = deepcopy(v2, {})
            end
        else
            t1[k] = deepcopy(v2, {})
        end
    end

    prev[t2] = nil
end

---Recursively merge `t2` into `t1`. Values from `t2` take precedence.
---
---All values are deep-copied. Cyclic references are discarded.
---
---Actions:
---- `userdata` or `thread` values in `t2` will no-op.
---- A |lua-dict| in `t2` will merge into a corresponding dict in `t1`.
---- Otherwise, the value in `t2` will deepcopy into and over `t1`.
---@param t1 table Modified in place!
---@param t2 table
---@return table Reference to `t1`.
local function merge_deep_right(t1, t2)
    merge_deep_right_do(t1, t2, {})
    return t1
end

---@param t table Modified in place!
---@param keys table
---@param prev table<table, true>
local function unset_keys_do(t, keys, prev)
    if prev[keys] == true then
        return
    end

    prev[keys] = true
    for k, v in pairs(keys) do
        if v == true then
            t[k] = nil
        elseif is_table(v) == 3 then
            local tv = t[k]
            if is_table(tv) == 3 then
                unset_keys_do(tv, v, prev)
            end
        end
    end

    prev[keys] = nil
end

---Recursively set values in `t` to `nil` if the matching key/value pair in `keys` is true. If
---a value in `keys` is a |lua-dict|, iterate recursively.
---
---If a cyclic reference is detected, iteration at that sub-table is aborted.
---@param t table Modified in place!
---@param keys table
---@return table Reference to `t`.
local function unset_keys(t, keys)
    unset_keys_do(t, keys, {})
    return t
end

---@generic T, U, M
---@param ret table<any, M>
---@param t1 table<any, any>
---@param t2 table<any, any>
---@param f fun(v1:T, v2:U): M
---@param prev table<table<any, any>, true>
local function zip_deep_with_do(ret, t1, t2, f, prev)
    if prev[t1] == true then
        return
    end

    prev[t1] = true

    for k, v1 in pairs(t1) do
        local v2 = t2[k]
        if v2 ~= nil then
            local v1_is_dict = is_table(v1) == 3
            local v2_is_dict = is_table(v2) == 3
            if v1_is_dict == true and v2_is_dict == true then
                local v_new = {}
                zip_deep_with_do(v_new, v1, v2, f, prev)
                ret[k] = v_new
            elseif v1_is_dict == false and v2_is_dict == false then
                ret[k] = f(v1, v2)
            end
        end
    end

    prev[t1] = nil
end

---Recursively zip `t1` and `t2` into a new |lua-dict| based on the results of `f`.
---
---Only keys present in both tables are included (intersection). Structural mis-matches are
---dropped.
---@generic T, U, M
---@param t1 table<any, any>
---@param t2 table<any, any>
---@param f fun(v1:T, v2:U): M
local function zip_deep_with_to(t1, t2, f)
    local ret = {}
    zip_deep_with_do(ret, t1, t2, f, {})
    return ret
end

---Added even though vim._assert_integer exists because it's a private function and it performs
---conversion in addition to validation.
---@param n any
---@return boolean
local function is_int(n)
    return type(n) == "number" and n % 1 == 0
end

---@param n any
---@return boolean
local function is_uint(n)
    return is_int(n) and n >= 0
end

---@class catharsis.types.ValidateListOpts
---@field item_type? string|string[]|fun(x:any): boolean, string
---@field len? integer Takes precedence over max and min len.
---@field max_len? integer
---@field min_len? integer

---@generic T
---@param t any
---@param opts catharsis.types.ValidateListOpts
---@return boolean, string
local function valid_list(t, opts)
    if not vim.islist(t) then
        return false, "Not a valid list"
    end

    local list_len = #t
    local len = opts.len
    if len ~= nil then
        if list_len ~= len then
            return false, "List length must be " .. len
        end
    else
        local min_len = opts.min_len
        if min_len and list_len < min_len then
            return false, "List length must be at least" .. min_len
        end

        local max_len = opts.max_len
        if max_len and list_len > max_len then
            return false, "List length must be at most" .. max_len
        end
    end

    local item_type = opts.item_type
    if item_type == nil then
        return true, ""
    end

    if type(item_type) == "function" then
        for i = 1, list_len do
            local ok, err = item_type(t[i])
            if not ok then
                return false, err
            end
        end

        return true, ""
    end

    local _tools = require("qf-herder._tools")
    local predicate = type(item_type) == "table"
            and function(v)
                return _tools.i_includes(item_type, type(v))
            end
        or function(v)
            return type(v) == item_type
        end

    if _tools.i_all(t, predicate) then
        return true, ""
    end

    local bad_val, bad_idx = _tools.i_find(t, _tools.complement(predicate))
    local fmt_str = "Invalid: Idx: %d, Val: %s, Type: %s, Expected: %s"
    local bad_val_str = tostring(bad_val)
    local bad_type = type(bad_val)
    local expected = vim.inspect(item_type)
    local msg = string.format(fmt_str, bad_idx, bad_val_str, bad_type, expected)

    return false, msg
end

---------------------------
-- MARK: Defaults/Schema --
---------------------------

---@param val any
---@return boolean, string
local function ll_split_validate(val)
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

    local ok = require("qf-herder._tools").i_includes(ll_splits, val)
    return ok, ok and "" or validator_err_make(vim.inspect(ll_splits), vim.inspect(val))
end

---@param val any
---@return boolean, string
local function qf_split_validate(val)
    local qf_splits = {
        "bo",
        "botright",
        "to",
        "topleft",
    }

    local ok = require("qf-herder._tools").i_includes(qf_splits, val)
    return ok, ok and "" or validator_err_make(vim.inspect(qf_splits), vim.inspect(val))
end

---@param val any
---@return boolean, string
local function spk_validate(val)
    local spk = { "", "cursor", "screen", "topline" }
    local ok = require("qf-herder._tools").i_includes(spk, val)
    return ok, ok and "" or validator_err_make(vim.inspect(spk), vim.inspect(val))
end

---@param val any
---@return boolean, string
local function is_lower_string(val)
    local ok = type(val) == "string" and val == string.lower(val)
    return ok, ok and "" or validator_err_make("string", val)
end

local cases = { "smart", "ignore", "" }

---@param val any
---@return boolean, string
local function case_validate(val)
    local ok = require("qf-herder._tools").i_includes(cases, val)
    return ok, ok and "" or validator_err_make(vim.inspect(cases), vim.inspect(val))
end

---@class qf-herder.config.Schema
local schema = {
    auto_open_changes = "boolean",
    default_cmds_set = "boolean",
    default_keymaps_set = "boolean",
    diagnostics = {
        clear_on_empty = "boolean",
        open_results = "boolean",
        reuse_title = "boolean",
        title = "string",
    },
    filter = {
        open_results = "boolean",
    },
    ftplugin = {
        maps_set = "boolean",
        opts_set = "boolean",
    },
    grep = {
        case = case_validate,
        reuse_title = "boolean",
        sync = "boolean",
    },
    keymap = {
        diag_err = is_lower_string,
        diag_hint = is_lower_string,
        diag_info = is_lower_string,
        diag_warn = is_lower_string,
        key_buf = is_lower_string,
        prefix_diag = is_lower_string,
        key_dir = is_lower_string,
        key_filename = is_lower_string,
        prefix_filter = "string",
        key_fname = is_lower_string,
        key_help = is_lower_string,
        key_text = is_lower_string,
        prefix_grep = "string",
        prefix_ll = is_lower_string,
        prefix_qf = is_lower_string,
        prefix_sort = "string",
        stack_clear = is_lower_string,
        stack_newer = "string",
        stack_older = "string",
        win_close = "string",
        win_open = is_lower_string,
    },
    nav = {
        do_zzze = "boolean",
        split_qf = qf_split_validate,
    },
    preview = {
        do_zzze = "boolean",
    },
    sort = {
        open_results = "boolean",
    },
    stack = {
        update_list_wins = "boolean",
        spk = spk_validate,
    },
    system = {
        auto_height = "boolean",
        open_results = "boolean",
        spk = spk_validate,
        split_ll = ll_split_validate,
        split_qf = qf_split_validate,
        timeout = function(val)
            return is_uint(val)
        end,
        update_list_wins = "boolean",
    },
    window = {
        auto_height = "boolean",
        split_ll = ll_split_validate,
        split_qf = qf_split_validate,
        spk = spk_validate,
    },
}

---@alias qf-herder.window.llSplit "abo"|"aboveleft"|"bel"|"belowright"|"lefta"|"leftabove"|"rightb"|"rightbelow"

---@alias qf-herder.window.qfSplit "bo"|"botright"|"to"|"topleft"

---@class qf-herder.Config
local default_config = {
    default_cmds_set = true, ---@type boolean -- Only checked on startup.
    default_keymaps_set = true, ---@type boolean -- Only checked on startup.
    ---@class qf-herder.diagnostics.Cfg
    diagnostics = {
        clear_on_empty = true, ---@type boolean
        open_results = true, ---@type boolean
        reuse_title = true, ---@type boolean
        title = "Diagnostics", ---@type string
    },
    ---@class qf-herder.filter.Cfg
    filter = {
        open_results = true, ---@type boolean
    },
    ---@class qf-herder.ftplugin.Cfg
    ftplugin = {
        maps_set = true, ---@type boolean
        opts_set = true, ---@type boolean
    },
    ---@class qf-herder.grep.Cfg
    grep = {
        case = "smart", ---@type "smart"|"ignore"|""
        reuse_title = true, ---@type boolean
        sync = true, ---@type boolean
    },
    -- Only checked on startup
    ---@class qf-herder.keymap.Cfg
    keymap = {
        diag_err = "e", ---@type string -- Must be lowercase
        diag_hint = "n", ---@type string -- Must be lowercase
        diag_info = "o", ---@type string -- Must be lowercase
        diag_warn = "w", ---@type string -- Must be lowercase
        key_fname = "f", ---@type string -- Must be lowercase
        key_buf = "u", ---@type string
        prefix_diag = "i", ---@type string -- Must be lowercase
        key_dir = "d", ---@type string
        prefix_filter = "r", ---@type string
        key_help = "h", ---@type string
        key_text = "e", ---@type string -- Must be lowercase
        prefix_grep = "g", ---@type string
        prefix_ll = "<leader>l", ---@type string -- Must be lowercase
        prefix_qf = "<leader>q", ---@type string -- Must be lowercase
        prefix_sort = "t", ---@type string
        stack_clear = "e", ---@type string
        stack_newer = "]", ---@type string
        stack_older = "[", ---@type string
        win_close = "o", ---@type string
        win_open = "p", ---@type string
    },
    ---@class qf-herder.nav.Cfg
    nav = {
        do_zzze = true, ---@type boolean
        split_qf = "botright", ---@type qf-herder.window.qfSplit
    },
    ---@class qf-herder.preview.Cfg
    preview = {
        do_zzze = true, ---@type boolean
    },
    ---@class qf-herder.sort.Cfg
    sort = {
        open_results = true, ---@type boolean
    },
    ---@class qf-herder.stack.Cfg
    stack = {
        spk = "topline", ---@type ""|"cursor"|"screen"|"topline"
        -- Resizes the list after running history cmds. Closes the list if the stack is freed.
        update_list_wins = true, ---@type boolean
    },
    ---@class qf-rancher.system.Cfg
    system = {
        auto_height = true, ---@type boolean
        open_results = true, ---@type boolean
        spk = "topline", ---@type ""|"cursor"|"screen"|"topline"
        split_ll = "belowright", ---@type qf-herder.window.llSplit
        split_qf = "botright", ---@type qf-herder.window.qfSplit
        timeout = 1000, ---@type uinteger
        update_list_wins = true, ---@type boolean
    },
    ---@class qf-herder.window.Cfg
    window = {
        auto_height = true, ---@type boolean
        split_ll = "belowright", ---@type qf-herder.window.llSplit
        split_qf = "botright", ---@type qf-herder.window.qfSplit
        spk = "topline", ---@type ""|"cursor"|"screen"|"topline"
    },
}

---@return boolean, string
function M.__default_schema_check()
    return matches_schema(default_config, schema)
end

---@class qf-herder.filter.Opts
---@field open_results? boolean

---@class qf-herder.ftplugin.Opts
---@field maps_set? boolean
---@field opts_set? boolean

---@class qf-herder.grep.Opts
---@field case? string "smart"|"ignore"|""
---@field reuse_title? boolean
---@field sync? boolean

---@class qf-herder.keymap.Opts
---@field diag_err?  string
---@field diag_hint?  string
---@field diag_info?  string
---@field diag_warn?  string
---@field fname?  string
---@field key_buf?  string
---@field key_diag?  string
---@field key_dir?  string
---@field key_filter?  string
---@field key_help?  string
---@field key_text?  string
---@field prefix_grep?  string
---@field prefix_ll?  string
---@field prefix_qf?  string
---@field sort_key?  string
---@field stack_clear?  string
---@field stack_newer?  string
---@field stack_older?  string
---@field win_close?  string
---@field win_open?  string

---@class qf-herder.nav.Opts
---@field do_zzze? boolean
---@field split_qf? qf-herder.window.qfSplit

---@class qf-herder.preview.Opts
---@field do_zzze? boolean

---@class qf-herder.sort.Opts
---@field open_results? boolean

---@class qf-herder.stack.Opts
---@field update_list_wins? boolean
---@field spk? ""|"cursor"|"screen"|"topline"

---@class qf-herder.system.Opts
---@field auto_height? boolean
---@field open_results? boolean
---@field spk? ""|"cursor"|"screen"|"topline"
---@field split_ll? qf-herder.window.llSplit
---@field split_qf? qf-herder.window.qfSplit
---@field timeout? uinteger
---@field update_list_wins? boolean

---@class qf-herder.window.Opts
---@field auto_height? boolean
---@field ll_split? qf-herder.window.llSplit
---@field qf_split? qf-herder.window.qfSplit
---@field spk? ""|"cursor"|"screen"|"topline"

---@class qf-herder.config.Partial
---@field default_cmds_set? boolean
---@field default_keymaps_set? boolean
---@field diagnostics? qf-herder.diagnostics.Opts
---@field filter? qf-herder.filter.Opts
---@field ftplugin? qf-herder.ftplugin.Opts
---@field grep? qf-herder.grep.Opts
---@field keymap? qf-herder.keymap.Opts
---@field nav? qf-herder.nav.Opts
---@field preview? qf-herder.preview.Opts
---@field sort? qf-herder.sort.Opts
---@field stack? qf-herder.stack.Opts
---@field system? qf-herder.system.Opts
---@field window? qf-herder.window.Opts

------------------
-- MARK: Config --
------------------

local config = M._deepcopy(default_config)
---@cast config qf-herder.Config

---@param new_config? qf-herder.config.Partial
---@return qf-herder.Config
function M.config(new_config)
    if new_config == nil then
        return M._deepcopy(config)
    end

    local ok, err = matches_schema(new_config, schema)
    if not ok then
        if vim.v.vim_did_enter == 1 then
            error(err)
        end

        api.nvim_echo({ { err, "ErrorMsg" } }, true, {})
        return M._deepcopy(config)
    end

    merge_deep_right(config, new_config)
    return M._deepcopy(config)
end

function M.config_reset()
    config = M._deepcopy(default_config)
end

---@param keys table
---@return qf-herder.Config
function M.unset_keys(keys)
    vim.validate("keys", keys, "table")

    unset_keys(config, keys)
    local defaults_zipped = zip_deep_with_to(keys, default_config, function(_, dv)
        return dv
    end)

    defaults_deep(config, defaults_zipped)
    return M._deepcopy(config)
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
local function buf_config_get_or_create(buf)
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
    vim.validate("buf", buf, is_uint)
    vim.validate("new_config", new_config, "table", true)

    buf = buf ~= 0 and buf or api.nvim_get_current_buf()
    if not api.nvim_buf_is_valid(buf) then
        buf_configs[buf] = nil
        error(buf .. " is not valid")
    end

    local buf_config = buf_config_get_or_create(buf)
    if new_config == nil then
        return M._deepcopy(buf_config)
    end

    local ok, err = matches_schema(new_config, schema)
    if not ok then
        api.nvim_echo({ { err, "ErrorMsg" } }, true, {})
    else
        merge_deep_right(buf_config, new_config)
    end

    return M._deepcopy(buf_config)
end

---@param bufs uinteger[]|nil
function M.buf_config_clear(bufs)
    vim.validate("bufs", bufs, function()
        return valid_list(bufs, { item_type = "number" })
    end, true)

    if bufs == nil then
        for _, cfg in pairs(buf_configs) do
            require("qf-herder._tools").clear(cfg)
        end

        return
    end

    for _, buf in ipairs(bufs) do
        local buf_config = buf_configs[buf]
        if buf_config ~= nil then
            require("qf-herder._tools").clear(buf_config)
        end
    end
end

---@param buf uinteger
---@param keys table
---@return qf-herder.config.Partial
function M.buf_config_unset_keys(buf, keys)
    vim.validate("buf", buf, is_uint)
    vim.validate("keys", keys, "table")

    buf = buf ~= 0 and buf or api.nvim_get_current_buf()
    if not api.nvim_buf_is_valid(buf) then
        buf_configs[buf] = nil
        error(buf .. " is not valid")
    end

    return M._deepcopy(unset_keys(buf_config_get_or_create(buf), keys))
end

---@return uinteger[]
function M.buf_config_list_bufs()
    local keys = table_keys(buf_configs)
    table.sort(keys)
    return keys
end

---@return uinteger[]
function M._buf_config_list_bufs_empty()
    return require("qf-herder._tools").i_keep(M.buf_config_list_bufs(), function(buf)
        return next(buf_configs[buf]) == nil
    end)
end

-----------------------
-- MARK: API Helpers --
-----------------------

---@param buf uinteger
---@param usr_config table?
---@param ... any
---@return table
function M._config_merged_get(buf, usr_config, ...)
    local cfg = M._deepcopy(get(config, ...))
    if cfg == nil then
        error("Invalid config path")
    end

    buf = buf ~= 0 and buf or api.nvim_get_current_buf()
    local buf_config = buf_configs[buf]
    if buf_config ~= nil then
        local buf_cfg = get(buf_config, ...)
        if buf_cfg ~= nil then
            merge_deep_right(cfg, buf_cfg)
        end
    end

    if usr_config == nil then
        return cfg
    end

    local sub_schema = get(schema, ...)
    local ok, err = matches_schema(usr_config, sub_schema)
    if not ok then
        error(err)
    end

    merge_deep_right(cfg, usr_config)
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

M.window = {}

---@class qf-herder.window.qfOpen.Opts
---@field auto_height? boolean
---@field qf_split? qf-herder.window.qfSplit
---@field spk? "cursor"|"screen"|"topline"|""

---@param opts? qf-herder.window.qfOpen.Opts
function M.window.qf_open(opts)
    local _, _, cfg = cfg_get_from_opts(opts, "window")
    require("qf-herder._window").qf_open(vim.v.count, cfg)
end

---@class qf-herder.window.qfClose.Opts
---@field spk? "cursor"|"screen"|"topline"|""

---@param opts? qf-herder.window.qfClose.Opts
function M.window.qf_close(opts)
    local _, _, cfg = cfg_get_from_opts(opts, "window")
    require("qf-herder._window").qf_close({ 0 }, cfg)
end

---@class qf-herder.window.qfToggle.Opts
---@field auto_height? boolean
---@field qf_split? qf-herder.window.qfSplit
---@field spk? "cursor"|"screen"|"topline"|""

---@param opts? qf-herder.window.qfToggle.Opts
function M.window.qf_toggle(opts)
    local _, _, cfg = cfg_get_from_opts(opts, "window")
    require("qf-herder._window").qf_toggle(vim.v.count, cfg)
end

---@class qf-herder.window.qfResize.Opts
---@field spk? "cursor"|"screen"|"topline"|""

---@param opts? qf-herder.window.qfResize.Opts
function M.window.qf_resize(opts)
    local _, _, cfg = cfg_get_from_opts(opts, "window")
    require("qf-herder._window").qf_resize(0, vim.v.count, cfg)
end

---@class qf-herder.window.llOpen.Opts
---@field auto_height? boolean
---@field ll_split? qf-herder.window.llSplit
---@field silent? boolean
---@field spk? "cursor"|"screen"|"topline"|""

---@param opts? qf-herder.window.llOpen.Opts
function M.window.ll_open(opts)
    local _, _, cfg = cfg_get_from_opts(opts, "window")
    require("qf-herder._window").ll_open(vim.v.count, false, cfg)
end

---@class qf-herder.window.llClose.Opts
---@field silent? boolean
---@field spk? "cursor"|"screen"|"topline"|""

---@param opts? qf-herder.window.llClose.Opts
function M.window.ll_close(opts)
    local _, _, cfg = cfg_get_from_opts(opts, "window")
    require("qf-herder._window").ll_close(api.nvim_get_current_win(), false, cfg)
end

---@class qf-herder.window.llToggle.Opts
---@field auto_height? boolean
---@field ll_split? qf-herder.window.llSplit
---@field spk? "cursor"|"screen"|"topline"|""

---@param opts? qf-herder.window.llToggle.Opts
function M.window.ll_toggle(opts)
    local _, _, cfg = cfg_get_from_opts(opts, "window")
    require("qf-herder._window").ll_toggle(vim.v.count, false, cfg)
end

---@class qf-herder.window.llResize.Opts
---@field silent? boolean
---@field spk? "cursor"|"screen"|"topline"|""

---@param opts? qf-herder.window.llResize.Opts
function M.window.ll_resize(opts)
    local _, _, cfg = cfg_get_from_opts(opts, "window")
    require("qf-herder._window").ll_resize(0, vim.v.count, false, cfg)
end

M.del = {}

function M.del.single()
    require("qf-herder._del").single()
end

function M.del.visual()
    require("qf-herder._del").visual()
end

M.diags = {}

---@class qf-herder.diagnostics.Opts
---@field clear_on_empty? boolean
---@field open_results? boolean
---@field reuse_title? boolean
---@field title? string

---@param get_opts vim.diagnostic.GetOpts
---@param opts? qf-herder.diagnostics.Opts
local function qf_diags_do(get_opts, top_only, opts)
    local _, _, cfg = cfg_get_from_opts(opts, "diagnostics")
    local sort_fun = require("qf-herder._sort").severity_asc
    require("qf-herder._diag").diags_to_list(nil, get_opts, top_only, sort_fun, cfg)
end

---@param opts? qf-herder.diagnostics.Opts
function M.diags.qf_all_bufs_top(opts)
    qf_diags_do({ severity = 1, 2, 3, 4 }, true, opts)
end

---@param opts? qf-herder.diagnostics.Opts
function M.diags.qf_all_bufs_error(opts)
    qf_diags_do({ severity = 1 }, false, opts)
end

---@param opts? qf-herder.diagnostics.Opts
function M.diags.qf_all_bufs_max_warn(opts)
    qf_diags_do({ severity = { 1, 2 } }, false, opts)
end

---@param opts? qf-herder.diagnostics.Opts
function M.diags.qf_all_bufs_max_info(opts)
    qf_diags_do({ severity = { 1, 2, 3 } }, false, opts)
end

---@param opts? qf-herder.diagnostics.Opts
function M.diags.qf_all_bufs_max_hint(opts)
    qf_diags_do({ severity = { 1, 2, 3, 4 } }, false, opts)
end

---@param get_opts vim.diagnostic.GetOpts
---@param opts? qf-herder.diagnostics.Opts
local function ll_diags_do(get_opts, top_only, opts)
    local win, _, cfg = cfg_get_from_opts(opts, "diagnostics")
    local sort_fun = require("qf-herder._sort").severity_asc
    require("qf-herder._diag").diags_to_list(win, get_opts, top_only, sort_fun, cfg)
end

---@param opts? qf-herder.diagnostics.Opts
function M.diags.ll_cur_buf_top(opts)
    ll_diags_do({ severity = 1, 2, 3, 4 }, true, opts)
end

---@param opts? qf-herder.diagnostics.Opts
function M.diags.ll_cur_buf_error(opts)
    ll_diags_do({ severity = 1 }, false, opts)
end

---@param opts? qf-herder.diagnostics.Opts
function M.diags.ll_cur_buf_max_warn(opts)
    ll_diags_do({ severity = { 1, 2 } }, false, opts)
end

---@param opts? qf-herder.diagnostics.Opts
function M.diags.ll_cur_buf_max_info(opts)
    ll_diags_do({ severity = { 1, 2, 3 } }, false, opts)
end

---@param opts? qf-herder.diagnostics.Opts
function M.diags.ll_cur_buf_max_hint(opts)
    ll_diags_do({ severity = { 1, 2, 3, 4 } }, false, opts)
end

M.filter = {}

---@param count uinteger
---@param name string
---@param f fun(entry:vim.quickfix.entry, regex:vim.regex): boolean
---@param opts? qf-herder.filter.Opts
local function qf_filter_do(count, name, f, opts)
    local _, _, cfg = cfg_get_from_opts(opts, "filter")
    require("qf-herder._filter").filter(nil, count, name, f, cfg)
end

---@param count uinteger
---@param name string
---@param f fun(entry:vim.quickfix.entry, regex:vim.regex): boolean
---@param opts? qf-herder.filter.Opts
local function ll_filter_do(count, name, f, opts)
    local win, _, cfg = cfg_get_from_opts(opts, "filter")
    require("qf-herder._filter").filter(win, count, name, f, cfg)
end

---@param opts? qf-herder.filter.Opts
function M.filter.qf_fname_keep(opts)
    qf_filter_do(vim.v.count, "Keep Fname", require("qf-herder._filter").fname_keep, opts)
end

---@param opts? qf-herder.filter.Opts
function M.filter.qf_fname_discard(opts)
    qf_filter_do(vim.v.count, "Discard Fname", require("qf-herder._filter").fname_discard, opts)
end

---@param opts? qf-herder.filter.Opts
function M.filter.ll_fname_keep(opts)
    ll_filter_do(vim.v.count, "Keep Fname", require("qf-herder._filter").fname_keep, opts)
end

---@param opts? qf-herder.filter.Opts
function M.filter.ll_fname_discard(opts)
    ll_filter_do(vim.v.count, "Discard Fname", require("qf-herder._filter").fname_discard, opts)
end

---@param opts? qf-herder.filter.Opts
function M.filter.qf_text_keep(opts)
    qf_filter_do(vim.v.count, "Keep Text", require("qf-herder._filter").text_keep, opts)
end

---@param opts? qf-herder.filter.Opts
function M.filter.qf_text_discard(opts)
    qf_filter_do(vim.v.count, "Discard Text", require("qf-herder._filter").text_discard, opts)
end

---@param opts? qf-herder.filter.Opts
function M.filter.ll_text_keep(opts)
    ll_filter_do(vim.v.count, "Keep Text", require("qf-herder._filter").text_keep, opts)
end

---@param opts? qf-herder.filter.Opts
function M.filter.ll_text_discard(opts)
    ll_filter_do(vim.v.count, "Discard Text", require("qf-herder._filter").text_discard, opts)
end

M.nav = {}

---@param opts? qf-herder.nav.Opts
function M.nav.q_prev(opts)
    local win, _, cfg = cfg_get_from_opts(opts, "nav")
    require("qf-herder._nav").q_prev(vim.v.count1, win, false, false, cfg)
end

---@param opts? qf-herder.nav.Opts
function M.nav.q_next(opts)
    local win, _, cfg = cfg_get_from_opts(opts, "nav")
    require("qf-herder._nav").q_next(vim.v.count1, win, false, false, cfg)
end

---@param opts? qf-herder.nav.Opts
function M.nav.q_prev_keep_focus(opts)
    local win, _, cfg = cfg_get_from_opts(opts, "nav")
    require("qf-herder._nav").q_prev(vim.v.count1, win, true, false, cfg)
end

---@param opts? qf-herder.nav.Opts
function M.nav.q_next_keep_focus(opts)
    local win, _, cfg = cfg_get_from_opts(opts, "nav")
    require("qf-herder._nav").q_next(vim.v.count1, win, true, false, cfg)
end

---@param opts? qf-herder.nav.Opts
function M.nav.q_q(opts)
    local win, _, cfg = cfg_get_from_opts(opts, "nav")
    require("qf-herder._nav").q_q(vim.v.count, win, false, false, cfg)
end

---@param opts? qf-herder.nav.Opts
function M.nav.q_q(opts)
    local win, _, cfg = cfg_get_from_opts(opts, "nav")
    require("qf-herder._nav").q_q(vim.v.count, win, true, false, cfg)
end

---@param opts? qf-herder.nav.Opts
function M.nav.q_rewind(opts)
    local _, _, cfg = cfg_get_from_opts(opts, "nav")
    require("qf-herder._nav").q_rewind(vim.v.count, false, cfg)
end

---@param opts? qf-herder.nav.Opts
function M.nav.q_last(opts)
    local _, _, cfg = cfg_get_from_opts(opts, "nav")
    require("qf-herder._nav").q_last(vim.v.count, false, cfg)
end

---@param opts? qf-herder.nav.Opts
function M.nav.q_pfile(opts)
    local _, _, cfg = cfg_get_from_opts(opts, "nav")
    require("qf-herder._nav").q_pfile(vim.v.count1, false, cfg)
end

---@param opts? qf-herder.nav.Opts
function M.nav.q_nfile(opts)
    local _, _, cfg = cfg_get_from_opts(opts, "nav")
    require("qf-herder._nav").q_nfile(vim.v.count1, false, cfg)
end

---@param opts? qf-herder.nav.Opts
function M.nav.l_prev(opts)
    local win, _, cfg = cfg_get_from_opts(opts, "nav")
    require("qf-herder._nav").l_prev(win, vim.v.count1, win, false, false, cfg)
end

---@param opts? qf-herder.nav.Opts
function M.nav.l_next(opts)
    local win, _, cfg = cfg_get_from_opts(opts, "nav")
    require("qf-herder._nav").l_next(win, vim.v.count1, win, false, false, cfg)
end

---@param opts? qf-herder.nav.Opts
function M.nav.l_prev_keep_focus(opts)
    local win, _, cfg = cfg_get_from_opts(opts, "nav")
    require("qf-herder._nav").l_prev(win, vim.v.count1, win, true, false, cfg)
end

---@param opts? qf-herder.nav.Opts
function M.nav.l_next_keep_focus(opts)
    local win, _, cfg = cfg_get_from_opts(opts, "nav")
    require("qf-herder._nav").l_next(win, vim.v.count1, win, true, false, cfg)
end

---@param opts? qf-herder.nav.Opts
function M.nav.l_l(opts)
    local win, _, cfg = cfg_get_from_opts(opts, "nav")
    require("qf-herder._nav").l_l(win, vim.v.count, win, false, false, cfg)
end

---@param opts? qf-herder.nav.Opts
function M.nav.l_l_keep_focus(opts)
    local win, _, cfg = cfg_get_from_opts(opts, "nav")
    require("qf-herder._nav").l_l(win, vim.v.count, win, true, false, cfg)
end

---@param opts? qf-herder.nav.Opts
function M.nav.l_rewind(opts)
    local win, _, cfg = cfg_get_from_opts(opts, "nav")
    require("qf-herder._nav").l_rewind(win, vim.v.count, false, cfg)
end

---@param opts? qf-herder.nav.Opts
function M.nav.l_last(opts)
    local win, _, cfg = cfg_get_from_opts(opts, "nav")
    require("qf-herder._nav").l_last(win, vim.v.count, false, cfg)
end

---@param opts? qf-herder.nav.Opts
function M.nav.l_pfile(opts)
    local win, _, cfg = cfg_get_from_opts(opts, "nav")
    require("qf-herder._nav").l_pfile(win, vim.v.count1, false, cfg)
end

---@param opts? qf-herder.nav.Opts
function M.nav.l_nfile(opts)
    local win, _, cfg = cfg_get_from_opts(opts, "nav")
    require("qf-herder._nav").l_nfile(win, vim.v.count1, false, cfg)
end

function M.nav.split()
    require("qf-herder._nav").split(false)
end

function M.nav.split_keep_focus()
    require("qf-herder._nav").split(true)
end

function M.nav.tabnew()
    require("qf-herder._nav").tabnew(false)
end

function M.nav.tabnew_keep_focus()
    require("qf-herder._nav").tabnew(true)
end

---@param opts? qf-herder.nav.Opts
function M.nav.qf_vsplit(opts)
    local _, _, cfg = cfg_get_from_opts(opts, "nav")
    require("qf-herder._nav").qf_vsplit(false, cfg)
end

---@param opts? qf-herder.nav.Opts
function M.nav.qf_vsplit_keep_focus(opts)
    local _, _, cfg = cfg_get_from_opts(opts, "nav")
    require("qf-herder._nav").qf_vsplit(true, cfg)
end

function M.nav.ll_vsplit()
    require("qf-herder._nav").ll_vsplit(false)
end

function M.nav.ll_vsplit_keep_focus()
    require("qf-herder._nav").ll_vsplit(true)
end

M.preview = {}

---@param opts? qf-herder.preview.Opts
function M.preview.open(opts)
    local _, _, cfg = cfg_get_from_opts(opts, "preview")
    require("qf-herder._preview").pvw_win_open(cfg)
end

function M.preview.close()
    require("qf-herder._preview").pvw_win_close()
end

---@param opts? qf-herder.preview.Opts
function M.preview.toggle(opts)
    local _, _, cfg = cfg_get_from_opts(opts, "preview")
    require("qf-herder._preview").pvw_win_toggle(cfg)
end

M.rg = {}

---@param regex boolean
---@param opts? qf-herder.grep.Opts
local function grep_ll_cur_buf(regex, opts)
    local win, buf, cfg = cfg_get_from_opts(opts, "grep")
    local locations = { api.nvim_buf_get_name(buf) }
    local sort_fun = require("qf-herder._sort").fname_asc
    require("qf-herder._grep").rg(win, locations, "Cur Buf", regex, "", sort_fun, cfg)
end

---@param opts? qf-herder.grep.Opts
function M.rg.ll_cur_buf_fixed(opts)
    grep_ll_cur_buf(false, opts)
end

---@param opts? qf-herder.grep.Opts
function M.rg.ll_cur_buf_regex(opts)
    grep_ll_cur_buf(true, opts)
end

---@param regex boolean
---@param opts? qf-herder.grep.Opts
local function grep_ll_help(regex, opts)
    local win, _, cfg = cfg_get_from_opts(opts, "grep")
    local locations = api.nvim_get_runtime_file("doc/*.txt", true)
    local sort_fun = require("qf-herder._sort").fname_asc
    require("qf-herder._grep").rg(win, locations, "Cur Buf", regex, "", sort_fun, cfg)
end

---@param opts? qf-herder.grep.Opts
function M.rg.ll_help_fixed(opts)
    grep_ll_help(false, opts)
end

---@param opts? qf-herder.grep.Opts
function M.rg.ll_help_regex(opts)
    grep_ll_help(true, opts)
end

---@return string[]
local function bufs_get_std_listed()
    local bufs = require("qf-herder._tools").i_keep(api.nvim_list_bufs(), function(buf)
        local buf_scope = { buf = buf }
        local bt = api.nvim_get_option_value("bt", buf_scope)
        return bt == "" and api.nvim_get_option_value("bl", buf_scope)
    end)

    return require("qf-herder._tools").i_filter_map_to(bufs, function(buf)
        return api.nvim_buf_get_name(buf)
    end)
end

---@param regex boolean
---@param opts? qf-herder.grep.Opts
local function grep_qf_bufs(regex, opts)
    local _, _, cfg = cfg_get_from_opts(opts, "grep")
    local locations = bufs_get_std_listed()
    local sort_fun = require("qf-herder._sort").fname_asc
    require("qf-herder._grep").rg(nil, locations, "Cur Buf", regex, "", sort_fun, cfg)
end

---@param opts? qf-herder.grep.Opts
function M.rg.qf_bufs_fixed(opts)
    grep_qf_bufs(false, opts)
end

---@param opts? qf-herder.grep.Opts
function M.rg.qf_bufs_regex(opts)
    grep_qf_bufs(true, opts)
end

---@param regex boolean
---@param opts? qf-herder.grep.Opts
local function grep_qf_tcd(regex, opts)
    local _, _, cfg = cfg_get_from_opts(opts, "grep")
    local locations = { fn.getcwd(-1, 0) }
    local sort_fun = require("qf-herder._sort").fname_asc
    require("qf-herder._grep").rg(nil, locations, "Tcd", regex, "", sort_fun, cfg)
end

---@param opts? qf-herder.grep.Opts
function M.rg.qf_tcd_fixed(opts)
    grep_qf_tcd(false, opts)
end

---@param opts? qf-herder.grep.Opts
function M.rg.qf_tcd_regex(opts)
    grep_qf_tcd(true, opts)
end

---@param buf uinteger
---@return string[]
local function bcd_get(buf)
    -- TODO-DEP: Remove `has()` when 0.14 comes out.
    if fn.has("nvim-0.13") == 1 then
        return { fn.getcwd(-1, -1, buf) }
    else
        return { fn.fnamemodify(api.nvim_buf_get_name(buf), ":h") }
    end
end

---@param regex boolean
---@param opts? qf-herder.grep.Opts
local function grep_ll_bcd(regex, opts)
    local _, buf, cfg = cfg_get_from_opts(opts, "grep")
    local locations = bcd_get(buf)
    local sort_fun = require("qf-herder._sort").fname_asc
    require("qf-herder._grep").rg(nil, locations, "Cur Buf", regex, "", sort_fun, cfg)
end

---@param opts? qf-herder.grep.Opts
function M.rg.ll_bcd_fixed(opts)
    grep_ll_bcd(false, opts)
end

---@param opts? qf-herder.grep.Opts
function M.rg.ll_bcd_regex(opts)
    grep_ll_bcd(true, opts)
end

M.sort = {}

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
