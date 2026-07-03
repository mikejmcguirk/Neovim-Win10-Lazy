local api = vim.api

local LIST_MAX_HEIGHT = 10

local M = {}

---@param src_win uinteger|nil
---@param auto_height boolean
---@return uinteger
local function resolve_list_height(src_win, auto_height)
    if auto_height == false then
        return LIST_MAX_HEIGHT
    end

    local ntq = require("nvim-tools.quickfix")
    local size = ntq.get_list(src_win, { nr = 0, size = 0 }).size ---@type uinteger
    return size == 0 and 1 or math.min(size, LIST_MAX_HEIGHT)
end

---@param spk string?
---@param count uinteger
local function copen_with_spk(spk, count)
    local _util = require("qf-herder._util")
    local old_spk = spk ~= nil and _util.ensure_spk(0, spk) or nil
    pcall(api.nvim_cmd, { cmd = "copen", count = count, mods = { split = "botright" } }, {})
    if old_spk ~= nil then
        api.nvim_set_option_value("spk", old_spk, { scope = "global" })
    end
end
-- LOW: Support custom split.

---@class qf-hreder.window.OpenCtx
---@field auto_height boolean
---@field spk "cursor"|"screen"|"topline"|nil

---Wrapper for `copen` in the current tabpage.
---@return boolean, uinteger
function M.qf_win_open(ctx)
    local _util = require("qf-herder._util")
    local qf_win = _util.find_qf_win(0)
    if qf_win ~= nil then
        return false, qf_win
    end

    local ctx_spk = ctx.spk
    _util.ll_wins_close_all_in_tabpage_with_spk(0, ctx_spk)
    copen_with_spk(ctx_spk, resolve_list_height(nil, ctx.auto_height))
    local qf_win_after = _util.find_qf_win(0)
    if qf_win_after ~= nil then
        return true, qf_win_after
    end

    return false, 0
end

---@class qf-herder.window.CloseCtx
---@field spk "cursor"|"screen"|"topline"|nil
-- TODO: Define the Opts here as well. For the public interface.

---@param tabpage uinteger
---@return boolean, uinteger
function M.qf_win_close(tabpage, ctx)
    local _util = require("qf-herder._util")
    local qf_win = _util.find_qf_win(tabpage)
    if qf_win == nil then
        return false, 0
    end

    return _util.win_close_with_spk(qf_win, tabpage, ctx.spk), qf_win
end
-- LOW: The old code has a "use_alt_win" option that I'm not sure of the purpose of.

return M
