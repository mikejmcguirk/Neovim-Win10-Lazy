--- @class QfRancherStack
local M = {}

-------------
--- TYPES ---
-------------

--- @class QfRancherHistoryOpts
--- @field count1? integer
--- @field always_open? boolean

-------------------
--- Module Data ---
-------------------

local no_qf_stack = "Quickfix stack is empty" --- @type string
local no_ll_stack = "Loclist stack is empty" --- @type string

------------------------
--- Helper Functions ---
------------------------

--- This seems to properly emulate what happens when you run setqflist({}, "r") on the current
--- list_nr

--- @param count integer
--- @return vim.fn.setqflist.what
local function get_del_list_data(count)
    require("mjm.error-list-util")._validate_count(count)
    return { context = {}, idx = 0, items = {}, nr = count, title = "" }
end

-----------------------
--- Stack Functions ---
-----------------------

--- NOTE: The qf stack number is the same in all tabs. If a change is made to chistory, check
--- all tabpages for an open qf window to resize

--- @param count1 integer
--- @param arithmetic function
--- @return nil
local function q_change_history(count1, arithmetic)
    require("mjm.error-list-util")._validate_count1(count1)

    local stack_len = vim.fn.getqflist({ nr = "$" }).nr --- @type integer
    if stack_len < 1 then
        vim.api.nvim_echo({ { no_qf_stack, "" } }, false, {})
        return
    end

    local cur_stack_nr = vim.fn.getqflist({ nr = 0 }).nr --- @type integer
    local new_stack_nr = arithmetic(cur_stack_nr, count1, 1, stack_len) --- @type integer

    vim.api.nvim_cmd({ cmd = "chistory", count = new_stack_nr }, {})
    require("mjm.error-list-open")._resize_all_qf_wins()
end

--- @param count1 integer
--- @return nil
function M._q_older(count1)
    q_change_history(count1, require("mjm.error-list-util")._wrapping_sub)
end

--- @param count1 integer
--- @return nil
function M._q_newer(count1)
    q_change_history(count1, require("mjm.error-list-util")._wrapping_add)
end

--- NOTE: For chistory and lhistory, a zero and one count behave the same
--- In order to reduce conditional logic, treat counts below 1 here as invalid, using a nil
--- count to run history simply as a listing

--- @param opts QfRancherHistoryOpts
--- @return nil
function M._q_history(opts)
    opts = opts or {}
    if vim.g.qf_rancher_debug_assertions then
        vim.validate("opts", opts, "table")
        vim.validate("opts.always_open", opts.always_open, { "boolean", "nil" })
        vim.validate("opts.count1", opts.count1, { "nil", "number" })
        if type(opts.count1) == "number" then
            require("mjm.error-list-util")._validate_count1(opts.count1)
        end
    end

    local stack_len = vim.fn.getqflist({ nr = "$" }).nr --- @type integer
    if stack_len < 1 then
        vim.api.nvim_echo({ { no_qf_stack, "" } }, false, {})
        return
    end

    --- @type integer|nil
    local adj_count = opts.count1 > 0 and math.min(opts.count1, stack_len) or nil
    local cur_list_nr = vim.fn.getqflist({ nr = 0 }).nr --- @type integer
    vim.api.nvim_cmd({ cmd = "chistory", count = adj_count }, {})

    local eo = require("mjm.error-list-open") --- @type QfRancherOpen
    if cur_list_nr ~= adj_count then
        eo._resize_all_qf_wins()
    end

    if opts.always_open then
        eo._open_qflist({ keep_win = true, suppress_errors = true })
    end
end

--- NOTE: For q_del and l_del, accept vim.v.count and treat zero as the current list. This
--- aligns with the convention of setqflist/setloclist. This also aligns with the expectation that
--- pressing the hotkey without a count would delete the current list, and allows vim.v.count
--- to be passed through cleanly

--- @param count integer
--- @return nil
function M._q_del(count)
    require("mjm.error-list-util")._validate_count(count)

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

--- @param count1 integer
--- @param arithmetic function
--- @return nil
local function l_change_history(count1, arithmetic)
    require("mjm.error-list-util")._validate_count1(count1)

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
    local new_stack_nr = arithmetic(cur_stack_nr, count1, 1, stack_len) --- @type integer

    vim.api.nvim_cmd({ cmd = "lhistory", count1 = new_stack_nr }, {})
    local tabpage = vim.api.nvim_win_get_tabpage(cur_win) --- @type integer
    require("mjm.error-list-open")._resize_llist_by_qf_id_and_tabpage(qf_id, tabpage)
end

--- @param count1 integer
--- @return nil
function M._l_older(count1)
    l_change_history(count1, require("mjm.error-list-util")._wrapping_sub)
end

--- @param count1 integer
--- @return nil
function M._l_newer(count1)
    l_change_history(count1, require("mjm.error-list-util")._wrapping_add)
end

--- @param opts QfRancherHistoryOpts
--- @return nil
function M._l_history(opts)
    opts = opts or {}
    if vim.g.qf_rancher_debug_assertions then
        vim.validate("opts", opts, "table")
        vim.validate("opts.always_open", opts.always_open, { "boolean", "nil" })
        vim.validate("opts.count1", opts.count1, { "nil", "number" })
        if type(opts.count1) == "number" then
            require("mjm.error-list-util")._validate_count1(opts.count1)
        end
    end

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

    --- @type integer|nil
    local adj_count = opts.count1 > 0 and math.min(opts.count1, stack_len) or nil
    local cur_list_nr = vim.fn.getloclist(cur_win, { nr = 0 }).nr --- @type integer
    vim.api.nvim_cmd({ cmd = "lhistory", count = adj_count }, {})

    local eo = require("mjm.error-list-open") --- @type QfRancherOpen
    if cur_list_nr ~= adj_count then
        local tabpage = vim.api.nvim_win_get_tabpage(cur_win)
        eo._resize_llist_by_qf_id_and_tabpage(qf_id, tabpage)
    end

    if opts.always_open then
        eo._open_loclist({ keep_win = true, suppress_errors = true })
    end
end

--- @param count integer
--- @return nil
function M._l_del(count)
    require("mjm.error-list-util")._validate_count(count)

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
        require("mjm.error-list-open")._resize_llist_by_qf_id_and_tabpage(qf_id, tabpage)
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
    require("mjm.error-list-open")._close_llist_by_qf_id_and_tabpage(qf_id, tabpage)
end

--- @param is_loclist boolean
--- @return function
function M._get_gethistory(is_loclist)
    vim.validate("is_loclist", is_loclist, "boolean")
    if is_loclist then
        return M._l_history
    else
        return M._q_history
    end
end

return M

------------
--- TODO ---
------------

--- Needs testing

-----------
--- MID ---
-----------

-----------
--- LOW ---
-----------

--- Commands to copy/merge/overwrite lists explicitly. Can currently backdoor your way into this
---     with sort. Would want more solid use case before builing out separately
