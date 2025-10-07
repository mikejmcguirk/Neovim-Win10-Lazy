--- @class QfRancherDiagnostics
local M = {}

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
--- @param what QfRancherWhat
--- @return nil
local function validate_diags_to_list(diag_info, diag_opts, what)
    diag_info = diag_info or {}
    diag_opts = diag_opts or {}
    what = what or {}

    local ey = require("mjm.error-list-types")
    ey._validate_diag_info(diag_info)
    ey._validate_diag_opts(diag_opts)
    require("mjm.error-list-types")._validate_what(what)
end

--- LOW: The title could be more descriptive, but as iT it aligns with how titles are constructed
--- by default

--- @param diag_info QfRancherDiagInfo
--- @param diag_opts QfRancherDiagOpts
--- @param what QfRancherWhat
--- @return nil
local function diags_to_list(diag_info, diag_opts, what)
    validate_diags_to_list(diag_info, diag_opts, what)

    local src_win = what.user_data.src_win
    local eu = require("mjm.error-list-util") --- @type QfRancherUtils
    if what.user_data.src_win and not eu._win_can_have_loclist(what.user_data.src_win) then
        local msg = "Win " .. src_win .. " cannot have a location list"
        vim.api.nvim_echo({ { msg, "" } }, false, {})
        return
    end

    --- @type integer|nil
    ---@diagnostic disable-next-line: undefined-field
    local buf = src_win and vim.api.nvim_win_get_buf(src_win) or nil
    local getopts = get_getopts(diag_info, diag_opts) --- @type vim.diagnostic.GetOpts

    local raw_diags = vim.diagnostic.get(buf, getopts) --- @type vim.Diagnostic[]
    if #raw_diags == 0 then
        --- LOW: Could be more specific
        vim.api.nvim_echo({ { "No diagnostics", "" } }, false, {})
        return
    end

    if diag_opts.sev_type == "top" then
        raw_diags = filter_diags_top_severity(raw_diags)
    end

    local converted_diags = vim.tbl_map(convert_diag, raw_diags) ---@type vim.quickfix.entry[]
    table.sort(converted_diags, require("mjm.error-list-sort")._sort_fname_diag_asc)

    local et = require("mjm.error-list-tools") --- @type QfRancherTools
    local what_set = vim.tbl_deep_extend("force", what, {
        items = converted_diags,
        title = "vim.diagnostic.get()",
        user_data = { sort_func = require("mjm.error-list-sort")._sort_fname_diag_asc },
    }) --- @type QfRancherWhat

    local dest_nr = et._set_list(what_set) --- @type integer
    if vim.g.qf_rancher_auto_open_changes and dest_nr > 0 then
        require("mjm.error-list-stack")._history(src_win, dest_nr, {
            silent = true,
            always_open = true,
        })
    end
end

--- LOW: The top map is bad because you have to set it here and then with the diag opts to make
--- top severity happen. Either the naming should be more clear or the architecture should be
--- changed somehow

local diag_queries = {
    hint = { level = vim.diagnostic.severity.HINT },
    info = { level = vim.diagnostic.severity.INFO },
    warn = { level = vim.diagnostic.severity.WARN },
    error = { level = vim.diagnostic.severity.ERROR },
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

--- @param src_win? integer
--- @param cargs vim.api.keyset.create_user_command.command_args
--- @return nil
local function make_diag_cmd(src_win, cargs)
    require("mjm.error-list-types")._validate_win(src_win, true)
    local fargs = cargs.fargs --- @type string[]

    local eu = require("mjm.error-list-util")
    local names = vim.tbl_keys(diag_queries) --- @type string[]
    local name = eu._check_cmd_arg(fargs, names, "hint")
    local diag_info = diag_queries[name] --- @type QfRancherDiagInfo
    if not diag_info then
        vim.api.nvim_echo({ { "No diagnostic query " .. name, "ErrorMsg" } }, true, { err = true })
        return
    end

    local ey = require("mjm.error-list-types") --- @type QfRancherTypes
    local sev_type = eu._check_cmd_arg(fargs, ey._sev_types, "min")
    local diag_opts = { sev_type = sev_type } --- @type QfRancherDiagOpts

    --- @type QfRancherAction
    local action = eu._check_cmd_arg(fargs, ey._actions, ey._default_action)
    --- @type QfRancherWhat
    local what = { nr = cargs.count, user_data = { action = action, src_win = src_win } }

    diags_to_list(diag_info, diag_opts, what)
end

function M._q_diag(cargs)
    make_diag_cmd(nil, cargs)
end

function M._l_diag(cargs)
    make_diag_cmd(vim.api.nvim_get_current_win(), cargs)
end

return M

------------
--- TODO ---
------------

--- Deeper auditing/testing

-----------
--- LOW ---
-----------

--- Add extensibility to this module
