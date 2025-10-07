local M = {}

-------------------
--- MODULE INFO ---
-------------------

--- TODO: Should be in types module
local default_timeout = 4000

-----------------
--- SYSTEM DO ---
-----------------

local function validate_system_do(system_opts, what)
    local eu = require("mjm.error-list-util")
    local ey = require("mjm.error-list-types")
    ey._validate_system_opts(system_opts)
    eu._is_valid_str_list(system_opts.cmd_parts)
    ey._validate_what(what)
end

--- @param obj vim.SystemCompleted
--- @param what QfRancherWhat
local function handle_output(obj, what)
    if obj.code ~= 0 then
        local err = (obj.stderr and #obj.stderr > 0) and "Error: " .. obj.stderr or ""
        local msg = (obj.code and "Exit code: " .. obj.code or "") .. " " .. err
        vim.api.nvim_echo({ { msg, "ErrorMsg" } }, true, { err = true })
        return
    end

    local eu = require("mjm.error-list-util") --- @type QfRancherUtils
    local list_win = what.user_data.list_win
    if list_win and not eu._win_can_have_loclist(list_win) then
        return
    end

    local lines = vim.split(obj.stdout or "", "\n", { trimempty = true }) --- @type string[]
    local qf_dict = vim.fn.getqflist({ lines = lines }) --- @type {items: table[]}
    if what.user_data.list_item_type then
        for _, item in pairs(qf_dict.items) do
            item.type = what.user_data.list_item_type
        end
    end

    --- TODO: Remove this when sorting is wholly moved to _set_list
    if what.user_data.action ~= "add" then
        table.sort(qf_dict, require("mjm.error-list-sort")._sort_fname_asc)
    end

    --- @type QfRancherWhat
    local what_set = vim.tbl_deep_extend("force", what, { items = qf_dict.items })
    local et = require("mjm.error-list-tools") --- @type QfRancherTools
    local dest_nr = et._set_list(what_set)

    if vim.g.qf_rancher_auto_open_changes then
        require("mjm.error-list-stack")._history(list_win, {
            count = dest_nr,
            silent = true,
            always_open = true,
        })
    end
end

-- TODO: This needs to be a public API so that way people can use it to build cmd line extensions
-- off of it

--- @param system_opts QfRancherSystemOpts
--- @param what QfRancherWhat
--- @return nil
function M.system_do(system_opts, what)
    system_opts = system_opts or {}
    what = what or {}
    validate_system_do(system_opts, what)

    local vim_system_opts = { text = true, timeout = system_opts.timeout or default_timeout }
    if system_opts.sync then
        local obj = vim.system(system_opts.cmd_parts, vim_system_opts)
            :wait(system_opts.timeout or default_timeout)
        handle_output(obj, what)
    else
        vim.system(system_opts.cmd_parts, vim_system_opts, function(obj)
            vim.schedule(function()
                handle_output(obj, what)
            end)
        end)
    end
end

return M

------------
--- TODO ---
------------

--- Global Checklist:
--- - Check that all functions have reasonable default sorts
--- - Check that window height updates are triggered where appropriate
--- - Check that functions have proper visibility
--- - Check that all mappings have plugs and cmds
--- - Check that all maps/cmds/plugs have desc fieldss
--- - Check that all functions have annotations and documentation
--- - Check that the qf and loclist versions are both properly built for purpose. Should be able
---     to use the loclist function for buf/win specific info
