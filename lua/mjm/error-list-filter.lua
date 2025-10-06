--- @class QfRancherFilter
local M = {}

-------------------------
--- Wrapper Functions ---
-------------------------

--- @param name string
--- @param keep boolean
--- @param input_type QfRancherInputType
--- @return string
local function get_prompt(name, keep, input_type)
    if vim.g.qf_rancher_debug_assertions then
        vim.validate("name", name, "string")
        vim.validate("keep", keep, "boolean")
        require("mjm.error-list-types")._validate_input_type(input_type)
    end

    --- @type string
    local enter_prompt = "Enter pattern to " .. (keep and "keep" or "remove")
    --- @type string
    local type = require("mjm.error-list-util")._get_display_input_type(input_type)
    return name .. ": " .. enter_prompt .. " (" .. type .. "): "
end

--- @param filter_info QfRancherFilterInfo
--- @param input_type QfRancherInputType
--- @param regex vim.regex|nil
--- @return QfRancherPredicateFunc
local function get_predicate(filter_info, input_type, regex)
    if input_type == "regex" and regex then
        return filter_info.regex_func
    elseif input_type == "sensitive" then
        return filter_info.sensitive_func
    else
        return filter_info.insensitive_func
    end
end

--- @param filter_info QfRancherFilterInfo
--- @param filter_opts QfRancherFilterOpts
--- @param input_opts QfRancherInputOpts
--- @param what QfRancherWhat
--- @return nil
local function validate_wrapper_input(filter_info, filter_opts, input_opts, what)
    local ey = require("mjm.error-list-types")
    ey._validate_filter_info(filter_info)
    ey._validate_filter_opts(filter_opts)
    ey._validate_input_opts(input_opts)
    ey._validate_what_strict(what)
end

--- @param filter_info QfRancherFilterInfo
--- @param filter_opts QfRancherFilterOpts
--- @param input_opts QfRancherInputOpts
--- @param what QfRancherWhat
--- @return nil
function M._filter_wrapper(filter_info, filter_opts, input_opts, what)
    filter_info = filter_info or {}
    filter_opts = filter_opts or {}
    input_opts = input_opts or {}
    what = what or {}
    validate_wrapper_input(filter_info, filter_opts, input_opts, what)

    local list_win = what.user_data.list_win
    local eu = require("mjm.error-list-util") --- @type QfRancherUtils

    if list_win and not eu._win_can_have_loclist(what.user_data.list_win) then
        return
    end

    local et = require("mjm.error-list-tools") --- @type QfRancherTools
    local cur_list = et._get_list_all(what.user_data.list_win, what.nr) --- @type table
    if cur_list.size == 0 then
        vim.api.nvim_echo({ { "No entries to filter", "" } }, false, {})
        return
    end

    local input_type = eu._resolve_input_type(input_opts.input_type) --- @type QfRancherInputType
    local prompt = get_prompt(filter_info.name, filter_opts.keep, input_type) --- @type string
    --- @type string|nil
    local pattern = eu._resolve_pattern(prompt, input_opts.pattern, input_type)
    if not pattern then
        return
    end

    local regex = input_type == "regex" and vim.regex(pattern) or nil --- @type vim.regex|nil
    local lower_pattern = string.lower(pattern) --- @type string
    --- LOW: The real issue is that the predicate types are a distinct thing
    if input_type == "smartcase" then
        local is_smart_pattern = lower_pattern == pattern
        input_type = is_smart_pattern and "insensitive" or "sensitive"
        pattern = is_smart_pattern and lower_pattern or pattern
    end

    --- @type QfRancherPredicateFunc
    local predicate = get_predicate(filter_info, input_type, regex)
    local new_items = vim.tbl_filter(function(t)
        return predicate({
            keep = filter_opts.keep,
            pattern = pattern,
            regex = regex,
            item = t,
        })
    end, cur_list.items) --- @type vim.quickfix.entry[]

    local what_set = vim.tbl_deep_extend("force", what, {
        items = new_items,
        title = "Filter", --- TODO: Improve title
    }) --- @type QfRancherWhat

    --- TODO: Should check for auto open and potentially do so
    et._set_list(what_set)
end

--- NOTE: In line with Cfilter and the C code, bufname() is used for checking filenames

-----------------------
-- Cfilter Emulation --
-----------------------

--- @type QfRancherPredicateFunc
local function cfilter_regex(opts)
    opts = opts or {}

    if opts.regex:match_str(opts.item.text) then
        return opts.keep
    end

    if not opts.item.bufnr then
        return false
    end

    local bufname = vim.fn.bufname(opts.item.bufnr)
    return opts.regex:match_str(bufname) and opts.keep or not opts.keep
end

--- @type QfRancherPredicateFunc
--- NOTE: Assumes pattern is all lowercase
local function cfilter_insensitive(opts)
    opts = opts or {}

    local lower_text = string.lower(opts.item.text)
    if string.find(lower_text, opts.pattern, 1, true) ~= nil then
        return opts.keep
    end

    if not opts.item.bufnr then
        return false
    end

    local lower_bufname = string.lower(vim.fn.bufname(opts.item.bufnr))
    return string.find(lower_bufname, opts.pattern, 1, true) ~= nil and opts.keep or not opts.keep
end

--- @type QfRancherPredicateFunc
local function cfilter_sensitive(opts)
    opts = opts or {}

    if string.find(opts.item.text, opts.pattern, 1, true) ~= nil then
        return opts.keep
    end

    if not opts.bufnr then
        return false
    end

    local bufname = vim.fn.bufname(opts.item.bufnr)
    return string.find(bufname, opts.pattern, 1, true) ~= nil and opts.keep or not opts.keep
end

--------------
-- Filename --
--------------

--- @param opts QfRancherPredicateOpts
--- @return boolean
local function fname_regex(opts)
    opts = opts or {}
    if not opts.item.bufnr then
        return false
    end

    local bufname = vim.fn.bufname(opts.item.bufnr)
    return opts.regex:match_str(bufname) and opts.keep or not opts.keep
end

--- @param opts QfRancherPredicateOpts
--- @return boolean
--- NOTE: Assumes pattern is all lowercase
local function fname_insensitive(opts)
    opts = opts or {}
    if not opts.item.bufnr then
        return false
    end

    local lower_bufname = string.lower(vim.fn.bufname(opts.item.bufnr))
    return string.find(lower_bufname, opts.pattern, 1, true) and opts.keep or not opts.keep
end

--- @param opts QfRancherPredicateOpts
--- @return boolean
local function fname_sensitive(opts)
    opts = opts or {}
    if not opts.item.bufnr then
        return false
    end

    local bufname = vim.fn.bufname(opts.item.bufnr)
    return string.find(bufname, opts.pattern, 1, true) and opts.keep or not opts.keep
end

----------
-- Text --
----------

--- @param opts QfRancherPredicateOpts
--- @return boolean
local function text_regex(opts)
    opts = opts or {}
    return opts.regex:match_str(opts.item.text) and opts.keep or not opts.keep
end

--- @param opts QfRancherPredicateOpts
--- @return boolean
--- NOTE: Assumes pattern is all lowercase
local function text_insensitive(opts)
    opts = opts or {}
    local lower_text = string.lower(opts.item.text)
    return string.find(lower_text, opts.pattern, 1, true) and opts.keep or not opts.keep
end

--- @param opts QfRancherPredicateOpts
--- @return boolean
local function text_sensitive(opts)
    opts = opts or {}
    return string.find(opts.item.text, opts.pattern, 1, true) and opts.keep or not opts.keep
end

----------
-- Type --
----------

--- @param opts QfRancherPredicateOpts
--- @return boolean
local function type_regex(opts)
    opts = opts or {}
    return opts.regex:match_str(opts.item.type) and opts.keep or not opts.keep
end

--- @param opts QfRancherPredicateOpts
--- @return boolean
--- NOTE: Assumes pattern is all lowercase
local function type_insensitive(opts)
    opts = opts or {}
    local lower_type = string.lower(opts.item.type)
    return string.find(lower_type, opts.pattern, 1, true) and opts.keep or not opts.keep
end

--- @param opts QfRancherPredicateOpts
--- @return boolean
local function type_sensitive(opts)
    opts = opts or {}
    return string.find(opts.item.type, opts.pattern, 1, true) and opts.keep or not opts.keep
end

-----------------
-- Line Number --
-----------------

--- @type QfRancherPredicateFunc
local function lnum_regex(opts)
    opts = opts or {}
    return opts.regex:match_str(tostring(opts.item.lnum)) and opts.keep or not opts.keep
end

--- DOCUMENT: This compares exactly, vs the insensitive, which works like a contains function
--- @param opts QfRancherPredicateOpts
--- @return boolean
local function lnum_sensitive(opts)
    opts = opts or {}
    return tostring(opts.item.lnum) == opts.pattern and opts.keep or not opts.keep
end

--- @type QfRancherPredicateFunc
local function lnum_insensitive(opts)
    opts = opts or {}
    local found = string.find(tostring(opts.item.lnum), opts.pattern, 1, true)
    return found and opts.keep or not opts.keep
end

local filters = {
    cfilter = {
        name = "Cfilter",
        insensitive_func = cfilter_insensitive,
        sensitive_func = cfilter_sensitive,
        regex_func = cfilter_regex,
    },
    fname = {
        name = "Filename",
        insensitive_func = fname_insensitive,
        sensitive_func = fname_sensitive,
        regex_func = fname_regex,
    },
    lnum = {
        name = "lnum",
        insensitive_func = lnum_insensitive,
        sensitive_func = lnum_sensitive,
        regex_func = lnum_regex,
    },
    text = {
        name = "Text",
        insensitive_func = text_insensitive,
        sensitive_func = text_sensitive,
        regex_func = text_regex,
    },
    type = {
        name = "type",
        insensitive_func = type_insensitive,
        sensitive_func = type_sensitive,
        regex_func = type_regex,
    },
}

function M.get_filter_names()
    return vim.tbl_keys(filters)
end

-----------
--- API ---
-----------

--- @param filter_opts QfRancherFilterOpts
--- @param input_opts QfRancherInputOpts
--- @param what QfRancherWhat
--- @return nil
function M._filter(name, filter_opts, input_opts, what)
    if not filters[name] then
        vim.api.nvim_echo({ { "Invalid filter", "ErrorMsg" } }, true, { err = true })
    end

    M._filter_wrapper(filters[name], filter_opts, input_opts, what)
end

--- DOCUMENT: Improve this once everything's baked in
--- Register a filter to be used with the Qfilter/Lfilter commands. The filter will be registered
--- under the name in the filter info
--- filter_info:
--- - name? string - The display name of your filter
--- - insensitive_func - The predicate function used for case insensitive comparisons
--- - regex_func - The predicate function used for regex comparisons
--- - sensitive_func - The predicate function used for case sensitive comparisons
--- @param filter_info QfRancherFilterInfo
function M.register_filter(filter_info)
    filters[filter_info.name] = filter_info
end

--- Clears the function name from the registered sorts
--- @param name string
function M.clear_filter(name)
    if #vim.tbl_keys(filters) <= 1 then
        vim.api.nvim_echo({ { "Cannot remove the last filter method" } }, false, {})
        return
    end

    filters[name] = nil
end

--- @param cargs vim.api.keyset.create_user_command.command_args
--- @param list_win? integer
--- @return nil
local function filter_cmd(cargs, list_win)
    cargs = cargs or {}

    local fargs = cargs.fargs

    local filter_names = M.get_filter_names()
    assert(#filter_names > 1, "No filter functions available")
    local eu = require("mjm.error-list-util")
    local filter_name = eu._check_cmd_arg(fargs, filter_names, "cfilter")

    local filter_opts = { keep = not cargs.bang }

    local ey = require("mjm.error-list-types")
    local input_type = eu._check_cmd_arg(fargs, ey._cmd_input_types, ey._default_input_type)
    local pattern = eu._find_cmd_pattern(fargs)
    local input_opts = { input_type = input_type, pattern = pattern }

    local action = eu._check_cmd_arg(fargs, ey._actions, ey._default_action)
    local what = { nr = cargs.count, user_data = { action = action, list_win = list_win } }

    M._filter(filter_name, filter_opts, input_opts, what)
end

--- @param cargs vim.api.keyset.create_user_command.command_args
function M._q_filter(cargs)
    filter_cmd(cargs, nil)
end

--- @param cargs vim.api.keyset.create_user_command.command_args
function M._l_filter(cargs)
    filter_cmd(cargs, vim.api.nvim_get_current_win())
end

return M

-----------
--- MID ---
-----------

--- Make a filer for only valid error lines. (buf_is_valid or fname_is_valid) and (lnum or pattern)
