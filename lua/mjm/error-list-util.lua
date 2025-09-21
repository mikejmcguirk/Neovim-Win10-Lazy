local M = {}

--- @alias QfRancherSetlistAction "merge"|"new"|"overwrite"

-- TODO: Replace the system functions with these

-- NOTE: It is simpler in theory to only pass the win value to the getlist and setlist functions,
-- returning the qflist functions if win is nil. But this forces contrivance upstream

--- @param win integer
--- @return string|nil
function M.get_listtype(win)
    win = win or vim.api.nvim_get_current_win()
    local wintype = vim.fn.win_gettype(win)
    return (wintype == "quickfix" or wintype == "loclist") and wintype or nil
end

--- @param win integer
--- @param get_loclist boolean
--- @return fun(table):any|nil
function M.get_getlist(win, get_loclist)
    vim.validate("get_loclist", get_loclist, "boolean")
    vim.validate("win", win, "number")
    vim.validate("win", win, function()
        return vim.api.nvim_win_is_valid(win)
    end)

    local wintype = vim.fn.win_gettype(win)
    local is_quickfix_win = wintype == "qflist"
    local cannot_have_loclist = not (wintype == "" or wintype == "loclist")
    if (not get_loclist) or is_quickfix_win or cannot_have_loclist then
        return vim.fn.getqflist
    end

    return function(what)
        win = win or vim.api.nvim_get_current_win()
        return what and vim.fn.getloclist(win, what) or vim.fn.getloclist(win)
    end
end

--- @param is_loclist? boolean
--- @param win? integer
--- If is_loclist is true and no win is provided, will default to current window
function M.get_setlist(is_loclist, win)
    if not is_loclist then
        return vim.fn.setqflist
    end

    return function(dict, a, b)
        local action, what
        if type(a) == "table" then
            action = ""
            what = a
        elseif type(a) == "string" and a ~= "" or a == "" then
            action = a
            what = b or {}
        elseif a == nil then
            action = ""
            what = b or {}
        else
            error("Invalid action: must be a non-nil string")
        end

        win = win or vim.api.nvim_get_current_win()
        vim.fn.setloclist(win, dict, action, what)
    end
end

-- TODO: For new lists, this should scan to see if there is an empty list available before the
-- end
--- @param getlist fun(integer, table)|fun(table)
--- @param action string
--- @return integer|string
function M.get_list_nr(getlist, action)
    if vim.v.count < 1 then
        local replace = action == "overwrite" or action == "merge"
        return replace and getlist({ nr = 0 }).nr or "$"
    else
        -- TODO: Double check that this works in the new list case
        return math.min(vim.v.count, getlist({ nr = "$" }).nr)
    end
end

--- @param entry table
--- @return string
local function get_qf_key(entry)
    local fname = entry.filename or ""
    local lnum = tostring(entry.lnum or 0)
    local col = tostring(entry.col or 0)
    return fname .. ":" .. lnum .. ":" .. col
end

--- @param a table
--- @param b table
--- @return table
function M.merge_qf_lists(a, b)
    local merged = {}
    local seen = {}

    local x = #a > #b and a or b
    local y = #a > #b and b or a

    for _, entry in ipairs(x) do
        local key = get_qf_key(entry)
        seen[key] = true
        table.insert(merged, entry)
    end

    for _, entry in ipairs(y) do
        local key = get_qf_key(entry)
        if not seen[key] then
            seen[key] = true
            table.insert(merged, entry)
        end
    end

    return merged
end

--- @param is_loclist boolean
--- @return fun(table):boolean
function M.get_openlist(is_loclist)
    local el = require("mjm.error-list")

    if is_loclist then
        return function(opts)
            return el.open_loclist(opts)
        end
    else
        return function(opts)
            return el.open_qflist(opts)
        end
    end
end

--- @param is_loclist boolean
--- @return fun(table):boolean
function M.get_resizelist(is_loclist)
    local el = require("mjm.error-list")

    if is_loclist then
        return function()
            return el.resize_loclist()
        end
    else
        return function()
            return el.resize_qflist()
        end
    end
end

return M
