local M = {}

-----------------
--- SYSTEM DO ---
-----------------

--- @param system_opts QfRancherSystemOpts
--- @param what QfRancherWhat
--- @return nil
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
        --- @type string
        local err = (obj.stderr and #obj.stderr > 0) and "Error: " .. obj.stderr or ""
        local msg = (obj.code and "Exit code: " .. obj.code or "") .. " " .. err --- @type string
        vim.api.nvim_echo({ { msg, "ErrorMsg" } }, true, { err = true })
        return
    end

    local eu = require("mjm.error-list-util") --- @type QfRancherUtils
    local src_win = what.user_data.src_win --- @type integer
    if src_win and not eu._win_can_have_loclist(src_win) then
        local msg = "Win " .. src_win .. " cannot have a location list"
        vim.api.nvim_echo({ { msg, "" } }, false, {})
        return
    end

    local lines = vim.split(obj.stdout or "", "\n", { trimempty = true }) --- @type string[]
    local qf_dict = vim.fn.getqflist({ lines = lines }) --- @type {items: table[]}
    if what.user_data.list_item_type then
        for _, item in pairs(qf_dict.items) do
            item.type = what.user_data.list_item_type
        end
    end

    --- @type QfRancherWhat
    local what_set = vim.tbl_deep_extend("force", what, { items = qf_dict.items })
    local et = require("mjm.error-list-tools") --- @type QfRancherTools
    local dest_nr = et._set_list(what_set) --- @type integer

    if vim.g.qf_rancher_auto_open_changes then
        require("mjm.error-list-stack")._history(src_win, dest_nr, {
            silent = true,
            always_open = true,
        })
    end
end

--- DOCUMENT: How to use this

--- @param system_opts QfRancherSystemOpts
--- @param what QfRancherWhat
--- @return nil
function M.system_do(system_opts, what)
    system_opts = system_opts or {}
    what = what or {}
    validate_system_do(system_opts, what)

    local ey = require("mjm.error-list-types")
    local vim_system_opts = { text = true, timeout = system_opts.timeout or ey._default_timeout }
    if system_opts.sync then
        local obj = vim.system(system_opts.cmd_parts, vim_system_opts)
            :wait(system_opts.timeout or ey._default_timeout)
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

--- Tests
