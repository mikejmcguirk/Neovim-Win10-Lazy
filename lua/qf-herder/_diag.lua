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
    local source = diag.source and (diag.source .. ": ") or ""
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
        text = source .. (diag.message or ""),
        type = severity_map[diag.severity] or "E",
        valid = true, -- TODO: I had this as 1 in the old code. Was that correct?
    }
end

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

---@param reuse_title boolean
---@param src_win uinteger?
---@param title string
---@return ("a"|"f"|"r"|"u"|" "), uinteger
local function set_nr_resolve(reuse_title, src_win, title)
    if not reuse_title then
        return " ", ntq.get_list(src_win, { nr = "$" })
    end

    local diag_nr = ntq._find_list_with_title(src_win, title)
    if diag_nr then
        return "u", diag_nr
    else
        return " ", ntq.get_list(src_win, { nr = "$" })
    end
end
-- TODO: Outline this logic for Grep as well.

---@param getopts? vim.diagnostic.GetOpts
---@return string
local function get_empty_msg(getopts)
    local default = "No diagnostics"
    if not (getopts and getopts.severity) then
        return default
    end

    local sev = getopts.severity

    if type(sev) == "number" then
        local plural = severity_plural[sev]
        return plural and ("No " .. plural) or default
    end

    if type(sev) == "table" then
        local min, max = sev.min, sev.max
        if not (min or max) then
            return default
        end

        if (min == nil or min == ds.HINT) and (max == nil or max == ds.ERROR) then
            return default
        end

        local parts = {}
        if min then
            parts[#parts + 1] = "Min: " .. (severity_str[min] or tostring(min))
        end

        if max then
            parts[#parts + 1] = "Max: " .. (severity_str[max] or tostring(max))
        end

        return default .. " (" .. table.concat(parts, ", ") .. ")"
    end

    return default
end

---@class qf-herder.diag.Cfg
---@field clear_on_empty boolean
---@field open_results boolean
---@field reuse_title boolean
---@field title string

---@param src_win integer|nil   -- nil = qflist, otherwise location-list window
---@param diag_get_opts vim.diagnostic.GetOpts
---@param f fun(a: vim.quickfix.entry, b: vim.quickfix.entry): boolean
---@param cfg qf-herder.diag.Cfg
function M.diags_to_list(src_win, diag_get_opts, f, cfg)
    local buf = src_win and api.nvim_win_get_buf(src_win) or nil
    local diags = vim.diagnostic.get(buf, diag_get_opts)
    local title = cfg.title
    local reuse_title = cfg.reuse_title

    if #diags == 0 then
        api.nvim_echo({ { get_empty_msg(diag_get_opts), "" } }, false, {})
        if not (reuse_title and cfg.clear_on_empty) then
            return
        end

        local diag_nr = ntq._find_list_with_title(src_win, title)
        if diag_nr then
            ntq.clear_list(src_win, diag_nr)
        end

        return
    end

    local items = ntt.i_filter_map_to(diags, convert_diag)
    table.sort(items, f)
    local action, set_nr = set_nr_resolve(reuse_title, src_win, title)
    local what = {
        items = items,
        nr = set_nr,
        title = title,
    }

    local dest_nr = ntq.set_list_checked(src_win, action, what)
    if dest_nr < 0 then
        api.nvim_echo({ { "Unable to set list", "ErrorMsg" } }, true, {})
        return
    end

    local _, _, ok, stack_cfg, err = herder._config_merged_from_win(src_win or 0, "stack")
    if not ok then
        api.nvim_echo({ { err, "ErrorMsg" } }, true, {})
        return
    end

    require("qf-herder._stack")._history(src_win, true, dest_nr, stack_cfg)
    if cfg.open_results then
        local _, _, ok_w, win_cfg, err_w = herder._config_merged_from_win(src_win or 0, "window")
        if not ok_w then
            api.nvim_echo({ { err_w, "ErrorMsg" } }, true, {})
            return
        end

        win_cfg.silent = true
        require("qf-herder._window").list_open(src_win, 0, win_cfg)
    end
end

return M

-- TODO: re-check the old code to make sure nothing was missed
