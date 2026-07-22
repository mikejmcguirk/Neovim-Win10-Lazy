local api = vim.api

local M = {}

-- Credit https://github.com/romainl/vim-qf
---@param keep_focus boolean
function M.split(keep_focus)
    local list_win = api.nvim_get_current_win()
    vim.cmd("wincmd \r | noautocmd wincmd =")
    if keep_focus then
        api.nvim_set_current_win(list_win)
    end
end

-- Credit https://github.com/romainl/vim-qf
---@param keep_focus boolean
function M.tabnew(keep_focus)
    local list_win = api.nvim_get_current_win()
    vim.cmd("wincmd \r | noautocmd wincmd T")
    if keep_focus then
        api.nvim_set_current_win(list_win)
    end
end

-- Credit https://github.com/romainl/vim-qf
---@param keep_focus boolean
function M.qf_vsplit(keep_focus)
    local qf_win = api.nvim_get_current_win()
    local spr = api.nvim_get_option_value("spr", { scope = "global" })
    vim.cmd("wincmd \r | noautocmd wincmd " .. (spr and "L" or "H"))

    local qf_split = require("qf-herder")._config_get().window.qf_split
    local qf_move = (qf_split == "to" or qf_split == "topleft") and "K" or "J"
    if keep_focus then
        api.nvim_set_current_win(qf_win)
        vim.cmd("noautocmd wincmd " .. qf_move)
    else
        api.nvim_win_call(qf_win, function()
            vim.cmd("noautocmd wincmd " .. qf_move)
        end)
    end
end

-- Credit https://github.com/romainl/vim-qf
---@param keep_focus boolean
function M.ll_vsplit(keep_focus)
    local ll_win = api.nvim_get_current_win()
    local spr = api.nvim_get_option_value("spr", { scope = "global" })
    vim.cmd("wincmd \r | noautocmd wincmd " .. (spr and "L" or "H"))
    if keep_focus then
        api.nvim_set_current_win(ll_win)
    end
end

return M
