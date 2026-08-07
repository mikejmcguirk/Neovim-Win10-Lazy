local api = vim.api
local fn = vim.fn

local _util = require("qf-herder._util")
local ntq = require("nvim-tools.quickfix")
local ntt = require("nvim-tools.table")

local M = {}

---@param src_win uinteger?
---@return uinteger?
local function src_win_resolve(src_win, item_type)
    if src_win == nil or item_type ~= "\1" then
        return src_win
    end

    local src_win_buf = api.nvim_win_get_buf(src_win)
    if api.nvim_get_option_value("bt", { buf = src_win_buf }) == "help" then
        return src_win
    end

    local ntb = require("nvim-tools.buf")
    local temp_buf = ntb.create_temp_buf("wipe", false, "help", "help", false)
    return api.nvim_open_win(temp_buf, false, { split = "below", win = src_win })
end

---@param stdout string?
---@param sort fun(a:vim.quickfix.entry, b:vim.quickfix.entry): boolean
---@param item_type string
---@return boolean, vim.quickfix.entry[], string
local function entries_from_stdout(stdout, sort, item_type)
    local lines = vim.split(stdout or "", "\n", { trimempty = true })
    if #lines == 0 then
        return false, {}, "No output"
    end

    ---@type vim.quickfix.entry[]
    local entries = fn.getqflist({ lines = lines }).items
    if #entries < 1 then
        return false, entries, "No entries"
    end

    table.sort(entries, sort)
    if item_type ~= "" then
        for _, item in ipairs(entries) do
            item.type = item_type
        end
    end

    return true, entries, ""
end

---@param src_win integer|nil
---@param obj vim.SystemCompleted
---@return boolean, string
local function state_verify(src_win, obj)
    if obj.code == nil or obj.code ~= 0 then
        local code_str = obj.code ~= nil and "Exit code: " .. obj.code or ""
        local err = obj.stderr ~= nil and #obj.stderr > 0 and "Error: " .. obj.stderr or ""
        api.nvim_echo({ { code_str .. " " .. err, "ErrorMsg" } }, true, {})
        return false, code_str .. " " .. err
    end

    if src_win and not api.nvim_win_is_valid(src_win) then
        return false, "Window " .. src_win .. " is not valid"
    end

    return true, ""
end

---@class qf-rancher.system.Ctx
---@field action "a"|"f"|"r"|"u"|" "
---@field item_type string
---@field sort fun(a:vim.quickfix.entry, b:vim.quickfix.entry): boolean

---@param src_win integer|nil
---@param obj vim.SystemCompleted
---@param what table
---@param ctx qf-rancher.system.Ctx
---@param cfg qf-rancher.system.Cfg
local function output_set_to_list(src_win, obj, what, ctx, cfg)
    local ok, err = state_verify(src_win, obj)
    if not ok then
        api.nvim_echo({ { err, "ErrorMsg" } }, true, {})
        return
    end

    local item_type = ctx.item_type
    local ok_e, entries, err_e = entries_from_stdout(obj.stdout, ctx.sort, item_type)
    if not ok_e then
        api.nvim_echo({ { err_e, "WarningMsg" } }, false, {})
        return
    end

    local src_win_res = src_win_resolve(src_win, item_type)
    local what_set = ntt.deepcopy(what)
    what_set.items = entries
    local dest_nr = ntq.set_list_checked(src_win_res, ctx.action, what_set)
    if dest_nr < 1 then
        api.nvim_echo({ { "Unable to set list", "ErrorMsg" } }, true, {})
        return
    end

    local is_new_ll_win = src_win ~= nil and src_win_res ~= src_win
    if is_new_ll_win then
        ---@cast src_win_res uinteger
        api.nvim_set_current_win(src_win_res)
    end

    if is_new_ll_win or cfg.open_results then
        _util.set_nr_and_open(src_win_res, dest_nr, false)
    end

    if is_new_ll_win then
        api.nvim_cmd({ cmd = "ll", count = 1, mods = { silent = true } }, {})
    end
end

---@param src_win uinteger|nil
---@param cmd_parts string[]
---@param sync boolean
---`""` is standard. `"\1"` for help.
---@param what table See |setqflist-what|
---@param ctx qf-rancher.system.Ctx
---@param cfg qf-rancher.system.Cfg
function M.cmd_to_list(src_win, cmd_parts, sync, what, ctx, cfg)
    local timeout = cfg.timeout
    local vim_system_opts = { text = true, timeout = timeout } ---@type vim.SystemOpts
    what = ntt.deepcopy(what)

    if sync then
        local obj = vim.system(cmd_parts, vim_system_opts):wait(timeout)
        output_set_to_list(src_win, obj, what, ctx, cfg)
    else
        vim.system(cmd_parts, vim_system_opts, function(obj)
            vim.schedule(function()
                output_set_to_list(src_win, obj, what, ctx, cfg)
            end)
        end)
    end
end

return M
