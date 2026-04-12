local api = vim.api
local fn = vim.fn

local M = {}

---Wrapper for nvim_open_tabpage
---@param buf integer?
---@param enter boolean
---@param after integer
function M.open_new_tab_v12(buf, enter, after)
    local ntt = require("nvim-tools.types")
    vim.validate("buf", buf, ntt.is_uint, true)
    vim.validate("enter", enter, "boolean")
    -- is_int because -1 is for current tabpage
    vim.validate("after", after, ntt.is_int)

    buf = buf and buf
        or require("nvim-tools.buf").create_temp_buf("wipe", false, "nofile", "", true)
    after = math.min(after, fn.tabpagenr("$"))

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

---@param buf integer?
---@param enter boolean
---@param after integer
function M.open_new_tab_old(buf, enter, after)
    local ntt = require("nvim-tools.types")
    vim.validate("buf", buf, ntt.is_uint, true)
    vim.validate("enter", enter, "boolean")
    -- is_int because -1 is for current tabpage
    vim.validate("after", after, ntt.is_int)

    local range = after_to_range(after)
    local cur_win = api.nvim_get_current_win()

    api.nvim_cmd({ cmd = "tabnew", range = { range } }, {})
    local tabpage = api.nvim_get_current_tabpage()
    local new_win = api.nvim_get_current_win()
    local new_buf = api.nvim_win_get_buf(new_win)

    local ntb = require("nvim-tools.buf")
    if ntb.is_empty_noname(new_buf) then
        api.nvim_set_option_value("bh", "wipe", { buf = new_buf })
    end

    if buf then
        api.nvim_set_current_buf(buf)
    end

    if not enter then
        api.nvim_set_current_win(cur_win)
    end

    return tabpage
end
-- MAYBE: This could be more robust, but hate to put a bunch of time into something that will be
-- gone next version.

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

return M
