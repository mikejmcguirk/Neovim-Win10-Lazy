-- TODO: Default display masks error types

local M = {}

-------------------------
--- Wrapper Functions ---
-------------------------

--- @param pattern string
--- @return boolean
local function is_filter_smartcase(pattern)
    if not vim.api.nvim_get_option_value("smartcase", { scope = "global" }) then return false end

    if string.lower(pattern) ~= pattern then return false end

    return true
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
        if result == "Keyboard interrupt" then return end
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

    local qf_win = (function()
        for _, win in pairs(vim.api.nvim_tabpage_list_wins(0)) do
            if vim.fn.win_gettype(win) == "quickfix" then return win end
        end

        return nil
    end)() --- @type integer

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

        if keep then table.insert(new_items, t) end
    end

    vim.fn.setqflist({}, "u", { nr = list_nr, items = new_items })
    if qf_win and view then
        view.topline = math.max(view.topline, 0)
        vim.api.nvim_win_call(qf_win, function() vim.fn.winrestview(view) end)
    end

    if qf_win then require("mjm.error-list").resize_list_win(qf_win) end
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
        if result == "Keyboard interrupt" then return end
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
        for _, win in pairs(vim.api.nvim_tabpage_list_wins(0)) do
            local win_qf_id = vim.fn.getloclist(win, { id = 0 }).id
            if win_qf_id == qf_id then
                if vim.fn.win_gettype(win) == "loclist" then return win end
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

        if keep then table.insert(new_items, t) end
    end

    vim.fn.setloclist(cur_win, {}, "u", { nr = list_nr, items = new_items })
    if loclist_win and view then
        view.topline = math.max(view.topline, 0)
        vim.api.nvim_win_call(loclist_win, function() vim.fn.winrestview(view) end)
    end

    if loclist_win then require("mjm.error-list").resize_list_win(loclist_win) end
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

    if not item.bufnr then return false end

    local fname = vim.fn.bufname(item.bufnr)
    local compare_fname = opts.smartcase and string.lower(fname) or fname
    local match_fname = string.match(compare_fname, pattern)

    local compare_text = opts.smartcase and string.lower(item.text) or item.text
    local match_text = string.match(compare_text, pattern)

    return (match_fname or match_text) and true or false
end

--- @param item table
--- @param pattern string
--- @param opts QfRancherFilterOpts
--- @return boolean
local function filter_remove_emu(item, pattern, opts)
    opts = opts or {}

    if not item.bufnr then return false end

    local fname = vim.fn.bufname(item.bufnr)
    local compare_fname = opts.smartcase and string.lower(fname) or fname
    local match_fname = string.match(compare_fname, pattern)

    local compare_text = opts.smartcase and string.lower(item.text) or item.text
    local match_text = string.match(compare_text, pattern)

    return not (match_fname or match_text) and true or false
end

--- @param item table
--- @param pattern string
--- @param opts QfRancherFilterOpts
--- @return boolean
local function filter_keep_emu_regex(item, pattern, opts)
    opts = opts or {}

    local regex = vim.regex(pattern)

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

    local regex = vim.regex(pattern)

    local fname = item.bufnr and vim.fn.bufname(item.bufnr) or nil
    local f_start, f_fin = fname and regex:match_str(fname) or nil, nil

    local t_start, t_fin = item.text and regex:match_str(item.text) or nil, nil

    return (not ((f_start and f_fin) or (t_start and t_fin))) and true or false
end

local keep_filter = "Enter pattern to keep: "
local qf_emu_keep = function() M.qf_filter_wrapper(keep_filter, filter_keep_emu) end
vim.keymap.set("n", "<leader>qkf", qf_emu_keep)

local ll_emu_keep = function() M.ll_filter_wrapper(keep_filter, filter_keep_emu) end
vim.keymap.set("n", "<leader>lkf", ll_emu_keep)

local rm_filter = "Enter pattern to remove: "
local qf_emu_rem = function() M.qf_filter_wrapper(rm_filter, filter_remove_emu) end
vim.keymap.set("n", "<leader>qrf", qf_emu_rem)

local ll_emu_rem = function() M.ll_filter_wrapper(rm_filter, filter_remove_emu) end
vim.keymap.set("n", "<leader>lrf", ll_emu_rem)

local qf_emu_keep_regex = function()
    M.qf_filter_wrapper("Enter pattern to keep (Regex): ", filter_keep_emu_regex)
end
vim.keymap.set("n", "<leader>qkF", qf_emu_keep_regex)

local ll_emu_keep_regex = function()
    M.ll_filter_wrapper("Enter pattern to keep (Regex): ", filter_keep_emu_regex)
end
vim.keymap.set("n", "<leader>lkF", ll_emu_keep_regex)

local qf_emu_rem_regex = function()
    M.qf_filter_wrapper("Enter pattern to remove (Regex): ", filter_remove_emu_regex)
end
vim.keymap.set("n", "<leader>qrF", qf_emu_rem_regex)

local ll_emu_rem_regex = function()
    M.ll_filter_wrapper("Enter pattern to remove (Regex): ", filter_remove_emu_regex)
end
vim.keymap.set("n", "<leader>lrF", ll_emu_rem_regex)

--------------
-- Filename --
--------------

--- @param item table
--- @param pattern string
--- @param opts QfRancherFilterOpts
--- @return boolean
local function filter_keep_fname(item, pattern, opts)
    opts = opts or {}

    if not item.bufnr then return false end

    local fname = vim.fn.bufname(item.bufnr)
    local compare_text = opts.smartcase and string.lower(fname) or fname
    return string.match(compare_text, pattern)
end

--- @param item table
--- @param pattern string
--- @param opts QfRancherFilterOpts
--- @return boolean
local function filter_remove_fname(item, pattern, opts)
    opts = opts or {}

    if not item.bufnr then return false end

    local fname = vim.fn.bufname(item.bufnr)
    local compare_text = opts.smartcase and string.lower(fname) or fname
    return not string.match(compare_text, pattern)
end

--- @param item table
--- @param pattern string
--- @param opts QfRancherFilterOpts
--- @return boolean
local function filter_keep_fname_regex(item, pattern, opts)
    opts = opts or {}

    if not item.bufnr then return false end
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

    if not item.bufnr then return false end
    local fname = vim.fn.bufname(item.bufnr)

    local regex = vim.regex(pattern)
    local start, fin = regex:match_str(fname)

    local keep = not (start and fin) and true or false
    return keep
end

local keep_msg = "Enter filename to keep: "
local qf_fname_keep = function() M.qf_filter_wrapper(keep_msg, filter_keep_fname) end
vim.keymap.set("n", "<leader>qki", qf_fname_keep)

local ll_fname_keep = function() M.ll_filter_wrapper(keep_msg, filter_keep_fname) end
vim.keymap.set("n", "<leader>lki", ll_fname_keep)

local rm_msg = "Enter filename to remove: "
local qf_fname_rem = function() M.qf_filter_wrapper(rm_msg, filter_remove_fname) end
vim.keymap.set("n", "<leader>qri", qf_fname_rem)

local ll_fname_rem = function() M.ll_filter_wrapper(rm_msg, filter_remove_fname) end
vim.keymap.set("n", "<leader>lri", ll_fname_rem)

local qf_fname_keep_regex = function()
    M.qf_filter_wrapper("Enter filename to keep (Regex): ", filter_keep_fname_regex)
end
vim.keymap.set("n", "<leader>qkI", qf_fname_keep_regex)

local ll_fname_keep_regex = function()
    M.ll_filter_wrapper("Enter filename to keep (Regex): ", filter_keep_fname_regex)
end
vim.keymap.set("n", "<leader>lkI", ll_fname_keep_regex)

local qf_fname_rem_regex = function()
    M.qf_filter_wrapper("Enter filename to remove (Regex): ", filter_remove_fname_regex)
end
vim.keymap.set("n", "<leader>qrI", qf_fname_rem_regex)

local ll_fname_rem_regex = function()
    M.ll_filter_wrapper("Enter filename to remove (Regex): ", filter_remove_fname_regex)
end
vim.keymap.set("n", "<leader>lrI", ll_fname_rem_regex)

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
    return string.match(compare_text, pattern)
end

--- @param item table
--- @param pattern string
--- @param opts QfRancherFilterOpts
--- @return boolean
local function filter_remove_text(item, pattern, opts)
    opts = opts or {}

    local compare_text = opts.smartcase and string.lower(item.text) or item.text
    return not string.match(compare_text, pattern)
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

local qf_txt_keep = function() M.qf_filter_wrapper("Enter text to keep: ", filter_keep_text) end
vim.keymap.set("n", "<leader>qke", qf_txt_keep)

local ll_txt_keep = function() M.ll_filter_wrapper("Enter text to keep: ", filter_keep_text) end
vim.keymap.set("n", "<leader>lke", ll_txt_keep)

local qf_txt_rem = function() M.qf_filter_wrapper("Enter text to remove: ", filter_remove_text) end
vim.keymap.set("n", "<leader>qre", qf_txt_rem)

local ll_txt_rem = function() M.ll_filter_wrapper("Enter text to remove: ", filter_remove_text) end
vim.keymap.set("n", "<leader>lre", ll_txt_rem)

local qf_txt_keep_regex = function()
    M.qf_filter_wrapper("Enter text to keep (Regex): ", filter_keep_text_regex)
end
vim.keymap.set("n", "<leader>qkE", qf_txt_keep_regex)

local ll_txt_keep_regex = function()
    M.ll_filter_wrapper("Enter text to keep (Regex): ", filter_keep_text_regex)
end
vim.keymap.set("n", "<leader>lkE", ll_txt_keep_regex)

local qf_txt_rem_regex = function()
    M.qf_filter_wrapper("Enter text to remove (Regex): ", filter_remove_text_regex)
end
vim.keymap.set("n", "<leader>qrE", qf_txt_rem_regex)

local ll_txt_rem_regex = function()
    M.ll_filter_wrapper("Enter text to remove (Regex): ", filter_remove_text_regex)
end
vim.keymap.set("n", "<leader>lrE", ll_txt_rem_regex)

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
    return string.match(compare_text, pattern)
end

--- @param item table
--- @param pattern string
--- @param opts QfRancherFilterOpts
--- @return boolean
local function filter_remove_type(item, pattern, opts)
    opts = opts or {}

    local compare_text = opts.smartcase and string.lower(item.type) or item.type
    return not string.match(compare_text, pattern)
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

local qf_typ_keep = function() M.qf_filter_wrapper("Enter type to keep: ", filter_keep_type) end
vim.keymap.set("n", "<leader>qkt", qf_typ_keep)

local ll_typ_keep = function() M.ll_filter_wrapper("Enter type to keep: ", filter_keep_type) end
vim.keymap.set("n", "<leader>lkt", ll_typ_keep)

local qf_typ_rem = function() M.qf_filter_wrapper("Enter type to remove: ", filter_remove_type) end
vim.keymap.set("n", "<leader>qrt", qf_typ_rem)

local ll_typ_rem = function() M.ll_filter_wrapper("Enter type to remove: ", filter_remove_type) end
vim.keymap.set("n", "<leader>lrt", ll_typ_rem)

local qf_typ_keep_regex = function()
    M.qf_filter_wrapper("Enter type to keep (Regex): ", filter_keep_type_regex)
end
vim.keymap.set("n", "<leader>qkT", qf_typ_keep_regex)

local ll_typ_keep_regex = function()
    M.ll_filter_wrapper("Enter type to keep (Regex): ", filter_keep_type_regex)
end
vim.keymap.set("n", "<leader>lkT", ll_typ_keep_regex)

local qf_typ_rem_regex = function()
    M.qf_filter_wrapper("Enter type to remove (Regex): ", filter_remove_type_regex)
end
vim.keymap.set("n", "<leader>qrT", qf_typ_rem_regex)

local ll_typ_rem_regex = function()
    M.ll_filter_wrapper("Enter type to remove (Regex): ", filter_remove_type_regex)
end
vim.keymap.set("n", "<leader>lrT", ll_typ_rem_regex)

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
    return string.match(compare_lnum, pattern)
end

--- @param item table
--- @param pattern string
--- @param opts QfRancherFilterOpts
--- @return boolean
local function filter_remove_lnum(item, pattern, opts)
    opts = opts or {}

    local compare_lnum = opts.smartcase and string.lower(item.lnum) or item.lnum
    return not string.match(compare_lnum, pattern)
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

local qf_lnum_keep = function()
    M.qf_filter_wrapper("Enter line number to keep: ", filter_keep_lnum)
end
vim.keymap.set("n", "<leader>qkl", qf_lnum_keep)

local ll_lnum_keep = function()
    M.ll_filter_wrapper("Enter line number to keep: ", filter_keep_lnum)
end
vim.keymap.set("n", "<leader>lkl", ll_lnum_keep)

local lnum_rm = "Enter line number to remove: "
local qf_lnum_rem = function() M.qf_filter_wrapper(lnum_rm, filter_remove_lnum) end
vim.keymap.set("n", "<leader>qrl", qf_lnum_rem)

local ll_lnum_rem = function() M.ll_filter_wrapper(lnum_rm, filter_remove_lnum) end
vim.keymap.set("n", "<leader>lrl", ll_lnum_rem)

local qf_lnum_keep_regex = function()
    M.qf_filter_wrapper("Enter line number to keep (Regex): ", filter_keep_lnum_regex)
end
vim.keymap.set("n", "<leader>qkL", qf_lnum_keep_regex)

local ll_lnum_keep_regex = function()
    M.ll_filter_wrapper("Enter line number to keep (Regex): ", filter_keep_lnum_regex)
end
vim.keymap.set("n", "<leader>lkL", ll_lnum_keep_regex)

local qf_lnum_rem_regex = function()
    M.qf_filter_wrapper("Enter line number to remove (Regex): ", filter_remove_lnum_regex)
end
vim.keymap.set("n", "<leader>qrL", qf_lnum_rem_regex)

local ll_lnum_rem_regex = function()
    M.ll_filter_wrapper("Enter line number to remove (Regex): ", filter_remove_lnum_regex)
end
vim.keymap.set("n", "<leader>lrL", ll_lnum_rem_regex)

return M
