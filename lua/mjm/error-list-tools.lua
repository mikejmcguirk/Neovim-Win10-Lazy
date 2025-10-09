--- @class QfRancherTools
local M = {}

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
    if vim.g.qf_rancher_debug_assertions then
        require("mjm.error-list-types")._validate_what(new_what)
    end

    local old_all = M._get_all(new_what.user_data.src_win, new_what.nr) --- @type table

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

    if vim.g.qf_rancher_debug_assertions then
        require("mjm.error-list-types")._validate_what(add_what)
    end

    return add_what
end

--- @param what QfRancherWhat
--- @return nil
local function cycle_lists_down(what)
    --- Always assert because this is a destructive, looping operation
    require("mjm.error-list-types")._validate_what(what)
    assert(what.nr > 0)
    local src_win = what.user_data.src_win --- @type integer|nil
    assert(what.nr < M._get_max_list_nr(src_win))

    for i = 1, what.nr - 1 do
        local next_list = M._get_all(src_win, i + 1) --- @type table
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

        M._set_list(next_what)
    end
end

--- @param setlist_action "r"|" "|"a"|"f"|"u"
--- @param what QfRancherWhat
--- @return integer
local function do_set_list(setlist_action, what)
    if vim.g.qf_rancher_debug_assertions then
        local ey = require("mjm.error-list-types") --- @type QfRancherTypes
        ey._validate_setlist_action(setlist_action)
        ey._validate_what(what)
    end

    local what_set = vim.deepcopy(what, true) --- @type QfRancherWhat
    local es = require("mjm.error-list-sort") --- @type QfRancherSort
    --- LOW: Are there conditions at which we shouldn't sort? Should it be possible to set
    --- the sort_func to vim.NIL selectively to ignore it?
    table.sort(what_set.items, what_set.user_data.sort_func or es._sort_fname_asc)

    local src_win = what_set.user_data.src_win --- @type integer|nil
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
    what.id = nil
    what.lines = nil
end

------------------
--- LIST TOOLS ---
------------------

--- @param what QfRancherWhat
--- @return integer
function M._set_list(what)
    validate_and_clean_set_list(what)

    local what_set = vim.deepcopy(what, true) --- @type QfRancherWhat
    local src_win = what.user_data.src_win --- @type integer|nil
    local action = what.user_data.action --- @type QfRancherAction

    local max_nr = M._get_max_list_nr(src_win) --- @type integer
    if max_nr == 0 then
        what_set.nr = max_nr
        return do_set_list(" ", what_set)
    end

    what_set.nr = math.min(what_set.nr, max_nr)
    if what_set.nr == 0 then
        what_set.nr = action == "new" and max_nr or M._get_cur_list_nr(src_win)
    end

    if what_set.nr == max_nr and action == "new" then
        return do_set_list(" ", what_set)
    end

    assert(what_set.nr > 0)
    if action == "add" then
        what_set = create_add_list_what(what_set)
    elseif action == "new" then
        cycle_lists_down(what_set)
    end

    return do_set_list("r", what_set)
end

--- NOTE: Prefer making new functions here rather than passing the what table down to get data.
--- Using the what table for getting and setting makes managing it more complicated

--- @param win integer|nil
--- @param nr integer
--- @return table
function M._get_all(win, nr)
    if vim.g.qf_rancher_debug_assertions then
        local ev = require("mjm.error-list-types")
        ev._validate_win(win, true)
        ev._validate_list_nr(nr)
    end

    return win and vim.fn.getloclist(win, { nr = nr, all = true })
        or vim.fn.getqflist({ nr = nr, all = true })
end

--- @param win integer|nil
--- @return integer
function M._get_cur_list_nr(win)
    if vim.g.qf_rancher_debug_assertions then
        require("mjm.error-list-types")._validate_win(win, true)
    end

    return win and vim.fn.getloclist(win, { nr = 0 }).nr or vim.fn.getqflist({ nr = 0 }).nr
end

--- @param win integer|nil
--- @return integer
function M._get_max_list_nr(win)
    if vim.g.qf_rancher_debug_assertions then
        require("mjm.error-list-types")._validate_win(win, true)
    end

    return win and vim.fn.getloclist(win, { nr = "$" }).nr or vim.fn.getqflist({ nr = "$" }).nr
end

--- MID: If we have to make another getlist query, do some kind of more unified interface
--- The simplest solution is a getlist function that takes an integer|nil win value
--- The issue is handling the nr validation. This can be done with a tbl_extend, but feels
--- contrived. Also the issue of getting back a specific property. Can handle with
--- something like return list_info[property]

--- @param win integer|nil
--- @param nr integer
--- @return integer|nil
function M._get_list_size(win, nr)
    if vim.g.qf_rancher_debug_assertions then
        local ey = require("mjm.error-list-types") --- @type QfRancherTypes
        ey._validate_win(win, true)
        ey._validate_list_nr(nr)
    end

    if win then
        local qf_id = vim.fn.getloclist(win, { id = 0 }).id --- @type integer
        if qf_id == 0 then
            vim.api.nvim_echo({ { "Current window has no location list", "" } }, false, {})
            return nil
        end
    end

    local max_nr = M._get_max_list_nr(win) --- @type integer
    if max_nr == 0 then
        -- vim.api.nvim_echo({ { "No list stack", "" } }, false, {})
        return nil
    end

    local adj_nr = math.min(nr, max_nr) --- @type integer
    return win and vim.fn.getloclist(win, { nr = adj_nr, size = 0 }).size
        or vim.fn.getqflist({ nr = adj_nr, size = 0 }).size
end

--- @param win integer|nil
--- @param nr integer
--- @return integer|nil
function M._get_list_idx(win, nr)
    if vim.g.qf_rancher_debug_assertions then
        local ey = require("mjm.error-list-types") --- @type QfRancherTypes
        ey._validate_win(win, true)
        ey._validate_list_nr(nr)
    end

    if win then
        local qf_id = vim.fn.getloclist(win, { id = 0 }).id --- @type integer
        if qf_id == 0 then
            vim.api.nvim_echo({ { "Current window has no location list", "" } }, false, {})
            return nil
        end
    end

    local max_nr = M._get_max_list_nr(win) --- @type integer
    if max_nr == 0 then
        -- vim.api.nvim_echo({ { "No list stack", "" } }, false, {})
        return nil
    end

    local adj_nr = math.min(nr, max_nr) --- @type integer
    return win and vim.fn.getloclist(win, { nr = adj_nr, idx = 0 }).idx
        or vim.fn.getqflist({ nr = adj_nr, idx = 0 }).idx
end

--- NOTE: For the delete functions, we want to return the list_nr that was deleted, 0 for the
--- whole stack, and -1 on failure

--- @param win integer|nil
--- @return integer
function M._del_all(win)
    if vim.g.qf_rancher_debug_assertions then
        require("mjm.error-list-types")._validate_win(win, true)
    end

    local max_nr = M._get_cur_list_nr(win) --- @type integer
    if max_nr < 1 then
        vim.api.nvim_echo({ { "No list stack", "" } }, false, {})
        return -1
    end

    local eo = require("mjm.error-list-open") --- @type QfRancherOpen
    if not win then
        local result = vim.fn.setqflist({}, "f") --- @type integer
        if result == -1 then
            return result
        end

        eo._close_qfwins({ all_tabpages = true })
        return 0
    end

    --- MAYBE: Make an option for whether or not to automatically close the list window after
    --- deleting the stack. Biggest issue is that an open loclist window without a stack
    --- (qf_id == 0) is stale data. And there's no reason for the qflist to behave inconsistently

    local qf_id = vim.fn.getloclist(win, { id = 0 }).id --- @type integer
    if qf_id == 0 then
        vim.api.nvim_echo({ { "Current window has no location list", "" } }, false, {})
        return -1
    end

    --- @type integer|nil
    local ll_win = require("mjm.error-list-util")._get_ll_win_by_qf_id(qf_id, {})
    local result = vim.fn.setloclist(win, {}, "f") --- @type integer
    if result == -1 then
        return result
    else
        if ll_win then
            eo._close_win_save_views(ll_win)
        end

        --- Should not happen, but verify no junk data
        eo._close_loclists_by_qf_id(qf_id, { all_tabpages = true })
        return 0
    end
end

--- @param win integer|nil
--- @param count integer
--- @return integer
function M._del_list(win, count)
    if vim.g.qf_rancher_debug_assertions then
        local ey = require("mjm.error-list-types")
        ey._validate_win(win, true)
        ey._validate_count(count)
    end

    if win and vim.fn.getloclist(win, { id = 0 }).id == 0 then
        vim.api.nvim_echo({ { "Current window has no location list", "" } }, false, {})
        return -1
    end

    local max_nr = M._get_max_list_nr(win) --- @type integer
    if max_nr == 0 then
        vim.api.nvim_echo({ { "Stack is empty", "" } }, false, {})
        return -1
    end

    local adj_count = math.min(count, max_nr) --- @type integer
    local cur_list_nr = M._get_cur_list_nr(win) --- @type integer
    adj_count = adj_count == 0 and cur_list_nr or adj_count
    if vim.g.qf_rancher_del_all_if_empty then
        local max_other_size = 0 --- @type integer
        for i = 1, max_nr do
            if i ~= adj_count then
                local this_size = M._get_list_size(win, i) --- @type integer|nil
                max_other_size = (this_size and this_size > max_other_size) and this_size
                    or max_other_size
            end
        end

        if max_nr == 1 or max_other_size == 0 then
            return M._del_all(win)
        end
    end

    -- MID: This doesn't purge title
    if adj_count == cur_list_nr then
        --- @type integer
        local result = win and vim.fn.setloclist(win, {}, "r") or vim.fn.setqflist({}, "r")
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

    local result = win and vim.fn.setloclist(win, {}, "r", del_list_data)
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
