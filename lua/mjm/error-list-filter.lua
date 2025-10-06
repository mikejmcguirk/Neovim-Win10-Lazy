--- @class QfRancherFilter
local M = {}

-------------
--- TYPES ---
-------------

--- @class QfRancherFilterInfo
--- @field name? string
--- @field insensitive_func QfRancherPredicateFunc
--- @field regex_func QfRancherPredicateFunc
--- @field sensitive_func QfRancherPredicateFunc

--- @class QfRancherFilterOpts
--- @field keep? boolean

--- @class QfRancherPredicateOpts
--- @field item table
--- @field keep boolean
--- @field pattern? string
--- @field regex? vim.regex

--- @alias QfRancherPredicateFunc fun(QfRancherPredicateOpts):boolean

-------------------------
--- Wrapper Functions ---
-------------------------

--- @param filter_info QfRancherFilterInfo
--- @param filter_opts QfRancherFilterOpts
--- @param input_type QfRancherInputType
--- @return string
local function resolve_prompt(filter_info, filter_opts, input_type)
    local name = filter_info.name and filter_info.name .. " - " or ""
    local enter_prompt = filter_opts.keep and "Enter pattern to keep" or "Enter pattern to remove"
    local type = require("mjm.error-list-util")._get_display_input_type(input_type)
    return name .. enter_prompt .. " (" .. type .. "): "
end

--- @param filter_info QfRancherFilterInfo
--- @param filter_opts QfRancherFilterOpts
--- @param input_opts QfRancherInputOpts
--- @return QfRancherInputType|nil, string|nil, vim.regex|nil
local function get_predicate_info(filter_info, filter_opts, input_opts)
    local eu = require("mjm.error-list-util") --- @type QfRancherUtils

    local input_type = eu._resolve_input_type(input_opts.input_type) --- @type QfRancherInputType
    local prompt = resolve_prompt(filter_info, filter_opts, input_type) --- @type string
    local pattern = eu._resolve_pattern(prompt, input_opts)
    if not pattern then
        return nil, nil, nil
    end

    if input_type == "regex" then
        return input_type, pattern, vim.regex(pattern)
    end

    local lower_pattern = string.lower(pattern) --- @type string
    if input_type == "insensitive" then
        return input_type, lower_pattern, nil
    end

    -- Handle case sensitive and smartcase together
    if input_type == "sensitive" or lower_pattern ~= pattern then
        return "sensitive", pattern, nil
    else
        return input_type, lower_pattern, nil
    end
end

--- @param filter_info QfRancherFilterInfo
--- @param input_type QfRancherInputType
--- @param pattern string
--- @param regex vim.regex|nil
--- @return QfRancherPredicateFunc
local function get_predicate(filter_info, input_type, pattern, regex)
    if input_type == "regex" and regex then
        return filter_info.regex_func
    elseif input_type == "sensitive" then
        return filter_info.sensitive_func
    else
        assert(string.lower(pattern) == pattern)
        return filter_info.insensitive_func
    end
end

--- @param predicate QfRancherPredicateFunc
--- @param items table[]
--- @param pattern string
--- @param keep boolean
--- @param regex? table
--- @return table[]
local function iter_with_predicate(predicate, items, pattern, keep, regex)
    return vim.tbl_filter(function(t)
        return predicate({
            keep = keep,
            pattern = pattern,
            regex = regex,
            item = t,
        })
    end, items)
end

--- @param filter_info QfRancherFilterInfo
--- @param filter_opts QfRancherFilterOpts
--- @param input_opts QfRancherInputOpts
--- @param what QfRancherWhat
--- @return nil
local function validate_wrapper_input(filter_info, filter_opts, input_opts, what)
    vim.validate("filter_info", filter_info, "table")
    vim.validate("filter_info.insensitive_func", filter_info.insensitive_func, "callable")
    vim.validate("filter_info.name", filter_info.name, { "nil", "string" })
    vim.validate("filter_info.regex_func", filter_info.regex_func, "callable")
    vim.validate("filter_info.sensitive_func", filter_info.sensitive_func, "callable")

    vim.validate("filter_opts", filter_opts, "table")
    vim.validate("filter_opts.keep", filter_opts.keep, { "boolean", "nil" })

    local eu = require("mjm.error-list-util")
    eu._validate_input_opts(input_opts)
    require("mjm.error-list-validation")._validate_what_strict(what)
end

--- @param filter_info QfRancherFilterInfo
--- @param filter_opts QfRancherFilterOpts
--- @param input_opts QfRancherInputOpts
--- @param what QfRancherWhat
--- @return nil
function M.filter_wrapper(filter_info, filter_opts, input_opts, what)
    filter_info = filter_info or {}
    filter_opts = filter_opts or {}
    input_opts = input_opts or {}
    what = what or {}
    validate_wrapper_input(filter_info, filter_opts, input_opts, what)

    local eu = require("mjm.error-list-util") --- @type QfRancherUtils
    if not eu._win_can_have_loclist(what.user_data.list_win) then
        return
    end

    local et = require("mjm.error-list-tools") --- @type QfRancherTools
    local cur_list = et._get_list(what.user_data.list_win, what.nr, what) --- @type table
    if cur_list.size == 0 then
        vim.api.nvim_echo({ { "No entries to filter", "" } }, false, {})
        return
    end

    --- @type QfRancherInputType|nil, string|nil, vim.regex|nil
    local input_type, pattern, regex = get_predicate_info(filter_info, filter_opts, input_opts)
    if (not input_type) or not pattern then
        return
    end

    --- @type QfRancherPredicateFunc
    local predicate = get_predicate(filter_info, input_type, pattern, regex)
    --- @type table[], integer
    local new_items =
        iter_with_predicate(predicate, cur_list.items, pattern, filter_opts.keep, regex)

    local what_set = vim.tbl_deep_extend("force", what, {
        items = new_items,
        title = "Filter", --- TODO: Improve title
    }) --- @type QfRancherWhat

    et._set_list(
        what_set.user_data.list_win,
        what_set.user_data.nr,
        what_set.user_data.action,
        what_set
    )
end

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
    if opts.regex:match_str(bufname) then
        return opts.keep
    else
        return not opts.keep
    end
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
    if string.find(lower_bufname, opts.pattern, 1, true) ~= nil then
        return opts.keep
    else
        return not opts.keep
    end
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
    if string.find(bufname, opts.pattern, 1, true) ~= nil then
        return opts.keep
    else
        return not opts.keep
    end
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
    if opts.regex:match_str(bufname) then
        return opts.keep
    else
        return not opts.keep
    end
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
    if string.find(lower_bufname, opts.pattern, 1, true) ~= nil then
        return opts.keep
    else
        return not opts.keep
    end
end

--- @param opts QfRancherPredicateOpts
--- @return boolean
local function fname_sensitive(opts)
    opts = opts or {}
    if not opts.item.bufnr then
        return false
    end

    local bufname = vim.fn.bufname(opts.item.bufnr)
    if string.find(bufname, opts.pattern, 1, true) ~= nil then
        return opts.keep
    else
        return not opts.keep
    end
end

----------
-- Text --
----------

--- @param opts QfRancherPredicateOpts
--- @return boolean
local function text_regex(opts)
    opts = opts or {}
    if opts.regex:match_str(opts.item.text) then
        return opts.keep
    else
        return not opts.keep
    end
end

--- @param opts QfRancherPredicateOpts
--- @return boolean
--- NOTE: Assumes pattern is all lowercase
local function text_insensitive(opts)
    opts = opts or {}
    local lower_text = string.lower(opts.item.text)
    if string.find(lower_text, opts.pattern, 1, true) ~= nil then
        return opts.keep
    else
        return not opts.keep
    end
end

--- @param opts QfRancherPredicateOpts
--- @return boolean
local function text_sensitive(opts)
    opts = opts or {}
    if string.find(opts.item.text, opts.pattern, 1, true) ~= nil then
        return opts.keep
    else
        return not opts.keep
    end
end

----------
-- Type --
----------

--- @param opts QfRancherPredicateOpts
--- @return boolean
local function type_regex(opts)
    opts = opts or {}
    if opts.regex:match_str(opts.item.type) then
        return opts.keep
    else
        return not opts.keep
    end
end

--- @param opts QfRancherPredicateOpts
--- @return boolean
--- NOTE: Assumes pattern is all lowercase
local function type_insensitive(opts)
    opts = opts or {}
    local lower_type = string.lower(opts.item.type)
    if string.find(lower_type, opts.pattern, 1, true) ~= nil then
        return opts.keep
    else
        return not opts.keep
    end
end

--- @param opts QfRancherPredicateOpts
--- @return boolean
local function type_sensitive(opts)
    opts = opts or {}
    if string.find(opts.item.type, opts.pattern, 1, true) ~= nil then
        return opts.keep
    else
        return not opts.keep
    end
end

-----------------
-- Line Number --
-----------------

--- @type QfRancherPredicateFunc
local function lnum_regex(opts)
    opts = opts or {}
    if opts.regex:match_str(tostring(opts.item.lnum)) then
        return opts.keep
    else
        return not opts.keep
    end
end

--- @param opts QfRancherPredicateOpts
--- @return boolean
local function lnum_sensitive(opts)
    opts = opts or {}
    if tostring(opts.item.lnum) == opts.pattern then
        return opts.keep
    else
        return not opts.keep
    end
end

--- @type QfRancherPredicateFunc
local function lnum_insensitive(opts)
    opts = opts or {}
    if string.find(tostring(opts.item.lnum), opts.pattern, 1, true) ~= nil then
        return opts.keep
    else
        return not opts.keep
    end
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

--- Run a registered filter
--- name: Name of the filter to use
--- filter_opts
--- - keep? boolean - Whether to keep items that match the predicate function
--- input_opts
--- - input_type? "insensitive"|"regex"|"sensitive"|"smart"|"vimsmart" - How to interpret the
---     input for matching
--- - pattern? string - the pattern to match against
--- what.user_data
--- - action? "new"|"replace"|"add" - Create a new list, replace a pre-existing one, or add a new
---     one
--- - list_win? integer - If not nil, output to that window's location list
--- @param filter_opts QfRancherFilterOpts
--- @param input_opts QfRancherInputOpts
--- @param what QfRancherWhat
--- @return nil
function M.filter(name, filter_opts, input_opts, what)
    if not filters[name] then
        vim.api.nvim_echo({ { "Invalid filter", "ErrorMsg" } }, true, { err = true })
    end

    M.filter_wrapper(filters[name], filter_opts, input_opts, what)
end

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

--- Run a filter without registering it
--- filter_info:
--- - name? string - The display name of your filter
--- - insensitive_func - The predicate function used for case insensitive comparisons
--- - regex_func - The predicate function used for regex comparisons
--- - sensitive_func - The predicate function used for case sensitive comparisons
--- filter_opts
--- - keep? boolean - Whether to keep items that match the predicate function
--- input_opts
--- - input_type? "insensitive"|"regex"|"sensitive"|"smart"|"vimsmart" - How to interpret the
---     input for matching
--- - pattern? string - the pattern to match against
--- what.user_data
--- - action? "new"|"replace"|"add" - Create a new list, replace a pre-existing one, or add a new
---     one
--- - list_win? integer - If not nil, output to that window's location list
--- @param filter_info QfRancherFilterInfo
--- @param filter_opts QfRancherFilterOpts
--- @param input_opts QfRancherInputOpts
--- @param what QfRancherWhat
--- @return nil
function M.adhoc_filter(filter_info, filter_opts, input_opts, what)
    M.filter_wrapper(filter_info, filter_opts, input_opts, what)
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
    local filter_func = eu._check_cmd_arg(fargs, filter_names, "cfilter")
    local ev = require("mjm.error-list-validation")
    local keep_this = not cargs.bang
    local action = eu._check_cmd_arg(fargs, ev._actions, ev._default_action)
    local pattern = eu._find_cmd_pattern(fargs)
    local count = cargs.count > 0 and cargs.count or nil

    local filter_opts = { keep = keep_this }
    -- TODO: is this right the right way to handle input type?
    local input_opts = { input_type = pattern and "regex" or "vimsmart", pattern = pattern }
    local what = { nr = count, user_data = { action = action, list_win = list_win } }

    M.filter(filter_func, filter_opts, input_opts, what)
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

------------
--- TODO ---
------------

--- Make a filer for only valid error lines. (buf_is_valid or fname_is_valid) and (lnum or pattern)
