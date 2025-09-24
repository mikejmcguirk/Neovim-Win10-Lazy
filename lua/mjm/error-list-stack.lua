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
    local new_stack_nr = eu.wrapping_sub(cur_stack_nr, count1, 1, stack_len)

    vim.api.nvim_cmd({ cmd = "chistory", count = new_stack_nr }, {})
    local elo = require("mjm.error-list-open")
    elo.resize_qflist()
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
    local new_stack_nr = eu.wrapping_add(cur_stack_nr, count1, 1, stack_len)

    vim.api.nvim_cmd({ cmd = "chistory", count1 = new_stack_nr }, {})
    local elo = require("mjm.error-list-open")
    elo.resize_qflist()
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
    elo.resize_qflist()
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
    elo.resize_qflist()
end

function M.q_del_all()
    vim.fn.setqflist({}, "f")
    require("mjm.error-list-open").close_qflist()
end

function M.l_older(count1)
    vim.validate("count1", count1, "number")
    vim.validate("count1", count1, function()
        return count1 > 0
    end)

    local cur_win = vim.api.nvim_get_current_win()
    local eu = require("mjm.error-list-util")
    local qf_id, ll_win = eu.get_loclist_info({ win = cur_win })
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
    local new_stack_nr = eu.wrapping_sub(cur_stack_nr, count1, 1, stack_len)

    vim.api.nvim_cmd({ cmd = "lhistory", count1 = new_stack_nr }, {})
    if ll_win then
        require("mjm.error-list-open").resize_list_win(ll_win)
    end
end

function M.l_newer(count1)
    vim.validate("count1", count1, "number")
    vim.validate("count1", count1, function()
        return count1 > 0
    end)

    local cur_win = vim.api.nvim_get_current_win()
    local qf_id, ll_win = require("mjm.error-list-util").get_loclist_info({ win = cur_win })
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
    local new_stack_nr = eu.wrapping_add(cur_stack_nr, count1, 1, stack_len)
    vim.api.nvim_cmd({ cmd = "lhistory", count1 = new_stack_nr }, {})
    if ll_win then
        require("mjm.error-list-open").resize_list_win(ll_win)
    end
end

function M.l_history(count)
    vim.validate("count", count, "number")
    vim.validate("count", count, function()
        return count >= 0
    end)

    local cur_win = vim.api.nvim_get_current_win()
    local qf_id, ll_win = require("mjm.error-list-util").get_loclist_info({ win = cur_win })
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
        require("mjm.error-list-open").resize_list_win(ll_win)
    end
end

function M.l_del(count)
    vim.validate("count", count, "number")
    vim.validate("count", count, function()
        return count >= 0
    end)

    local cur_win = vim.api.nvim_get_current_win()
    local qf_id, ll_win = require("mjm.error-list-util").get_loclist_info({ win = cur_win })
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
        require("mjm.error-list-open").resize_list_win(ll_win)
    end
end

--- MAYBE: You could have this be a sub-function of l_del. Lets you re-use cur_win code

function M.l_del_all()
    local cur_win = vim.api.nvim_get_current_win()
    local qf_id, ll_win = require("mjm.error-list-util").get_loclist_info({ win = cur_win })
    if qf_id == 0 then
        vim.api.nvim_echo({ { "Current window has no location list", "" } }, false, {})
        return
    end

    vim.fn.setloclist(cur_win, {}, "f")
    if ll_win then
        require("mjm.error-list-open").close_list_win(ll_win)
    end
end

function M.get_history(is_loclist)
    if is_loclist then
        return M.l_history
    else
        return M.q_history
    end
end

-----------------
--- Plug Maps ---
-----------------

vim.api.nvim_set_keymap("n", "<Plug>(qf-rancher-qf-older)", "<nop>", {
    noremap = true,
    desc = "<Plug> Go to an older qflist",
    callback = function()
        M.q_older(vim.v.count1)
    end,
})

vim.api.nvim_set_keymap("n", "<Plug>(qf-rancher-qf-newer)", "<nop>", {
    noremap = true,
    desc = "<Plug> Go to a newer qflist",
    callback = function()
        M.q_newer(vim.v.count1)
    end,
})

vim.api.nvim_set_keymap("n", "<Plug>(qf-rancher-qf-history)", "<nop>", {
    noremap = true,
    desc = "<Plug> View or jump within the quickfix history",
    callback = function()
        M.q_history(vim.v.count)
    end,
})

vim.api.nvim_set_keymap("n", "<Plug>(qf-rancher-qf-del)", "<nop>", {
    noremap = true,
    desc = "<Plug> Delete a list from the quickfix stack",
    callback = function()
        M.q_del(vim.v.count)
    end,
})

vim.api.nvim_set_keymap("n", "<Plug>(qf-rancher-qf-del-all)", "<nop>", {
    noremap = true,
    desc = "<Plug> Delete all items from the quickfix stack",
    callback = function()
        M.q_del_all()
    end,
})

vim.api.nvim_set_keymap("n", "<Plug>(qf-rancher-ll-older)", "<nop>", {
    noremap = true,
    desc = "<Plug> Go to an older location list",
    callback = function()
        M.l_older(vim.v.count1)
    end,
})

vim.api.nvim_set_keymap("n", "<Plug>(qf-rancher-ll-newer)", "<nop>", {
    noremap = true,
    desc = "<Plug> Go to a newer location list",
    callback = function()
        M.l_newer(vim.v.count1)
    end,
})

vim.api.nvim_set_keymap("n", "<Plug>(qf-rancher-ll-history)", "<nop>", {
    noremap = true,
    desc = "<Plug> View or jump within the loclist history",
    callback = function()
        M.l_history(vim.v.count)
    end,
})

vim.api.nvim_set_keymap("n", "<Plug>(qf-rancher-ll-del)", "<nop>", {
    noremap = true,
    desc = "<Plug> Delete a list from the loclist stack",
    callback = function()
        M.l_del(vim.v.count)
    end,
})

vim.api.nvim_set_keymap("n", "<Plug>(qf-rancher-ll-del-all)", "<nop>", {
    noremap = true,
    desc = "<Plug> Delete all items from the loclist stack",
    callback = function()
        M.l_del_all()
    end,
})

--------------------
--- Default Maps ---
--------------------

if vim.g.qfrancher_setdefaultmaps then
    vim.api.nvim_set_keymap("n", "<leader>q[", "<Plug>(qf-rancher-qf-older)", {
        noremap = true,
        desc = "Go to an older qflist",
    })

    vim.api.nvim_set_keymap("n", "<leader>q]", "<Plug>(qf-rancher-qf-newer)", {
        noremap = true,
        desc = "Go to a newer qflist",
    })

    vim.api.nvim_set_keymap("n", "<leader>qQ", "<Plug>(qf-rancher-qf-history)", {
        noremap = true,
        desc = "View or jump within the quickfix history",
    })

    vim.api.nvim_set_keymap("n", "<leader>qe", "<Plug>(qf-rancher-qf-del)", {
        noremap = true,
        desc = "Delete a list from the quickfix stack",
    })

    vim.api.nvim_set_keymap("n", "<leader>qE", "<Plug>(qf-rancher-qf-del-all)", {
        noremap = true,
        desc = "Delete all items from the quickfix stack",
    })

    vim.api.nvim_set_keymap("n", "<leader>l[", "<Plug>(qf-rancher-ll-older)", {
        noremap = true,
        desc = "Go to an older loclist",
    })

    vim.api.nvim_set_keymap("n", "<leader>l]", "<Plug>(qf-rancher-ll-newer)", {
        noremap = true,
        desc = "Go to a newer loclist",
    })

    vim.api.nvim_set_keymap("n", "<leader>lL", "<Plug>(qf-rancher-ll-history)", {
        noremap = true,
        desc = "View or jump within the loclist history",
    })

    vim.api.nvim_set_keymap("n", "<leader>le", "<Plug>(qf-rancher-ll-del)", {
        noremap = true,
        desc = "Delete a list from the loclist stack",
    })

    vim.api.nvim_set_keymap("n", "<leader>lE", "<Plug>(qf-rancher-ll-del-all)", {
        noremap = true,
        desc = "<Plug> Delete all items from the loclist stack",
    })
end

------------
--- Cmds ---
------------

if vim.g.qfrancher_setdefaultcmds then
    vim.api.nvim_create_user_command("Qolder", function(arg)
        local count = arg.count > 0 and arg.count or 1
        M.q_older(count)
    end, { count = 0 })

    vim.api.nvim_create_user_command("Qnewer", function(arg)
        local count = arg.count > 0 and arg.count or 1
        M.q_newer(count)
    end, { count = 0 })

    vim.api.nvim_create_user_command("Qhistory", function(arg)
        local count = arg.count >= 0 and arg.count or 0
        M.q_history(count)
    end, { count = 0 })

    -- DOCUMENT: "all" overrides count
    -- NOTE: Ideally, a count would override the "all" arg, in order to default to safer behavior,
    -- but the dict sent to the callback includes a count of 0 whether it was explicitly passed or
    -- not. Since a count of 0 can be explicitly passed, only overriding a count > 0 is convoluted
    vim.api.nvim_create_user_command("Qdelete", function(arg)
        if arg.args == "all" then
            M.q_del_all()
            return
        end

        local count = arg.count >= 0 and arg.count or 0
        M.q_del(count)
    end, { count = 0, nargs = "?" })

    vim.api.nvim_create_user_command("Lolder", function(arg)
        local count = arg.count > 0 and arg.count or 1
        M.l_older(count)
    end, { count = 0 })

    vim.api.nvim_create_user_command("Lnewer", function(arg)
        local count = arg.count > 0 and arg.count or 1
        M.l_newer(count)
    end, { count = 0 })

    vim.api.nvim_create_user_command("Lhistory", function(arg)
        local count = arg.count >= 0 and arg.count or 0
        M.l_history(count)
    end, { count = 0 })

    -- DOCUMENT: "all" overrides count
    -- NOTE: Ideally, a count would override the "all" arg, in order to default to safer behavior,
    -- but the dict sent to the callback includes a count of 0 whether it was explicitly passed or
    -- not. Since a count of 0 can be explicitly passed, only overriding a count > 0 is convoluted
    vim.api.nvim_create_user_command("Ldelete", function(arg)
        if arg.args == "all" then
            M.l_del_all()
            return
        end

        local count = arg.count >= 0 and arg.count or 0
        M.l_del(count)
    end, { count = 0, nargs = "?" })
end

return M
