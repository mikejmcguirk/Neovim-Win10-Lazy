--- @class QfRancherStack
local M = {}

-------------------
--- Module Data ---
-------------------

local no_qf_stack = "Quickfix stack is empty" --- @type string
local no_ll_stack = "Loclist stack is empty" --- @type string

------------------------
--- Helper Functions ---
------------------------

--- @param count integer
--- @return vim.fn.setqflist.what
local function get_del_list_data(count)
    if vim.g.qf_rancher_debug_assertions then
        require("mjm.error-list-types")._validate_count(count)
    end

    --- TODO: Have a bunch of examples I can use to make this better
    return { context = {}, idx = 0, items = {}, nr = count, title = "" }
end

--- @param win integer|nil
--- @return nil
local function resize_after_hist_change(win)
    local eo = require("mjm.error-list-open")
    if win then
        eo._resize_loclists_by_win(win, { tabpage = vim.api.nvim_get_current_tabpage() })
    else
        eo._resize_all_qf_wins()
    end
end

-------------------
--- OLDER/NEWER ---
-------------------

--- @param win integer|nil
--- @param count integer
--- @param arithmetic function
--- @return nil
local function change_history(win, count, arithmetic)
    if vim.g.qf_rancher_debug_assertions then
        local ey = require("mjm.error-list-types")
        ey._validate_win(win, true)
        ey._validate_count(count)
        vim.validate("arithmetic", arithmetic, "callable")
    end

    local et = require("mjm.error-list-tools") --- @type QfRancherTools
    local stack_len = et._get_max_list_nr(win) --- @type integer
    if stack_len < 1 then
        vim.api.nvim_echo({ { "Stack is empty", "" } }, false, {})
        return
    end

    local cur_list_nr = et._get_cur_list_nr(win) --- @type integer
    local count1 = require("mjm.error-list-util")._count_to_count1(count) --- @type integer
    local new_list_nr = arithmetic(cur_list_nr, count1, 1, stack_len) --- @type integer

    local cmd = win and "lhistory" or "chistory" --- @type string
    vim.api.nvim_cmd({ cmd = cmd, count = new_list_nr }, {})
    if vim.g.qf_rancher_debug_assertions then
        local list_nr_after = et._get_cur_list_nr(win)
        assert(new_list_nr == list_nr_after)
    end

    if cur_list_nr ~= new_list_nr then
        resize_after_hist_change(win)
    end
end

--- @param count integer
--- @return nil
function M._q_older(count)
    change_history(nil, count, require("mjm.error-list-util")._wrapping_sub)
end

--- @param count integer
--- @return nil
function M._q_newer(count)
    change_history(nil, count, require("mjm.error-list-util")._wrapping_add)
end

--- @param count integer
--- @param arithmetic function
--- @return nil
local function l_change_history(count, arithmetic)
    local cur_win = vim.api.nvim_get_current_win() --- @type integer
    local qf_id = vim.fn.getloclist(cur_win, { id = 0 }).id --- @type integer
    if qf_id == 0 then
        vim.api.nvim_echo({ { "Current window has no location list", "" } }, false, {})
        return
    end

    change_history(cur_win, count, arithmetic)
end

--- @param count integer
--- @return nil
function M._l_older(count)
    l_change_history(count, require("mjm.error-list-util")._wrapping_sub)
end

--- @param count integer
--- @return nil
function M._l_newer(count)
    l_change_history(count, require("mjm.error-list-util")._wrapping_add)
end

---------------
--- HISTORY ---
---------------

--- @param win integer|nil
--- @param count integer
--- @param opts QfRancherHistoryOpts
--- @return nil
local function history(win, count, opts)
    if vim.g.qf_rancher_debug_assertions then
        local ey = require("mjm.error-list-types")
        ey._validate_win(win, true)
        ey._validate_count(count)
        ey._validate_history_opts(opts)
    end

    local et = require("mjm.error-list-tools") --- @type QfRancherTools
    local stack_len = et._get_max_list_nr(win) --- @type integer
    if stack_len < 1 then
        vim.api.nvim_echo({ { "Stack is empty", "" } }, false, {})
        return
    end

    local cur_list_nr = et._get_cur_list_nr(win) --- @type integer
    local cmd = win and "lhistory" or "chistory" --- @type string
    local adj_count = count > 0 and math.min(count, stack_len) or nil --- @type integer|nil
    ---@diagnostic disable-next-line: missing-fields
    vim.api.nvim_cmd({ cmd = cmd, count = adj_count, mods = { silent = opts.silent } }, {})
    if vim.g.qf_rancher_debug_assertions then
        if adj_count then
            local list_nr_after = et._get_cur_list_nr(win)
            assert(adj_count == list_nr_after)
        end
    end

    if cur_list_nr ~= adj_count then
        resize_after_hist_change(win)
    end

    if opts.always_open then
        local open_opts = { keep_win = opts.keep_win, suppress_errors = true }
        require("mjm.error-list-open")._open_list(win, open_opts)
    end
end

--- @param count integer
--- @param opts QfRancherHistoryOpts
--- @return nil
function M._q_history(count, opts)
    history(nil, count, opts)
end

--- @param win integer
--- @param opts QfRancherHistoryOpts
--- @return nil
function M._l_history(win, count, opts)
    local ey = require("mjm.error-list-types")
    ey._validate_win(win, false)

    local qf_id = vim.fn.getloclist(win, { id = 0 }).id --- @type integer
    if qf_id == 0 then
        vim.api.nvim_echo({ { "Current window has no location list", "" } }, false, {})
        return
    end

    history(win, count, opts)
end

----------------
--- DELETION ---
----------------

--- @param count integer
--- @return nil
function M._q_del(count)
    require("mjm.error-list-types")._validate_count(count)

    local stack_len = vim.fn.getqflist({ nr = "$" }).nr --- @type integer
    if stack_len < 1 then
        vim.api.nvim_echo({ { no_qf_stack, "" } }, false, {})
        return
    end

    local cur_stack_nr = vim.fn.getqflist({ nr = 0 }).nr --- @type integer
    count = math.min(count, stack_len)
    if count < 1 then
        vim.fn.setqflist({}, "r") --- Don't use bespoke behavior unnecessarily
    else
        vim.fn.setqflist({}, "r", get_del_list_data(count))
    end

    if count == 0 or count == cur_stack_nr then
        require("mjm.error-list-open")._resize_all_qf_wins()
    end
end

function M._q_del_all()
    require("mjm.error-list-open")._close_qflist()
    if vim.fn.getqflist({ nr = "$" }).nr < 1 then
        vim.api.nvim_echo({ { no_qf_stack, "" } }, false, {})
    else
        vim.fn.setqflist({}, "f")
    end
end

--- @param count integer
--- @return nil
function M._l_del(count)
    require("mjm.error-list-types")._validate_count(count)

    local cur_win = vim.api.nvim_get_current_win() --- @type integer
    local qf_id = vim.fn.getloclist(cur_win, { id = 0 }).id --- @type integer
    if qf_id == 0 then
        vim.api.nvim_echo({ { "Current window has no location list", "" } }, false, {})
        return
    end

    local stack_len = vim.fn.getloclist(cur_win, { nr = "$" }).nr --- @type integer
    if stack_len < 1 then
        vim.api.nvim_echo({ { no_ll_stack, "" } }, false, {})
        return
    end

    local cur_stack_nr = vim.fn.getloclist(cur_win, { nr = 0 }).nr --- @type integer
    count = math.min(count, stack_len)
    if count < 1 then
        vim.fn.setloclist(cur_win, {}, "r")
    else
        vim.fn.setloclist(cur_win, {}, "r", get_del_list_data(count))
    end

    if count == 0 or count == cur_stack_nr then
        local tabpage = vim.api.nvim_win_get_tabpage(cur_win) --- @type integer
        require("mjm.error-list-open")._resize_llists_by_qf_id_and_tabpage(qf_id, tabpage)
    end
end

--- @return nil
function M._l_del_all()
    local cur_win = vim.api.nvim_get_current_win() --- @type integer
    local qf_id = vim.fn.getloclist(cur_win, { id = 0 }).id --- @type integer
    if qf_id == 0 then
        vim.api.nvim_echo({ { "Current window has no location list", "" } }, false, {})
        return
    end

    if vim.fn.getloclist(cur_win, { nr = "$" }).nr < 1 then
        vim.api.nvim_echo({ { no_ll_stack, "" } }, false, {})
    else
        vim.fn.setloclist(cur_win, {}, "f")
    end

    local tabpage = vim.api.nvim_win_get_tabpage(cur_win) --- @type integer
    require("mjm.error-list-open")._close_llists_by_qf_id_and_tabpage(qf_id, tabpage)
end

--- @param is_loclist boolean
--- @return function
function M._get_gethistory(is_loclist)
    vim.validate("is_loclist", is_loclist, { "boolean", "nil" })
    if is_loclist then
        return M._l_history
    else
        return M._q_history
    end
end

function M._history(win, count, opts)
    if win then
        M._l_history(win, count, opts)
    else
        M._q_history(count, opts)
    end
end

return M

------------
--- TODO ---
------------

--- Because a lot of the functions have changed, go through the maps and cmds and make sure they
--- are correct
--- Deep audit/testing

-----------
--- MID ---
-----------

-----------
--- LOW ---
-----------

--- Commands to copy/merge/overwrite lists explicitly. Can currently backdoor your way into this
---     with sort. Would want more solid use case before builing out separately
