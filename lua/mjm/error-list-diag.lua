--- @class QfRancherDiagnostics
local M = {}

-------------
--- Types ---
-------------

--- @alias QfRancherSeverityType "min"|"only"|"top"

--- @alias QfRancherDiagInfo { level: vim.diagnostic.Severity|nil }
--- @alias QfRancherDiagOpts { sev_type: QfRancherSeverityType }

------------------------
--- HELPER FUNCTIONS ---
------------------------

--- LOW: This and tbl_filter do not feel like the most efficient way to do this

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

--- LOW: I think that, for something that is checked in a hot loop, this is faster than having
--- to re-require it every iteration. Could check for fastest method though
local severity_map = require("mjm.error-list-util")._severity_map ---@type table<integer, string>

---@param d vim.Diagnostic
---@return vim.quickfix.entry
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
        vim.validate("diag_opts.sev_type", diag_opts.sev_type, "string")
        if type(diag_info.level) == "number" then
            local msg = "Diagnostic severity " .. diag_info.level .. " is invalid"
            assert(diag_info.level >= 1 and diag_info.level <= 4, msg)
        end
    end

    local level = diag_info.level or vim.diagnostic.severity.HINT --- @type vim.diagnostic.Severity
    if diag_opts.sev_type == "only" then
        return { severity = level }
    end

    --- @type boolean
    local min_hint = diag_opts.sev_type == "min" and level == vim.diagnostic.severity.HINT
    if min_hint or diag_opts.sev_type == "top" then
        return { severity = nil }
    else
        return { severity = { min = level } }
    end
end

--- @param diag_info QfRancherDiagInfo
--- @param output_opts QfRancherOutputOpts
--- @return nil
local function validate_diags_to_list(diag_info, diag_opts, output_opts)
    vim.validate("diag_info", diag_info, "table")
    vim.validate("diag_info.level", diag_info.level, { "nil", "number" })
    vim.validate("diag_opts", diag_opts, "table")
    vim.validate("diag_opts.sev_type", diag_opts.sev_type, "string")

    require("mjm.error-list-util")._validate_output_opts(output_opts)
end

--- LOW: The title could be more descriptive, but as it it aligns with how titles are constructed
--- by default

--- @param diag_info QfRancherDiagInfo
--- @param diag_opts QfRancherDiagOpts
--- @param output_opts QfRancherOutputOpts
--- @return nil
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
    local buf = output_opts.use_loclist and vim.api.nvim_win_get_buf(cur_win) or nil
    local getopts = get_getopts(diag_info, diag_opts) --- @type vim.diagnostic.GetOpts

    local raw_diags = vim.diagnostic.get(buf, getopts) --- @type vim.Diagnostic[]
    if #raw_diags == 0 then
        vim.api.nvim_echo({ { "No diagnostics", "" } }, false, {})
        return
    end

    if diag_opts.sev_type == "top" then
        raw_diags = filter_diags_top_severity(raw_diags)
    end

    local converted_diags = vim.tbl_map(convert_diag, raw_diags) ---@type vim.quickfix.entry[]
    table.sort(converted_diags, require("mjm.error-list-sort")._sort_fname_diag_asc)

    local et = require("mjm.error-list-tools") --- @type QfRancherTools
    local what = et._create_what_table({
        items = converted_diags,
        title = "vim.diagnostic.get()",
        user_data = { diag_sort = true },
    }) --- @type vim.fn.setqflist.what

    local set_win = output_opts.use_loclist and cur_win or nil --- @type integer|nil
    et._set_list(set_win, output_opts.count, output_opts.action, what)
end

local diag_queries = {
    hint = { level = vim.diagnostic.severity.HINT },
    info = { level = vim.diagnostic.severity.INFO },
    warn = { level = vim.diagnostic.severity.WARN },
    error = { level = vim.diagnostic.severity.ERROR },
    --- TODO: The way top maps are done is inconsistent
    top = { level = nil },
} --- @type table <string, QfRancherDiagInfo>

--- @param name string
--- @param output_opts QfRancherOutputOpts
function M.diags(name, diag_opts, output_opts)
    local diag_info = diag_queries[name] --- @type QfRancherDiagInfo|nil
    if not diag_info then
        vim.api.nvim_echo({ { "No diagnostic query " .. name, "ErrorMsg" } }, true, { err = true })
        return
    end

    diags_to_list(diag_info, diag_opts, output_opts)
end

local sev_types = { "min", "only", "top" } --- @type string[]

--- TODO: I have just this outlined for now because it's simple, but will need to change when
--- the cmd stuff is moved to the util file. Stuff like actions and the loop/check logic can
--- go there, but then the diag specific pieces would hang out here. And the cmd creation itself
--- would go into the maps/plugin file. Want to move over filter/grep/sort first since they are
--- more complicated

local function make_diag_cmd(cargs, is_loclist)
    local fargs = cargs.fargs --- @type string[]

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

    local output_opts = { action = action, use_loclist = is_loclist } --- @type QfRancherOutputOpts

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

function M._q_diag(cargs)
    make_diag_cmd(cargs, false)
end

function M._l_diag(cargs)
    make_diag_cmd(cargs, true)
end

return M

------------
--- TODO ---
------------

--- Deeper auditing/testing
