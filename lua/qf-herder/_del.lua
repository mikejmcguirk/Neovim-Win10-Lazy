local api = vim.api
local fn = vim.fn

local _tools = require("qf-herder._tools")

local M = {}

function M.single()
    local list_win = api.nvim_get_current_win() ---@type integer
    local wintype = fn.win_gettype(list_win)
    if not (wintype == "quickfix" or wintype == "loclist") then
        api.nvim_echo({ { QFR_NOT_LIST, "" } }, false, {})
        return
    end

    local src_win = wintype == "loclist" and list_win or nil
    local what_ret = _tools.get_list(src_win, { nr = 0, all = true }) ---@type table
    if #what_ret.items < 1 then
        return
    end

    local row, col = unpack(api.nvim_win_get_cursor(list_win))
    local cur_idx = _tools.get_list(src_win, { idx = 0 }).idx ---@type uinteger
    local new_idx = cur_idx > row and math.max(cur_idx - 1, 0) or cur_idx
    table.remove(what_ret.items, row)
    local adj_idx = math.min(new_idx, #what_ret.items)

    local what_set = _tools.what_ret_to_set(what_ret)
    what_set.idx = adj_idx
    _tools.set_list(src_win, "u", what_set)
    _tools.protected_set_cursor(0, { row, col })
end

function M.visual()
    local list_win = api.nvim_get_current_win() ---@type integer
    local wintype = fn.win_gettype(list_win)
    if not (wintype == "quickfix" or wintype == "loclist") then
        api.nvim_echo({ { QFR_NOT_LIST, "" } }, false, {})
        return
    end

    local mode = string.sub(api.nvim_get_mode().mode, 1, 1) ---@type string
    if mode ~= "V" then
        api.nvim_echo({ { "Must be in visual line mode", "" } }, false, {})
        return
    end

    local src_win = wintype == "loclist" and list_win or nil
    local what_ret = _tools.get_list(src_win, { nr = 0, all = true }) ---@type table
    if #what_ret.items < 1 then
        return
    end

    local vregion = _tools.region_from_positions(".", "v", "v", false)
    local vrange_4 = _tools.range_from_region(vregion)

    local cur_idx = _tools.get_list(src_win, { idx = 0 }).idx ---@type integer
    local idx_dist = math.max(cur_idx - vrange_4[1], 0) ---@type integer
    local idx_move = math.min(idx_dist, vrange_4[3] - vrange_4[1] + 1) ---@type integer
    local new_idx = math.max(cur_idx - idx_move, 0) ---@type integer

    local col = api.nvim_win_get_cursor(list_win)[2]
    api.nvim_cmd({ cmd = "normal", args = { "\27" }, bang = true }, {})
    for i = vrange_4[3], vrange_4[1], -1 do
        table.remove(what_ret.items, i)
    end

    local adj_idx = math.min(new_idx, #what_ret.items) ---@type integer
    _tools.set_list(src_win, "u", { nr = 0, items = what_ret.items, idx = adj_idx })
    _tools.protected_set_cursor(0, { vrange_4[1], col })
end

return M
