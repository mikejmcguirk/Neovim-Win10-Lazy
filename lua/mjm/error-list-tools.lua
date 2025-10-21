local eo = Qfr_Defer_Require("mjm.error-list-open") ---@type QfrOpen
local ey = Qfr_Defer_Require("mjm.error-list-types") ---@type QfrTypes
local eu = Qfr_Defer_Require("mjm.error-list-util") ---@type QfrUtil

-- local api = vim.api
local fn = vim.fn

---@class QfrTools
local M = {}

-- MAYBE: Loop backwards so that, for ties, the more recent list is used

---@param src_win integer|nil
---@param title string
---@return integer|nil
function M._find_list_with_title(src_win, title)
    ey._validate_win(src_win, true)
    vim.validate("title", title, "string")

    local max_nr = M._get_list(src_win, { nr = "$" }).nr ---@type integer
    for i = 1, max_nr do
        if M._get_list(src_win, { nr = i, title = 0 }).title == title then return i end
    end

    return nil
end

---@param src_win integer|nil
---@param nr integer|"$"|nil
---@return integer|"$"
local function resolve_list_nr(src_win, nr)
    ey._validate_win(src_win, true)
    ey._validate_list_nr(nr, true)

    if not nr then return 0 end
    if nr == 0 or type(nr) == "string" then return nr end

    local max_nr = M._get_list(src_win, { nr = "$" }).nr ---@type integer
    ---@diagnostic disable-next-line: param-type-mismatch, return-type-mismatch
    return math.min(nr, max_nr)
end

-- NOTE: Post-calculate the destination nr because set_list can change the stack length

---@param src_win integer|nil
---@param nr integer|"$"
---@return integer
local function get_result(src_win, nr)
    ey._validate_win(src_win, true)
    ey._validate_list_nr(nr)

    -- The output return of set_list might be used by history and navigation functions that
    -- do not treat 0 counts as the current list. Convert here
    if nr == 0 then return M._get_list(src_win, { nr = 0 }).nr end

    local max_nr = M._get_list(src_win, { nr = "$" }).nr

    if nr == "$" then return max_nr end

    assert(type(nr) == "number")
    return math.min(nr, max_nr)
end

---@param src_win integer|nil
---@return integer
local function del_all(src_win)
    ey._validate_win(src_win, true)

    if not src_win then
        local result = fn.setqflist({}, "f") ---@type integer
        if result == 0 and eu._get_g_var("qfr_close_on_stack_clear") then
            eo._close_qfwins({ all_tabpages = true })
        end

        return result
    end

    local qf_id = fn.getloclist(src_win, { id = 0 }).id ---@type integer
    local result = fn.setloclist(src_win, {}, "f") ---@type integer
    if result == 0 and eu._get_g_var("qfr_close_on_stack_clear") then
        eo._close_loclists_by_qf_id(qf_id, { all_tabpages = true })
    end

    return result
end

---@param src_win integer|nil
---@param action QfrAction
---@param what QfrWhat
---@return integer
function M._set_list(src_win, action, what)
    ey._validate_win(src_win, true)
    ey._validate_action(action)
    ey._validate_what(what)

    if action == "f" then return del_all(src_win) end

    local what_set = vim.deepcopy(what, true) ---@type QfrWhat
    what_set.nr = resolve_list_nr(src_win, what_set.nr)

    local items_len = what_set.items and #what_set.items or 0
    local lines_len = what_set.lines and #what_set.lines or 0
    local new_len = items_len + lines_len
    local idx = what_set.idx or 1
    what_set.idx = new_len > 0 and math.min(idx, new_len) or nil

    local result = src_win and fn.setloclist(src_win, {}, action, what_set)
        or fn.setqflist({}, action, what_set)

    return result == -1 and result or get_result(src_win, what_set.nr)
end

---@param src_win integer|nil
---@param list_nr integer|"$"|nil
---@return integer
function M._clear_list(src_win, list_nr)
    ey._validate_win(src_win, true)
    ey._validate_list_nr(list_nr, true)

    local nr = resolve_list_nr(src_win, list_nr) ---@type integer|"$"

    ---@type QfrWhat
    local what = { nr = nr, context = {}, items = {}, quickfixtextfunc = "", title = "" }
    local result = src_win and fn.setloclist(src_win, {}, "r", what) or fn.setqflist({}, "r", what)
    return result == -1 and result or get_result(src_win, nr)
end

---@param output_opts QfrOutputOpts
---@return QfrOutputOpts
function M.handle_new_same_title(output_opts)
    ey._validate_output_opts(output_opts)

    if not eu._get_g_var("qfr_reuse_same_title") then return output_opts end

    if output_opts.action ~= " " then return output_opts end
    local what = output_opts.what
    if not (what.title and #what.title > 0) then return output_opts end

    local src_win = output_opts.src_win
    local max_nr = M._get_list(src_win, { nr = "$" }).nr ---@type integer
    local title_nr = nil
    for i = 1, max_nr do
        if M._get_list(src_win, { nr = i, title = 0 }).title == what.title then
            title_nr = i
            break
        end
    end

    if not title_nr then return output_opts end

    local adj_output_opts = vim.deepcopy(output_opts, true)
    adj_output_opts.what.nr = title_nr
    adj_output_opts.action = "u"

    return adj_output_opts
end

---@param src_win integer|nil
---@param what table
---@return any
function M._get_list(src_win, what)
    ey._validate_win(src_win, true)
    vim.validate("what", what, "table")

    local what_get = vim.deepcopy(what, true) ---@type table
    what_get.nr = resolve_list_nr(src_win, what_get.nr)

    return src_win and fn.getloclist(src_win, what_get) or fn.getqflist(what_get)
end

---@param src_win integer|nil
---@param stack table[]
---@return nil
function M._set_stack(src_win, stack)
    ey._validate_win(src_win, true)
    vim.validate("stack", stack, "table")

    if src_win and not eu._valid_win_for_loclist(src_win) then return end

    M._set_list(src_win, "f", {})

    for _, what in ipairs(stack) do
        M._set_list(src_win, " ", what)
    end

    if eu._get_g_var("qfr_debug_assertions") then
        local max_nr = M._get_list(src_win, { nr = "$" }).nr
        assert(#stack == max_nr)
    end
end

---@param what_ret table
---@return table
function M._what_ret_to_set(what_ret)
    local what_set = {} ---@type QfrWhat

    what_set.context = type(what_ret.context) == "table" and what_ret.context or nil
    what_set.idx = type(what_ret.idx) == "number" and what_ret.idx or nil
    what_set.items = type(what_ret.items) == "table" and what_ret.items or {}

    local qftf = what_ret.quickfixtextfunc
    local is_qftf_func = type(qftf) == "function"
    local is_qftf_str = type(qftf) == "string" and #qftf > 0
    if is_qftf_func or is_qftf_str then what_set.quickfixtextfunc = qftf end

    local title = what_ret.title
    local is_title_str = type(what_ret.title) == "string" and #title > 0
    what_set.title = is_title_str and title or nil

    return what_set
end

---@param src_win integer
---@return table[]
function M._get_stack(src_win)
    ey._validate_win(src_win, true)

    -- TODO: This should be a custom response what type
    local stack = {} ---@type table

    local max_nr = M._get_list(src_win, { nr = "$" }).nr ---@type integer
    if max_nr < 1 then return stack end

    for i = 1, max_nr do
        local what_ret = M._get_list(src_win, { nr = i, all = true }) ---@type table
        local what_set = M._what_ret_to_set(what_ret) ---@type QfrWhat
        what_set.nr = i

        stack[#stack + 1] = what_set
    end

    if eu._get_g_var("qfr_debug_assertions") then assert(#stack == max_nr) end

    return stack
end

return M

-- TODO: Docs
-- TODO: Tests

-- MID: Gated behind a g:var, re-implement the ability to add new lists inside the stack without
-- deleting the lists after by shifting the previous lists down and out. Before doing this, it is
-- necessary to properly understand the nuances of how id, nr, and action interact
-- MID: Gated behind a g:var, re-implement the ability to de-dupe list entries when adding. The
-- blocker here is that, because the underlying file data can change, proper de-duplication
-- would require pulling the old list and removing the old list entries specifically. This would
-- then also require manually setting the idx and maybe the view to match the old list. I want to
-- properly understand the nuances of how the default "a" action works first
-- MID: Gated behind a g:var (free_stack_if_nolist), re-implement the behavior where deleting the
-- last non-empty list will free the stack. Like the items above, properly integrating this
-- into a unified _set_list function (in order to keep the behavior as consistent as possible
-- with the defaults) requires a better understanding of how the built-in setlist behaves
