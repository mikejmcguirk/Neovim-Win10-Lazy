--- TODO:
--- - Check that all functions have reasonable default sorts
--- - Check that window height updates are triggered where appropriate
--- - Check that functions have proper visibility
--- - Check that all mappings have plugs and cmds
--- - Check that all maps/cmds/plugs have desc fieldss
--- - Check that all functions have annotations and documentation
--- - Check that the qf and loclist versions are both properly built for purpose. Should be able
---     to use the loclist function for buf/win specific info

local M = {}

-- LOW: A lot of opportunity for function composition in here

-- FUTURE: Would be neat to have commands that let you specify lists to add into one another,
-- or the ability to overwrite one list with another. But I'm not sure if the cost/benefit
-- analysis works out ATM

function M.q_older(count1)
    vim.validate("count1", count1, "number")
    vim.validate("count1", count1, function()
        return count1 > 0
    end)

    local stack_len = vim.fn.getqflist({ nr = "$" }).nr
    if stack_len < 1 then
        vim.api.nvim_echo({ { "No items in quickfix stack", "" } }, false, {})
        return
    end

    local cur_stack_nr = vim.fn.getqflist({ nr = 0 }).nr
    local eu = require("mjm.error-list-util")
    local new_stack_nr = eu._wrapping_sub(cur_stack_nr, count1, 1, stack_len)

    vim.api.nvim_cmd({ cmd = "chistory", count = new_stack_nr }, {})
    local elo = require("mjm.error-list-open")
    elo._resize_qflist()
end

function M.q_newer(count1)
    vim.validate("count1", count1, "number")
    vim.validate("count1", count1, function()
        return count1 > 0
    end)

    local stack_len = vim.fn.getqflist({ nr = "$" }).nr
    if stack_len < 1 then
        vim.api.nvim_echo({ { "No items in quickfix stack", "" } }, false, {})
        return
    end

    local cur_stack_nr = vim.fn.getqflist({ nr = 0 }).nr
    local eu = require("mjm.error-list-util")
    local new_stack_nr = eu._wrapping_add(cur_stack_nr, count1, 1, stack_len)

    vim.api.nvim_cmd({ cmd = "chistory", count1 = new_stack_nr }, {})
    local elo = require("mjm.error-list-open")
    elo._resize_qflist()
end

function M.q_history(count)
    vim.validate("count", count, "number")
    vim.validate("count", count, function()
        return count >= 0
    end)

    local stack_len = vim.fn.getqflist({ nr = "$" }).nr
    if stack_len < 1 then
        vim.api.nvim_echo({ { "No items in quickfix stack", "" } }, false, {})
        return
    end

    if count < 1 then
        vim.api.nvim_cmd({ cmd = "chistory" }, {})
        return
    end

    count = math.min(count, stack_len)
    vim.api.nvim_cmd({ cmd = "chistory", count = count }, {})
    local elo = require("mjm.error-list-open")
    elo._resize_qflist()
end

function M.q_del(count)
    vim.validate("count", count, "number")
    vim.validate("count", count, function()
        return count >= 0
    end)

    local stack_len = vim.fn.getqflist({ nr = "$" }).nr
    if stack_len < 1 then
        vim.api.nvim_echo({ { "No items in quickix stack", "" } }, false, {})
        return
    end

    if count < 1 then
        vim.fn.setqflist({}, "r")
        return
    end

    count = math.min(count, stack_len)
    vim.fn.setqflist({}, "r", { items = {}, nr = count, title = "" })
    local elo = require("mjm.error-list-open")
    elo._resize_qflist()
end

function M.q_del_all()
    vim.fn.setqflist({}, "f")
    require("mjm.error-list-open")._close_qflist()
end

function M.l_older(count1)
    vim.validate("count1", count1, "number")
    vim.validate("count1", count1, function()
        return count1 > 0
    end)

    local cur_win = vim.api.nvim_get_current_win()
    local eu = require("mjm.error-list-util")
    local qf_id, ll_win = eu._get_loclist_info({ win = cur_win })
    if qf_id == 0 then
        vim.api.nvim_echo({ { "Current window has no location list", "" } }, false, {})
        return
    end

    local stack_len = vim.fn.getloclist(cur_win, { nr = "$" }).nr
    if stack_len < 1 then
        vim.api.nvim_echo({ { "No items in quickix stack", "" } }, false, {})
        return
    end

    local cur_stack_nr = vim.fn.getloclist(cur_win, { nr = 0 }).nr
    local new_stack_nr = eu._wrapping_sub(cur_stack_nr, count1, 1, stack_len)

    vim.api.nvim_cmd({ cmd = "lhistory", count1 = new_stack_nr }, {})
    if ll_win then
        require("mjm.error-list-open")._resize_list_win(ll_win)
    end
end

function M.l_newer(count1)
    vim.validate("count1", count1, "number")
    vim.validate("count1", count1, function()
        return count1 > 0
    end)

    local cur_win = vim.api.nvim_get_current_win()
    local qf_id, ll_win = require("mjm.error-list-util")._get_loclist_info({ win = cur_win })
    if qf_id == 0 then
        vim.api.nvim_echo({ { "Current window has no location list", "" } }, false, {})
        return
    end

    local stack_len = vim.fn.getloclist(cur_win, { nr = "$" }).nr
    if stack_len < 1 then
        vim.api.nvim_echo({ { "No items in quickix stack", "" } }, false, {})
        return
    end

    local cur_stack_nr = vim.fn.getloclist(cur_win, { nr = 0 }).nr
    local eu = require("mjm.error-list-util")
    local new_stack_nr = eu._wrapping_add(cur_stack_nr, count1, 1, stack_len)
    vim.api.nvim_cmd({ cmd = "lhistory", count1 = new_stack_nr }, {})
    if ll_win then
        require("mjm.error-list-open")._resize_list_win(ll_win)
    end
end

function M.l_history(count)
    vim.validate("count", count, "number")
    vim.validate("count", count, function()
        return count >= 0
    end)

    local cur_win = vim.api.nvim_get_current_win()
    local qf_id, ll_win = require("mjm.error-list-util")._get_loclist_info({ win = cur_win })
    if qf_id == 0 then
        vim.api.nvim_echo({ { "Current window has no location list", "" } }, false, {})
        return
    end

    local stack_len = vim.fn.getloclist(cur_win, { nr = "$" }).nr
    if stack_len < 1 then
        vim.api.nvim_echo({ { "No items in quickix stack", "" } }, false, {})
        return
    end

    if count < 1 then
        vim.api.nvim_cmd({ cmd = "lhistory" }, {})
        return
    end

    count = math.min(count, stack_len)
    vim.api.nvim_cmd({ cmd = "lhistory", count = count }, {})
    if ll_win then
        require("mjm.error-list-open")._resize_list_win(ll_win)
    end
end

function M.l_del(count)
    vim.validate("count", count, "number")
    vim.validate("count", count, function()
        return count >= 0
    end)

    local cur_win = vim.api.nvim_get_current_win()
    local qf_id, ll_win = require("mjm.error-list-util")._get_loclist_info({ win = cur_win })
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
    vim.fn.setloclist(cur_win, {}, "r", { items = {}, nr = count, title = "" })
    if ll_win then
        require("mjm.error-list-open")._resize_list_win(ll_win)
    end
end

--- MAYBE: You could have this be a sub-function of l_del. Lets you re-use cur_win code

function M.l_del_all()
    local cur_win = vim.api.nvim_get_current_win()
    local qf_id, ll_win = require("mjm.error-list-util")._get_loclist_info({ win = cur_win })
    if qf_id == 0 then
        vim.api.nvim_echo({ { "Current window has no location list", "" } }, false, {})
        return
    end

    vim.fn.setloclist(cur_win, {}, "f")
    if ll_win then
        require("mjm.error-list-open")._close_list_win(ll_win)
    end
end

function M._get_gethistory(is_loclist)
    if is_loclist then
        return M.l_history
    else
        return M.q_history
    end
end

return M
