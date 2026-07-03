local api = vim.api
-- local fn = vim.fn

local M = {}

---@param tabpage uinteger
---@param spk string?
function M.ll_wins_close_all_in_tabpage_with_spk(tabpage, spk)
    local ll_wins = M.ll_wins_find_all_in_tabpage(tabpage)
    M.win_close_multiple_with_spk(ll_wins, tabpage, spk)
end

---@param tabpage uinteger
---@return uinteger[]
function M.ll_wins_find_all_in_tabpage(tabpage)
    local tabpage_wins = api.nvim_tabpage_list_wins(tabpage)
    return require("nvim-tools.table").keep(tabpage_wins, function(win)
        return vim.call("win_gettype", win) == "loclist"
    end)
end

---@param tabpage uinteger
---@param spk string
---@return string? Old spk.
function M.ensure_spk(tabpage, spk)
    if tabpage ~= 0 then
        local cur_tabpage = api.nvim_get_current_tabpage()
        if tabpage ~= cur_tabpage then
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
    local wins = api.nvim_tabpage_list_wins(tabpage)
    local wins_len = #wins
    for i = 1, wins_len do
        local win = wins[i]
        if vim.call("win_gettype", win) == "quickfix" then
            return win
        end
    end
end

---@param win uinteger
---@param tabpage uinteger
---@param spk string?
---@return boolean
function M.win_close_with_spk(win, tabpage, spk)
    local old_spk = spk ~= nil and M.ensure_spk(tabpage, spk) or nil
    local _win = require("nvim-tools.win")
    local ok, _, _, _ = _win.protected_close(win, true)
    if old_spk ~= nil then
        api.nvim_set_option_value("spk", old_spk, { scope = "global" })
    end

    return ok
end

---@param wins uinteger[]
---@param tabpage uinteger
---@param spk string?
---@return boolean
function M.win_close_multiple_with_spk(wins, tabpage, spk)
    local wins_len = #wins
    -- Fine to be defensive here if it avoids setting a temp option.
    if wins_len == 0 then
        return true
    end

    local old_spk = spk ~= nil and M.ensure_spk(tabpage, spk) or nil
    local _win = require("nvim-tools.win")
    local ok = true
    for i = 1, wins_len do
        local ok_w, _, _, _ = _win.protected_close(wins[i], true)
        if ok_w == false then
            ok = false
        end
    end

    if old_spk ~= nil then
        api.nvim_set_option_value("spk", old_spk, { scope = "global" })
    end

    return ok
end

return M
