--- @class QfRancherSort
local M = {}

---------------
--- Wrapper ---
---------------

--- @param sort_info QfRancherSortInfo
--- @param sort_opts QfRancherSortOpts
--- @param what QfRancherWhat
--- @return nil
local function validate_sort_wrapper_input(sort_info, sort_opts, what)
    sort_info = sort_info or {}
    sort_opts = sort_opts or {}
    what = what or {}

    local ey = require("mjm.error-list-types")
    ey._validate_sort_info(sort_info)
    ey._validate_sort_opts(sort_opts)
    ey._validate_what(what)
end

--- @param sort_info QfRancherSortInfo
--- @param sort_opts QfRancherSortOpts
--- @param what QfRancherWhat
--- @return nil
local function sort_wrapper(sort_info, sort_opts, what)
    validate_sort_wrapper_input(sort_info, sort_opts, what)

    --- TODO: This should check for an open list so it can't run silently
    local src_win = what.user_data.list_win --- @type integer|nil
    local eu = require("mjm.error-list-util") --- @type QfRancherUtils
    if src_win and not eu._win_can_have_loclist(what.user_data.list_win) then
        return
    end

    local et = require("mjm.error-list-tools") --- @type QfRancherTools
    local cur_list = et._get_all(src_win, what.nr) --- @type table
    if cur_list.size < 1 then
        vim.api.nvim_echo({ { "Not enough entries to sort", "" } }, false, {})
        return
    end

    --- @type QfRancherSortPredicate
    local new_items = vim.deepcopy(cur_list.items, false) --- @type vim.quickfix.entry[]
    local predicate = sort_opts.dir == "asc" and sort_info.asc_func or sort_info.desc_func
    local what_set = vim.tbl_deep_extend("force", what, {
        context = type(cur_list.context) == "table" and cur_list.context or what.context,
        efm = cur_list.efm or what.efm,
        items = new_items,
        quickfixtextfunc = type(cur_list.quickfixtextfunc == "function")
                and cur_list.quickfixtextfunc
            or what.quickfixtextfunc,
        title = cur_list.title or what.title,
        user_data = { sort_func = predicate },
    }) --- @type QfRancherWhat

    local dest_nr = et._set_list(what_set) --- @type integer
    if vim.g.qf_rancher_auto_open_changes then
        require("mjm.error-list-stack")._history(what_set.user_data.list_win, dest_nr, {
            silent = true,
            always_open = true,
        })
    end
end

------------------
--- Sort Parts ---
------------------

--- TODO: The line numbering in the sorts is wrong

--- @type QfRancherCheckFunc
local function check_asc(a, b)
    return a < b
end

--- @type QfRancherCheckFunc
local function check_desc(a, b)
    return a > b
end

--- @param a table
--- @param b table
--- @return string|nil, string|nil
local function get_fnames(a, b)
    if not (a.bufnr and b.bufnr) then
        return nil, nil
    end

    local fname_a = vim.fn.bufname(a.bufnr) --- @type string|nil
    local fname_b = vim.fn.bufname(b.bufnr) --- @type string|nil
    return fname_a, fname_b
end

--- @param a table
--- @param b table
--- @param check QfRancherCheckFunc
--- @return boolean|nil
local function check_fname(a, b, check)
    local fname_a, fname_b = get_fnames(a, b) --- @type string|nil, string|nil
    if not (fname_a and fname_b) then
        return nil
    end

    if fname_a == fname_b then
        return nil
    else
        return check(fname_a, fname_b)
    end
end

--- @param a table
--- @param b table
--- @param check QfRancherCheckFunc
--- @return boolean|nil
local function check_lnum(a, b, check)
    local lnum_a, lnum_b = a.lnum, b.lnum --- @type integer|nil, integer|nil
    if not (lnum_a and lnum_b) then
        return nil
    end

    if lnum_a == lnum_b then
        return nil
    else
        check(lnum_a, lnum_b)
    end
end

--- @param a table
--- @param b table
--- @param check QfRancherCheckFunc
--- @return boolean|nil
local function check_col(a, b, check)
    local col_a, col_b = a.col, b.col --- @type integer|nil, integer|nil
    if not (col_a and col_b) then
        return nil
    end

    if col_a == col_b then
        return nil
    else
        return check(col_a, col_b)
    end
end

--- @param a table
--- @param b table
--- @param check QfRancherCheckFunc
--- @return boolean|nil
local function check_end_lnum(a, b, check)
    local end_lnum_a, end_lnum_b = a.end_lnum, b.end_lnum --- @type integer|nil, integer|nil
    if not (end_lnum_a and end_lnum_b) then
        return nil
    end

    if end_lnum_a == end_lnum_b then
        return nil
    else
        return check(end_lnum_a, end_lnum_b)
    end
end

--- @param a table
--- @param b table
--- @param check QfRancherCheckFunc
--- @return boolean|nil
local function check_end_col_asc(a, b, check)
    local end_col_a, end_col_b = a.end_col, b.end_col --- @type integer|nil, integer|nil
    if not (end_col_a and end_col_b) then
        return nil
    end

    if end_col_a == end_col_b then
        return nil
    else
        return check(end_col_a, end_col_b)
    end
end

--- @param a table
--- @param b table
--- @param check QfRancherCheckFunc
--- @return boolean|nil
local function check_lcol(a, b, check)
    local checked_lnum = check_lnum(a, b, check) --- @type boolean|nil
    if type(checked_lnum) == "boolean" then
        return checked_lnum
    end

    local checked_col = check_col(a, b, check) --- @type boolean|nil
    if type(checked_col) == "boolean" then
        return checked_col
    end

    local checked_end_lnum = check_end_lnum(a, b, check) --- @type boolean|nil
    if type(checked_end_lnum) == "boolean" then
        return checked_end_lnum
    end

    return check_end_col_asc(a, b, check) -- Return the nil here if we get it
end

--- @param a table
--- @param b table
--- @return boolean|nil
local function check_fname_lcol(a, b, check)
    local checked_fname = check_fname(a, b, check) --- @type boolean|nil
    if type(checked_fname) == "boolean" then
        return checked_fname
    end

    return check_lcol(a, b, check) -- Allow the nil to pass through
end

--- @param a table
--- @param b table
--- @param check QfRancherCheckFunc
--- @return boolean|nil
local function check_type(a, b, check)
    local type_a, type_b = a.type, b.type --- @type string|nil, string|nil
    if not (type_a and type_b) then
        return nil
    end

    if type_a == type_b then
        return nil
    else
        return check(type_a, type_b)
    end
end

--- @param a table
--- @param b table
--- @param check QfRancherCheckFunc
--- @return boolean|nil
local function check_lcol_type(a, b, check)
    local checked_lcol = check_lcol(a, b, check) --- @type boolean|nil
    if type(checked_lcol) == "boolean" then
        return checked_lcol
    end

    return check_type(a, b, check) -- Allow the nil to pass through
end

---@type table<string, integer>
local severity_unmap = require("mjm.error-list-util")._severity_unmap

--- @param a table
--- @param b table
--- @return integer|nil, integer|nil
local function get_severities(a, b)
    if not (a.type and b.type) then
        return nil, nil
    end

    local severity_a = severity_unmap[a.type] or nil --- @type integer|nil
    local severity_b = severity_unmap[b.type] or nil --- @type integer|nil
    return severity_a, severity_b
end

--- @param a table
--- @param b table
--- @return boolean|nil
local function check_severity(a, b, check)
    local severity_a, severity_b = get_severities(a, b) --- @type integer|nil, integer|nil
    if not (severity_a and severity_b) then
        return nil
    end

    if severity_a == severity_b then
        return nil
    else
        return check(severity_a, severity_b)
    end
end

--- @param a table
--- @param b table
--- @return boolean|nil
local function check_lcol_severity(a, b, check)
    local checked_lcol = check_lcol(a, b, check) --- @type boolean|nil
    if type(checked_lcol) == "boolean" then
        return checked_lcol
    end

    return check_severity(a, b, check) -- Allow the nil to pass through
end

-----------------
--- Sort Info ---
-----------------

--- @type QfRancherSortPredicate
function M._sort_fname_asc(a, b)
    if (not a) or not b then
        return false
    end

    local checked_fname = check_fname(a, b, check_asc) --- @type boolean|nil
    if type(checked_fname) == "boolean" then
        return checked_fname
    end

    local checked_lcol_type = check_lcol_type(a, b, check_asc) --- @type boolean|nil
    return type(checked_lcol_type) == "boolean" and checked_lcol_type or false
end

--- @type QfRancherSortPredicate
function M._sort_fname_desc(a, b)
    if (not a) or not b then
        return false
    end

    local checked_fname = check_fname(a, b, check_desc) --- @type boolean|nil
    if type(checked_fname) == "boolean" then
        return checked_fname
    end

    local checked_lcol_type = check_lcol_type(a, b, check_asc) --- @type boolean|nil
    return type(checked_lcol_type) == "boolean" and checked_lcol_type or false
end

--- @type QfRancherSortPredicate
function M._sort_type_asc(a, b)
    if (not a) or not b then
        return false
    end

    local checked_type = check_type(a, b, check_asc) --- @type boolean|nil
    if type(checked_type) == "boolean" then
        return checked_type
    end

    local checked_fname_lcol = check_fname_lcol(a, b, check_asc) --- @type boolean|nil
    return type(checked_fname_lcol) == "boolean" and checked_fname_lcol or false
end

--- @type QfRancherSortPredicate
function M._sort_type_desc(a, b)
    if (not a) or not b then
        return false
    end

    local checked_type = check_type(a, b, check_desc) --- @type boolean|nil
    if type(checked_type) == "boolean" then
        return checked_type
    end

    local checked_fname_lcol = check_fname_lcol(a, b, check_asc) --- @type boolean|nil
    return type(checked_fname_lcol) == "boolean" and checked_fname_lcol or false
end

--- @type QfRancherSortPredicate
function M._sort_severity_asc(a, b)
    if (not a) or not b then
        return false
    end

    local checked_severity = check_severity(a, b, check_asc) --- @type boolean|nil
    if type(checked_severity) == "boolean" then
        return checked_severity
    end

    local checked_fname_lcol = check_fname_lcol(a, b, check_asc) --- @type boolean|nil
    checked_fname_lcol = checked_fname_lcol == nil and false or checked_fname_lcol
    return type(checked_fname_lcol) == "boolean" and checked_fname_lcol or false
end

--- @type QfRancherSortPredicate
function M._sort_severity_desc(a, b)
    if (not a) or not b then
        return false
    end

    local checked_severity = check_severity(a, b, check_desc) --- @type boolean|nil
    if type(checked_severity) == "boolean" then
        return checked_severity
    end

    local checked_fname_lcol = check_fname_lcol(a, b, check_asc) --- @type boolean|nil
    return type(checked_fname_lcol) == "boolean" and checked_fname_lcol or false
end

--- @type QfRancherSortPredicate
function M._sort_fname_diag_asc(a, b)
    if (not a) or not b then
        return false
    end

    local checked_fname = check_fname(a, b, check_asc) --- @type boolean|nil
    if type(checked_fname) == "boolean" then
        return checked_fname
    end

    local checked_lcol_severity = check_lcol_severity(a, b, check_asc) --- @type boolean|nil
    return type(checked_lcol_severity) == "boolean" and checked_lcol_severity or false
end

--- @type QfRancherSortPredicate
function M._sort_fname_diag_desc(a, b)
    if (not a) or not b then
        return false
    end

    local checked_fname = check_fname(a, b, check_desc) --- @type boolean|nil
    if type(checked_fname) == "boolean" then
        return checked_fname
    end

    local checked_lcol_severity = check_lcol_severity(a, b, check_asc) --- @type boolean|nil
    return type(checked_lcol_severity) == "boolean" and checked_lcol_severity or false
end

-----------
--- API ---
-----------

local sorts = {
    fname = { asc_func = M._sort_fname_asc, desc_func = M._sort_fname_desc },
    fname_diag = { asc_func = M._sort_fname_diag_asc, desc_func = M._sort_fname_diag_desc },
    severity = { asc_func = M._sort_severity_asc, desc_func = M._sort_severity_desc },
    type = { asc_func = M._sort_type_asc, desc_func = M._sort_type_desc },
} --- @type table<string, QfRancherSortInfo>

--- DOCUMENT: this

--- @return string[]
function M.get_sort_names()
    return vim.tbl_keys(sorts)
end

--- DOCUMENT: Improve this?
--- Add your own sort. Can be accessed using Qsort or Lsort
--- name: The name the sort is accessed with
--- asc_func: Predicate to sort ascending. Takes two quickfix items. Returns boolean
--- asc_func: Predicate to sort descending. Takes two quickfix items. Returns boolean
--- @param name string
--- @param asc_func QfRancherSortPredicate
--- @param desc_func QfRancherSortPredicate
--- @return nil
function M.register_sort(name, asc_func, desc_func)
    sorts[name] = { asc_func = asc_func, desc_func = desc_func }
end

--- Clears the function name from the registered sorts
--- @param name string
function M.clear_sort(name)
    if #vim.tbl_keys(sorts) <= 1 then
        vim.api.nvim_echo({ { "Cannot remove the last sort method" } }, false, {})
        return
    end

    if sorts[name] then
        sorts[name] = nil
        vim.api.nvim_echo({ { name .. " removed from sort list", "" } }, true, {})
    else
        vim.api.nvim_echo({ { name .. " is not a registered sort", "" } }, true, {})
    end
end

--- Run a registered sort
--- name: The registered name of the sort to run
--- sort_opts:
--- - dir?: "asc"|"desc" Defaults to "asc"
--- what
--- - action? "new"|"replace"|"add" - Create a new list, replace a pre-existing one, or add a new
---     one
--- - is_loclist? boolean - Whether to filter against a location list
--- @param name string
--- @param sort_opts QfRancherSortOpts
--- @param what QfRancherWhat
--- @return nil
function M.sort(name, sort_opts, what)
    local sort_info = sorts[name] --- @type QfRancherSortInfo
    if not sort_info then
        vim.api.nvim_echo({ { "Invalid sort", "ErrorMsg" } }, true, { err = true })
    end

    sort_wrapper(sort_info, sort_opts, what)
end

local function sort_cmd(list_win, cargs)
    cargs = cargs or {}
    local fargs = cargs.fargs

    local sort_names = require("mjm.error-list-sort").get_sort_names()
    assert(#sort_names > 1, "No sort functions available")
    local eu = require("mjm.error-list-util") --- @type QfRancherUtils
    local sort_name = eu._check_cmd_arg(fargs, sort_names, "fname") --- @type string

    local ey = require("mjm.error-list-types") --- @type QfRancherTypes
    local dir = eu._check_cmd_arg(fargs, { "asc", "desc" }, "asc") --- @type QfRancherSortDir

    --- @type QfRancherAction
    local action = eu._check_cmd_arg(fargs, ey._actions, ey._default_action)
    --- @type QfRancherWhat
    local what = { nr = cargs.count, user_data = { action = action, list_win = list_win } }

    M.sort(sort_name, { dir = dir }, what)
end

M._q_sort = function(cargs)
    sort_cmd(nil, cargs)
end

M._l_sort = function(cargs)
    sort_cmd(vim.api.nvim_get_current_win(), cargs)
end

return M

------------
--- TODO ---
------------

--- Do the cmd map refactoring
