local api = vim.api
local fn = vim.fn

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
---@return boolean
local function copen_with_spk(spk, count)
    local _util = require("qf-herder._util")
    local old_spk = spk ~= nil and _util.ensure_spk(0, spk) or nil
    local ok = pcall(function()
        api.nvim_cmd({ cmd = "copen", count = count, mods = { split = "botright" } }, {})
    end)

    if old_spk ~= nil then
        api.nvim_set_option_value("spk", old_spk, { scope = "global" })
    end

    return ok
end

-- LOW: Support custom split.
---@param spk string?
---@param count uinteger
---@return boolean
local function lopen_with_spk(spk, count)
    local _util = require("qf-herder._util")
    local old_spk = spk ~= nil and _util.ensure_spk(0, spk) or nil
    local ok = pcall(function()
        api.nvim_cmd({ cmd = "copen", count = count, mods = { split = "botright" } }, {})
    end)

    if old_spk ~= nil then
        api.nvim_set_option_value("spk", old_spk, { scope = "global" })
    end

    return ok
end
-- LOW: Support custom split.

---@class qf-hreder.window.OpenCtx
---@field auto_height boolean
---@field spk "cursor"|"screen"|"topline"|nil

---Wrapper for `copen` in the current tabpage.
---@return boolean
function M.qf_win_open(ctx)
    local _util = require("qf-herder._util")
    local qf_win = _util.find_qf_win(0)
    if qf_win ~= nil then
        return false
    end

    local ctx_spk = ctx.spk
    _util.ll_wins_close_all_in_tabpage_with_spk(0, ctx.spk)
    return copen_with_spk(ctx_spk, resolve_list_height(nil, ctx.auto_height))
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

function M.qf_win_toggle(ctx)
    local _util = require("qf-herder._util")
    local qf_win = _util.find_qf_win(0)
    local ctx_spk = ctx.spk
    if qf_win == nil then
        _util.ll_wins_close_all_in_tabpage_with_spk(0, ctx_spk)
        return copen_with_spk(ctx_spk, resolve_list_height(nil, ctx.auto_height))
    else
        return _util.win_close_with_spk(qf_win, 0, ctx_spk), qf_win
    end
end

function M.ll_win_open(ctx)
    local win = api.nvim_get_current_win()
    local qf_id = fn.getloclist(win, { id = 0 }).id
    if qf_id == 0 then
        -- TODO: print no location list
        return
    end

    M.qf_win_close(0, { "topline" })
    local ctx_spk = ctx.spk
    -- TODO: Probably wrong.
    return copen_with_spk(ctx_spk, resolve_list_height(nil, ctx.auto_height))
end

return M
