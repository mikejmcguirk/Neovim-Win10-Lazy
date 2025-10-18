---@mod Diags Sends diags to the qf list

--- @class QfRancherDiagnostics
local Diags = {}

local ea = Qfr_Defer_Require("mjm.error-list-stack") ---@type QfrStack
local es = Qfr_Defer_Require("mjm.error-list-sort") ---@type QfRancherSort
local et = Qfr_Defer_Require("mjm.error-list-tools") ---@type QfrTools
local eu = Qfr_Defer_Require("mjm.error-list-util") ---@type QfrUtil
local ey = Qfr_Defer_Require("mjm.error-list-types") ---@type QfrTypes

local api = vim.api
local ds = vim.diagnostic.severity

-- ======================
-- == HELPER FUNCTIONS ==
-- ======================

-- LOW: This and tbl_filter do not feel like the most efficient way to do this

---@param diags vim.Diagnostic[]
---@return vim.Diagnostic[]
local function filter_diags_top_severity(diags)
    local top_severity = ds.HINT ---@type vim.diagnostic.Severity
    for _, diag in ipairs(diags) do
        if diag.severity < top_severity then top_severity = diag.severity end
    end

    return vim.tbl_filter(function(diag)
        return diag.severity == top_severity
    end, diags)
end

-- LOW: Does this actually help/matter?
local severity_map = ey._severity_map ---@type table<integer, string>

-- LOW: Come up with a way to specify a custom conversion function

---@param d vim.Diagnostic
---@return vim.quickfix.entry
---NOTE: Hot loop. No validation
local function convert_diag(d)
    local source = d.source and d.source .. ": " or "" ---@type string

    return {
        bufnr = d.bufnr,
        col = d.col and (d.col + 1) or nil,
        end_col = d.end_col and (d.end_col + 1) or nil,
        end_lnum = d.end_lnum and (d.end_lnum + 1) or nil,
        lnum = d.lnum + 1,
        nr = tonumber(d.code),
        text = source .. (d.message or ""),
        type = severity_map[d.severity] or "E",
        valid = 1,
    }
end

-- ===================
-- == DIAGS TO LIST ==
-- ===================

---Convert diagnostics into list entries
---
---@param diag_opts QfrDiagOpts Options dict:
---- filter: (string) "min", "only", or "top" severity
---- level: vim.diagnostic.Severity
---@param what QfrWhat
---@return nil
function Diags.diags_to_list(diag_opts, what)
    ey._validate_diag_opts(diag_opts)
    ey._validate_what(what)

    local src_win = what.user_data.src_win ---@type integer
    if src_win and not eu._valid_win_for_loclist(src_win) then return end

    local buf = src_win and api.nvim_win_get_buf(src_win) or nil ---@type integer|nil
    local getopts = (function()
        local level = diag_opts.level or ds.HINT ---@type vim.diagnostic.Severity
        if diag_opts.filter == "only" then return { severity = level } end

        local min_hint = diag_opts.filter == "min" and level == ds.HINT
        if min_hint or diag_opts.filter == "top" then return { severity = nil } end

        return { severity = { min = level } }
    end)()

    local raw_diags = vim.diagnostic.get(buf, getopts) ---@type vim.Diagnostic[]
    local plural = ey._plural_severity_map[diag_opts.level] or "diagnostics" ---@type string
    if #raw_diags == 0 then
        api.nvim_echo({ { "No " .. plural, "" } }, false, {})
        return
    end

    if diag_opts.filter == "top" then raw_diags = filter_diags_top_severity(raw_diags) end
    local converted_diags = vim.tbl_map(convert_diag, raw_diags) ---@type vim.quickfix.entry[]

    local what_set = vim.tbl_deep_extend("force", what, {
        items = converted_diags,
        title = "vim.diagnostic.get() " .. diag_opts.filter .. " " .. plural,
        user_data = { sort_func = es._sort_fname_diag_asc },
    }) ---@type QfrWhat

    local dest_nr = et._set_list(src_win, what_set) ---@type integer
    if eu._get_g_var("qf_rancher_auto_open_changes") and dest_nr > 0 then
        ea._history(src_win, dest_nr, {
            always_open = true,
            default = "current",
            silent = true,
        })
    end
end

-- ===============
-- == CMD FUNCS ==
-- ===============

-- DOCUMENT: How these work for making your own custom cmd maps

local level_map = {
    hint = ds.HINT,
    info = ds.INFO,
    warn = ds.WARN,
    error = ds.ERROR,
    top = nil,
} ---@type table <string, vim.diagnostic.Severity>

---@param src_win integer|nil
---@param cargs vim.api.keyset.create_user_command.command_args
---@return nil
local function make_diag_cmd(src_win, cargs)
    ey._validate_win(src_win, true)

    local fargs = cargs.fargs ---@type string[]

    local levels = vim.tbl_keys(level_map) ---@type string[]
    local level = eu._check_cmd_arg(fargs, levels, "hint") ---@type string
    local sev_filter = eu._check_cmd_arg(fargs, ey._sev_filters, "min") ---@type string

    local diag_opts = { level = level_map[level], filter = sev_filter } ---@type QfrDiagOpts

    local action = eu._check_cmd_arg(fargs, ey._actions, ey._default_action) ---@type QfrAction
    ---@type QfrWhat
    local what = { nr = cargs.count, user_data = { action = action, src_win = src_win } }

    Diags.diags_to_list(diag_opts, what)
end

---@param cargs vim.api.keyset.create_user_command.command_args
---@return nil
function Diags.q_diag_cmd(cargs)
    make_diag_cmd(nil, cargs)
end

---@param cargs vim.api.keyset.create_user_command.command_args
---@return nil
function Diags.l_diag_cmd(cargs)
    make_diag_cmd(api.nvim_get_current_win(), cargs)
end

return Diags
---@export Diags

-- TODO: Docs
-- TODO: Add tests
