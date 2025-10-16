--- @class QfRancherFiletypeFuncs
local M = {}

local et = Qfr_Defer_Require("mjm.error-list-tools") --- @type QfRancherTools
local eu = Qfr_Defer_Require("mjm.error-list-util") --- @type QfRancherUtils
local ey = Qfr_Defer_Require("mjm.error-list-types") --- @type QfRancherTypes

local api = vim.api
local fn = vim.fn

function M._del_one_list_item()
    local list_win = api.nvim_get_current_win() --- @type integer
    if not ey._is_in_list_win(list_win) then return end

    local wintype = fn.win_gettype(list_win)
    local src_win = wintype == "loclist" and list_win or nil --- @type integer|nil
    local list_dict = et._get_list(src_win, { nr = 0, all = true }) --- @type table
    if #list_dict.items < 1 then return end

    local row, col = unpack(api.nvim_win_get_cursor(list_win)) --- @type integer, integer
    table.remove(list_dict.items, row)
    et._set_list(src_win, {
        nr = 0,
        items = list_dict.items,
        idx = list_dict.idx,
        user_data = { action = "replace" },
    })

    eu._protected_set_cursor(0, { row, col })
end

return M
