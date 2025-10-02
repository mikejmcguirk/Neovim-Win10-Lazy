--- @class QfRancherDiagnostics
local M = {}

-------------
--- Types ---
-------------

--- @alias QfRancherSeverityType "min"|"only"|"top"
--- @alias QfRancherDiagInfo {sev_type: QfRancherSeverityType, level: vim.diagnostic.Severity}

--- @param diags vim.Diagnostic[]
--- @return integer
local function get_top_severity(diags)
    local severity = vim.diagnostic.severity.HINT --- @type vim.diagnostic.Severity
    for _, diag in pairs(diags) do
        if diag.severity < severity then
            severity = diag.severity
        end
    end

    return severity
end

--- @param diags vim.Diagnostic[]
--- @return vim.Diagnostic[]
local function filter_diags_top_severity(diags)
    local top_severity = get_top_severity(diags) --- @type vim.diagnostic.Severity
    return vim.tbl_filter(function(diag)
        return diag.severity == top_severity
    end, diags)
end

local severity_map = require("mjm.error-list-util")._severity_map ---@type table<integer, string>

---@param d vim.Diagnostic
---@return table
local function convert_diag(d)
    d = d or {}

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

--- @param diag_info QfRancherDiagInfo
--- @return vim.diagnostic.GetOpts
local function get_diagnostic_opt(diag_info)
    if vim.g.qf_rancher_debug_assertions then
        vim.validate("diag_info", diag_info, "table")
        vim.validate("diag_info.sev_type", diag_info.sev_type, { "nil", "string" })
        vim.validate("diag_info.level", diag_info.level, { "nil", "number" })
        if type(diag_info.level) == "number" then
            local msg = "Diagnostic severity " .. diag_info.level .. " is invalid"
            assert(diag_info.level >= 1 and diag_info.level <= 4, msg)
        end
    end

    local type = diag_info.sev_type or "min" --- @type QfRancherSeverityType
    local level = diag_info.level or vim.diagnostic.severity.HINT --- @type vim.diagnostic.Severity
    if type == "only" then
        return { severity = level }
    end

    local min_hint = type == "min" and level == vim.diagnostic.severity.HINT --- @type boolean
    if min_hint or type == "top" then
        return { severity = nil }
    else
        return { severity = { min = level } }
    end
end

local function validate_diags_to_list(diag_info, output_opts)
    vim.validate("diag_info", diag_info, "table")
    vim.validate("diag_info.sev_type", diag_info.sev_type, { "nil", "string" })
    vim.validate("diag_info.level", diag_info.level, { "nil", "number" })

    local eu = require("mjm.error-list-util")
    eu.validate_output_opts(output_opts)
end

--- @param diag_info QfRancherDiagInfo
--- @param output_opts QfRancherOutputOpts
local function diags_to_list(diag_info, output_opts)
    diag_info = diag_info or {}
    output_opts = output_opts or {}
    validate_diags_to_list(diag_info, output_opts)

    local cur_win = vim.api.nvim_get_current_win() --- @type integer
    output_opts.loclist_source_win = cur_win
    local eu = require("mjm.error-list-util") --- @type QfRancherUtils
    if not eu._is_loclist_output_valid(output_opts) then
        return
    end

    local getlist = eu._get_getlist(output_opts) --- @type function|nil
    if not getlist then
        return
    end

    local setlist = eu._get_setlist(output_opts) --- @type function|nil
    if not setlist then
        return
    end

    --- @type integer|nil
    local buf = output_opts.is_loclist and vim.api.nvim_win_get_buf(cur_win) or nil
    local get_opts = get_diagnostic_opt(diag_info) --- @type vim.diagnostic.GetOpts

    local raw_diags = vim.diagnostic.get(buf, get_opts) --- @type vim.Diagnostic[]
    if #raw_diags == 0 then
        vim.api.nvim_echo({ { "No diagnostics", "" } }, false, {})
        return
    end

    if diag_info.sev_type == "top" then
        raw_diags = filter_diags_top_severity(raw_diags)
    end

    local converted_diags = vim.tbl_map(convert_diag, raw_diags) ---@type table[]
    table.sort(converted_diags, require("mjm.error-list-sort")._sort_fname_diag_asc)
    --- @type QfRancherSetOpts
    local set_opts = { getlist = getlist, setlist = setlist, new_items = converted_diags }
    output_opts.title = "vim.diagnostic.get()"
    eu.set_list_items(set_opts, output_opts)
end

--- TODO: Cmd Naming conventions:
--- - Qdiag
--- - Qdiagadd
--- - Qdiagreplace (?)
--- - Qdiag top (top severity)
--- - Qdiag info (min severity info)
--- - Qdiag info only (only show info)

local diag_queries = {
    hint = { sev_type = "min", level = vim.diagnostic.severity.HINT },
    info = { sev_type = "min", level = vim.diagnostic.severity.INFO },
    warn = { sev_type = "min", level = vim.diagnostic.severity.WARN },
    error = { sev_type = "min", level = vim.diagnostic.severity.ERROR },
    hint_only = { sev_type = "only", level = vim.diagnostic.severity.HINT },
    info_only = { sev_type = "only", level = vim.diagnostic.severity.INFO },
    warn_only = { sev_type = "only", level = vim.diagnostic.severity.WARN },
    error_only = { sev_type = "only", level = vim.diagnostic.severity.ERROR },
    top = { sev_type = "top", level = nil },
} --- @type table <string, QfRancherDiagInfo>

function M.diags(name, output_opts)
    local diag_info = diag_queries[name]
    if not diag_info then
        vim.api.nvim_echo({ { "No diagnostic query " .. name, "ErrorMsg" } }, true, { err = true })
    end

    diags_to_list(diag_info, output_opts)
end

return M
