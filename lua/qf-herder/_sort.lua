local api = vim.api

local ntq = require("nvim-tools.quickfix")

local M = {}

---@param src_win uinteger|nil
---@param count uinteger
---@param f fun(a:vim.quickfix.entry, b:vim.quickfix.entry): boolean
---@param cfg qf-herder.sort.Cfg
function M.sort(src_win, count, f, cfg)
    if src_win ~= nil then
        local qf_id = vim.call("getloclist", src_win, { id = 0 }).id ---@type uinteger
        if qf_id == 0 then
            api.nvim_echo({ { QFR_NO_LL, "" } }, false, {})
            return
        end
    end

    local nr = ntq.resolve_list_nr(src_win, count)
    local what_ret = ntq.get_list(src_win, { nr = nr, all = true }) ---@type table
    local size = what_ret.size
    if size == 0 then
        api.nvim_echo({ { "No entries", "" } }, false, {})
        return
    elseif size == 1 then
        return
    end

    local what_set = ntq.what_ret_to_set(what_ret)
    table.sort(what_set.items, f)
    local dest_nr = ntq.set_list_checked(src_win, "u", what_set)
    if dest_nr < 1 then
        api.nvim_echo({ { "Unable to set new list", "ErrorMsg" } }, true, {})
        return
    end

    if not cfg.goto_after then
        return
    end

    local herder = require("qf-herder")
    local _, _, ok, stack_cfg, err = herder._config_merged_from_win(src_win or 0, "stack")
    if not ok then
        api.nvim_echo({ { err, "ErrorMsg" } }, true, {})
        return
    end

    require("qf-herder._stack")._history(src_win, true, dest_nr, stack_cfg)
end

-- TODO: For APIs, I would have fname ASC/DESC and severity ASC/DESC as built-ins. And then
-- I would have an API that takes a custom predicate. I'm not sure what the use cases here are
-- so unwilling to go further

---@param a vim.quickfix.entry
---@param b vim.quickfix.entry
---@return boolean
local function check_range(a, b)
    local lnum_a = a.lnum
    local lnum_b = b.lnum
    if lnum_a ~= nil and lnum_b ~= nil and lnum_a ~= lnum_b then
        return lnum_a < lnum_b
    end

    local col_a = a.col
    local col_b = b.col
    if col_a ~= nil and col_b ~= nil and col_a ~= col_b then
        return col_a < col_b
    end

    local end_lnum_a = a.end_lnum
    local end_lnum_b = b.end_lnum
    if end_lnum_a ~= nil and end_lnum_b ~= nil and end_lnum_a ~= end_lnum_b then
        return end_lnum_a < end_lnum_b
    end

    local end_col_a = a.end_col
    local end_col_b = b.end_col
    if end_col_a ~= nil and end_col_b ~= nil then
        return end_col_a < end_col_b
    end

    return false
end

---@param a vim.quickfix.entry
---@param b vim.quickfix.entry
---@return boolean
function M.fname_asc(a, b)
    local bufnr_a = a.bufnr
    local bufnr_b = b.bufnr
    local bufname_a = bufnr_a ~= nil and vim.call("bufname", bufnr_a) or ""
    local bufname_b = bufnr_b ~= nil and vim.call("bufname", bufnr_b) or ""
    if bufname_a ~= bufname_b then
        return bufname_a < bufname_b
    end

    return check_range(a, b)
end

---@param a vim.quickfix.entry
---@param b vim.quickfix.entry
---@return boolean
function M.fname_desc(a, b)
    return M.fname_asc(b, a)
end

local diag_err = vim.diagnostic.severity.ERROR
local diag_warn = vim.diagnostic.severity.WARN
local diag_info = vim.diagnostic.severity.INFO
local diag_hint = vim.diagnostic.severity.HINT
local severity_unmap = {
    E = diag_err,
    W = diag_warn,
    I = diag_info,
    H = diag_hint,
}

---@param a vim.quickfix.entry
---@param b vim.quickfix.entry
---@return boolean
function M.severity_asc(a, b)
    local type_a = a.type
    local type_b = b.type
    if type_a ~= nil and type_b ~= nil then
        local sev_a = severity_unmap[type_a]
        local sev_b = severity_unmap[type_b]
        if sev_a ~= nil and sev_b ~= nil and sev_a ~= sev_b then
            return sev_a < sev_b
        end
    end

    return M.fname_asc(a, b)
end

---@param a vim.quickfix.entry
---@param b vim.quickfix.entry
---@return boolean
function M.severity_desc(a, b)
    return M.severity_asc(b, a)
end

return M
