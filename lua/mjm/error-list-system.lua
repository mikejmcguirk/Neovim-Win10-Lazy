local M = {}

-------------
--- TYPES ---
-------------

--- @class QfRancherSystemOpts
--- @field async? boolean
--- @field cmd_parts? string[]
--- @field timeout? integer

-------------------
--- MODULE INFO ---
-------------------

local default_async = true
local default_timeout = 4000

-----------------
--- SYSTEM DO ---
-----------------

function M.validate_system_opts(system_opts)
    system_opts = system_opts or {}
    vim.validate("system_opts", system_opts, "table")

    vim.validate("system_opts.cmd_parts", system_opts.cmd_parts, { "nil", "table" })
    vim.validate("system_opts.async", system_opts.async, { "boolean", "nil" })
    system_opts.async = system_opts.async == nil and default_async or system_opts.async
    vim.validate("system_opts.timeout", system_opts.timeout, { "nil", "number" })
    system_opts.timeout = system_opts.timeout == nil and default_timeout or system_opts.timeout

    return true
end

local function validate_system_do(system_opts, output_opts)
    system_opts = system_opts or {}
    output_opts = output_opts or {}

    local eu = require("mjm.error-list-util")

    vim.validate("system_opts", system_opts, function()
        return M.validate_system_opts()
    end)

    vim.validate("system_opts.cmd_parts", system_opts.cmd_parts, "table")
    eu._check_str_list(system_opts.cmd_parts)

    eu._validate_output_opts(output_opts)
end

--- @param obj vim.SystemCompleted
--- @param output_opts QfRancherOutputOpts
local function handle_output(obj, output_opts)
    if obj.code ~= 0 then
        local code = obj.code and "Exit code: " .. obj.code or ""
        local err = (obj.stderr and #obj.stderr > 0) and "Error: " .. obj.stderr or ""
        local msg = code .. " " .. err

        vim.api.nvim_echo({ { msg, "ErrorMsg" } }, true, { err = true })
        return
    end

    local eu = require("mjm.error-list-util") --- @type QfRancherUtils
    if not eu._is_valid_loclist_output(output_opts) then
        return
    end

    local lines = vim.split(obj.stdout or "", "\n", { trimempty = true }) --- @type string[]
    local qf_dict = vim.fn.getqflist({ lines = lines }) --- @type {items: table[]}
    if output_opts.list_item_type then
        for _, item in pairs(qf_dict.items) do
            item.type = output_opts.list_item_type
        end
    end

    if output_opts.action ~= "add" then
        table.sort(qf_dict, require("mjm.error-list-sort")._sort_fname_asc)
    end

    local getlist = eu._get_getlist(output_opts)
    if not getlist then
        return
    end

    local setlist = eu._get_setlist(output_opts)
    if not setlist then
        return
    end

    local set_opts = { new_items = qf_dict.items, getlist = getlist, setlist = setlist }
    eu._set_list_items(set_opts, output_opts)

    -- TODO: There should be an output opts function that handles opening the list afterwards
    -- So like, see if it's open, maybe resize it, do history to move to the right one, and
    -- so on. It's repeated logic that only needs to be written once
    -- local elo = require("mjm.error-list-open")
    -- if output_opts.is_loclist then
    --     elo._open_loclist()
    -- else
    --     elo._open_qflist()
    -- end
end

-- TODO: This needs to be a public API so that way people can use it to build cmd line extensions
-- off of it

--- @param system_opts QfRancherSystemOpts
--- @param output_opts QfRancherOutputOpts
--- @return nil
function M.system_do(system_opts, output_opts)
    validate_system_do(system_opts, output_opts)

    local vim_system_opts = { text = true, timeout = system_opts.timeout or default_timeout }
    if system_opts.async then
        vim.system(system_opts.cmd_parts, vim_system_opts, function(obj)
            vim.schedule(function()
                handle_output(obj, output_opts)
            end)
        end)
    else
        local obj = vim.system(system_opts.cmd_parts, vim_system_opts)
            :wait(system_opts.timeout or default_timeout)
        handle_output(obj, output_opts)
    end
end

return M

--------------
--- # TODO ---
--------------

--- Global Checklist:
--- - Check that all functions have reasonable default sorts
--- - Check that window height updates are triggered where appropriate
--- - Check that functions have proper visibility
--- - Check that all mappings have plugs and cmds
--- - Check that all maps/cmds/plugs have desc fieldss
--- - Check that all functions have annotations and documentation
--- - Check that the qf and loclist versions are both properly built for purpose. Should be able
---     to use the loclist function for buf/win specific info
