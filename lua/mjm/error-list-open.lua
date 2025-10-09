--- @class QfRancherOpen
local M = {}

-------------------
--- MODULE DATA ---
-------------------

local max_qf_height = 10

--------------------
--- HELPER FUNCS ---
--------------------

--- @param msg string
--- @param print_msgs boolean
--- @param is_err boolean
--- @return nil
local function checked_echo(msg, print_msgs, is_err)
    if not print_msgs then
        return
    end

    if is_err then
        vim.api.nvim_echo({ { msg, "ErrorMsg" } }, true, { err = true })
    else
        vim.api.nvim_echo({ { msg, "" } }, false, {})
    end
end

-- TODO: https://github.com/neovim/neovim/pull/33402
-- Add variable buf removal behavior back into this function once this is resolved

--- @param win integer
--- @param opts QfRancherPWinCloseOpts
--- @return boolean, [string, string]|nil
local function pwin_close(win, opts)
    if vim.g.qf_rancher_debug_assertions then
        local ey = require("mjm.error-list-types") --- @type QfRancherTypes
        ey._validate_win(win, false)
        ey._validate_pwin_close_opts(opts)
    end

    if not vim.api.nvim_win_is_valid(win) then
        local msg = "Window " .. win .. " is invalid" --- @type string
        checked_echo(msg, opts.print_errs, true)
        return false, { msg, "ErrorMsg" }
    end

    local tabpages = vim.api.nvim_list_tabpages() --- @type integer[]
    local win_tabpage = vim.api.nvim_win_get_tabpage(win) --- @type integer
    local win_tabpage_wins = vim.api.nvim_tabpage_list_wins(win_tabpage) --- @type integer[]
    local buf = vim.api.nvim_win_get_buf(win) --- @type integer

    if #tabpages > 1 or #win_tabpage_wins > 1 then
        local ok, err = pcall(vim.api.nvim_win_close, win, opts.force) --- @type boolean, any
        if not ok then
            local msg = err or ("Unknown error closing window " .. win) --- @type string
            checked_echo(msg, opts.print_errs, true)
            return false, { msg, "ErrorMsg" }
        end

        vim.schedule(function()
            local buf_wins = vim.fn.win_findbuf(buf) --- @type integer[]
            local buf_list = vim.api.nvim_list_bufs() --- @type integer[]
            if #buf_wins < 1 and vim.tbl_contains(buf_list, buf) then
                vim.api.nvim_set_option_value("buflisted", false, { buf = buf })
                vim.api.nvim_buf_delete(buf, { unload = true, force = opts.force })
            end
        end)

        return true, nil
    end

    if not vim.api.nvim_buf_is_valid(buf) then
        local msg = "Bufnr " .. buf .. " in window " .. win .. " is not valid" --- @type string
        checked_echo(msg, opts.print_errs, true)
        return false, { msg, "ErrorMsg" }
    end

    vim.api.nvim_set_option_value("buflisted", false, { buf = buf })
    vim.api.nvim_buf_delete(buf, { unload = true, force = opts.force })
    return true, nil
end

--- @param wins integer[]
--- @return nil
local function pclose_wins(wins)
    for _, win in pairs(wins) do
        pwin_close(win, { force = true })
    end
end

--- @param views vim.fn.winsaveview.ret[]
--- @return nil
local function restore_views(views)
    for win, view in pairs(views) do
        if not vim.api.nvim_win_is_valid(win) then
            return
        end

        vim.api.nvim_win_call(win, function()
            if vim.fn.line("w0") ~= view.topline then
                vim.fn.winrestview(view)
            end
        end)
    end
end

--- @param wins integer[]
--- @return vim.fn.winsaveview.ret[]
local function get_views(wins)
    local views = {} --- @type vim.fn.winsaveview.ret[]
    if vim.g.qf_rancher_always_save_views == false then
        return views
    end

    --- @type string
    local splitkeep = vim.api.nvim_get_option_value("splitkeep", { scope = "global" })
    if splitkeep == "screen" or splitkeep == "topline" then
        return views
    end

    for _, win in pairs(wins) do
        if not views[win] then
            local wintype = vim.fn.win_gettype(win)
            if wintype == "" or wintype == "loclist" or wintype == "quickfix" then
                views[win] = vim.api.nvim_win_call(win, vim.fn.winsaveview)
            end
        end
    end

    return views
end

--- @param win integer|nil
--- @param height integer|nil
--- @return integer
local function resolve_height_for_list(win, height)
    if vim.g.qf_rancher_debug_assertions then
        require("mjm.error-list-types")._validate_win(win, true)
        vim.validate("height", height, { "nil", "number" })
    end

    if height then
        return height
    end

    local size = require("mjm.error-list-tools")._get_list_size(win, 0) --- @type integer|nil
    if not size then
        return max_qf_height
    end

    size = math.max(size, 1)
    size = math.min(size, max_qf_height)
    return size
end

--- TODO: Does the hight have to be capped at the total display lines in Vim?

--- @param list_win integer
--- @param height integer|nil
--- @param opts QfRancherTabpageOpts
--- @return nil
local function resize_list_win(list_win, height, opts)
    if vim.g.qf_rancher_debug_assertions then
        local ey = require("mjm.error-list-types") --- @type QfRancherTypes
        ey._validate_win(list_win, false)
        vim.validate("height", height, { "nil", "number" })
        ey._validate_tabpage_opts(opts)
    end

    local list_wintype = vim.fn.win_gettype(list_win)
    local is_loclist = list_wintype == "loclist" --- @type boolean
    local is_qflist = list_wintype == "quickfix" --- @type boolean
    if not (is_loclist or is_qflist) then
        return
    end

    local old_height = vim.api.nvim_win_get_height(list_win) --- @type integer
    local win_param = is_loclist and list_win or nil --- @type integer|nil
    local new_height = resolve_height_for_list(win_param, height) --- @type integer
    if old_height == new_height then
        return
    end

    local views = {}
    local tabpages = require("mjm.error-list-util")._resolve_tabpages(opts) --- @type integer[]
    for _, tabpage in ipairs(tabpages) do
        local tabpage_wins = vim.api.nvim_tabpage_list_wins(tabpage) --- @type integer[]
        tabpage_wins = vim.tbl_filter(function(win)
            return win ~= list_win
        end, tabpage_wins)

        vim.list_extend(views, get_views(tabpage_wins))
    end

    vim.api.nvim_win_set_height(list_win, new_height)
    restore_views(views)
end

--- @param opts QfRancherOpenOpts
--- @return nil
local function clean_open_opts(opts)
    require("mjm.error-list-types")._validate_open_opts(opts)

    if opts.always_resize == nil then
        opts.always_resize = false
    end

    if opts.height and opts.height < 1 then
        opts.height = nil
    end

    if opts.keep_win == nil then
        opts.keep_win = false
    end

    if opts.print_errs == nil then
        opts.print_errs = false
    end
end

------------
--- OPEN ---
------------

--- @param list_win integer
--- @param opts QfRancherOpenOpts
--- @param tabpage integer
--- @return boolean
local function handle_open_listwin(list_win, opts, tabpage)
    if opts.always_resize then
        resize_list_win(list_win, opts.height, { tabpage = tabpage })
    else
        checked_echo("List win is already open", opts.print_errs, false)
    end

    return false
end

--- @param views vim.fn.winsaveview.ret[]
--- @param keep_win boolean
--- @param cur_win integer
--- @return boolean
local function open_cleanup(views, keep_win, cur_win)
    restore_views(views)
    if keep_win then
        vim.api.nvim_set_current_win(cur_win)
    end

    return true
end

--- @param opts? QfRancherOpenOpts
--- @return boolean
function M._open_qflist(opts)
    opts = opts or {}
    clean_open_opts(opts)

    local cur_win = vim.api.nvim_get_current_win() --- @type integer
    local tabpage = vim.api.nvim_win_get_tabpage(cur_win) --- @type integer
    local eu = require("mjm.error-list-util") --- @type QfRancherUtils
    local qf_win = eu._get_qf_win({ tabpage = tabpage }) --- @type integer|nil

    if qf_win then
        return handle_open_listwin(qf_win, opts, tabpage)
    end

    local ll_wins = eu._get_all_loclist_wins({ tabpage = tabpage }) --- @type integer[]
    local tabpage_wins = vim.api.nvim_tabpage_list_wins(tabpage) --- @type integer[]
    tabpage_wins = vim.tbl_filter(function(win)
        return not vim.tbl_contains(ll_wins, win)
    end, tabpage_wins)

    local views = get_views(tabpage_wins) --- @type vim.fn.winsaveview.ret[]
    pclose_wins(ll_wins)
    local height = resolve_height_for_list(nil, opts.height)

    local qfsplit = vim.g.qf_rancher_qfsplit or "botright" --- @type string
    --- @diagnostic disable: missing-fields
    vim.api.nvim_cmd({ cmd = "copen", count = height, mods = { split = qfsplit } }, {})
    return open_cleanup(views, opts.keep_win, cur_win)
end

--- MID: It would be better if this took win as its first arg

--- @param opts? QfRancherOpenOpts
--- @return boolean
function M._open_loclist(opts)
    opts = opts or {}
    clean_open_opts(opts)

    local cur_win = vim.api.nvim_get_current_win() --- @type integer
    local qf_id = vim.fn.getloclist(cur_win, { id = 0 }).id --- @type integer
    if qf_id == 0 then
        checked_echo("Window has no location list", opts.print_errs, false)
        return false
    end

    local tabpage = vim.api.nvim_win_get_tabpage(cur_win) --- @type integer
    local eu = require("mjm.error-list-util") --- @type QfRancherUtils
    local ll_win = eu._get_ll_win_by_qf_id(qf_id, { tabpage = tabpage }) --- @type integer|nil
    if ll_win then
        return handle_open_listwin(ll_win, opts, tabpage)
    end

    local tabpage_wins = vim.api.nvim_tabpage_list_wins(tabpage) --- @type integer[]
    local qf_win = eu._get_qf_win({ tabpage = tabpage }) --- @type integer|nil
    if qf_win then
        tabpage_wins = vim.tbl_filter(function(win)
            return win ~= qf_win
        end, tabpage_wins)
    end

    local views = get_views(tabpage_wins) --- @type vim.fn.winsaveview.ret[]
    local height = resolve_height_for_list(cur_win, opts.height) --- @type integer
    if qf_win then
        pwin_close(qf_win, { force = true })
    end

    --- @diagnostic disable: missing-fields
    vim.api.nvim_cmd({ cmd = "lopen", count = height }, {})
    return open_cleanup(views, opts.keep_win, cur_win)
end

--- @param win? integer
--- @param opts QfRancherOpenOpts
--- @return boolean
function M._open_list(win, opts)
    --- NOTE: Because these functions return booleans, cannot use the Lua ternary
    if win then
        return M._open_loclist(opts)
    else
        return M._open_qflist(opts)
    end
end

-------------
--- CLOSE ---
-------------

--- @return boolean
function M._close_qflist()
    local cur_win = vim.api.nvim_get_current_win() --- @type integer
    local tabpage = vim.api.nvim_win_get_tabpage(cur_win) --- @type integer

    local eu = require("mjm.error-list-util") --- @type QfRancherUtils
    local qf_win = eu._get_qf_win({ tabpage = tabpage }) --- @type integer|nil
    if not qf_win then
        return false
    end

    local tabpage_wins = vim.api.nvim_tabpage_list_wins(tabpage) --- @type integer[]
    tabpage_wins = vim.tbl_filter(function(win)
        return win ~= qf_win
    end, tabpage_wins)

    local views = get_views(tabpage_wins) --- @type vim.fn.winsaveview.ret[]
    pwin_close(qf_win, { force = true })
    restore_views(views)
    return true
end

--- @return boolean
function M._close_loclist()
    local cur_win = vim.api.nvim_get_current_win() --- @type integer
    local wintype = vim.fn.win_gettype(cur_win)
    local qf_id = vim.fn.getloclist(cur_win, { id = 0 }).id ---@type integer
    if qf_id == 0 and wintype ~= "loclist" then
        vim.api.nvim_echo({ { "Window has no loclist", "" } }, false, {})
        return false
    end

    local eu = require("mjm.error-list-util") --- @type QfRancherUtils
    local tabpage = vim.api.nvim_win_get_tabpage(cur_win) --- @type integer
    local ll_wins = eu._get_loclist_wins_by_qf_id(qf_id, { tabpage = tabpage }) --- @type integer[]
    if #ll_wins < 1 then
        return false
    end

    local tabpage_wins = vim.api.nvim_tabpage_list_wins(tabpage) --- @type integer[]
    tabpage_wins = vim.tbl_filter(function(win)
        return not vim.tbl_contains(ll_wins, win)
    end, tabpage_wins)

    local views = get_views(tabpage_wins) --- @type vim.fn.winsaveview.ret[]
    pclose_wins(ll_wins)
    restore_views(views)
    return true
end

--- @return nil
function M._toggle_qflist()
    if not M._open_qflist() then
        M._close_qflist()
    end
end

--- @return nil
function M._toggle_loclist()
    if not M._open_loclist({}) then
        M._close_loclist()
    end
end

--- @param win integer
--- @return boolean
function M._close_win_save_views(win)
    if vim.g.qf_rancher_debug_assertions then
        local ey = require("mjm.error-list-types") --- @type QfRancherTypes
        ey._validate_win(win, false)
    end

    local tabpage = vim.api.nvim_win_get_tabpage(win) --- @type integer
    local tabpage_wins = vim.api.nvim_tabpage_list_wins(tabpage) --- @type integer[]
    tabpage_wins = vim.tbl_filter(function(t_win)
        return t_win ~= win
    end, tabpage_wins)

    local views = get_views(tabpage_wins) --- @type vim.fn.winsaveview.ret[]
    pwin_close(win, { force = true })
    restore_views(views)

    return true
end

-----------------------
--- BULK OPERATIONS ---
-----------------------

--- @param opts QfRancherTabpageOpts
--- @return nil
function M._close_qfwins(opts)
    if vim.g.qf_rancher_debug_assertions then
        local ey = require("mjm.error-list-types") --- @type QfRancherTypes
        ey._validate_tabpage_opts(opts)
    end

    local qflists = require("mjm.error-list-util")._get_qf_wins(opts) --- @type integer[]
    for _, list in ipairs(qflists) do
        M._close_win_save_views(list)
    end
end

--- @param opts QfRancherTabpageOpts
--- @return nil
function M._resize_qfwins(opts)
    if vim.g.qf_rancher_debug_assertions then
        local ey = require("mjm.error-list-types") --- @type QfRancherTypes
        ey._validate_tabpage_opts(opts)
    end

    local qfwins = require("mjm.error-list-util")._get_qf_wins(opts) --- @type integer[]
    for _, win in ipairs(qfwins) do
        local tabpage = vim.api.nvim_win_get_tabpage(win) --- @type integer
        resize_list_win(win, nil, { tabpage = tabpage })
    end
end

--- @param win integer
--- @param opts QfRancherTabpageOpts
--- @return nil
function M._resize_loclists_by_win(win, opts)
    if vim.g.qf_rancher_debug_assertions then
        local ey = require("mjm.error-list-types") --- @type QfRancherTypes
        ey._validate_win(win, false)
        ey._validate_tabpage_opts(opts)
    end

    --- @type integer[]
    local loclists = require("mjm.error-list-util")._get_loclist_wins_by_win(win, opts)
    for _, list_win in ipairs(loclists) do
        local tabpage = vim.api.nvim_win_get_tabpage(list_win) --- @type integer
        resize_list_win(list_win, nil, { tabpage = tabpage })
    end
end

-- --- @param qf_id integer
-- --- @param opts QfRancherTabpageOpts
-- --- @return nil
-- function M._resize_loclists_by_qf_id(qf_id, opts)
--     if vim.g.qf_rancher_debug_assertions then
--         local ey = require("mjm.error-list-types") --- @type QfRancherTypes
--         ey._validate_qf_id(qf_id)
--         ey._validate_tabpage_opts(opts)
--     end
--
--     local llists = require("mjm.error-list-util")._get_loclist_wins_by_qf_id(qf_id, opts)
--     for _, list in ipairs(llists) do
--         resize_ll_win(list)
--     end
-- end

-- --- @param win integer
-- --- @param opts QfRancherTabpageOpts
-- --- @return nil
-- function M._close_loclists_by_win(win, opts)
--     if vim.g.qf_rancher_debug_assertions then
--         local ey = require("mjm.error-list-types") --- @type QfRancherTypes
--         ey._validate_win(win, false)
--         ey._validate_tabpage_opts(opts)
--     end
--
--     local llists = require("mjm.error-list-util")._get_loclist_wins_by_win(win, opts)
--     for _, list in ipairs(llists) do
--         M._close_list_win(list)
--     end
-- end

--- @param qf_id integer
--- @param opts QfRancherTabpageOpts
--- @return nil
function M._close_loclists_by_qf_id(qf_id, opts)
    if vim.g.qf_rancher_debug_assertions then
        local ey = require("mjm.error-list-types") --- @type QfRancherTypes
        ey._validate_qf_id(qf_id)
        ey._validate_tabpage_opts(opts)
    end

    --- @type integer[]
    local llists = require("mjm.error-list-util")._get_loclist_wins_by_qf_id(qf_id, opts)
    for _, list in ipairs(llists) do
        M._close_win_save_views(list)
    end
end

return M

------------
--- TODO ---
------------

-- - Check that window height updates are triggered where appropriate
-- - Check that all mappings have plugs and cmds
-- - Check that all maps/cmds/plugs have desc fieldss
-- - Check that the qf and loclist versions are both properly built for purpose.
--
-- All resizing operations should respect the g option and splitkeep
-- Add <leader>qP / <leader>lP as maps to set the list to max size
-- Make the various list sizing functions account for screen height
--
-- Tests
-- Docs

-----------
--- MID ---
-----------

--- Implement a feature where, if you open list to a blank one, do a wrapping search forward or
---     backward for a list with items
--- - Or less obstrusively, showing history on blank lists or a statusline component
--- https://github.com/neovim/neovim/pull/33402 - When this request goes through, for Nvim
---     versions that have it, use Bufwipeout behavior by default in Pwinclose. It shouldn't
---     matter for qf wins, but as of right now, bwipeout affects Shada state

-----------
--- LOW ---
-----------

--- Make get_list_height work without nowrap
--- Make a Neovim tools repo that has the pwin close function
