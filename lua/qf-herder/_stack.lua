local api = vim.api
local fn = vim.fn

local ntq = require("nvim-tools.quickfix")
local _util = require("qf-herder._util")

local M = {}

----------------
-- MARK: Util --
----------------

---@param src_win uinteger|nil
---@param silent boolean
---@param cfg qf-herder.stack.Cfg
local function autosize_do(src_win, silent, cfg)
    if not cfg.update_list_wins then
        return
    end

    if src_win ~= nil then
        require("qf-herder._window").ll_resize(src_win, 0, { silent = silent, spk = cfg.spk })
    else
        require("qf-herder._window").qf_resize(0, 0, { spk = cfg.spk })
    end
end

---@param src_win integer|nil
---@param list_nr integer|"$"
---@return integer
local function clear_list(src_win, list_nr)
    local nr = ntq.resolve_list_nr(src_win, list_nr)
    local what = { nr = nr, context = {}, items = {}, quickfixtextfunc = "", title = "" }
    local action = "r"
    return ntq.set_result_resolve(ntq.set_list(src_win, action, what), src_win, nr, action)
end

---@param cur_nr uinteger
---@param silent boolean
---@return boolean
local function has_stack_or_echo(cur_nr, silent)
    if cur_nr > 0 then
        return true
    end

    if not silent then
        api.nvim_echo({ { "No entries", "" } }, false, {})
    end

    return false
end

---@param src_win uinteger|nil
---@param silent boolean
---@param nr uinteger
local function history_goto(src_win, silent, nr)
    -- TODO-DEP: At Nvim 0.14, remove optional opts
    if src_win ~= nil then
        api.nvim_win_call(src_win, function()
            api.nvim_cmd({ cmd = "lhi", count = nr, mods = { silent = silent } }, {})
        end)
    else
        api.nvim_cmd({ cmd = "chi", count = nr, mods = { silent = silent } }, {})
    end
end

---@param src_win uinteger|nil
---@param silent boolean
---@param count uinteger|nil
---@return uinteger, uinteger
local function history_goto_abs(src_win, silent, count)
    if count == nil then
        local cmd = src_win ~= nil and "lhi" or "chi"
        -- TODO-DEP: At Nvim 0.14, remove optional opts
        api.nvim_cmd({ cmd = cmd, mods = { silent = silent } }, {})
        return 0, 0
    end

    local cur_nr = ntq.get_list(src_win, { nr = 0 }).nr ---@type uinteger
    if not has_stack_or_echo(cur_nr, silent) then
        return 0, 0
    end

    -- By default, |:chi| and |:lhi| treat 0 as 1.
    count = count == 0 and cur_nr or math.min(count, ntq.get_list(src_win, { nr = "$" }).nr)
    history_goto(src_win, silent, count)
    return cur_nr, count
end

---@param math fun(x:uinteger, y:uinteger, min:uinteger, max:uinteger): uinteger
---@param src_win uinteger|nil
---@param silent boolean
---@param count1 uinteger
---@param cfg qf-herder.stack.Cfg
local function nr_change(math, src_win, silent, count1, cfg)
    local cur_nr = ntq.get_list(src_win, { nr = 0 }).nr ---@type uinteger
    if not has_stack_or_echo(cur_nr, silent) then
        return
    end

    local max_nr = ntq.get_list(src_win, { nr = "$" }).nr ---@type uinteger
    local new_nr = math(cur_nr, count1, 1, max_nr)
    history_goto(src_win, silent, new_nr)
    if new_nr ~= cur_nr then
        autosize_do(src_win, silent, cfg)
    end
end

--------------------
-- MARK: Quickfix --
--------------------

---@param silent boolean
---@param count1 uinteger
---@param cfg qf-herder.stack.Cfg
function M.q_older(silent, count1, cfg)
    print("in stack older")
    nr_change(require("nvim-tools.math").wrapping_sub, nil, silent, count1, cfg)
end

---@param silent boolean
---@param count1 uinteger
---@param cfg qf-herder.stack.Cfg
function M.q_newer(silent, count1, cfg)
    nr_change(require("nvim-tools.math").wrapping_add, nil, silent, count1, cfg)
end

---@param silent boolean
---@param count uinteger|nil
---@param cfg qf-herder.stack.Cfg
function M.q_history(silent, count, cfg)
    local cur_nr, new_nr = history_goto_abs(nil, silent, count)
    if cur_nr > 0 and new_nr > 0 and cur_nr ~= new_nr then
        autosize_do(nil, silent, cfg)
    end
end

---@param cfg qf-herder.stack.Cfg
function M.q_clear(count, cfg)
    if clear_list(nil, count) == 0 then
        autosize_do(nil, false, cfg)
    end
end
-- LOW: You could get the old and new size of the list to see if a resize is necessary. But I
-- think getting the information for the guard is more expensive than always autosizing, given
-- that clearing an empty list should be an atypical action.

---@param cfg qf-herder.stack.Cfg
function M.q_free(cfg)
    local result = vim.call("setqflist", {}, "f") ---@type -1|0
    if result == 0 and cfg.update_list_wins then
        require("qf-herder._window").qf_wins_close_with_spk(api.nvim_list_tabpages(), cfg.spk)
    end
end

-------------------
-- MARK: Loclist --
-------------------

---@param src_win uinteger
---@param silent boolean
---@param count1 uinteger
---@param cfg qf-herder.stack.Cfg
function M.l_older(src_win, silent, count1, cfg)
    nr_change(require("nvim-tools.math").wrapping_sub, src_win, silent, count1, cfg)
end

---@param src_win uinteger
---@param silent boolean
---@param count1 uinteger
---@param cfg qf-herder.stack.Cfg
function M.l_newer(src_win, silent, count1, cfg)
    nr_change(require("nvim-tools.math").wrapping_add, src_win, silent, count1, cfg)
end

---@param src_win uinteger
---@param silent boolean
---@param count uinteger|nil
---@param cfg qf-herder.stack.Cfg
function M.l_history(src_win, silent, count, cfg)
    local cur_nr, new_nr = history_goto_abs(src_win, silent, count)
    if cur_nr > 0 and new_nr > 0 and cur_nr ~= new_nr then
        autosize_do(src_win, silent, cfg)
    end
end

---@param src_win uinteger?
---@param silent boolean
---@param count uinteger|nil
---@param cfg qf-herder.stack.Cfg
function M._history(src_win, silent, count, cfg)
    if src_win ~= nil then
        M.l_history(src_win, silent, count, cfg)
    else
        M.q_history(silent, count, cfg)
    end
end

---@param src_win uinteger
---@param count uinteger
---@param silent boolean
---@param cfg qf-herder.stack.Cfg
function M.l_clear(src_win, count, silent, cfg)
    local qf_id = fn.getloclist(src_win, { id = 0 }).id ---@type uinteger
    if not _util.qf_id_valid_or_echo_no_ll(qf_id, silent) then
        return
    end

    if clear_list(src_win, count) == 0 then
        autosize_do(src_win, silent, cfg)
    end
end

---@param src_win uinteger
---@param silent boolean
---@param cfg qf-herder.stack.Cfg
function M.l_free(src_win, silent, cfg)
    local qf_id = fn.getloclist(src_win, { id = 0 }).id ---@type uinteger
    if not _util.qf_id_valid_or_echo_no_ll(qf_id, silent) then
        return
    end

    if fn.setloclist(src_win, {}, "f") == 0 and cfg.update_list_wins then
        -- Pass qf_id 0 since setlist "f" invalidates the old one.
        require("qf-herder._window").ll_wins_close_with_spk_and_qf_id({ 0 }, cfg.spk, 0)
    end
end

----------------
-- MARK: Cmds --
----------------

---@param cargs vim.api.keyset.create_user_command.command_args
function M.q_older_cmd(cargs)
    local _, _, cfg = require("qf-herder")._config_merged_from_win(0, "stack")
    M.q_older(false, math.min(cargs.count, 1), cfg)
end

---@param cargs vim.api.keyset.create_user_command.command_args
function M.q_newer_cmd(cargs)
    local _, _, cfg = require("qf-herder")._config_merged_from_win(0, "stack")
    M.q_newer(false, math.min(cargs.count, 1), cfg)
end

-- cargs.count shows zero if the user entered a count of 0 or if the user did not enter a
-- count. Use range to check if the user actually entered a count

---@param cargs vim.api.keyset.create_user_command.command_args
function M.q_history_cmd(cargs)
    local _, _, cfg = require("qf-herder")._config_merged_from_win(0, "stack")
    M.q_history(false, (cargs.range > 0 and cargs.count or nil), cfg)
end

---@param cargs vim.api.keyset.create_user_command.command_args
function M.q_clear_cmd(cargs)
    local _, _, cfg = require("qf-herder")._config_merged_from_win(0, "stack")
    M.q_clear(cargs.count, cfg)
end

function M.q_free_cmd()
    local _, _, cfg = require("qf-herder")._config_merged_from_win(0, "stack")
    M.q_free(cfg)
end

---@param cargs vim.api.keyset.create_user_command.command_args
function M.l_older_cmd(cargs)
    local win, _, cfg = require("qf-herder")._config_merged_from_win(0, "stack")
    M.l_older(win, false, math.min(cargs.count, 1), cfg)
end

---@param cargs vim.api.keyset.create_user_command.command_args
function M.l_newer_cmd(cargs)
    local win, _, cfg = require("qf-herder")._config_merged_from_win(0, "stack")
    M.l_newer(win, false, math.min(cargs.count, 1), cfg)
end

---@param cargs vim.api.keyset.create_user_command.command_args
function M.l_history_cmd(cargs)
    local win, _, cfg = require("qf-herder")._config_merged_from_win(0, "stack")
    M.l_history(win, false, (cargs.range > 0 and cargs.count or nil), cfg)
end

---@param cargs vim.api.keyset.create_user_command.command_args
function M.l_clear_cmd(cargs)
    local win, _, cfg = require("qf-herder")._config_merged_from_win(0, "stack")
    M.l_clear(win, cargs.count, false, cfg)
end

function M.l_free_cmd()
    local win, _, cfg = require("qf-herder")._config_merged_from_win(0, "stack")
    M.l_free(win, false, cfg)
end

return M
