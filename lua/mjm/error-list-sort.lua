local ea = Qfr_Defer_Require("mjm.error-list-stack") ---@type QfrStack
local et = Qfr_Defer_Require("mjm.error-list-tools") ---@type QfrTools
local eu = Qfr_Defer_Require("mjm.error-list-util") ---@type QfrUtil
local ey = Qfr_Defer_Require("mjm.error-list-types") ---@type QfrTypes

local api = vim.api
local fn = vim.fn

---@mod Sort Sends diags to the qf list

---@ class QfRancherSort
local Sort = {}

---------------
--- Wrapper ---
---------------

---@param sort_info QfRancherSortInfo
---@param sort_opts QfRancherSortOpts
---@param output_opts QfrOutputOpts
---@return nil
local function sort_wrapper(sort_info, sort_opts, output_opts)
    ey._validate_sort_info(sort_info)
    ey._validate_sort_opts(sort_opts)
    ey._validate_output_opts(output_opts)

    local src_win = output_opts.src_win ---@type integer|nil
    if src_win and not eu._valid_win_for_loclist(src_win) then return end

    local cur_list = et._get_list(src_win, { nr = output_opts.what.nr, all = true }) ---@type table
    if cur_list.size <= 1 then
        api.nvim_echo({ { "Not enough entries to sort", "" } }, false, {})
        return
    end

    ---@type QfRancherSortPredicate
    local predicate = sort_opts.dir == "asc" and sort_info.asc_func or sort_info.desc_func
    local what_set = et._what_ret_to_set(cur_list) ---@type QfrWhat
    table.sort(what_set.items, predicate)
    what_set.nr = output_opts.what.nr

    local dest_nr = et._set_list(src_win, output_opts.action, what_set) ---@type integer
    if eu._get_g_var("qf_rancher_auto_open_changes") then
        ea._get_history(src_win, dest_nr, {
            always_open = true,
            default = "cur_list",
            silent = true,
        })
    end
end

------------------
--- Sort Parts ---
------------------

--- NOTE: Do not use ternaries here, as it causes logical errors

---@type QfRancherCheckFunc
local function check_asc(a, b)
    return a < b
end

---@type QfRancherCheckFunc
local function check_desc(a, b)
    return a > b
end

---@param a any
---@param b any
---@param check QfRancherCheckFunc
---@return boolean|nil
local function a_b_check(a, b, check)
    if not (a and b) then return nil end

    if a == b then
        return nil
    else
        return check(a, b)
    end
end

---@param a table
---@param b table
---@return string|nil, string|nil
local function get_fnames(a, b)
    if not (a.bufnr and b.bufnr) then return nil, nil end

    local fname_a = fn.bufname(a.bufnr) ---@type string|nil
    local fname_b = fn.bufname(b.bufnr) ---@type string|nil
    return fname_a, fname_b
end

---@param a table
---@param b table
---@param check QfRancherCheckFunc
---@return boolean|nil
local function check_fname(a, b, check)
    local fname_a, fname_b = get_fnames(a, b) ---@type string|nil, string|nil
    return a_b_check(fname_a, fname_b, check)
end

---@param a table
---@param b table
---@param check QfRancherCheckFunc
---@return boolean|nil
local function check_lcol(a, b, check)
    local checked_lnum = a_b_check(a.lnum, b.lnum, check) ---@type boolean|nil
    if type(checked_lnum) == "boolean" then return checked_lnum end

    local checked_col = a_b_check(a.col, b.col, check) ---@type boolean|nil
    if type(checked_col) == "boolean" then return checked_col end

    local checked_end_lnum = a_b_check(a.end_lnum, b.end_lnum, check) ---@type boolean|nil
    if type(checked_end_lnum) == "boolean" then return checked_end_lnum end

    return a_b_check(a.end_col, b.end_col, check) -- Return the nil here if we get it
end

---@param a table
---@param b table
---@return boolean|nil
local function check_fname_lcol(a, b, check)
    local checked_fname = check_fname(a, b, check) ---@type boolean|nil
    if type(checked_fname) == "boolean" then return checked_fname end

    return check_lcol(a, b, check) -- Allow the nil to pass through
end

---@param a table
---@param b table
---@param check QfRancherCheckFunc
---@return boolean|nil
local function check_lcol_type(a, b, check)
    local checked_lcol = check_lcol(a, b, check) ---@type boolean|nil
    if type(checked_lcol) == "boolean" then return checked_lcol end

    return a_b_check(a.type, b.type, check)
end

---@type table<string, integer>
local severity_unmap = ey._severity_unmap

---@param a table
---@param b table
---@return integer|nil, integer|nil
local function get_severities(a, b)
    if not (a.type and b.type) then return nil, nil end

    local severity_a = severity_unmap[a.type] or nil ---@type integer|nil
    local severity_b = severity_unmap[b.type] or nil ---@type integer|nil
    return severity_a, severity_b
end

---@param a table
---@param b table
---@return boolean|nil
local function check_severity(a, b, check)
    local severity_a, severity_b = get_severities(a, b) ---@type integer|nil, integer|nil
    return a_b_check(severity_a, severity_b, check)
end

---@param a table
---@param b table
---@return boolean|nil
local function check_lcol_severity(a, b, check)
    local checked_lcol = check_lcol(a, b, check) ---@type boolean|nil
    if type(checked_lcol) == "boolean" then return checked_lcol end

    return check_severity(a, b, check) -- Allow the nil to pass through
end

-----------------
--- Sort Info ---
-----------------

---@param a vim.quickfix.entry
---@param b vim.quickfix.entry
---@param check QfRancherCheckFunc
---@return boolean
local function sort_fname(a, b, check)
    if not (a and b) then return false end

    local checked_fname = check_fname(a, b, check) ---@type boolean|nil
    if type(checked_fname) == "boolean" then return checked_fname end

    local checked_lcol_type = check_lcol_type(a, b, check_asc) ---@type boolean|nil
    if type(checked_lcol_type) == "boolean" then
        return checked_lcol_type
    else
        return false
    end
end

---@type QfRancherSortPredicate
function Sort._sort_fname_asc(a, b)
    return sort_fname(a, b, check_asc)
end

---@type QfRancherSortPredicate
function Sort._sort_fname_desc(a, b)
    return sort_fname(a, b, check_desc)
end

---@param a vim.quickfix.entry
---@param b vim.quickfix.entry
---@param check QfRancherCheckFunc
---@return boolean
local function sort_text(a, b, check)
    if not (a and b) then return false end

    local a_trim = a.text:gsub("^%s*(.-)%s*$", "%1") ---@type string
    local b_trim = b.text:gsub("^%s*(.-)%s*$", "%1") ---@type string

    local checked_text = a_b_check(a_trim, b_trim, check) ---@type boolean|nil
    if type(checked_text) == "boolean" then return checked_text end

    local checked_fname_lcol = check_fname_lcol(a, b, check_asc) ---@type boolean|nil
    if type(checked_fname_lcol) == "boolean" then
        return checked_fname_lcol
    else
        return false
    end
end

---@text QfRancherSortPredicate
function Sort._sort_text_asc(a, b)
    return sort_text(a, b, check_asc)
end

---@text QfRancherSortPredicate
function Sort._sort_text_desc(a, b)
    return sort_text(a, b, check_desc)
end

---@param a vim.quickfix.entry
---@param b vim.quickfix.entry
---@param check QfRancherCheckFunc
---@return boolean
local function sort_type(a, b, check)
    if not (a and b) then return false end

    local checked_type = a_b_check(a.type, b.type, check) ---@type boolean|nil
    if type(checked_type) == "boolean" then return checked_type end

    local checked_fname_lcol = check_fname_lcol(a, b, check_asc) ---@type boolean|nil
    if type(checked_fname_lcol) == "boolean" then
        return checked_fname_lcol
    else
        return false
    end
end

---@type QfRancherSortPredicate
function Sort._sort_type_asc(a, b)
    return sort_type(a, b, check_asc)
end

---@type QfRancherSortPredicate
function Sort._sort_type_desc(a, b)
    return sort_type(a, b, check_desc)
end

---@param a vim.quickfix.entry
---@param b vim.quickfix.entry
---@param check QfRancherCheckFunc
---@return boolean
local function sort_severity(a, b, check)
    if not (a and b) then return false end

    local checked_severity = check_severity(a, b, check) ---@type boolean|nil
    if type(checked_severity) == "boolean" then return checked_severity end

    local checked_fname_lcol = check_fname_lcol(a, b, check_asc) ---@type boolean|nil
    checked_fname_lcol = checked_fname_lcol == nil and false or checked_fname_lcol
    if type(checked_fname_lcol) == "boolean" then
        return checked_fname_lcol
    else
        return false
    end
end

---@type QfRancherSortPredicate
function Sort._sort_severity_asc(a, b)
    return sort_severity(a, b, check_asc)
end

---@type QfRancherSortPredicate
function Sort._sort_severity_desc(a, b)
    return sort_severity(a, b, check_desc)
end

---@param a vim.quickfix.entry
---@param b vim.quickfix.entry
---@param check QfRancherCheckFunc
---@return boolean
local function sort_diag_fname(a, b, check)
    if not (a and b) then return false end

    local checked_fname = check_fname(a, b, check) ---@type boolean|nil
    if type(checked_fname) == "boolean" then return checked_fname end

    local checked_lcol_severity = check_lcol_severity(a, b, check_asc) ---@type boolean|nil
    if type(checked_lcol_severity) == "boolean" then
        return checked_lcol_severity
    else
        return false
    end
end

---@type QfRancherSortPredicate
function Sort._sort_fname_diag_asc(a, b)
    return sort_diag_fname(a, b, check_asc)
end

---@type QfRancherSortPredicate
function Sort._sort_fname_diag_desc(a, b)
    return sort_diag_fname(a, b, check_desc)
end

-- =========
-- == API ==
-- =========

local sorts = {
    fname = { asc_func = Sort._sort_fname_asc, desc_func = Sort._sort_fname_desc },
    fname_diag = { asc_func = Sort._sort_fname_diag_asc, desc_func = Sort._sort_fname_diag_desc },
    severity = { asc_func = Sort._sort_severity_asc, desc_func = Sort._sort_severity_desc },
    text = { asc_func = Sort._sort_text_asc, desc_func = Sort._sort_text_desc },
    type = { asc_func = Sort._sort_type_asc, desc_func = Sort._sort_type_desc },
} ---@type table<string, QfRancherSortInfo>

--- DOCUMENT: this

---@return string[]
function Sort.get_sort_names()
    return vim.tbl_keys(sorts)
end

--- DOCUMENT: Improve this?
--- Add your own sort. Can be accessed using Qsort or Lsort
--- name: The name the sort is accessed with
--- asc_func: Predicate to sort ascending. Takes two quickfix items. Returns boolean
--- asc_func: Predicate to sort descending. Takes two quickfix items. Returns boolean
---@param name string
---@param asc_func QfRancherSortPredicate
---@param desc_func QfRancherSortPredicate
---@return nil
function Sort.register_sort(name, asc_func, desc_func)
    sorts[name] = { asc_func = asc_func, desc_func = desc_func }
end

--- Clears the function name from the registered sorts
---@param name string
function Sort.clear_sort(name)
    if #vim.tbl_keys(sorts) <= 1 then
        api.nvim_echo({ { "Cannot remove the last sort method" } }, false, {})
        return
    end

    if sorts[name] then
        sorts[name] = nil
        api.nvim_echo({ { name .. " removed from sort list", "" } }, true, {})
    else
        api.nvim_echo({ { name .. " is not a registered sort", "" } }, true, {})
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
---@param name string
---@param sort_opts QfRancherSortOpts
---@param output_opts QfrOutputOpts
---@return nil
function Sort.sort(name, sort_opts, output_opts)
    local sort_info = sorts[name] ---@type QfRancherSortInfo
    if not sort_info then
        api.nvim_echo({ { "Invalid sort", "ErrorMsg" } }, true, { err = true })
    end

    sort_wrapper(sort_info, sort_opts, output_opts)
end

-- ===============
-- == CMD FUNCS ==
-- ===============

---@param src_win integer|nil
---@param cargs vim.api.keyset.create_user_command.command_args
---@return nil
local function sort_cmd(src_win, cargs)
    local fargs = cargs.fargs

    local sort_names = Sort.get_sort_names() ---@type string[]
    if #sort_names < 1 then
        api.nvim_echo({ { "No sort functions available", "ErrorMsg" } }, true, { err = true })
        return
    end

    local sort_name = eu._check_cmd_arg(fargs, sort_names, "fname") ---@type string
    local dir = cargs.bang and "desc" or "asc"

    ---@type QfrAction
    local action = eu._check_cmd_arg(fargs, ey._actions, ey._default_action)
    ---@type QfrOutputOpts
    local output_opts = { src_win = src_win, action = action, what = { nr = cargs.count } }

    Sort.sort(sort_name, { dir = dir }, output_opts)
end

---@param cargs vim.api.keyset.create_user_command.command_args
---@return nil
Sort.q_sort = function(cargs)
    sort_cmd(nil, cargs)
end

---@param cargs vim.api.keyset.create_user_command.command_args
---@return nil
Sort.l_sort = function(cargs)
    sort_cmd(api.nvim_get_current_win(), cargs)
end

return Sort
---@export sort

-- TODO: Testing
-- TODO: Docs
