local api = vim.api
local fn = vim.fn

local ntq = require("nvim-tools.quickfix")
local _util = require("qf-herder._util")

----------------
-- MARK: Util --
----------------

---@param idx_max uinteger
---@param silent boolean
---@return boolean
local function ensure_entries_or_echo(idx_max, silent)
    if idx_max >= 1 then
        return true
    end

    if not silent then
        api.nvim_echo({ { QFR_NO_ERRS, "" } }, false, {})
    end

    return false
end

---@param src_win uinteger|nil
---@param count uinteger?
---@param cmd string
---@param silent boolean
---@param do_zzze boolean
---@return boolean, string
local function cmd_do(src_win, count, cmd, silent, do_zzze)
    local function cmd_call()
        local ok, err = pcall(api.nvim_cmd, { cmd = cmd, count = count, silent = silent }, {})
        if ok and do_zzze then
            api.nvim_cmd({ cmd = "norm", args = { "zzze" }, bang = true }, {})
        end

        return ok, err
    end

    if src_win == nil then
        return cmd_call()
    else
        ---@diagnostic disable-next-line: missing-return-value
        return api.nvim_win_call(src_win, function()
            return cmd_call()
        end)
    end
end
-- TODO: I'm not sure this nvim_win_call multi-return works in v11 or v12.

---@param src_win integer|nil
---@param count1 integer
---@param silent boolean
---@param do_zzze boolean
---@param cmd string
---@param backup_cmd string
---@return nil
local function file_nav_wrap(src_win, count1, silent, do_zzze, cmd, backup_cmd)
    local list_info = ntq.get_list(src_win, { idx = 0, size = 0 })
    if not ensure_entries_or_echo(list_info.size, silent) then
        return
    end

    local ok, err = cmd_do(src_win, count1, cmd, silent, do_zzze)
    if ok then
        return
    end

    if string.find(err, "E42", 1, true) or string.find(err, "E776", 1, true) then
        api.nvim_echo({ { err:sub(#"Vim:" + 1), "" } }, false, {})
        return
    end

    if string.find(err, "E553", 1, true) then
        ok, err = cmd_do(src_win, nil, backup_cmd, silent, do_zzze)
    end

    if not ok then
        local msg = err and err:sub(#"Vim:" + 1) or "Unknown qf file error"
        api.nvim_echo({ { msg, "ErrorMsg" } }, true, {})
    end
end

---@param src_win uinteger|nil
---@param silent boolean
---@param count uinteger
---@param cmd string
---@param do_zzze boolean
local function bookends(src_win, silent, count, cmd, do_zzze)
    local list_info = ntq.get_list(src_win, { idx = 0, size = 0 })
    if not ensure_entries_or_echo(list_info.size, silent) then
        return
    end

    local ok, err = cmd_do(src_win, count >= 1 and count or nil, cmd, silent, do_zzze)
    if ok then
        return
    end

    api.nvim_echo({ { string.sub(err, #"Vim:" + 1), "ErrorMsg" } }, true, {})
end

---@param src_win uinteger? Location list window context
---@param count1 uinteger Wrapping count next entry to navigate to
---@param silent boolean
---@param math fun(x:uinteger, y:uinteger, min:uinteger, max:uinteger): uinteger
---@param do_zzze boolean
local function idx_change(src_win, count1, silent, math, do_zzze)
    local list_info = ntq.get_list(src_win, { idx = 0, size = 0 })
    local idx_max = list_info.size
    if ensure_entries_or_echo(idx_max, silent) then
        local cmd = src_win == nil and "cc" or "ll"
        cmd_do(src_win, math(list_info.idx, count1, 1, idx_max), cmd, silent, do_zzze)
    end
end

local M = {}

-------------------------------------
-- MARK: Relative Entry Navigation --
-------------------------------------

---@param count1 integer Wrapping count previous entry to navigate to
---@param silent boolean
---@param cfg qf-herder.nav.Cfg
---@return nil
function M.q_prev(count1, silent, cfg)
    idx_change(nil, count1, silent, require("nvim-tools.math").wrapping_sub, cfg.do_zzze)
end

---@param count1 integer Wrapping count next entry to navigate to
---@param silent boolean
---@param cfg qf-herder.nav.Cfg
---@return nil
function M.q_next(count1, silent, cfg)
    idx_change(nil, count1, silent, require("nvim-tools.math").wrapping_add, cfg.do_zzze)
end

---@param src_win integer
---@param count1 integer Wrapping count previous entry to navigate to
---@param silent boolean
---@param cfg qf-herder.nav.Cfg
---@return nil
function M.l_prev(src_win, count1, silent, cfg)
    if _util.ll_ensure_qf_id_or_echo(fn.getloclist(src_win, { id = 0 }).id, silent) then
        idx_change(src_win, count1, silent, require("nvim-tools.math").wrapping_sub, cfg.do_zzze)
    end
end

---@param src_win integer
---@param count1 integer  Wrapping count previous entry to navigate to
---@param silent boolean
---@param cfg qf-herder.nav.Cfg
---@return nil
function M.l_next(src_win, count1, silent, cfg)
    if _util.ll_ensure_qf_id_or_echo(fn.getloclist(src_win, { id = 0 }).id, silent) then
        idx_change(src_win, count1, silent, require("nvim-tools.math").wrapping_add, cfg.do_zzze)
    end
end

-------------------------------------
-- MARK: Absolute Entry Navigation --
-------------------------------------

---Runs in current tabpage context.
---@param count integer
---@param silent boolean
---@param cfg qf-herder.nav.Cfg
function M.q_q(count, silent, cfg)
    local list_info = ntq.get_list(nil, { idx = 0, size = 0 })
    if not ensure_entries_or_echo(list_info.size, silent) then
        return
    end

    -- No clamping count here because `:cc` handles it.
    if count == 0 then
        -- By default, `:cc` without a count goes to the current list entry.
        count = fn.win_gettype() == "quickfix" and api.nvim_win_get_cursor(0)[1] or list_info.idx
    end

    cmd_do(nil, count, "cc", silent, cfg.do_zzze)
end

---Runs in `src_win` context.
---@param src_win integer
---@param count uinteger
---@param silent boolean
---@param cfg qf-herder.nav.Cfg
function M.l_l(src_win, count, silent, cfg)
    local qf_id = fn.getloclist(src_win, { id = 0 }).id
    if not _util.ll_ensure_qf_id_or_echo(qf_id, silent) then
        return
    end

    local list_info = ntq.get_list(src_win, { idx = 0, size = 0 })
    if not ensure_entries_or_echo(list_info.size, silent) then
        return
    end

    local get_count = function()
        if count > 0 then
            return count
        end

        -- By default, `:ll` without a count goes to the current list entry.
        if fn.win_gettype() == "loclist" and fn.getloclist(0, { id = 0 }).id == qf_id then
            return api.nvim_win_get_cursor(0)[1]
        else
            return list_info.idx
        end
    end

    cmd_do(src_win, get_count(), "ll", silent, cfg.do_zzze)
end

---@param count integer
---@param silent boolean
---@param cfg qf-herder.nav.Cfg
---@return nil
function M.q_rewind(count, silent, cfg)
    bookends(nil, silent, count, "crewind", cfg.do_zzze)
end

---@param count integer
---@param silent boolean
---@param cfg qf-herder.nav.Cfg
---@return nil
function M.q_last(count, silent, cfg)
    bookends(nil, silent, count, "clast", cfg.do_zzze)
end

---@param src_win integer
---@param count integer
---@param silent boolean
---@param cfg qf-herder.nav.Cfg
function M.l_rewind(src_win, count, silent, cfg)
    if _util.ll_ensure_qf_id_or_echo(fn.getloclist(src_win, { id = 0 }).id, silent) then
        bookends(src_win, silent, count, "lrewind", cfg.do_zzze)
    end
end

---@param src_win integer
---@param count integer
---@param silent boolean
---@param cfg qf-herder.nav.Cfg
function M.l_last(src_win, count, silent, cfg)
    if _util.ll_ensure_qf_id_or_echo(fn.getloclist(src_win, { id = 0 }).id, silent) then
        bookends(src_win, silent, count, "llast", cfg.do_zzze)
    end
end

------------------------------
-- MARK: Navigation by File --
------------------------------

---@param count1 integer
---@param silent boolean
---@param cfg qf-herder.nav.Cfg
function M.q_pfile(count1, silent, cfg)
    file_nav_wrap(nil, count1, silent, cfg.do_zzze, "cpfile", "clast")
end

---@param count1 integer
---@param silent boolean
---@param cfg qf-herder.nav.Cfg
function M.q_nfile(count1, silent, cfg)
    file_nav_wrap(nil, count1, silent, cfg.do_zzze, "cnfile", "crewind")
end

---@param src_win integer
---@param silent boolean
---@param count1 integer
---@param cfg qf-herder.nav.Cfg
function M.l_pfile(src_win, count1, silent, cfg)
    if _util.ll_ensure_qf_id_or_echo(fn.getloclist(src_win, { id = 0 }).id, silent) then
        file_nav_wrap(src_win, count1, silent, cfg.do_zzze, "lpfile", "llast")
    end
end

---@param src_win integer
---@param silent boolean
---@param count1 integer
---@param cfg qf-herder.nav.Cfg
---@return nil
function M.l_nfile(src_win, count1, silent, cfg)
    if _util.ll_ensure_qf_id_or_echo(fn.getloclist(src_win, { id = 0 }).id, silent) then
        file_nav_wrap(src_win, count1, silent, cfg.do_zzze, "lnfile", "lrewind")
    end
end

----------------
-- MARK: Cmds --
----------------

---@param cargs vim.api.keyset.create_user_command.command_args
function M.q_prev_cmd(cargs)
    local _, _, cfg = require("qf-herder")._config_merged_from_win(0, "nav")
    M.q_prev(math.max(cargs.count, 1), cargs.smods.silent or false, cfg)
end

---@param cargs vim.api.keyset.create_user_command.command_args
function M.q_next_cmd(cargs)
    local _, _, cfg = require("qf-herder")._config_merged_from_win(0, "nav")
    M.q_next(math.max(cargs.count, 1), cargs.smods.silent or false, cfg)
end

---@param cargs vim.api.keyset.create_user_command.command_args
function M.q_q_cmd(cargs)
    local _, _, cfg = require("qf-herder")._config_merged_from_win(0, "nav")
    M.q_q(cargs.count, cargs.smods.silent or false, cfg)
end

---@param cargs vim.api.keyset.create_user_command.command_args
function M.q_rewind_cmd(cargs)
    local _, _, cfg = require("qf-herder")._config_merged_from_win(0, "nav")
    M.q_rewind(cargs.count, cargs.smods.silent or false, cfg)
end

---@param cargs vim.api.keyset.create_user_command.command_args
function M.q_last_cmd(cargs)
    local _, _, cfg = require("qf-herder")._config_merged_from_win(0, "nav")
    M.q_last(cargs.count, cargs.smods.silent or false, cfg)
end

---@param cargs vim.api.keyset.create_user_command.command_args
function M.q_pfile_cmd(cargs)
    local _, _, cfg = require("qf-herder")._config_merged_from_win(0, "nav")
    M.q_pfile(math.max(cargs.count, 1), cargs.smods.silent or false, cfg)
end

---@param cargs vim.api.keyset.create_user_command.command_args
function M.q_nfile_cmd(cargs)
    local _, _, cfg = require("qf-herder")._config_merged_from_win(0, "nav")
    M.q_nfile(math.max(cargs.count, 1), cargs.smods.silent or false, cfg)
end

---@param cargs vim.api.keyset.create_user_command.command_args
function M.l_prev_cmd(cargs)
    local cur_win, _, cfg = require("qf-herder")._config_merged_from_win(0, "nav")
    M.l_prev(cur_win, math.max(cargs.count, 1), cargs.smods.silent or false, cfg)
end

---@param cargs vim.api.keyset.create_user_command.command_args
function M.l_next_cmd(cargs)
    local cur_win, _, cfg = require("qf-herder")._config_merged_from_win(0, "nav")
    M.l_next(cur_win, math.max(cargs.count, 1), cargs.smods.silent or false, cfg)
end

---@param cargs vim.api.keyset.create_user_command.command_args
function M.l_l_cmd(cargs)
    local cur_win, _, cfg = require("qf-herder")._config_merged_from_win(0, "nav")
    M.l_l(cur_win, cargs.count, cargs.smods.silent or false, cfg)
end

---@param cargs vim.api.keyset.create_user_command.command_args
function M.l_rewind_cmd(cargs)
    local cur_win, _, cfg = require("qf-herder")._config_merged_from_win(0, "nav")
    M.l_rewind(cur_win, cargs.count, cargs.smods.silent or false, cfg)
end

---@param cargs vim.api.keyset.create_user_command.command_args
function M.l_last_cmd(cargs)
    local cur_win, _, cfg = require("qf-herder")._config_merged_from_win(0, "nav")
    M.l_last(cur_win, cargs.count, cargs.smods.silent or false, cfg)
end

---@param cargs vim.api.keyset.create_user_command.command_args
function M.l_pfile_cmd(cargs)
    local cur_win, _, cfg = require("qf-herder")._config_merged_from_win(0, "nav")
    M.l_pfile(cur_win, math.max(cargs.count, 1), cargs.smods.silent or false, cfg)
end

---@param cargs vim.api.keyset.create_user_command.command_args
function M.l_nfile_cmd(cargs)
    local cur_win, _, cfg = require("qf-herder")._config_merged_from_win(0, "nav")
    M.l_nfile(cur_win, math.max(cargs.count, 1), cargs.smods.silent or false, cfg)
end

return M
