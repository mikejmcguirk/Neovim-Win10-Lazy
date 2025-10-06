--- @class QfRancherSort
local M = {}

-------------
--- Types ---
-------------

--- @alias QfRancherSortPredicate fun(table, table): boolean

--- @class QfRancherSortInfo
--- @field asc_func QfRancherSortPredicate
--- @field desc_func QfRancherSortPredicate

--- @alias QfRancherSortDir "asc"|"desc"

--- @class QfRancherSortOpts
--- @field dir? QfRancherSortDir
---
--- @alias QfRancherSortable string|integer
--- @alias QfRancherCheckFunc fun(QfRancherSortable, QfRancherSortable):boolean

---------------
--- Wrapper ---
---------------

--- @param dir QfRancherSortDir
--- @return boolean
local function validate_sort_dir(dir)
    return dir == "asc" or dir == "desc"
end

--- @param sort_info QfRancherSortInfo
--- @param sort_opts QfRancherSortOpts
--- @param what QfRancherWhat
--- @return nil
local function validate_sort_wrapper_input(sort_info, sort_opts, what)
    sort_info = sort_info or {}
    sort_opts = sort_opts or {}
    what = what or {}

    vim.validate("sort_info", sort_info, "table")
    vim.validate("sort_info.asc_func", sort_info.asc_func, "callable")
    vim.validate("sort_info.desc_func", sort_info.desc_func, "callable")

    vim.validate("sort_opts", sort_opts, "table")
    vim.validate("sort_opts.dir", sort_opts.dir, { "nil", "string" })
    if type(sort_opts.dir) == "string" then
        vim.validate("sort_opts.dir", sort_opts.dir, function()
            return validate_sort_dir(sort_opts.dir)
        end)
    end

    require("mjm.error-list-validation")._validate_what_strict(what)
end

--- @param sort_info QfRancherSortInfo
--- @param sort_opts QfRancherSortOpts
--- @param what QfRancherWhat
--- @return nil
local function sort_wrapper(sort_info, sort_opts, what)
    validate_sort_wrapper_input(sort_info, sort_opts, what)
    sort_opts.dir = sort_opts.dir or "asc"

    local eu = require("mjm.error-list-util") --- @type QfRancherUtils
    if not eu._win_can_have_loclist(what.user_data.list_win) then
        return
    end

    local et = require("mjm.error-list-tools") --- @type QfRancherTools
    local cur_list = et._get_list(what.user_data.list_win, what.nr, nil) --- @type table
    if cur_list.size < 1 then
        vim.api.nvim_echo({ { "Not enough entries to sort", "" } }, false, {})
        return
    end

    -- local dest_list_nr = eu._get_dest_list_nr(getlist, what) --- @type integer
    -- local list_win = eu._find_list_win(what) --- @type integer|nil
    -- local view = (list_win and dest_list_nr == cur_list.nr)
    --         and vim.api.nvim_win_call(list_win, vim.fn.winsaveview)
    --     or nil --- @type vim.fn.winsaveview.ret|nil

    local predicate = sort_opts.dir and sort_opts.dir == "asc" and sort_info.asc_func
        or sort_info.desc_func

    local new_items = vim.deepcopy(cur_list.items, false)
    table.sort(new_items, predicate)
    what.title = cur_list.title

    --- TODO: This needs to take a flag for if it should save a view. In this case, even though
    --- we're just replacing, we're bumped to line 1, so we need to save a view. If we're just
    --- adding new items (grep/diag), we usually don't need to save a view, though perhaps we
    --- should if we're merging into the list we're looking at. Filter is an interesting case
    --- beause it uses custom logic. Perhaps there the view needs to be passed down
    --- Another possibility is - set_list should go back to only handling placing the qf items, and
    --- we can avoid having to create spooky action at a distance. Since the view handling has to
    --- be between placing the items and final open anyway (or, at the very least, their logic is
    --- intermingled), maybe it's better to break opening the result into its own logic

    local what_set = vim.tbl_deep_extend("force", what, {
        items = new_items,
        title = cur_list.title,
        user_data = { diag_sort = true },
    })
    et._set_list(what_set)

    -- if list_win and view then
    --     vim.api.nvim_win_call(list_win, function()
    --         vim.fn.winrestview(view)
    --     end)
    -- end

    --- TODO: This function needs to be changed
    local use_loclist = what_set.user_data.list_win and true or false
    eu._get_openlist(use_loclist)({ always_resize = true })
end

------------------
--- Sort Parts ---
------------------

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
    local checked_lcol = check_lcol(a, b, check)
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

    local checked_fname = check_fname(a, b, check_desc)
    if type(checked_fname) == "boolean" then
        return checked_fname
    end

    local checked_lcol_type = check_lcol_type(a, b, check_asc)
    return type(checked_lcol_type) == "boolean" and checked_lcol_type or false
end

--- @type QfRancherSortPredicate
function M._sort_type_asc(a, b)
    if (not a) or not b then
        return false
    end

    local checked_type = check_type(a, b, check_asc)
    if type(checked_type) == "boolean" then
        return checked_type
    end

    local checked_fname_lcol = check_fname_lcol(a, b, check_asc)
    return type(checked_fname_lcol) == "boolean" and checked_fname_lcol or false
end

--- @type QfRancherSortPredicate
function M._sort_type_desc(a, b)
    if (not a) or not b then
        return false
    end

    local checked_type = check_type(a, b, check_desc)
    if type(checked_type) == "boolean" then
        return checked_type
    end

    local checked_fname_lcol = check_fname_lcol(a, b, check_asc)
    return type(checked_fname_lcol) == "boolean" and checked_fname_lcol or false
end

--- @type QfRancherSortPredicate
function M._sort_severity_asc(a, b)
    if (not a) or not b then
        return false
    end

    local checked_severity = check_severity(a, b, check_asc)
    if type(checked_severity) == "boolean" then
        return checked_severity
    end

    local checked_fname_lcol = check_fname_lcol(a, b, check_asc)
    checked_fname_lcol = checked_fname_lcol == nil and false or checked_fname_lcol
    return type(checked_fname_lcol) == "boolean" and checked_fname_lcol or false
end

--- @type QfRancherSortPredicate
function M._sort_severity_desc(a, b)
    if (not a) or not b then
        return false
    end

    local checked_severity = check_severity(a, b, check_desc)
    if type(checked_severity) == "boolean" then
        return checked_severity
    end

    local checked_fname_lcol = check_fname_lcol(a, b, check_asc)
    return type(checked_fname_lcol) == "boolean" and checked_fname_lcol or false
end

--- @type QfRancherSortPredicate
function M._sort_fname_diag_asc(a, b)
    if (not a) or not b then
        return false
    end

    local checked_fname = check_fname(a, b, check_asc)
    if type(checked_fname) == "boolean" then
        return checked_fname
    end

    local checked_lcol_severity = check_lcol_severity(a, b, check_asc)
    return type(checked_lcol_severity) == "boolean" and checked_lcol_severity or false
end

--- @type QfRancherSortPredicate
function M._sort_fname_diag_desc(a, b)
    if (not a) or not b then
        return false
    end

    local checked_fname = check_fname(a, b, check_desc)
    if type(checked_fname) == "boolean" then
        return checked_fname
    end

    local checked_lcol_severity = check_lcol_severity(a, b, check_asc)
    return type(checked_lcol_severity) == "boolean" and checked_lcol_severity or false
end

-----------
--- API ---
-----------

local sorts = {
    fname = { asc_func = M._sort_fname_asc, desc_func = M._sort_fname_desc },
    fname_diag = {
        asc_func = M._sort_fname_diag_asc,
        desc_func = M._sort_fname_diag_desc,
    },
    severity = { asc_func = M._sort_severity_asc, desc_func = M._sort_severity_desc },
    type = { asc_func = M._sort_type_asc, desc_func = M._sort_type_desc },
} --- @type table<string, QfRancherSortInfo>

function M.get_sort_names()
    return vim.tbl_keys(sorts)
end

--- Add your own sort. Can be accessed using Qsort or Lsort
--- name: The name the sort is accessed with
--- asc_func: Predicate to sort ascending. Takes two quickfix items. Returns boolean
--- asc_func: Predicate to sort descending. Takes two quickfix items. Returns boolean
--- @param name string
--- @param asc_func QfRancherSortPredicate
--- @param desc_func QfRancherSortPredicate
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

    sorts[name] = nil
end

--- Run a sort without registering it
--- asc_func: Predicate to sort ascending. Takes two quickfix items. Returns boolean
--- asc_func: Predicate to sort descending. Takes two quickfix items. Returns boolean
--- sort_opts:
--- - dir?: "asc"|"desc" Defaults to "asc"
--- what
--- - action? "new"|"replace"|"add" - Create a new list, replace a pre-existing one, or add a new
---     one
--- - is_loclist? boolean - Whether to filter against a location list
--- @param asc_func QfRancherSortPredicate
--- @param desc_func QfRancherSortPredicate
--- @param sort_opts QfRancherSortOpts
--- @param what QfRancherWhat
--- @return nil
function M.adhoc_sort(asc_func, desc_func, sort_opts, what)
    local sort_info = { asc_func = asc_func, desc_func = desc_func } --- @type QfRancherSortInfo
    sort_wrapper(sort_info, sort_opts, what)
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

return M

------------
--- TODO ---
------------

--- Do the cmd map refactoring
