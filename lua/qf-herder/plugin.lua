local api = vim.api

local herder = require("qf-herder")
local config = herder._config_get()
local cfg_keymap = config.keymap

local qf_prefix = cfg_keymap.qf_prefix
-- TODO: When cutting off, internalize the str functions
local qf_prefix_tbl = require("nvim-tools.str").split_map(qf_prefix)
local qf_last = qf_prefix_tbl[#qf_prefix_tbl]
local ll_prefix = cfg_keymap.ll_prefix
local ll_prefix_tbl = require("nvim-tools.str").split_map(ll_prefix)
local ll_last = ll_prefix_tbl[#ll_prefix_tbl]

local win_close = cfg_keymap.win_close
local win_open = cfg_keymap.win_open
local resize = string.upper(win_open)

local M = {}

-- stylua: ignore
M.maps = {

    -------------------------
    -- MARK: Maps - Window --
    -------------------------

{ { "n" }, "<Plug>(qf-herder-qf-open)", qf_prefix .. win_open, "", "Open the quickfix list", function() require("qf-herder").window.qf_open() end, },
{ { "n" }, "<Plug>(qf-herder-qf-close)", qf_prefix .. win_close, "", "Close the quickfix list", function() require("qf-herder").window.qf_close() end, },
{ { "n" }, "<Plug>(qf-herder-qf-toggle)", qf_prefix .. qf_last, "", "Toggle the quickfix list", function() require("qf-herder").window.qf_toggle() end, },
{ { "n" }, "<Plug>(qf-herder-qf-resize)", qf_prefix .. resize, "", "Resize the quickfix list", function() require("qf-herder").window.qf_resize() end, },
{ { "n" }, "<Plug>(qf-herder-ll-open)", ll_prefix .. win_open, "", "Open the location list", function() require("qf-herder").window.ll_open() end, },
{ { "n" }, "<Plug>(qf-herder-ll-close)", ll_prefix .. win_close, "", "Close the location list", function() require("qf-herder").window.ll_close() end, },
{ { "n" }, "<Plug>(qf-herder-ll-toggle)", ll_prefix .. ll_last, "", "Toggle the location list", function() require("qf-herder").window.ll_toggle() end, },
{ { "n" }, "<Plug>(qf-herder-ll-resize)", ll_prefix .. resize, "", "Resize the location list", function() require("qf-herder").window.ll_resize() end, },
}

for _, map in ipairs(M.maps) do
    for _, mode in ipairs(map[1]) do
        api.nvim_set_keymap(mode, map[2], map[4], {
            noremap = true,
            desc = map[5],
            callback = map[6],
        })
    end
end

-- TODO: do we need this here?
-- TODO-DEP: Remove this when 0.14 comes out.
api.nvim_set_hl(0, "Dimmed", { default = true, link = "Comment" })

if config.default_keymaps_set then
    for _, map in ipairs(M.maps) do
        for _, mode in ipairs(map[1]) do
            -- MID: Use `mapcheck()` or `hasmapto()`
            local lhs = map[3]
            if vim.call("maparg", lhs, mode) == "" then
                api.nvim_set_keymap(mode, lhs, map[2], { noremap = true, desc = map[5] })
            end
        end
    end
end

if not config.default_cmds_set then
    return
end

-- stylua: ignore
M.cmds = {

    -------------------------
    -- MARK: Cmds - Window --
    -------------------------

{ "Qopen", function(cargs) require("qf-herder._window").q_open_cmd(cargs) end, { count = 0, desc = "Open the quickfix list to [count] height" } },
{ "Qclose", function() require("qf-herder._window").q_close_cmd() end, { desc = "Close the quickfix list" } },
{ "Qtoggle", function(cargs) require("qf-herder._window").q_toggle_cmd(cargs) end, { count = 0, desc = "Toggle the quickfix list (to [count] height on open)" } },
{ "Qresize", function(cargs) require("qf-herder._window").q_resize_cmd(cargs) end, { count = 0, desc = "Resize the quickfix list to [count] height" } },
{ "Lopen", function(cargs) require("qf-herder._window").l_open_cmd(cargs) end, { count = 0, desc = "Open the location list to [count] height" } },
{ "Lclose", function() require("qf-herder._window").l_close_cmd() end, { desc = "Close the location list" } },
{ "Ltoggle", function(cargs) require("qf-herder._window").l_toggle_cmd(cargs) end, { count = 0, desc = "Toggle the location list (to [count] height on open)" } },
{ "Lresize", function(cargs) require("qf-herder._window").l_resize_cmd(cargs) end, { count = 0, desc = "Resize the location list to [count] height" } },
}

for _, cmd in ipairs(M.cmds) do
    api.nvim_create_user_command(cmd[1], cmd[2], cmd[3])
end
