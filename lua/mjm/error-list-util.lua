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

--- @alias QfRancherSetlistAction "add"|"new"|"overwrite"

-- TODO: Replace the system functions with these

-- TODO: Where possible, replace loclist finding functions throughout the plugin with the below

--- @param x integer
--- @param y integer
--- @param min integer
--- @param max integer
--- @return integer
function M.wrapping_add(x, y, min, max)
    local period = max - min + 1 --- @type integer
    return ((x - min + y) % period) + min
end

--- @param x integer
--- @param y integer
--- @param min integer
--- @param max integer
--- @return integer
function M.wrapping_sub(x, y, min, max)
    local period = max - min + 1 --- @type integer
    return ((x - y - min) % period) + min
end

--- @param win integer
--- @param qf_id integer
--- @return integer|nil
local function find_loclist_window(win, qf_id)
    vim.validate("qf_id", qf_id, "number")
    vim.validate("win", win, "number")
    vim.validate("win", win, function()
        return vim.api.nvim_win_is_valid(win)
    end)

    local win_tabpage = vim.api.nvim_win_get_tabpage(win) --- @type integer
    local win_tabpage_wins = vim.api.nvim_tabpage_list_wins(win_tabpage) --- @type integer[]
    for _, t_win in pairs(win_tabpage_wins) do
        local tw_qf_id = vim.fn.getloclist(t_win, { id = 0 }).id --- @type integer
        if tw_qf_id == qf_id then
            local t_win_buf = vim.api.nvim_win_get_buf(t_win) --- @type integer
            --- @type string
            local t_win_buftype = vim.api.nvim_get_option_value("buftype", { buf = t_win_buf })
            if t_win_buftype == "quickfix" then
                return t_win
            end
        end
    end

    return nil
end

-- TODO replace the function in open with this one

--- @param opts?{tabpage?: integer, win?:integer}
--- @return integer|nil
function M.find_qf_win(opts)
    opts = opts or {}
    vim.validate("opts.tabpage", opts.tabpage, { "nil", "number" })
    vim.validate("opts.win", opts.win, { "nil", "number" })
    if opts.tabpage then
        local tab_wins = vim.api.nvim_tabpage_list_wins(opts.tabpage)
        for _, win in pairs(tab_wins) do
            if vim.fn.win_gettype(win) == "quickfix" then
                return win
            end
        end

        return nil
    end

    -- TODO: This logic can be compresse
    local win = opts.win or vim.api.nvim_get_current_win()
    local win_tabpage = vim.api.nvim_win_get_tabpage(win)
    local tab_wins = vim.api.nvim_tabpage_list_wins(win_tabpage)
    for _, t_win in pairs(tab_wins) do
        if vim.fn.win_gettype(t_win) == "quickfix" then
            return t_win
        end
    end

    return nil
end

--- @return boolean
function M.has_any_qflist()
    local max_nr = vim.fn.getqflist({ nr = "$" }).nr --- @type integer
    if max_nr == 0 then
        return false
    end

    for i = 1, max_nr do
        local size = vim.fn.getqflist({ nr = i, size = 0 }).size --- @type integer
        if size > 0 then
            return true
        end
    end

    return false
end

--- @param opts {win:integer}
--- @return integer, integer|nil
--- Get loclist information for a window
--- Opts:
--- - win: The window to check loclist information for
--- Returns:
--- - the qf_id and the open loclist winid, if it exists
function M.get_loclist_info(opts)
    opts = opts or {}
    vim.validate("opts.win", opts.win, { "nil", "number" })
    local win = opts.win or vim.api.nvim_get_current_win() --- @type integer
    local qf_id = vim.fn.getloclist(win, { id = 0 }).id --- @type integer
    if qf_id == 0 then
        return qf_id, nil
    end

    return qf_id, find_loclist_window(win, qf_id)
end

--- @param opts {win?:integer}
--- @return boolean
function M.has_any_loclist(opts)
    opts = opts or {}
    vim.validate("opts.win", opts.win, { "nil", "number" })
    local win = opts.win or vim.api.nvim_get_current_win() --- @type integer

    local max_nr = vim.fn.getloclist(win, { nr = "$" }).nr --- @type integer
    if max_nr == 0 then
        return false
    end

    for i = 1, max_nr do
        local size = vim.fn.getloclist(win, { nr = i, size = 0 }).size --- @type integer
        if size > 0 then
            return true
        end
    end

    return false
end

-- TODO: Could this be used in the ftplugin maps?

--- @param opts?{tabpage?:integer}
--- @return integer[]
function M.find_orphan_loclists(opts)
    opts = opts or {}
    vim.validate("opts.tabpage", opts.tabpage, { "nil", "number" })
    local tabpage = opts.tabpage or vim.api.nvim_get_current_tabpage() --- @type integer
    local tab_wins = vim.api.nvim_tabpage_list_wins(tabpage) --- @type integer[]

    local orphans = {} --- @type integer[]
    for _, win in pairs(tab_wins) do
        if vim.fn.win_gettype(win) == "loclist" then
            local qf_id = vim.fn.getloclist(win, { id = 0 }).id
            if qf_id == 0 then
                table.insert(orphans, win)
            else
                local is_orphan = true
                for _, inner_win in pairs(tab_wins) do
                    local iw_qf_id = vim.fn.getloclist(inner_win, { id = 0 }).id
                    if inner_win ~= win and iw_qf_id == qf_id then
                        is_orphan = false
                        break
                    end
                end

                if is_orphan then
                    table.insert(orphans, win)
                end
            end
        end
    end

    return orphans
end

-- NOTE: It is simpler in theory to only pass the win value to the getlist and setlist functions,
-- returning the qflist functions if win is nil. But this forces contrivance upstream

--- @param win integer
--- @return string|nil
function M.get_listtype(win)
    win = win or vim.api.nvim_get_current_win()
    local wintype = vim.fn.win_gettype(win)
    return (wintype == "quickfix" or wintype == "loclist") and wintype or nil
end

--- @param opts {get_loclist?:boolean, win?:integer}
--- @return fun(table):any|nil
--- If no win is provided, the current win is used as a fallback
--- If no get_loclist value is provided or it is false, getqflist is always returned
--- If a win is provided but it cannot have a loclist, getqflist is returned
function M.get_getlist(opts)
    opts = opts or {}
    vim.validate("opts.get_loclist", opts.get_loclist, { "boolean", "nil" })
    vim.validate("opts.win", opts.win, { "nil", "number" })
    if opts.win then
        vim.validate("opts.win", opts.win, function()
            return vim.api.nvim_win_is_valid(opts.win)
        end)
    end

    if not opts.get_loclist then
        return vim.fn.getqflist
    end

    local win = opts.win or vim.api.nvim_get_current_win()
    local wintype = vim.fn.win_gettype(win)
    local can_have_loclist = wintype == "" or wintype == "loclist"
    if not can_have_loclist then
        return vim.fn.getqflist
    end

    return function(what)
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
        local replace = action == "overwrite" or action == "add"
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
    local elo = require("mjm.error-list-open")

    if is_loclist then
        return function(opts)
            return elo.open_loclist(opts)
        end
    else
        return function(opts)
            return elo.open_qflist(opts)
        end
    end
end

--- @param is_loclist boolean
--- @return fun(table):boolean
function M.get_resizelist(is_loclist)
    local elo = require("mjm.error-list-open")

    if is_loclist then
        return function()
            return elo.resize_loclist()
        end
    else
        return function()
            return elo.resize_qflist()
        end
    end
end

return M
