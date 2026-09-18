local api = vim.api
local fn = vim.fn

local _tools = require("qf-herder._tools")

local M = {}

local opts_cache = nil ---@type qf-herder.del.Opts?
local ofunc = "v:lua.require'qf-herder._del'.del_in_qf_cb"
-- TODO-DEP: Make this a function when 0.15 comes out.

---@param vmode boolean
---@return uinteger, uinteger One indexed.
local function del_line_range_get(vmode)
    local start = api.nvim_buf_get_mark(0, vmode and "<" or "[")
    local fin = api.nvim_buf_get_mark(0, vmode and ">" or "]")
    return math.min(start[1], fin[1]), math.max(start[1], fin[1])
end

---@param cur_idx uinteger
---@param start_line uinteger
---@param end_line uinteger
---@param entries_after_len uinteger
---@return uinteger
local function new_idx_get(cur_idx, start_line, end_line, entries_after_len)
    if cur_idx < start_line then
        return cur_idx
    elseif end_line < cur_idx then
        return cur_idx - (end_line - start_line + 1)
    else
        return math.min(start_line, entries_after_len)
    end
end

---@param vmode boolean
local function del_in_qf_do(vmode)
    local list_win = api.nvim_get_current_win() ---@type integer
    local wintype = fn.win_gettype(list_win)
    if not (wintype == "quickfix" or wintype == "loclist") then
        api.nvim_echo({ { QFR_NOT_LIST, "" } }, false, {})
        return
    end

    local src_win = wintype == "loclist" and list_win or nil
    local what_ret = _tools.get_list(src_win, { nr = 0, all = true }) ---@type table
    if #what_ret.items < 1 then
        return
    end

    if vmode then
        api.nvim_cmd({ cmd = "normal", args = { "\27" }, bang = true }, {})
    end

    local start_line, end_line = del_line_range_get(vmode)
    _tools.i_expel(what_ret.items, start_line, end_line)
    local items_len = #what_ret.items
    local new_idx = new_idx_get(what_ret.idx, start_line, end_line, items_len)
    local col = api.nvim_win_get_cursor(list_win)[2]

    _tools.set_list(src_win, "u", { nr = 0, items = what_ret.items, idx = new_idx })
    _tools.protected_set_cursor(0, { start_line, col })

    ---@type qf-herder.del.Cfg
    local cfg = require("qf-herder")._config_merged_get(0, opts_cache, "del")
    -- TODO: This is the same logic _stack uses, which we don't want to duplicate.
    if cfg.auto_resize then
        ---@type qf-herder.window.Cfg
        local win_cfg = require("qf-herder")._config_merged_get(0, nil, "window")
        local new_size = math.min(items_len, 10)
        if src_win ~= nil then
            require("qf-herder._window").ll_resize(src_win, new_size, true, win_cfg)
        else
            require("qf-herder._window").qf_resize(0, new_size, win_cfg)
        end
    end
end
-- MID: Add do_zzze as an option. Problem: If a centered cursor doesn't leave enough list rows to
-- cover the rest of the window, zz will leave blank area in the window.

---@param _ "block"|"char"|"line"
function M.del_in_qf_cb(_)
    del_in_qf_do(_tools.is_vmode(api.nvim_get_mode().mode))
end

---@param opts qf-herder.del.Opts?
function M.del_in_qf(opts)
    opts_cache = opts
    api.nvim_set_option_value("operatorfunc", ofunc, { scope = "global" })
    api.nvim_feedkeys("g@", "ni", true)
end
---@param opts qf-herder.del.Opts?
function M.del_in_qf_line(opts)
    opts_cache = opts
    api.nvim_set_option_value("operatorfunc", ofunc, { scope = "global" })
    api.nvim_feedkeys("g@_", "ni", true)
end

return M
