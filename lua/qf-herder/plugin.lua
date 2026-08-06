local api = vim.api

-- TODO: Rename the prefix back to QF_RANCHER for specificity
QFR_NO_ERRS = "No errors"
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

local key_diags = cfg_keymap.key_diags
local key_filename = cfg_keymap.key_filename

local sort_key = cfg_keymap.sort_key
local fname_asc = key_filename
local fname_desc = string.upper(fname_asc)
local sev_asc = key_diags
local sev_desc = string.upper(sev_asc)

local stack_clear = cfg_keymap.stack_clear
local stack_free = string.upper(stack_clear)
local last_ll_upper = string.upper(last_ll)
local last_qf_upper = string.upper(last_qf)
local stack_newer = cfg_keymap.stack_newer
local stack_older = cfg_keymap.stack_older

local win_close = cfg_keymap.win_close
local win_open = cfg_keymap.win_open
local resize = string.upper(win_open)

local nmode = { "n" }

local M = {}

-- stylua: ignore
M.maps = {

    -------------------------
    -- MARK: Maps - Window --
    -------------------------

{ nmode, "<Plug>(qf-herder-qf-open)", prefix_qf .. win_open, "", "Open the quickfix list", function() herder.window.qf_open() end, },
{ nmode, "<Plug>(qf-herder-qf-close)", prefix_qf .. win_close, "", "Close the quickfix list", function() herder.window.qf_close() end, },
{ nmode, "<Plug>(qf-herder-qf-toggle)", prefix_qf .. last_qf, "", "Toggle the quickfix list", function() herder.window.qf_toggle() end, },
{ nmode, "<Plug>(qf-herder-qf-resize)", prefix_qf .. resize, "", "Resize the quickfix list", function() herder.window.qf_resize() end, },
{ nmode, "<Plug>(qf-herder-ll-open)", prefix_ll .. win_open, "", "Open the location list", function() herder.window.ll_open() end, },
{ nmode, "<Plug>(qf-herder-ll-close)", prefix_ll .. win_close, "", "Close the location list", function() herder.window.ll_close() end, },
{ nmode, "<Plug>(qf-herder-ll-toggle)", prefix_ll .. last_ll, "", "Toggle the location list", function() herder.window.ll_toggle() end, },
{ nmode, "<Plug>(qf-herder-ll-resize)", prefix_ll .. resize, "", "Resize the location list", function() herder.window.ll_resize() end, },

    ----------------------
    -- MARK: Maps - Del --
    ----------------------

{ nmode, "<Plug>(qf-herder-del-single)", "", "", "Delete a single list item", function() herder.del.single() end, },
{ nmode, "<Plug>(qf-herder-del-visual)", "", "", "Delete visual line selected list items", function() herder.del.visual() end, },

    ----------------------
    -- MARK: Maps - Nav --
    ----------------------

{ nmode, "<Plug>(qf-herder-qf-prev)", "[" .. last_qf , "", "Open the [wrapping count] prev quickfix item", function() herder.nav.q_prev() end },
{ nmode, "<Plug>(qf-herder-qf-next)", "]" .. last_qf , "", "Open the [wrapping count] next quickfix item", function() herder.nav.q_next() end },
{ nmode, "<Plug>(qf-herder-qf-qq)", "", "", "Open the current or [count] quickfix item", function() herder.nav.q_q() end },
{ nmode, "<Plug>(qf-herder-qf-prev-keep-focus)", "" , "", "Open the [wrapping count] prev quickfix item, keep focus", function() herder.nav.q_prev_keep_focus() end },
{ nmode, "<Plug>(qf-herder-qf-next-keep-focus)", "" , "", "Open the [wrapping count] next quickfix item, keep focus", function() herder.nav.q_next_keep_focus() end },
{ nmode, "<Plug>(qf-herder-qf-qq-keep-focus)", "", "", "Open the current or [count] quickfix item, keep focus", function() herder.nav.q_q_keep_focus() end },
{ nmode, "<Plug>(qf-herder-qf-rewind)", "[" ..last_qf_upper, "", "Open the first or [count] quickfix item", function() herder.nav.q_rewind() end },
{ nmode, "<Plug>(qf-herder-qf-last)", "]" .. last_qf_upper, "", "Open the last or [count] quickfix item", function() herder.nav.q_last() end },
{ nmode, "<Plug>(qf-herder-qf-pfile)", "[<C-" .. last_qf_upper .. ">", "", "Open the [count] prev quickfix file", function() herder.nav.q_pfile() end },
{ nmode, "<Plug>(qf-herder-qf-nfile)", "]<C-" .. last_qf_upper .. ">", "", "Open the [count] next quickfix file", function() herder.nav.q_nfile() end },
{ nmode, "<Plug>(qf-herder-ll-prev)", "[" .. last_ll , "", "Open the [wrapping count] prev loclist item", function() herder.nav.l_prev() end },
{ nmode, "<Plug>(qf-herder-ll-next)", "]" .. last_ll , "", "Open the [wrapping count] next loclist item", function() herder.nav.l_next() end },
{ nmode, "<Plug>(qf-herder-ll-ll)", "", "", "Open the current or [count] loclist item", function() herder.nav.l_l() end },
{ nmode, "<Plug>(qf-herder-ll-prev-keep-focus)", "[" .. last_ll , "", "Open the [wrapping count] prev loclist item, keep focus", function() herder.nav.l_prev_keep_focus() end },
{ nmode, "<Plug>(qf-herder-ll-next-keep-focus)", "]" .. last_ll , "", "Open the [wrapping count] next loclist item, keep focus", function() herder.nav.l_next_keep_focus() end },
{ nmode, "<Plug>(qf-herder-ll-ll-keep-focus)", "", "", "Open the current or [count] loclist item, keep focus", function() herder.nav.l_l_keep_focus() end },
{ nmode, "<Plug>(qf-herder-ll-rewind)", "[" ..last_ll_upper, "", "Open the first or [count] loclist item", function() herder.nav.l_rewind() end },
{ nmode, "<Plug>(qf-herder-ll-last)", "]" .. last_ll_upper, "", "Open the last or [count] loclist item", function() herder.nav.l_last() end },
{ nmode, "<Plug>(qf-herder-ll-pfile)", "[<C-" .. last_ll_upper .. ">", "", "Open the [count] prev loclist file", function() herder.nav.l_pfile() end },
{ nmode, "<Plug>(qf-herder-ll-nfile)", "]<C-" .. last_ll_upper .. ">", "", "Open the [count] next loclist file", function() herder.nav.l_nfile() end },
{ nmode, "<Plug>(qf-herder-split)", "", "", "Open the current list item in a split", function() herder.nav.split() end },
{ nmode, "<Plug>(qf-herder-split-keep-focus)", "", "", "Open the current list item in a split, keeping focus", function() herder.nav.split_keep_focus() end },
{ nmode, "<Plug>(qf-herder-tabnew)", "", "", "Open the current list item in a new tab", function() herder.nav.tabnew() end },
{ nmode, "<Plug>(qf-herder-tabnew-keep-focus)", "", "", "Open the current list item in a new tab, keeping focus", function() herder.nav.tabnew_keep_focus() end },
{ nmode, "<Plug>(qf-herder-qf-vsplit)", "", "", "Open the current quickfix item in a vsplit", function() herder.nav.qf_vsplit() end },
{ nmode, "<Plug>(qf-herder-qf-vsplit-keep-focus)", "", "", "Open the current quickfix item in a vsplit, keeping focus", function() herder.nav.qf_vsplit_keep_focus() end },
{ nmode, "<Plug>(qf-herder-ll-vsplit)", "", "", "Open the current loclist item in a vsplit", function() herder.nav.ll_vsplit() end },
{ nmode, "<Plug>(qf-herder-ll-vsplit-keep-focus)", "", "", "Open the current loclist item in a vsplit, keeping focus", function() herder.nav.ll_vsplit_keep_focus() end },

    --------------------------
    -- MARK: Maps - Preview --
    --------------------------

{ nmode , "<Plug>(qf-herder-preview-open)", "", "", "Open the preview window", function() herder.preview.open() end },
{ nmode , "<Plug>(qf-herder-preview-close)", "", "", "Close the preview window", function() herder.preview.close() end },
{ nmode , "<Plug>(qf-herder-preview-toggle)", "", "", "Toggle the preview window", function() herder.preview.toggle() end },

    -----------------------
    -- MARK: Maps - Sort --
    -----------------------

{ nmode , "<Plug>(qf-herder-qf-sort-fname-asc)", prefix_qf .. sort_key .. fname_asc, "", "Sort [count] quickfix list by filename asc", function() herder.sort.qf_fname_asc() end },
{ nmode , "<Plug>(qf-herder-qf-sort-fname-desc)", prefix_qf .. sort_key .. fname_desc, "", "Sort [count] quickfix list by filename desc", function() herder.sort.qf_fname_desc() end },
{ nmode , "<Plug>(qf-herder-qf-sort-sev-asc)", prefix_qf .. sort_key .. sev_asc, "", "Sort [count] quickfix list by sev asc", function() herder.sort.qf_severity_asc() end },
{ nmode , "<Plug>(qf-herder-qf-sort-sev-desc)", prefix_qf .. sort_key .. sev_desc, "", "Sort [count] quickfix list by sev desc", function() herder.sort.qf_severity_desc() end },
{ nmode , "<Plug>(qf-herder-ll-sort-fname-asc)", prefix_ll .. sort_key .. fname_asc, "", "Sort [count] location list by filename asc", function() herder.sort.ll_fname_asc() end },
{ nmode , "<Plug>(qf-herder-ll-sort-fname-desc)", prefix_ll .. sort_key .. fname_desc, "", "Sort [count] location list by filename desc", function() herder.sort.ll_fname_desc() end },
{ nmode , "<Plug>(qf-herder-ll-sort-sev-asc)", prefix_ll .. sort_key .. sev_asc, "", "Sort [count] location list by severity asc", function() herder.sort.ll_severity_asc() end },
{ nmode , "<Plug>(qf-herder-ll-sort-sev-desc)", prefix_ll .. sort_key .. sev_desc, "", "Sort [count] location list by severity desc", function() herder.sort.ll_severity_desc() end },

    ------------------------
    -- MARK: Maps - Stack --
    ------------------------

{ nmode, "<Plug>(qf-herder-qf-older)", prefix_qf .. stack_older, "", "Go to a [wrapping count] older quickfix list", function() herder.stack.q_older() end },
{ nmode, "<Plug>(qf-herder-qf-newer)", prefix_qf .. stack_newer, "", "Go to a [wrapping count] newer quickfix list", function() herder.stack.q_newer() end },
{ nmode, "<Plug>(qf-herder-qf-history)", prefix_qf .. last_qf_upper, "", "Go to the [count] quickfix list or view the entire stack", function() herder.stack.q_history() end },
{ nmode, "<Plug>(qf-herder-qf-clear)", prefix_qf .. stack_clear, "", "Clear the [count] quickfix list", function() herder.stack.q_clear() end },
{ nmode, "<Plug>(qf-herder-qf-free)", prefix_qf .. stack_free, "", "Free the quickfix stack", function() herder.stack.q_free() end },
{ nmode, "<Plug>(qf-herder-ll-older)", prefix_ll .. stack_older, "", "Go to a [wrapping count] older location list", function() herder.stack.l_older() end },
{ nmode, "<Plug>(qf-herder-ll-newer)", prefix_ll .. stack_newer, "", "Go to a [wrapping count] newer location list", function() herder.stack.l_newer() end },
{ nmode, "<Plug>(qf-herder-ll-history)", prefix_ll .. last_ll_upper, "", "Go to the [count] location list or view the entire stack", function() herder.stack.l_history() end },
{ nmode, "<Plug>(qf-herder-ll-clear)", prefix_ll .. stack_clear, "", "Clear the [count] location list", function() herder.stack.l_clear() end },
{ nmode, "<Plug>(qf-herder-ll-free)", prefix_ll .. stack_free, "", "Free the location list stack", function() herder.stack.l_free() end },

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
        local lhs = map[3]
        if #lhs > 0 then
            for _, mode in ipairs(map[1]) do
                -- MID: Use `mapcheck()` or `hasmapto()`
                if vim.call("maparg", lhs, mode) == "" then
                    api.nvim_set_keymap(mode, lhs, map[2], { noremap = true, desc = map[5] })
                end
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
