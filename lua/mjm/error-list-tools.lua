-- TODO: also put entry validation in here

local M = {}

--- TODO: What I'm seeing here is, I think we need to do a general validation for the what table
--- to have it, but then we need to do separate validations for separately purposes. If we're
--- setting lines, we would expect the efm table to be present. But we're actually setting list
--- contents, do we actually need efm? I'm not sure if it's used by other qf internals to parse
--- them (though I guess it would be). The point is, for the interface we're trying to create here,
--- we want to avoid wrong or extranneous data. As overly broad possibilities make the code
--- harder to reason about

--- Validate qf entries as per the vim.quickfix.entry annotation
--- @param item vim.quickfix.entry
--- @return nil
local function validate_qf_item(item)
    vim.validate("entry", item, "table")

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
    vim.validate("item.valid", item.valid, { "boolean", "nil" })
    --- Since user_data can be any, don't validate here
end

--- TODO: I would actually like to clamp down more on the entry validation, but there are questions
--- related to how to handle scenarios where you are processing verbose error messages, with
--- compilers being the most obvious example. Certainly the option to only show error lines
--- should exist, but absent a strong alternative, I'm not sure what the solution is for
--- extended error messages beyond letting them hit the qflist

--- Validate qf items more strictly.
--- NOTE: Does not include the base validation against the annotation
--- NOTE: This is designed for entries used to set qflists. The entries from getqflist() are
--- not exactly the same
--- @param item vim.quickfix.entry
--- @return nil
local function validate_qf_item_rancher(item)
    --- Do not allow empty or invalid bufnrs
    if type(item.bufnr) == "number" then
        vim.validate("item.bufnr", item.bufnr, function()
            return vim.api.nvim_buf_is_valid(item.bufnr)
        end)
    end

    if type(item.filename) == "string" then
        vim.validate("item.filename", item.filename, function()
            local full_path = vim.fn.fnamemodify(item.filename, ":p")
            --- TODO: Apparently 1 is readable, so need to deal with that elsewhere
            return vim.fn.filereadable(full_path) == 1
        end)
    end

    --- Per the docs, col/end_col, vcol, nr, type, and text are optional

    --- Either lnum or pattern can be used to find a matching error line
    --- To be rendered as an error line, you must have one of fname/bufnr and lnum/pattern
end

--- Validates what against the vim.fn.setqflist.what annotation
--- @param what vim.fn.setqflist.what
--- @return nil
local function validate_what(what)
    if not vim.g.qf_rancher_debug_assertions then
        return
    end

    vim.validate("what", what, "table")
    vim.validate("what.context", what.context, { "nil", "table" })
    vim.validate("what.efm", what.efm, { "nil", "string" })
    vim.validate("what.id", what.id, { "nil", "number" })

    --- While Nvim can handle an idx of "$" for the last entry, the annotation only allows for
    --- integer types. Only allow numbers here for consistency
    vim.validate("what.idx", what.idx, { "nil", "number" })
    vim.validate("what.items", what.items, { "nil", "table" })
    if type(what.items) == "table" then
        for _, item in ipairs(what.items) do
            validate_qf_item(item)
        end
    end

    --- TODO: If this is a table, should check if the items are valid
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

--- For clarity/simplicity, Qf-Rancher's what-table requirements are more strict than the base
--- annotation
--- @param what vim.fn.setqflist.what
--- @return nil
local function validate_what_rancher(what)
    if not vim.g.qf_rancher_debug_assertions then
        return
    end

    validate_what(what)

    if type(what.items) == "table" then
        for _, item in pairs(what.items) do
            validate_qf_item_rancher(item)
        end
    end
    --- Negative ids do not exist
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

    --- Internally, Quickfix data (entries, title, etc.) are store as a subset of the Quickfix
    --- list number. Get closer to that representation here by not allowing stack data to be
    --- co-mingled with individual list data
    vim.validate("what.nr", what.nr, "nil")
end

--- @param what vim.fn.setqflist.what
--- @return nil
local function validate_what_for_qf_set(what)
    if not vim.g.qf_rancher_debug_assertions then
        return
    end

    validate_what_rancher(what)
    --- qf_id does not matter for Quickfix lists
    vim.validate("what.id", what.id, "nil")
    --- Do not allow setting from lines, as this would force callees to have to handle
    --- multiple datatypes. qf entries should be created using separate logic
    vim.validate("what.lines", what.lines, "nil")
end

--- TODO: This will almost certainly be generalized, but keeping the set_qflist naming convention
--- to avoid prematurely making decisions about what goes where
local function validate_set_qflist(list_nr, action, what)
    vim.validate("list_nr", list_nr, "number")
    vim.validate("list_nr", list_nr, function()
        return list_nr >= 0
    end)

    require("mjm.error-list-util")._validate_action(action)
    validate_what_for_qf_set(what)
end

--- TODO: Unsure if this should have a status return
--- @param list_nr integer
--- @param action QfRancherAction
--- @param what vim.fn.setqflist.what
function M._set_qflist(list_nr, action, what)
    validate_set_qflist(list_nr, action, what)
    --
end

function M._clear_qf_stack()
    vim.fn.setqflist({}, "f")
    --- TODO: If it doesn't already exist, make a function in open to close all qflists in
    --- all tabs
    require("mjm.error-list-open")._close_qflist()
end

return M
