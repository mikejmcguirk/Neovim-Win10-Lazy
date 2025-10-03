--- @class QfRancherDiagnostics
local M = {}

-------------
--- Types ---
-------------

--- @alias QfRancherSeverityType "min"|"only"|"top"

--- @alias QfRancherDiagInfo { level: vim.diagnostic.Severity}
--- @alias QfRancherDiagOpts { sev_type: QfRancherSeverityType}

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
--- @param diag_opts QfRancherDiagOpts
--- @return vim.diagnostic.GetOpts
local function get_getopts(diag_info, diag_opts)
    if vim.g.qf_rancher_debug_assertions then
        vim.validate("diag_info", diag_info, "table")
        vim.validate("diag_info.level", diag_info.level, { "nil", "number" })
        vim.validate("diag_opts", diag_opts, "table")
        vim.validate("diag_opts.sev_type", diag_opts.sev_type, { "nil", "string" })
        if type(diag_info.level) == "number" then
            local msg = "Diagnostic severity " .. diag_info.level .. " is invalid"
            assert(diag_info.level >= 1 and diag_info.level <= 4, msg)
        end
    end

    local level = diag_info.level or vim.diagnostic.severity.HINT --- @type vim.diagnostic.Severity
    local type = diag_opts.sev_type or "min" --- @type QfRancherSeverityType
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

--- @param diag_info QfRancherDiagInfo
--- @param output_opts QfRancherOutputOpts
local function validate_diags_to_list(diag_info, diag_opts, output_opts)
    vim.validate("diag_info", diag_info, "table")
    vim.validate("diag_info.level", diag_info.level, { "nil", "number" })
    vim.validate("diag_opts", diag_opts, "table")
    vim.validate("diag_opts.sev_type", diag_opts.sev_type, { "nil", "string" })

    local eu = require("mjm.error-list-util") --- @type QfRancherUtils
    eu.validate_output_opts(output_opts)
end

--- @param diag_info QfRancherDiagInfo
--- @param diag_opts QfRancherDiagOpts
--- @param output_opts QfRancherOutputOpts
local function diags_to_list(diag_info, diag_opts, output_opts)
    diag_info = diag_info or {}
    diag_opts = diag_opts or {}
    output_opts = output_opts or {}
    validate_diags_to_list(diag_info, diag_opts, output_opts)

    local cur_win = vim.api.nvim_get_current_win() --- @type integer
    output_opts.loclist_source_win = cur_win
    local eu = require("mjm.error-list-util") --- @type QfRancherUtils
    if not eu._is_valid_loclist_output(output_opts) then
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
    local getopts = get_getopts(diag_info, diag_opts) --- @type vim.diagnostic.GetOpts

    local raw_diags = vim.diagnostic.get(buf, getopts) --- @type vim.Diagnostic[]
    if #raw_diags == 0 then
        vim.api.nvim_echo({ { "No diagnostics", "" } }, false, {})
        return
    end

    if diag_opts.sev_type == "top" then
        raw_diags = filter_diags_top_severity(raw_diags)
    end

    local converted_diags = vim.tbl_map(convert_diag, raw_diags) ---@type table[]
    table.sort(converted_diags, require("mjm.error-list-sort")._sort_fname_diag_asc)
    --- @type QfRancherSetOpts
    local set_opts = { getlist = getlist, setlist = setlist, new_items = converted_diags }
    output_opts.title = "vim.diagnostic.get()"
    --- TODO: This is sending to the list but not opening
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
    hint = { level = vim.diagnostic.severity.HINT },
    info = { level = vim.diagnostic.severity.INFO },
    warn = { level = vim.diagnostic.severity.WARN },
    error = { level = vim.diagnostic.severity.ERROR },
} --- @type table <string, QfRancherDiagInfo>

--- @param name string
--- @param output_opts QfRancherOutputOpts
function M.diags(name, diag_opts, output_opts)
    local diag_info = diag_queries[name]
    if not diag_info then
        vim.api.nvim_echo({ { "No diagnostic query " .. name, "ErrorMsg" } }, true, { err = true })
    end

    diags_to_list(diag_info, diag_opts, output_opts)
end

local sev_types = { "min", "only", "top" }

--- TODO: I have just this outline for now because it's simple, but will need to change when
--- the cmd stuff is moved to the util file. Stuff like actions and the loop/check logic can
--- go there, but then the diag specific pieces would hang out here. And the cmd creation itself
--- would go into the maps/plugin file

local function make_diag_cmd(cargs, is_loclist)
    local fargs = cargs.fargs

    local sev_type = "min"
    for _, arg in ipairs(fargs) do
        if vim.tbl_contains(sev_types, arg) then
            sev_type = arg
            break
        end
    end

    local diag_opts = { sev_type = sev_type } --- @type QfRancherDiagOpts

    local actions = { "new", "replace", "add" } --- @type QfRancherAction[]

    local action = "new" --- @type QfRancherAction
    for _, arg in ipairs(fargs) do
        if vim.tbl_contains(actions, arg) then
            action = arg
            break
        end
    end

    local output_opts = { action = action, is_loclist = is_loclist } --- @type QfRancherOutputOpts

    local name = "hint" --- @type string
    local names = vim.tbl_keys(diag_queries) --- @type string[]

    for _, arg in ipairs(fargs) do
        if vim.tbl_contains(names, arg) then
            name = arg
            break
        end
    end

    local diag_info = diag_queries[name] --- @type QfRancherDiagInfo
    if not diag_info then
        vim.api.nvim_echo({ { "No diagnostic query " .. name, "ErrorMsg" } }, true, { err = true })
        return
    end

    diags_to_list(diag_info, diag_opts, output_opts)
end

--- TODO: This is.... okay function naming because it's accurate, but then you have l_history and
--- q_history which are maps so it feels inconsistent

function M._q_diag(cargs)
    make_diag_cmd(cargs, false)
end

function M._l_diag(cargs)
    make_diag_cmd(cargs, true)
end

vim.api.nvim_create_user_command("Qdiag", function(cargs)
    M._q_diag(cargs)
end, { nargs = "*", desc = "Query diagnostics into the Quickfix list" })

vim.api.nvim_create_user_command("Ldiag", function(cargs)
    M._l_diag(cargs)
end, { nargs = "*", desc = "Query diagnostics into the Location list" })

return M
