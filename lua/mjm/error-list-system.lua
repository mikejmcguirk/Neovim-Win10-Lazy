local ea = Qfr_Defer_Require("mjm.error-list-stack") ---@type QfrStack
local et = Qfr_Defer_Require("mjm.error-list-tools") ---@type QfrTools
local eu = Qfr_Defer_Require("mjm.error-list-util") ---@type QfrUtil
local ey = Qfr_Defer_Require("mjm.error-list-types") ---@type QfrTypes

---@mod System Sends diags to the qf list

---@class QfrSystem
local System = {}

---@param obj vim.SystemCompleted
---@param output_opts QfrOutputOpts
local function handle_output(obj, output_opts)
    if obj.code ~= 0 then
        ---@type string
        local err = (obj.stderr and #obj.stderr > 0) and "Error: " .. obj.stderr or ""
        local msg = (obj.code and "Exit code: " .. obj.code or "") .. " " .. err ---@type string
        vim.api.nvim_echo({ { msg, "ErrorMsg" } }, true, { err = true })
        return
    end

    local src_win = output_opts.src_win ---@type integer
    if src_win and not eu._valid_win_for_loclist(src_win) then return end

    local lines = vim.split(obj.stdout or "", "\n", { trimempty = true }) ---@type string[]
    if #lines == 0 then return end

    local qf_dict = vim.fn.getqflist({ lines = lines }) ---@type {items: table[]}
    if output_opts.what.user_data.list_item_type then
        for _, item in pairs(qf_dict.items) do
            item.type = output_opts.what.user_data.list_item_type
        end
    end

    ---@type QfrWhat
    local what_set = vim.tbl_deep_extend("force", output_opts.what, { items = qf_dict.items })
    local dest_nr = et._set_list(src_win, output_opts.action, what_set) ---@type integer
    if eu._get_g_var("qf_rancher_auto_open_changes") then
        ea._history(src_win, dest_nr, {
            always_open = true,
            default = "current",
            silent = true,
        })
    end
end

-- DOCUMENT: How to use this

---@param system_opts QfrSystemOpts
---@param output_opts QfrOutputOpts
---@return nil
function System.system_do(system_opts, output_opts)
    ey._validate_system_opts(system_opts)
    ey._validate_output_opts(output_opts)

    ---@type vim.SystemOpts
    local vim_system_opts = { text = true, timeout = system_opts.timeout or ey._default_timeout }
    if system_opts.sync then
        local obj = vim.system(system_opts.cmd_parts, vim_system_opts)
            :wait(system_opts.timeout or ey._default_timeout) ---@type vim.SystemCompleted
        handle_output(obj, output_opts)
    else
        vim.system(system_opts.cmd_parts, vim_system_opts, function(obj)
            vim.schedule(function()
                handle_output(obj, output_opts)
            end)
        end)
    end
end

return System
---@export sys

-- TODO: Tests
-- TODO: Docs
