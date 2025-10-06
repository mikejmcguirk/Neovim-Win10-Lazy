--- @class QfRancherTools
local M = {}

-------------
--- TYPES ---
-------------

------------------------
--- HELPER FUNCTIONS ---
------------------------

--- @param old_all table
--- @param new_what vim.fn.setqflist.what
local function create_add_list_what(old_all, new_what)
    local items = require("mjm.error-list-util")._merge_qf_lists(old_all.items, new_what.items)
    local es = require("mjm.error-list-sort")
    ---@diagnostic disable-next-line: undefined-field
    local sort_func = new_what.user_data.diag_sort == true and es._sort_fname_asc
        or es._sort_fname_diag_asc
    table.sort(items, sort_func)

    local idx = new_what.idx or old_all.idx or nil
    idx = math.min(idx, #items)

    local add_what = M._create_what_table({
        context = new_what.context or old_all.context or {},
        efm = old_all.efm or new_what.efm or nil,
        idx = idx,
        items = items,
        lines = nil,
        quickfixtextfunc = new_what.quickfixtextfunc or old_all.quickfixtextfunc or nil,
        title = new_what.title or old_all.title or nil,
    })

    return vim.tbl_extend("force", new_what, add_what)
end

--- @param list_nr integer
--- @return nil
local function cycle_lists_down(win, list_nr)
    if vim.g.qf_rancher_debug_assertions then
        local ev = require("mjm.error-list-validation")
        ev._validate_win(win, true)
        ev._validate_list_nr(list_nr, false)
        assert(list_nr <= M._get_list_stack_len(win))
    end

    for i = 1, list_nr - 1 do
        local next_list = M._get_list(win, i + 1, { all = true })
        M._set_list(win, i, "replace", next_list)
    end
end

--- @param win integer|nil
--- @param list_nr integer|string
local function resolve_list_nr(win, list_nr)
    local ev = require("mjm.error-list-validation")
    ev._validate_win(win, true)
    ev._validate_list_nr(list_nr, true)
    return win and vim.fn.getloclist(win, { nr = list_nr }).nr
        or vim.fn.getqflist({ nr = list_nr }).nr
end

--- @param win integer|nil
--- @param list_nr integer|"$"
--- @param setlist_action "r"|" "|"a"|"f"|"u"
--- @param what vim.fn.setqflist.what
local function do_set_list(win, list_nr, setlist_action, what)
    local ev = require("mjm.error-list-validation")
    ev._validate_win(win, true)
    ev._validate_list_nr(list_nr, true)
    vim.validate("setlist_action", setlist_action, "string")
    ev._validate_what(what)

    local what_set = vim.deepcopy(what, true)
    what_set = vim.tbl_extend("force", what_set, { nr = list_nr })
    local result = win and vim.fn.setloclist(win, {}, "r", what_set)
        or vim.fn.setqflist({}, "r", what_set) --- @type integer
    return result == -1 and result or resolve_list_nr(win, list_nr)
end

--- TODO: The code needs to be strict about the fact that the "$" list nr is only to be used for
--- internal purposes, and not within the general business logic

local function validate_set_list(win, list_nr, action, what)
    local ev = require("mjm.error-list-validation")
    ev._validate_win(win, true)
    ev._validate_list_nr(list_nr, false)
    ev._validate_action(action)
    ev._validate_what_strict(what)
    vim.validate("what.id", what.id, "nil")
    vim.validate("what.lines", what.lines, "nil")
    vim.validate("what.nr", what.nr, "nil")
end

------------------
--- LIST TOOLS ---
------------------

--- @param opts vim.fn.setqflist.what
--- @return vim.fn.setqflist.what
function M._create_what_table(opts)
    opts = opts or {}
    local what = {}

    what.context = opts.context or {}
    what.efm = opts.efm or nil
    what.id = nil
    what.idx = opts.idx or nil
    what.items = opts.items or nil
    what.lines = opts.lines or nil
    what.nr = nil
    what.quickfixtextfunc = opts.quickfixtextfunc or nil
    what.title = opts.title or ""
    ---@diagnostic disable-next-line: undefined-field
    what.user_data = opts.user_data or nil

    if vim.g.qf_rancher_debug_assertions then
        require("mjm.error-list-validation")._validate_what_strict(what)
    end

    return what
end

--- @param win integer|nil
--- @param list_nr integer
--- @param action QfRancherAction
--- @param what vim.fn.setqflist.what
--- @return integer
function M._set_list(win, list_nr, action, what)
    what = what or {}
    validate_set_list(win, list_nr, action, what)

    local stack_len = M._get_list_stack_len(win) --- @type integer
    if stack_len == 0 then
        return do_set_list(win, "$", " ", what)
    end

    local what_set = vim.deepcopy(what, true) --- @type vim.fn.setqflist.what
    local set_list_nr = list_nr == 0 and M._get_cur_stack_nr(win) or list_nr --- @type integer
    set_list_nr = math.min(set_list_nr, stack_len) --- @type integer

    if action == "new" and set_list_nr < stack_len then
        cycle_lists_down(win, set_list_nr)
        return do_set_list(win, set_list_nr, "r", what_set)
    end

    if action == "add" then
        local cur_list = M._get_list(win, set_list_nr, { all = true }) --- @type table
        what_set = create_add_list_what(cur_list, what_set)
    end

    if action == "add" or action == "replace" then
        return do_set_list(win, set_list_nr, "r", what_set)
    end

    return do_set_list(win, "$", " ", what_set)
end

--- LOW: Create a type and validation for the getqflist return
--- MID: Need to make a validation for the what items that can handle zero values to get the
--- current values
--- TODO: Maybe restrict the validation for the get_qflist what table

--- @param win integer|nil
--- @param list_nr integer
--- @param what table
--- @return table
function M._get_list(win, list_nr, what)
    if vim.g.qf_rancher_debug_assertions then
        local ev = require("mjm.error-list-validation")
        ev._validate_win(win, true)
        ev._validate_list_nr(list_nr, false)
    end

    local what_get = vim.tbl_extend("force", what, { nr = list_nr })
    if win then
        return vim.fn.getloclist(win, what_get)
    else
        return vim.fn.getqflist(what_get)
    end
end

--- @return nil
function M._clear_list_stack(win)
    if not win then
        vim.fn.setqflist({}, "f")
        require("mjm.error-list-open")._close_all_qf_wins()
        return
    end

    local qf_id = vim.fn.getloclist(win, { id = 0 }).id
    vim.fn.setloclsit(win, {}, "f")
    require("mjm.error-list-open")._close_all_loclists_by_qf_id(qf_id)
end

--- @param win integer|nil
--- @return integer
function M._get_cur_stack_nr(win)
    if win then
        return vim.fn.getloclist(win, { nr = 0 }).nr
    else
        return vim.fn.getqflist({ nr = 0 }).nr
    end
end

--- @param win integer|nil
--- @return integer
function M._get_list_stack_len(win)
    if win then
        return vim.fn.getloclist(win, { nr = "$" }).nr
    else
        return vim.fn.getqflist({ nr = "$" }).nr
    end
end

return M

-----------
--- MID ---
-----------

--- Tighter validation for qf entries. Issue is how to handle multi-line errors like from compilers

----------
--- PR ---
----------

--- Update the what annotation to inclucde the user_data field
