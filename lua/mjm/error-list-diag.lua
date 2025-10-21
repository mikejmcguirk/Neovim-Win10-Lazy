local ea = Qfr_Defer_Require("mjm.error-list-stack") ---@type QfrStack
local es = Qfr_Defer_Require("mjm.error-list-sort") ---@type QfRancherSort
local et = Qfr_Defer_Require("mjm.error-list-tools") ---@type QfrTools
local eu = Qfr_Defer_Require("mjm.error-list-util") ---@type QfrUtil
local ey = Qfr_Defer_Require("mjm.error-list-types") ---@type QfrTypes

local api = vim.api
local ds = vim.diagnostic.severity

---@mod Diags Sends diags to the qf list

--- @class QfRancherDiagnostics
local Diags = {}

-- ===================
-- == DIAGS TO LIST ==
-- ===================

-- LOW: I assume there is a more performant way to do this

---@param diags vim.Diagnostic[]
---@return vim.Diagnostic[]
local function filter_diags_top_severity(diags)
    -- LOW: Gate a validation of the individual diags behind the debug g:var
    vim.validate("diags", diags, "table")

    local top_severity = ds.HINT ---@type vim.diagnostic.Severity
    for _, diag in ipairs(diags) do
        if diag.severity < top_severity then top_severity = diag.severity end
        if top_severity == ds.ERROR then break end
    end

    return vim.tbl_filter(function(diag)
        return diag.severity == top_severity
    end, diags)
end

-- LOW: Does this actually help/matter?
local severity_map = ey._severity_map ---@type table<integer, string>

-- LOW: Come up with a way to specify a custom conversion function
-- MID: The runtime's add function in get_diagnostics clamps the lnum values to buf_line_count
-- Awkward to add here because the conversion is outlined, and maybe not necessary, but does
-- help with safety for stale diags

---@type QfrDiagDispFunc
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

---@param getopts? vim.diagnostic.GetOpts
---@return string
local function get_empty_msg(getopts)
    ey._validate_diag_getopts(getopts, true)

    local default = "No diagnostics" ---@type string

    if not (getopts and getopts.severity) then return default end

    if type(getopts.severity) == "number" then
        local plural = ey._severity_map_plural[getopts.severity] ---@type string|nil
        if plural then return "No " .. plural end
        return default
    end

    local min = getopts.severity.min ---@type integer|nil
    local max = getopts.severity.max ---@type integer|nil
    if not (min or max) then return default end

    local min_hint = min == ds.HINT ---@type boolean
    local max_error = type(max) == "nil" or max == ds.ERROR ---@type boolean
    if min_hint and max_error then return default end

    local min_txt = min and ey._severity_map_str[min]
    local max_txt = max and ey._severity_map_str[max]
    if not (min_txt or max_txt) then return default end

    local parts = {}
    if min_txt then parts[#parts + 1] = "Min: " .. min_txt end
    if max_txt then parts[#parts + 1] = "max: " .. max_txt end
    local minmax_txt = table.concat(parts, " ,")

    return default .. " (" .. minmax_txt .. ")"
end

---Convert diagnostics into list entries
---
---@param diag_opts QfrDiagOpts
---@param output_opts QfrOutputOpts
---@return nil
function Diags.diags_to_list(diag_opts, output_opts)
    ey._validate_diag_opts(diag_opts)
    ey._validate_output_opts(output_opts)

    local src_win = output_opts.src_win ---@type integer|nil
    if src_win and not eu._valid_win_for_loclist(src_win) then return end

    local title = "Diagnostics" ---@type string
    local buf = src_win and api.nvim_win_get_buf(src_win) or nil ---@type integer|nil
    local raw_diags = vim.diagnostic.get(buf, diag_opts.getopts) ---@type vim.Diagnostic[]
    if #raw_diags == 0 then
        api.nvim_echo({ { get_empty_msg(diag_opts.getopts), "" } }, false, {})

        ---@return boolean
        local function should_clear()
            if not (diag_opts.getopts and diag_opts.getopts.severity) then return true end
            if diag_opts.getopts.severity == { min = ds.INFO } then return true end
            if diag_opts.getopts.severity == { min = nil } then return true end
            return false
        end

        if should_clear() then
            local diag_nr = et._find_list_with_title(src_win, title) ---@type integer|nil
            if diag_nr then eu._clear_list_and_resize(src_win, diag_nr) end
        end

        return
    end

    if diag_opts.top then raw_diags = filter_diags_top_severity(raw_diags) end
    local disp_func = diag_opts.disp_func or convert_diag ---@type QfrDiagDispFunc
    local converted_diags = vim.tbl_map(disp_func, raw_diags) ---@type vim.quickfix.entry[]
    table.sort(converted_diags, es._sort_fname_asc)

    local adj_output_opts = et.handle_new_same_title(output_opts) ---@type QfrOutputOpts
    local what_set = vim.tbl_deep_extend("force", adj_output_opts.what, {
        items = converted_diags,
        title = title,
    }) ---@type QfrWhat

    local dest_nr = et._set_list(src_win, adj_output_opts.action, what_set) ---@type integer
    if eu._get_g_var("qfr_auto_open_changes") and dest_nr > 0 then
        ea._get_history(src_win, dest_nr, {
            open_list = true,
            default = "cur_list",
            silent = true,
        })
    end
end

-- ===============
-- == CMD FUNCS ==
-- ===============

-- LOW: Figure out how to customize diag cmd mappings. Could just do cmd registration, but that
-- would then sit on top of the default cmd structure. Feels more natural to figure out a
-- cmd syntax that allows for arriving at the various combinations of getopts

local level_map = {
    hint = ds.HINT,
    info = ds.INFO,
    warn = ds.WARN,
    error = ds.ERROR,
} ---@type table <string, vim.diagnostic.Severity>

---@param src_win integer|nil
---@param cargs vim.api.keyset.create_user_command.command_args
---@return nil
local function unpack_diag_cmd(src_win, cargs)
    ey._validate_win(src_win, true)

    local fargs = cargs.fargs ---@type string[]

    local top = vim.tbl_contains(fargs, "top") and true or false ---@type boolean

    local getopts = (function()
        if top then return { severity = nil } end

        local levels = vim.tbl_keys(level_map) ---@type string[]
        local level = eu._check_cmd_arg(fargs, levels, "hint") ---@type string
        local severity = level_map[level] ---@type vim.diagnostic.Severity

        if cargs.bang then return { severity = severity } end

        severity = severity == ds.HINT and nil or severity
        return { severity = { min = severity } }
    end)() ---@type vim.diagnostic.GetOpts

    local diag_opts = { top = top, getopts = getopts } ---@type QfrDiagOpts

    ---@type QfrAction
    local action = eu._check_cmd_arg(fargs, ey._actions, ey._default_action)
    ---@type QfrOutputOpts
    local output_opts = { src_win = src_win, action = action, what = { nr = cargs.count } }

    Diags.diags_to_list(diag_opts, output_opts)
end

-- DOCUMENT: Can use these for customizing the diag user cmd. Note how they work here
-- The way you could do it would be, document the cmd syntax here in a general comment, not that
-- the functions below are for mapping it yourself, then let lemmy-help autogen them

---@param cargs vim.api.keyset.create_user_command.command_args
---@return nil
function Diags.q_diag_cmd(cargs)
    unpack_diag_cmd(nil, cargs)
end

---@param cargs vim.api.keyset.create_user_command.command_args
---@return nil
function Diags.l_diag_cmd(cargs)
    unpack_diag_cmd(api.nvim_get_current_win(), cargs)
end

return Diags
---@export Diags

-- TODO: Docs
-- TODO: Add tests

-- MID: Ability to select/map based on namespace
-- MID: Possibly related to the above - query by diagnostic producer(s). Glancing at the built-in
-- code, each LSP has its own namespace. Should be able to make a convenience function to get
-- the namespace from the LSP name
