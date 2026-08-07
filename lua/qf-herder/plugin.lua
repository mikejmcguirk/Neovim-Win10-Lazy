local api = vim.api

local hls = {
    { "QfRancherPreviewRange", "CurSearch" },
}

for _, hl in ipairs(hls) do
    api.nvim_set_hl(0, hl[1], { default = true, link = hl[2] })
end

-- TODO: Rename the prefix back to QF_RANCHER for specificity
QFR_NO_ERRS = "No errors"
QFR_NO_LL = "No location list"
QFR_NOT_LIST = "Current win is not an error list"

local herder = require("qf-herder")
local config = herder._config_get()
local cfg_keymap = config.keymap

-- TODO: When cutting off, make as many of the external calls as possible local to this module
-- to reduce requires.

local prefix_ll = cfg_keymap.prefix_ll
local prefix_ll_tbl = require("nvim-tools.str").split_map(prefix_ll)
local last_ll = prefix_ll_tbl[#prefix_ll_tbl]
local prefix_qf = cfg_keymap.prefix_qf
local prefix_qf_tbl = require("nvim-tools.str").split_map(prefix_qf)
local last_qf = prefix_qf_tbl[#prefix_qf_tbl]

local key_diag = cfg_keymap.key_diag
local diag_err = cfg_keymap.diag_err
local diag_warn = cfg_keymap.diag_warn
local diag_info = cfg_keymap.diag_info
local diag_hint = cfg_keymap.diag_hint
local diag_err_only = string.upper(diag_err)
local diag_warn_only = string.upper(diag_warn)
local diag_info_only = string.upper(diag_info)
local diag_hint_only = string.upper(diag_hint)

local prefix_grep = cfg_keymap.prefix_grep
local key_buf = cfg_keymap.key_buf
local key_help = cfg_keymap.key_help
local key_dir = cfg_keymap.key_dir
local key_buf_re = string.upper(key_buf)
local key_help_re = string.upper(key_help)
local key_dir_re = string.upper(key_dir)

local key_filter = cfg_keymap.key_filter
local key_text = cfg_keymap.key_text
local key_text_upper = string.upper(key_text)

local sort_key = cfg_keymap.sort_key
local key_fname = cfg_keymap.fname
local key_fname_upper = string.upper(key_fname)
local sev_asc = key_diag
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
local nxmode = { "n", "x" }

local M = {}

-- stylua: ignore
M.maps = {

    -------------------------
    -- MARK: Maps - Window --
    -------------------------

{ nmode, "<Plug>(qf-herder-qf-open)", { prefix_qf .. win_open }, "", "Open the quickfix list", function() herder.window.qf_open() end, },
{ nmode, "<Plug>(qf-herder-qf-close)", { prefix_qf .. win_close }, "", "Close the quickfix list", function() herder.window.qf_close() end, },
{ nmode, "<Plug>(qf-herder-qf-toggle)", { prefix_qf .. last_qf }, "", "Toggle the quickfix list", function() herder.window.qf_toggle() end, },
{ nmode, "<Plug>(qf-herder-qf-resize)", { prefix_qf .. resize }, "", "Resize the quickfix list", function() herder.window.qf_resize() end, },
{ nmode, "<Plug>(qf-herder-ll-open)", { prefix_ll .. win_open }, "", "Open the location list", function() herder.window.ll_open() end, },
{ nmode, "<Plug>(qf-herder-ll-close)", { prefix_ll .. win_close }, "", "Close the location list", function() herder.window.ll_close() end, },
{ nmode, "<Plug>(qf-herder-ll-toggle)", { prefix_ll .. last_ll }, "", "Toggle the location list", function() herder.window.ll_toggle() end, },
{ nmode, "<Plug>(qf-herder-ll-resize)", { prefix_ll .. resize }, "", "Resize the location list", function() herder.window.ll_resize() end, },

    ----------------------
    -- MARK: Maps - Del --
    ----------------------

{ nmode, "<Plug>(qf-herder-del-single)", {}, "", "Delete a single list item", function() herder.del.single() end, },
{ nmode, "<Plug>(qf-herder-del-visual)", {}, "", "Delete visual line selected list items", function() herder.del.visual() end, },

    ------------------------------
    -- MARK: Maps - Diagnostics --
    ------------------------------

{ nmode, "<Plug>(qf-herder-diag-ll-curbuf-errs)", { prefix_ll .. key_diag .. diag_err, prefix_ll .. key_diag .. diag_err_only }, "", "Send cur buf errors to the location list", function() herder.diags.ll_cur_buf_errors() end, },
{ nmode, "<Plug>(qf-herder-diag-ll-curbuf-min-hint)", { prefix_ll .. key_diag .. diag_hint }, "", "Send cur buf hints+ to the location list", function() herder.diags.ll_cur_buf_min_hint() end, },
{ nmode, "<Plug>(qf-herder-diag-ll-curbuf-min-info)", { prefix_ll .. key_diag .. diag_info }, "", "Send cur buf info+ to the location list", function() herder.diags.ll_cur_buf_min_info() end, },
{ nmode, "<Plug>(qf-herder-diag-ll-curbuf-min-warn)", { prefix_ll .. key_diag .. diag_warn }, "", "Send cur buf warnings+ to the location list", function() herder.diags.ll_cur_buf_min_warn() end, },
{ nmode, "<Plug>(qf-herder-diag-ll-curbuf-only-hint)", { prefix_ll .. key_diag .. diag_hint_only }, "", "Send cur buf hints to the location list", function() herder.diags.ll_cur_buf_only_hint() end, },
{ nmode, "<Plug>(qf-herder-diag-ll-curbuf-only-info)", { prefix_ll .. key_diag .. diag_info_only }, "", "Send cur buf info to the location list", function() herder.diags.ll_cur_buf_only_info() end, },
{ nmode, "<Plug>(qf-herder-diag-ll-curbuf-only-warn)", { prefix_ll .. key_diag .. diag_warn_only }, "", "Send cur buf warnings to the location list", function() herder.diags.ll_cur_buf_only_warn() end, },
{ nmode, "<Plug>(qf-herder-diag-qf-bufs-errs)", { prefix_qf .. key_diag .. diag_err, prefix_qf .. key_diag .. diag_err_only }, "", "Send all errors to the quickfix list", function() herder.diags.qf_all_bufs_err() end, },
{ nmode, "<Plug>(qf-herder-diag-qf-bufs-min-hint)", { prefix_qf .. key_diag .. diag_hint }, "", "Send all hints+ to the quickfix list", function() herder.diags.qf_all_bufs_min_hint() end, },
{ nmode, "<Plug>(qf-herder-diag-qf-bufs-min-info)", { prefix_qf .. key_diag .. diag_info }, "", "Send all info+ to the quickfix list", function() herder.diags.qf_all_bufs_min_info() end, },
{ nmode, "<Plug>(qf-herder-diag-qf-bufs-min-warn)", { prefix_qf .. key_diag .. diag_warn }, "", "Send all warnings+ to the quickfix list", function() herder.diags.qf_all_bufs_min_warnings() end, },
{ nmode, "<Plug>(qf-herder-diag-qf-bufs-only-hint)", { prefix_qf .. key_diag .. diag_hint_only }, "", "Send all hints to the quickfix list", function() herder.diags.qf_all_bufs_only_hint() end, },
{ nmode, "<Plug>(qf-herder-diag-qf-bufs-only-info)", { prefix_qf .. key_diag .. diag_info_only }, "", "Send all info to the quickfix list", function() herder.diags.qf_all_bufs_only_info() end, },
{ nmode, "<Plug>(qf-herder-diag-qf-bufs-only-warn)", { prefix_qf .. key_diag .. diag_warn_only }, "", "Send all warnings to the quickfix list", function() herder.diags.qf_all_bufs_only_warnings() end, },

    -----------------------
    -- MARK: Maps - Filter --
    -----------------------

{ nmode, "<Plug>(qf-herder-filter-ll-fname-keep)", { prefix_ll .. key_filter .. key_fname }, "", "Keep matching filenames", function() herder.filter.ll_fname_keep() end, },
{ nmode, "<Plug>(qf-herder-filter-ll-fname-discard)", { prefix_ll .. key_filter .. key_fname_upper }, "", "Discard matching filenames", function() herder.filter.ll_fname_discard() end, },
{ nmode, "<Plug>(qf-herder-filter-ll-text-keep)", { prefix_ll .. key_filter .. key_text }, "", "Keep matching filenames", function() herder.filter.ll_text_keep() end, },
{ nmode, "<Plug>(qf-herder-filter-ll-text-discard)", { prefix_ll .. key_filter .. key_text_upper }, "", "Discard matching filenames", function() herder.filter.ll_text_discard() end, },
{ nmode, "<Plug>(qf-herder-filter-qf-fname-keep)", { prefix_qf .. key_filter .. key_fname }, "", "Keep matching filenames", function() herder.filter.qf_fname_keep() end, },
{ nmode, "<Plug>(qf-herder-filter-qf-fname-discard)", { prefix_qf .. key_filter .. key_fname_upper }, "", "Discard matching filenames", function() herder.filter.qf_fname_discard() end, },
{ nmode, "<Plug>(qf-herder-filter-qf-text-keep)", { prefix_qf .. key_filter .. key_text }, "", "Keep matching filenames", function() herder.filter.qf_text_keep() end, },
{ nmode, "<Plug>(qf-herder-filter-qf-text-discard)", { prefix_qf .. key_filter .. key_text_upper }, "", "Discard matching filenames", function() herder.filter.qf_text_discard() end, },

    -----------------------
    -- MARK: Maps - Grep --
    -----------------------

{ nxmode, "<Plug>(qf-herder-rg-ll-bcd-fixed)", { prefix_ll .. prefix_grep .. key_buf }, "", "Ripgrep the bcd to the location list (fixed strings)", function() herder.rg.ll_bcd_fixed() end, },
{ nxmode, "<Plug>(qf-herder-rg-ll-bcd-regex)", { prefix_ll .. prefix_grep .. key_buf_re }, "", "Ripgrep the bcd to the location list (regex)", function() herder.rg.ll_bcd_regex() end, },
{ nxmode, "<Plug>(qf-herder-rg-ll-curbuf-fixed)", { prefix_ll .. prefix_grep .. key_buf }, "", "Ripgrep a single buf to the location list (fixed strings)", function() herder.rg.ll_cur_buf_fixed() end, },
{ nxmode, "<Plug>(qf-herder-rg-ll-curbuf-regex)", { prefix_ll .. prefix_grep .. key_buf_re }, "", "Ripgrep a single buf to the location list (regex)", function() herder.rg.ll_cur_buf_regex() end, },
{ nxmode, "<Plug>(qf-herder-rg-ll-help-fixed)", { prefix_ll .. prefix_grep .. key_help }, "", "Ripgrep help dirs to the location list (fixed strings)", function() herder.rg.ll_help_fixed() end, },
{ nxmode, "<Plug>(qf-herder-rg-ll-help-regex)", { prefix_ll .. prefix_grep .. key_help_re }, "", "Ripgrep help dirs to the location list (regex)", function() herder.rg.ll_help_regex() end, },
{ nxmode, "<Plug>(qf-herder-rg-qf-bufs-fixed)", { prefix_qf .. prefix_grep .. key_buf }, "", "Ripgrep all bufs to the quickfix list (fixed strings)", function() herder.rg.qf_bufs_fixed() end, },
{ nxmode, "<Plug>(qf-herder-rg-qf-bufs-regex)", { prefix_qf .. prefix_grep .. key_buf_re }, "", "Ripgrep all bufs to the quickfix list (regex)", function() herder.rg.qf_bufs_regex() end, },
{ nxmode, "<Plug>(qf-herder-rg-qf-tcd-fixed)", { prefix_qf .. prefix_grep .. key_dir }, "", "Ripgrep the tcd to the quickfix list (fixed strings)", function() herder.rg.qf_tcd_fixed() end, },
{ nxmode, "<Plug>(qf-herder-rg-qf-tcd-regex)", { prefix_qf .. prefix_grep .. key_dir_re }, "", "Ripgrep the tcd to the quickfix list (regex)", function() herder.rg.qf_tcd_regex() end, },

    ----------------------
    -- MARK: Maps - Nav --
    ----------------------

{ nmode, "<Plug>(qf-herder-ll-last)", { "]" .. last_ll_upper }, "", "Open the last or [count] loclist item", function() herder.nav.l_last() end },
{ nmode, "<Plug>(qf-herder-ll-ll)", {}, "", "Open the current or [count] loclist item", function() herder.nav.l_l() end },
{ nmode, "<Plug>(qf-herder-ll-ll-keep-focus)", {}, "", "Open the current or [count] loclist item, keep focus", function() herder.nav.l_l_keep_focus() end },
{ nmode, "<Plug>(qf-herder-ll-next)", { "]" .. last_ll } , "", "Open the [wrapping count] next loclist item", function() herder.nav.l_next() end },
{ nmode, "<Plug>(qf-herder-ll-next-keep-focus)", { "]" .. last_ll }, "", "Open the [wrapping count] next loclist item, keep focus", function() herder.nav.l_next_keep_focus() end },
{ nmode, "<Plug>(qf-herder-ll-nfile)", { "]<C-" .. last_ll_upper .. ">" }, "", "Open the [count] next loclist file", function() herder.nav.l_nfile() end },
{ nmode, "<Plug>(qf-herder-ll-pfile)", { "[<C-" .. last_ll_upper .. ">" }, "", "Open the [count] prev loclist file", function() herder.nav.l_pfile() end },
{ nmode, "<Plug>(qf-herder-ll-prev)", { "[" .. last_ll } , "", "Open the [wrapping count] prev loclist item", function() herder.nav.l_prev() end },
{ nmode, "<Plug>(qf-herder-ll-prev-keep-focus)", { "[" .. last_ll }, "", "Open the [wrapping count] prev loclist item, keep focus", function() herder.nav.l_prev_keep_focus() end },
{ nmode, "<Plug>(qf-herder-ll-rewind)", { "[" .. last_ll_upper }, "", "Open the first or [count] loclist item", function() herder.nav.l_rewind() end },
{ nmode, "<Plug>(qf-herder-ll-vsplit)", {}, "", "Open the current loclist item in a vsplit", function() herder.nav.ll_vsplit() end },
{ nmode, "<Plug>(qf-herder-ll-vsplit-keep-focus)", {}, "", "Open the current loclist item in a vsplit, keeping focus", function() herder.nav.ll_vsplit_keep_focus() end },
{ nmode, "<Plug>(qf-herder-qf-last)", { "]" .. last_qf_upper }, "", "Open the last or [count] quickfix item", function() herder.nav.q_last() end },
{ nmode, "<Plug>(qf-herder-qf-next)", { "]" .. last_qf }, "", "Open the [wrapping count] next quickfix item", function() herder.nav.q_next() end },
{ nmode, "<Plug>(qf-herder-qf-next-keep-focus)", {}, "", "Open the [wrapping count] next quickfix item, keep focus", function() herder.nav.q_next_keep_focus() end },
{ nmode, "<Plug>(qf-herder-qf-nfile)", { "]<C-" .. last_qf_upper .. ">" }, "", "Open the [count] next quickfix file", function() herder.nav.q_nfile() end },
{ nmode, "<Plug>(qf-herder-qf-pfile)", { "[<C-" .. last_qf_upper .. ">" }, "", "Open the [count] prev quickfix file", function() herder.nav.q_pfile() end },
{ nmode, "<Plug>(qf-herder-qf-prev)", { "[" .. last_qf }, "", "Open the [wrapping count] prev quickfix item", function() herder.nav.q_prev() end },
{ nmode, "<Plug>(qf-herder-qf-prev-keep-focus)", {}, "", "Open the [wrapping count] prev quickfix item, keep focus", function() herder.nav.q_prev_keep_focus() end },
{ nmode, "<Plug>(qf-herder-qf-qq)", {}, "", "Open the current or [count] quickfix item", function() herder.nav.q_q() end },
{ nmode, "<Plug>(qf-herder-qf-qq-keep-focus)", {}, "", "Open the current or [count] quickfix item, keep focus", function() herder.nav.q_q_keep_focus() end },
{ nmode, "<Plug>(qf-herder-qf-rewind)", { "[" .. last_qf_upper }, "", "Open the first or [count] quickfix item", function() herder.nav.q_rewind() end },
{ nmode, "<Plug>(qf-herder-qf-vsplit)", {}, "", "Open the current quickfix item in a vsplit", function() herder.nav.qf_vsplit() end },
{ nmode, "<Plug>(qf-herder-qf-vsplit-keep-focus)", {}, "", "Open the current quickfix item in a vsplit, keeping focus", function() herder.nav.qf_vsplit_keep_focus() end },
{ nmode, "<Plug>(qf-herder-split)", {}, "", "Open the current list item in a split", function() herder.nav.split() end },
{ nmode, "<Plug>(qf-herder-split-keep-focus)", {}, "", "Open the current list item in a split, keeping focus", function() herder.nav.split_keep_focus() end },
{ nmode, "<Plug>(qf-herder-tabnew)", {}, "", "Open the current list item in a new tab", function() herder.nav.tabnew() end },
{ nmode, "<Plug>(qf-herder-tabnew-keep-focus)", {}, "", "Open the current list item in a new tab, keeping focus", function() herder.nav.tabnew_keep_focus() end },

    --------------------------
    -- MARK: Maps - Preview --
    --------------------------

{ nmode , "<Plug>(qf-herder-preview-open)", {}, "", "Open the preview window", function() herder.preview.open() end },
{ nmode , "<Plug>(qf-herder-preview-close)", {}, "", "Close the preview window", function() herder.preview.close() end },
{ nmode , "<Plug>(qf-herder-preview-toggle)", {}, "", "Toggle the preview window", function() herder.preview.toggle() end },

    -----------------------
    -- MARK: Maps - Sort --
    -----------------------

{ nmode , "<Plug>(qf-herder-qf-sort-fname-asc)", { prefix_qf .. sort_key .. key_fname }, "", "Sort [count] quickfix list by filename asc", function() herder.sort.qf_fname_asc() end },
{ nmode , "<Plug>(qf-herder-qf-sort-fname-desc)", { prefix_qf .. sort_key .. key_fname_upper }, "", "Sort [count] quickfix list by filename desc", function() herder.sort.qf_fname_desc() end },
{ nmode , "<Plug>(qf-herder-qf-sort-sev-asc)", { prefix_qf .. sort_key .. sev_asc }, "", "Sort [count] quickfix list by sev asc", function() herder.sort.qf_severity_asc() end },
{ nmode , "<Plug>(qf-herder-qf-sort-sev-desc)", { prefix_qf .. sort_key .. sev_desc }, "", "Sort [count] quickfix list by sev desc", function() herder.sort.qf_severity_desc() end },
{ nmode , "<Plug>(qf-herder-ll-sort-fname-asc)", { prefix_ll .. sort_key .. key_fname }, "", "Sort [count] location list by filename asc", function() herder.sort.ll_fname_asc() end },
{ nmode , "<Plug>(qf-herder-ll-sort-fname-desc)", { prefix_ll .. sort_key .. key_fname_upper }, "", "Sort [count] location list by filename desc", function() herder.sort.ll_fname_desc() end },
{ nmode , "<Plug>(qf-herder-ll-sort-sev-asc)", { prefix_ll .. sort_key .. sev_asc }, "", "Sort [count] location list by severity asc", function() herder.sort.ll_severity_asc() end },
{ nmode , "<Plug>(qf-herder-ll-sort-sev-desc)", { prefix_ll .. sort_key .. sev_desc }, "", "Sort [count] location list by severity desc", function() herder.sort.ll_severity_desc() end },

    ------------------------
    -- MARK: Maps - Stack --
    ------------------------

{ nmode, "<Plug>(qf-herder-qf-older)", { prefix_qf .. stack_older }, "", "Go to a [wrapping count] older quickfix list", function() herder.stack.q_older() end },
{ nmode, "<Plug>(qf-herder-qf-newer)", { prefix_qf .. stack_newer }, "", "Go to a [wrapping count] newer quickfix list", function() herder.stack.q_newer() end },
{ nmode, "<Plug>(qf-herder-qf-history)", { prefix_qf .. last_qf_upper }, "", "Go to the [count] quickfix list or view the entire stack", function() herder.stack.q_history() end },
{ nmode, "<Plug>(qf-herder-qf-clear)", { prefix_qf .. stack_clear }, "", "Clear the [count] quickfix list", function() herder.stack.q_clear() end },
{ nmode, "<Plug>(qf-herder-qf-free)", { prefix_qf .. stack_free }, "", "Free the quickfix stack", function() herder.stack.q_free() end },
{ nmode, "<Plug>(qf-herder-ll-older)", { prefix_ll .. stack_older }, "", "Go to a [wrapping count] older location list", function() herder.stack.l_older() end },
{ nmode, "<Plug>(qf-herder-ll-newer)", { prefix_ll .. stack_newer }, "", "Go to a [wrapping count] newer location list", function() herder.stack.l_newer() end },
{ nmode, "<Plug>(qf-herder-ll-history)", { prefix_ll .. last_ll_upper }, "", "Go to the [count] location list or view the entire stack", function() herder.stack.l_history() end },
{ nmode, "<Plug>(qf-herder-ll-clear)", { prefix_ll .. stack_clear }, "", "Clear the [count] location list", function() herder.stack.l_clear() end },
{ nmode, "<Plug>(qf-herder-ll-free)", { prefix_ll .. stack_free }, "", "Free the location list stack", function() herder.stack.l_free() end },

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

if config.default_keymaps_set then
    for _, map in ipairs(M.maps) do
        for _, lhs in ipairs(map[3]) do
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
{ "Lclose", function(cargs) require("qf-herder._window").l_close_cmd(cargs) end, { desc = "Close the location list" } },
{ "Ltoggle", function(cargs) require("qf-herder._window").l_toggle_cmd(cargs) end, { count = 0, desc = "Toggle the location list (to [count] height on open)" } },
{ "Lresize", function(cargs) require("qf-herder._window").l_resize_cmd(cargs) end, { count = 0, desc = "Resize the location list to [count] height" } },

    ------------------------
    -- MARK: Cmds - Nav --
    ------------------------

{ "Llast",  function(cargs) require("qf-herder._nav").l_last_cmd(cargs) end, { count = 0, desc = "Open the last or [count] loclist item" } },
{ "Lnext",  function(cargs) require("qf-herder._nav").l_next_cmd(cargs) end, { count = 0, desc = "Open the [wrapping count] next loclist item" } },
{ "Lnfile",  function(cargs) require("qf-herder._nav").l_nfile_cmd(cargs) end, { count = 0, desc = "Open the [count] next loclist file" } },
{ "Lpfile",  function(cargs) require("qf-herder._nav").l_pfile_cmd(cargs) end, { count = 0, desc = "Open the [count] prev loclist file" } },
{ "Lprev",  function(cargs) require("qf-herder._nav").l_prev_cmd(cargs) end, { count = 0, desc = "Open the [wrapping count] prev loclist item" } },
{ "Lq",  function(cargs) require("qf-herder._nav").l_l_cmd(cargs) end, { count = 0, desc = "Open the current or [count] loclist item" } },
{ "Lrewind",  function(cargs) require("qf-herder._nav").l_rewind_cmd(cargs) end, { count = 0, desc = "Open the first or [count] loclist item" } },
{ "Qlast",  function(cargs) require("qf-herder._nav").q_last_cmd(cargs) end, { count = 0, desc = "Open the last or [count] quickfix item" } },
{ "Qnext",  function(cargs) require("qf-herder._nav").q_next_cmd(cargs) end, { count = 0, desc = "Open the [wrapping count] next quickfix item" } },
{ "Qnfile",  function(cargs) require("qf-herder._nav").q_nfile_cmd(cargs) end, { count = 0, desc = "Open the [count] next quickfix file" } },
{ "Qpfile",  function(cargs) require("qf-herder._nav").q_pfile_cmd(cargs) end, { count = 0, desc = "Open the [count] prev quickfix file" } },
{ "Qprev",  function(cargs) require("qf-herder._nav").q_prev_cmd(cargs) end, { count = 0, desc = "Open the [wrapping count] prev quickfix item" } },
{ "Qq",  function(cargs) require("qf-herder._nav").q_q_cmd(cargs) end, { count = 0, desc = "Open the current or [count] quickfix item" } },
{ "Qrewind",  function(cargs) require("qf-herder._nav").q_rewind_cmd(cargs) end, { count = 0, desc = "Open the first or [count] quickfix item" } },

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
{ "Lfree",  function(cargs) require("qf-herder._stack").l_free_cmd(cargs) end, { desc = "Free the location list stack" } },

}

for _, cmd in ipairs(M.cmds) do
    api.nvim_create_user_command(cmd[1], cmd[2], cmd[3])
end
