local M = {}

local function wrapping_add(x, y, min_val, max_val)
    local period = max_val - min_val + 1
    return ((x - min_val + y) % period) + min_val
end

local function wrapping_sub(x, y, min_val, max_val)
    local period = max_val - min_val + 1
    return ((x - y - min_val) % period) + min_val
end

-- TODO: The logic between the history commands seems similar enough that you could pass an
-- is_loclist option in and use each function for both listtypes

function M.q_older(count)
    vim.validate("count", count, "number")
    vim.validate("count", count, function()
        return count > 0
    end)

    local stack_len = vim.fn.getqflist({ nr = "$" }).nr
    if stack_len < 1 then
        vim.api.nvim_echo({ { "No items in quickix stack", "" } }, false, {})
        return
    end

    local cur_stack_nr = vim.fn.getqflist({ nr = 0 }).nr
    local new_stack_nr = wrapping_sub(cur_stack_nr, count, 1, stack_len)

    vim.api.nvim_cmd({ cmd = "chistory", count = new_stack_nr }, {})
    local elo = require("mjm.error-list-open")
    elo.resize_qflist()
end

function M.q_newer(count)
    vim.validate("count", count, "number")
    vim.validate("count", count, function()
        return count > 0
    end)

    local stack_len = vim.fn.getqflist({ nr = "$" }).nr
    if stack_len < 1 then
        vim.api.nvim_echo({ { "No items in quickix stack", "" } }, false, {})
        return
    end

    local cur_stack_nr = vim.fn.getqflist({ nr = 0 }).nr
    local new_stack_nr = wrapping_add(cur_stack_nr, count, 1, stack_len)

    vim.api.nvim_cmd({ cmd = "chistory", count = new_stack_nr }, {})
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
        vim.api.nvim_echo({ { "No items in quickix stack", "" } }, false, {})
        return
    end

    if count < 1 then
        vim.api.nvim_cmd({ cmd = "chistory" }, {})
        return
    end

    -- TODO: This error could be a bit better
    if count > stack_len then
        vim.api.nvim_echo({ { "Invalid count " .. count, "" } }, false, {})
        return
    end

    vim.api.nvim_cmd({ cmd = "chistory", count = count }, {})
    local elo = require("mjm.error-list-open")
    elo.resize_qflist()
end

function M.l_older(count)
    vim.validate("count", count, "number")
    vim.validate("count", count, function()
        return count > 0
    end)

    local cur_win = vim.api.nvim_get_current_win()
    local qf_id = vim.fn.getloclist(cur_win, { id = 0 }).id
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
    local new_stack_nr = wrapping_sub(cur_stack_nr, count, 1, stack_len)

    vim.api.nvim_cmd({ cmd = "lhistory", count = new_stack_nr }, {})
    local elo = require("mjm.error-list-open")
    elo.resize_loclist()
end

function M.l_newer(count)
    vim.validate("count", count, "number")
    vim.validate("count", count, function()
        return count > 0
    end)

    local cur_win = vim.api.nvim_get_current_win()
    local qf_id = vim.fn.getloclist(cur_win, { id = 0 }).id
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
    local new_stack_nr = wrapping_add(cur_stack_nr, count, 1, stack_len)

    vim.api.nvim_cmd({ cmd = "lhistory", count = new_stack_nr }, {})
    local elo = require("mjm.error-list-open")
    elo.resize_loclist()
end

function M.l_history(count)
    vim.validate("count", count, "number")
    vim.validate("count", count, function()
        return count >= 0
    end)

    local cur_win = vim.api.nvim_get_current_win()
    local qf_id = vim.fn.getloclist(cur_win, { id = 0 }).id
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

    -- TODO: This error could be a bit better
    if count > stack_len then
        vim.api.nvim_echo({ { "Invalid count " .. count, "" } }, false, {})
        return
    end

    vim.api.nvim_cmd({ cmd = "lhistory", count = count }, {})
    local elo = require("mjm.error-list-open")
    elo.resize_loclist()
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
        M.q_older(vim.v.count1)
    end,
})

vim.api.nvim_set_keymap("n", "<Plug>(qf-rancher-qf-history)", "<nop>", {
    noremap = true,
    desc = "<Plug> View or jump within the quickfix history",
    callback = function()
        M.q_history(vim.v.count)
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
        M.l_older(vim.v.count1)
    end,
})

vim.api.nvim_set_keymap("n", "<Plug>(qf-rancher-ll-history)", "<nop>", {
    noremap = true,
    desc = "<Plug> View or jump within the loclist history",
    callback = function()
        M.l_history(vim.v.count)
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
end

return M
