--- @class QfRancherNav
local M = {}

local eu = Qfr_Defer_Require("mjm.error-list-util") --- @type QfRancherUtil
local ey = Qfr_Defer_Require("mjm.error-list-types") --- @type QfRancherTypes

local api = vim.api

-----------------
--- PREV/NEXT ---
-----------------

--- @param new_idx integer
--- @param cmd string
--- @param opts table
--- @return boolean
local function goto_list_entry(new_idx, cmd, opts)
    ey._validate_uint(new_idx)
    vim.validate("cmd", cmd, "string")
    vim.validate("opts", opts, "table")

    --- @type boolean, string
    local ok, result = pcall(vim.api.nvim_cmd, { cmd = cmd, count = new_idx }, {})
    if ok then
        eu._do_zzze(api.nvim_get_current_win())
        return true
    end

    local msg = result or ("Unknown error displaying list entry " .. new_idx) --- @type string
    vim.api.nvim_echo({ { msg, "ErrorMsg" } }, true, { err = true })
    return false
end

--- @param count integer
--- @param opts table
--- @return boolean
function M._q_prev(count, opts)
    --- @type integer|nil
    local new_idx = eu._get_idx_wrapping_sub(nil, count)
    if new_idx then return goto_list_entry(new_idx, "cc", opts) end
    return false
end

--- @param count integer
--- @param opts table
--- @return boolean
function M._q_next(count, opts)
    --- @type integer|nil
    local new_idx = eu._get_idx_wrapping_add(nil, count)
    if new_idx then return goto_list_entry(new_idx, "cc", opts) end
    return false
end

--- @param src_win integer
--- @param count integer
--- @param opts table
--- @return boolean
function M._l_prev(src_win, count, opts)
    return eu._locwin_check(src_win, function()
        --- @type integer|nil
        local new_idx = eu._get_idx_wrapping_sub(src_win, count)
        if new_idx then goto_list_entry(new_idx, "ll", opts) end
    end)
end

--- @param src_win integer
--- @param count integer
--- @param opts table
--- @return boolean
function M._l_next(src_win, count, opts)
    return eu._locwin_check(src_win, function()
        --- @type integer|nil
        local new_idx = eu._get_idx_wrapping_add(src_win, count)
        if new_idx then goto_list_entry(new_idx, "ll", opts) end
    end)
end

--- @param src_win integer|nil
--- @param count integer
--- @param opts table
--- @return boolean
function M._prev(src_win, count, opts)
    ey._validate_win(src_win, true)
    if src_win then
        return M._l_prev(src_win, count, opts)
    else
        return M._q_prev(count, opts)
    end
end

--- @param src_win integer|nil
--- @param count integer
--- @param opts table
--- @return boolean
function M._next(src_win, count, opts)
    ey._validate_win(src_win, true)
    if src_win then
        return M._l_next(src_win, count, opts)
    else
        return M._q_next(count, opts)
    end
end

--- @param cargs vim.api.keyset.create_user_command.command_args
--- @return nil
function M._q_prev_cmd(cargs)
    M._q_prev(cargs.count, {})
end

--- @param cargs vim.api.keyset.create_user_command.command_args
--- @return nil
function M._q_next_cmd(cargs)
    M._q_next(cargs.count, {})
end

--- @param cargs vim.api.keyset.create_user_command.command_args
--- @return nil
function M._l_prev_cmd(cargs)
    M._l_prev(vim.api.nvim_get_current_win(), cargs.count, {})
end

--- @param cargs vim.api.keyset.create_user_command.command_args
--- @return nil
function M._l_next_cmd(cargs)
    M._l_next(vim.api.nvim_get_current_win(), cargs.count, {})
end

-----------------
--- GOTO ITEM ---
-----------------

--- NOTE: These are for cmd mappings only
--- DOCUMENT: That Qq with no count goes to current entry, which is a difference from :cc
---     this also applies to :Ll / :ll

--- @param src_win integer|nil
--- @param count integer
--- @return nil
local function goto_specific_idx(src_win, count)
    ey._validate_win(src_win, true)
    ey._validate_uint(count)

    local et = require("mjm.error-list-tools") --- @type QfRancherTools
    local size = et._get_list_size(src_win, 0) --- @type integer|nil
    if not size or size < 1 then return nil end

    local cmd = src_win and "ll" or "cc" --- @type string
    if count > 0 then
        local adj_count = math.min(count, size) --- @type integer
        goto_list_entry(adj_count, cmd, {})
        return
    end

    local cur_win = src_win or vim.api.nvim_get_current_win() --- @type integer
    local wintype = vim.fn.win_gettype(cur_win)
    local in_loclist = type(src_win) == "number" and wintype == "loclist" --- @type boolean
    local in_qflist = (not src_win) and wintype == "quickfix" --- @type boolean
    if in_loclist or in_qflist then
        local row = vim.api.nvim_win_get_cursor(cur_win)[1] --- @type integer
        local adj_count = math.min(row, size) --- @type integer
        goto_list_entry(adj_count, cmd, {})
        return
    end

    local cur_idx = et._get_list_idx(src_win, 0) --- @type integer|nil
    if not cur_idx then return nil end

    goto_list_entry(cur_idx, cmd, {})
end

--- @param count integer
--- @return nil
-- Meant for cmd mapping only
function M._q_q(count)
    goto_specific_idx(nil, count)
end

--- @param win integer
--- @param count integer
--- @return nil
function M._l_l(win, count)
    eu._locwin_check(win, function()
        goto_specific_idx(win, count)
    end)
end

--- @param cargs vim.api.keyset.create_user_command.command_args
--- @return nil
function M._q_q_cmd(cargs)
    M._q_q(cargs.count)
end

--- @param cargs vim.api.keyset.create_user_command.command_args
--- @return nil
function M._l_l_cmd(cargs)
    M._l_l(vim.api.nvim_get_current_win(), cargs.count)
end

-------------------
--- REWIND/LAST ---
-------------------

--- @param count integer
--- @param cmd string
--- @return nil
local function bookends(count, cmd)
    require("mjm.error-list-types")._validate_uint(count)
    vim.validate("cmd", cmd, "string")

    local adj_count = count >= 1 and count or nil --- @type integer|nil
    --- @type boolean, string
    local ok, err = pcall(vim.api.nvim_cmd, { cmd = cmd, count = adj_count }, {})
    if ok then return end

    local msg = err:sub(#"Vim:" + 1) --- @type string
    if string.find(err, "E42", 1, true) then
        vim.api.nvim_echo({ { msg, "" } }, false, {})
    else
        vim.api.nvim_echo({ { msg, "ErrorMsg" } }, true, { err = true })
    end
end

--- @param count integer
--- @return nil
function M._q_rewind(count)
    bookends(count, "crewind")
end

--- @param count integer
--- @return nil
function M._q_last(count)
    bookends(count, "clast")
end

--- @param win integer
--- @param count integer
--- @return nil
function M._l_rewind(win, count)
    eu._locwin_check(win, function()
        bookends(count, "lrewind")
    end)
end

--- @param win integer
--- @param count integer
--- @return nil
function M._l_last(win, count)
    eu._locwin_check(win, function()
        bookends(count, "llast")
    end)
end

--- @param cargs vim.api.keyset.create_user_command.command_args
--- @return nil
function M._q_rewind_cmd(cargs)
    M._q_rewind(cargs.count)
end

--- @param cargs vim.api.keyset.create_user_command.command_args
--- @return nil
function M._q_last_cmd(cargs)
    M._q_last(cargs.count)
end

--- @param cargs vim.api.keyset.create_user_command.command_args
--- @return nil
function M._l_rewind_cmd(cargs)
    M._l_rewind(vim.api.nvim_get_current_win(), cargs.count)
end

--- @param cargs vim.api.keyset.create_user_command.command_args
--- @return nil
function M._l_last_cmd(cargs)
    M._l_last(vim.api.nvim_get_current_win(), cargs.count)
end

-----------------
--- NAV WRAPS ---
-----------------

--- @param src_win integer|nil
--- @param count integer
--- @param cmd string
--- @param backup_cmd string
--- @return nil
local function file_nav_wrap(src_win, count, cmd, backup_cmd)
    ey._validate_win(src_win, true)
    ey._validate_uint(count)
    vim.validate("cmd", cmd, "string")
    vim.validate("backup_cmd", backup_cmd, "string")

    local et = require("mjm.error-list-tools") --- @type QfRancherTools
    local size = et._get_list_size(src_win, 0) --- @type integer|nil
    if not size or size < 1 then return nil end

    local adj_count = eu._count_to_count1(count) --- @type integer

    --- @type boolean, string
    local ok, err = pcall(vim.api.nvim_cmd, { cmd = cmd, count = adj_count }, {})
    local e42 = string.find(err, "E42", 1, true) --- @type integer|nil
    local e776 = string.find(err, "E776", 1, true) --- @type integer|nil
    if (not ok) and (e42 or e776) then
        vim.api.nvim_echo({ { err:sub(#"Vim:" + 1), "" } }, false, {})
        return
    end

    local e553 = string.find(err, "E553", 1, true) --- @type integer|nil
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
    file_nav_wrap(nil, count, "cpfile", "clast")
end

--- @param count integer
--- @return nil
function M._q_nfile(count)
    file_nav_wrap(nil, count, "cnfile", "crewind")
end

--- @param win integer
--- @param count integer
--- @return nil
function M._l_pfile(win, count)
    eu._locwin_check(win, function()
        file_nav_wrap(win, count, "lpfile", "llast")
    end)
end

--- @param win integer
--- @param count integer
--- @return nil
function M._l_nfile(win, count)
    eu._locwin_check(win, function()
        file_nav_wrap(win, count, "lnfile", "lrewind")
    end)
end

--- @param cargs vim.api.keyset.create_user_command.command_args
--- @return nil
function M._q_pfile_cmd(cargs)
    M._q_pfile(cargs.count)
end

--- @param cargs vim.api.keyset.create_user_command.command_args
--- @return nil
function M._q_nfile_cmd(cargs)
    M._q_nfile(cargs.count)
end

--- @param cargs vim.api.keyset.create_user_command.command_args
--- @return nil
function M._l_pfile_cmd(cargs)
    M._l_pfile(vim.api.nvim_get_current_win(), cargs.count)
end

--- @param cargs vim.api.keyset.create_user_command.command_args
--- @return nil
function M._l_nfile_cmd(cargs)
    M._l_nfile(vim.api.nvim_get_current_win(), cargs.count)
end

return M

------------
--- TODO ---
------------

--- Testing
--- Docs
