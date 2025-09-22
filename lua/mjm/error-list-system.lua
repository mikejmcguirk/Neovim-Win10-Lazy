--- TODO:
--- - Check that all functions have reasonable default sorts
--- - Check that window height updates are triggered where appropriate
--- - Check that functions have proper visibility
--- - Check that all mappings have plugs and cmds
--- - Check that all maps/cmds/plugs have desc fieldss
--- - Check that all functions have annotations and documentation

local M = {}

-------------
--- Types ---
-------------

--- @class QfRancherSystemIn
--- @field cmd_parts? string[]
--- @field err_chunk? [string, string]
--- @field err_msg_hist? boolean
--- @field title? string

--- @class QfRancherSystemOpts
--- @field async? boolean
--- @field loclist? boolean
--- @field add? boolean
--- @field overwrite? boolean
--- @field timeout? integer
--- @field type? string

----------------------
--- System Helpers ---
----------------------

local function get_qf_key(entry)
    local fname = entry.filename or ""
    local lnum = tostring(entry.lnum or 0)
    local col = tostring(entry.col or 0)
    return fname .. ":" .. lnum .. ":" .. col
end

local function merge_qf_lists(a, b)
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

-- TODO: THere's a reference here to remove
--- @param win? integer
local function get_getlist(win)
    if not win then
        return vim.fn.getqflist
    end

    return function(what)
        if not what then
            return vim.fn.getloclist(win)
        end

        return vim.fn.getloclist(win, what)
    end
end

local function get_setlist(win)
    if not win then
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

        vim.fn.setloclist(win, dict, action, what)
    end
end

--- @param get_cmd_parts fun():boolean, QfRancherSystemIn
--- @return boolean, QfRancherSystemIn|nil
local function resolve_cmd_parts(get_cmd_parts)
    if type(get_cmd_parts) ~= "function" then
        local chunk = { "No function provided to get cmd parts", "ErrorMsg" }
        vim.api.nvim_echo({ chunk }, true, { err = true })
        return false, nil
    end

    local ok, system_in = get_cmd_parts()

    if not ok then
        local chunk = system_in.err_chunk or { "Unknown error getting command parts", "ErrorMsg" }
        vim.api.nvim_echo({ chunk }, system_in.err_msg_hist or true, { err = true })
        return false, nil
    end

    if type(system_in.cmd_parts) ~= "table" then
        local chunk = { "No cmd parts table provided from input function", "ErrorMsg" }
        vim.api.nvim_echo({ chunk }, true, { err = true })
        return false, nil
    end

    if #system_in.cmd_parts < 1 then
        local chunk = { "cmd_parts empty in qf_system_wrapper", "ErrorMsg" }
        vim.api.nvim_echo({ chunk }, true, { err = true })
        return false, nil
    end

    return true, system_in
end

--- @param getlist function
--- @param opts table
--- @return integer|string
local function get_list_nr(getlist, opts)
    opts = opts or {}

    if vim.v.count < 1 then
        if opts.overwrite or opts.add then
            return getlist({ nr = 0 }).nr
        else
            return "$"
        end
    else
        return math.min(vim.v.count, getlist({ nr = "$" }).nr)
    end
end

----------------------
--- System Wrapper ---
----------------------

--- @param get_cmd_parts fun():boolean, QfRancherSystemIn
--- @param opts QfRancherSystemOpts
--- @return nil
function M.qf_sys_wrap(get_cmd_parts, opts)
    --- @type boolean, QfRancherSystemIn|nil
    local ok, system_in = resolve_cmd_parts(get_cmd_parts)
    if (not ok) or not system_in then
        return
    end --- Errors printed in resolve_cmd_parts

    opts = opts or {}
    local cur_win = opts.loclist and vim.api.nvim_get_current_win() or nil
    local cur_wintype = cur_win and vim.fn.win_gettype(cur_win) or nil
    if opts.loclist and cur_wintype == "quickfix" then
        local chunk = { "Cannot create a loclist in a quickfix window", "" }
        vim.api.nvim_echo({ chunk }, false, {})
        return
    end

    local getlist = get_getlist(cur_win)
    local list_nr = get_list_nr(getlist, opts) --- @type integer|string

    local function handle_result(obj)
        if obj.code ~= 0 then
            local code = obj.code and "Exit code: " .. obj.code or ""
            local err = (obj.stderr and #obj.stderr > 0) and "Error: " .. obj.stderr or ""
            local msg = code .. " " .. err

            vim.api.nvim_echo({ { msg, "ErrorMsg" } }, true, { err = true })
            return
        end

        local lines = vim.split(obj.stdout or "", "\n", { trimempty = true })
        local qf_dict = vim.fn.getqflist({ lines = lines })

        if opts.type then
            for _, item in pairs(qf_dict.items) do
                item.type = opts.type
            end
        end

        -- TODO: I have this copied over to the diags module as well
        -- It seems like what we want is a separate bit of code in a utils module or something to
        -- handle setting to the list. So you would want the formatted items, the list type,
        -- the win number, and the action, and then that can be calculated
        -- Especially relevant when you start dealing with cases like copies, or more complex
        -- add logic into blanks
        -- TODO: outline anyway, but also it should not be possible to both add and overwrite
        -- though I'm not sure it hurts anything so iunno. Or maybe it should be an enum
        if opts.add then
            local cur_list = getlist({ nr = list_nr, items = true })
            qf_dict.items = merge_qf_lists(cur_list.items, qf_dict.items)
        end

        table.sort(qf_dict.items, require("mjm.error-list-sort").sort_fname_asc)
        local title = type(system_in.title) == "string" and system_in.title or ""
        local setlist = get_setlist(cur_win)
        local action = (opts.add or opts.overwrite) and "r" or " "
        setlist({}, action, { items = qf_dict.items, nr = list_nr, title = title })

        -- TODO: do a getopen thing here too
        -- TODO: if either of these return false, do a resize instead
        local elo = require("mjm.error-list-open")
        if opts.loclist then
            elo.open_loclist()
        else
            elo.open_qflist()
        end

        -- TODO: need a wrapper for these that resizes
        if opts.overwrite or opts.add then
            if opts.loclist then
                vim.cmd(list_nr .. "lhistory")
            else
                vim.cmd(list_nr .. "chistory")
            end
        end
    end

    if opts.async then
        vim.system(system_in.cmd_parts, { text = true }, function(obj)
            vim.schedule(function()
                handle_result(obj)
            end)
        end)
    else
        local obj = vim.system(system_in.cmd_parts, { text = true }):wait(opts.timeout or 2000)
        handle_result(obj)
    end
end

return M
