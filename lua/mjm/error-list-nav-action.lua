local M = {}

-- TODO: Have an option for opening the list on cmd execution
-- TODO: Lots of repeated code here, including maybe with the stack module

function M.q_prev(count1)
    vim.validate("count", count1, "number")
    vim.validate("count", count1, function()
        return count1 > 0
    end)

    local cur_stack_nr = vim.fn.getqflist({ nr = 0 }).nr
    local size = vim.fn.getqflist({ nr = cur_stack_nr, size = 0 }).size
    if size < 1 then
        vim.api.nvim_echo({ { "No items in quickfix list", "" } }, false, {})
        return
    end

    local cur_idx = vim.fn.getqflist({ nr = cur_stack_nr, idx = 0 }).idx
    local eu = require("mjm.error-list-util")
    local new_idx = eu.wrapping_sub(cur_idx, count1, 1, size)
    local ok, result = vim.api.nvim_cmd({ cmd = "cc", count = new_idx }, {})
    if ok then
        vim.api.nvim_cmd({ cmd = "normal", args = { "zz" }, bang = true }, {})
        return
    end

    local msg = result or ("Unknown error displaying list entry " .. new_idx)
    vim.api.nvim_echo({ { msg, "ErrorMsg" } }, true, { err = true })
end

function M.q_next(count1)
    vim.validate("count", count1, "number")
    vim.validate("count", count1, function()
        return count1 > 0
    end)

    local cur_stack_nr = vim.fn.getqflist({ nr = 0 }).nr
    local size = vim.fn.getqflist({ nr = cur_stack_nr, size = 0 }).size
    if size < 1 then
        vim.api.nvim_echo({ { "No items in quickfix list", "" } }, false, {})
        return
    end

    local cur_idx = vim.fn.getqflist({ nr = cur_stack_nr, idx = 0 }).idx
    local eu = require("mjm.error-list-util")
    local new_idx = eu.wrapping_add(cur_idx, count1, 1, size)
    local ok, result = vim.api.nvim_cmd({ cmd = "cc", count = new_idx }, {})
    if ok then
        vim.api.nvim_cmd({ cmd = "normal", args = { "zz" }, bang = true }, {})
        return
    end

    local msg = result or ("Unknown error displaying list entry " .. new_idx)
    vim.api.nvim_echo({ { msg, "ErrorMsg" } }, true, { err = true })
end

function M.q_open(count)
    vim.validate("count", count, "number")
    vim.validate("count", count, function()
        return count > 0
    end)

    local cur_stack_nr = vim.fn.getqflist({ nr = 0 }).nr
    local size = vim.fn.getqflist({ nr = cur_stack_nr, size = 0 }).size
    if size < 1 then
        vim.api.nvim_echo({ { "No items in quickfix list", "" } }, false, {})
        return
    end

    count = math.min(count, size)
    local ok, result = vim.api.nvim_cmd({ cmd = "cc", count = count }, {})
    if ok then
        vim.api.nvim_cmd({ cmd = "normal", args = { "zz" }, bang = true }, {})
        return
    end

    local msg = result or ("Unknown error displaying list entry " .. count)
    vim.api.nvim_echo({ { msg, "ErrorMsg" } }, true, { err = true })
end

-- DOCUMENT: The cn/cpfile logic does not have the same level of wrapping logic as the cc wrapper
function M.q_pfile(count1)
    vim.validate("count", count1, "number")
    vim.validate("count", count1, function()
        return count1 > 0
    end)

    local ok, err = pcall(vim.api.nvim_cmd, { cmd = "cpfile", count = count1 }, {})
    if (not ok) and (err:match("E42") or err:match("E776")) then
        vim.notify(err:sub(#"Vim:" + 1))
        return
    end

    if (not ok) and err:match("E553") then
        ok, err = pcall(vim.api.nvim_cmd, { cmd = "clast" }, {})
    end

    if not ok then
        local msg = err and err:sub(#"Vim:" + 1) or "Unknown qf file error"
        vim.api.nvim_echo({ { msg, "ErrorMsg" } }, true, { err = true })
        return
    end

    vim.api.nvim_cmd({ cmd = "normal", args = { "zz" }, bang = true }, {})
end

function M.q_nfile(count1)
    vim.validate("count", count1, "number")
    vim.validate("count", count1, function()
        return count1 > 0
    end)

    local ok, err = pcall(vim.api.nvim_cmd, { cmd = "cnfile", count = count1 }, {})
    if (not ok) and (err:match("E42") or err:match("E776")) then
        vim.notify(err:sub(#"Vim:" + 1))
        return
    end

    if (not ok) and err:match("E553") then
        ok, err = pcall(vim.api.nvim_cmd, { cmd = "crewind" }, {})
    end

    if not ok then
        local msg = err and err:sub(#"Vim:" + 1) or "Unknown qf file error"
        vim.api.nvim_echo({ { msg, "ErrorMsg" } }, true, { err = true })
        return
    end

    vim.api.nvim_cmd({ cmd = "normal", args = { "zz" }, bang = true }, {})
end

function M.q_jump(count)
    vim.validate("count", count, "number")
    vim.validate("count", count, function()
        return count > 0
    end)

    local cur_stack_nr = vim.fn.getqflist({ nr = 0 }).nr
    local max_stack_nr = vim.fn.getqflist({ nr = "$" }).nr
    count = math.min(count, max_stack_nr)
    local qf_win = require("mjm.error-list-util").find_qf_win()
    if not qf_win then
        require("mjm.error-list-open").open_qflist()
    else
        vim.api.nvim_set_current_win(qf_win)
    end

    if count > 0 and max_stack_nr > 0 and count ~= cur_stack_nr then
        require("mjm.error-list-stack").q_history(count)
    end
end

function M.l_prev(count)
    vim.validate("count", count, "number")
    vim.validate("count", count, function()
        return count > 0
    end)

    local cur_win = vim.api.nvim_get_current_win()
    local eu = require("mjm.error-list-util")
    local qf_id, _ = eu.get_loclist_info({ win = cur_win })
    if qf_id == 0 then
        vim.api.nvim_echo({ { "Current window has no location list", "" } }, false, {})
        return
    end

    local cur_stack_nr = vim.fn.getloclist(cur_win, { nr = 0 }).nr
    local size = vim.fn.getloclist(cur_win, { nr = cur_stack_nr, size = 0 }).size
    if size < 1 then
        vim.api.nvim_echo({ { "No items in quickfix list", "" } }, false, {})
        return
    end

    local cur_idx = vim.fn.getloclist(cur_win, { nr = cur_stack_nr, idx = 0 }).idx
    local new_idx = eu.wrapping_sub(cur_idx, count, 1, size)
    local ok, result = vim.api.nvim_cmd({ cmd = "ll", count = new_idx }, {})
    if ok then
        vim.api.nvim_cmd({ cmd = "normal", args = { "zz" }, bang = true }, {})
        return
    end

    local msg = result or ("Unknown error displaying list entry " .. new_idx)
    vim.api.nvim_echo({ { msg, "ErrorMsg" } }, true, { err = true })
end

function M.l_next(count)
    vim.validate("count", count, "number")
    vim.validate("count", count, function()
        return count > 0
    end)

    local cur_win = vim.api.nvim_get_current_win()
    local eu = require("mjm.error-list-util")
    local qf_id, _ = eu.get_loclist_info({ win = cur_win })
    if qf_id == 0 then
        vim.api.nvim_echo({ { "Current window has no location list", "" } }, false, {})
        return
    end

    local cur_stack_nr = vim.fn.getloclist(cur_win, { nr = 0 }).nr
    local size = vim.fn.getloclist(cur_win, { nr = cur_stack_nr, size = 0 }).size
    if size < 1 then
        vim.api.nvim_echo({ { "No items in quickfix list", "" } }, false, {})
        return
    end

    local cur_idx = vim.fn.getloclist(cur_win, { nr = cur_stack_nr, idx = 0 }).idx
    local new_idx = eu.wrapping_add(cur_idx, count, 1, size)
    local ok, result = vim.api.nvim_cmd({ cmd = "ll", count = new_idx }, {})
    if ok then
        vim.api.nvim_cmd({ cmd = "normal", args = { "zz" }, bang = true }, {})
        return
    end

    local msg = result or ("Unknown error displaying list entry " .. new_idx)
    vim.api.nvim_echo({ { msg, "ErrorMsg" } }, true, { err = true })
end

function M.l_open(count)
    vim.validate("count", count, "number")
    vim.validate("count", count, function()
        return count > 0
    end)

    local cur_win = vim.api.nvim_get_current_win()
    local eu = require("mjm.error-list-util")
    local qf_id, _ = eu.get_loclist_info({ win = cur_win })
    if qf_id == 0 then
        vim.api.nvim_echo({ { "Current window has no location list", "" } }, false, {})
        return
    end

    local cur_stack_nr = vim.fn.getloclist(cur_win, { nr = 0 }).nr
    local size = vim.fn.getloclist(cur_win, { nr = cur_stack_nr, size = 0 }).size
    if size < 1 then
        vim.api.nvim_echo({ { "No items in location list", "" } }, false, {})
        return
    end

    count = math.min(count, size)
    local ok, result = vim.api.nvim_cmd({ cmd = "ll", count = count }, {})
    if ok then
        vim.api.nvim_cmd({ cmd = "normal", args = { "zz" }, bang = true }, {})
        return
    end

    local msg = result or ("Unknown error displaying list entry " .. count)
    vim.api.nvim_echo({ { msg, "ErrorMsg" } }, true, { err = true })
end

function M.l_pfile(count1)
    vim.validate("count", count1, "number")
    vim.validate("count", count1, function()
        return count1 > 0
    end)

    local cur_win = vim.api.nvim_get_current_win()
    local eu = require("mjm.error-list-util")
    local qf_id, _ = eu.get_loclist_info({ win = cur_win })
    if qf_id == 0 then
        vim.api.nvim_echo({ { "Current window has no location list", "" } }, false, {})
        return
    end

    local ok, err = pcall(vim.api.nvim_cmd, { cmd = "lpfile", count = count1 }, {})
    if (not ok) and (err:match("E42") or err:match("E776")) then
        vim.notify(err:sub(#"Vim:" + 1))
        return
    end

    if (not ok) and err:match("E553") then
        ok, err = pcall(vim.api.nvim_cmd, { cmd = "llast" }, {})
    end

    if not ok then
        local msg = err and err:sub(#"Vim:" + 1) or "Unknown loclist file error"
        vim.api.nvim_echo({ { msg, "ErrorMsg" } }, true, { err = true })
        return
    end

    vim.api.nvim_cmd({ cmd = "normal", args = { "zz" }, bang = true }, {})
end

function M.l_nfile(count1)
    vim.validate("count", count1, "number")
    vim.validate("count", count1, function()
        return count1 > 0
    end)

    local cur_win = vim.api.nvim_get_current_win()
    local eu = require("mjm.error-list-util")
    local qf_id, _ = eu.get_loclist_info({ win = cur_win })
    if qf_id == 0 then
        vim.api.nvim_echo({ { "Current window has no location list", "" } }, false, {})
        return
    end

    local ok, err = pcall(vim.api.nvim_cmd, { cmd = "lnfile", count = count1 }, {})
    if (not ok) and (err:match("E42") or err:match("E776")) then
        vim.notify(err:sub(#"Vim:" + 1))
        return
    end

    if (not ok) and err:match("E553") then
        ok, err = pcall(vim.api.nvim_cmd, { cmd = "lrewind" }, {})
    end

    if not ok then
        local msg = err and err:sub(#"Vim:" + 1) or "Unknown loclist file error"
        vim.api.nvim_echo({ { msg, "ErrorMsg" } }, true, { err = true })
        return
    end

    vim.api.nvim_cmd({ cmd = "normal", args = { "zz" }, bang = true }, {})
end

-- count is for which nr in the stack to jump to. go to the last if invalid
function M.l_jump(count)
    vim.validate("count", count, "number")
    vim.validate("count", count, function()
        return count > 0
    end)

    local cur_win = vim.api.nvim_get_current_win()
    local eu = require("mjm.error-list-util")
    local qf_id, ll_win = eu.get_loclist_info({ win = cur_win })
    if qf_id == 0 then
        vim.api.nvim_echo({ { "Current window has no location list", "" } }, false, {})
        return
    end

    local cur_stack_nr = vim.fn.getloclist(cur_win, { nr = 0 }).nr
    local max_stack_nr = vim.fn.getloclist(cur_win, { nr = "$" }).nr
    count = math.min(count, max_stack_nr)
    if not ll_win then
        require("mjm.error-list-open").open_loclist()
    else
        vim.api.nvim_set_current_win(ll_win)
    end

    if count > 0 and count ~= cur_stack_nr then
        require("mjm.error-list-stack").l_history(count)
    end
end

return M
