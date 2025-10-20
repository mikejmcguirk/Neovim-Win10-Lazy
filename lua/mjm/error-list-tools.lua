---@class QfrTools
local M = {}

local eo = Qfr_Defer_Require("mjm.error-list-open") ---@type QfRancherOpen
local ey = Qfr_Defer_Require("mjm.error-list-types") ---@type QfrTypes
local eu = Qfr_Defer_Require("mjm.error-list-util") ---@type QfrUtil

-- TODO: Replace my bespoke actions with "a"/"u"|"r"/" "
-- There will still need to be translation, but it will allow things to better conform with the
-- built-in data types, making the API more easily grokkable
--
-- We need to think through the actual conditions:
-- a qf_id for a quickfix set ties to a specific list
-- a non-zero nr value ties to a specific list for qf and loclists
-- "$" is the highest list_nr
-- 0 is the current list
-- For qflists, the doc says to prefer ID rather than nr
-- But looking at the code, qf_ids are converted to numbers, and this would create an inconsistency
-- with loclists, so, iunno

-- NOTE: While the docs say to prefer qf_id for setting qflists, the code resolves qf_id values to
-- nr values, and doing sets by qf_id would make handling new lists contrived

---@param src_win integer|nil
---@param nr integer|"$"|nil
---@return integer|"$"
local function resolve_list_nr(src_win, nr)
    ey._validate_win(src_win, true)
    ey._validate_list_nr(nr, true)

    if not nr then return 0 end
    if type(nr) == "string" then return nr end
    if nr == 0 then return nr end

    local max_nr = M._get_list(src_win, { nr = "$" }).nr ---@type integer
    ---@diagnostic disable-next-line: param-type-mismatch, return-type-mismatch
    return math.min(nr, max_nr)
end

-- TODO: The close_wins behavior should be behind a g var
-- TODO: This should be local, but need to fix the refs to it first

---@param src_win integer|nil
---@return integer
local function del_all(src_win)
    ey._validate_win(src_win, true)

    if not src_win then
        local result = vim.fn.setqflist({}, "f") ---@type integer
        if result == 0 then eo._close_qfwins({ all_tabpages = true }) end
        return result
    end

    local qf_id = vim.fn.getloclist(src_win, { id = 0 }).id ---@type integer
    local result = vim.fn.setloclist(src_win, {}, "f") ---@type integer
    if result == 0 then eo._close_loclists_by_qf_id(qf_id, { all_tabpages = true }) end
    return result
end

---@param src_win integer|nil
---@param action QfrRealAction
---@param what QfrWhat
---@return integer
function M._set_list(src_win, action, what)
    ey._validate_win(src_win, true)
    ey._validate_real_action(action)
    ey._validate_what(what)

    if action == "f" then return del_all(src_win) end

    local what_set = vim.deepcopy(what, true) ---@type QfrWhat
    what_set.nr = resolve_list_nr(src_win, what_set.nr)

    local result = src_win and vim.fn.setloclist(src_win, {}, action, what_set)
        or vim.fn.setqflist({}, action, what_set)

    return result == -1 and result or M._get_list(src_win, { nr = what_set.nr }).nr
end

---@param src_win integer|nil
---@param what table
---@return any
function M._get_list(src_win, what)
    ey._validate_win(src_win, true)
    vim.validate("what", what, "table")

    local what_set = vim.deepcopy(what, true) ---@type QfrWhat
    what_set.nr = resolve_list_nr(src_win, what_set.nr)

    return src_win and vim.fn.getloclist(src_win, what_set) or vim.fn.getqflist(what_set)
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

    if eu._get_g_var("qf_rancher_debug_assertions") then
        local max_nr = M._get_list(src_win, { nr = "$" }).nr
        assert(#stack == max_nr)
    end
end

---@param what_get table
---@return table
local function what_get_to_set(what_get)
    local what_set = {} ---@type vim.fn.setqflist.what

    what_set.context = type(what_get.context) == "table" and what_get.context or nil
    what_set.idx = type(what_get.idx) == "number" and what_get.idx or nil
    what_set.items = type(what_get.items) == "table" and what_get.items or nil
    what_set.quickfixtextfunc = type(what_get.quickfixtextfunc) == "function"
            and what_get.quickfixtextfunc
        or nil

    what_set.title = type(what_get.title) == "string" and what_get.title or nil

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
        local what_get = M._get_list(src_win, { nr = i, all = true }) ---@type table
        local what_set = what_get_to_set(what_get)
        what_set.nr = i
        what_set.user_data = {}
        what_set.user_data.action = "new"

        stack[#stack + 1] = what_set
    end

    if eu._get_g_var("qf_rancher_debug_assertions") then assert(#stack == max_nr) end

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
-- MID: Gated behind a g:var (free_stack_if_list), re-implement the behavior where deleting the
-- last non-empty list will free the stack. Like the items above, properly integrating this
-- into a unified _set_list function (in order to keep the behavior as consistent as possible
-- with the defaults) requires a better understanding of how the built-in setlist behaves
