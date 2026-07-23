local api = vim.api
local fn = vim.fn

local ntt = require("nvim-tools.table")
local _util = require("qf-herder._util")

local M = {}

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
---@field reuse_title boolean
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

    -- TODO: Do we need special case handling here for qf?
    -- TODO: Maybe outline this as some kind of "ensure_src_win" function but need to know the
    -- qf case.
    local orig_src_win = src_win
    if src_win and item_type == "\1" then
        local src_win_buf = api.nvim_win_get_buf(src_win)
        if api.nvim_get_option_value("bt", { buf = src_win_buf }) ~= "help" then
            local ntb = require("nvim-tools.buf")
            local temp_buf = ntb.create_temp_buf("wipe", false, "help", "help", false)
            src_win = api.nvim_open_win(temp_buf, false, { split = "below", win = src_win })
        end
    end

    local what_set = ntt.merge_deep_right(what, entries)
    local dest_nr = require("nvim-tools.quickfix").set_list_checked(src_win, ctx.action, what_set)
    if dest_nr < 1 then
        api.nvim_echo({ { "Unable to set list", "ErrorMsg" } }, true, {})
        return
    end

    local cfg_spk = cfg.spk
    local history_cfg = { spk = cfg_spk, update_list_wins = cfg.update_list_wins }
    require("qf-herder._stack")._history(src_win, false, dest_nr, history_cfg)
    if cfg.open_results then
        if src_win ~= nil and orig_src_win ~= src_win then
            api.nvim_set_current_win(src_win)
        end

        require("qf-herder._window").list_open(src_win, 0, {
            auto_height = cfg.auto_height,
            split_ll = cfg.split_ll,
            split_qf = cfg.split_qf,
            silent = false, -- TODO: Should be removed
            spk = cfg_spk,
        })
    end

    -- TODO: I think this is the right behavior but this is a disorganized way to do it,
    -- because we don't need the win_call if we opened results. I think we make a nav abstraction
    -- that does an optional win_call. Or maybe we accept that the abstraction always does it.
    if src_win ~= nil then
        api.nvim_win_call(src_win, function()
            api.nvim_cmd({ cmd = "ll", count = 1, silent = true }, {})
        end)
    else
        api.nvim_cmd({ cmd = "cc", count = 1, silent = true }, {})
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
    what = ntt.deepcopy(what)

    local timeout = cfg.timeout
    ---@type vim.SystemOpts
    local vim_system_opts = { text = true, timeout = timeout }
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
