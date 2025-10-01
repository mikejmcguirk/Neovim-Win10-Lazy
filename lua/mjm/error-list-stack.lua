local M = {}

-------------------
--- Module Data ---
-------------------

local no_qf_items = "No items in quickfix stack"
local no_ll_items = "No items in loclist stack"

------------------------
--- Helper Functions ---
------------------------

-- TODO: put these in utils since they can also be used by nav_action

--- @param count1 integer
--- @return nil
local function validate_count1(count1)
    vim.validate("count", count1, "number")
    vim.validate("count", count1, function()
        return count1 >= 0
    end)
end

--- @param count integer
--- @return nil
local function validate_count(count)
    vim.validate("count", count, "number")
    vim.validate("count", count, function()
        return count >= 0
    end)
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
    validate_count1(count1)

    local stack_len = vim.fn.getqflist({ nr = "$" }).nr
    if stack_len < 1 then
        vim.api.nvim_echo({ { no_qf_items, "" } }, false, {})
        return
    end

    local cur_stack_nr = vim.fn.getqflist({ nr = 0 }).nr
    local new_stack_nr = arithmetic(cur_stack_nr, count1, 1, stack_len)

    vim.api.nvim_cmd({ cmd = "chistory", count = new_stack_nr }, {})
    require("mjm.error-list-open")._resize_all_qf_wins()
end

--- @param count1 integer
--- @return nil
function M.q_older(count1)
    q_change_history(count1, require("mjm.error-list-util")._wrapping_sub)
end

--- @param count1 integer
--- @return nil
function M.q_newer(count1)
    q_change_history(count1, require("mjm.error-list-util")._wrapping_add)
end

--- @param count integer
--- @return nil
function M.q_history(count)
    validate_count(count)

    local stack_len = vim.fn.getqflist({ nr = "$" }).nr --- @type integer
    if stack_len < 1 then
        vim.api.nvim_echo({ { no_qf_items, "" } }, false, {})
        return
    end

    local adj_count = count > 0 and math.min(count, stack_len) or nil --- @type integer|nil
    vim.api.nvim_cmd({ cmd = "chistory", count = adj_count }, {})
end

--- @param count integer
--- @return nil
function M.q_del(count)
    validate_count(count)

    local stack_len = vim.fn.getqflist({ nr = "$" }).nr
    if stack_len < 1 then
        vim.api.nvim_echo({ { no_qf_items, "" } }, false, {})
        return
    end

    if count < 1 then
        vim.fn.setqflist({}, "r")
        return
    end

    local cur_stack_nr = vim.fn.getqflist({ nr = 0 }).nr
    count = math.min(count, stack_len)
    -- TODO: Is there not a better way to do this?
    vim.fn.setqflist({}, "r", { items = {}, nr = count, title = "" })
    if count == cur_stack_nr then
        require("mjm.error-list-open")._resize_all_qf_wins()
    end
end

function M.q_del_all()
    vim.fn.setqflist({}, "f")
    require("mjm.error-list-open")._close_qflist()
end

--- @param count1 integer
--- @param arithmetic function
--- @return nil
local function l_change_history(count1, arithmetic)
    validate_count1(count1)

    local cur_win = vim.api.nvim_get_current_win()
    local qf_id = vim.fn.getloclist(cur_win, { id = 0 }).id
    if qf_id == 0 then
        vim.api.nvim_echo({ { "Current window has no location list", "" } }, false, {})
        return
    end

    local stack_len = vim.fn.getloclist(cur_win, { nr = "$" }).nr
    if stack_len < 1 then
        vim.api.nvim_echo({ { no_ll_items, "" } }, false, {})
        return
    end

    local cur_stack_nr = vim.fn.getloclist(cur_win, { nr = 0 }).nr
    local new_stack_nr = arithmetic(cur_stack_nr, count1, 1, stack_len)

    vim.api.nvim_cmd({ cmd = "lhistory", count1 = new_stack_nr }, {})
    local tabpage = vim.api.nvim_win_get_tabpage(cur_win)
    require("mjm.error-list-open")._resize_llist_by_qf_id_and_tabpage(qf_id, tabpage)
end

--- @param count1 integer
--- @return nil
function M.l_older(count1)
    l_change_history(count1, require("mjm.error-list-util")._wrapping_sub)
end

--- @param count1 integer
--- @return nil
function M.l_newer(count1)
    l_change_history(count1, require("mjm.error-list-util")._wrapping_add)
end

--- @param count integer
--- @return nil
function M.l_history(count)
    validate_count(count)

    local cur_win = vim.api.nvim_get_current_win()
    local qf_id = vim.fn.getloclist(cur_win, { id = 0 }).id
    if qf_id == 0 then
        vim.api.nvim_echo({ { "Current window has no location list", "" } }, false, {})
        return
    end

    local stack_len = vim.fn.getloclist(cur_win, { nr = "$" }).nr
    if stack_len < 1 then
        vim.api.nvim_echo({ { no_ll_items, "" } }, false, {})
        return
    end

    local adj_count = count > 0 and math.min(count, stack_len) or nil --- @type integer|nil
    vim.api.nvim_cmd({ cmd = "lhistory", count = adj_count }, {})
end

--- @param count integer
--- @return nil
function M.l_del(count)
    validate_count(count)

    local cur_win = vim.api.nvim_get_current_win()
    local qf_id = vim.fn.getloclist(cur_win, { id = 0 }).id
    if qf_id == 0 then
        vim.api.nvim_echo({ { "Current window has no location list", "" } }, false, {})
        return
    end

    local stack_len = vim.fn.getloclist(cur_win, { nr = "$" }).nr
    if stack_len < 1 then
        vim.api.nvim_echo({ { "No items in loclist stack", "" } }, false, {})
        return
    end

    if count < 1 then
        vim.fn.setloclist(cur_win, {}, "r")
        return
    end

    count = math.min(count, stack_len)
    -- TODO: like with qf - seems like an awkward way to do this
    vim.fn.setloclist(cur_win, {}, "r", { items = {}, nr = count, title = "" })
    local tabpage = vim.api.nvim_win_get_tabpage(cur_win)
    require("mjm.error-list-open")._resize_llist_by_qf_id_and_tabpage(qf_id, tabpage)
end

--- MAYBE: You could have this be a sub-function of l_del. Lets you re-use cur_win code

function M.l_del_all()
    local cur_win = vim.api.nvim_get_current_win()
    local qf_id = vim.fn.getloclist(cur_win, { id = 0 }).id
    if qf_id == 0 then
        vim.api.nvim_echo({ { "Current window has no location list", "" } }, false, {})
        return
    end

    vim.fn.setloclist(cur_win, {}, "f")
    -- TODO: In this case, what we need is to take a qf_id and tabpage, see if it exists, if it
    -- does, save the views and then close
    -- Do we add these options into close_loclist? would save redundancy
end

function M._get_gethistory(is_loclist)
    if is_loclist then
        return M.l_history
    else
        return M.q_history
    end
end

return M

--- TODO:
--- - Check that all functions have reasonable default sorts
--- - Check that window height updates are triggered where appropriate
--- - Check that functions have proper visibility
--- - Check that all mappings have plugs and cmds
--- - Check that all maps/cmds/plugs have desc fieldss
--- - Check that all functions have annotations and documentation
--- - Check that the qf and loclist versions are both properly built for purpose. Should be able
---     to use the loclist function for buf/win specific info

-- LOW: A lot of opportunity for function composition in here

-- FUTURE: Would be neat to have commands that let you specify lists to add into one another,
-- or the ability to overwrite one list with another. But I'm not sure if the cost/benefit
-- analysis works out ATM
