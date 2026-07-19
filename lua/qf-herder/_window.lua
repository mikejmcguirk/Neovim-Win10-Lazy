local api = vim.api
local fn = vim.fn

local _util = require("qf-herder._util")

local LIST_MAX_HEIGHT = 10
local NO_LL = "No location list"

---@class qf-herder.window.Ctx
---@field auto_height boolean
---@field spk ""|"cursor"|"screen"|"topline"
---@field qf_split "botright"|"topleft"
---@field ll_split "aboveleft"|"belowright"
---@field silent boolean

------------------
-- MARK: Common --
------------------

---@param src_win uinteger|nil
---@param count uinteger
---@param auto_height boolean
---@return uinteger
local function height_resolve(src_win, count, auto_height)
    if count > 0 then
        return count
    elseif auto_height == false then
        return LIST_MAX_HEIGHT
    end

    local ntq = require("nvim-tools.quickfix")
    local size = ntq.get_list(src_win, { nr = 0, size = 0 }).size ---@type uinteger
    return size == 0 and 1 or math.min(size, LIST_MAX_HEIGHT)
end

---@param spk ""|"cursor"|"screen"|"topline"
---@param win uinteger
---@param height uinteger
local function win_resize_with_spk(spk, win, height)
    local old_spk = #spk > 0 and _util.ensure_spk(0, spk) or nil
    local ntw = require("nvim-tools.win")
    pcall(ntw.resize, win, -1, height, { anchor = "bottom" })
    if old_spk ~= nil then
        api.nvim_set_option_value("spk", old_spk, { scope = "global" })
    end
end

--------------------
-- MARK: Quickfix --
--------------------

local M = {}

---@param spk string
---@param count uinteger
---@param split "botright"|"topleft"
---@return boolean, string
local function copen_with_spk(spk, count, split)
    local old_spk = #spk > 0 and _util.ensure_spk(0, spk) or nil
    local ok, err = pcall(function()
        api.nvim_cmd({ cmd = "copen", count = count, mods = { split = split } }, {})
    end)

    if old_spk ~= nil then
        api.nvim_set_option_value("spk", old_spk, { scope = "global" })
    end

    ---@diagnostic disable-next-line: return-type-mismatch
    return ok, err
end
-- MID: Can be combined with lopen_with_spk by taking cmd as a param and making split inclusive
-- of all options. Wait because this would be a pain to unwind if it were premature.

---Wrapper for `copen` in the current tabpage.
---@param count uinteger
---@param ctx qf-herder.window.Ctx
---@return boolean, string
function M.qf_win_open(count, ctx)
    local qf_win = _util.find_qf_win(0)
    if qf_win ~= nil then
        return false, "Quickfix window already open"
    end

    local ctx_spk = ctx.spk
    _util.ll_wins_close_all_in_tabpage_with_spk(0, ctx_spk)
    return copen_with_spk(ctx_spk, height_resolve(nil, count, ctx.auto_height), ctx.qf_split)
end

---@class qf-herder.window.quickfixClose.Ctx
---@field spk "cursor"|"screen"|"topline"|""

---@param tabpage uinteger
---@param ctx qf-herder.window.Ctx
---@return boolean, uinteger
function M.qf_win_close(tabpage, ctx)
    local qf_win = _util.find_qf_win(tabpage)
    if qf_win == nil then
        return false, 0
    end

    return _util.win_close_with_spk(qf_win, tabpage, ctx.spk), qf_win
end

---@param count uinteger
---@param ctx qf-herder.window.Ctx
---@return boolean, string
function M.qf_win_toggle(count, ctx)
    local qf_win = _util.find_qf_win(0)
    local ctx_spk = ctx.spk
    if qf_win == nil then
        _util.ll_wins_close_all_in_tabpage_with_spk(0, ctx_spk)
        return copen_with_spk(ctx_spk, height_resolve(nil, count, ctx.auto_height), ctx.qf_split)
    else
        return _util.win_close_with_spk(qf_win, 0, ctx_spk)
    end
end

---@param tabpage uinteger
---@param count uinteger
---@param ctx qf-herder.window.Ctx
function M.qf_win_resize(tabpage, count, ctx)
    local qf_win = _util.find_qf_win(tabpage)
    if qf_win ~= nil then
        win_resize_with_spk(ctx.spk, qf_win, height_resolve(nil, count, true))
    end
end

-------------------------
-- MARK: Location List --
-------------------------

---@param spk string
---@param count uinteger
---@return boolean, string
local function lopen_with_spk(spk, count, split)
    local old_spk = #spk > 0 and _util.ensure_spk(0, spk) or nil
    local ok, err = pcall(function()
        api.nvim_cmd({ cmd = "lopen", count = count, mods = { split = split } }, {})
    end)

    if old_spk ~= nil then
        api.nvim_set_option_value("spk", old_spk, { scope = "global" })
    end

    ---@diagnostic disable-next-line: return-type-mismatch
    return ok, err
end

---@param count uinteger
---@param ctx qf-herder.window.Ctx
---@return boolean, string
function M.ll_win_open(count, ctx)
    local src_win = api.nvim_get_current_win()
    local qf_id = fn.getloclist(src_win, { id = 0 }).id
    if qf_id == 0 then
        if not ctx.silent then
            api.nvim_echo({ { NO_LL, "" } }, false, {})
        end

        return false, NO_LL
    end

    local ll_win = _util.ll_win_find_one_by_qf_id(0, qf_id)
    if ll_win ~= nil then
        return false, "Location list already open"
    end

    local ctx_spk = ctx.spk
    M.qf_win_close(0, ctx)
    return lopen_with_spk(ctx_spk, height_resolve(src_win, count, ctx.auto_height), ctx.ll_split)
end

---@class qf-herder.window.locationListClose.Ctx : qf-herder.window.quickfixClose.Ctx
---@field silent boolean

---@param tabpage uinteger
---@param ctx qf-herder.window.Ctx
---@return boolean, uinteger
function M.ll_win_close(tabpage, ctx)
    local qf_id = fn.getloclist(api.nvim_get_current_win(), { id = 0 }).id
    if qf_id == 0 then
        if not ctx.silent then
            api.nvim_echo({ { NO_LL, "" } }, false, {})
        end

        return false, 0
    end

    local ll_win = _util.ll_win_find_one_by_qf_id(0, qf_id)
    if ll_win == nil then
        return false, 0
    end

    return _util.win_close_with_spk(ll_win, tabpage, ctx.spk), ll_win
end

---@param count uinteger
---@param ctx qf-herder.window.Ctx
---@return boolean, string
function M.ll_win_toggle(count, ctx)
    local qf_id = fn.getloclist(api.nvim_get_current_win(), { id = 0 }).id
    if qf_id == 0 then
        if not ctx.silent then
            api.nvim_echo({ { NO_LL, "" } }, false, {})
        end

        return false, NO_LL
    end

    local ll_win = _util.ll_win_find_one_by_qf_id(0, qf_id)
    local ctx_spk = ctx.spk
    if ll_win == nil then
        M.qf_win_close(0, ctx)
        return lopen_with_spk(ctx_spk, height_resolve(nil, count, ctx.auto_height), ctx.ll_split)
    else
        return _util.win_close_with_spk(ll_win, 0, ctx_spk)
    end
end

---@param src_win uinteger
---@param count uinteger
---@param ctx qf-herder.window.Ctx
function M.ll_win_resize(src_win, count, ctx)
    local qf_id = fn.getloclist(src_win, { id = 0 }).id
    if qf_id == 0 then
        if not ctx.silent then
            api.nvim_echo({ { NO_LL, "" } }, false, {})
        end

        return false, NO_LL
    end

    local ll_win = _util.ll_win_find_one_by_qf_id(0, qf_id)
    if ll_win ~= nil then
        win_resize_with_spk(ctx.spk, ll_win, height_resolve(src_win, count, true))
    end
end

return M

-- TODO-DEP: For any of these that I use internally, narrow the ctx param to only what the
-- function needs, so long as it's a subset of the overall Ctx var. Create specific sub-classes to
-- help with type-checking.
