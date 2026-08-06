local api = vim.api
local fn = vim.fn

local ntq = require("nvim-tools.quickfix")

local M = {}

function M.single()
    local list_win = api.nvim_get_current_win() ---@type integer
    local wintype = fn.win_gettype(list_win)
    if not (wintype == "quickfix" or wintype == "loclist") then
        api.nvim_echo({ { QFR_NOT_LIST, "" } }, false, {})
        return
    end

    local src_win = wintype == "loclist" and list_win or nil
    local what_ret = ntq.get_list(src_win, { nr = 0, all = true }) ---@type table
    if #what_ret.items < 1 then
        return
    end

    local row, col = unpack(api.nvim_win_get_cursor(list_win))
    local cur_idx = ntq.get_list(src_win, { idx = 0 }).idx ---@type uinteger
    local new_idx = cur_idx > row and math.max(cur_idx - 1, 0) or cur_idx
    table.remove(what_ret.items, row)
    local adj_idx = math.min(new_idx, #what_ret.items)

    local what_set = ntq.what_ret_to_set(what_ret)
    what_set.idx = adj_idx
    ntq.set_list(src_win, "u", what_set)
    require("nvim-tools.win").protected_set_cursor(0, { row, col })
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
    local what_ret = ntq.get_list(src_win, { nr = 0, all = true }) ---@type table
    if #what_ret.items < 1 then
        return
    end

    local vrange_4 = require("nvim-tools.range").get_regionpos4(".", "v", mode)

    local cur_idx = ntq.get_list(src_win, { idx = 0 }).idx ---@type integer
    local idx_dist = math.max(cur_idx - vrange_4[1], 0) ---@type integer
    local idx_move = math.min(idx_dist, vrange_4[3] - vrange_4[1] + 1) ---@type integer
    local new_idx = math.max(cur_idx - idx_move, 0) ---@type integer

    local col = api.nvim_win_get_cursor(list_win)[2]
    api.nvim_cmd({ cmd = "normal", args = { "\27" }, bang = true }, {})
    for i = vrange_4[3], vrange_4[1], -1 do
        table.remove(what_ret.items, i)
    end

    local adj_idx = math.min(new_idx, #what_ret.items) ---@type integer
    ntq.set_list(src_win, "u", { nr = 0, items = what_ret.items, idx = adj_idx })

    require("nvim-tools.win").protected_set_cursor(0, { vrange_4[1], col })
end

return M
