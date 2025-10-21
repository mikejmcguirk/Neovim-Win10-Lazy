local et = Qfr_Defer_Require("mjm.error-list-tools") ---@type QfrTools
local eu = Qfr_Defer_Require("mjm.error-list-util") ---@type QfrUtil
local ey = Qfr_Defer_Require("mjm.error-list-types") ---@type QfrTypes

local api = vim.api
local fn = vim.fn

---@mod Nav Navigate lists

--- @class QfRancherNav
local Nav = {}

-- ============
-- == LOCALS ==
-- ============

---@param new_idx integer
---@param cmd string
---@param opts table
---@return boolean
local function goto_list_entry(new_idx, cmd, opts)
    ey._validate_uint(new_idx)
    vim.validate("cmd", cmd, "string")
    vim.validate("opts", opts, "table")

    ---@type boolean, string
    local ok, result = pcall(api.nvim_cmd, { cmd = cmd, count = new_idx }, {})
    if ok then
        eu._do_zzze(api.nvim_get_current_win())
        return true
    end

    local msg = result or ("Unknown error displaying list entry " .. new_idx) ---@type string
    api.nvim_echo({ { msg, "ErrorMsg" } }, true, { err = true })
    return false
end

---@param src_win integer|nil
---@param count integer
---@return nil
local function goto_specific_idx(src_win, count)
    ey._validate_win(src_win, true)
    ey._validate_uint(count)

    local size = et._get_list(src_win, { size = 0 }).size ---@type integer
    if not size or size < 1 then return nil end

    local cmd = src_win and "ll" or "cc" ---@type string
    if count > 0 then
        local adj_count = math.min(count, size) ---@type integer
        goto_list_entry(adj_count, cmd, {})
        return
    end

    -- If we're in a list, go to the entry under the cursor
    local cur_win = src_win or api.nvim_get_current_win() ---@type integer
    local wintype = fn.win_gettype(cur_win)
    local in_loclist = type(src_win) == "number" and wintype == "loclist" ---@type boolean
    local in_qflist = (not src_win) and wintype == "quickfix" ---@type boolean
    if in_loclist or in_qflist then
        local row = api.nvim_win_get_cursor(cur_win)[1] ---@type integer
        local adj_count = math.min(row, size) ---@type integer
        goto_list_entry(adj_count, cmd, {})
        return
    end

    local cur_idx = et._get_list(src_win, { idx = 0 }).idx ---@type integer
    if cur_idx < 1 then return end

    goto_list_entry(cur_idx, cmd, {})
end

-- REWIND/LAST --

-- MID: This works, but isn't really different from the goto_list_entry function

---@param count integer
---@param cmd string
---@return nil
local function bookends(count, cmd)
    ey._validate_uint(count)
    vim.validate("cmd", cmd, "string")

    local adj_count = count >= 1 and count or nil ---@type integer|nil
    ---@type boolean, string
    local ok, err = pcall(api.nvim_cmd, { cmd = cmd, count = adj_count }, {})
    if ok then
        eu._do_zzze(api.nvim_get_current_win())
        return
    end

    local msg = err:sub(#"Vim:" + 1) ---@type string
    if string.find(err, "E42", 1, true) then
        api.nvim_echo({ { msg, "" } }, false, {})
    else
        api.nvim_echo({ { msg, "ErrorMsg" } }, true, { err = true })
    end
end

---@param src_win integer|nil
---@param count integer
---@param cmd string
---@param backup_cmd string
---@return nil
local function file_nav_wrap(src_win, count, cmd, backup_cmd)
    ey._validate_win(src_win, true)
    ey._validate_uint(count)
    vim.validate("cmd", cmd, "string")
    vim.validate("backup_cmd", backup_cmd, "string")

    local size = et._get_list(src_win, { size = 0 }).size ---@type integer
    if not size or size < 1 then
        api.nvim_echo({ { "E42: No Errors", "" } }, false, {})
        return nil
    end

    local adj_count = eu._count_to_count1(count) ---@type integer

    ---@type boolean, string
    local ok, err = pcall(api.nvim_cmd, { cmd = cmd, count = adj_count }, {})
    local e42 = string.find(err, "E42", 1, true) ---@type integer|nil
    local e776 = string.find(err, "E776", 1, true) ---@type integer|nil
    if (not ok) and (e42 or e776) then
        api.nvim_echo({ { err:sub(#"Vim:" + 1), "" } }, false, {})
        return
    end

    local e553 = string.find(err, "E553", 1, true) ---@type integer|nil
    if (not ok) and e553 then
        ok, err = pcall(api.nvim_cmd, { cmd = backup_cmd }, {})
    end

    if not ok then
        local msg = err and err:sub(#"Vim:" + 1) or "Unknown qf file error" ---@type string
        api.nvim_echo({ { msg, "ErrorMsg" } }, true, { err = true })
        return
    end

    eu._do_zzze(api.nvim_get_current_win())
end

-- ================
-- == PUBLIC API ==
-- ================

-- PREV/NEXT --

---@param cargs vim.api.keyset.create_user_command.command_args
---@return nil
function Nav.q_prev_cmd(cargs)
    Nav._q_prev(cargs.count, {})
end

---@param cargs vim.api.keyset.create_user_command.command_args
---@return nil
function Nav.q_next_cmd(cargs)
    Nav._q_next(cargs.count, {})
end

---@param cargs vim.api.keyset.create_user_command.command_args
---@return nil
function Nav.l_prev_cmd(cargs)
    Nav._l_prev(api.nvim_get_current_win(), cargs.count, {})
end

---@param cargs vim.api.keyset.create_user_command.command_args
---@return nil
function Nav.l_next_cmd(cargs)
    Nav._l_next(api.nvim_get_current_win(), cargs.count, {})
end

-- GOTO SPECIFIC INDEX --

-- DOCUMENT: That Qq with no count goes to current entry, which is a difference from :cc
--     this also applies to :Ll / :ll

---@param cargs vim.api.keyset.create_user_command.command_args
---@return nil
function Nav.q_q_cmd(cargs)
    Nav._q_q(cargs.count)
end

---@param cargs vim.api.keyset.create_user_command.command_args
---@return nil
function Nav.l_l_cmd(cargs)
    Nav._l_l(api.nvim_get_current_win(), cargs.count)
end

-- DOCUMENT: This goes to specific indexes

-- REWIND/LAST --

---@param cargs vim.api.keyset.create_user_command.command_args
---@return nil
function Nav.q_rewind_cmd(cargs)
    Nav._q_rewind(cargs.count)
end

---@param cargs vim.api.keyset.create_user_command.command_args
---@return nil
function Nav.q_last_cmd(cargs)
    Nav._q_last(cargs.count)
end

---@param cargs vim.api.keyset.create_user_command.command_args
---@return nil
function Nav.l_rewind_cmd(cargs)
    Nav._l_rewind(api.nvim_get_current_win(), cargs.count)
end

---@param cargs vim.api.keyset.create_user_command.command_args
---@return nil
function Nav.l_last_cmd(cargs)
    Nav._l_last(api.nvim_get_current_win(), cargs.count)
end

-- FILE NAV --

-- DOCUMENT: The wrap isn't as precise as prev/next

---@param cargs vim.api.keyset.create_user_command.command_args
---@return nil
function Nav.q_pfile_cmd(cargs)
    Nav._q_pfile(cargs.count)
end

---@param cargs vim.api.keyset.create_user_command.command_args
---@return nil
function Nav.q_nfile_cmd(cargs)
    Nav._q_nfile(cargs.count)
end

---@param cargs vim.api.keyset.create_user_command.command_args
---@return nil
function Nav.l_pfile_cmd(cargs)
    Nav._l_pfile(api.nvim_get_current_win(), cargs.count)
end

---@param cargs vim.api.keyset.create_user_command.command_args
---@return nil
function Nav.l_nfile_cmd(cargs)
    Nav._l_nfile(api.nvim_get_current_win(), cargs.count)
end

---@export Nav

-- =================
-- == UNSUPPORTED ==
-- =================

-- PREV/NEXT --

---@param count integer
---@param opts table
---@return boolean
function Nav._q_prev(count, opts)
    local new_idx = eu._get_idx_wrapping_sub(nil, count) ---@type integer|nil
    if new_idx then return goto_list_entry(new_idx, "cc", opts) end
    return false
end

---@param count integer
---@param opts table
---@return boolean
function Nav._q_next(count, opts)
    local new_idx = eu._get_idx_wrapping_add(nil, count) ---@type integer|nil
    if new_idx then return goto_list_entry(new_idx, "cc", opts) end
    return false
end

---@param src_win integer
---@param count integer
---@param opts table
---@return boolean
function Nav._l_prev(src_win, count, opts)
    return eu._locwin_check(src_win, function()
        local new_idx = eu._get_idx_wrapping_sub(src_win, count) ---@type integer|nil
        if new_idx then goto_list_entry(new_idx, "ll", opts) end
    end)
end

---@param src_win integer
---@param count integer
---@param opts table
---@return boolean
function Nav._l_next(src_win, count, opts)
    return eu._locwin_check(src_win, function()
        local new_idx = eu._get_idx_wrapping_add(src_win, count) ---@type integer|nil
        if new_idx then goto_list_entry(new_idx, "ll", opts) end
    end)
end

-- GOTO SPECIFIC INDEX --

-- MID: [Q]Q is a bit awkward for going to a specific index

---@param count integer
---@return nil
function Nav._q_q(count)
    goto_specific_idx(nil, count)
end

---@param win integer
---@param count integer
---@return nil
function Nav._l_l(win, count)
    eu._locwin_check(win, function()
        goto_specific_idx(win, count)
    end)
end

-- REWIND/LAST --

---@param count integer
---@return nil
function Nav._q_rewind(count)
    bookends(count, "crewind")
end

---@param count integer
---@return nil
function Nav._q_last(count)
    bookends(count, "clast")
end

---@param win integer
---@param count integer
---@return nil
function Nav._l_rewind(win, count)
    eu._locwin_check(win, function()
        bookends(count, "lrewind")
    end)
end

---@param win integer
---@param count integer
---@return nil
function Nav._l_last(win, count)
    eu._locwin_check(win, function()
        bookends(count, "llast")
    end)
end

-- FILE NAV --

---@param count integer
---@return nil
function Nav._q_pfile(count)
    file_nav_wrap(nil, count, "cpfile", "clast")
end

---@param count integer
---@return nil
function Nav._q_nfile(count)
    file_nav_wrap(nil, count, "cnfile", "crewind")
end

---@param win integer
---@param count integer
---@return nil
function Nav._l_pfile(win, count)
    eu._locwin_check(win, function()
        file_nav_wrap(win, count, "lpfile", "llast")
    end)
end

---@param win integer
---@param count integer
---@return nil
function Nav._l_nfile(win, count)
    eu._locwin_check(win, function()
        file_nav_wrap(win, count, "lnfile", "lrewind")
    end)
end

return Nav

-- TODO: Testing
-- TODO: Docs
