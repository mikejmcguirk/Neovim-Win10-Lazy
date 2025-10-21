local eo = Qfr_Defer_Require("mjm.error-list-open") ---@type QfrOpen
local et = Qfr_Defer_Require("mjm.error-list-tools") ---@type QfrTools
local eu = Qfr_Defer_Require("mjm.error-list-util") ---@type QfrUtil
local ey = Qfr_Defer_Require("mjm.error-list-types") ---@type QfrTypes

local api = vim.api

--- @class QfrStack
local M = {}

------------------------
--- Helper Functions ---
------------------------

---@param src_win integer|nil
---@return nil
local function resize_after_stack_change(src_win)
    if not eu._get_g_var("qf_rancher_auto_list_height") then return end
    if src_win then
        local src_win_tabpage = api.nvim_win_get_tabpage(src_win) ---@type integer
        eo._resize_loclists_by_win(src_win, { tabpage = src_win_tabpage })
    else
        eo._resize_qfwins({ all_tabpages = true })
    end
end

-------------------
--- OLDER/NEWER ---
-------------------

-- TODO: This command centers the view on the current idx. If you are scrolled in the list but
-- the idx is off screen, it will center the view on that idx. Save and restore view if
-- cur_stack_nr does not change

---@param src_win integer|nil
---@param count integer
---@param arithmetic function
---@return nil
local function change_history(src_win, count, arithmetic)
    ey._validate_win(src_win, true)
    ey._validate_uint(count)
    vim.validate("arithmetic", arithmetic, "callable")

    local stack_len = et._get_list(src_win, { nr = "$" }).nr ---@type integer
    if stack_len < 1 then
        api.nvim_echo({ { "Stack is empty", "" } }, false, {})
        return
    end

    local cur_list_nr = et._get_list(src_win, { nr = 0 }).nr ---@type integer
    local count1 = eu._count_to_count1(count) ---@type integer
    local new_list_nr = arithmetic(cur_list_nr, count1, 1, stack_len) ---@type integer

    local cmd = src_win and "lhistory" or "chistory" ---@type string
    api.nvim_cmd({ cmd = cmd, count = new_list_nr }, {})
    if eu._get_g_var("qf_rancher_debug_assertions") then
        local list_nr_after = et._get_list(src_win, { nr = 0 }).nr ---@type integer
        assert(new_list_nr == list_nr_after)
    end

    if cur_list_nr ~= new_list_nr then resize_after_stack_change(src_win) end
end

---@param count integer
---@return nil
function M._q_older(count)
    change_history(nil, count, eu._wrapping_sub)
end

---@param count integer
---@return nil
function M._q_newer(count)
    change_history(nil, count, eu._wrapping_add)
end

---@param cargs vim.api.keyset.create_user_command.command_args
---@return nil
function M._q_older_cmd(cargs)
    M._q_older(cargs.count)
end

---@param cargs vim.api.keyset.create_user_command.command_args
---@return nil
function M._q_newer_cmd(cargs)
    M._q_newer(cargs.count)
end

---@param count integer
---@param arithmetic function
---@return nil
local function l_change_history(win, count, arithmetic)
    eu._locwin_check(win, function()
        change_history(win, count, arithmetic)
    end)
end

---@param win integer
---@param count integer
---@return nil
function M._l_older(win, count)
    l_change_history(win, count, eu._wrapping_sub)
end

---@param win integer
---@param count integer
---@return nil
function M._l_newer(win, count)
    l_change_history(win, count, eu._wrapping_add)
end

---@param cargs vim.api.keyset.create_user_command.command_args
---@return nil
function M._l_older_cmd(cargs)
    M._l_older(api.nvim_get_current_win(), cargs.count)
end

---@param cargs vim.api.keyset.create_user_command.command_args
---@return nil
function M._l_newer_cmd(cargs)
    M._l_newer(api.nvim_get_current_win(), cargs.count)
end

---------------
--- HISTORY ---
---------------

-- NOTE: In chistory/lhistory, a count of zero is treated the same as a count of 1. To show the
-- entire stack, the count must be nil. When using custom commands that take a count, a count of
-- zero is returned in cargs if none is provided. Counts of zero must be converted to nil

-- DOCUMENT: By default, the keymap version will print the current list, the cmds show the stack

---@param src_win integer|nil
---@param count integer
---@param opts QfRancherHistoryOpts
---@return nil
function M._get_history(src_win, count, opts)
    ey._validate_win(src_win, true)
    ey._validate_uint(count)
    ey._validate_history_opts(opts)

    local max_nr = et._get_list(src_win, { nr = "$" }).nr ---@type integer
    if max_nr < 1 then
        if not opts.silent then api.nvim_echo({ { "No entries", "" } }, false, {}) end
        return
    end

    local cur_nr = et._get_list(src_win, { nr = 0 }).nr ---@type integer
    local default = opts.default == "cur_list" and cur_nr or nil ---@type integer|nil
    local adj_count = count > 0 and math.min(count, max_nr) or default ---@type integer|nil

    local cmd = src_win and "lhistory" or "chistory" ---@type string
    ---@diagnostic disable-next-line: missing-fields
    api.nvim_cmd({ cmd = cmd, count = adj_count, mods = { silent = opts.silent } }, {})

    resize_after_stack_change(src_win)
    if opts.always_open then
        eo._open_list(src_win, { keep_win = opts.keep_win, nop_if_open = true })
    end
end

---@param count integer
---@param opts QfRancherHistoryOpts
---@return nil
function M._q_history(count, opts)
    M._get_history(nil, count, opts)
end

---@param win integer
---@param opts QfRancherHistoryOpts
---@return nil
function M._l_history(win, count, opts)
    ey._validate_win(win, false)
    eu._locwin_check(win, function()
        M._get_history(win, count, opts)
    end)
end

---@param cargs vim.api.keyset.create_user_command.command_args
---@return nil
function M._q_history_cmd(cargs)
    M._q_history(cargs.count, { default = "show_stack" })
end

---@param cargs vim.api.keyset.create_user_command.command_args
---@return nil
function M._l_history_cmd(cargs)
    M._l_history(api.nvim_get_current_win(), cargs.count, { default = "show_stack" })
end

----------------
--- DELETION ---
----------------

---@param src_win integer|nil
---@param count integer
---@return nil
function M._del(src_win, count)
    ey._validate_win(src_win, true)
    ey._validate_uint(count)

    local result = et._clear_list(src_win, count)
    if result == -1 or result == 0 then return end

    local cur_list_nr = et._get_list(src_win, { nr = 0 }).nr ---@type integer
    if eu._get_g_var("qf_rancher_debug_assertions") then
        local target = count == 0 and cur_list_nr or count ---@type integer
        assert(result == target)
    end

    if result == cur_list_nr then resize_after_stack_change(src_win) end
end

---@param count integer
---@return nil
function M._q_del(count)
    M._del(nil, count)
end

---@param count integer
---@return nil
function M._l_del(win, count)
    eu._locwin_check(win, function()
        M._del(win, count)
    end)
end

------------------
--- DELETE ALL ---
------------------

--- NOTE: The _del_all tools function contains the necessary validations

---@return nil
function M._q_del_all()
    et._set_list(nil, "f", {})
end

---@param src_win integer
---@return nil
function M._l_del_all(src_win)
    et._set_list(src_win, "f", {})
end

-- ---@param win integer
-- ---@return nil
-- function M._del_all(win)
--     et._del_all(win)
-- end

--- DOCUMENT: All overrides count

---@param cargs vim.api.keyset.create_user_command.command_args
---@return nil
function M._q_delete_cmd(cargs)
    if cargs.args == "all" then
        M._q_del_all()
        return
    end

    M._q_del(cargs.count)
end

---@param cargs vim.api.keyset.create_user_command.command_args
---@return nil
function M._l_delete_cmd(cargs)
    if cargs.args == "all" then
        M._l_del_all(api.nvim_get_current_win())
        return
    end

    M._l_del(api.nvim_get_current_win(), cargs.count)
end

return M

------------
--- TODO ---
------------

--- Testing
--- Docs

-----------
--- MID ---
-----------

-- Create a clean stack cmd/map that removes empty stacks and shifts down the remainders. You
-- should then be able to use the default setqflist " " behavior to delete the tail. You can then
-- make auto-consolidation a non-default option

-----------
--- LOW ---
-----------
