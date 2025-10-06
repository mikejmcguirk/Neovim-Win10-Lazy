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
--- @param diag_opts QfRancherDiagOpts
--- @param what vim.fn.setqflist.what
--- @return nil
local function validate_diags_to_list(diag_info, diag_opts, what)
    vim.validate("diag_info", diag_info, "table")
    vim.validate("diag_info.level", diag_info.level, { "nil", "number" })
    vim.validate("diag_opts", diag_opts, "table")
    vim.validate("diag_opts.sev_type", diag_opts.sev_type, "string")

    require("mjm.error-list-validation")._validate_what(what)
end

--- LOW: The title could be more descriptive, but as it it aligns with how titles are constructed
--- by default

--- @param diag_info QfRancherDiagInfo
--- @param diag_opts QfRancherDiagOpts
--- @param what QfRancherWhat
--- @return nil
local function diags_to_list(diag_info, diag_opts, what)
    diag_info = diag_info or {}
    diag_opts = diag_opts or {}
    what = what or {}
    validate_diags_to_list(diag_info, diag_opts, what)

    local cur_win = vim.api.nvim_get_current_win() --- @type integer
    local eu = require("mjm.error-list-util") --- @type QfRancherUtils
    if not eu._win_can_have_loclist(what.user_data.list_win) then
        return
    end

    --- @type integer|nil
    ---@diagnostic disable-next-line: undefined-field
    local buf = what.list_win and vim.api.nvim_win_get_buf(cur_win) or nil
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

    local set_win = what.use_loclist and cur_win or nil --- @type integer|nil
    et._set_list(set_win, what.count, what.action, what)
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
--- @param diag_opts QfRancherDiagOpts
--- @param what QfRancherWhat
function M.diags(name, diag_opts, what)
    local diag_info = diag_queries[name] --- @type QfRancherDiagInfo|nil
    if not diag_info then
        vim.api.nvim_echo({ { "No diagnostic query " .. name, "ErrorMsg" } }, true, { err = true })
        return
    end

    diags_to_list(diag_info, diag_opts, what)
end

local sev_types = { "min", "only", "top" } --- @type string[]

--- TODO: I have just this outlined for now because it's simple, but will need to change when
--- the cmd stuff is moved to the util file. Stuff like actions and the loop/check logic can
--- go there, but then the diag specific pieces would hang out here. And the cmd creation itself
--- would go into the maps/plugin file. Want to move over filter/grep/sort first since they are
--- more complicated

--- @param cargs vim.api.keyset.create_user_command.command_args
--- @param list_win? integer
--- @return nil
local function make_diag_cmd(cargs, list_win)
    require("mjm.error-list-validation")._validate_win(list_win, true)

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

    local what = { user_data = { action = action, list_win = list_win } } --- @type QfRancherWhat

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

    diags_to_list(diag_info, diag_opts, what)
end

function M._q_diag(cargs)
    make_diag_cmd(cargs, nil)
end

function M._l_diag(cargs)
    make_diag_cmd(cargs, vim.api.nvim_get_current_win())
end

return M

------------
--- TODO ---
------------

--- Deeper auditing/testing
