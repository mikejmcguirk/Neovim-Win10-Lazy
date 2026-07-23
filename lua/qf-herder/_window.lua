local api = vim.api
local fn = vim.fn

local _util = require("qf-herder._util")

local LIST_MAX_HEIGHT = 10

-----------------
-- MARK: Utils --
-----------------

---@param src_win uinteger|nil
---@param count uinteger
---@param auto_height boolean
---@return uinteger
local function height_resolve(src_win, count, auto_height)
    if count > 0 then
        return count
    elseif auto_height == false then
        return LIST_MAX_HEIGHT
    end

    local ntq = require("nvim-tools.quickfix")
    local size = ntq.get_list(src_win, { nr = 0, size = 0 }).size ---@type uinteger
    return size == 0 and 1 or math.min(size, LIST_MAX_HEIGHT)
end

---@param spk ""|"cursor"|"screen"|"topline"
---@param tabpage uinteger
---@param win uinteger
---@param height uinteger
local function win_resize_with_spk(spk, tabpage, win, height)
    local old_spk = #spk > 0 and _util.ensure_spk(nil, tabpage, spk) or nil
    pcall(require("nvim-tools.win").resize, win, -1, height, { anchor = "bottom" })
    if old_spk ~= nil then
        api.nvim_set_option_value("spk", old_spk, { scope = "global" })
    end
end

local M = {}

---@param src_win uinteger|nil
---@param count uinteger
---@param cfg qf-herder.window.Cfg
function M.list_open(src_win, count, cfg)
    if src_win == nil then
        M.qf_open(count, cfg)
    else
        M.ll_open(count, cfg)
    end
end

---@param tabpages uinteger[]
---@param qf_id uinteger
---@return uinteger|nil
function M.ll_win_find_one_by_qf_id(tabpages, qf_id)
    local what = { id = 0 }
    return M.win_find_one(tabpages, function(win)
        local w_qf_id = vim.call("getloclist", win, what).id ---@type uinteger
        return w_qf_id == qf_id and vim.call("win_gettype", win) == "loclist"
    end)
end

---@param tabpages uinteger[]
---@param spk ""|"cursor"|"screen"|"topline"
function M.ll_wins_close_with_spk(tabpages, spk)
    M.wins_close_with_spk(tabpages, spk, function(win)
        return vim.call("win_gettype", win) == "loclist"
    end)
end

---@param tabpages uinteger[]
---@param spk ""|"cursor"|"screen"|"topline"
---@param qf_id uinteger
function M.ll_wins_close_with_spk_and_qf_id(tabpages, spk, qf_id)
    local what = { id = 0 }
    M.wins_close_with_spk(tabpages, spk, function(win)
        local w_qf_id = vim.call("getloclist", win, what).id
        return w_qf_id == qf_id and vim.call("win_gettype", win) == "loclist"
    end)
end

---@param tabpages uinteger[]
---@return uinteger|nil
function M.qf_win_find_one(tabpages)
    return M.win_find_one(tabpages, function(win)
        return vim.call("win_gettype", win) == "quickfix"
    end)
end

---@param tabpages uinteger[]
---@param spk ""|"cursor"|"screen"|"topline"
function M.qf_wins_close_with_spk(tabpages, spk)
    M.wins_close_with_spk(tabpages, spk, function(win)
        return vim.call("win_gettype", win) == "quickfix"
    end)
end

---@param win uinteger
---@param tabpage uinteger
---@param spk ""|"cursor"|"screen"|"topline"
---@return boolean
function M.win_close_one_with_spk(win, tabpage, spk)
    local old_spk = #spk > 0 and _util.ensure_spk(nil, tabpage, spk) or nil
    local _win = require("nvim-tools.win")
    local ok, _, _, _ = _win.protected_close(win, true)
    if old_spk ~= nil then
        api.nvim_set_option_value("spk", old_spk, { scope = "global" })
    end

    return ok
end

---@param wins uinteger[]
---@param tabpage uinteger
---@param spk ""|"cursor"|"screen"|"topline"
---@return boolean
function M.win_close_multiple_with_spk(wins, tabpage, spk)
    if #wins == 0 then
        return true
    end

    local old_spk = spk ~= nil and _util.ensure_spk(nil, tabpage, spk) or nil
    local _win = require("nvim-tools.win")
    local ok = _win.protected_close_multiple(wins, true)
    if old_spk ~= nil then
        api.nvim_set_option_value("spk", old_spk, { scope = "global" })
    end

    return ok
end

---@param tabpages uinteger[]
---@param spk ""|"cursor"|"screen"|"topline"
---@param f fun(win:uinteger): boolean
function M.wins_close_with_spk(tabpages, spk, f)
    local cur_tabpage = api.nvim_get_current_tabpage()
    local cur_idx = 0
    for i, tabpage in ipairs(tabpages) do
        if tabpage == 0 or tabpage == cur_tabpage then
            cur_idx = i
            break
        end
    end

    local ntt = require("nvim-tools.table")
    local tabpages_len = #tabpages
    if cur_idx > 0 then
        local cur_tabpage_wins = api.nvim_tabpage_list_wins(cur_tabpage)
        ntt.i_keep(cur_tabpage_wins, f)
        if #cur_tabpage_wins > 0 then
            M.win_close_multiple_with_spk(cur_tabpage_wins, cur_tabpage, spk)
        end

        if tabpages_len == 1 then
            return
        end
    end

    local ntw = require("nvim-tools.win")
    for i = 1, cur_idx - 1 do
        local wins = api.nvim_tabpage_list_wins(tabpages[i])
        ntt.i_keep(wins, f)
        ntw.protected_close_multiple(wins, true)
    end

    for i = cur_idx + 1, tabpages_len do
        local wins = api.nvim_tabpage_list_wins(tabpages[i])
        ntt.i_keep(wins, f)
        ntw.protected_close_multiple(wins, true)
    end
end

---@param tabpages uinteger[]
---@return uinteger|nil
function M.win_find_one(tabpages, f)
    local ntt = require("nvim-tools.table")
    for _, tabpage in ipairs(tabpages) do
        local win, _ = ntt.i_find(api.nvim_tabpage_list_wins(tabpage), f)
        if win ~= nil then
            return win
        end
    end
end

--------------------
-- MARK: Quickfix --
--------------------

---@param spk "cursor"|"screen"|"topline"|""
---@param count uinteger
---@param split qf-herder.window.qfSplit
---@return boolean, string
local function copen_with_spk(spk, count, split)
    local old_spk = #spk > 0 and _util.ensure_spk(nil, 0, spk) or nil
    local ok, err = pcall(function()
        ---@diagnostic disable-next-line: assign-type-mismatch
        api.nvim_cmd({ cmd = "copen", count = count, mods = { split = split } }, {})
    end)

    if old_spk ~= nil then
        api.nvim_set_option_value("spk", old_spk, { scope = "global" })
    end

    ---@diagnostic disable-next-line: return-type-mismatch
    return ok, err
end
-- MID: Can be combined with lopen_with_spk by taking cmd as a param and making split inclusive
-- of all options. Wait because this would be a pain to unwind if it were premature.

---Wrapper for `copen` in the current tabpage.
---@param count uinteger
---@param cfg qf-herder.window.Cfg
---@return boolean, string
function M.qf_open(count, cfg)
    local qf_win = M.qf_win_find_one({ 0 })
    if qf_win ~= nil then
        return false, "Quickfix window already open"
    end

    local cfg_spk = cfg.spk
    M.ll_wins_close_with_spk({ 0 }, cfg_spk)
    return copen_with_spk(cfg_spk, height_resolve(nil, count, cfg.auto_height), cfg.split_qf)
end

---@class qf-herder.window.quickfixClose.Cfg
---@field spk "cursor"|"screen"|"topline"|""

---@param tabpages uinteger[]
---@param cfg qf-herder.window.Cfg
function M.qf_close(tabpages, cfg)
    M.qf_wins_close_with_spk(tabpages, cfg.spk)
end

---@param count uinteger
---@param cfg qf-herder.window.Cfg
function M.qf_toggle(count, cfg)
    local qf_win = M.qf_win_find_one({ 0 })
    local cfg_spk = cfg.spk
    if qf_win == nil then
        M.ll_wins_close_with_spk({ 0 }, cfg_spk)
        copen_with_spk(cfg_spk, height_resolve(nil, count, cfg.auto_height), cfg.split_qf)
    else
        M.win_close_one_with_spk(qf_win, 0, cfg_spk)
    end
end

---@class qf-herder.window.qf_resize.Cfg
---@field spk "cursor"|"screen"|"topline"|""

---@param tabpage uinteger
---@param count uinteger
---@param cfg qf-herder.window.qf_resize.Cfg
function M.qf_resize(tabpage, count, cfg)
    local qf_win = M.qf_win_find_one({ tabpage })
    if qf_win ~= nil then
        win_resize_with_spk(cfg.spk, tabpage, qf_win, height_resolve(nil, count, true))
    end
end

-------------------------
-- MARK: Location List --
-------------------------

---@param spk "cursor"|"screen"|"topline"|""
---@param count uinteger
---@param split qf-herder.window.llSplit
---@return boolean
local function lopen_with_spk(spk, count, split)
    local old_spk = #spk > 0 and _util.ensure_spk(nil, 0, spk) or nil
    local ok, _ = pcall(function()
        ---@diagnostic disable-next-line: assign-type-mismatch
        api.nvim_cmd({ cmd = "lopen", count = count, mods = { split = split } }, {})
    end)

    if old_spk ~= nil then
        api.nvim_set_option_value("spk", old_spk, { scope = "global" })
    end

    ---@diagnostic disable-next-line: return-type-mismatch
    return ok
end

---@param count uinteger
---@param cfg qf-herder.window.Cfg
function M.ll_open(count, cfg)
    local src_win = api.nvim_get_current_win()
    local qf_id = fn.getloclist(src_win, { id = 0 }).id
    if not _util.ll_ensure_qf_id_or_echo(qf_id, cfg.silent) then
        return
    end

    if M.ll_win_find_one_by_qf_id({ 0 }, qf_id) ~= nil then
        local cfg_spk = cfg.spk
        M.qf_wins_close_with_spk({ 0 }, cfg_spk)
        lopen_with_spk(cfg_spk, height_resolve(src_win, count, cfg.auto_height), cfg.split_ll)
    end
end

---@class qf-herder.window.locationListClose.Cfg : qf-herder.window.quickfixClose.Cfg
---@field silent boolean

---@param src_win uinteger
---@param cfg qf-herder.window.Cfg
function M.ll_close(src_win, cfg)
    local qf_id = fn.getloclist(src_win, { id = 0 }).id
    if not _util.ll_ensure_qf_id_or_echo(qf_id, cfg.silent) then
        return
    end

    local tabpage = api.nvim_win_get_tabpage(src_win)
    local ll_win = M.ll_win_find_one_by_qf_id({ tabpage }, qf_id)
    if ll_win ~= nil then
        M.win_close_one_with_spk(ll_win, tabpage, cfg.spk)
    end
end

---@param count uinteger
---@param cfg qf-herder.window.Cfg
function M.ll_toggle(count, cfg)
    local src_win = api.nvim_get_current_win()
    local qf_id = fn.getloclist(src_win, { id = 0 }).id ---@type uinteger
    if not _util.ll_ensure_qf_id_or_echo(qf_id, cfg.silent) then
        return
    end

    local cfg_spk = cfg.spk
    local ll_win = M.ll_win_find_one_by_qf_id({ 0 }, qf_id)
    if ll_win == nil then
        M.qf_wins_close_with_spk({ 0 }, cfg_spk)
        local height = height_resolve(src_win, count, cfg.auto_height)
        return lopen_with_spk(cfg_spk, height, cfg.split_ll)
    else
        return M.win_close_one_with_spk(ll_win, 0, cfg_spk)
    end
end

---@class qf-herder.window.ll_resize.Cfg
---@field silent boolean
---@field spk "cursor"|"screen"|"topline"|""

---@param src_win uinteger
---@param count uinteger
---@param cfg qf-herder.window.ll_resize.Cfg
function M.ll_resize(src_win, count, cfg)
    local qf_id = fn.getloclist(src_win, { id = 0 }).id ---@type uinteger
    if not _util.ll_ensure_qf_id_or_echo(qf_id, cfg.silent) then
        return
    end

    local tabpage = api.nvim_win_get_tabpage(src_win)
    local ll_win = M.ll_win_find_one_by_qf_id({ tabpage }, qf_id)
    if ll_win ~= nil then
        win_resize_with_spk(cfg.spk, tabpage, ll_win, height_resolve(src_win, count, true))
    end
end

----------------
-- MARK: Cmds --
----------------

---@param cargs vim.api.keyset.create_user_command.command_args
function M.q_open_cmd(cargs)
    local _, _, cfg = require("qf-herder")._config_merged_from_win(0, "window")
    M.qf_open(cargs.count, cfg)
end

function M.q_close_cmd()
    local _, _, cfg = require("qf-herder")._config_merged_from_win(0, "window")
    M.qf_close({ 0 }, cfg)
end

---@param cargs vim.api.keyset.create_user_command.command_args
function M.q_toggle_cmd(cargs)
    local _, _, cfg = require("qf-herder")._config_merged_from_win(0, "window")
    M.qf_toggle(cargs.count, cfg)
end

---@param cargs vim.api.keyset.create_user_command.command_args
function M.q_resize_cmd(cargs)
    local _, _, cfg = require("qf-herder")._config_merged_from_win(0, "window")
    M.qf_resize(0, cargs.count, cfg)
end

---@param cargs vim.api.keyset.create_user_command.command_args
function M.l_open_cmd(cargs)
    local _, _, cfg = require("qf-herder")._config_merged_from_win(0, "window")
    M.ll_open(cargs.count, cfg)
end

function M.l_close_cmd()
    local src_win, _, cfg = require("qf-herder")._config_merged_from_win(0, "window")
    M.ll_close(src_win, cfg)
end

---@param cargs vim.api.keyset.create_user_command.command_args
function M.l_toggle_cmd(cargs)
    local _, _, cfg = require("qf-herder")._config_merged_from_win(0, "window")
    M.ll_toggle(cargs.count, cfg)
end

---@param cargs vim.api.keyset.create_user_command.command_args
function M.l_resize_cmd(cargs)
    local src_win, _, cfg = require("qf-herder")._config_merged_from_win(0, "window")
    M.ll_resize(src_win, cargs.count, cfg)
end

return M
