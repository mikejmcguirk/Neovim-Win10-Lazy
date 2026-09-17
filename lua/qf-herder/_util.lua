local api = vim.api
-- local fn = vim.fn

local M = {}

---@param win uinteger?
---@param tabpage uinteger?
---@param spk ""|"cursor"|"screen"|"topline"
---@return (""|"cursor"|"screen"|"topline")?
function M.ensure_spk(win, tabpage, spk)
    if #spk == 0 then
        return
    end

    local cur_tabpage = api.nvim_get_current_tabpage()
    tabpage = tabpage == 0 and cur_tabpage or tabpage
    if win ~= nil and api.nvim_win_get_tabpage(win) ~= cur_tabpage then
        return
    elseif tabpage ~= nil and tabpage ~= cur_tabpage then
        return
    end

    local scope_global = { scope = "global" }
    ---@type ""|"cursor"|"screen"|"topline"
    local old_spk = api.nvim_get_option_value("spk", scope_global)
    api.nvim_set_option_value("spk", spk, scope_global)
    return old_spk
end

---@param reuse_title boolean
---@param src_win uinteger?
---@param title string
---@return ("a"|"f"|"r"|"u"|" "), uinteger
function M.set_nr_resolve(reuse_title, src_win, title)
    local _tools = require("qf-herder._tools")
    if reuse_title then
        local set_nr = _tools.list_nr_with_title(src_win, title)
        if set_nr then
            return "u", set_nr
        end
    end

    return " ", _tools.get_list(src_win, { nr = "$" }).nr
end

---@param src_win uinteger?
---@param nr uinteger
---@param silent boolean
function M.set_nr_and_open(src_win, nr, silent)
    local herder = require("qf-herder")
    local _, _, stack_cfg = herder._config_merged_from_win(src_win or 0, "stack")
    require("qf-herder._stack")._history(src_win, silent, nr, stack_cfg)

    local _, _, win_cfg = herder._config_merged_from_win(src_win or 0, "window")
    require("qf-herder._window").list_open(src_win, 0, silent, win_cfg)
end

---------------------------
-- MARK: List Operations --
---------------------------

---@param src_win integer|nil
---@param list_nr integer|"$"
---@return integer
function M.clear_list(src_win, list_nr)
    local nr = M.resolve_list_nr(src_win, list_nr)
    local what = { nr = nr, context = {}, items = {}, quickfixtextfunc = "", title = "" }
    local action = "r"
    local _tools = require("qf-herder._tools")
    return M.set_result_resolve(_tools.set_list(src_win, action, what), src_win, nr, action)
end

---@param src_win integer|nil
---@param nr uinteger|"$"
---@return uinteger
function M.resolve_list_nr(src_win, nr)
    local _tools = require("qf-herder._tools")
    if nr == 0 then
        return _tools.get_list(src_win, { nr = 0 }).nr
    end

    local max_nr = _tools.get_list(src_win, { nr = "$" }).nr
    if nr == "$" then
        return max_nr
    end

    ---@diagnostic disable-next-line: param-type-mismatch, return-type-mismatch
    return math.min(nr, max_nr)
end

---@param result -1|0
---@param src_win integer|nil
---@param nr integer|"$"
---@param action "a"|"f"|"r"|"u"|" "
---@return integer
function M.set_result_resolve(result, src_win, nr, action)
    if result == -1 then
        return -1
    end

    if action == "f" then
        return 0 -- Stack cleared
    end

    local _tools = require("qf-herder._tools")
    if nr == 0 then
        return _tools.get_list(src_win, { nr = 0 }).nr ---@type uinteger
    end

    local max_nr = _tools.get_list(src_win, { nr = "$" }).nr ---@type integer
    -- "$" will always have acted on the last item in the list. When action is " ", the new list
    -- is always at the end.
    if type(nr) == "string" or action == " " then
        return max_nr
    end

    return math.min(nr, max_nr)
end

---@param src_win integer|nil
---@param action "a"|"f"|"r"|"u"|" "
---@param what table
---@return integer
function M.set_list_checked(src_win, action, what)
    local what_set = require("qf-herder")._deepcopy(what)

    local _tools = require("qf-herder._tools")
    what_set.nr = M.resolve_list_nr(src_win, what_set.nr)
    if what_set.idx then
        if what_set.items or what_set.lines then
            local items_len = what_set.items and #what_set.items or 0
            local lines_len = what_set.lines and #what_set.lines or 0
            local new_len = items_len + lines_len
            what_set.idx = new_len > 0 and math.min(what_set.idx, new_len) or nil
        else
            ---@type uinteger
            local cur_size = _tools.get_list(src_win, { nr = what_set.nr, size = 0 }).size
            what_set.idx = math.min(what_set.idx, cur_size)
        end
    end

    return M.set_result_resolve(
        _tools.set_list(src_win, action, what),
        src_win,
        what_set.nr,
        action
    )
end

return M
