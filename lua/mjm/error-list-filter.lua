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
    vim.validate("name", name, "string")
    vim.validate("keep", keep, "boolean")
    require("mjm.error-list-types")._validate_input_type(input_type)

    local enter_prompt = "Enter pattern to " .. (keep and "keep" or "remove") --- @type string
    --- @type string
    local type = require("mjm.error-list-util")._get_display_input_type(input_type)
    return name .. ": " .. enter_prompt .. " (" .. type .. "): "
end

--- @param filter_info QfRancherFilterInfo
--- @param input_type QfRancherInputType
--- @param regex vim.regex|nil
--- @return QfRancherPredicateFunc
local function get_predicate(filter_info, input_type, regex)
    local ey = require("mjm.error-list-types")
    ey._validate_filter_info(filter_info)
    ey._validate_input_type(input_type)
    --- LOW: Validate regex

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
    filter_info = filter_info or {}
    filter_opts = filter_opts or {}
    input_opts = input_opts or {}
    what = what or {}

    local ey = require("mjm.error-list-types")
    ey._validate_filter_info(filter_info)
    ey._validate_filter_opts(filter_opts)
    ey._validate_input_opts(input_opts)
    ey._validate_what(what)
end

--- @param filter_info QfRancherFilterInfo
--- @param filter_opts QfRancherFilterOpts
--- @param input_opts QfRancherInputOpts
--- @param what QfRancherWhat
--- @return nil
function M._filter_wrapper(filter_info, filter_opts, input_opts, what)
    validate_wrapper_input(filter_info, filter_opts, input_opts, what)

    local src_win = what.user_data.src_win --- @type integer|nil
    local eu = require("mjm.error-list-util") --- @type QfRancherUtil
    if src_win and not eu._valid_win_for_loclist(what.user_data.src_win) then
        local msg = "Win " .. src_win .. " cannot have a location list"
        vim.api.nvim_echo({ { msg, "" } }, false, {})
        return
    end

    local et = require("mjm.error-list-tools") --- @type QfRancherTools
    local cur_list = et._get_list_all(src_win, what.nr) --- @type table
    if cur_list.size == 0 then
        vim.api.nvim_echo({ { "No entries to filter", "" } }, false, {})
        return
    end

    local input_type = eu._resolve_input_type(input_opts.input_type) --- @type QfRancherInputType
    local prompt = get_prompt(filter_info.name, filter_opts.keep, input_type) --- @type string
    --- @type string|nil
    local pattern = eu._resolve_pattern(prompt, input_opts.pattern, input_type)
    if not pattern then return end

    local regex = input_type == "regex" and vim.regex(pattern) or nil --- @type vim.regex|nil
    local lower_pattern = string.lower(pattern) --- @type string
    --- LOW: The real issue here is that the predicate types are a distinct thing
    if input_type == "smartcase" then
        local is_smart_pattern = lower_pattern == pattern --- @type boolean
        input_type = is_smart_pattern and "insensitive" or "sensitive"
        pattern = is_smart_pattern and lower_pattern or pattern
    end

    --- @type QfRancherPredicateFunc
    local predicate = get_predicate(filter_info, input_type, regex)
    local keep = filter_opts.keep
    local new_items = vim.tbl_filter(function(t)
        return predicate(t, keep, { pattern = pattern, regex = regex })
    end, cur_list.items) --- @type vim.quickfix.entry[]

    local what_set = vim.tbl_deep_extend("force", what, {
        idx = math.min(#new_items, cur_list.idx),
        items = new_items,
        title = filter_info.name .. " filter: /" .. pattern,
    }) --- @type QfRancherWhat

    local dest_nr = et._set_list(src_win, what_set) --- @type integer
    if eu._get_g_var("qf_rancher_auto_open_changes") then
        require("mjm.error-list-stack")._history(what_set.user_data.src_win, dest_nr, {
            always_open = true,
            default = "current",
            silent = true,
        })
    end
end

--- NOTE: In line with Cfilter and the C code, bufname() is used for checking filenames
--- NOTE: x and y or z ternaries only work if y is truthy. Because keep can be either, don't use
---     ternaries here
--- LOW: Would like to eliminate the opts table from these functions entirely, but I'm not sure
---     what a less contrived way is to handle the possibilty of either pattern or regex being
---     sent to the predicate function

-------------------------
--- BOILERPLATE LOGIC ---
-------------------------

--- @param regex vim.regex
--- @param comparison string
--- @param keep boolean
--- @return boolean
local function regex_boilerplate(regex, comparison, keep)
    if regex:match_str(comparison) then
        return keep
    else
        return not keep
    end
end

--- @param pattern string
--- @param comparison string
--- @param keep boolean
--- @return boolean
local function insensitive_boilerplate(pattern, comparison, keep)
    local lower = string.lower(comparison) --- @type string
    if string.find(lower, pattern, 1, true) then
        return keep
    else
        return not keep
    end
end

--- @param pattern string
--- @param comparison string
--- @param keep boolean
--- @return boolean
local function sensitive_boilerplate(pattern, comparison, keep)
    if string.find(comparison, pattern, 1, true) then
        return keep
    else
        return not keep
    end
end

-----------------------
-- Cfilter Emulation --
-----------------------

--- @type QfRancherPredicateFunc
local function cfilter_regex(item, keep, opts)
    opts = opts or {}
    if regex_boilerplate(opts.regex, item.text, keep) == keep then return keep end

    if not item.bufnr then return false end

    return regex_boilerplate(opts.regex, vim.fn.bufname(item.bufnr), keep)
end

--- @type QfRancherPredicateFunc
--- NOTE: Assumes pattern is all lowercase
local function cfilter_insensitive(item, keep, opts)
    opts = opts or {}
    if insensitive_boilerplate(opts.pattern, item.text, keep) == keep then return keep end

    if not item.bufnr then return false end

    return insensitive_boilerplate(opts.pattern, vim.fn.bufname(item.bufnr), keep)
end

--- @type QfRancherPredicateFunc
local function cfilter_sensitive(item, keep, opts)
    opts = opts or {}
    if sensitive_boilerplate(opts.pattern, item.text, keep) == keep then return keep end

    if not opts.bufnr then return false end

    return sensitive_boilerplate(opts.pattern, vim.fn.bufname(item.bufnr), keep)
end

--------------
-- Filename --
--------------

--- @type QfRancherPredicateFunc
local function fname_regex(item, keep, opts)
    opts = opts or {}
    if not item.bufnr then return false end

    return regex_boilerplate(opts.regex, vim.fn.bufname(item.bufnr), keep)
end

--- @type QfRancherPredicateFunc
--- NOTE: Assumes pattern is all lowercase
local function fname_insensitive(item, keep, opts)
    opts = opts or {}
    if not item.bufnr then return false end

    return insensitive_boilerplate(opts.pattern, vim.fn.bufname(item.bufnr), keep)
end

--- @type QfRancherPredicateFunc
local function fname_sensitive(item, keep, opts)
    opts = opts or {}
    if not item.bufnr then return false end

    return sensitive_boilerplate(opts.pattern, vim.fn.bufname(item.bufnr), keep)
end

----------
-- Text --
----------

--- @type QfRancherPredicateFunc
local function text_regex(item, keep, opts)
    opts = opts or {}
    return regex_boilerplate(opts.regex, item.text, keep)
end

--- @type QfRancherPredicateFunc
--- NOTE: Assumes pattern is all lowercase
local function text_insensitive(item, keep, opts)
    opts = opts or {}
    return insensitive_boilerplate(opts.pattern, item.text, keep)
end

--- @type QfRancherPredicateFunc
local function text_sensitive(item, keep, opts)
    opts = opts or {}
    return sensitive_boilerplate(opts.pattern, item.text, keep)
end

----------
-- Type --
----------

--- @type QfRancherPredicateFunc
local function type_regex(item, keep, opts)
    opts = opts or {}
    return regex_boilerplate(opts.regex, item.type, keep)
end

--- NOTE: Assumes pattern is all lowercase
--- @type QfRancherPredicateFunc
local function type_insensitive(item, keep, opts)
    opts = opts or {}
    return insensitive_boilerplate(opts.pattern, item.type, keep)
end

--- @type QfRancherPredicateFunc
local function type_sensitive(item, keep, opts)
    opts = opts or {}
    return sensitive_boilerplate(opts.pattern, item.type, keep)
end

-----------------
-- Line Number --
-----------------

--- @type QfRancherPredicateFunc
local function lnum_regex(item, keep, opts)
    opts = opts or {}
    return regex_boilerplate(opts.regex, tostring(item.lnum), keep)
end

--- DOCUMENT: This compares exactly, vs the insensitive, which works like a contains function
--- @type QfRancherPredicateFunc
local function lnum_sensitive(item, keep, opts)
    opts = opts or {}
    if tostring(item.lnum) == opts.pattern then
        return keep
    else
        return not keep
    end
end

--- @type QfRancherPredicateFunc
local function lnum_insensitive(item, keep, opts)
    opts = opts or {}
    return insensitive_boilerplate(opts.pattern, tostring(item.lnum), keep)
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
        name = "Lnum",
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
        name = "Type",
        insensitive_func = type_insensitive,
        sensitive_func = type_sensitive,
        regex_func = type_regex,
    },
} --- @type table<string, QfRancherFilterInfo>

--- @return string[]
function M.get_filter_names()
    return vim.tbl_keys(filters)
end

-----------
--- API ---
-----------

--- DOCUMENT: this. Needed if you want to map your filter

--- @param name string
--- @param filter_opts QfRancherFilterOpts
--- @param input_opts QfRancherInputOpts
--- @param what QfRancherWhat
--- @return nil
function M.filter(name, filter_opts, input_opts, what)
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
--- @return nil
function M.register_filter(filter_info)
    filters[filter_info.name] = filter_info
end

--- Clears the function name from the registered sorts
--- DOCUMENT: How this works
--- @param name string
--- @return nil
function M.clear_filter(name)
    if #vim.tbl_keys(filters) <= 1 then
        vim.api.nvim_echo({ { "Cannot remove the last filter method" } }, false, {})
        return
    end

    if filters[name] then
        filters[name] = nil
        vim.api.nvim_echo({ { name .. " removed from filter list", "" } }, true, {})
    else
        vim.api.nvim_echo({ { name .. " is not a registered filter", "" } }, true, {})
    end
end

--- @param cargs vim.api.keyset.create_user_command.command_args
--- @param src_win? integer
--- @return nil
local function filter_cmd(cargs, src_win)
    cargs = cargs or {}
    local fargs = cargs.fargs --- @type string[]

    local filter_names = M.get_filter_names() --- @type string[]
    assert(#filter_names > 1, "No filter functions available")
    local eu = require("mjm.error-list-util") --- @type QfRancherUtil
    local filter_name = eu._check_cmd_arg(fargs, filter_names, "cfilter") --- @type string

    local filter_opts = { keep = not cargs.bang } --- @type QfRancherFilterOpts

    local ey = require("mjm.error-list-types") --- @type QfRancherTypes
    --- @type QfRancherInputType
    local input_type = eu._check_cmd_arg(fargs, ey._cmd_input_types, ey._default_input_type)
    local pattern = eu._find_cmd_pattern(fargs) --- @type string|nil
    --- @type QfRancherInputOpts
    local input_opts = { input_type = input_type, pattern = pattern }

    --- @type QfRancherAction
    local action = eu._check_cmd_arg(fargs, ey._actions, ey._default_action)
    --- @type QfRancherWhat
    local what = { nr = cargs.count, user_data = { action = action, src_win = src_win } }

    M.filter(filter_name, filter_opts, input_opts, what)
end

--- @param cargs vim.api.keyset.create_user_command.command_args
--- @return nil
function M._q_filter(cargs)
    filter_cmd(cargs, nil)
end

--- @param cargs vim.api.keyset.create_user_command.command_args
--- @return nil
function M._l_filter(cargs)
    filter_cmd(cargs, vim.api.nvim_get_current_win())
end

return M

------------
--- TODO ---
------------

--- Tests
--- Docs

-----------
--- MID ---
-----------

--- Make a filer for only valid error lines. (buf_is_valid or fname_is_valid) and (lnum or pattern)
--- - With this, make an additional entry validation to check for valid errors only
--- Make a filter for dotfiles/hidden files
--- do qkie and so on syntactic sugar mappings for diagnostics

-----------
--- LOW ---
-----------

--- Depending on how some of the more niche sorts are used, add different default sorts to the
---     filter_opts field
--- Look again and how Cfilter works

----------------
--- DOCUMENT ---
----------------

---Document specifically that a cfilter emulation is available
