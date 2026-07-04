local api = vim.api
local fn = vim.fn

local M = {}

---Wrapper for nvim_open_tabpage
---@audited 2026-07-03
---@param buf integer?
---@param enter boolean
---@param after integer
function M.open_new_tab_v12(buf, enter, after)
    buf = buf and buf
        or require("nvim-tools.buf").create_temp_buf("wipe", false, "nofile", "", true)
    after = math.min(after, vim.call("tabpagenr", "$"))
    return api.nvim_open_tabpage(buf, enter, { after = after })
end

---@param after integer
---@return integer?
local function after_to_range(after)
    if after == -1 then
        return nil
    end

    return math.min(after, fn.tabpagenr("$"))
end

---@audited 2026-07-03
---@param buf integer?
---@param enter boolean
---@param after integer
function M.open_new_tab_old(buf, enter, after)
    local range = after_to_range(after)
    local cur_win = api.nvim_get_current_win()
    api.nvim_cmd({ cmd = "tabnew", range = { range } }, {})

    local tabpage_new = api.nvim_get_current_tabpage()
    local win_new = api.nvim_get_current_win()
    local buf_new = api.nvim_win_get_buf(win_new)

    local ntb = require("nvim-tools.buf")
    if ntb.is_empty_noname(buf_new) then
        api.nvim_set_option_value("bh", "wipe", { buf = buf_new })
    end

    if buf then
        api.nvim_set_current_buf(buf)
    end

    if not enter then
        api.nvim_set_current_win(cur_win)
    end

    return tabpage_new
end
-- TODO-DEP: Remove when 0.13 comes out.

---@audited 2026-07-03
---@param buf integer?
---@param enter boolean
---@param after integer
function M.open_new_tab(buf, enter, after)
    if fn.has("nvim-0.12") then
        return M.open_new_tab_v12(buf, enter, after)
    else
        return M.open_new_tab_old(buf, enter, after)
    end
end
-- TODO-DEP: Remove when 0.13 comes out.

return M
