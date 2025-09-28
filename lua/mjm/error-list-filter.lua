local M = {}

-------------
--- TYPES ---
-------------

--- @alias QfRancherAction "new"|"replace"|"add"
--- @alias QfRancherInputType "insensitive"|"regex"|"sensitive"|"smart"|"vimsmart"
--- @alias QfRancherFilterFunc fun(
--- table, string, boolean, QfRancherInputType, integer, vim.regex): table[], integer

--- @class QfRancherFilterInfo
--- @field name? string
--- @field func QfRancherFilterFunc

--- @class QfRancherFilterOpts
--- @field keep? boolean

--- @class QfRancherFilterPredicateOpts
--- @field bufnr? integer
--- @field keep boolean
--- @field pattern? string
--- @field regex? vim.regex
--- @field text? string

--- TODO: These should be moved to a general file

--- @class QfRancherInputOpts
--- @field input_type? QfRancherInputType
--- @field pattern? string
---
--- @class QfRancherOutputOpts
--- @field action? QfRancherAction
--- @field is_loclist? boolean
---
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
--- @return string|nil, QfRancherInputType|nil, vim.regex|nil
local function get_predicate_info(filter_info, filter_opts, input_opts)
    local eu = require("mjm.error-list-util") --- @type QfRancherUtils

    local input_type = eu.resolve_input_type(input_opts.input_type) --- @type QfRancherInputType
    local pattern = input_opts.pattern and input_opts.pattern
        or eu.get_input(resolve_prompt(filter_info, filter_opts, input_type)) --- @type string|nil
    if not pattern then
        return nil, nil, nil
    end

    if input_type == "regex" then
        return pattern, input_type, vim.regex(pattern)
    end

    local lower_pattern = string.lower(pattern) --- @type string
    if input_type == "insensitive" then
        return lower_pattern, input_type, nil
    end

    -- Handle case sensitive and smartcase together
    if input_type == "sensitive" or lower_pattern ~= pattern then
        return pattern, "sensitive", nil
    else
        return lower_pattern, input_type, nil
    end
end

--- @param filter_info QfRancherFilterInfo
--- @param filter_opts QfRancherFilterOpts
--- @param input_opts QfRancherInputOpts
--- @param output_opts QfRancherOutputOpts
--- @return nil
--- NOTE: Since the inputs come from API calls, perform all validations regardless of debug
--- settings
local function validate_filter_wrapper(filter_info, filter_opts, input_opts, output_opts)
    vim.validate("filter_info", filter_info, "table")
    vim.validate("filter_info.name", filter_info.name, { "nil", "string" })
    vim.validate("filter_info.func", filter_info.func, "callable")

    vim.validate("filter_opts", filter_opts, "table")
    vim.validate("filter_opts.keep", filter_opts.keep, { "boolean", "nil" })

    vim.validate("input_opts", input_opts, "table")
    vim.validate("input_opts.pattern", input_opts.pattern, { "nil", "string" })
    vim.validate("input_opts.input_type", input_opts.input_type, { "nil", "string" })
    if type(input_opts.input_type) == "string" then
        vim.validate("input_opts.input_type", input_opts.input_type, function()
            return require("mjm.error-list-util").validate_input_type(input_opts.input_type)
        end)
    end

    vim.validate("output_opts", output_opts, "table")
    vim.validate("output_opts.is_loclist", output_opts.is_loclist, { "nil", "boolean" })
    vim.validate("output_opts.action", output_opts.action, { "nil", "string" })
    if type(output_opts.action) == "string" then
        vim.validate("action", output_opts.action, function()
            return require("mjm.error-list-util").validate_action(output_opts.action)
        end)
    end
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
    validate_filter_wrapper(filter_info, filter_opts, input_opts, output_opts)

    local eu = require("mjm.error-list-util") --- @type QfRancherUtils
    local getlist = eu.get_getlist({ is_loclist = output_opts.is_loclist }) --- @type function
    local cur_list = getlist({ all = true }) --- @type table
    if cur_list.size == 0 then
        vim.api.nvim_echo({ { "No entries to filter", "" } }, false, {})
        return
    end

    --- @return string|nil, QfRancherInputType|nil, vim.regex|nil
    local pattern, input_type, regex = get_predicate_info(filter_info, filter_opts, input_opts)
    if (not pattern) or not input_type then
        return
    end

    local action = output_opts.action or "new" --- @type QfRancherAction
    local dest_list_nr = eu.get_dest_list_nr(getlist, action) --- @type integer
    local list_win = eu.find_list_win(output_opts.is_loclist) --- @type integer|nil
    local view = (list_win and dest_list_nr == cur_list.nr)
            and vim.api.nvim_win_call(list_win, vim.fn.winsaveview)
        or nil --- @type vim.fn.winsaveview.ret|nil

    local view_row = view and view.lnum or 0 --- @type integer
    --- @type table[], integer
    local new_items, view_rows_removed =
        filter_info.func(cur_list.items, pattern, filter_opts.keep, input_type, view_row, regex)

    local setlist = eu.get_setlist(output_opts.is_loclist) --- @type function
    eu.set_list_items(getlist, setlist, dest_list_nr, new_items, action, "Filter")

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

--- @param opts QfRancherFilterPredicateOpts
--- @return boolean
local function cfilter_regex(opts)
    opts = opts or {}

    if opts.regex:match_str(opts.text) then
        return opts.keep
    end

    if not opts.bufnr then
        return false
    end

    local bufname = vim.fn.bufname(opts.bufnr)
    if opts.regex:match_str(bufname) then
        return opts.keep
    end

    return not opts.keep
end

--- @param opts QfRancherFilterPredicateOpts
--- @return boolean
--- NOTE: Assumes pattern is all lowercase
local function cfilter_insensitive(opts)
    opts = opts or {}

    local lower_text = string.lower(opts.text)
    if string.find(lower_text, opts.pattern, 1, true) ~= nil then
        return opts.keep
    end

    if not opts.bufnr then
        return false
    end

    local lower_bufname = string.lower(vim.fn.bufname(opts.bufnr))
    if string.find(lower_bufname, opts.pattern, 1, true) ~= nil then
        return opts.keep
    else
        return not opts.keep
    end
end

--- @param opts QfRancherFilterPredicateOpts
--- @return boolean
local function cfilter_sensitive(opts)
    opts = opts or {}

    if string.find(opts.text, opts.pattern, 1, true) ~= nil then
        return opts.keep
    end

    if not opts.bufnr then
        return false
    end

    local bufname = vim.fn.bufname(opts.bufnr)
    if string.find(bufname, opts.pattern, 1, true) ~= nil then
        return opts.keep
    end

    return not opts.keep
end

--- @param input_type QfRancherInputType
--- @param pattern string
--- @param keep boolean
--- @param regex vim.regex|nil
--- @return function
local function get_cfilter_predicate(input_type, pattern, keep, regex)
    vim.validate("pattern", pattern, "string")
    vim.validate("keep", keep, "boolean")
    vim.validate("regex", regex, { "nil", "userdata" })
    vim.validate("input_type", input_type, "string")
    if type(input_type) == "string" then
        vim.validate("input_type", input_type, function()
            return require("mjm.error-list-util").validate_input_type(input_type)
        end)
    end

    if input_type == "regex" and regex then
        return cfilter_regex
    end

    if input_type == "sensitive" then
        return cfilter_sensitive
    end

    assert(string.lower(pattern) == pattern)
    return cfilter_insensitive
end

--- @param items table[]
--- @param pattern string
--- @param keep boolean
--- @param input_type string
--- @param view_row integer
--- @param regex? table
--- @return table[], integer
local function cfilter_func(items, pattern, keep, input_type, view_row, regex)
    vim.validate("items", items, "table")
    vim.validate("pattern", pattern, "string")
    vim.validate("keep", keep, "boolean")
    vim.validate("view_row", view_row, "number")
    vim.validate("regex", regex, { "nil", "userdata" })
    vim.validate("input_type", input_type, "string")
    if type(input_type) == "string" then
        vim.validate("input_type", input_type, function()
            return require("mjm.error-list-util").validate_input_type(input_type)
        end)
    end

    local predicate = get_cfilter_predicate(input_type, pattern, keep, regex)
    local view_rows_removed = 0
    local new_items = {}
    for i, item in ipairs(items) do
        local keep_this = predicate({
            bufnr = item.bufnr,
            keep = keep,
            pattern = pattern,
            regex = regex,
            text = item.text,
        })

        if keep_this then
            table.insert(new_items, item)
        elseif i < view_row then
            view_rows_removed = view_rows_removed + 1
        end
    end

    return new_items, view_rows_removed
end

local cfilter_info = { name = "Cfilter", func = cfilter_func }

--- @param filter_opts QfRancherFilterOpts
--- @param input_opts QfRancherInputOpts
--- @param output_opts QfRancherOutputOpts
--- NOTE: Don't do data validation here. This is just a pass through between API callers and the
--- filer_wrapper function
function M.cfilter(filter_opts, input_opts, output_opts)
    filter_opts = filter_opts or {}
    input_opts = input_opts or {}
    output_opts = output_opts or {}
    M.filter_wrapper(cfilter_info, filter_opts, input_opts, output_opts)
end

--------------
-- Filename --
--------------

--- @param item table
--- @param pattern string
--- @param opts QfRancherFilterOpts
--- @return boolean
local function filter_keep_fname(item, pattern, opts)
    opts = opts or {}

    if not item.bufnr then
        return false
    end

    local fname = vim.fn.bufname(item.bufnr)
    local compare_text = opts.insensitive and string.lower(fname) or fname
    return string.find(compare_text, pattern, 1, true) ~= nil
end

--- @param item table
--- @param pattern string
--- @param opts QfRancherFilterOpts
--- @return boolean
local function filter_remove_fname(item, pattern, opts)
    opts = opts or {}

    if not item.bufnr then
        return false
    end

    local fname = vim.fn.bufname(item.bufnr)
    local compare_text = opts.insensitive and string.lower(fname) or fname
    return not string.find(compare_text, pattern, 1, true)
end

--- @param item table
--- @param pattern string
--- @param opts QfRancherFilterOpts
--- @return boolean
local function filter_keep_fname_regex(item, pattern, opts)
    opts = opts or {}

    if not item.bufnr then
        return false
    end
    local fname = vim.fn.bufname(item.bufnr)

    local regex = vim.regex(pattern)
    local start, fin = regex:match_str(fname)

    local keep = (start and fin) and true or false
    return keep
end

--- @param item table
--- @param pattern string
--- @param opts QfRancherFilterOpts
--- @return boolean
local function filter_remove_fname_regex(item, pattern, opts)
    opts = opts or {}

    if not item.bufnr then
        return false
    end
    local fname = vim.fn.bufname(item.bufnr)

    local regex = vim.regex(pattern)
    local start, fin = regex:match_str(fname)

    local keep = not (start and fin) and true or false
    return keep
end

vim.keymap.set("n", "<leader>qkf", function()
    M.filter_wrapper("Enter filename to keep: ", filter_keep_fname)
end)

vim.keymap.set("n", "<leader>lkf", function()
    M.ll_filter_wrapper("Enter filename to keep: ", filter_keep_fname)
end)

vim.keymap.set("n", "<leader>qrf", function()
    M.filter_wrapper("Enter filename to remove: ", filter_remove_fname)
end)

vim.keymap.set("n", "<leader>lrf", function()
    M.ll_filter_wrapper("Enter filename to remove: ", filter_remove_fname)
end)

vim.keymap.set("n", "<leader>qkF", function()
    M.filter_wrapper("Enter filename to keep (Regex): ", filter_keep_fname_regex)
end)

vim.keymap.set("n", "<leader>lkF", function()
    M.ll_filter_wrapper("Enter filename to keep (Regex): ", filter_keep_fname_regex)
end)

vim.keymap.set("n", "<leader>qrF", function()
    M.filter_wrapper("Enter filename to remove (Regex): ", filter_remove_fname_regex)
end)

vim.keymap.set("n", "<leader>lrF", function()
    M.ll_filter_wrapper("Enter filename to remove (Regex): ", filter_remove_fname_regex)
end)

----------
-- Text --
----------

--- @param item table
--- @param pattern string
--- @param opts QfRancherFilterOpts
--- @return boolean
local function filter_keep_text(item, pattern, opts)
    opts = opts or {}

    local compare_text = opts.insensitive and string.lower(item.text) or item.text
    return string.find(compare_text, pattern, 1, true) ~= nil
end

--- @param item table
--- @param pattern string
--- @param opts QfRancherFilterOpts
--- @return boolean
local function filter_remove_text(item, pattern, opts)
    opts = opts or {}

    local compare_text = opts.insensitive and string.lower(item.text) or item.text
    return not string.find(compare_text, pattern, 1, true)
end

--- @param item table
--- @param pattern string
--- @param opts QfRancherFilterOpts
--- @return boolean
local function filter_keep_text_regex(item, pattern, opts)
    opts = opts or {}

    local regex = vim.regex(pattern)
    local start, fin = regex:match_str(item.text)

    local keep = (start and fin) and true or false
    return keep
end

--- @param item table
--- @param pattern string
--- @param opts QfRancherFilterOpts
--- @return boolean
local function filter_remove_text_regex(item, pattern, opts)
    opts = opts or {}

    local regex = vim.regex(pattern)
    local start, fin = regex:match_str(item.text)

    local keep = not (start and fin) and true or false
    return keep
end

vim.keymap.set("n", "<leader>qke", function()
    M.filter_wrapper("Enter text to keep: ", filter_keep_text)
end)

vim.keymap.set("n", "<leader>lke", function()
    M.ll_filter_wrapper("Enter text to keep: ", filter_keep_text)
end)

vim.keymap.set("n", "<leader>qre", function()
    M.filter_wrapper("Enter text to remove: ", filter_remove_text)
end)

vim.keymap.set("n", "<leader>lre", function()
    M.ll_filter_wrapper("Enter text to remove: ", filter_remove_text)
end)

vim.keymap.set("n", "<leader>qkE", function()
    M.filter_wrapper("Enter text to keep (Regex): ", filter_keep_text_regex)
end)

vim.keymap.set("n", "<leader>lkE", function()
    M.ll_filter_wrapper("Enter text to keep (Regex): ", filter_keep_text_regex)
end)

vim.keymap.set("n", "<leader>qrE", function()
    M.filter_wrapper("Enter text to remove (Regex): ", filter_remove_text_regex)
end)

vim.keymap.set("n", "<leader>lrE", function()
    M.ll_filter_wrapper("Enter text to remove (Regex): ", filter_remove_text_regex)
end)

----------
-- Type --
----------

--- @param item table
--- @param pattern string
--- @param opts QfRancherFilterOpts
--- @return boolean
local function filter_keep_type(item, pattern, opts)
    opts = opts or {}

    local compare_text = opts.insensitive and string.lower(item.type) or item.type
    return string.find(compare_text, pattern, 1, true) ~= nil
end

--- @param item table
--- @param pattern string
--- @param opts QfRancherFilterOpts
--- @return boolean
local function filter_remove_type(item, pattern, opts)
    opts = opts or {}

    local compare_text = opts.insensitive and string.lower(item.type) or item.type
    return not string.find(compare_text, pattern, 1, true)
end

--- @param item table
--- @param pattern string
--- @param opts QfRancherFilterOpts
--- @return boolean
local function filter_keep_type_regex(item, pattern, opts)
    opts = opts or {}

    local regex = vim.regex(pattern)
    local start, fin = regex:match_str(item.type)

    local keep = (start and fin) and true or false
    return keep
end

--- @param item table
--- @param pattern string
--- @param opts QfRancherFilterOpts
--- @return boolean
local function filter_remove_type_regex(item, pattern, opts)
    opts = opts or {}

    local regex = vim.regex(pattern)
    local start, fin = regex:match_str(item.type)

    local keep = not (start and fin) and true or false
    return keep
end

vim.keymap.set("n", "<leader>qkt", function()
    M.filter_wrapper("Enter type to keep: ", filter_keep_type)
end)

vim.keymap.set("n", "<leader>lkt", function()
    M.ll_filter_wrapper("Enter type to keep: ", filter_keep_type)
end)

vim.keymap.set("n", "<leader>qrt", function()
    M.filter_wrapper("Enter type to remove: ", filter_remove_type)
end)

vim.keymap.set("n", "<leader>lrt", function()
    M.ll_filter_wrapper("Enter type to remove: ", filter_remove_type)
end)

vim.keymap.set("n", "<leader>qkT", function()
    M.filter_wrapper("Enter type to keep (Regex): ", filter_keep_type_regex)
end)

vim.keymap.set("n", "<leader>lkT", function()
    M.ll_filter_wrapper("Enter type to keep (Regex): ", filter_keep_type_regex)
end)

vim.keymap.set("n", "<leader>qrT", function()
    M.filter_wrapper("Enter type to remove (Regex): ", filter_remove_type_regex)
end)

vim.keymap.set("n", "<leader>lrT", function()
    M.ll_filter_wrapper("Enter type to remove (Regex): ", filter_remove_type_regex)
end)

-----------------
-- Line Number --
-----------------

--- @param item table
--- @param pattern string
--- @param opts QfRancherFilterOpts
--- @return boolean
local function filter_keep_lnum(item, pattern, opts)
    opts = opts or {}

    local compare_lnum = opts.insensitive and string.lower(item.lnum) or item.lnum
    return string.find(compare_lnum, pattern, 1, true) ~= nil
end

--- @param item table
--- @param pattern string
--- @param opts QfRancherFilterOpts
--- @return boolean
local function filter_remove_lnum(item, pattern, opts)
    opts = opts or {}

    local compare_lnum = opts.insensitive and string.lower(item.lnum) or item.lnum
    return not string.find(compare_lnum, pattern, 1, true)
end

--- @param item table
--- @param pattern string
--- @param opts QfRancherFilterOpts
--- @return boolean
local function filter_keep_lnum_regex(item, pattern, opts)
    opts = opts or {}

    local regex = vim.regex(pattern)
    local start, fin = regex:match_str(item.lnum)

    local keep = (start and fin) and true or false
    return keep
end

--- @param item table
--- @param pattern string
--- @param opts QfRancherFilterOpts
--- @return boolean
local function filter_remove_lnum_regex(item, pattern, opts)
    opts = opts or {}

    local regex = vim.regex(pattern)
    local start, fin = regex:match_str(item.lnum)

    local keep = not (start and fin) and true or false
    return keep
end

vim.keymap.set("n", "<leader>qkn", function()
    M.filter_wrapper("Enter line number to keep: ", filter_keep_lnum)
end)

vim.keymap.set("n", "<leader>lkn", function()
    M.ll_filter_wrapper("Enter line number to keep: ", filter_keep_lnum)
end)

vim.keymap.set("n", "<leader>qrn", function()
    M.filter_wrapper("Enter line number to remove: ", filter_remove_lnum)
end)

vim.keymap.set("n", "<leader>lrn", function()
    M.ll_filter_wrapper("Enter line number to remove: ", filter_remove_lnum)
end)

vim.keymap.set("n", "<leader>qkN", function()
    M.filter_wrapper("Enter line number to keep (Regex): ", filter_keep_lnum_regex)
end)

vim.keymap.set("n", "<leader>lkN", function()
    M.ll_filter_wrapper("Enter line number to keep (Regex): ", filter_keep_lnum_regex)
end)

vim.keymap.set("n", "<leader>qrN", function()
    M.filter_wrapper("Enter line number to remove (Regex): ", filter_remove_lnum_regex)
end)

vim.keymap.set("n", "<leader>lrN", function()
    M.ll_filter_wrapper("Enter line number to remove (Regex): ", filter_remove_lnum_regex)
end)

return M
