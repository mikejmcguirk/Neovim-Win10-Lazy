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

---@param reuse_title boolean
---@param src_win uinteger?
---@param title string
---@return ("a"|"f"|"r"|"u"|" "), uinteger
function M.set_nr_resolve(reuse_title, src_win, title)
    local ntq = require("nvim-tools.quickfix")
    if reuse_title then
        local set_nr = ntq.find_list_with_title(src_win, title)
        if set_nr then
            return "u", set_nr
        end
    end

    return " ", ntq.get_list(src_win, { nr = "$" }).nr
end

return M
