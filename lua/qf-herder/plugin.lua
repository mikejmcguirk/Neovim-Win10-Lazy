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

local qfr = require("qf-herder")
local config = qfr._config_get()
local cfg_keymap = config.keymap

-- TODO: When cutting off, make as many of the external calls as possible local to this module
-- to reduce requires.

---@param str string
---@return string[]
function split_map(str)
    local result = {}
    local i = 1
    while i <= #str do
        if string.byte(str, i) == 60 then
            local j = str:find(">", i)
            if j then
                table.insert(result, str:sub(i, j))
                i = j + 1
            else
                table.insert(result, str:sub(i, i))
                i = i + 1
            end
        else
            table.insert(result, str:sub(i, i))
            i = i + 1
        end
    end

    return result
end

local prefix_ll = cfg_keymap.prefix_ll
local prefix_qf = cfg_keymap.prefix_qf

local prefix_grep = cfg_keymap.prefix_grep
local key_buf = cfg_keymap.key_buf
local key_buf_re = string.upper(key_buf)
local key_dir = cfg_keymap.key_dir
local key_dir_re = string.upper(key_dir)
local key_help = cfg_keymap.key_help
local key_help_re = string.upper(key_help)

local nmode = { "n" }
local nxmode = { "n", "x" }

local M = {}

-- TODO: Go through the plug map names and make more consistent. You'll have like "filter-ll" then "ll-sort". Sloppy.

-- stylua: ignore
M.maps = {

    -------------------------
    -- MARK: Maps - Window --
    -------------------------

{ nmode, "<Plug>(qf-herder-qf-open)", {}, "", "Open the quickfix list", function() qfr.window.qf_open() end, },
{ nmode, "<Plug>(qf-herder-qf-close)", {}, "", "Close the quickfix list", function() qfr.window.qf_close() end, },
{ nmode, "<Plug>(qf-herder-qf-toggle)", { "<C-q>" }, "", "Toggle the quickfix list", function() qfr.window.qf_toggle() end, },
{ nmode, "<Plug>(qf-herder-qf-resize)", {}, "", "Resize the quickfix list", function() qfr.window.qf_resize() end, },
{ nmode, "<Plug>(qf-herder-ll-open)", {}, "", "Open the location list", function() qfr.window.ll_open() end, },
{ nmode, "<Plug>(qf-herder-ll-close)", {}, "", "Close the location list", function() qfr.window.ll_close() end, },
{ nmode, "<Plug>(qf-herder-ll-toggle)", { "<C-w><C-q>", "<C-w>q" }, "", "Toggle the location list", function() qfr.window.ll_toggle() end, },
{ nmode, "<Plug>(qf-herder-ll-resize)", {}, "", "Resize the location list", function() qfr.window.ll_resize() end, },

    ----------------------
    -- MARK: Maps - Del --
    ----------------------

{ nxmode, "<Plug>(qf-herder-del-operator)", {}, "", "Delete list items linewise over a motion", function() qfr.del.in_qf() end, },
{ nmode, "<Plug>(qf-herder-del-line)", {}, "", "Delete the list item under the cursor", function() qfr.del.in_qf_line() end, },

    ------------------------------
    -- MARK: Maps - Diagnostics --
    ------------------------------

{ nmode, "<Plug>(qf-herder-diag-ll-curbuf-min-err)", {}, "", "Send cur buf errors to the location list", function() qfr.diags.ll_cur_buf_error() end, },
{ nmode, "<Plug>(qf-herder-diag-ll-curbuf-min-hint)", { "grl" }, "", "Send cur buf hints+ to the location list", function() qfr.diags.ll_cur_buf_max_hint() end, },
{ nmode, "<Plug>(qf-herder-diag-ll-curbuf-min-info)", {}, "", "Send cur buf info+ to the location list", function() qfr.diags.ll_cur_buf_max_info() end, },
{ nmode, "<Plug>(qf-herder-diag-ll-curbuf-min-warn)", {}, "", "Send cur buf warnings+ to the location list", function() qfr.diags.ll_cur_buf_max_warn() end, },
{ nmode, "<Plug>(qf-herder-diag-ll-curbuf-top)", { "grL" }, "", "Send cur buf top severity to the location list", function() qfr.diags.ll_cur_buf_top() end, },
{ nmode, "<Plug>(qf-herder-diag-qf-bufs-min-err)", {}, "", "Send all errors to the quickfix list", function() qfr.diags.qf_all_bufs_error() end, },
{ nmode, "<Plug>(qf-herder-diag-qf-bufs-min-hint)", { "grq" }, "", "Send all hints+ to the quickfix list", function() qfr.diags.qf_all_bufs_max_hint() end, },
{ nmode, "<Plug>(qf-herder-diag-qf-bufs-min-info)", {}, "", "Send all info+ to the quickfix list", function() qfr.diags.qf_all_bufs_max_info() end, },
{ nmode, "<Plug>(qf-herder-diag-qf-bufs-min-warn)", {}, "", "Send all warnings+ to the quickfix list", function() qfr.diags.qf_all_bufs_max_warn() end, },
{ nmode, "<Plug>(qf-herder-diag-qf-bufs-top)", { "grQ" }, "", "Send top severity to the quickfix list", function() qfr.diags.qf_all_bufs_top() end, },

    -----------------------
    -- MARK: Maps - Filter --
    -----------------------

{ nmode, "<Plug>(qf-herder-filter-ll-fname-keep)", {}, "", "Keep matching filenames", function() qfr.filter.ll_fname_keep() end, },
{ nmode, "<Plug>(qf-herder-filter-ll-fname-discard)", {}, "", "Discard matching filenames", function() qfr.filter.ll_fname_discard() end, },
{ nmode, "<Plug>(qf-herder-filter-ll-text-keep)", {}, "", "Keep matching filenames", function() qfr.filter.ll_text_keep() end, },
{ nmode, "<Plug>(qf-herder-filter-ll-text-discard)", {}, "", "Discard matching filenames", function() qfr.filter.ll_text_discard() end, },
{ nmode, "<Plug>(qf-herder-filter-qf-fname-keep)", {}, "", "Keep matching filenames", function() qfr.filter.qf_fname_keep() end, },
{ nmode, "<Plug>(qf-herder-filter-qf-fname-discard)", {}, "", "Discard matching filenames", function() qfr.filter.qf_fname_discard() end, },
{ nmode, "<Plug>(qf-herder-filter-qf-text-keep)", {}, "", "Keep matching filenames", function() qfr.filter.qf_text_keep() end, },
{ nmode, "<Plug>(qf-herder-filter-qf-text-discard)", {}, "", "Discard matching filenames", function() qfr.filter.qf_text_discard() end, },

    -----------------------
    -- MARK: Maps - Grep --
    -----------------------

{ nxmode, "<Plug>(qf-herder-rg-ll-bcd-fixed)", { prefix_ll .. prefix_grep .. key_dir }, "", "Ripgrep the bcd to the location list (fixed strings)", function() qfr.rg.ll_bcd_fixed() end, },
{ nxmode, "<Plug>(qf-herder-rg-ll-bcd-regex)", { prefix_ll .. prefix_grep .. key_dir_re }, "", "Ripgrep the bcd to the location list (regex)", function() qfr.rg.ll_bcd_regex() end, },
{ nxmode, "<Plug>(qf-herder-rg-ll-curbuf-fixed)", { prefix_ll .. prefix_grep .. key_buf }, "", "Ripgrep a single buf to the location list (fixed strings)", function() qfr.rg.ll_cur_buf_fixed() end, },
{ nxmode, "<Plug>(qf-herder-rg-ll-curbuf-regex)", { prefix_ll .. prefix_grep .. key_buf_re }, "", "Ripgrep a single buf to the location list (regex)", function() qfr.rg.ll_cur_buf_regex() end, },
{ nxmode, "<Plug>(qf-herder-rg-ll-help-fixed)", { prefix_ll .. prefix_grep .. key_help }, "", "Ripgrep help dirs to the location list (fixed strings)", function() qfr.rg.ll_help_fixed() end, },
{ nxmode, "<Plug>(qf-herder-rg-ll-help-regex)", { prefix_ll .. prefix_grep .. key_help_re }, "", "Ripgrep help dirs to the location list (regex)", function() qfr.rg.ll_help_regex() end, },
{ nxmode, "<Plug>(qf-herder-rg-qf-bufs-fixed)", { prefix_qf .. prefix_grep .. key_buf }, "", "Ripgrep all bufs to the quickfix list (fixed strings)", function() qfr.rg.qf_bufs_fixed() end, },
{ nxmode, "<Plug>(qf-herder-rg-qf-bufs-regex)", { prefix_qf .. prefix_grep .. key_buf_re }, "", "Ripgrep all bufs to the quickfix list (regex)", function() qfr.rg.qf_bufs_regex() end, },
{ nxmode, "<Plug>(qf-herder-rg-qf-tcd-fixed)", { prefix_qf .. prefix_grep .. key_dir }, "", "Ripgrep the tcd to the quickfix list (fixed strings)", function() qfr.rg.qf_tcd_fixed() end, },
{ nxmode, "<Plug>(qf-herder-rg-qf-tcd-regex)", { prefix_qf .. prefix_grep .. key_dir_re }, "", "Ripgrep the tcd to the quickfix list (regex)", function() qfr.rg.qf_tcd_regex() end, },

    ----------------------
    -- MARK: Maps - Nav --
    ----------------------

{ nmode, "<Plug>(qf-herder-ll-rewind)", { "[L" }, "", "Open the first or [count] loclist item", function() qfr.nav.l_rewind() end },
{ nmode, "<Plug>(qf-herder-ll-last)", { "]L" }, "", "Open the last or [count] loclist item", function() qfr.nav.l_last() end },
{ nmode, "<Plug>(qf-herder-ll-prev)", { "[l" } , "", "Open the [wrapping count] prev loclist item", function() qfr.nav.l_prev() end },
{ nmode, "<Plug>(qf-herder-ll-next)", { "]l" } , "", "Open the [wrapping count] next loclist item", function() qfr.nav.l_next() end },
{ nmode, "<Plug>(qf-herder-ll-prev-keep-focus)", {}, "", "Open the [wrapping count] prev loclist item, keep focus", function() qfr.nav.l_prev_keep_focus() end },
{ nmode, "<Plug>(qf-herder-ll-next-keep-focus)", {}, "", "Open the [wrapping count] next loclist item, keep focus", function() qfr.nav.l_next_keep_focus() end },
{ nmode, "<Plug>(qf-herder-ll-pfile)", { "[<C-l>" }, "", "Open the [count] prev loclist file", function() qfr.nav.l_pfile() end },
{ nmode, "<Plug>(qf-herder-ll-nfile)", { "]<C-l>" }, "", "Open the [count] next loclist file", function() qfr.nav.l_nfile() end },

{ nmode, "<Plug>(qf-herder-ll-ll)", {}, "", "Open the current or [count] loclist item", function() qfr.nav.l_l() end },
{ nmode, "<Plug>(qf-herder-ll-ll-keep-focus)", {}, "", "Open the current or [count] loclist item, keep focus", function() qfr.nav.l_l_keep_focus() end },
{ nmode, "<Plug>(qf-herder-ll-vsplit)", {}, "", "Open the focused loclist item in a vsplit", function() qfr.nav.ll_vsplit() end },
{ nmode, "<Plug>(qf-herder-ll-vsplit-keep-focus)", {}, "", "Open the focused loclist item in a vsplit, keeping focus", function() qfr.nav.ll_vsplit_keep_focus() end },

{ nmode, "<Plug>(qf-herder-qf-prev)", { "[q" }, "", "Open the [wrapping count] prev quickfix item", function() qfr.nav.q_prev() end },
{ nmode, "<Plug>(qf-herder-qf-prev-keep-focus)", {}, "", "Open the [wrapping count] prev quickfix item, keep focus", function() qfr.nav.q_prev_keep_focus() end },
{ nmode, "<Plug>(qf-herder-qf-next)", { "]q" }, "", "Open the [wrapping count] next quickfix item", function() qfr.nav.q_next() end },
{ nmode, "<Plug>(qf-herder-qf-next-keep-focus)", {}, "", "Open the [wrapping count] next quickfix item, keep focus", function() qfr.nav.q_next_keep_focus() end },
{ nmode, "<Plug>(qf-herder-qf-rewind)", { "[Q" }, "", "Open the first or [count] quickfix item", function() qfr.nav.q_rewind() end },
{ nmode, "<Plug>(qf-herder-qf-last)", { "]Q" }, "", "Open the last or [count] quickfix item", function() qfr.nav.q_last() end },
{ nmode, "<Plug>(qf-herder-qf-pfile)", { "[<C-q>" }, "", "Open the [count] prev quickfix file", function() qfr.nav.q_pfile() end },
{ nmode, "<Plug>(qf-herder-qf-nfile)", { "]<C-q>" }, "", "Open the [count] next quickfix file", function() qfr.nav.q_nfile() end },

{ nmode, "<Plug>(qf-herder-qf-qq)", {}, "", "Open the current or [count] quickfix item", function() qfr.nav.q_q() end },
{ nmode, "<Plug>(qf-herder-qf-qq-keep-focus)", {}, "", "Open the current or [count] quickfix item, keep focus", function() qfr.nav.q_q_keep_focus() end },
{ nmode, "<Plug>(qf-herder-qf-vsplit)", {}, "", "Open the focused quickfix item in a vsplit", function() qfr.nav.qf_vsplit() end },
{ nmode, "<Plug>(qf-herder-qf-vsplit-keep-focus)", {}, "", "Open the focused quickfix item in a vsplit, keeping focus", function() qfr.nav.qf_vsplit_keep_focus() end },

{ nmode, "<Plug>(qf-herder-split)", {}, "", "Open the focused list item in a split", function() qfr.nav.split() end },
{ nmode, "<Plug>(qf-herder-split-keep-focus)", {}, "", "Open the focused list item in a split, keeping focus", function() qfr.nav.split_keep_focus() end },
{ nmode, "<Plug>(qf-herder-tabnew)", {}, "", "Open the focused list item in a new tab", function() qfr.nav.tabnew() end },
{ nmode, "<Plug>(qf-herder-tabnew-keep-focus)", {}, "", "Open the focused list item in a new tab, keeping focus", function() qfr.nav.tabnew_keep_focus() end },

    --------------------------
    -- MARK: Maps - Preview --
    --------------------------

{ nmode, "<Plug>(qf-herder-preview-open)", {}, "", "Open the preview window", function() qfr.preview.open() end },
{ nmode, "<Plug>(qf-herder-preview-close)", {}, "", "Close the preview window", function() qfr.preview.close() end },
{ nmode, "<Plug>(qf-herder-preview-toggle)", {}, "", "Toggle the preview window", function() qfr.preview.toggle() end },

    -----------------------
    -- MARK: Maps - Sort --
    -----------------------

{ nmode, "<Plug>(qf-herder-qf-sort-fname-asc)", {}, "", "Sort [count] quickfix list by filename asc", function() qfr.sort.qf_fname_asc() end },
{ nmode, "<Plug>(qf-herder-qf-sort-fname-desc)", {}, "", "Sort [count] quickfix list by filename desc", function() qfr.sort.qf_fname_desc() end },
{ nmode, "<Plug>(qf-herder-qf-sort-sev-asc)", {}, "", "Sort [count] quickfix list by sev asc", function() qfr.sort.qf_severity_asc() end },
{ nmode, "<Plug>(qf-herder-qf-sort-sev-desc)", {}, "", "Sort [count] quickfix list by sev desc", function() qfr.sort.qf_severity_desc() end },
{ nmode, "<Plug>(qf-herder-ll-sort-fname-asc)", {}, "", "Sort [count] location list by filename asc", function() qfr.sort.ll_fname_asc() end },
{ nmode, "<Plug>(qf-herder-ll-sort-fname-desc)", {}, "", "Sort [count] location list by filename desc", function() qfr.sort.ll_fname_desc() end },
{ nmode, "<Plug>(qf-herder-ll-sort-sev-asc)", {}, "", "Sort [count] location list by severity asc", function() qfr.sort.ll_severity_asc() end },
{ nmode, "<Plug>(qf-herder-ll-sort-sev-desc)", {}, "", "Sort [count] location list by severity desc", function() qfr.sort.ll_severity_desc() end },

    ------------------------
    -- MARK: Maps - Stack --
    ------------------------

{ nmode, "<Plug>(qf-herder-qf-older)", {}, "", "Go to a [wrapping count] older quickfix list", function() qfr.stack.q_older() end },
{ nmode, "<Plug>(qf-herder-qf-newer)", {}, "", "Go to a [wrapping count] newer quickfix list", function() qfr.stack.q_newer() end },
{ nmode, "<Plug>(qf-herder-qf-history)", {}, "", "Go to the [count] quickfix list or view the entire stack", function() qfr.stack.q_history() end },
{ nmode, "<Plug>(qf-herder-qf-free)", {}, "", "Free the quickfix stack", function() qfr.stack.q_free() end },
{ nmode, "<Plug>(qf-herder-ll-older)", {}, "", "Go to a [wrapping count] older location list", function() qfr.stack.l_older() end },
{ nmode, "<Plug>(qf-herder-ll-newer)", {}, "", "Go to a [wrapping count] newer location list", function() qfr.stack.l_newer() end },
{ nmode, "<Plug>(qf-herder-ll-history)", {}, "", "Go to the [count] location list or view the entire stack", function() qfr.stack.l_history() end },
{ nmode, "<Plug>(qf-herder-ll-free)", {}, "", "Free the location list stack", function() qfr.stack.l_free() end },

}

local plug_opts = { noremap = true }
for _, map in ipairs(M.maps) do
    for _, mode in ipairs(map[1]) do
        plug_opts.desc = map[5]
        plug_opts.callback = map[6]
        api.nvim_set_keymap(mode, map[2], map[4], plug_opts)
    end
end

plug_opts.desc = nil
plug_opts.callback = nil

---@param mode string
---@param lhs string
---@param rhs string
---@return boolean
local function should_map_default(mode, lhs, rhs)
    if vim.call("hasmapto", rhs, mode) == 1 then
        return false
    end

    local maparg_res = vim.call("maparg", lhs, mode) ---@type string
    -- TODO: The defaults string might need a has() check. Might have been changed
    -- after nvim 10
    return maparg_res == "" or string.find(maparg_res, "vim/_core/defaults", 1, true) ~= nil
end

if config.default_keymaps_set then
    for _, map in ipairs(M.maps) do
        plug_opts.desc = map[5]
        for _, lhs in ipairs(map[3]) do
            for _, mode in ipairs(map[1]) do
                local rhs = map[2]
                if should_map_default(mode, lhs, rhs) then
                    api.nvim_set_keymap(mode, lhs, rhs, plug_opts)
                end
            end
        end
    end
end

if not config.default_cmds_set then
    return M
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
{ "Lolder",  function(cargs) require("qf-herder._stack").l_older_cmd(cargs) end, { count = 0, desc = "Go to a [wrapping count] older location list" } },
{ "Lnewer",  function(cargs) require("qf-herder._stack").l_newer_cmd(cargs) end, { count = 0, desc = "Go to a [wrapping count] newer location list" } },
{ "Lhistory",  function(cargs) require("qf-herder._stack").l_history_cmd(cargs) end, { count = 0, desc = "Go to the [count] location list or view the entire stack" } },

}

for _, cmd in ipairs(M.cmds) do
    api.nvim_create_user_command(cmd[1], cmd[2], cmd[3])
end

return M
