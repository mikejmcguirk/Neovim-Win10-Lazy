local fn = vim.fn

local M = {}

---@param src_win integer|nil
---@param title string
---@return integer|nil
function M._find_list_with_title(src_win, title)
    local max_nr = M.get_list(src_win, { nr = "$" }).nr
    if src_win then
        for i = max_nr, 1, -1 do
            local title_i = fn.getloclist(src_win, { nr = i, title = 0 }).title ---@type string
            if title_i == title then
                return i
            end
        end
    else
        for i = max_nr, 1, -1 do
            local title_i = fn.getqflist({ nr = i, title = 0 }).title ---@type string
            if title_i == title then
                return i
            end
        end
    end

    return nil
end

---@param src_win integer|nil
---@param what table
---@return any
function M.get_list(src_win, what)
    return src_win and fn.getloclist(src_win, what) or fn.getqflist(what)
end

---@param src_win integer|nil
---@param nr uinteger|"$"
---@return uinteger
function M.resolve_list_nr(src_win, nr)
    if nr == 0 then
        return M.get_list(src_win, { nr = 0 }).nr
    end

    local max_nr = M.get_list(src_win, { nr = "$" }).nr
    if nr == "$" then
        return max_nr
    end

    ---@diagnostic disable-next-line: param-type-mismatch, return-type-mismatch
    return math.min(nr, max_nr)
end

---@param src_win uinteger|nil
---@param action "a"|"f"|"r"|"u"|" "
---@param what table
---@return -1|0
function M.set_list(src_win, action, what)
    return src_win and fn.setloclist(src_win, {}, action, what) or fn.setqflist({}, action, what)
end

---@param result -1|0
---@param src_win integer|nil
---@param nr integer|"$"
---@param action qf-rancher.types.Action
---@return integer
function M.set_result_resolve(result, src_win, nr, action)
    if result == -1 then
        return -1
    end

    if action == "f" then
        return 0 -- Stack cleared
    end

    if nr == 0 then
        return M.get_list(src_win, { nr = 0 }).nr ---@type uinteger
    end

    local max_nr = M.get_list(src_win, { nr = "$" }).nr ---@type integer
    -- "$" will always have acted on the last item in the list. When action is " ", the new list
    -- is always at the end.
    if type(nr) == "string" or action == " " then
        return max_nr
    end

    return math.min(nr, max_nr)
end

---@param src_win integer|nil
---@param action qf-rancher.types.Action
---@param what table
---@return integer
function M.set_list_checked(src_win, action, what)
    local what_set = require("nvim-tools.table").deepcopy(what)

    what_set.nr = M.resolve_list_nr(src_win, what_set.nr)
    if what_set.idx then
        if what_set.items or what_set.lines then
            local items_len = what_set.items and #what_set.items or 0
            local lines_len = what_set.lines and #what_set.lines or 0
            local new_len = items_len + lines_len
            what_set.idx = new_len > 0 and math.min(what_set.idx, new_len) or nil
        else
            ---@type uinteger
            local cur_size = M.get_list(src_win, { nr = what_set.nr, size = 0 }).size
            what_set.idx = math.min(what_set.idx, cur_size)
        end
    end

    return M.set_result_resolve(M.set_list(src_win, action, what), src_win, what_set.nr, action)
end

---@param what_ret table
---@return table
function M.what_ret_to_set(what_ret)
    local what_set = {}

    local wr_nr = what_ret.nr
    what_set.nr = wr_nr ~= nil and wr_nr or 0

    local wr_context = what_ret.context
    what_set.context = type(wr_context) == "table" and wr_context or nil
    local wr_idx = what_ret.idx
    what_set.idx = type(wr_idx) == "number" and wr_idx or nil
    local wr_items = what_ret.items
    what_set.items = type(wr_items) == "table" and wr_items or {}

    local wr_quickfixtextfunc = what_ret.quickfixtextfunc
    local is_qftf_func = type(wr_quickfixtextfunc) == "function"
    local is_qftf_str = type(wr_quickfixtextfunc) == "string" and #wr_quickfixtextfunc > 0
    if is_qftf_func or is_qftf_str then
        what_set.quickfixtextfunc = wr_quickfixtextfunc
    end

    local wr_title = what_ret.title
    local is_title_str = type(wr_title) == "string" and #wr_title > 0
    what_set.title = is_title_str and wr_title or nil

    return what_set
end

---@param src_win integer|nil
---@param list_nr integer|"$"
---@return integer
function M.clear_list(src_win, list_nr)
    local nr = M.resolve_list_nr(src_win, list_nr)
    local what = { nr = nr, context = {}, items = {}, quickfixtextfunc = "", title = "" }
    local action = "r"
    return M.set_result_resolve(M.set_list(src_win, action, what), src_win, nr, action)
end

return M

-- TODO: Move the highly customized rancher stuff out of here. Includes anything tied to bespoke
-- list transformations and enhanced result reporting.
-- TODO: Add custom annotations for the missing qf data types. Really should just be PR'd though.
