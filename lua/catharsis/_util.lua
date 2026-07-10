local api = vim.api

local M = {}

---@param win uinteger
---@param buf uinteger
---@param pos_ext [uinteger, uinteger]
---@return boolean
function M.req_matches_nvim_state(win, buf, pos_ext)
    if api.nvim_get_current_win() ~= win or api.nvim_win_get_buf(win) ~= buf then
        return false
    end

    local cursor_ext = require("nvim-tools.win").cursor_ext_get(win)
    return require("nvim-tools.table").i_equals(cursor_ext, pos_ext)
end

return M
