local api = vim.api

-- TODO: Rename the prefix back to QF_RANCHER for specificity
QFR_NO_LL = "No location list"

local herder = require("qf-herder")
local config = herder._config_get()
local cfg_keymap = config.keymap

local prefix_ll = cfg_keymap.prefix_ll
local prefix_ll_tbl = require("nvim-tools.str").split_map(prefix_ll)
local last_ll = prefix_ll_tbl[#prefix_ll_tbl]
local prefix_qf = cfg_keymap.prefix_qf
-- TODO: When cutting off, internalize the str functions
local prefix_qf_tbl = require("nvim-tools.str").split_map(prefix_qf)
local last_qf = prefix_qf_tbl[#prefix_qf_tbl]

local stack_clear = cfg_keymap.stack_clear
local stack_free = string.upper(stack_clear)
local stack_l_history = string.upper(last_ll)
local stack_q_history = string.upper(last_qf)
local stack_newer = cfg_keymap.stack_newer
local stack_older = cfg_keymap.stack_older

local win_close = cfg_keymap.win_close
local win_open = cfg_keymap.win_open
local resize = string.upper(win_open)

local M = {}

-- stylua: ignore
M.maps = {

    -------------------------
    -- MARK: Maps - Window --
    -------------------------

{ { "n" }, "<Plug>(qf-herder-qf-open)", prefix_qf .. win_open, "", "Open the quickfix list", function() require("qf-herder").window.qf_open() end, },
{ { "n" }, "<Plug>(qf-herder-qf-close)", prefix_qf .. win_close, "", "Close the quickfix list", function() require("qf-herder").window.qf_close() end, },
{ { "n" }, "<Plug>(qf-herder-qf-toggle)", prefix_qf .. last_qf, "", "Toggle the quickfix list", function() require("qf-herder").window.qf_toggle() end, },
{ { "n" }, "<Plug>(qf-herder-qf-resize)", prefix_qf .. resize, "", "Resize the quickfix list", function() require("qf-herder").window.qf_resize() end, },
{ { "n" }, "<Plug>(qf-herder-ll-open)", prefix_ll .. win_open, "", "Open the location list", function() require("qf-herder").window.ll_open() end, },
{ { "n" }, "<Plug>(qf-herder-ll-close)", prefix_ll .. win_close, "", "Close the location list", function() require("qf-herder").window.ll_close() end, },
{ { "n" }, "<Plug>(qf-herder-ll-toggle)", prefix_ll .. last_ll, "", "Toggle the location list", function() require("qf-herder").window.ll_toggle() end, },
{ { "n" }, "<Plug>(qf-herder-ll-resize)", prefix_ll .. resize, "", "Resize the location list", function() require("qf-herder").window.ll_resize() end, },

    ------------------------
    -- MARK: Maps - Stack --
    ------------------------

{ { "n" }, "<Plug>(qf-herder-qf-older)", prefix_qf .. stack_older, "", "Go to a [wrapping count] older quickfix list", function() require("qf-herder").stack.q_older() end },
{ { "n" }, "<Plug>(qf-herder-qf-newer)", prefix_qf .. stack_newer, "", "Go to a [wrapping count] newer quickfix list", function() require("qf-herder").stack.q_newer() end },
{ { "n" }, "<Plug>(qf-herder-qf-history)", prefix_qf .. stack_q_history, "", "Go to the [count] quickfix list or view the entire stack", function() require("qf-herder").stack.q_history() end },
{ { "n" }, "<Plug>(qf-herder-qf-clear)", prefix_qf .. stack_clear, "", "Clear the [count] quickfix list", function() require("qf-herder").stack.q_clear() end },
{ { "n" }, "<Plug>(qf-herder-qf-free)", prefix_qf .. stack_free, "", "Free the quickfix stack", function() require("qf-herder").stack.q_free() end },
{ { "n" }, "<Plug>(qf-herder-ll-older)", prefix_ll .. stack_older, "", "Go to a [wrapping count] older location list", function() require("qf-herder").stack.l_older() end },
{ { "n" }, "<Plug>(qf-herder-ll-newer)", prefix_ll .. stack_newer, "", "Go to a [wrapping count] newer location list", function() require("qf-herder").stack.l_newer() end },
{ { "n" }, "<Plug>(qf-herder-ll-history)", prefix_ll .. stack_l_history, "", "Go to the [count] location list or view the entire stack", function() require("qf-herder").stack.l_history() end },
{ { "n" }, "<Plug>(qf-herder-ll-clear)", prefix_ll .. stack_clear, "", "Clear the [count] location list", function() require("qf-herder").stack.l_clear() end },
{ { "n" }, "<Plug>(qf-herder-ll-free)", prefix_ll .. stack_free, "", "Free the location list stack", function() require("qf-herder").stack.l_free() end },

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

    ------------------------
    -- MARK: Cmds - Stack --
    ------------------------

{ "Qolder",  function(cargs) require("qf-herder._stack").q_older_cmd(cargs) end, { count = 0, desc = "Go to a [wrapping count] older quickfix list" } },
{ "Qnewer",  function(cargs) require("qf-herder._stack").q_newer_cmd(cargs) end, { count = 0, desc = "Go to a [wrapping count] newer quickfix list" } },
{ "Qhistory",  function(cargs) require("qf-herder._stack").q_history_cmd(cargs) end, { count = 0, desc = "Go to the [count] quickfix list or view the entire stack" } },
{ "Qclear",  function(cargs) require("qf-herder._stack").q_clear_cmd(cargs) end, { count = 0, desc = "Clear the [count] quickfix list" } },
{ "Qfree",  function() require("qf-herder._stack").q_free_cmd() end, { desc = "Free the quickfix stack" } },
{ "Lolder",  function(cargs) require("qf-herder._stack").l_older_cmd(cargs) end, { count = 0, desc = "Go to a [wrapping count] older location list" } },
{ "Lnewer",  function(cargs) require("qf-herder._stack").l_newer_cmd(cargs) end, { count = 0, desc = "Go to a [wrapping count] newer location list" } },
{ "Lhistory",  function(cargs) require("qf-herder._stack").l_history_cmd(cargs) end, { count = 0, desc = "Go to the [count] location list or view the entire stack" } },
{ "Lclear",  function(cargs) require("qf-herder._stack").l_clear_cmd(cargs) end, { count = 0, desc = "Clear the [count] location list" } },
{ "Lfree",  function() require("qf-herder._stack").l_free_cmd() end, { desc = "Free the location list stack" } },

}

for _, cmd in ipairs(M.cmds) do
    api.nvim_create_user_command(cmd[1], cmd[2], cmd[3])
end
