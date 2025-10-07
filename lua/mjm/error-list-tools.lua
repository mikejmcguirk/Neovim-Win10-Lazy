--- @class QfRancherTools
local M = {}

------------------------
--- HELPER FUNCTIONS ---
------------------------

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

    local old_all = M._get_all(new_what.user_data.list_win, new_what.nr)

    --- @type vim.quickfix.entry[]
    local items = require("mjm.error-list-util")._merge_qf_lists(old_all.items, new_what.items)
    local es = require("mjm.error-list-sort") --- @type QfRancherSort
    --- TODO: If sort is moved somewhere else, this would be removed or moved
    table.sort(items, new_what.user_data.sort_func or es._sort_fname_asc)

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
    local list_win = what.user_data.list_win --- @type integer|nil
    assert(what.nr < M._get_max_list_nr(list_win))

    for i = 1, what.nr - 1 do
        local next_list = M._get_all(list_win, i + 1) --- @type table
        local next_what = {
            context = use_old(next_list.context, "table") or {},
            efm = use_old(next_list.efm, "string"),
            idx = use_old(next_list.idx, "number"),
            items = use_old(next_list.items, "table"),
            nr = i,
            quickfixtextfunc = use_old(next_list.quickfixtextgfunc, "function"),
            title = use_old(next_list.title, "string"),
            user_data = { action = "replace", list_win = list_win },
        } --- @type QfRancherWhat

        M._set_list(next_what)
    end
end

--- @param setlist_action "r"|" "|"a"|"f"|"u"
--- @param what QfRancherWhat
--- @return integer
local function do_set_list(setlist_action, what)
    if vim.g.qf_rancher_debug_assertions then
        local ey = require("mjm.error-list-types")
        ey._validate_setlist_action(setlist_action)
        ey._validate_what(what)
    end

    local list_win = what.user_data.list_win --- @type integer|nil
    local max_nr_before = M._get_max_list_nr(list_win) --- @type integer
    local result = list_win and vim.fn.setloclist(list_win, {}, setlist_action, what)
        or vim.fn.setqflist({}, setlist_action, what) --- @type integer

    if result == -1 then
        --- MID: Have not seen this come up unless there's some other code error. If it does,
        --- write error handling
        return result
    end

    --- MID: There is no need to get max_nr_before again here. But I want to wait to fix it in
    --- case a more organic solution arises than passing an "append" parameter
    if setlist_action == " " and what.nr == max_nr_before then
        local max_nr_after = M._get_max_list_nr(list_win) --- @type integer
        return math.min(what.nr + 1, max_nr_after)
    end

    return what.nr > 0 and what.nr or 1
end

--- @param what QfRancherWhat
--- @return nil
local function validate_and_clean_set_list(what)
    what = what or {}

    local ev = require("mjm.error-list-types")
    ev._validate_what(what)
    --- TODO: Add new validation here for the what user_data section
    --- A note here is that the validation for validity and the validation for performing the
    --- set are different. It is valid for every value to be nil. But for set, action at least
    --- must be present. You can do a cleanup, but I think allowing fallback on everything creates
    --- confusing assumptions

    what.id = nil
    what.lines = nil
end

------------------
--- LIST TOOLS ---
------------------

--- TODO: Since we're using the what table to carry the sort info down for diags anyway, just do
--- all sorting here. This removes the issue of calling functions having to reason about when
--- this function sorts. Instead, they can pass a sort to the what table and assume the
--- underlying logic is correctly handled
---
--- @param what QfRancherWhat
--- @return integer
function M._set_list(what)
    validate_and_clean_set_list(what)

    local what_set = vim.deepcopy(what, true) --- @type QfRancherWhat
    local list_win = what.user_data.list_win --- @type integer|nil
    local action = what.user_data.action --- @type QfRancherAction

    local max_nr = M._get_max_list_nr(list_win) --- @type integer
    if max_nr == 0 then
        what_set.nr = max_nr
        return do_set_list(" ", what_set)
    end

    what_set.nr = math.min(what_set.nr, max_nr)
    if what_set.nr == 0 then
        what_set.nr = action == "new" and max_nr or M._get_cur_list_nr(list_win)
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

    if win then
        return vim.fn.getloclist(win, { nr = nr, all = true })
    else
        return vim.fn.getqflist({ nr = nr, all = true })
    end
end

--- @param win integer|nil
--- @return integer
function M._get_cur_list_nr(win)
    if vim.g.qf_rancher_debug_assertions then
        require("mjm.error-list-types")._validate_win(win, true)
    end

    if win then
        return vim.fn.getloclist(win, { nr = 0 }).nr
    else
        return vim.fn.getqflist({ nr = 0 }).nr
    end
end

--- @param win integer|nil
--- @return integer
function M._get_max_list_nr(win)
    if vim.g.qf_rancher_debug_assertions then
        require("mjm.error-list-types")._validate_win(win, true)
    end

    if win then
        return vim.fn.getloclist(win, { nr = "$" }).nr
    else
        return vim.fn.getqflist({ nr = "$" }).nr
    end
end

--- TODO: Use in qE/lE
--- @param win integer|nil
--- @return nil
function M._clear_stack(win)
    if vim.g.qf_rancher_debug_assertions then
        require("mjm.error-list-types")._validate_win(win, true)
    end

    local eo = require("mjm.error-list-open")

    if not win then
        vim.fn.setqflist({}, "f")
        eo._close_all_qf_wins()
        return
    end

    local qf_id = vim.fn.getloclist(win, { id = 0 }).id --- @type integer
    vim.fn.setloclist(win, {}, "f")
    eo._close_all_loclists_by_qf_id(qf_id)
end

return M

------------
--- TODO ---
------------

--- Add a what user_data option to save and restore the view of the current list_win

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
