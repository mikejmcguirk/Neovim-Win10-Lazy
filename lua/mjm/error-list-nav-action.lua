local M = {}

--- - Check that window height updates are triggered where appropriate
--- - Check that functions have proper visibility
--- - Check that all mappings have plugs and cmds
--- - Check that all maps/cmds/plugs have desc fieldss
--- - Check that all functions have annotations and documentation
--- - Check that the qf and loclist versions are both properly built for purpose. Should be able
---     to use the loclist function for buf/win specific info

-- TODO: Have an option for opening the list on cmd execution
-- TODO: Lots of repeated code here, including maybe with the stack module
-- TODO: Right now we have qQ, which is resize and change list without jump, and we have q<C-q>
-- which does that and also jumps to the list. It feels like qQ should be the one that jumps
-- and q<C-q> the one that doesn't
--      And it turns out qQ doesn't even resize so now I'm really not sure why I have both

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

function M.q_q(count1)
    vim.validate("count1", count1, "number")
    vim.validate("count1", count1, function()
        return count1 > 0
    end)

    local cur_stack_nr = vim.fn.getqflist({ nr = 0 }).nr
    local size = vim.fn.getqflist({ nr = cur_stack_nr, size = 0 }).size
    if size < 1 then
        vim.api.nvim_echo({ { "No items in quickfix list", "" } }, false, {})
        return
    end

    count1 = math.min(count1, size)
    local ok, result = vim.api.nvim_cmd({ cmd = "cc", count = count1 }, {})
    if ok then
        vim.api.nvim_cmd({ cmd = "normal", args = { "zz" }, bang = true }, {})
        return
    end

    local msg = result or ("Unknown error displaying list entry " .. count1)
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
        return count >= 0
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

function M.l_l(count)
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

function M.l_jump(count)
    vim.validate("count", count, "number")
    vim.validate("count", count, function()
        return count >= 0
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

-----------------
--- Plug Maps ---
-----------------

vim.api.nvim_set_keymap("n", "<Plug>(qf-rancher-qf-prev)", "<nop>", {
    noremap = true,
    desc = "<Plug> Go to a previous qf entry",
    callback = function()
        M.q_prev(vim.v.count1)
    end,
})

vim.api.nvim_set_keymap("n", "<Plug>(qf-rancher-qf-next)", "<nop>", {
    noremap = true,
    desc = "<Plug> Go to a later qf entry",
    callback = function()
        M.q_next(vim.v.count1)
    end,
})

vim.api.nvim_set_keymap("n", "<Plug>(qf-rancher-qf-pfile)", "<nop>", {
    noremap = true,
    desc = "<Plug> Go to the previous qf file",
    callback = function()
        M.q_pfile(vim.v.count1)
    end,
})

vim.api.nvim_set_keymap("n", "<Plug>(qf-rancher-qf-nfile)", "<nop>", {
    noremap = true,
    desc = "<Plug> Go to the next qf file",
    callback = function()
        M.q_nfile(vim.v.count1)
    end,
})

vim.api.nvim_set_keymap("n", "<Plug>(qf-rancher-qf-jump)", "<nop>", {
    noremap = true,
    desc = "<Plug> Jump to the qflist",
    callback = function()
        M.q_jump(vim.v.count)
    end,
})

vim.api.nvim_set_keymap("n", "<Plug>(qf-rancher-ll-prev)", "<nop>", {
    noremap = true,
    desc = "<Plug> Go to a previous loclist entry",
    callback = function()
        M.l_prev(vim.v.count1)
    end,
})

vim.api.nvim_set_keymap("n", "<Plug>(qf-rancher-ll-next)", "<nop>", {
    noremap = true,
    desc = "<Plug> Go to a previous loclist entry",
    callback = function()
        M.l_next(vim.v.count1)
    end,
})

vim.api.nvim_set_keymap("n", "<Plug>(qf-rancher-ll-pfile)", "<nop>", {
    noremap = true,
    desc = "<Plug> Go to the previous loclist file",
    callback = function()
        M.l_pfile(vim.v.count1)
    end,
})

vim.api.nvim_set_keymap("n", "<Plug>(qf-rancher-ll-nfile)", "<nop>", {
    noremap = true,
    desc = "<Plug> Go to the next loclist file",
    callback = function()
        M.l_nfile(vim.v.count1)
    end,
})

vim.api.nvim_set_keymap("n", "<Plug>(qf-rancher-ll-jump)", "<nop>", {
    noremap = true,
    desc = "<Plug> Jump to the loclist",
    callback = function()
        M.l_jump(vim.v.count)
    end,
})

--------------------
--- Default Maps ---
--------------------

if vim.g.qfrancher_setdefaultmaps then
    vim.api.nvim_set_keymap("n", "[q", "<Plug>(qf-rancher-qf-prev)", {
        noremap = true,
        desc = "Go to a previous qf entry",
    })

    vim.api.nvim_set_keymap("n", "]q", "<Plug>(qf-rancher-qf-next)", {
        noremap = true,
        desc = "Go to a later qf entry",
    })

    vim.api.nvim_set_keymap("n", "[<C-q>", "<Plug>(qf-rancher-qf-pfile)", {
        noremap = true,
        desc = "Go to the previous qf file",
    })

    vim.api.nvim_set_keymap("n", "]<C-q>", "<Plug>(qf-rancher-qf-nfile)", {
        noremap = true,
        desc = "Go to the next qf file",
    })

    vim.api.nvim_set_keymap("n", "<leader>q<C-q>", "<Plug>(qf-rancher-qf-jump)", {
        noremap = true,
        desc = "Jump to the qflist",
    })

    vim.api.nvim_set_keymap("n", "[l", "<Plug>(qf-rancher-ll-prev)", {
        noremap = true,
        desc = "Go to a previous loclist entry",
    })

    vim.api.nvim_set_keymap("n", "]l", "<Plug>(qf-rancher-ll-next)", {
        noremap = true,
        desc = "Go to a previous loclist entry",
    })

    vim.api.nvim_set_keymap("n", "[<C-l>", "<Plug>(qf-rancher-ll-pfile)", {
        noremap = true,
        desc = "Go to the previous loclist file",
    })

    vim.api.nvim_set_keymap("n", "]<C-l>", "<Plug>(qf-rancher-ll-nfile)", {
        noremap = true,
        desc = "Go to the next loclist file",
    })

    vim.api.nvim_set_keymap("n", "<leader>l<C-l>", "<Plug>(qf-rancher-ll-jump)", {
        noremap = true,
        desc = "Jump to the loclist",
    })
end

--------------------
--- Default Cmds ---
--------------------

if vim.g.qfrancher_setdefaultcmds then
    vim.api.nvim_create_user_command("Qprev", function(arg)
        local count = arg.count > 0 and arg.count or 1
        M.q_prev(count)
    end, { count = 0 })

    vim.api.nvim_create_user_command("Qnext", function(arg)
        local count = arg.count > 0 and arg.count or 1
        M.q_next(count)
    end, { count = 0 })

    vim.api.nvim_create_user_command("Qq", function(arg)
        local count = arg.count > 0 and arg.count or 1
        M.q_q(count)
    end, { count = 0 })

    vim.api.nvim_create_user_command("Qpfile", function(arg)
        local count = arg.count > 0 and arg.count or 1
        M.q_pfile(count)
    end, { count = 0 })

    vim.api.nvim_create_user_command("Qnfile", function(arg)
        local count = arg.count > 0 and arg.count or 1
        M.q_nfile(count)
    end, { count = 0 })

    vim.api.nvim_create_user_command("Qjump", function(arg)
        local count = arg.count >= 0 and arg.count or 0
        M.q_jump(count)
    end, { count = 0 })

    vim.api.nvim_create_user_command("Lprev", function(arg)
        local count = arg.count > 0 and arg.count or 1
        M.l_prev(count)
    end, { count = 0 })

    vim.api.nvim_create_user_command("Lnext", function(arg)
        local count = arg.count > 0 and arg.count or 1
        M.l_next(count)
    end, { count = 0 })

    vim.api.nvim_create_user_command("Lq", function(arg)
        local count = arg.count > 0 and arg.count or 1
        M.l_q(count)
    end, { count = 0 })

    vim.api.nvim_create_user_command("Lpfile", function(arg)
        local count = arg.count > 0 and arg.count or 1
        M.l_pfile(count)
    end, { count = 0 })

    vim.api.nvim_create_user_command("Lnfile", function(arg)
        local count = arg.count > 0 and arg.count or 1
        M.l_nfile(count)
    end, { count = 0 })

    vim.api.nvim_create_user_command("Ljump", function(arg)
        local count = arg.count >= 0 and arg.count or 0
        M.l_jump(count)
    end, { count = 0 })
end

return M
