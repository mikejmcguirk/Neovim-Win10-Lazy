--- TODO:
--- - Check that all functions have reasonable default sorts
--- - Check that window height updates are triggered where appropriate
--- - Check that functions have proper visibility
--- - Check that all mappings have plugs and cmds
--- - Check that all maps/cmds/plugs have desc fieldss
--- - Check that all functions have annotations and documentation
--- - Check that the qf and loclist versions are both properly built for purpose. Should be able
---     to use the loclist function for buf/win specific info

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
--- @param output_opts QfRancherOutputOpts
--- @return nil
local function clean_wrapper_input(sort_info, sort_opts, output_opts)
    sort_info = sort_info or {}
    sort_opts = sort_opts or {}
    output_opts = output_opts or {}

    vim.validate("sort_info", sort_info, "table")
    vim.validate("sort_info.asc_func", sort_info.asc_func, "callable")
    vim.validate("sort_info.desc_func", sort_info.desc_func, "callable")

    vim.validate("sort_opts", sort_opts, "table")
    vim.validate("sort_opts.dir", sort_opts.dir, { "nil", "string" })
    if type(sort_opts.dir) == "string" then
        vim.validate("sort_opts.dir", sort_opts.dir, function()
            return validate_sort_dir(sort_opts.dir)
        end)
    else
        sort_opts.dir = "asc"
    end

    local eu = require("mjm.error-list-util")
    eu.validate_output_opts(output_opts)
end

--- @param sort_info QfRancherSortInfo
--- @param sort_opts QfRancherSortOpts
--- @param output_opts QfRancherOutputOpts
--- @return nil
function M._sort_wrapper(sort_info, sort_opts, output_opts)
    clean_wrapper_input(sort_info, sort_opts, output_opts)

    local eu = require("mjm.error-list-util") --- @type QfRancherUtils
    if not eu.check_loclist_output(output_opts) then
        return
    end

    local getlist = eu.get_getlist(output_opts) --- @type function|nil
    if not getlist then
        return
    end

    local cur_list = getlist({ all = true }) --- @type table
    if cur_list.size < 1 then
        vim.api.nvim_echo({ { "Not enough entries to sort", "" } }, false, {})
        return
    end

    -- TODO: Reudandant var, but unsure of how to handle view check
    local dest_list_nr = eu.get_dest_list_nr(getlist, output_opts) --- @type integer
    local list_win = eu.find_list_win(output_opts.is_loclist) --- @type integer|nil
    local view = (list_win and dest_list_nr == cur_list.nr)
            and vim.api.nvim_win_call(list_win, vim.fn.winsaveview)
        or nil --- @type vim.fn.winsaveview.ret|nil

    local predicate = sort_opts.dir and sort_opts.dir == "asc" and sort_info.asc_func
        or sort_info.desc_func

    table.sort(cur_list.items, predicate)
    local setlist = eu.get_setlist(output_opts) --- @type function|nil
    -- TODO: Because of nil, handle earlier
    if not setlist then
        return
    end

    output_opts.title = cur_list.title
    local set_list_opts = { getlist = getlist, setlist = setlist, new_items = cur_list.items }
    eu.set_list_items(set_list_opts, output_opts)

    -- TODO: Test if this is actually necessary
    if list_win and view then
        vim.api.nvim_win_call(list_win, function()
            vim.fn.winrestview(view)
        end)
    end

    eu.get_openlist(output_opts.is_loclist)({ always_resize = true })
end

------------------
--- Sort Parts ---
------------------

--- @param a table
--- @param b table
--- @return string|nil, string|nil
local function get_fnames(a, b)
    if not (a.bufnr and b.bufnr) then
        return nil, nil
    end

    local fname_a = vim.fn.bufname(a.bufnr)
    local fname_b = vim.fn.bufname(b.bufnr)
    return fname_a, fname_b
end

--- @param a table
--- @param b table
--- @return boolean|nil
local function check_fname_asc(a, b)
    local fname_a, fname_b = get_fnames(a, b)
    if not (fname_a and fname_b) then
        return nil
    end

    if fname_a == fname_b then
        return nil
    else
        return fname_a < fname_b
    end
end

--- @param a table
--- @param b table
--- @return boolean|nil
local function check_fname_desc(a, b)
    local fname_a, fname_b = get_fnames(a, b)
    if not (fname_a and fname_b) then
        return nil
    end

    if fname_a == fname_b then
        return nil
    else
        return fname_a > fname_b
    end
end

--- @param a table
--- @param b table
--- @return boolean|nil
local function check_lnum_asc(a, b)
    local lnum_a, lnum_b = a.lnum, b.lnum
    if not (lnum_a and lnum_b) then
        return nil
    end

    if lnum_a == lnum_b then
        return nil
    else
        return lnum_a < lnum_b
    end
end

-- --- @param a table
-- --- @param b table
-- --- @return boolean|nil
-- local function check_lnum_desc(a, b)
--     local lnum_a, lnum_b = a.lnum, b.lnum
--     if not (lnum_a and lnum_b) then
--         return nil
--     end
--
--     if lnum_a == lnum_b then
--         return nil
--     else
--         return lnum_a > lnum_b
--     end
-- end

--- @param a table
--- @param b table
--- @return boolean|nil
local function check_col_asc(a, b)
    local col_a, col_b = a.col, b.col
    if not (col_a and col_b) then
        return nil
    end

    if col_a == col_b then
        return nil
    else
        return col_a < col_b
    end
end

-- --- @param a table
-- --- @param b table
-- --- @return boolean|nil
-- local function check_col_desc(a, b)
--     local col_a, col_b = a.col, b.col
--     if not (col_a and col_b) then
--         return nil
--     end
--
--     if col_a == col_b then
--         return nil
--     else
--         return col_a > col_b
--     end
-- end

--- @param a table
--- @param b table
--- @return boolean|nil
local function check_end_lnum_asc(a, b)
    local end_lnum_a, end_lnum_b = a.end_lnum, b.end_lnum
    if not (end_lnum_a and end_lnum_b) then
        return nil
    end

    if end_lnum_a == end_lnum_b then
        return nil
    else
        return end_lnum_a < end_lnum_b
    end
end

-- --- @param a table
-- --- @param b table
-- --- @return boolean|nil
-- local function check_end_lnum_desc(a, b)
--     local end_lnum_a, end_lnum_b = a.end_lnum, b.end_lnum
--     if not (end_lnum_a and end_lnum_b) then
--         return nil
--     end
--
--     if end_lnum_a == end_lnum_b then
--         return nil
--     else
--         return end_lnum_a > end_lnum_b
--     end
-- end

--- @param a table
--- @param b table
--- @return boolean|nil
local function check_end_col_asc(a, b)
    local end_col_a, end_col_b = a.end_col, b.end_col
    if not (end_col_a and end_col_b) then
        return nil
    end

    if end_col_a == end_col_b then
        return nil
    else
        return end_col_a < end_col_b
    end
end

-- --- @param a table
-- --- @param b table
-- --- @return boolean|nil
-- local function check_end_col_desc(a, b)
--     local end_col_a, end_col_b = a.end_col, b.end_col
--     if not (end_col_a and end_col_b) then
--         return nil
--     end
--
--     if end_col_a == end_col_b then
--         return nil
--     else
--         return end_col_a > end_col_b
--     end
-- end

--- @param a table
--- @param b table
--- @return boolean|nil
local function check_lcol_asc(a, b)
    local checked_lnum = check_lnum_asc(a, b) --- @type boolean|nil
    if type(checked_lnum) == "boolean" then
        return checked_lnum
    end

    local checked_col = check_col_asc(a, b) --- @type boolean|nil
    if type(checked_col) == "boolean" then
        return checked_col
    end

    local checked_end_lnum = check_end_lnum_asc(a, b) --- @type boolean|nil
    if type(checked_end_lnum) == "boolean" then
        return checked_end_lnum
    end

    return check_end_col_asc(a, b) -- Return the nil here if we get it
end

--- @param a table
--- @param b table
--- @return boolean|nil
local function check_fname_lcol_asc(a, b)
    local checked_fname = check_fname_asc(a, b)
    if type(checked_fname) == "boolean" then
        return checked_fname
    end

    return check_lcol_asc(a, b) -- Allow the nil to pass through
end

-- --- @param a table
-- --- @param b table
-- --- @return boolean|nil
-- local function check_lcol_desc(a, b)
--     local checked_lnum = check_lnum_desc(a, b) --- @type boolean|nil
--     if type(checked_lnum) == "boolean" then
--         return checked_lnum
--     end
--
--     local checked_col = check_col_desc(a, b) --- @type boolean|nil
--     if type(checked_col) == "boolean" then
--         return checked_col
--     end
--
--     local checked_end_lnum = check_end_lnum_desc(a, b) --- @type boolean|nil
--     if type(checked_end_lnum) == "boolean" then
--         return checked_end_lnum
--     end
--
--     return check_end_col_desc(a, b) -- Return the nil here if we get it
-- end

--- @param a table
--- @param b table
--- @return boolean|nil
local function check_type_asc(a, b)
    local type_a, type_b = a.type, b.type
    if not (type_a and type_b) then
        return nil
    end

    if type_a == type_b then
        return nil
    else
        return type_a < type_b
    end
end

--- @param a table
--- @param b table
--- @return boolean|nil
local function check_type_desc(a, b)
    local type_a, type_b = a.type, b.type
    if not (type_a and type_b) then
        return nil
    end

    if type_a == type_b then
        return nil
    else
        return type_a > type_b
    end
end

--- @param a table
--- @param b table
--- @return boolean|nil
local function check_lcol_type_asc(a, b)
    local checked_lcol = check_lcol_asc(a, b)
    if type(checked_lcol) == "boolean" then
        return checked_lcol
    end

    return check_type_asc(a, b) -- Allow the nil to pass through
end

---@type table<string, integer>
local severity_unmap = require("mjm.error-list-util").severity_unmap

--- @param a table
--- @param b table
--- @return integer|nil, integer|nil
local function get_severities(a, b)
    if not (a.type and b.type) then
        return nil, nil
    end

    local severity_a = severity_unmap[a.type] or nil
    local severity_b = severity_unmap[b.type] or nil
    return severity_a, severity_b
end

--- @param a table
--- @param b table
--- @return boolean|nil
local function check_severity_asc(a, b)
    local severity_a, severity_b = get_severities(a, b)
    if not (severity_a and severity_b) then
        return nil
    end

    if severity_a == severity_b then
        return nil
    else
        return severity_a < severity_b
    end
end

--- @param a table
--- @param b table
--- @return boolean|nil
local function check_severity_desc(a, b)
    local severity_a, severity_b = get_severities(a, b)
    if not (severity_a and severity_b) then
        return nil
    end

    if severity_a == severity_b then
        return nil
    else
        return severity_a > severity_b
    end
end

--- @param a table
--- @param b table
--- @return boolean|nil
local function check_lcol_severity_asc(a, b)
    local checked_lcol = check_lcol_asc(a, b)
    if type(checked_lcol) == "boolean" then
        return checked_lcol
    end

    return check_severity_asc(a, b) -- Allow the nil to pass through
end

-----------------
--- Sort Info ---
-----------------

--- TODO: A couple situations out there that need these for merge/sort. Biggest one is set list
--- items

--- @type QfRancherSortPredicate
--- Sort list items in ascending order by fname. Fall back to line/col info asc then type asc
function M._sort_fname_asc(a, b)
    if (not a) or not b then
        return false
    end

    local checked_fname = check_fname_asc(a, b) --- @type boolean|nil
    if type(checked_fname) == "boolean" then
        return checked_fname
    end

    local checked_lcol_type = check_lcol_type_asc(a, b) --- @type boolean|nil
    return type(checked_lcol_type) == "boolean" and checked_lcol_type or false
end

--- @type QfRancherSortPredicate
--- Sort list items in descending order by fname. Fall back to line/col info asc then type asc
function M._sort_fname_desc(a, b)
    if (not a) or not b then
        return false
    end

    local checked_fname = check_fname_desc(a, b)
    if type(checked_fname) == "boolean" then
        return checked_fname
    end

    local checked_lcol_type = check_lcol_type_asc(a, b)
    return type(checked_lcol_type) == "boolean" and checked_lcol_type or false
end

--- @type QfRancherSortPredicate
--- Sort list items in ascending order by type. Fall back to fname asc then line/col info asc
function M._sort_type_asc(a, b)
    if (not a) or not b then
        return false
    end

    local checked_type = check_type_asc(a, b)
    if type(checked_type) == "boolean" then
        return checked_type
    end

    local checked_fname_lcol = check_fname_lcol_asc(a, b)
    return type(checked_fname_lcol) == "boolean" and checked_fname_lcol or false
end

--- @type QfRancherSortPredicate
--- Sort list items in descending order by type. Fall back to fname asc then line/col info asc
function M._sort_type_desc(a, b)
    if (not a) or not b then
        return false
    end

    local checked_type = check_type_desc(a, b)
    if type(checked_type) == "boolean" then
        return checked_type
    end

    local checked_fname_lcol = check_fname_lcol_asc(a, b)
    return type(checked_fname_lcol) == "boolean" and checked_fname_lcol or false
end

--- @type QfRancherSortPredicate
--- Sort by diagnostic severity ascending. Fall back to fname asc, then line/col info asc
function M._sort_severity_asc(a, b)
    if (not a) or not b then
        return false
    end

    local checked_severity = check_severity_asc(a, b)
    if type(checked_severity) == "boolean" then
        return checked_severity
    end

    local checked_fname_lcol = check_fname_lcol_asc(a, b)
    checked_fname_lcol = checked_fname_lcol == nil and false or checked_fname_lcol
    return type(checked_fname_lcol) == "boolean" and checked_fname_lcol or false
end

--- @type QfRancherSortPredicate
--- Sort by diagnostic severity descending. Fall back to fname asc, then line/col info asc
function M._sort_severity_desc(a, b)
    if (not a) or not b then
        return false
    end

    local checked_severity = check_severity_desc(a, b)
    if type(checked_severity) == "boolean" then
        return checked_severity
    end

    local checked_fname_lcol = check_fname_lcol_asc(a, b)
    return type(checked_fname_lcol) == "boolean" and checked_fname_lcol or false
end

--- @type QfRancherSortPredicate
--- Sort by fname ascending, falling back to line/col info asc then diagnostic severity asc
function M._sort_fname_diag_asc(a, b)
    if (not a) or not b then
        return false
    end

    local checked_fname = check_fname_asc(a, b)
    if type(checked_fname) == "boolean" then
        return checked_fname
    end

    local checked_lcol_severity = check_lcol_severity_asc(a, b)
    return type(checked_lcol_severity) == "boolean" and checked_lcol_severity or false
end

--- @type QfRancherSortPredicate
--- Sort by fname descending, falling back to line/col info asc then diagnostic severity asc
function M._sort_fname_diag_desc(a, b)
    if (not a) or not b then
        return false
    end

    local checked_fname = check_fname_desc(a, b)
    if type(checked_fname) == "boolean" then
        return checked_fname
    end

    local checked_lcol_severity = check_lcol_severity_asc(a, b)
    return type(checked_lcol_severity) == "boolean" and checked_lcol_severity or false
end

local sorts = {
    fname = { asc_func = M._sort_fname_asc, desc_func = M._sort_fname_desc }, --- f
    fname_diag = {
        asc_func = M._sort_fname_diag_asc,
        desc_func = M._sort_fname_diag_desc,
    }, --- if
    severity = { asc_func = M._sort_severity_asc, desc_func = M._sort_severity_desc }, --- is
    type = { asc_func = M._sort_type_asc, desc_func = M._sort_type_desc }, --- t
} --- @type table<string, QfRancherSortInfo>

function M.get_sort_names()
    return vim.tbl_keys(sorts)
end

--- @param name string
--- @param asc_func QfRancherSortPredicate
--- @param desc_func QfRancherSortPredicate
--- Add your own sort. Can be accessed using Qsort or Lsort
--- name: The name the sort is accessed with
--- asc_func: Predicate to sort ascending. Takes two quickfix items. Returns boolean
--- asc_func: Predicate to sort descending. Takes two quickfix items. Returns boolean
function M.register_sort(name, asc_func, desc_func)
    sorts[name] = { asc_func = asc_func, desc_func = desc_func }
end

--- @param name string
--- Clears the function name from the registered sorts
function M.clear_sort(name)
    if #vim.tbl_keys(sorts) <= 1 then
        vim.api.nvim_echo({ { "Cannot remove the last sort method" } }, false, {})
        return
    end

    sorts[name] = nil
end

--- @param asc_func QfRancherSortPredicate
--- @param desc_func QfRancherSortPredicate
--- @param sort_opts QfRancherSortOpts
--- @param output_opts QfRancherOutputOpts
--- @return nil
--- Run a sort without registering it
--- asc_func: Predicate to sort ascending. Takes two quickfix items. Returns boolean
--- asc_func: Predicate to sort descending. Takes two quickfix items. Returns boolean
--- sort_opts:
--- - dir?: "asc"|"desc" Defaults to "asc"
--- output_opts
--- - action? "new"|"replace"|"add" - Create a new list, replace a pre-existing one, or add a new
---     one
--- - is_loclist? boolean - Whether to filter against a location list
function M.adhoc_sort(asc_func, desc_func, sort_opts, output_opts)
    local sort_info = { asc_func = asc_func, desc_func = desc_func } --- @type QfRancherSortInfo
    M._sort_wrapper(sort_info, sort_opts, output_opts)
end

--- @param name string
--- @param sort_opts QfRancherSortOpts
--- @param output_opts QfRancherOutputOpts
--- @return nil
--- Run a registered sort
--- name: The registered name of the sort to run
--- sort_opts:
--- - dir?: "asc"|"desc" Defaults to "asc"
--- output_opts
--- - action? "new"|"replace"|"add" - Create a new list, replace a pre-existing one, or add a new
---     one
--- - is_loclist? boolean - Whether to filter against a location list
function M.sort(name, sort_opts, output_opts)
    if not sorts[name] then
        vim.api.nvim_echo({ { "Invalid sort", "ErrorMsg" } }, true, { err = true })
    end
    M._sort_wrapper(sorts[name], sort_opts, output_opts)
end

return M
