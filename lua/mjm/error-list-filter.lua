local M = {}

-------------------------
--- Wrapper Functions ---
-------------------------

--- @param pattern string
--- @return boolean
local function is_filter_smartcase(pattern)
    --- @type boolean
    local smartcase = vim.api.nvim_get_option_value("smartcase", { scope = "global" })
    if smartcase and string.lower(pattern) == pattern then
        return true
    else
        return false
    end
end

--- @class QfRancherFilterOpts
--- @field smartcase? boolean

--- @param prompt string
--- @param filter_func fun(table, string, FilterOpts): boolean
--- @return nil
function M.qf_filter_wrapper(prompt, filter_func)
    local list_size = vim.fn.getqflist({ size = true }).size --- @type integer
    if (not list_size) or list_size == 0 then
        vim.api.nvim_echo({ { "No list entries", "" } }, false, {})
        return
    end

    --- @type boolean, string
    local ok, result = pcall(vim.fn.input, { prompt = prompt, cancelreturn = "" })
    if not ok then
        if result == "Keyboard interrupt" then
            return
        end
        --- @type [string, string]
        local chunk = { result or "Unknown error getting input", "ErrorMsg" }
        vim.api.nvim_echo({ chunk }, true, { err = true })
        return
    end

    local smartcase = is_filter_smartcase(result) --- @type boolean
    local list_nr = (function()
        if vim.v.count > 0 then
            return math.min(vim.v.count, vim.fn.getqflist({ nr = "$" }).nr)
        else
            return vim.fn.getqflist({ nr = 0 }).nr
        end
    end)() --- @type integer

    local eu = require("mjm.error-list-util")
    local qf_win = eu.find_qf_win() --- @type integer|nil
    --- @type vim.fn.winsaveview.ret|nil
    local view = qf_win and vim.api.nvim_win_call(qf_win, vim.fn.winsaveview) or nil
    local row = view and view.lnum or 0 --- @type integer
    local list = vim.fn.getqflist({ nr = list_nr, all = true }) --- @type table
    local new_items = {} --- @type table
    for i, t in ipairs(list.items) do
        local keep = filter_func(t, result, { smartcase = smartcase }) --- @type boolean

        if not keep and i < row and view then
            view.topline = view.topline - 1
            view.lnum = view.lnum - 1
        end

        if keep then
            table.insert(new_items, t)
        end
    end

    vim.fn.setqflist({}, "u", { nr = list_nr, items = new_items })
    if qf_win and view then
        view.topline = math.max(view.topline, 0)
        vim.api.nvim_win_call(qf_win, function()
            vim.fn.winrestview(view)
        end)
    end

    if qf_win then
        require("mjm.error-list-open").resize_list_win(qf_win)
    end
end

--- @param prompt string
--- @param filter_func fun(table, string, FilterOpts): boolean
--- @return nil
function M.ll_filter_wrapper(prompt, filter_func)
    local cur_win = vim.api.nvim_get_current_win() --- @type integer
    local qf_id = vim.fn.getloclist(cur_win, { id = 0 }).id
    if qf_id == 0 then
        vim.api.nvim_echo({ { "Window has no location list", "" } }, false, {})
        return
    end

    local list_size = vim.fn.getloclist(cur_win, { size = true }).size --- @type integer
    if (not list_size) or list_size == 0 then
        vim.api.nvim_echo({ { "No list entries", "" } }, false, {})
        return
    end

    --- @type boolean, string
    local ok, result = pcall(vim.fn.input, { prompt = prompt, cancelreturn = "" })
    if not ok then
        if result == "Keyboard interrupt" then
            return
        end
        --- @type [string, string]
        local chunk = { result or "Unknown error getting input", "ErrorMsg" }
        vim.api.nvim_echo({ chunk }, true, { err = true })
        return
    end

    local smartcase = is_filter_smartcase(result) --- @type boolean

    local list_nr = (function()
        if vim.v.count > 0 then
            return math.min(vim.v.count, vim.fn.getloclist(cur_win, { nr = "$" }).nr)
        else
            return vim.fn.getloclist(cur_win, { nr = 0 }).nr
        end
    end)() --- @type integer

    local loclist_win = (function()
        for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
            local win_qf_id = vim.fn.getloclist(win, { id = 0 }).id
            if win_qf_id == qf_id then
                if vim.fn.win_gettype(win) == "loclist" then
                    return win
                end
            end
        end

        return nil
    end)() --- @type integer

    --- @type vim.fn.winsaveview.ret|nil
    local view = loclist_win and vim.api.nvim_win_call(loclist_win, vim.fn.winsaveview) or nil
    local row = view and view.lnum or 0 --- @type integer

    local list = vim.fn.getloclist(cur_win, { nr = list_nr, all = true }) --- @type table
    local new_items = {} --- @type table
    for i, t in ipairs(list.items) do
        local keep = filter_func(t, result, { smartcase = smartcase }) --- @type boolean

        if not keep and i < row and view then
            view.topline = view.topline - 1
            view.lnum = view.lnum - 1
        end

        if keep then
            table.insert(new_items, t)
        end
    end

    vim.fn.setloclist(cur_win, {}, "u", { nr = list_nr, items = new_items })
    if loclist_win and view then
        view.topline = math.max(view.topline, 0)
        vim.api.nvim_win_call(loclist_win, function()
            vim.fn.winrestview(view)
        end)
    end

    if loclist_win then
        require("mjm.error-list-open").resize_list_win(loclist_win)
    end
end

-----------------------
-- Cfilter Emulation --
-----------------------

--- @param item table
--- @param pattern string
--- @param opts QfRancherFilterOpts
--- @return boolean
local function filter_keep_emu(item, pattern, opts)
    opts = opts or {}

    if not item.bufnr then
        return false
    end

    local fname = vim.fn.bufname(item.bufnr)
    local compare_fname = opts.smartcase and string.lower(fname) or fname
    local find_fname = string.find(compare_fname, pattern, 1, true)

    local compare_text = opts.smartcase and string.lower(item.text) or item.text
    local find_text = string.find(compare_text, pattern, 1, true)

    return (find_fname or find_text) and true or false
end

--- @param item table
--- @param pattern string
--- @param opts QfRancherFilterOpts
--- @return boolean
local function filter_remove_emu(item, pattern, opts)
    opts = opts or {}

    if not item.bufnr then
        return false
    end

    local fname = vim.fn.bufname(item.bufnr)
    local compare_fname = opts.smartcase and string.lower(fname) or fname
    local find_fname = string.find(compare_fname, pattern, 1, true)

    local compare_text = opts.smartcase and string.lower(item.text) or item.text
    local find_text = string.find(compare_text, pattern, 1, true)

    return not (find_fname or find_text) and true or false
end

--- @param item table
--- @param pattern string
--- @param opts QfRancherFilterOpts
--- @return boolean
local function filter_keep_emu_regex(item, pattern, opts)
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
local function filter_remove_emu_regex(item, pattern, opts)
    opts = opts or {}

    local regex = vim.regex(pattern) --- @type vim.regex

    local fname = item.bufnr and vim.fn.bufname(item.bufnr) or nil
    local f_start, f_fin = fname and regex:match_str(fname) or nil, nil

    local t_start, t_fin = item.text and regex:match_str(item.text) or nil, nil

    return (not ((f_start and f_fin) or (t_start and t_fin))) and true or false
end

vim.keymap.set("n", "<leader>qkl", function()
    M.qf_filter_wrapper("Enter pattern to keep: ", filter_keep_emu)
end)

vim.keymap.set("n", "<leader>lkl", function()
    M.ll_filter_wrapper("Enter pattern to keep: ", filter_keep_emu)
end)

vim.keymap.set("n", "<leader>qrl", function()
    M.qf_filter_wrapper("Enter pattern to remove: ", filter_remove_emu)
end)

vim.keymap.set("n", "<leader>lrl", function()
    M.ll_filter_wrapper("Enter pattern to remove: ", filter_remove_emu)
end)

vim.keymap.set("n", "<leader>qkL", function()
    M.qf_filter_wrapper("Enter pattern to keep (Regex): ", filter_keep_emu_regex)
end)

vim.keymap.set("n", "<leader>lkL", function()
    M.ll_filter_wrapper("Enter pattern to keep (Regex): ", filter_keep_emu_regex)
end)

vim.keymap.set("n", "<leader>qrL", function()
    M.qf_filter_wrapper("Enter pattern to remove (Regex): ", filter_remove_emu_regex)
end)

vim.keymap.set("n", "<leader>lrL", function()
    M.ll_filter_wrapper("Enter pattern to remove (Regex): ", filter_remove_emu_regex)
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
    local compare_text = opts.smartcase and string.lower(fname) or fname
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
    local compare_text = opts.smartcase and string.lower(fname) or fname
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
    M.qf_filter_wrapper("Enter filename to keep: ", filter_keep_fname)
end)

vim.keymap.set("n", "<leader>lkf", function()
    M.ll_filter_wrapper("Enter filename to keep: ", filter_keep_fname)
end)

vim.keymap.set("n", "<leader>qrf", function()
    M.qf_filter_wrapper("Enter filename to remove: ", filter_remove_fname)
end)

vim.keymap.set("n", "<leader>lrf", function()
    M.ll_filter_wrapper("Enter filename to remove: ", filter_remove_fname)
end)

vim.keymap.set("n", "<leader>qkF", function()
    M.qf_filter_wrapper("Enter filename to keep (Regex): ", filter_keep_fname_regex)
end)

vim.keymap.set("n", "<leader>lkF", function()
    M.ll_filter_wrapper("Enter filename to keep (Regex): ", filter_keep_fname_regex)
end)

vim.keymap.set("n", "<leader>qrF", function()
    M.qf_filter_wrapper("Enter filename to remove (Regex): ", filter_remove_fname_regex)
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

    local compare_text = opts.smartcase and string.lower(item.text) or item.text
    return string.find(compare_text, pattern, 1, true) ~= nil
end

--- @param item table
--- @param pattern string
--- @param opts QfRancherFilterOpts
--- @return boolean
local function filter_remove_text(item, pattern, opts)
    opts = opts or {}

    local compare_text = opts.smartcase and string.lower(item.text) or item.text
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
    M.qf_filter_wrapper("Enter text to keep: ", filter_keep_text)
end)

vim.keymap.set("n", "<leader>lke", function()
    M.ll_filter_wrapper("Enter text to keep: ", filter_keep_text)
end)

vim.keymap.set("n", "<leader>qre", function()
    M.qf_filter_wrapper("Enter text to remove: ", filter_remove_text)
end)

vim.keymap.set("n", "<leader>lre", function()
    M.ll_filter_wrapper("Enter text to remove: ", filter_remove_text)
end)

vim.keymap.set("n", "<leader>qkE", function()
    M.qf_filter_wrapper("Enter text to keep (Regex): ", filter_keep_text_regex)
end)

vim.keymap.set("n", "<leader>lkE", function()
    M.ll_filter_wrapper("Enter text to keep (Regex): ", filter_keep_text_regex)
end)

vim.keymap.set("n", "<leader>qrE", function()
    M.qf_filter_wrapper("Enter text to remove (Regex): ", filter_remove_text_regex)
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

    local compare_text = opts.smartcase and string.lower(item.type) or item.type
    return string.find(compare_text, pattern, 1, true) ~= nil
end

--- @param item table
--- @param pattern string
--- @param opts QfRancherFilterOpts
--- @return boolean
local function filter_remove_type(item, pattern, opts)
    opts = opts or {}

    local compare_text = opts.smartcase and string.lower(item.type) or item.type
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
    M.qf_filter_wrapper("Enter type to keep: ", filter_keep_type)
end)

vim.keymap.set("n", "<leader>lkt", function()
    M.ll_filter_wrapper("Enter type to keep: ", filter_keep_type)
end)

vim.keymap.set("n", "<leader>qrt", function()
    M.qf_filter_wrapper("Enter type to remove: ", filter_remove_type)
end)

vim.keymap.set("n", "<leader>lrt", function()
    M.ll_filter_wrapper("Enter type to remove: ", filter_remove_type)
end)

vim.keymap.set("n", "<leader>qkT", function()
    M.qf_filter_wrapper("Enter type to keep (Regex): ", filter_keep_type_regex)
end)

vim.keymap.set("n", "<leader>lkT", function()
    M.ll_filter_wrapper("Enter type to keep (Regex): ", filter_keep_type_regex)
end)

vim.keymap.set("n", "<leader>qrT", function()
    M.qf_filter_wrapper("Enter type to remove (Regex): ", filter_remove_type_regex)
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

    local compare_lnum = opts.smartcase and string.lower(item.lnum) or item.lnum
    return string.find(compare_lnum, pattern, 1, true) ~= nil
end

--- @param item table
--- @param pattern string
--- @param opts QfRancherFilterOpts
--- @return boolean
local function filter_remove_lnum(item, pattern, opts)
    opts = opts or {}

    local compare_lnum = opts.smartcase and string.lower(item.lnum) or item.lnum
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
    M.qf_filter_wrapper("Enter line number to keep: ", filter_keep_lnum)
end)

vim.keymap.set("n", "<leader>lkn", function()
    M.ll_filter_wrapper("Enter line number to keep: ", filter_keep_lnum)
end)

vim.keymap.set("n", "<leader>qrn", function()
    M.qf_filter_wrapper("Enter line number to remove: ", filter_remove_lnum)
end)

vim.keymap.set("n", "<leader>lrn", function()
    M.ll_filter_wrapper("Enter line number to remove: ", filter_remove_lnum)
end)

vim.keymap.set("n", "<leader>qkN", function()
    M.qf_filter_wrapper("Enter line number to keep (Regex): ", filter_keep_lnum_regex)
end)

vim.keymap.set("n", "<leader>lkN", function()
    M.ll_filter_wrapper("Enter line number to keep (Regex): ", filter_keep_lnum_regex)
end)

vim.keymap.set("n", "<leader>qrN", function()
    M.qf_filter_wrapper("Enter line number to remove (Regex): ", filter_remove_lnum_regex)
end)

vim.keymap.set("n", "<leader>lrN", function()
    M.ll_filter_wrapper("Enter line number to remove (Regex): ", filter_remove_lnum_regex)
end)

return M
