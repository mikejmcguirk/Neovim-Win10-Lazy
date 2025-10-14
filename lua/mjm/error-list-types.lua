--- @class QfRancherTypes
local M = {}

-------------------------
--- SEMI-CUSTOM TYPES ---
-------------------------

--- PR: The built-in what annotation does not contain the user_data field
--- NOTE: Handling the "$" nr value adds complexity. Disallow here
--- NOTE: Similarly, don't create a custom annotation for "$" idx values
--- NOTE: Because what tables are frequently passed down through function chains, require nr at
---     each validation step rather than have to reason about how functions down the chain
---     handle nil values

--- @class QfRancherWhat : vim.fn.setqflist.what
--- @field nr integer
--- @field user_data? any

--- @param what QfRancherWhat
--- @return nil
function M._validate_what(what)
    vim.validate("what", what, "table")

    vim.validate("what.context", what.context, "table", true)
    vim.validate("what.efm", what.efm, "string", true)
    M._validate_uint(what.id, true)
    M._validate_uint(what.idx, true)
    vim.validate("what.items", what.items, "table", true)
    if vim.g.qf_rancher_debug_assertions and type(what.items) == "table" then
        for _, item in ipairs(what.items) do
            M._validate_list_item(item)
        end
    end

    -- TODO: This should just be validate_str_list and that function should have an optional
    -- boolean. Or maybe you can just use the vim.list validator
    vim.validate("what.lines", what.lines, "table", true)
    if type(what.lines) == "table" then
        M._validate_str_list(what.lines)
    end

    M._validate_uint(what.nr)
    vim.validate("what.quickfixtextfunc", what.quickfixtextfunc, "callable", true)
    vim.validate("what.title", what.title, "string", true)
    if type(what.user_data) == "table" then
        M._validate_user_data(what.user_data)
    end
end

--- @class QfRancherUserData
--- @field action? QfRancherAction
--- @field list_item_type? string
--- @field src_win? integer
--- @field sort_func? QfRancherSortPredicate

--- @param user_data QfRancherUserData
--- @return nil
function M._validate_user_data(user_data)
    vim.validate("user_data", user_data, "table")
    vim.validate("user_data.action", user_data.action, "string", true)
    if type(user_data.action) == "string" then
        M._validate_action(user_data.action)
    end

    vim.validate("user_data.list_item_type", user_data.list_item_type, "string", true)
    vim.validate("user_data.src_win", user_data.src_win, "number", true)
    vim.validate("user_data.sort_func", user_data.sort_func, "callable", true)
end

-- LOW: Add validation for win config

------------------
--- PRIMITIVES ---
------------------

--- @param num integer|nil
--- @param optional? boolean
--- @return nil
function M._validate_uint(num, optional)
    vim.validate("num", num, "number", optional)
    vim.validate("num", num, function()
        return num % 1 == 0
    end, optional, "Num is not an integer")
    vim.validate("num", num, function()
        return num >= 0
    end, optional, "Num is less than zero")
end

--- @param num integer|nil
--- @param optional? boolean
--- @return nil
function M._validate_int(num, optional)
    vim.validate("num", num, "number", optional)
    vim.validate("num", num, function()
        return num % 1 == 0
    end, optional, "Num is not an integer")
end

-- TODO: Use the vim.islist validation here
-- TODO: Add an optional flag here
--- @param table string[]
--- @return nil
function M._validate_str_list(table)
    vim.validate("table", table, "table")
    for k, v in ipairs(table) do
        -- TODO: Validate elements are strings before printing concated errors
        assert(type(k) == "number", "Key " .. vim.inspect(k) .. " is not a number")
        assert(type(v) == "string", "Item " .. vim.inspect(v) .. " is not a string")
    end
end

-----------------
--- BUILT-INS ---
-----------------

-- MID: Perhaps create a separate validation for stack nrs limiting to between 0-10
-- How a huge deal since clamping is easy, but would enforce more type consistency

-- TODO: Check usages of this to see where a simple vim.validate, or maybe not validating at all,
-- is sufficient

--- @param win integer|nil
--- @param optional? boolean
--- @return nil
function M._validate_win(win, optional)
    M._validate_uint(win, optional)
    if optional and type(win) == "nil" then
        return
    end

    if type(win) == "number" then
        vim.validate("win", win, function()
            return vim.api.nvim_win_is_valid(win)
        end, "Win " .. win .. " is not valid")
    else
        error("Win is not a number or nil")
    end
end

--- @param buf integer|nil
--- @param optional? boolean
--- @return nil
function M._validate_buf(buf, optional)
    M._validate_uint(buf, optional)
    if optional and type(buf) == "nil" then
        return
    end

    if type(buf) == "number" then
        vim.validate("buf", buf, function()
            return vim.api.nvim_buf_is_valid(buf)
        end)
    else
        error("buf is not a number or nil")
    end
end

--- @param list_win integer
--- @param optional? boolean
--- @return nil
function M._validate_list_win(list_win, optional)
    M._validate_win(list_win, optional)
    if optional and type(list_win) == "nil" then
        return
    end

    local list_win_buf = vim.api.nvim_win_get_buf(list_win) --- @type integer
    --- @type string
    local buftype = vim.api.nvim_get_option_value("buftype", { buf = list_win_buf })
    vim.validate("buftype", buftype, function()
        return buftype == "quickfix"
    end, optional, "Buftype must be quickfix")
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
function M._validate_list_item(item)
    vim.validate("item", item, "table")

    vim.validate("item.bufnr", item.bufnr, "number", true)
    -- Cannot check if buf is valid here, because a valid buf at the time of list creation might
    -- have been deleted
    M._validate_uint(item.bufnr, true)
    -- Cannot check if filename is valid here, because a valid filename at the time of list
    -- creation might have been moved or deleted
    vim.validate("item.filename", item.filename, "string", true)

    vim.validate("item.module", item.module, "string", true)
    M._validate_int(item.nr, true)
    vim.validate("item.pattern", item.pattern, "string", true)
    M._validate_uint(item.vcol, true)

    vim.validate("item.text", item.text, "string", true)

    --- MID: Figure out what the proper validation for this is
    -- vim.validate("item.valid", item.valid, { "boolean", "nil" })

    vim.validate("item.type", item.type, "string", true)
    if type(item.type) == "string" then
        vim.validate("item.type", item.type, function()
            return #item.type <= 1
        end)
    end

    --- NOTE: While qf rows and cols are one indexed, 0 is used to represent non-values
    M._validate_uint(item.lnum, true)
    M._validate_uint(item.col, true)
    M._validate_uint(item.end_lnum, true)
    M._validate_uint(item.end_col, true)
end

M._severity_map = {
    [vim.diagnostic.severity.ERROR] = "E",
    [vim.diagnostic.severity.WARN] = "W",
    [vim.diagnostic.severity.INFO] = "I",
    [vim.diagnostic.severity.HINT] = "H",
} ---@type table<integer, string>

M._severity_unmap = {
    E = vim.diagnostic.severity.ERROR,
    W = vim.diagnostic.severity.WARN,
    I = vim.diagnostic.severity.INFO,
    H = vim.diagnostic.severity.HINT,
} ---@type table<string, integer>

-- :h 'winborder'
-- PR: This feels like something you could put into vim.validate. Or at least a type annotation

--- @alias QfRancherBorder ""|"bold"|"double"|"none"|"rounded"|"shadow"|"single"|"solid"|string[]

--- @type string[]
local valid_borders = { "", "bold", "double", "none", "rounded", "shadow", "single", "solid" }

--- @param border QfRancherBorder
function M._validate_border(border)
    vim.validate("border", border, { "string", "table" })
    if type(border) == "string" then
        vim.validate("border", border, function()
            return vim.tbl_contains(valid_borders, border)
        end)
    elseif type(border) == "table" then
        M._validate_str_list(border)
        vim.validate("border", border, function()
            return #border == 8
        end)
    end
end

--- @alias QfRancherTitlePos "left"|"center"|"right"

--- @param title_pos string
--- @return nil
function M._validate_title_pos(title_pos)
    vim.validate("title_pos", title_pos, "string")
    vim.validate("title_pos", title_pos, function()
        return title_pos == "left" or title_pos == "center" or title_pos == "right"
    end)
end

--- @param winblend integer
--- @return nil
function M._validate_winblend(winblend)
    M._validate_uint(winblend)
    vim.validate("winblend", winblend, function()
        return winblend >= 0 and winblend <= 100
    end, false, "Winblend is not between 0 and 100")
end

-------------------------------
--- CUSTOM TYPES -- GENERAL ---
-------------------------------

--- @alias QfRancherAction "new"|"replace"|"add"

M._actions = { "new", "replace", "add" }
M._default_action = "new"

--- @param action QfRancherAction
--- @return nil
function M._validate_action(action)
    vim.validate("action", action, "string")
    vim.validate("action", action, function()
        return vim.tbl_contains(M._actions, action)
    end)
end

--- @alias QfRancherInputType "insensitive"|"regex"|"sensitive"|"smartcase"|"vimsmart"

--- @type string[]
local input_types = { "insensitive", "regex", "sensitive", "smartcase", "vimsmart" }
M._default_input_type = "vimsmart"
M._cmd_input_types = vim.tbl_filter(function(t)
    return t ~= "vimsmart"
end, input_types)

--- @param input QfRancherInputType
--- @return nil
function M._validate_input_type(input)
    vim.validate("input", input, "string")
    vim.validate("input", input, function()
        return vim.tbl_contains(input_types, input)
    end, "Input type " .. input .. " is not valid")
end

--- @class QfRancherInputOpts
--- @field input_type QfRancherInputType
--- @field pattern? string

--- @param input_opts QfRancherInputOpts
--- @return nil
function M._validate_input_opts(input_opts)
    vim.validate("input_opts", input_opts, "table")
    M._validate_input_type(input_opts.input_type)
    vim.validate("input_opts.pattern", input_opts.pattern, "string", true)
end

--- @class QfRancherTabpageOpts
--- @field tabpage? integer
--- @field tabpages? integer[]
--- @field all_tabpages? boolean

--- @param opts QfRancherTabpageOpts
function M._validate_tabpage_opts(opts)
    vim.validate("opts", opts, "table")
    vim.validate("opts.tabpage", opts.tabpage, "number", true)
    vim.validate("opts.tabpages", opts.tabpages, "table", true)
    vim.validate("opts.all_tabpages", opts.all_tabpages, "boolean", true)
end

---------------------------
--- CUSTOM TYPES - DIAG ---
---------------------------

--- @alias QfRancherSeverityType "min"|"only"|"top"

M._sev_types = { "min", "only", "top" } --- @type QfRancherSeverityType[]

--- @param sev_type QfRancherSeverityType
--- @return nil
function M._validate_sev_type(sev_type)
    vim.validate("sev_type", sev_type, "string")
    vim.validate("sev_type", sev_type, function()
        return sev_type == "min" or sev_type == "only" or sev_type == "top"
    end, "Severity type " .. sev_type .. " is invalid")
end

--- @alias QfRancherDiagInfo { level: vim.diagnostic.Severity|nil }

--- @param diag_info QfRancherDiagInfo
--- @return nil
function M._validate_diag_info(diag_info)
    vim.validate("diag_info", diag_info, "table")
    vim.validate("diag_info.level", diag_info.level, "number", true)
end

--- @alias QfRancherDiagOpts { sev_type: QfRancherSeverityType }

--- @param diag_opts QfRancherDiagOpts
--- @return nil
function M._validate_diag_opts(diag_opts)
    vim.validate("diag_opts", diag_opts, "table")
    vim.validate("diag_opts.sev_type", diag_opts.sev_type, "string")
    M._validate_sev_type(diag_opts.sev_type)
end

------------------------------
--- CUSTOM TYPES -- FILTER ---
------------------------------

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
    vim.validate("filter_opts.keep", filter_opts.keep, "boolean", true)
end

--- @class QfRancherPredicateOpts
--- @field pattern? string
--- @field regex? vim.regex

--- @alias QfRancherPredicateFunc fun(vim.qflist.entry, boolean, QfRancherPredicateOpts):boolean

----------------------------
--- CUSTOM TYPES -- GREP ---
----------------------------

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
    vim.validate("grep_info.list_item_type", grep_info.list_item_type, "string", true)
    vim.validate("location_func", grep_info.location_func, "callable")
end

----------------------------
--- CUSTOM TYPES -- OPEN ---
----------------------------

--- @class QfRancherOpenOpts
--- @field always_resize? boolean
--- @field height? integer
--- @field keep_win? boolean
--- @field print_errs? boolean

--- @param open_opts QfRancherOpenOpts
--- @return nil
function M._validate_open_opts(open_opts)
    vim.validate("open_opts", open_opts, "table")
    vim.validate("open_opts.always_resize", open_opts.always_resize, "boolean", true)
    vim.validate("open_opts.height", open_opts.height, "number", true)
    vim.validate("open_opts.keep_win", open_opts.keep_win, "boolean", true)
    vim.validate("open_opts.print_errs", open_opts.print_errs, "boolean", true)
end

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

    vim.validate("system_opts.cmd_parts", system_opts.cmd_parts, "table", true)
    vim.validate("system_opts.sync", system_opts.sync, "boolean", true)
    vim.validate("system_opts.timeout", system_opts.timeout, "number", true)
end

M._sync_opts = { "sync", "async" }
M._default_sync_opt = "async"
M._default_timeout = 4000

-------------------
--- STACK TYPES ---
-------------------

--- @class QfRancherHistoryOpts
--- @field always_open? boolean
--- @field default? "all"|"current"
--- @field keep_win? boolean
--- @field silent? boolean

--- @param opts QfRancherHistoryOpts
--- @return nil
function M._validate_history_opts(opts)
    vim.validate("opts", opts, "table")
    vim.validate("opts.default", opts.default, "string", true)
    vim.validate("opts.always_open", opts.always_open, "boolean", true)
    vim.validate("opts.keep_win", opts.keep_win, "boolean", true)
    vim.validate("opts.silent", opts.silent, "boolean", true)
end

return M

------------
--- TODO ---
------------

--- Use validation primarily for type integrity. Use assertions for stuff that would hurt perf or
--- is more logic based
--- Don't validate types that are only passed through
--- Do accept multiple validations, to avoid reasoning about where validation happens

--- Tests
--- Documentation

-----------
--- LOW ---
-----------

--- Create a type and validation for getqflist returns
