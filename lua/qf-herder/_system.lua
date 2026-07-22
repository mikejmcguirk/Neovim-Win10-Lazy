local api = vim.api
local fn = vim.fn

local _util = require("qf-herder._util")

local M = {}

---@class qf-rancher.system.Ctx
---@field action "a"|"f"|"r"|"u"|" "
---@field item_type string
---@field reuse_title boolean
---@field sort fun(a:vim.quickfix.entry, b:vim.quickfix.entry): boolean

-- TODO: Integrate this back into init.lua
---@class qf-rancher.system.Cfg
---@field silent boolean
---@field timeout uinteger

---@param src_win integer|nil
---@param obj vim.SystemCompleted
---@param what table
---@param ctx qf-rancher.system.Ctx
---@param cfg qf-rancher.system.Cfg
local function output_set_to_list(src_win, obj, what, ctx, cfg)
    if obj.code == nil or obj.code ~= 0 then
        local code_str = obj.code ~= nil and "Exit code: " .. obj.code or ""
        local err = obj.stderr ~= nil and #obj.stderr > 0 and "Error: " .. obj.stderr or ""
        api.nvim_echo({ { code_str .. " " .. err, "ErrorMsg" } }, true, {})
        return
    end

    -- TODO: This check is supposed to be if the window can accept a location list at all. It
    -- also should not be deferred until after an external cmd is run, especially since this might
    -- be non-trivial ops like greps or compiler results. This simply needs to be re-validated,
    -- since the user might do something like accidently close the win, and we can re-bundle the
    -- validity checking as well.
    if src_win then
        local qf_id = fn.getloclist(src_win, { id = 0 }).id ---@type uinteger
        if not _util.qf_id_valid_or_echo_no_ll(qf_id, cfg.silent) then
            return
        end
    end

    local lines = vim.split(obj.stdout or "", "\n", { trimempty = true })
    if #lines == 0 then
        api.nvim_echo({ { "No output" } }, false, {})
        return
    end

    local lines_dict = fn.getqflist({ lines = lines }) ---@type { items: vim.quickfix.entry[] }
    if #lines_dict.items < 1 then
        api.nvim_echo({ { "No items" } }, false, {})
        return
    end

    local lines_dict_items = lines_dict.items
    table.sort(lines_dict_items, ctx.sort)
    local item_type = ctx.item_type
    if item_type ~= "" then
        for _, item in ipairs(lines_dict_items) do
            item.type = item_type
        end
    end

    -- local orig_src_win = src_win
    -- if src_win and system_opts.list_item_type == "\1" then
    --     src_win = get_lhelp_win(src_win)
    --     -- TODO: Doesn't set_list do this?
    --     if type(what.nr) == "number" then
    --         local max_nr = rt._get_list(src_win, { nr = "$" }).nr ---@type integer
    --         ---@diagnostic disable-next-line: param-type-mismatch
    --         what.nr = math.min(what.nr, max_nr)
    --     end
    -- end

    -- TODO: Still handle \1 specifically since it's the only item type with designated behavior.
    -- If the current win cannot accept help results, read a cfg value for how to handle.
    -- Split in one of four directions. Don't allow `botright`/`topleft`. This should apply for
    -- both ll and qf (in line with defaults).

    -- TODO: Like the code above, if we change origin windows, make sure we move if we are not
    -- focusing on the list.

    -- TODO: Have a config value for auto-opening results and set it to true. (Different from
    -- default behavior it seems, though that might be a cmd arg. Double check.)

    -- local what_set = vim.tbl_deep_extend("force", what, { items = lines_dict.items })
    -- local dest_nr = rt._set_list(src_win, action, what_set) ---@type integer
    -- if dest_nr < 1 then
    --     api.nvim_echo({ { "Unable to set list", "ErrorMsg" } }, true, {})
    --     return
    -- end

    -- if src_win and orig_src_win ~= src_win then
    --     -- Set so that lopen has proper window context
    --     api.nvim_set_current_win(src_win)
    -- end

    -- if vim.g.qfr_auto_open_changes then
    --     local ra = require("qf-rancher.stack")
    --     local _, _, _ = ra._goto_history(src_win, dest_nr, { silent = true })
    --     rw._open_list(src_win, {
    --         close_others = true,
    --         silent = true,
    --         on_list = function(list_win, _)
    --             api.nvim_set_current_win(list_win)
    --             rw._resize_list_win(list_win)
    --         end,
    --     })
    -- end

    -- if src_win and orig_src_win ~= src_win then
    --     local first_item = what_set.items[1]
    --     local dest_bt = system_opts.list_item_type == "\1" and "help" or ""
    --     ru._open_item(first_item, src_win, { buftype = dest_bt, clearjumps = true, focus = true })
    -- end
end

---@param src_win uinteger|nil
---@param cmd_parts string[]
---@param sync boolean
---`""` is standard. `"\1"` for help.
---@param what table See |setqflist-what|
---@param ctx qf-rancher.system.Ctx
---@param cfg qf-rancher.system.Cfg
function M.cmd_to_list(src_win, cmd_parts, sync, what, ctx, cfg)
    local timeout = cfg.timeout
    ---@type vim.SystemOpts
    local vim_system_opts = { text = true, timeout = timeout }
    if sync then
        local obj = vim.system(cmd_parts, vim_system_opts):wait(timeout)
        output_set_to_list(src_win, obj, what, ctx)
    else
        vim.system(cmd_parts, vim_system_opts, function(obj)
            vim.schedule(function()
                output_set_to_list(src_win, obj, what, ctx, cfg)
            end)
        end)
    end
end

return M
