local api = vim.api
-- local fn = vim.fn

local M = {}

---@param tabpage uinteger
---@param spk string
function M.ll_wins_close_all_in_tabpage_with_spk(tabpage, spk)
    local ll_wins = M.ll_wins_find_all_in_tabpage(tabpage)
    M.win_close_multiple_with_spk(ll_wins, tabpage, spk)
end

---@param tabpage uinteger
---@return uinteger[]
function M.ll_wins_find_all_in_tabpage(tabpage)
    local tabpage_wins = api.nvim_tabpage_list_wins(tabpage)
    return require("nvim-tools.table").i_keep(tabpage_wins, function(win)
        return vim.call("win_gettype", win) == "loclist"
    end)
end

---@param tabpage uinteger
---@param qf_id uinteger
---@return uinteger|nil
function M.ll_win_find_one_by_qf_id(tabpage, qf_id)
    local tabpage_wins = api.nvim_tabpage_list_wins(tabpage)
    local what = { id = 0 }
    local win, _ = require("nvim-tools.table").i_find(tabpage_wins, function(t_win)
        local w_qf_id = vim.call("getloclist", t_win, what).id ---@type uinteger
        return w_qf_id == qf_id and vim.call("win_gettype", t_win) == "loclist"
    end)

    return win
end

---@param operation_tabpage uinteger Which tabpage is the operation affecting? If this is not
---zero and different from the current tabpage, changing spk will be skipped.
---@param spk string
---@return string? Old spk.
function M.ensure_spk(operation_tabpage, spk)
    if operation_tabpage ~= 0 then
        local cur_tabpage = api.nvim_get_current_tabpage()
        if operation_tabpage ~= cur_tabpage then
            return nil
        end
    end

    local scope_global = { scope = "global" }
    local old_spk = api.nvim_get_option_value("spk", scope_global)
    api.nvim_set_option_value("spk", spk, scope_global)
    return old_spk
end

---@param tabpage integer
---@return integer|nil
function M.find_qf_win(tabpage)
    local ntt = require("nvim-tools.table")
    local win, _ = ntt.i_find(api.nvim_tabpage_list_wins(tabpage), function(t_win)
        return vim.call("win_gettype", t_win) == "quickfix"
    end)

    return win
end

---@param tabpages uinteger[]
---@return boolean
function M.list_win_has(tabpages)
    local ntt = require("nvim-tools.table")
    return ntt.i_any(tabpages, function(tabpage)
        return ntt.i_any(api.nvim_tabpage_list_wins(tabpage), function(win)
            local wintype = vim.call("win_gettype", win)
            return wintype == "quickfix" or wintype == "loclist"
        end)
    end)
end

---@param win uinteger
---@param tabpage uinteger
---@param spk string
---@return boolean, string
function M.win_close_with_spk(win, tabpage, spk)
    local old_spk = #spk > 0 and M.ensure_spk(tabpage, spk) or nil
    local _win = require("nvim-tools.win")
    local ok, _, err, _ = _win.protected_close(win, true)
    if old_spk ~= nil then
        api.nvim_set_option_value("spk", old_spk, { scope = "global" })
    end

    return ok, err
end

---@param wins uinteger[]
---@param tabpage uinteger
---@param spk string
---@return boolean, string
function M.win_close_multiple_with_spk(wins, tabpage, spk)
    local wins_len = #wins
    if wins_len == 0 then
        return true, ""
    end

    local old_spk = spk ~= nil and M.ensure_spk(tabpage, spk) or nil
    local _win = require("nvim-tools.win")
    local ok = true
    local err = ""
    for i = 1, wins_len do
        local ok_w, _, err_w, _ = _win.protected_close(wins[i], true)
        if ok_w == false then
            ok = false
            err = err_w
            break
        end
    end

    if old_spk ~= nil then
        api.nvim_set_option_value("spk", old_spk, { scope = "global" })
    end

    return ok, err
end

return M
