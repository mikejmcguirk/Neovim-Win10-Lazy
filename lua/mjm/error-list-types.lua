--- @class QfRancherValidation
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

--- TODO: The what annotation does not allow for the user_data field. This makes sense since it is
--- not ready by setqflist, but makes working with the data a pain. See how quickfix.c handles
--- it internally. Maybe submit PR

--- @class QfRancherWhat : vim.fn.setqflist.what
--- @field user_data? any

--- @class QfRancherUserData
--- @field action? QfRancherAction
--- @field list_item_type? string
--- @field list_win? integer
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
--- @param allow_symbol? boolean
--- @return nil
function M._validate_list_nr(list_nr, allow_symbol)
    local validator = allow_symbol == true and { "number", "string" } or "number"
    vim.validate("list_nr", list_nr, validator)
    if type(list_nr) == "number" then
        vim.validate("list_nr", list_nr, function()
            return list_nr >= 0
        end)
    elseif type(list_nr) == "string" then
        vim.validate("list_nbr", list_nr, function()
            return list_nr == "$"
        end)
    end
end

--- Validate qf items as per the vim.quickfix.entry annotation
--- @param item vim.quickfix.entry
--- @return nil
function M._validate_qf_item(item)
    vim.validate("item", item, "table")

    vim.validate("item.bufnr", item.bufnr, { "nil", "number" })
    vim.validate("item.filename", item.filename, { "nil", "string" })
    vim.validate("item.module", item.module, { "nil", "string" })
    vim.validate("item.lnum", item.lnum, { "nil", "number" })
    vim.validate("item.end_lnum", item.end_lnum, { "nil", "number" })
    vim.validate("item.pattern", item.pattern, { "nil", "string" })
    vim.validate("item.col", item.col, { "nil", "number" })
    vim.validate("item.vcol", item.vcol, { "nil", "number" })
    vim.validate("item.end_col", item.end_col, { "nil", "number" })
    vim.validate("item.nr", item.nr, { "nil", "number" })
    vim.validate("item.text", item.text, { "nil", "string" })
    vim.validate("item.type", item.type, { "nil", "string" })
    --- MID: Figure out what the proper validation for this is
    -- vim.validate("item.valid", item.valid, { "boolean", "nil" })
end

--- Validate qf items more strictly.
--- NOTE: Does not include the base validation against the annotation
--- NOTE: This is designed for entries used to set qflists. The entries from getqflist() are
--- not exactly the same
--- @param item vim.quickfix.entry
--- @return nil
function M._validate_qf_item_strict(item)
    if type(item.bufnr) == "number" then
        vim.validate("item.bufnr", item.bufnr, function()
            return vim.api.nvim_buf_is_valid(item.bufnr)
        end)
    end

    if type(item.filename) == "string" then
        vim.validate("item.filename", item.filename, function()
            local full_path = vim.fn.fnamemodify(item.filename, ":p")
            return vim.uv.fs_access(full_path, 4) == true
        end)
    end

    --- NOTE: While qf rows and cols are one indexed, 0 is used to represent non-values

    if type(item.lnum) == "number" then
        vim.validate("item.lnum", item.lnum, function()
            return item.lnum >= 0
        end)
    end

    if type(item.end_lnum) == "number" then
        vim.validate("item.end_lnum", item.end_lnum, function()
            return item.end_lnum >= 0
        end)
    end

    if type(item.col) == "number" then
        vim.validate("item.col", item.col, function()
            return item.col >= 0
        end)
    end

    if type(item.end_col) == "number" then
        vim.validate("item.end_col", item.end_col, function()
            return item.end_col >= 0
        end)
    end

    --- LOW: Is there any validation to do on nr?

    if type(item.type) == "string" then
        vim.validate("item.type", item.type, function()
            return #item.type <= 1
        end)
    end
end

--- Validates what against the vim.fn.setqflist.what annotation
--- @param what vim.fn.setqflist.what
--- @return nil
function M._validate_what(what)
    vim.validate("what", what, "table")
    vim.validate("what.context", what.context, { "nil", "table" })
    vim.validate("what.efm", what.efm, { "nil", "string" })
    vim.validate("what.id", what.id, { "nil", "number" })

    --- While Nvim can handle an idx of "$" for the last idx, the annotation only allows for
    --- integer types. Only allow numbers here for consistency
    vim.validate("what.idx", what.idx, { "nil", "number" })
    vim.validate("what.items", what.items, { "nil", "table" })
    if vim.g.qf_rancher_debug_assertions and type(what.items) == "table" then
        for _, item in ipairs(what.items) do
            M._validate_qf_item(item)
        end
    end

    vim.validate("what.lines", what.lines, { "nil", "table" })
    if type(what.lines) == "table" then
        require("mjm.error-list-util")._is_valid_str_list(what.lines)
    end

    vim.validate("what.nr", what.nr, { "nil", "number", "string" })
    --- "$" is the only string entry allowed in the annotation for nr
    if type(what.nr) == "string" then
        vim.validate("what.nr", what.nr, function()
            return what.nr == "$"
        end)
    end

    vim.validate("what.quickfixtextfunc", what.quickfixtextfunc, { "callable", "nil" })
    vim.validate("what.title", what.title, { "nil", "string" })
end

--- Validate what tables based on more specific criteria
--- @param what vim.fn.setqflist.what
--- @return nil
function M._validate_what_strict(what)
    M._validate_what(what)

    if vim.g.qf_rancher_debug_assertions and type(what.items) == "table" then
        for _, item in pairs(what.items) do
            M._validate_qf_item_strict(item)
        end
    end

    if type(what.id) == "number" then
        vim.validate("what.id", what.id, function()
            return what.id >= 0
        end)
    end

    --- Negative idx values do not exist
    if type(what.idx) == "number" then
        vim.validate("what.idx", what.idx, function()
            return what.idx >= 0
        end)
    end
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
--- @field item table
--- @field keep boolean
--- @field pattern? string
--- @field regex? vim.regex

--- @alias QfRancherPredicateFunc fun(QfRancherPredicateOpts):boolean

------------------
--- GREP TYPES ---
------------------

--- @alias QfRancherGrepLocFunc fun():string[]
---
--- @alias QfRancherGrepLocs string[]
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
