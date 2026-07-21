local api = vim.api

local ntq = require("nvim-tools.quickfix")

local M = {}

---@param tabpage uinteger
---@param cfg qf-herder.stack.Cfg
local function wrapup_qf(tabpage, cfg)
    if not cfg.autosize_changes then
        return
    end

    require("qf-herder._window").qf_resize(tabpage, 0, { spk = cfg.spk })
end

---@param src_win uinteger
---@param silent boolean
---@param cfg qf-herder.stack.Cfg
local function wrapup_ll(src_win, silent, cfg)
    if not cfg.autosize_changes then
        return
    end

    require("qf-herder._window").ll_resize(src_win, 0, { silent = silent, spk = cfg.spk })
end

---@param src_win uinteger|nil
---@param silent boolean
---@param count uinteger
---@param cfg qf-herder.stack.Cfg
local function history_goto(src_win, silent, count, cfg)
    -- TODO-DEP: At Nvim 0.14, remove optional opts
    if src_win ~= nil then
        api.nvim_win_call(src_win, function()
            api.nvim_cmd({ cmd = "lhi", count = count, mods = { silent = silent } }, {})
        end)
    else
        api.nvim_cmd({ cmd = "chi", count = count, mods = { silent = silent } }, {})
    end

    if not cfg.autosize_changes then
        return
    end
end

---@param silent boolean
---@param count1 uinteger
---@param cfg qf-herder.stack.Cfg
function M.q_newer(tabpage, silent, count1, cfg)
    local cur_nr = ntq.get_list(nil, { nr = 0 }).nr ---@type uinteger
    if cur_nr == 0 then
        api.nvim_echo({ { "No entries", "" } }, false, {})
        return
    end

    local max_nr = ntq.get_list(nil, { nr = "$" }).nr ---@type uinteger
    local new_nr = require("nvim-tools.math").wrapping_add(cur_nr, count1, 1, max_nr)
    history_goto(nil, silent, new_nr, cfg)
    wrapup_qf(tabpage, cfg)
end

---@param silent boolean
---@param count1 uinteger
---@param cfg qf-herder.stack.Cfg
function M.q_older(tabpage, silent, count1, cfg)
    local cur_nr = ntq.get_list(nil, { nr = 0 }).nr ---@type uinteger
    if cur_nr == 0 then
        api.nvim_echo({ { "No entries", "" } }, false, {})
        return
    end

    local max_nr = ntq.get_list(nil, { nr = "$" }).nr ---@type uinteger
    local new_nr = require("nvim-tools.math").wrapping_sub(cur_nr, count1, 1, max_nr)
    history_goto(nil, silent, new_nr, cfg)
    wrapup_qf(tabpage, cfg)
end

---@param src_win uinteger|nil
---@param silent boolean
---@param count uinteger|nil
---@param cfg qf-herder.stack.Cfg
local function history_goto_abs(src_win, silent, count, cfg)
    local cmd = src_win ~= nil and "lhi" or "chi"
    if count == nil then
        -- TODO-DEP: At Nvim 0.14, remove optional opts
        api.nvim_cmd({ cmd = cmd, mods = { silent = silent } }, {})
        return
    end

    local cur_nr = ntq.get_list(src_win, { nr = 0 }).nr ---@type uinteger
    if cur_nr == 0 then
        api.nvim_echo({ { "No entries", "" } }, false, {})
        return
    end

    -- By default, |:chi| and |:lhi| treat 0 as 1.
    count = count == 0 and cur_nr or math.min(count, ntq.get_list(src_win, { nr = "$" }).nr)
    history_goto(src_win, silent, count, cfg)
end

---@param silent boolean
---@param count uinteger|nil
---@param cfg qf-herder.stack.Cfg
function M.q_history(tabpage, silent, count, cfg)
    history_goto_abs(nil, silent, count, cfg)
    wrapup_qf(tabpage, cfg)
end

---@param src_win uinteger
---@param silent boolean
---@param count1 uinteger
---@param cfg qf-herder.stack.Cfg
function M.l_newer(src_win, silent, count1, cfg)
    local cur_nr = ntq.get_list(src_win, { nr = 0 }).nr ---@type uinteger
    if cur_nr == 0 then
        api.nvim_echo({ { "No entries", "" } }, false, {})
        return
    end

    local max_nr = ntq.get_list(nil, { nr = "$" }).nr ---@type uinteger
    local new_nr = require("nvim-tools.math").wrapping_add(cur_nr, count1, 1, max_nr)
    history_goto(src_win, silent, new_nr, cfg)
    wrapup_ll(src_win, silent, cfg)
end

---@param src_win uinteger
---@param silent boolean
---@param count1 uinteger
---@param cfg qf-herder.stack.Cfg
function M.l_older(src_win, silent, count1, cfg)
    local cur_nr = ntq.get_list(src_win, { nr = 0 }).nr ---@type uinteger
    if cur_nr == 0 then
        api.nvim_echo({ { "No entries", "" } }, false, {})
        return
    end

    local max_nr = ntq.get_list(nil, { nr = "$" }).nr ---@type uinteger
    local new_nr = require("nvim-tools.math").wrapping_sub(cur_nr, count1, 1, max_nr)
    history_goto(src_win, silent, new_nr, cfg)
    wrapup_ll(src_win, silent, cfg)
end

---@param src_win uinteger
---@param silent boolean
---@param count uinteger|nil
---@param cfg qf-herder.stack.Cfg
function M.l_history(src_win, silent, count, cfg)
    history_goto_abs(src_win, silent, count, cfg)
    wrapup_ll(src_win, silent, cfg)
end

return M
