local api = vim.api
local fn = vim.fn

local M = {}

local ntq = require("nvim-tools.quickfix")
local _util = require("qf-herder._util")

---@param entries vim.quickfix.entry[] Modified in place!
---@param re vim.regex
---@param f fun(entry:vim.quickfix.entry, regex:vim.regex): boolean
---@return vim.quickfix.entry[] Reference to `entries`.
local function regex_keep(entries, re, f)
    local entries_len = #entries
    if entries_len == 0 then
        return entries
    end

    local j = 1
    for i = 1, entries_len do
        local v = entries[i]
        if f(v, re) then
            entries[j] = v
            j = j + 1
        end
    end

    for i = j, entries_len do
        entries[i] = nil
    end

    return entries
end

---@param name string
---@return boolean, string
local function pattern_get(name)
    return require("nvim-tools.ui").input({ prompt = "[filter] " .. name .. ": " })
end

---@param src_win uinteger|nil
---@param count uinteger
---@param name string
---@param f fun(entry:vim.quickfix.entry, regex:vim.regex): boolean
---@param cfg qf-herder.filter.Cfg
function M.filter(src_win, count, name, f, cfg)
    if src_win ~= nil and fn.getloclist(src_win, { id = 0 }).id == 0 then
        api.nvim_echo({ { QFR_NO_LL, "" } }, false, {})
        return
    end

    local nr = ntq.resolve_list_nr(src_win, count)
    local what_ret = ntq.get_list(src_win, { nr = nr, all = true }) ---@type table
    local size = what_ret.size
    if size == 0 then
        api.nvim_echo({ { "No entries", "" } }, false, {})
        return
    end

    local ok_p, pattern = pattern_get(name)
    if not (ok_p and #pattern > 0) then
        api.nvim_echo({ { pattern, "WarningMsg" } }, true, {})
        return
    end

    local what_set = ntq.what_ret_to_set(what_ret)
    local ok_r, re = pcall(vim.regex, pattern)
    if not ok_r then
        api.nvim_echo({ { re, "ErrorMsg" } }, true, {})
        return
    end

    regex_keep(what_set.items, re, f)
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

---@param entry vim.quickfix.entry
---@param re vim.regex
---@return boolean
function M.fname_keep(entry, re)
    local bufnr = entry.bufnr
    if bufnr ~= nil then
        local sc, ec = re:match_str(vim.call("bufname", bufnr))
        return sc ~= nil and ec ~= nil
    else
        return false
    end
end

---@param entry vim.quickfix.entry
---@param re vim.regex
---@return boolean
function M.fname_discard(entry, re)
    local bufnr = entry.bufnr
    if bufnr ~= nil then
        local sc, ec = re:match_str(vim.call("bufname", bufnr))
        return sc == nil or ec == nil
    else
        return true
    end
end

---@param entry vim.quickfix.entry
---@param re vim.regex
---@return boolean
function M.text_keep(entry, re)
    local text = entry.text
    if text ~= nil then
        local sc, ec = re:match_str(text)
        return sc ~= nil and ec ~= nil
    else
        return false
    end
end

---@param entry vim.quickfix.entry
---@param re vim.regex
---@return boolean
function M.text_discard(entry, re)
    local text = entry.text
    if text ~= nil then
        local sc, ec = re:match_str(text)
        return sc == nil or ec == nil
    else
        return true
    end
end

return M
