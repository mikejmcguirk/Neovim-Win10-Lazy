local api = vim.api
local ds = vim.diagnostic.severity

local herder = require("qf-herder")
local ntt = require("nvim-tools.table")
local ntq = require("nvim-tools.quickfix")

local M = {}

local severity_map = {
    [ds.ERROR] = "E",
    [ds.WARN] = "W",
    [ds.INFO] = "I",
    [ds.HINT] = "H",
}

---@param diag vim.Diagnostic
---@return vim.quickfix.entry
local function convert_diag(diag)
    local diag_source = diag.source
    local code = diag.code
    local end_lnum = diag.end_lnum
    local col = diag.col
    local end_col = diag.end_col

    return {
        bufnr = diag.bufnr,
        col = col and (col + 1) or nil,
        end_col = end_col and (end_col + 1) or nil,
        end_lnum = end_lnum and (end_lnum + 1) or nil,
        lnum = diag.lnum + 1,
        ---@diagnostic disable-next-line: assign-type-mismatch
        nr = code ~= nil and tonumber(code) or nil,
        text = (diag_source and (diag_source .. ": ") or "") .. (diag.message or ""),
        type = severity_map[diag.severity] or "E",
        ---@diagnostic disable-next-line: assign-type-mismatch
        valid = 1,
    }
end
-- PR: Valid in getqflist() shows as 1 or 0, but the annotation here wants a boolean. Two
-- action items:
-- - Is boolean true acceptable here?
-- - Send a PR to include 0|1 in the typedef for entry

local severity_plural = {
    [ds.ERROR] = "errors",
    [ds.WARN] = "warnings",
    [ds.INFO] = "info",
    [ds.HINT] = "hints",
}

local severity_str = {
    [ds.ERROR] = "ERROR",
    [ds.WARN] = "WARN",
    [ds.INFO] = "INFO",
    [ds.HINT] = "HINT",
}

---@param getopts vim.diagnostic.GetOpts
---@return string
local function get_empty_msg(getopts)
    local default = "No diagnostics"
    local sev = getopts.severity
    if sev == nil then
        return default
    end

    if type(sev) == "number" then
        local plural = severity_plural[sev]
        return plural and ("No " .. plural) or default
    elseif type(sev) ~= "table" then
        return default
    end

    local min = sev.min or ds.HINT
    local max = sev.max or ds.ERROR
    if min == ds.HINT and max == ds.ERROR then
        return default
    end

    local parts = {}
    parts[#parts + 1] = "Min: " .. (severity_str[min] or tostring(min))
    parts[#parts + 1] = "Max: " .. (severity_str[max] or tostring(max))
    return default .. " (" .. table.concat(parts, ", ") .. ")"
end

---@class qf-herder.diag.Cfg
---@field clear_on_empty boolean
---@field open_results boolean
---@field reuse_title boolean
---@field title string

---@param src_win integer|nil   -- nil = qflist, otherwise location-list window
---@param get_opts vim.diagnostic.GetOpts
---@param f fun(a: vim.quickfix.entry, b: vim.quickfix.entry): boolean
---@param cfg qf-herder.diag.Cfg
function M.diags_to_list(src_win, get_opts, f, cfg)
    local buf = src_win ~= nil and api.nvim_win_get_buf(src_win) or nil
    local diags = vim.diagnostic.get(buf, get_opts)
    local reuse_title = cfg.reuse_title
    local title = cfg.title

    if #diags == 0 then
        api.nvim_echo({ { get_empty_msg(get_opts), "" } }, false, {})
        if reuse_title and cfg.clear_on_empty then
            local diag_nr = ntq.find_list_with_title(src_win, title)
            if diag_nr then
                ntq.clear_list(src_win, diag_nr)
            end
        end

        return
    end

    local items = ntt.i_filter_map_to(diags, convert_diag)
    table.sort(items, f)
    local _util = require("qf-herder._util")
    local action, set_nr = _util.set_nr_resolve(reuse_title, src_win, title)
    local what = { items = items, nr = set_nr, title = title }

    local dest_nr = ntq.set_list_checked(src_win, action, what)
    if dest_nr < 0 then
        api.nvim_echo({ { "Unable to set list", "ErrorMsg" } }, true, {})
        return
    end

    local _, _, stack_cfg = herder._config_merged_from_win(src_win or 0, "stack")
    require("qf-herder._stack")._history(src_win, true, dest_nr, stack_cfg)
    if cfg.open_results then
        local _, _, win_cfg = herder._config_merged_from_win(src_win or 0, "window")
        win_cfg.silent = true
        require("qf-herder._window").list_open(src_win, 0, win_cfg)
    end
end

return M
