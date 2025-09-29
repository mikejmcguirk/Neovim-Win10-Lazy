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
local function resolve_prompt(filter_info, filter_opts, input_type)
    local name = filter_info.name and filter_info.name .. " - " or ""
    local enter_prompt = filter_opts.keep and "Enter pattern to keep" or "Enter pattern to remove"
    local type = require("mjm.error-list-util").get_display_input_type(input_type)
    return name .. enter_prompt .. " (" .. type .. "): "
end

--- @param filter_info QfRancherFilterInfo
--- @param filter_opts QfRancherFilterOpts
--- @param input_opts QfRancherInputOpts
--- @return QfRancherInputType|nil, string|nil, vim.regex|nil
local function get_predicate_info(filter_info, filter_opts, input_opts)
    local eu = require("mjm.error-list-util") --- @type QfRancherUtils

    local input_type = eu.resolve_input_type(input_opts.input_type) --- @type QfRancherInputType
    local pattern = input_opts.pattern and input_opts.pattern
        or eu.get_input(resolve_prompt(filter_info, filter_opts, input_type)) --- @type string|nil
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
local function clean_wrapper_input(filter_info, filter_opts, input_opts, output_opts)
    filter_info = filter_info or {}
    filter_opts = filter_opts or {}
    input_opts = input_opts or {}
    output_opts = output_opts or {}

    vim.validate("filter_info", filter_info, "table")
    vim.validate("filter_info.insensitive_func", filter_info.insensitive_func, "callable")
    vim.validate("filter_info.name", filter_info.name, { "nil", "string" })
    vim.validate("filter_info.regex_func", filter_info.regex_func, "callable")
    vim.validate("filter_info.sensitive_func", filter_info.sensitive_func, "callable")

    vim.validate("filter_opts", filter_opts, "table")
    vim.validate("filter_opts.keep", filter_opts.keep, { "boolean", "nil" })
    filter_opts.keep = filter_opts.keep or true

    vim.validate("input_opts", input_opts, "table")
    vim.validate("input_opts.pattern", input_opts.pattern, { "nil", "string" })
    vim.validate("input_opts.input_type", input_opts.input_type, { "nil", "string" })
    if type(input_opts.input_type) == "string" then
        vim.validate("input_opts.input_type", input_opts.input_type, function()
            return require("mjm.error-list-util").validate_input_type(input_opts.input_type)
        end)
    else
        input_opts.input_type = "vimsmart"
    end

    vim.validate("output_opts", output_opts, "table")
    vim.validate("output_opts.is_loclist", output_opts.is_loclist, { "nil", "boolean" })
    output_opts.is_loclist = output_opts.is_loclist or false
    vim.validate("output_opts.action", output_opts.action, { "nil", "string" })
    if type(output_opts.action) == "string" then
        vim.validate("action", output_opts.action, function()
            return require("mjm.error-list-util").validate_action(output_opts.action)
        end)
    else
        output_opts.action = "new" --- Cfilter default
    end
end

--- @param filter_info QfRancherFilterInfo
--- @param filter_opts QfRancherFilterOpts
--- @param input_opts QfRancherInputOpts
--- @param output_opts QfRancherOutputOpts
--- @return nil
function M.filter_wrapper(filter_info, filter_opts, input_opts, output_opts)
    clean_wrapper_input(filter_info, filter_opts, input_opts, output_opts)

    local eu = require("mjm.error-list-util") --- @type QfRancherUtils
    local getlist = eu.get_getlist({ is_loclist = output_opts.is_loclist }) --- @type function
    local cur_list = getlist({ all = true }) --- @type table
    if cur_list.size == 0 then
        vim.api.nvim_echo({ { "No entries to filter", "" } }, false, {})
        return
    end

    local dest_list_nr = eu.get_dest_list_nr(getlist, output_opts.action) --- @type integer
    local list_win = eu.find_list_win(output_opts.is_loclist) --- @type integer|nil
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

    local setlist = eu.get_setlist(output_opts.is_loclist) --- @type function
    eu.set_list_items(getlist, setlist, dest_list_nr, new_items, output_opts.action, "Filter")

    if list_win and view then
        view.topline = math.max(view.topline - view_rows_removed, 0)
        view.lnum = math.max(view.lnum - view_rows_removed, 1)
        vim.api.nvim_win_call(list_win, function()
            vim.fn.winrestview(view)
        end)
    end

    eu.get_openlist(output_opts.is_loclist)({ always_resize = true })
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

local cfilter_info = {
    name = "Cfilter",
    insensitive_func = cfilter_insensitive,
    sensitive_func = cfilter_sensitive,
    regex_func = cfilter_regex,
}

--- @param filter_opts QfRancherFilterOpts
--- @param input_opts QfRancherInputOpts
--- @param output_opts QfRancherOutputOpts
--- NOTE: Don't do data validation here. This is just a pass through between API callers and the
--- filer_wrapper function
function M.cfilter(filter_opts, input_opts, output_opts)
    M.filter_wrapper(cfilter_info, filter_opts, input_opts, output_opts)
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

local fname_info = {
    name = "Filename",
    insensitive_func = fname_insensitive,
    sensitive_func = fname_sensitive,
    regex_func = fname_regex,
}

function M.fname(filter_opts, input_opts, output_opts)
    M.filter_wrapper(fname_info, filter_opts, input_opts, output_opts)
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

local text_info = {
    name = "Text",
    insensitive_func = text_insensitive,
    sensitive_func = text_sensitive,
    regex_func = text_regex,
}

--- @param filter_opts QfRancherFilterOpts
--- @param input_opts QfRancherInputOpts
--- @param output_opts QfRancherOutputOpts
--- NOTE: Don't do data validation here. This is just a pass through between API callers and the
--- filer_wrapper function
function M.text(filter_opts, input_opts, output_opts)
    M.filter_wrapper(text_info, filter_opts, input_opts, output_opts)
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

local type_info = {
    name = "type",
    insensitive_func = type_insensitive,
    sensitive_func = type_sensitive,
    regex_func = type_regex,
}

--- @param filter_opts QfRancherFilterOpts
--- @param input_opts QfRancherInputOpts
--- @param output_opts QfRancherOutputOpts
--- NOTE: Don't do data validation here. This is just a pass through between API callers and the
--- filer_wrapper function
function M.type(filter_opts, input_opts, output_opts)
    M.filter_wrapper(type_info, filter_opts, input_opts, output_opts)
end

-----------------
-- Line Number --
-----------------

--- @type QfRancherPredicateFunc
local function lnum_regex(opts)
    opts = opts or {}
    if opts.regex:match_str(opts.item.lnum) then
        return opts.keep
    else
        return not opts.keep
    end
end

--- @param opts QfRancherPredicateOpts
--- @return boolean
local function lnum_sensitive(opts)
    opts = opts or {}
    if string.find(opts.item.lnum, opts.pattern, 1, true) ~= nil then
        return opts.keep
    else
        return not opts.keep
    end
end

local lnum_info = {
    name = "lnum",
    insensitive_func = lnum_sensitive,
    sensitive_func = lnum_sensitive,
    regex_func = lnum_regex,
}

--- @param filter_opts QfRancherFilterOpts
--- @param input_opts QfRancherInputOpts
--- @param output_opts QfRancherOutputOpts
--- NOTE: Don't do data validation here. This is just a pass through between API callers and the
--- filer_wrapper function
function M.lnum(filter_opts, input_opts, output_opts)
    M.filter_wrapper(lnum_info, filter_opts, input_opts, output_opts)
end

-------------------
--- General API ---
-------------------

--- @param filter_info QfRancherFilterInfo
--- @param filter_opts QfRancherFilterOpts
--- @param input_opts QfRancherInputOpts
--- @param output_opts QfRancherOutputOpts
--- Create your own filter.
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
function M.filter(filter_info, filter_opts, input_opts, output_opts)
    M.filter_wrapper(filter_info, filter_opts, input_opts, output_opts)
end

return M
