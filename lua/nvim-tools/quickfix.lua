local fn = vim.fn

local M = {}

---@param src_win integer|nil
---@param title string
---@return integer|nil
function M._find_list_with_title(src_win, title)
    local max_nr = M._get_list(src_win, { nr = "$" }).nr
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

---@param what_ret table
---@return table
function M.what_ret_to_set(what_ret)
    local what_set = {}

    local wr_context = what_ret.context
    what_set.context = type(wr_context) == "table" and wr_context or nil
    local wr_idx = what_ret.idx
    what_set.idx = type(wr_idx) == "number" and wr_idx or nil
    local wr_items = what_ret.items
    what_set.items = type(wr_items) == "table" and wr_items.items or {}

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
-- TODO: I remember this being important in rancher but I'm not totally sure why.

return M

-- TODO: Add custom annotations for the missing qf data types. Really should just be PR'd though.
