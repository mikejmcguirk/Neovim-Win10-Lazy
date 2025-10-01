local M = {}

--- @param count1 integer
--- @param arithmetic function
--- @return integer|nil
local function get_qf_new_idx(count1, arithmetic)
    require("mjm.error-list-util")._validate_count1(count1)
    vim.validate("arithmetic", arithmetic, "callable")

    local cur_stack_nr = vim.fn.getqflist({ nr = 0 }).nr --- @type integer
    local size = vim.fn.getqflist({ nr = cur_stack_nr, size = 0 }).size --- @type integer
    if size < 1 then
        vim.api.nvim_echo({ { "No items in quickfix list", "" } }, false, {})
        return nil
    end

    local cur_idx = vim.fn.getqflist({ nr = cur_stack_nr, idx = 0 }).idx --- @type integer
    return arithmetic(cur_idx, count1, 1, size)
end

--- @param new_idx integer
--- @param cmd string
--- @return nil
local function goto_list_entry(new_idx, cmd)
    vim.validate("new_idx", new_idx, "number")
    vim.validate("cmd", cmd, "string")

    --- @type boolean, string
    local ok, result = pcall(vim.api.nvim_cmd, { cmd = cmd, count = new_idx }, {})
    if ok then
        vim.api.nvim_cmd({ cmd = "normal", args = { "zz" }, bang = true }, {})
        return
    end

    local msg = result or ("Unknown error displaying list entry " .. new_idx)
    vim.api.nvim_echo({ { msg, "ErrorMsg" } }, true, { err = true })
end

--- @param count1 integer
--- @return nil
function M.q_prev(count1)
    --- @type integer|nil
    local new_idx = get_qf_new_idx(count1, require("mjm.error-list-util")._wrapping_sub)
    if new_idx then
        goto_list_entry(new_idx, "cc")
    end
end

--- @param count1 integer
--- @return nil
function M.q_next(count1)
    --- @type integer|nil
    local new_idx = get_qf_new_idx(count1, require("mjm.error-list-util")._wrapping_add)
    if new_idx then
        goto_list_entry(new_idx, "cc")
    end
end

--- @param count1 integer
--- @return nil
-- Meant for cmd mapping only
function M.q_q(count1)
    require("mjm.error-list-util")._validate_count1(count1)

    local cur_stack_nr = vim.fn.getqflist({ nr = 0 }).nr --- @type integer
    local size = vim.fn.getqflist({ nr = cur_stack_nr, size = 0 }).size --- @type integer
    if size < 1 then
        vim.api.nvim_echo({ { "No items in quickfix list", "" } }, false, {})
        return
    end

    count1 = math.min(count1, size)
    goto_list_entry(count1, "cc")
end

-- TODO: For rewind and last, the idea is we eat counts less than one in order to goto the
-- beginning by default. But I'm not sure if this properly mimicks doing 0chistory vs chistory
-- Would need to check the cargs to see what count passes when hitting 0 vs not entering one

--- @param count integer
--- @return nil
function M.q_rewind(count)
    require("mjm.error-list-util")._validate_count(count)

    local cur_stack_nr = vim.fn.getqflist({ nr = 0 }).nr --- @type integer
    local size = vim.fn.getqflist({ nr = cur_stack_nr, size = 0 }).size --- @type integer
    if size < 1 then
        vim.api.nvim_echo({ { "No items in quickfix list", "" } }, false, {})
        return
    end

    local adj_count = count >= 1 and count or nil
    vim.api.nvim_cmd({ cmd = "crewind", count = adj_count }, {})
end

--- @param count integer
--- @return nil
function M.q_last(count)
    require("mjm.error-list-util")._validate_count(count)

    local cur_stack_nr = vim.fn.getqflist({ nr = 0 }).nr --- @type integer
    local size = vim.fn.getqflist({ nr = cur_stack_nr, size = 0 }).size --- @type integer
    if size < 1 then
        vim.api.nvim_echo({ { "No items in quickfix list", "" } }, false, {})
        return
    end

    local adj_count = count >= 1 and count or nil
    vim.api.nvim_cmd({ cmd = "clast", count = adj_count }, {})
end

--- @param count1 integer
--- @param cmd string
--- @param backup_cmd string
--- @return nil
local function file_nav_wrap(count1, cmd, backup_cmd)
    if vim.g.qf_rancher_debug_assertions then
        require("mjm.error-list-util")._validate_count1(count1)
        vim.validate("cmd", cmd, "string")
        vim.validate("backup_cmd", backup_cmd, "string")
    end

    --- @type boolean, string
    local ok, err = pcall(vim.api.nvim_cmd, { cmd = cmd, count = count1 }, {})
    local e42 = string.find(err, "E42", 1, true) ~= nil --- @type boolean
    local e776 = string.find(err, "E776", 1, true) ~= nil --- @type boolean
    if (not ok) and (e42 or e776) then
        vim.api.nvim_echo({ { err:sub(#"Vim:" + 1), "" } }, false, {})
        return
    end

    local e553 = string.find(err, "E553", 1, true) ~= nil --- @type boolean
    if (not ok) and e553 then
        ok, err = pcall(vim.api.nvim_cmd, { cmd = backup_cmd }, {})
    end

    if not ok then
        local msg = err and err:sub(#"Vim:" + 1) or "Unknown qf file error" --- @type string
        vim.api.nvim_echo({ { msg, "ErrorMsg" } }, true, { err = true })
        return
    end

    vim.api.nvim_cmd({ cmd = "normal", args = { "zz" }, bang = true }, {})
end

--- @param count1 integer
--- @return nil
function M.q_pfile(count1)
    local cur_stack_nr = vim.fn.getqflist({ nr = 0 }).nr --- @type integer
    local size = vim.fn.getqflist({ nr = cur_stack_nr, size = 0 }).size --- @type integer
    if size < 1 then
        vim.api.nvim_echo({ { "No items in quickfix list", "" } }, false, {})
        return nil
    end

    file_nav_wrap(count1, "cpfile", "clast")
end

--- @param count1 integer
--- @return nil
function M.q_nfile(count1)
    local cur_stack_nr = vim.fn.getqflist({ nr = 0 }).nr --- @type integer
    local size = vim.fn.getqflist({ nr = cur_stack_nr, size = 0 }).size --- @type integer
    if size < 1 then
        vim.api.nvim_echo({ { "No items in quickfix list", "" } }, false, {})
        return nil
    end

    file_nav_wrap(count1, "cnfile", "crewind")
end

-- TODO: I think the jump commands are the ones with the redundancy issues right?

--- @param count integer
--- @return nil
function M.q_jump(count)
    require("mjm.error-list-util")._validate_count(count)
    local cur_stack_nr = vim.fn.getqflist({ nr = 0 }).nr --- @type integer
    local max_stack_nr = vim.fn.getqflist({ nr = "$" }).nr --- @type integer
    count = math.min(count, max_stack_nr)
    local qf_win = require("mjm.error-list-util")._find_qf_win() --- @type integer|nil
    if not qf_win then
        require("mjm.error-list-open")._open_qflist()
    else
        vim.api.nvim_set_current_win(qf_win)
    end

    if count > 0 and max_stack_nr > 0 and count ~= cur_stack_nr then
        require("mjm.error-list-stack").q_history(count)
    end
end

--- @param win? integer
--- @return integer|nil, integer|nil, integer|nil
local function get_cur_ll_info(win)
    vim.validate("win", win, { "nil", "number" })

    local cur_win = win or vim.api.nvim_get_current_win() --- @type integer
    local qf_id = vim.fn.getloclist(cur_win, { nr = 0 }).nr --- @type integer
    if qf_id == 0 then
        vim.api.nvim_echo({ { "Current window has no location list", "" } }, false, {})
        return nil, nil
    end

    local cur_stack_nr = vim.fn.getloclist(cur_win, { nr = 0 }).nr --- @type integer
    local size = vim.fn.getloclist(cur_win, { nr = cur_stack_nr, size = 0 }).size --- @type integer
    if size < 1 then
        vim.api.nvim_echo({ { "No items in the location list", "" } }, false, {})
        return nil, nil
    end

    return qf_id, cur_stack_nr, size
end

--- @param count1 integer
--- @param arithmetic function
--- @return integer|nil
local function get_ll_new_idx(count1, arithmetic)
    require("mjm.error-list-util")._validate_count1(count1)

    local cur_win = vim.api.nvim_get_current_win() --- @type integer
    --- @type integer|nil, integer|nil, integer|nil
    local qf_id, cur_stack_nr, size = get_cur_ll_info(cur_win)
    if not (qf_id and cur_stack_nr and size) then
        return
    end

    --- @type integer
    local cur_idx = vim.fn.getloclist(cur_win, { nr = cur_stack_nr, idx = 0 }).idx
    return arithmetic(cur_idx, count1, 1, size)
end

--- @param count1 integer
--- @return nil
function M.l_prev(count1)
    --- @type integer|nil
    local new_idx = get_ll_new_idx(count1, require("mjm.error-list-util")._wrapping_sub)
    if new_idx then
        goto_list_entry(new_idx, "ll")
    end
end

--- @param count1 integer
--- @return nil
function M.l_next(count1)
    --- @type integer|nil
    local new_idx = get_ll_new_idx(count1, require("mjm.error-list-util")._wrapping_add)
    if new_idx then
        goto_list_entry(new_idx, "ll")
    end
end

--- @param count1 integer
--- @return nil
function M.l_l(count1)
    require("mjm.error-list-util")._validate_count1(count1)

    --- @type integer|nil, integer|nil, integer|nil
    local qf_id, cur_stack_nr, size = get_cur_ll_info()
    if not (qf_id and cur_stack_nr and size) then
        return
    end

    count1 = math.min(count1, size)
    goto_list_entry(count1, "ll")
end

--- TODO: This needs to accept count
function M.l_rewind()
    --- @type integer|nil, integer|nil, integer|nil
    local qf_id, cur_stack_nr, size = get_cur_ll_info()
    if not (qf_id and cur_stack_nr and size) then
        return
    end

    vim.api.nvim_cmd({ cmd = "crewind" }, {})
end

--- TODO: This needs to accept count
function M.l_last()
    --- @type integer|nil, integer|nil, integer|nil
    local qf_id, cur_stack_nr, size = get_cur_ll_info()
    if not (qf_id and cur_stack_nr and size) then
        return
    end

    vim.api.nvim_cmd({ cmd = "clast" }, {})
end

--- @param count1 integer
--- @return nil
function M.l_pfile(count1)
    --- @type integer|nil, integer|nil, integer|nil
    local qf_id, cur_stack_nr, size = get_cur_ll_info()
    if not (qf_id and cur_stack_nr and size) then
        return
    end

    file_nav_wrap(count1, "lpfile", "llast")
end

--- @param count1 integer
--- @return nil
function M.l_nfile(count1)
    --- @type integer|nil, integer|nil, integer|nil
    local qf_id, cur_stack_nr, size = get_cur_ll_info()
    if not (qf_id and cur_stack_nr and size) then
        return
    end

    file_nav_wrap(count1, "lnfile", "lrewind")
end

--- TODO: this function is a mess
--- TODO: And I think it's also a redundancy one

function M.l_jump(count)
    require("mjm.error-list-util")._validate_count(count)

    local cur_win = vim.api.nvim_get_current_win() --- @type integer
    -- TODO: This abstraction is bad because it like mingles two things, we should get the
    -- qf id first, and then get the ll_win if we need it. It's more lines but it's more clear
    -- what is happening and why
    -- TODO: annotate everything after this is fixed
    local eu = require("mjm.error-list-util")
    local qf_id, ll_win = eu._get_loclist_info({ win = cur_win })
    if qf_id == 0 then
        vim.api.nvim_echo({ { "Current window has no location list", "" } }, false, {})
        return
    end

    local cur_stack_nr = vim.fn.getloclist(cur_win, { nr = 0 }).nr
    local max_stack_nr = vim.fn.getloclist(cur_win, { nr = "$" }).nr
    count = math.min(count, max_stack_nr)
    if not ll_win then
        require("mjm.error-list-open")._open_loclist()
    else
        vim.api.nvim_set_current_win(ll_win)
    end

    if count > 0 and count ~= cur_stack_nr then
        require("mjm.error-list-stack").l_history(count)
    end
end

return M

------------
--- TODO ---
------------

--- Map the rewind and last functions, plus make cmds for them

------------
--- TEST ---
------------

--- Make sure that the count1s are behaving the way I think they would
