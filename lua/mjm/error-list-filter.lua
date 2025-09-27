local M = {}

-------------------------
--- Wrapper Functions ---
-------------------------

--- @alias QfRancherAction "new"|"replace"|"add"

--- @return boolean
local function resolve_smartcase()
    local g_use_smartcase = vim.g.qfrancher_use_smartcase
    if g_use_smartcase ~= nil and g_use_smartcase ~= vim.NIL then
        return vim.g.qfrancher_use_smartcase
    else
        return vim.api.nvim_get_option_value("smartcase", { scope = "global" })
    end
end

--- @class QfRancherFilterOpts
--- @field keep? boolean
--- @field regex? vim.regex
--- @field insensitive? boolean
--- @field smartcase? boolean
--- @field use_regex? boolean
---
--- @alias QfRancherFilterFunc fun(table, string, QfRancherFilterOpts): boolean

--- @param is_loclist boolean
--- @param filter_func QfRancherFilterFunc
--- @param filter_opts QfRancherFilterOpts
--- @param opts{action?: QfRancherAction, pattern?:string, prompt?:string }
--- @return nil
function M.all_filter_wrapper(is_loclist, filter_func, filter_opts, opts)
    opts = opts or {}
    vim.validate("is_loclist", is_loclist, "boolean")
    vim.validate("filter_func", filter_func, "callable")
    vim.validate("filter_opts", filter_opts, "table")
    vim.validate("filter_opts.keep", filter_opts.keep, { "boolean", "nil" })
    vim.validate("filter_opts.insensitive", filter_opts.insensitive, { "boolean", "nil" })
    vim.validate("opts.action", opts.action, { "nil", "string" })
    vim.validate("opts.pattern", opts.pattern, { "nil", "string" })
    vim.validate("opts.prompt", opts.prompt, { "nil", "string" })

    local cur_win = vim.api.nvim_get_current_win()
    local eu = require("mjm.error-list-util")
    local getlist = eu.get_getlist({ get_loclist = is_loclist, win = cur_win })
    local cur_list_size = getlist({ size = true }).size --- @type integer
    if (not cur_list_size) or cur_list_size == 0 then
        vim.api.nvim_echo({ { "No entries to filter", "" } }, false, {})
        return
    end

    --- @type string|nil
    local pattern = opts.pattern and opts.pattern
        or eu.get_input(opts.prompt or "Enter filter pattern")
    if not pattern then
        return
    end

    local list_win = eu.find_list_win(is_loclist, { win = cur_win }) --- @type integer|nil
    --- @type vim.fn.winsaveview.ret|nil
    local view = list_win and vim.api.nvim_win_call(list_win, vim.fn.winsaveview) or nil
    local row = view and view.lnum or 0 --- @type integer

    local action = opts.action or "replace"
    action = vim.v.count > 0 and action or "replace"
    local dest_list_nr = eu.get_dest_list_nr(getlist, action) --- @type string|integer

    local old_list = vim.fn.getqflist({ nr = dest_list_nr, all = true }) --- @type table
    local new_items = {} --- @type table
    filter_opts = filter_opts or {}
    filter_opts.regex = filter_opts.use_regex and vim.regex(pattern) or nil --- @type vim.regex|nil
    filter_opts.smartcase = resolve_smartcase() --- @type boolean
    for i, t in ipairs(old_list.items) do
        local keep = filter_func(t, pattern, filter_opts) --- @type boolean
        if keep then
            table.insert(new_items, t)
        elseif i < row and view then
            view.topline = view.topline - 1
            view.lnum = view.lnum - 1
        end
    end

    local setlist = eu.get_setlist(is_loclist)
    eu.set_list_items(getlist, setlist, dest_list_nr, new_items, action, "Filter")
    if list_win and view then
        view.topline = math.max(view.topline, 0)
        view.lnum = math.max(view.lnum, 1)
        vim.api.nvim_win_call(list_win, function()
            vim.fn.winrestview(view)
        end)
    end

    eu.get_openlist(is_loclist)({ always_resize = true })
end

--- In order for this to work in a sane way from the mappings file, we need to be able to feed
--- in the action and the casing. It should also be possible to pre-specify the pattern
--- define smartcase beforehand
-----------------------
-- Cfilter Emulation --
-----------------------

--- @param item table
--- @param pattern string
--- @param opts QfRancherFilterOpts
--- @return boolean
local function cfilter_keep(item, pattern, opts)
    opts = opts or {}

    if not item.bufnr then
        return false
    end

    local fname = vim.fn.bufname(item.bufnr)
    local compare_fname = opts.insensitive and string.lower(fname) or fname
    local find_fname = string.find(compare_fname, pattern, 1, true)

    local compare_text = opts.insensitive and string.lower(item.text) or item.text
    local find_text = string.find(compare_text, pattern, 1, true)

    return (find_fname or find_text) and true or false
end

--- @param item table
--- @param pattern string
--- @param opts QfRancherFilterOpts
--- @return boolean
local function cfilter_remove(item, pattern, opts)
    opts = opts or {}

    if not item.bufnr then
        return false
    end

    local fname = vim.fn.bufname(item.bufnr)
    local compare_fname = opts.insensitive and string.lower(fname) or fname
    local find_fname = string.find(compare_fname, pattern, 1, true)

    local compare_text = opts.insensitive and string.lower(item.text) or item.text
    local find_text = string.find(compare_text, pattern, 1, true)

    return not (find_fname or find_text) and true or false
end

--- @param item table
--- @param pattern string
--- @param opts QfRancherFilterOpts
--- @return boolean
local function cfilter_keep_regex(item, pattern, opts)
    opts = opts or {}

    local regex = vim.regex(pattern) --- @type vim.regex

    local fname = item.bufnr and vim.fn.bufname(item.bufnr) or nil
    local f_start, f_fin = fname and regex:match_str(fname) or nil, nil

    local t_start, t_fin = item.text and regex:match_str(item.text) or nil, nil

    return ((f_start and f_fin) or (t_start and t_fin)) and true or false
end

--- @param item table
--- @param pattern string
--- @param opts QfRancherFilterOpts
--- @return boolean
local function cfilter_remove_regex(item, pattern, opts)
    opts = opts or {}

    local regex = vim.regex(pattern) --- @type vim.regex

    local fname = item.bufnr and vim.fn.bufname(item.bufnr) or nil
    local f_start, f_fin = fname and regex:match_str(fname) or nil, nil

    local t_start, t_fin = item.text and regex:match_str(item.text) or nil, nil

    return (not ((f_start and f_fin) or (t_start and t_fin))) and true or false
end

--- @param pattern string
--- @param text string
--- @param opts QfRancherFilterOpts
--- @return boolean
local function do_literal(pattern, text, opts)
    vim.validate("pattern", pattern, "string")
    vim.validate("text", text, "string")
    vim.validate("opts.insensitive", opts.insensitive, "boolean")
    vim.validate("opts.smartcase", opts.smartcase, "boolean")

    if not (opts.insensitive or opts.smartcase) then
        return string.find(text, pattern, 1, true) ~= nil
    end

    if opts.smartcase then
        local smart_text = string.lower(pattern) == pattern and string.lower(text) or text
        return string.find(smart_text, pattern, 1, true) ~= nil
    end

    return string.find(text, pattern, 1, true) ~= nil
end

--- @param text string
--- @param regex vim.regex
--- @return boolean
local function do_regex(text, regex)
    local start, fin = regex:match_str(text)
    return start ~= nil and fin ~= nil
end

--- @param item table
--- @param pattern string
--- @param opts QfRancherFilterOpts
--- @return boolean
local function cfilter_both(item, pattern, opts)
    opts = opts or {}
    vim.validate("item", item, "table")
    vim.validate("pattern", pattern, "string")
    vim.validate("opts.keep", opts.keep, { "boolean", "nil" })
    vim.validate("opts.regex", opts.regex, { "nil", "table" })
    vim.validate("opts.insensitive", opts.insensitive, { "boolean", "nil" })
    vim.validate("opts.smartcase", opts.smartcase, { "boolean" })

    if not item.bufnr then
        return false
    end

    local has_text = opts.regex and do_regex(item.text, opts.regex)
        or do_literal(pattern, item.text, opts)
    if has_text then
        return opts.keep and has_text or not has_text
    end

    local bufname = vim.fn.bufname(item.bufnr)
    local has_bufname = opts.regex and do_regex(bufname, opts.regex)
        or do_literal(pattern, bufname, opts)
    if has_bufname and opts.keep then
        return true
    end

    return false
end

local function validate_filter_input(is_loclist, filter_opts, opts)
    vim.validate("is_loclist", is_loclist, "boolean")
    vim.validate("filter_opts", filter_opts, "table")
    vim.validate("filter_opts.keep", filter_opts.keep, { "boolean", "nil" })
    vim.validate("filter_opts.regex", filter_opts.regex, { "nil" })
    vim.validate("filter_opts.insensitive", filter_opts.insensitive, { "boolean", "nil" })
    vim.validate("filter_opts.use_regex", filter_opts.use_regex, { "boolean", "nil" })
    vim.validate("opts", opts, "table")
    vim.validate("opts.pattern", opts.pattern, { "nil", "string" })
    vim.validate("opts.prompt", opts.prompt, { "nil", "string" })
    vim.validate("opts.action", opts.action, { "nil", "string" })
    if type(opts.action) == "string" then
        vim.validate("action", opts.action, function()
            return require("mjm.error-list-util").validate_action(opts.action)
        end)
    end
end

-- pass in opts.insensitive. determine smartcase later
-- pass in the cfilter opts, so we're determining smartcase, all caps, etc here
-- and also pass in action here
--- @param is_loclist boolean
--- @param filter_opts QfRancherFilterOpts
--- @param opts{action?: QfRancherAction, pattern?:string, prompt?:string }
function M.cfilter(is_loclist, filter_opts, opts)
    filter_opts = filter_opts or {}
    opts = opts or {}
    validate_filter_input(is_loclist, filter_opts, opts)

    opts.prompt = (function()
        if opts.prompt then
            return opts.prompt
        end

        local prompt
        if filter_opts.keep then
            prompt = "Enter Cfilter pattern to keep"
        else
            prompt = "Enter Cfilter pattern to remove"
        end

        if filter_opts.use_regex then
            prompt = prompt .. " (Regex)"
        elseif not filter_opts.insensitive then
            prompt = prompt .. " (Case Sensitive)"
        end

        prompt = prompt .. ": "

        return prompt
    end)()

    M.all_filter_wrapper(is_loclist, cfilter_both, filter_opts, opts)
end

vim.keymap.set("n", "<leader>lkl", function()
    M.ll_filter_wrapper("Enter pattern to keep: ", cfilter_keep)
end)

vim.keymap.set("n", "<leader>qrl", function()
    M.all_filter_wrapper("Enter pattern to remove: ", cfilter_remove)
end)

vim.keymap.set("n", "<leader>lrl", function()
    M.ll_filter_wrapper("Enter pattern to remove: ", cfilter_remove)
end)

vim.keymap.set("n", "<leader>qkL", function()
    M.all_filter_wrapper("Enter pattern to keep (Regex): ", cfilter_keep_regex)
end)

vim.keymap.set("n", "<leader>lkL", function()
    M.ll_filter_wrapper("Enter pattern to keep (Regex): ", cfilter_keep_regex)
end)

vim.keymap.set("n", "<leader>qrL", function()
    M.all_filter_wrapper("Enter pattern to remove (Regex): ", cfilter_remove_regex)
end)

vim.keymap.set("n", "<leader>lrL", function()
    M.ll_filter_wrapper("Enter pattern to remove (Regex): ", cfilter_remove_regex)
end)

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
    M.all_filter_wrapper("Enter filename to keep: ", filter_keep_fname)
end)

vim.keymap.set("n", "<leader>lkf", function()
    M.ll_filter_wrapper("Enter filename to keep: ", filter_keep_fname)
end)

vim.keymap.set("n", "<leader>qrf", function()
    M.all_filter_wrapper("Enter filename to remove: ", filter_remove_fname)
end)

vim.keymap.set("n", "<leader>lrf", function()
    M.ll_filter_wrapper("Enter filename to remove: ", filter_remove_fname)
end)

vim.keymap.set("n", "<leader>qkF", function()
    M.all_filter_wrapper("Enter filename to keep (Regex): ", filter_keep_fname_regex)
end)

vim.keymap.set("n", "<leader>lkF", function()
    M.ll_filter_wrapper("Enter filename to keep (Regex): ", filter_keep_fname_regex)
end)

vim.keymap.set("n", "<leader>qrF", function()
    M.all_filter_wrapper("Enter filename to remove (Regex): ", filter_remove_fname_regex)
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
    M.all_filter_wrapper("Enter text to keep: ", filter_keep_text)
end)

vim.keymap.set("n", "<leader>lke", function()
    M.ll_filter_wrapper("Enter text to keep: ", filter_keep_text)
end)

vim.keymap.set("n", "<leader>qre", function()
    M.all_filter_wrapper("Enter text to remove: ", filter_remove_text)
end)

vim.keymap.set("n", "<leader>lre", function()
    M.ll_filter_wrapper("Enter text to remove: ", filter_remove_text)
end)

vim.keymap.set("n", "<leader>qkE", function()
    M.all_filter_wrapper("Enter text to keep (Regex): ", filter_keep_text_regex)
end)

vim.keymap.set("n", "<leader>lkE", function()
    M.ll_filter_wrapper("Enter text to keep (Regex): ", filter_keep_text_regex)
end)

vim.keymap.set("n", "<leader>qrE", function()
    M.all_filter_wrapper("Enter text to remove (Regex): ", filter_remove_text_regex)
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
    M.all_filter_wrapper("Enter type to keep: ", filter_keep_type)
end)

vim.keymap.set("n", "<leader>lkt", function()
    M.ll_filter_wrapper("Enter type to keep: ", filter_keep_type)
end)

vim.keymap.set("n", "<leader>qrt", function()
    M.all_filter_wrapper("Enter type to remove: ", filter_remove_type)
end)

vim.keymap.set("n", "<leader>lrt", function()
    M.ll_filter_wrapper("Enter type to remove: ", filter_remove_type)
end)

vim.keymap.set("n", "<leader>qkT", function()
    M.all_filter_wrapper("Enter type to keep (Regex): ", filter_keep_type_regex)
end)

vim.keymap.set("n", "<leader>lkT", function()
    M.ll_filter_wrapper("Enter type to keep (Regex): ", filter_keep_type_regex)
end)

vim.keymap.set("n", "<leader>qrT", function()
    M.all_filter_wrapper("Enter type to remove (Regex): ", filter_remove_type_regex)
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
    M.all_filter_wrapper("Enter line number to keep: ", filter_keep_lnum)
end)

vim.keymap.set("n", "<leader>lkn", function()
    M.ll_filter_wrapper("Enter line number to keep: ", filter_keep_lnum)
end)

vim.keymap.set("n", "<leader>qrn", function()
    M.all_filter_wrapper("Enter line number to remove: ", filter_remove_lnum)
end)

vim.keymap.set("n", "<leader>lrn", function()
    M.ll_filter_wrapper("Enter line number to remove: ", filter_remove_lnum)
end)

vim.keymap.set("n", "<leader>qkN", function()
    M.all_filter_wrapper("Enter line number to keep (Regex): ", filter_keep_lnum_regex)
end)

vim.keymap.set("n", "<leader>lkN", function()
    M.ll_filter_wrapper("Enter line number to keep (Regex): ", filter_keep_lnum_regex)
end)

vim.keymap.set("n", "<leader>qrN", function()
    M.all_filter_wrapper("Enter line number to remove (Regex): ", filter_remove_lnum_regex)
end)

vim.keymap.set("n", "<leader>lrN", function()
    M.ll_filter_wrapper("Enter line number to remove (Regex): ", filter_remove_lnum_regex)
end)

return M
