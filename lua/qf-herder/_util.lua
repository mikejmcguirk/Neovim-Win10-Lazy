local api = vim.api
-- local fn = vim.fn

local M = {}

---@param win uinteger?
---@param tabpage uinteger?
---@param spk ""|"cursor"|"screen"|"topline"
---@return (""|"cursor"|"screen"|"topline")?
function M.ensure_spk(win, tabpage, spk)
    if #spk == 0 then
        return
    end

    local cur_tabpage = api.nvim_get_current_tabpage()
    tabpage = tabpage == 0 and cur_tabpage or tabpage
    if win ~= nil and api.nvim_win_get_tabpage(win) ~= cur_tabpage then
        return
    elseif tabpage ~= nil and tabpage ~= cur_tabpage then
        return
    end

    local scope_global = { scope = "global" }
    ---@type ""|"cursor"|"screen"|"topline"
    local old_spk = api.nvim_get_option_value("spk", scope_global)
    api.nvim_set_option_value("spk", spk, scope_global)
    return old_spk
end

---@param qf_id uinteger
---@return boolean
function M.ll_ensure_qf_id_or_echo(qf_id, silent)
    if qf_id > 0 then
        return true
    end

    if not silent then
        api.nvim_echo({ { QFR_NO_LL, "" } }, false, {})
    end

    return false
end

return M
