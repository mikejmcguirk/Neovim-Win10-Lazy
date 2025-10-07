--- @class QfRancherTypes
local M = {}

--- @alias QfRancherAction "new"|"replace"|"add"

--- @param action QfRancherAction
--- @return nil
function M._validate_action(action)
    vim.validate("action", action, "string")
    vim.validate("action", action, function()
        return action == "new" or action == "replace" or action == "add"
    end)
end

--- @alias QfRancherInputType "insensitive"|"regex"|"sensitive"|"smartcase"|"vimsmart"

--- @type string[]
local input_types = { "insensitive", "regex", "sensitive", "smartcase", "vimsmart" }
M._default_input_type = "vimsmart"
M._cmd_input_types = vim.tbl_filter(function(t)
    return t ~= "vimsmart"
end, input_types)

function M._validate_input_type(input)
    vim.validate("input", input, "string")
    vim.validate("input", input, function()
        return vim.tbl_contains(input_types, input)
    end)
end

--- @class QfRancherInputOpts
--- @field input_type? QfRancherInputType
--- @field pattern? string

function M._validate_input_opts(input_opts)
    vim.validate("input_opts", input_opts, "table")
    M._validate_input_type(input_opts.input_type)
    vim.validate("input_opts.pattern", input_opts.pattern, { "nil", "string" })
end

--- @class QfRancherOutputOpts
--- @field action? QfRancherAction
--- @field count? integer|nil
--- @field use_loclist? boolean|nil
--- @field loclist_source_win? integer --- TODO: But why though?
--- @field list_item_type? string|nil
--- @field title? string|nil --- TODO: Nix this

--- PR: The builtin what annotation does not contain the user_data field. On one hand, this makes
--- sense because it is not atually read by setqflist. On the other, it means the field cannot
--- be used without suppressing diagnostics. Double-check how the field is read internally, but
--- feels like something that should be added
--- NOTE: Handling the "$" nr value adds significant complexity. Disallow here

--- @class QfRancherWhat : vim.fn.setqflist.what
--- @field nr integer
--- @field user_data? any

--- @class QfRancherUserData
--- @field action? QfRancherAction
--- @field list_item_type? string
--- @field src_win? integer
--- @field sort_func? QfRancherSortPredicate

M._actions = { "new", "replace", "add" }
M._default_action = "new"

--- @param count integer
--- @return nil
function M._validate_count(count)
    vim.validate("count", count, "number")
    vim.validate("count", count, function()
        return count >= 0
    end)
end

--- @param count1 integer
--- @return nil
function M._validate_count1(count1)
    vim.validate("count", count1, "number")
    vim.validate("count", count1, function()
        return count1 >= 1
    end)
end

--- @param win integer|nil
--- @param allow_nil? boolean
--- @return nil
function M._validate_win(win, allow_nil)
    local validator = allow_nil == true and { "nil", "number" } or "number"
    vim.validate("win", win, validator)
    if type(win) == "number" then
        vim.validate("win", win, function()
            return vim.api.nvim_win_is_valid(win)
        end)
    end
end

--- @param list_nr integer|string
--- @return nil
function M._validate_list_nr(list_nr)
    vim.validate("list_nr", list_nr, "number")
    vim.validate("list_nr", list_nr, function()
        return list_nr >= 0
    end)
end

--- MID: If this value starts being used in more places, consider making an alias for it rather
--- than add-hoc annotation enums

--- @param setlist_action "r"|" "|"a"|"f"|"u"
--- @return nil
function M._validate_setlist_action(setlist_action)
    vim.validate("setlist_action", setlist_action, "string")
    vim.validate("setlist_action", setlist_action, function()
        return setlist_action == "r"
            or setlist_action == " "
            or setlist_action == "a"
            or setlist_action == "f"
            or setlist_action == "u"
    end)
end

--- NOTE: This is designed for entries used to set qflists. The entries from getqflist() are
--- not exactly the same
--- @param item vim.quickfix.entry
--- @return nil
function M.validate_list_item(item)
    vim.validate("item", item, "table")
    vim.validate("item.bufnr", item.bufnr, { "nil", "number" })
    if type(item.bufnr) == "number" then
        vim.validate("item.bufnr", item.bufnr, function()
            return vim.api.nvim_buf_is_valid(item.bufnr)
        end)
    end

    vim.validate("item.filename", item.filename, { "nil", "string" })
    if type(item.filename) == "string" then
        vim.validate("item.filename", item.filename, function()
            local full_path = vim.fn.fnamemodify(item.filename, ":p")
            return vim.uv.fs_access(full_path, 4) == true
        end)
    end

    vim.validate("item.module", item.module, { "nil", "string" })

    vim.validate("item.nr", item.nr, { "nil", "number" })
    vim.validate("item.pattern", item.pattern, { "nil", "string" })
    vim.validate("item.vcol", item.vcol, { "nil", "number" })
    vim.validate("item.text", item.text, { "nil", "string" })
    vim.validate("item.type", item.type, { "nil", "string" })
    --- MID: Figure out what the proper validation for this is
    -- vim.validate("item.valid", item.valid, { "boolean", "nil" })

    if type(item.type) == "string" then
        vim.validate("item.type", item.type, function()
            return #item.type <= 1
        end)
    end

    --- NOTE: While qf rows and cols are one indexed, 0 is used to represent non-values

    vim.validate("item.lnum", item.lnum, { "nil", "number" })
    if type(item.lnum) == "number" then
        vim.validate("item.lnum", item.lnum, function()
            return item.lnum >= 0
        end)
    end

    vim.validate("item.end_lnum", item.end_lnum, { "nil", "number" })
    if type(item.end_lnum) == "number" then
        vim.validate("item.end_lnum", item.end_lnum, function()
            return item.end_lnum >= 0
        end)
    end

    vim.validate("item.col", item.col, { "nil", "number" })
    if type(item.col) == "number" then
        vim.validate("item.col", item.col, function()
            return item.col >= 0
        end)
    end

    vim.validate("item.end_col", item.end_col, { "nil", "number" })
    if type(item.end_col) == "number" then
        vim.validate("item.end_col", item.end_col, function()
            return item.end_col >= 0
        end)
    end
end

--- @param what QfRancherWhat
--- @return nil
function M._validate_what(what)
    vim.validate("what", what, "table")
    vim.validate("what.context", what.context, { "nil", "table" })
    vim.validate("what.efm", what.efm, { "nil", "string" })
    vim.validate("what.id", what.id, { "nil", "number" })
    if type(what.id) == "number" then
        vim.validate("what.id", what.id, function()
            return what.id >= 0
        end)
    end

    --- While Nvim can handle an idx of "$" for the last idx, the annotation only allows for
    --- integer types. Only allow numbers here for consistency
    vim.validate("what.idx", what.idx, { "nil", "number" })
    if type(what.idx) == "number" then
        vim.validate("what.idx", what.idx, function()
            return what.idx >= 0
        end)
    end

    vim.validate("what.items", what.items, { "nil", "table" })
    if vim.g.qf_rancher_debug_assertions and type(what.items) == "table" then
        --- TODO: Consolidate these
        for _, item in ipairs(what.items) do
            M.validate_list_item(item)
        end
    end

    vim.validate("what.lines", what.lines, { "nil", "table" })
    if type(what.lines) == "table" then
        require("mjm.error-list-util")._is_valid_str_list(what.lines)
    end

    M._validate_list_nr(what.nr)
    vim.validate("what.quickfixtextfunc", what.quickfixtextfunc, { "callable", "nil" })
    vim.validate("what.title", what.title, { "nil", "string" })
end

------------------
--- DIAG TYPES ---
------------------

--- @alias QfRancherSeverityType "min"|"only"|"top"

M._sev_types = { "min", "only", "top" } --- @type QfRancherSeverityType[]

--- @param sev_type QfRancherSeverityType
--- @return nil
function M._validate_sev_type(sev_type)
    vim.validate("sev_type", sev_type, function()
        return sev_type == "min" or sev_type == "only" or sev_type == "top"
    end)
end

--- @alias QfRancherDiagInfo { level: vim.diagnostic.Severity|nil }
--- @alias QfRancherDiagOpts { sev_type: QfRancherSeverityType }

--- @param diag_info QfRancherDiagInfo
--- @return nil
function M._validate_diag_info(diag_info)
    vim.validate("diag_info", diag_info, "table")
    vim.validate("diag_info.level", diag_info.level, { "nil", "number" })
end

--- @param diag_opts QfRancherDiagOpts
--- @return nil
function M._validate_diag_opts(diag_opts)
    vim.validate("diag_opts", diag_opts, "table")
    vim.validate("diag_opts.sev_type", diag_opts.sev_type, "string")
    M._validate_sev_type(diag_opts.sev_type)
end

--------------------
--- FILTER TYPES ---
--------------------

--- @class QfRancherFilterInfo
--- @field name string
--- @field insensitive_func QfRancherPredicateFunc
--- @field regex_func QfRancherPredicateFunc
--- @field sensitive_func QfRancherPredicateFunc

--- @param filter_info QfRancherFilterInfo
function M._validate_filter_info(filter_info)
    vim.validate("filter_info", filter_info, "table")
    vim.validate("filter_info.name", filter_info.name, "string")
    vim.validate("filter_info.insensitive_func", filter_info.insensitive_func, "callable")
    vim.validate("filter_info.regex_func", filter_info.regex_func, "callable")
    vim.validate("filter_info.sensitive_func", filter_info.sensitive_func, "callable")
end

--- @class QfRancherFilterOpts
--- @field keep? boolean

function M._validate_filter_opts(filter_opts)
    vim.validate("filter_opts", filter_opts, "table")
    vim.validate("filter_opts.keep", filter_opts.keep, { "boolean", "nil" })
end

--- @class QfRancherPredicateOpts
--- @field pattern? string
--- @field regex? vim.regex

--- @alias QfRancherPredicateFunc fun(vim.qflist.entry, boolean, QfRancherPredicateOpts):boolean

------------------
--- GREP TYPES ---
------------------

--- @alias QfRancherGrepPartsFunc fun(string, string, QfRancherGrepLocs):string[]

--- @class QfRancherGrepInfo
--- @field name string
--- @field list_item_type string|nil
--- @field location_func fun():string[]

--- @param grep_info QfRancherGrepInfo
--- @return nil
function M._validate_grep_info(grep_info)
    vim.validate("grep_info", grep_info, "table")
    vim.validate("grep_info.name", grep_info.name, "string")
    vim.validate("grep_info.list_item_type", grep_info.list_item_type, { "nil", "string" })
    vim.validate("location_func", grep_info.location_func, "callable")
end

------------------
--- OPEN TYPES ---
------------------

--- @class QfRancherOpenOpts
--- @field always_resize? boolean
--- @field height? integer
--- @field keep_win? boolean
--- @field suppress_errors? boolean

--- @class QfRancherPWinCloseOpts
--- @field bdel? boolean
--- @field bwipeout? boolean
--- @field force? boolean
--- @field print_errors? boolean

------------------
--- SORT TYPES ---
------------------

--- @alias QfRancherSortPredicate fun(table, table): boolean

--- @class QfRancherSortInfo
--- @field asc_func QfRancherSortPredicate
--- @field desc_func QfRancherSortPredicate

--- @param sort_info QfRancherSortInfo
--- @return nil
function M._validate_sort_info(sort_info)
    vim.validate("sort_info", sort_info, "table")
    vim.validate("sort_info.asc_func", sort_info.asc_func, "callable")
    vim.validate("sort_info.desc_func", sort_info.desc_func, "callable")
end

--- @alias QfRancherSortDir "asc"|"desc"

--- @param dir QfRancherSortDir
--- @return nil
function M._validate_sort_dir(dir)
    vim.validate("dir", dir, function()
        return dir == "asc" or dir == "desc"
    end)
end

--- @class QfRancherSortOpts
--- @field dir QfRancherSortDir

--- @param sort_opts QfRancherSortOpts
--- @return nil
function M._validate_sort_opts(sort_opts)
    vim.validate("sort_opts", sort_opts, "table")
    vim.validate("sort_opts.dir", sort_opts.dir, "string")
    if type(sort_opts.dir) == "string" then
        M._validate_sort_dir(sort_opts.dir)
    end
end

--- @alias QfRancherSortable string|integer
--- @alias QfRancherCheckFunc fun(QfRancherSortable, QfRancherSortable):boolean

--------------------
--- SYSTEM TYPES ---
--------------------

--- @class QfRancherSystemOpts
--- @field sync? boolean
--- @field cmd_parts? string[]
--- @field timeout? integer

--- @param system_opts QfRancherSystemOpts
--- @return nil
function M._validate_system_opts(system_opts)
    vim.validate("system_opts", system_opts, "table")

    vim.validate("system_opts.cmd_parts", system_opts.cmd_parts, { "nil", "table" })
    vim.validate("system_opts.sync", system_opts.sync, { "boolean", "nil" })
    vim.validate("system_opts.timeout", system_opts.timeout, { "nil", "number" })
end

M._sync_opts = { "sync", "async" }
M._default_sync_opt = "async"
M._default_timeout = 4000

return M

------------
--- TODO ---
------------

--- Put all validations in here
--- Project wide thing: Where should validations be behind the g var and when should they not?
---     Anything from an API needs to have a validation layer. Not sure what else or how much
---     further you should go in than the initial calls
--- Rename this to something that suggests it is what governs the data types. Move the types here
--- as well

-----------
--- LOW ---
-----------

--- Create a type and validation for getqflist returns
