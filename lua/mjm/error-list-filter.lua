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
--- @param view_row integer
--- @param regex? table
--- @return table[], integer
local function iter_with_predicate(predicate, items, pattern, keep, view_row, regex)
    local view_rows_removed = 0 --- @type integer
    local new_items = {} --- @type table[]
    for i, item in ipairs(items) do
        local predicate_opts = {
            keep = keep,
            pattern = pattern,
            regex = regex,
            item = item,
        } --- @type QfRancherPredicateOpts

        if predicate(predicate_opts) then
            table.insert(new_items, item)
        elseif i < view_row then
            view_rows_removed = view_rows_removed + 1
        end
    end

    return new_items, view_rows_removed
end

--- @param filter_info QfRancherFilterInfo
--- @param filter_opts QfRancherFilterOpts
--- @param input_opts QfRancherInputOpts
--- @param output_opts QfRancherOutputOpts
--- @return nil
local function validate_wrapper_input(filter_info, filter_opts, input_opts, output_opts)
    vim.validate("filter_info", filter_info, "table")
    vim.validate("filter_info.insensitive_func", filter_info.insensitive_func, "callable")
    vim.validate("filter_info.name", filter_info.name, { "nil", "string" })
    vim.validate("filter_info.regex_func", filter_info.regex_func, "callable")
    vim.validate("filter_info.sensitive_func", filter_info.sensitive_func, "callable")

    vim.validate("filter_opts", filter_opts, "table")
    vim.validate("filter_opts.keep", filter_opts.keep, { "boolean", "nil" })

    local eu = require("mjm.error-list-util")
    eu._validate_input_opts(input_opts)
    eu._validate_output_opts(output_opts)
end

--- TODO: Keeping this for now because I don't know how things shake out after the output
--- validation is broken up
--- @param filter_info QfRancherFilterInfo
--- @param filter_opts QfRancherFilterOpts
--- @param input_opts QfRancherInputOpts
--- @param output_opts QfRancherOutputOpts
--- @return nil
local function clean_wrapper_input(filter_info, filter_opts, input_opts, output_opts)
    filter_opts.keep = filter_opts.keep == nil and true or filter_opts.keep
end

--- @param filter_info QfRancherFilterInfo
--- @param filter_opts QfRancherFilterOpts
--- @param input_opts QfRancherInputOpts
--- @param output_opts QfRancherOutputOpts
--- @return nil
function M.filter_wrapper(filter_info, filter_opts, input_opts, output_opts)
    filter_info = filter_info or {}
    filter_opts = filter_opts or {}
    input_opts = input_opts or {}
    output_opts = output_opts or {}
    validate_wrapper_input(filter_info, filter_opts, input_opts, output_opts)
    clean_wrapper_input(filter_info, filter_opts, input_opts, output_opts)

    local eu = require("mjm.error-list-util") --- @type QfRancherUtils
    if not eu._is_valid_loclist_output(output_opts) then
        return
    end

    local getlist = eu._get_getlist(output_opts) --- @type function|nil
    if not getlist then
        return
    end

    local cur_list = getlist({ all = true }) --- @type table
    if cur_list.size == 0 then
        vim.api.nvim_echo({ { "No entries to filter", "" } }, false, {})
        return
    end

    local setlist = eu._get_setlist(output_opts) --- @type function|nil
    if not setlist then
        return
    end

    -- TODO: Redundant with upated set_list_items, but unsure how to get rid of this because
    -- it blocks the unnecessary saving of a view. But, since saving the view is the typical
    -- case, maybe this isn't worth the check. The big issue anyway, AFAIK, is restoring the view
    -- rather than saving it
    -- TODO: This is a kind of slop that's starting to creep up in the code in general, where
    -- vestigal pieces of data are accumulating. Clean these out
    --
    -- TODO: There might be a better way to do this - Filtering the list can resize it, or if
    -- we switch to a new list, that can also cause a resize. So we would want to store views
    -- in that chain somehow. So it would be something like, we make a views table here and pass
    -- it through to the opening function. You could do something where, when getting views, you
    -- check the views list to see if the win is already there.
    local dest_list_nr = eu._get_dest_list_nr(getlist, output_opts) --- @type integer
    local list_win = eu._find_list_win(output_opts) --- @type integer|nil
    local view = (list_win and dest_list_nr == cur_list.nr)
            and vim.api.nvim_win_call(list_win, vim.fn.winsaveview)
        or nil --- @type vim.fn.winsaveview.ret|nil

    --- @type QfRancherInputType|nil, string|nil, vim.regex|nil
    local input_type, pattern, regex = get_predicate_info(filter_info, filter_opts, input_opts)
    if (not input_type) or not pattern then
        return
    end

    --- @type QfRancherPredicateFunc
    local predicate = get_predicate(filter_info, input_type, pattern, regex)
    local view_row = view and view.lnum or 0 --- @type integer
    --- @type table[], integer
    local new_items, view_rows_removed =
        iter_with_predicate(predicate, cur_list.items, pattern, filter_opts.keep, view_row, regex)

    output_opts.title = "Filter" -- TODO: This can be improved
    eu._set_list_items(
        { getlist = getlist, setlist = setlist, new_items = new_items },
        output_opts
    )

    if list_win and view then
        view.topline = math.max(view.topline - view_rows_removed, 0)
        view.lnum = math.max(view.lnum - view_rows_removed, 1)
        vim.api.nvim_win_call(list_win, function()
            vim.fn.winrestview(view)
        end)
    end
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
--- output_opts
--- - action? "new"|"replace"|"add" - Create a new list, replace a pre-existing one, or add a new
---     one
--- - is_loclist? boolean - Whether to filter against a location list
--- @param filter_opts QfRancherFilterOpts
--- @param input_opts QfRancherInputOpts
--- @param output_opts QfRancherOutputOpts
--- @return nil
function M.filter(name, filter_opts, input_opts, output_opts)
    if not filters[name] then
        vim.api.nvim_echo({ { "Invalid filter", "ErrorMsg" } }, true, { err = true })
    end

    M.filter_wrapper(filters[name], filter_opts, input_opts, output_opts)
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
--- output_opts
--- - action? "new"|"replace"|"add" - Create a new list, replace a pre-existing one, or add a new
---     one
--- - is_loclist? boolean - Whether to filter against a location list
--- @param filter_info QfRancherFilterInfo
--- @param filter_opts QfRancherFilterOpts
--- @param input_opts QfRancherInputOpts
--- @param output_opts QfRancherOutputOpts
--- @return nil
function M.adhoc_filter(filter_info, filter_opts, input_opts, output_opts)
    M.filter_wrapper(filter_info, filter_opts, input_opts, output_opts)
end

return M

------------
--- TODO ---
------------

--- Make a filer for only valid error lines. (buf_is_valid or fname_is_valid) and (lnum or pattern)
