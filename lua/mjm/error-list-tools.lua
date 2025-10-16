--- @class QfRancherTools
local M = {}

local eo = Qfr_Defer_Require("mjm.error-list-open") --- @type QfRancherOpen
local eu = Qfr_Defer_Require("mjm.error-list-util") --- @type QfRancherUtils
local ey = Qfr_Defer_Require("mjm.error-list-types") --- @type QfRancherTypes

local api = vim.api

------------------------
--- HELPER FUNCTIONS ---
------------------------

--- @param entry table
--- @return string
local function get_qf_key(entry)
    local fname = entry.filename or "" --- @type string
    local type = entry.type or "" --- @type string
    local lnum = tostring(entry.lnum or 0) --- @type string
    local col = tostring(entry.col or 0) --- @type string
    local end_lnum = tostring(entry.end_lnum or 0) --- @type string
    local end_col = tostring(entry.end_col or 0) --- @type string
    return fname .. ":" .. type .. ":" .. lnum .. ":" .. col .. ":" .. end_lnum .. ":" .. end_col
end

--- @param a vim.quickfix.entry[]
--- @param b vim.quickfix.entry[]
--- @return vim.quickfix.entry[]
local function merge_qf_lists(a, b)
    local merged = {} --- @type table<string, boolean>
    local seen = {} --- @type table<string, boolean>

    local x = #a > #b and a or b --- @type vim.quickfix.entry[]
    local y = #a > #b and b or a --- @type vim.quickfix.entry

    for _, entry in ipairs(x) do
        local key = get_qf_key(entry) --- @type string
        seen[key] = true
        table.insert(merged, entry)
    end

    for _, entry in ipairs(y) do
        local key = get_qf_key(entry) --- @type string
        if not seen[key] then
            seen[key] = true
            table.insert(merged, entry)
        end
    end

    return merged
end

--- @param var any
--- @param var_type string
--- @return boolean
local function use_old(var, var_type)
    return type(var) == var_type and var or nil
end

--- @param new_what QfRancherWhat
--- @return QfRancherWhat
local function create_add_list_what(new_what)
    require("mjm.error-list-types")._validate_what(new_what)

    local old_all = M._get_list_all(new_what.user_data.src_win, new_what.nr) --- @type table

    local items = merge_qf_lists(old_all.items, new_what.items) --- @type vim.quickfix.entry[]
    local idx = new_what.idx or old_all.idx or nil --- @type integer|nil
    idx = idx and math.min(idx, #items)

    local add_what = {
        context = new_what.context or use_old(old_all.context, "table") or {},
        efm = new_what.efm or use_old(old_all.efm, "string"),
        idx = idx,
        items = items,
        nr = new_what.nr,
        quickfixtextfunc = new_what.quickfixtextfunc
            or use_old(old_all.quickfixtextfunc, "function"),
        title = new_what.title or use_old(old_all.title, "string"),
        user_data = new_what.user_data or nil,
    } --- @type QfRancherWhat

    if require("mjm.error-list-util")._get_g_var("qf_rancher_debug_assertions") then
        require("mjm.error-list-types")._validate_what(add_what)
    end

    return add_what
end

--- @param what QfRancherWhat
--- @return nil
local function cycle_lists_down(src_win, what)
    --- Always assert because this is a destructive, looping operation
    require("mjm.error-list-types")._validate_what(what)
    assert(what.nr > 0)
    assert(what.nr < M._get_max_list_nr(src_win))

    for i = 1, what.nr - 1 do
        local next_list = M._get_list_all(src_win, i + 1) --- @type table
        local next_what = {
            context = use_old(next_list.context, "table") or {},
            efm = use_old(next_list.efm, "string"),
            idx = use_old(next_list.idx, "number"),
            items = use_old(next_list.items, "table"),
            nr = i,
            quickfixtextfunc = use_old(next_list.quickfixtextgfunc, "function"),
            title = use_old(next_list.title, "string"),
            user_data = { action = "replace", src_win = src_win },
        } --- @type QfRancherWhat

        M._set_list(src_win, next_what)
    end
end

--- @param setlist_action "r"|" "|"a"|"f"|"u"
--- @param what QfRancherWhat
--- @return integer
local function do_set_list(src_win, setlist_action, what)
    ey._validate_setlist_action(setlist_action)
    ey._validate_what(what)

    local what_set = vim.deepcopy(what, true) --- @type QfRancherWhat
    local es = require("mjm.error-list-sort") --- @type QfRancherSort
    --- LOW: Are there conditions at which we shouldn't sort? Should it be possible to set
    --- the sort_func to vim.NIL selectively to ignore it?
    if what_set.items then
        table.sort(what_set.items, (what_set.user_data.sort_func or es._sort_fname_asc))
    end

    local max_nr_before = M._get_max_list_nr(src_win) --- @type integer
    local result = src_win and vim.fn.setloclist(src_win, {}, setlist_action, what_set)
        or vim.fn.setqflist({}, setlist_action, what_set) --- @type integer

    if result == -1 then
        --- MID: Have not seen this come up unless there's some other code error. If it does,
        --- write error handling
        return result
    end

    --- MID: There is no need to get max_nr_before again here. But I want to wait to fix it in
    --- case a more organic solution arises than passing an "append" parameter
    if setlist_action == " " and what_set.nr == max_nr_before then
        local max_nr_after = M._get_max_list_nr(src_win) --- @type integer
        return math.min(what_set.nr + 1, max_nr_after)
    end

    return what_set.nr > 0 and what_set.nr or 1
end

--- @param what QfRancherWhat
--- @return nil
local function validate_and_clean_set_list(what)
    require("mjm.error-list-types")._validate_what(what)
    ey._validate_action(what.user_data.action)

    what.id = nil
    what.lines = nil
end

------------------
--- LIST TOOLS ---
------------------

--- @param what QfRancherWhat
--- @return integer
function M._set_list(src_win, what)
    validate_and_clean_set_list(what)

    local what_set = vim.deepcopy(what, true) --- @type QfRancherWhat
    local action = what.user_data.action --- @type QfRancherAction

    local max_nr = M._get_list(src_win, { nr = "$" }).nr --- @type integer
    if max_nr == 0 then
        what_set.nr = max_nr
        return do_set_list(src_win, " ", what_set)
    end

    what_set.nr = math.min(what_set.nr, max_nr)
    if what_set.nr == 0 then
        what_set.nr = action == "new" and max_nr or M._get_cur_list_nr(src_win)
    end

    if what_set.nr == max_nr and action == "new" then
        return do_set_list(src_win, " ", what_set)
    end

    assert(what_set.nr > 0)
    if action == "add" then
        what_set = create_add_list_what(what_set)
    elseif action == "new" then
        cycle_lists_down(src_win, what_set)
    end

    return do_set_list(src_win, "r", what_set)
end

-- TODO: Just do one getlist function here. Adjust the number in place. This is already
-- wasteful and difficult to manage. It will only get worse. The trivial slowness of
-- editing the what table is not worth this
-- I am unsure how much validation to build for the what table
-- TODO: Move everything to the centralized what function
-- TODO: Create a validation for what table and add to types. Unsure exactly what to call it
-- because "get_what" could also be the result of the get statement
-- "response_what" is accurate but long. Check the docs

--- @param src_win integer
--- @param what table
--- @return any
function M._get_list(src_win, what)
    ey._validate_win(src_win, true)
    vim.validate("what", what, "table")
    vim.validate("what.nr", what.nr, function()
        return type(what.nr) == "number" or what.nr == "$"
    end)

    --- @type integer
    local max_nr = src_win and vim.fn.getloclist(src_win, { nr = "$" }).nr
        or vim.fn.getqflist({ nr = "$" }).nr

    what.nr = what.nr == "$" and max_nr or math.min(what.nr, max_nr)
    return src_win and vim.fn.getloclist(src_win, what) or vim.fn.getqflist(what)
end

--- @param src_win integer
--- @param stack table[]
--- @return nil
function M._set_stack(src_win, stack)
    ey._validate_win(src_win)
    vim.validate("stack", stack, "table")

    -- TODO: Outline this and use where needed. _set_list being the most obvious
    if src_win then
        local src_wintype = vim.fn.win_gettype(src_win)
        if src_wintype ~= "" then
            local msg = "Win "
                .. src_win
                .. " with type "
                .. src_wintype
                .. " cannot have a location list"
            vim.api.nvim_echo({ { msg, "ErrorMsg" } }, true, { err = true })
            return
        end
    end

    M._del_all(src_win, false)

    -- TODO: Again, need typing for the "get" what values
    -- I am torn on whether or not to make a "what to what" function
    for _, list in ipairs(stack) do
        local what = vim.deepcopy(list) --- @type table
        M._set_list(src_win, what)
    end

    if eu._get_g_var("qf_rancher_debug_assertions") then
        local max_nr = vim.fn.getloclist(src_win, { nr = "$" }).nr
        assert(#stack == max_nr)
    end
end

--- @param what_return table
--- @return table
local function what_to_what(what_return)
    local what_set = {} --- @type vim.fn.setqflist.what

    what_set.context = type(what_return.context) == "table" and what_return.context or nil
    what_set.idx = type(what_return.idx) == "number" and what_return.idx or nil
    what_set.items = type(what_return.items) == "table" and what_return.items or nil
    what_set.quickfixtextfunc = type(what_return.quickfixtextfunc) == "function"
            and what_return.quickfixtextfunc
        or nil

    what_set.title = type(what_return.title) == "string" and what_return.title or nil

    return what_set
end

--- @param src_win integer
--- @return table[]
function M._get_stack(src_win)
    ey._validate_win(src_win)

    -- TODO: This should be a custom response what type
    local stack = {} --- @type table

    --- @type integer
    local max_nr = src_win and vim.fn.getloclist(src_win, { nr = "$" }).nr
        or vim.fn.getqflist({ nr = "$" }).nr

    if max_nr < 1 then return stack end

    for i = 1, max_nr do
        local what_return = M._get_list(src_win, { nr = i, all = true }) --- @type table
        local what_set = what_to_what(what_return)
        what_set.nr = i
        what_set.user_data = {}
        what_set.user_data.action = "new"

        stack[#stack + 1] = what_set
    end

    if eu._get_g_var("qf_rancher_debug_assertions") then assert(#stack == max_nr) end

    return stack
end

--- @param src_win integer|nil
--- @param nr integer
--- @return table
function M._get_list_all(src_win, nr)
    local ev = require("mjm.error-list-types")
    ev._validate_win(src_win, true)
    ev._validate_uint(nr)

    return src_win and vim.fn.getloclist(src_win, { nr = nr, all = true })
        or vim.fn.getqflist({ nr = nr, all = true })
end

--- @param src_win integer|nil
--- @param nr integer
--- @return vim.quickfix.entry[]
function M._get_list_items(src_win, nr)
    local ev = require("mjm.error-list-types")
    ev._validate_win(src_win, true)
    ev._validate_uint(nr)

    return src_win and vim.fn.getloclist(src_win) or vim.fn.getqflist()
end

--- @param src_win integer|nil
--- @return integer
function M._get_cur_list_nr(src_win)
    require("mjm.error-list-types")._validate_win(src_win, true)
    return src_win and vim.fn.getloclist(src_win, { nr = 0 }).nr or vim.fn.getqflist({ nr = 0 }).nr
end

--- @param src_win integer|nil
--- @return integer
function M._get_max_list_nr(src_win)
    require("mjm.error-list-types")._validate_win(src_win, true)
    return src_win and vim.fn.getloclist(src_win, { nr = "$" }).nr
        or vim.fn.getqflist({ nr = "$" }).nr
end

--- @param src_win integer|nil
--- @param nr integer
--- @return integer|nil
function M._get_list_size(src_win, nr)
    ey._validate_win(src_win, true)
    ey._validate_uint(nr)

    if src_win then
        local qf_id = vim.fn.getloclist(src_win, { id = 0 }).id --- @type integer
        if qf_id == 0 then
            api.nvim_echo({ { "Current window has no location list", "" } }, false, {})
            return nil
        end
    end

    local max_nr = M._get_max_list_nr(src_win) --- @type integer
    if max_nr == 0 then
        -- api.nvim_echo({ { "No list stack", "" } }, false, {})
        return nil
    end

    local adj_nr = math.min(nr, max_nr) --- @type integer
    return src_win and vim.fn.getloclist(src_win, { nr = adj_nr, size = 0 }).size
        or vim.fn.getqflist({ nr = adj_nr, size = 0 }).size
end

--- @param src_win integer|nil
--- @param nr integer
--- @return integer|nil
function M._get_list_idx(src_win, nr)
    ey._validate_win(src_win, true)
    ey._validate_uint(nr)

    if src_win then
        local qf_id = vim.fn.getloclist(src_win, { id = 0 }).id --- @type integer
        if qf_id == 0 then
            api.nvim_echo({ { "Current window has no location list", "" } }, false, {})
            return nil
        end
    end

    local max_nr = M._get_max_list_nr(src_win) --- @type integer
    if max_nr == 0 then
        -- api.nvim_echo({ { "No list stack", "" } }, false, {})
        return nil
    end

    local adj_nr = math.min(nr, max_nr) --- @type integer
    return src_win and vim.fn.getloclist(src_win, { nr = adj_nr, idx = 0 }).idx
        or vim.fn.getqflist({ nr = adj_nr, idx = 0 }).idx
end

--- NOTE: For the delete functions, we want to return the list_nr that was deleted, 0 for the
--- whole stack, and -1 on failure

--- @param src_win integer|nil
--- @param close_wins? boolean
--- @return integer
function M._del_all(src_win, close_wins)
    require("mjm.error-list-types")._validate_win(src_win, true)
    vim.validate("close_wins", close_wins, "boolean", true)

    if not src_win then
        local result = vim.fn.setqflist({}, "f") --- @type integer
        if result == 0 and close_wins then eo._close_qfwins({ all_tabpages = true }) end

        return result
    end

    local qf_id = vim.fn.getloclist(src_win, { id = 0 }).id --- @type integer
    local result = vim.fn.setloclist(src_win, {}, "f") --- @type integer
    if result == -1 then
        return result
    else
        if close_wins then eo._close_loclists_by_qf_id(qf_id, { all_tabpages = true }) end
        return 0
    end
end

--- @param src_win integer|nil
--- @param count integer
--- @return integer
function M._del_list(src_win, count)
    ey._validate_win(src_win, true)
    ey._validate_uint(count)

    if src_win and vim.fn.getloclist(src_win, { id = 0 }).id == 0 then
        api.nvim_echo({ { "Current window has no location list", "" } }, false, {})
        return -1
    end

    local max_nr = M._get_max_list_nr(src_win) --- @type integer
    if max_nr == 0 then
        api.nvim_echo({ { "Stack is empty", "" } }, false, {})
        return -1
    end

    local adj_count = math.min(count, max_nr) --- @type integer
    local cur_list_nr = M._get_cur_list_nr(src_win) --- @type integer
    adj_count = adj_count == 0 and cur_list_nr or adj_count
    if require("mjm.error-list-util")._get_g_var("qf_rancher_del_all_if_empty") then
        local max_other_size = 0 --- @type integer
        for i = 1, max_nr do
            if i ~= adj_count then
                local this_size = M._get_list_size(src_win, i) --- @type integer|nil
                max_other_size = (this_size and this_size > max_other_size) and this_size
                    or max_other_size
            end
        end

        if max_nr == 1 or max_other_size == 0 then return M._del_all(src_win, true) end
    end

    -- MID: This doesn't purge title
    if adj_count == cur_list_nr then
        --- @type integer
        local result = src_win and vim.fn.setloclist(src_win, {}, "r") or vim.fn.setqflist({}, "r")
        return result == -1 and result or adj_count
    end

    local del_list_data = {
        context = {},
        efm = "",
        idx = 0,
        items = {},
        nr = adj_count,
        quickfixtextfunc = nil,
        title = "",
        user_data = nil,
    } --- @type QfRancherWhat

    local result = src_win and vim.fn.setloclist(src_win, {}, "r", del_list_data)
        or vim.fn.setqflist({}, "r", del_list_data) --- @type integer
    return result == -1 and result or adj_count
end

return M

------------
--- TODO ---
------------

--- Add a what user_data option to save and restore the view of the current src_win

-----------
--- MID ---
-----------

--- The view should have a functionality similar to the filter view saving, where the idx and
---     view can be moved up based on the change in list size. The problem is knowing which rows
---     were removed above the row/idx, which I'm not sure you can do without re-comparing the
---     lists. You can also pass this down as userdata, but this gets us back to the original
---     problem where callers are maintaining their own records of the list in addition to the
---     set function

----------
--- PR ---
----------
