local api = vim.api
local fn = vim.fn

local herder = require("qf-herder")

local M = {}

function M.do_ftplugin()
    local ft = api.nvim_get_option_value("ft", { buf = 0 })
    if ft ~= "qf" then
        return
    end

    local cur_buf = api.nvim_get_current_buf()
    ---@type qf-herder.ftplugin.Cfg
    local cfg_ftplugin = herder._config_merged_get(cur_buf, nil, "ftplugin")

    if cfg_ftplugin.opts_set then
        local buf_scope = { buf = cur_buf }
        api.nvim_set_option_value("bl", false, buf_scope)

        local local_scope = { scope = "local" }
        api.nvim_set_option_value("cc", "", local_scope)
        api.nvim_set_option_value("list", false, local_scope)
        api.nvim_set_option_value("spell", false, local_scope)
    end

    if not cfg_ftplugin.maps_set then
        return
    end

    local opts = { noremap = true, nowait = true }
    api.nvim_buf_set_keymap(0, "x", "d", "<Plug>(qf-herder-del-visual)", opts)
    api.nvim_buf_set_keymap(0, "n", "dd", "<Plug>(qf-herder-del-single)", opts)
    api.nvim_buf_set_keymap(0, "n", "p", "<Plug>(qf-herder-preview-toggle)", opts)
    api.nvim_buf_set_keymap(0, "n", "s", "<Plug>(qf-herder-split)", opts)
    api.nvim_buf_set_keymap(0, "n", "<C-s>", "<Plug>(qf-herder-split-keep-focus)", opts)
    api.nvim_buf_set_keymap(0, "n", "x", "<Plug>(qf-herder-tabnew)", opts)
    api.nvim_buf_set_keymap(0, "n", "<C-x>", "<Plug>(qf-herder-tabnew-keep-focus)", opts)

    if fn.win_gettype(0) == "loclist" then
        api.nvim_buf_set_keymap(0, "n", "o", "<Plug>(qf-herder-ll-ll)", opts)
        api.nvim_buf_set_keymap(0, "n", "<C-o>", "<Plug>(qf-herder-ll-ll-keep-focus)", opts)
        api.nvim_buf_set_keymap(0, "n", "q", "<Plug>(qf-herder-ll-close)", opts)
        api.nvim_buf_set_keymap(0, "n", "v", "<Plug>(qf-herder-ll-vsplit)", opts)
        api.nvim_buf_set_keymap(0, "n", "<C-v>", "<Plug>(qf-herder-ll-vsplit-keep-focus)", opts)
        api.nvim_buf_set_keymap(0, "n", "<", "<Plug>(qf-herder-ll-older)", opts)
        api.nvim_buf_set_keymap(0, "n", ">", "<Plug>(qf-herder-ll-newer)", opts)
        api.nvim_buf_set_keymap(0, "n", "{", "<Plug>(qf-herder-ll-prev-keep-focus)", opts)
        api.nvim_buf_set_keymap(0, "n", "}", "<Plug>(qf-herder-ll-next-keep-focus)", opts)
    else
        api.nvim_buf_set_keymap(0, "n", "o", "<Plug>(qf-herder-qf-qq)", opts)
        api.nvim_buf_set_keymap(0, "n", "<C-o>", "<Plug>(qf-herder-qf-qq-keep-focus)", opts)
        api.nvim_buf_set_keymap(0, "n", "q", "<Plug>(qf-herder-qf-close)", opts)
        api.nvim_buf_set_keymap(0, "n", "v", "<Plug>(qf-herder-qf-vsplit)", opts)
        api.nvim_buf_set_keymap(0, "n", "<C-v>", "<Plug>(qf-herder-qf-vsplit-keep-focus)", opts)
        api.nvim_buf_set_keymap(0, "n", "<", "<Plug>(qf-herder-qf-older)", opts)
        api.nvim_buf_set_keymap(0, "n", ">", "<Plug>(qf-herder-qf-newer)", opts)
        api.nvim_buf_set_keymap(0, "n", "{", "<Plug>(qf-herder-qf-prev-keep-focus)", opts)
        api.nvim_buf_set_keymap(0, "n", "}", "<Plug>(qf-herder-qf-next-keep-focus)", opts)
    end
end

return M
-- TODO: Remove the M table and wrapper function when actually setting this up as an ftplugin.
