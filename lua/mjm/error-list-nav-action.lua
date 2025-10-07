--- @class QfRancherNav
local M = {}

-------------------
--- MODULE DATA ---
-------------------

local empty_qf_list = "No items in quickfix list"

---------------------
--- NAV FUNCTIONS ---
---------------------

--- @return integer
local function get_cur_qf_list_size()
    local size = vim.fn.getqflist({ size = 0 }).size --- @type integer
    if size < 1 then
        vim.api.nvim_echo({ { empty_qf_list, "" } }, false, {})
    end

    return size
end

--- @param count1 integer
--- @param arithmetic function
--- @return integer|nil
local function get_qf_new_idx(count1, arithmetic)
    require("mjm.error-list-types")._validate_count1(count1)
    vim.validate("arithmetic", arithmetic, "callable")

    local size = get_cur_qf_list_size() --- @type integer
    if size < 1 then
        return nil
    end

    local cur_idx = vim.fn.getqflist({ idx = 0 }).idx --- @type integer
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

    local msg = result or ("Unknown error displaying list entry " .. new_idx) --- @type string
    vim.api.nvim_echo({ { msg, "ErrorMsg" } }, true, { err = true })
end

--- @param count integer
--- @return nil
function M._q_prev(count)
    count = require("mjm.error-list-util")._count_to_count1()

    --- @type integer|nil
    local new_idx = get_qf_new_idx(count, require("mjm.error-list-util")._wrapping_sub)
    if new_idx then
        goto_list_entry(new_idx, "cc")
    end
end

--- @param count integer
--- @return nil
function M._q_next(count)
    count = require("mjm.error-list-util")._count_to_count1()

    --- @type integer|nil
    local new_idx = get_qf_new_idx(count, require("mjm.error-list-util")._wrapping_add)
    if new_idx then
        goto_list_entry(new_idx, "cc")
    end
end

--- DOCUMENT: That Qq with no count goes to current entry, which is a difference from :cc
---     this also applies to :Ll / :ll

--- @param count integer
--- @return nil
-- Meant for cmd mapping only
function M._q_q(count)
    require("mjm.error-list-types")._validate_count(count)

    local size = get_cur_qf_list_size() --- @type integer
    if size < 1 then
        return
    end

    if count == 0 then
        local cur_win = vim.api.nvim_get_current_win() --- @type integer
        local wintype = vim.fn.win_gettype(cur_win) --- @type string
        if wintype == "quickfix" then
            local row = vim.api.nvim_win_get_cursor(cur_win)[1] --- @type integer
            count = math.min(row, size)
        else
            local idx = vim.fn.getqflist({ idx = 0 }).idx --- @type integer
            count = idx
        end
    end

    goto_list_entry(count, "cc")
end

--- @param count integer
--- @return nil
function M._q_rewind(count)
    require("mjm.error-list-types")._validate_count(count)
    if get_cur_qf_list_size() >= 1 then
        local adj_count = count >= 1 and count or nil --- @type integer|nil
        vim.api.nvim_cmd({ cmd = "crewind", count = adj_count }, {})
    end
end

--- @param count integer
--- @return nil
function M._q_last(count)
    require("mjm.error-list-types")._validate_count(count)
    if get_cur_qf_list_size() >= 1 then
        local adj_count = count >= 1 and count or nil --- @type integer|nil
        vim.api.nvim_cmd({ cmd = "clast", count = adj_count }, {})
    end
end

--- @param count1 integer
--- @param cmd string
--- @param backup_cmd string
--- @return nil
local function file_nav_wrap(count1, cmd, backup_cmd)
    if vim.g.qf_rancher_debug_assertions then
        require("mjm.error-list-types")._validate_count1(count1)
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

--- @param count integer
--- @return nil
function M._q_pfile(count)
    count = require("mjm.error-list-util")._count_to_count1()

    if get_cur_qf_list_size() >= 1 then
        file_nav_wrap(count, "cpfile", "clast")
    end
end

--- @param count integer
--- @return nil
function M._q_nfile(count)
    count = require("mjm.error-list-util")._count_to_count1()

    if get_cur_qf_list_size() >= 1 then
        file_nav_wrap(count, "cnfile", "crewind")
    end
end

--- @param win? integer
--- @return integer|nil, integer|nil, integer|nil
local function _get_cur_ll_info(win)
    vim.validate("win", win, { "nil", "number" })

    local cur_win = win or vim.api.nvim_get_current_win() --- @type integer
    local qf_id = vim.fn.getloclist(cur_win, { nr = 0 }).nr --- @type integer
    if qf_id == 0 then
        vim.api.nvim_echo({ { "Current window has no location list", "" } }, false, {})
        return nil, nil, nil
    end

    local cur_stack_nr = vim.fn.getloclist(cur_win, { nr = 0 }).nr --- @type integer
    local size = vim.fn.getloclist(cur_win, { nr = cur_stack_nr, size = 0 }).size --- @type integer
    if size < 1 then
        vim.api.nvim_echo({ { "No items in the location list", "" } }, false, {})
        return nil, nil, nil
    end

    return qf_id, cur_stack_nr, size
end

--- @param count1 integer
--- @param arithmetic function
--- @return integer|nil
local function get_ll_new_idx(count1, arithmetic)
    require("mjm.error-list-types")._validate_count1(count1)

    local cur_win = vim.api.nvim_get_current_win() --- @type integer
    --- @type integer|nil, integer|nil, integer|nil
    local qf_id, cur_stack_nr, size = _get_cur_ll_info(cur_win)
    if not (qf_id and cur_stack_nr and size) then
        return
    end

    --- @type integer
    local cur_idx = vim.fn.getloclist(cur_win, { nr = cur_stack_nr, idx = 0 }).idx
    return arithmetic(cur_idx, count1, 1, size)
end

--- @param count integer
--- @return nil
function M._l_prev(count)
    count = require("mjm.error-list-util")._count_to_count1()

    --- @type integer|nil
    local new_idx = get_ll_new_idx(count, require("mjm.error-list-util")._wrapping_sub)
    if new_idx then
        goto_list_entry(new_idx, "ll")
    end
end

--- @param count integer
--- @return nil
function M._l_next(count)
    count = require("mjm.error-list-util")._count_to_count1()

    --- @type integer|nil
    local new_idx = get_ll_new_idx(count, require("mjm.error-list-util")._wrapping_add)
    if new_idx then
        goto_list_entry(new_idx, "ll")
    end
end

--- @param count integer
--- @return nil
function M._l_l(count)
    require("mjm.error-list-types")._validate_count(count)

    local cur_win = vim.api.nvim_get_current_win() --- @type integer
    --- @type integer|nil, integer|nil, integer|nil
    local qf_id, cur_stack_nr, size = _get_cur_ll_info(cur_win)
    if not (qf_id and cur_stack_nr and size) then
        return
    end

    if count == 0 then
        local wintype = vim.fn.win_gettype(cur_win) --- @type string
        if wintype == "loclist" then
            local row = vim.api.nvim_win_get_cursor(cur_win)[1] --- @type integer
            count = math.min(row, size)
        else
            local idx = vim.fn.getloclist(cur_win, { idx = 0 }).idx --- @type integer
            count = idx
        end
    end

    goto_list_entry(count, "ll")
end

--- @param count integer
--- @return nil
function M._l_rewind(count)
    require("mjm.error-list-types")._validate_count(count)

    --- @type integer|nil, integer|nil, integer|nil
    local qf_id, cur_stack_nr, size = _get_cur_ll_info()
    if not (qf_id and cur_stack_nr and size) then
        return
    end

    local adj_count = count >= 1 and count or nil --- @type integer|nil
    vim.api.nvim_cmd({ cmd = "lrewind", count = adj_count }, {})
end

--- @param count integer
--- @return nil
function M._l_last(count)
    require("mjm.error-list-types")._validate_count(count)

    --- @type integer|nil, integer|nil, integer|nil
    local qf_id, cur_stack_nr, size = _get_cur_ll_info()
    if not (qf_id and cur_stack_nr and size) then
        return
    end

    local adj_count = count >= 1 and count or nil --- @type integer|nil
    vim.api.nvim_cmd({ cmd = "llast", count = adj_count }, {})
end

--- @param count integer
--- @return nil
function M._l_pfile(count)
    count = require("mjm.error-list-util")._count_to_count1()

    --- @type integer|nil, integer|nil, integer|nil
    local qf_id, cur_stack_nr, size = _get_cur_ll_info()
    if not (qf_id and cur_stack_nr and size) then
        return
    end

    file_nav_wrap(count, "lpfile", "llast")
end

--- @param count integer
--- @return nil
function M._l_nfile(count)
    count = require("mjm.error-list-util")._count_to_count1()

    --- @type integer|nil, integer|nil, integer|nil
    local qf_id, cur_stack_nr, size = _get_cur_ll_info()
    if not (qf_id and cur_stack_nr and size) then
        return
    end

    file_nav_wrap(count, "lnfile", "lrewind")
end

return M

------------
--- TODO ---
------------

--- Deep auditing/testing
--- [q]q enter errors
