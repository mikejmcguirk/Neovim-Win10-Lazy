--- @class QfRancherOpen
local M = {}

-------------------
--- MODULE DATA ---
-------------------

local max_qf_height = 10

--------------------
--- HELPER FUNCS ---
--------------------

--- @param win integer
--- @param opts QfRancherPWinCloseOpts
--- @return boolean, [string, string]|nil
local function pwin_close(win, opts)
    opts = opts or {}
    vim.validate("win", win, "number")

    if not vim.api.nvim_win_is_valid(win) then
        local chunk = { "Window " .. win .. " is invalid", "ErrorMsg" }
        if opts.print_errors then
            vim.api.nvim_echo({ chunk }, true, { err = true })
        end

        return false, chunk
    end

    local force = opts.force and true or false --- @type boolean
    local tabpages = vim.api.nvim_list_tabpages() --- @type integer[]
    local win_tabpage = vim.api.nvim_win_get_tabpage(win) --- @type integer
    local win_tabpage_wins = vim.api.nvim_tabpage_list_wins(win_tabpage) --- @type integer[]
    local buf = vim.api.nvim_win_get_buf(win) --- @type integer

    if #tabpages > 1 or #win_tabpage_wins > 1 then
        local ok, err = pcall(vim.api.nvim_win_close, win, force) --- @type boolean, any
        if not ok then
            local msg = err or ("Unknown error closing window " .. win) --- @type string
            local chunk = { msg, "ErrorMsg" } --- @type [string, string]
            if opts.print_errors then
                vim.api.nvim_echo({ chunk }, true, { err = true })
            end

            return false, { msg, "ErrorMsg" }
        end

        local buf_wins = vim.fn.win_findbuf(buf)
        local buf_list = vim.api.nvim_list_bufs()
        if #buf_wins < 1 and vim.tbl_contains(buf_list, buf) then
            --- TODO: Add in the opt usage once the Bwipeout issue is fixed
            vim.api.nvim_set_option_value("buflisted", false, { buf = buf })
            vim.api.nvim_buf_delete(buf, { unload = true })
        end

        return true, nil
    end

    if not vim.api.nvim_buf_is_valid(buf) then
        local msg = "Bufnr " .. buf .. " in window " .. win .. " is not valid" --- @type string
        local chunk = { msg, "ErrorMsg" } --- @type [string, string]
        if opts.print_errors then
            vim.api.nvim_echo({ chunk }, true, { err = true })
        end

        return false, chunk
    end

    local buf_delete_opts = opts.bwipeout and { force = force } or { force = force, unload = true }
    if opts.bdel and not opts.bwipeout then
        vim.api.nvim_set_option_value("buflisted", false, { buf = buf })
    end

    vim.api.nvim_buf_delete(buf, buf_delete_opts)
    return true, nil
end

--- @param wins integer[]
--- @return nil
local function pclose_wins(wins)
    for _, win in pairs(wins) do
        pwin_close(win, { bdel = true, force = true })
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
--- @return integer[]
local function find_ll_wins(wins)
    local ll_wins = {}
    for _, win in pairs(wins) do
        local wintype = vim.fn.win_gettype(win) --- @type string
        if wintype == "loclist" then
            table.insert(ll_wins, win)
        end
    end

    return ll_wins
end

--- @param wins integer[]
--- @return vim.fn.winsaveview.ret[]
local function get_views(wins)
    local views = {}

    if vim.g.qf_rancher_always_save_views == false then
        return views
    end

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

--- TODO: For these functions, two objectives:
--- - The duplicate logic is sloppy and tasteless
--- - Has the same tabpage scoping issues with the finding opts we looked at before

--- @param win integer
--- @param height integer|nil
--- @return integer
local function resolve_ll_height(win, height)
    vim.validate("win", win, "number")
    vim.validate("height", height, { "nil", "number" })

    if height then
        return height
    end

    local size = vim.fn.getloclist(win, { size = 0 }).size
    size = math.max(size, 1)
    size = math.min(size, max_qf_height)
    return size
end

--- @param height integer|nil
--- @return integer
local function resolve_qf_height(height)
    vim.validate("height", height, { "nil", "number" })

    if height then
        return height
    end

    local size = vim.fn.getqflist({ size = 0 }).size
    size = math.max(size, 1)
    size = math.min(size, max_qf_height)
    return size
end

--- TODO: This has the old, weird tabpage logic in it

--- @param ll_win integer
--- @param height? integer
--- @param opts? {tabpage?: integer, tabpage_wins?:integer[]}
--- @return nil
local function resize_ll_win(ll_win, height, opts)
    opts = opts or {}

    if vim.g.qf_rancher_debug_assertions then
        vim.validate("ll_win", ll_win, "number")
        vim.validate("ll_win", ll_win, function()
            return vim.api.nvim_win_is_valid(ll_win)
        end)

        local wintype = vim.fn.win_gettype(ll_win)
        local ll = wintype == "loclist"
        assert(ll, "ll_win " .. ll_win .. "has a non loclist type: " .. wintype)

        vim.validate("opts.tabpage", opts.tabpage, { "nil", "number" })
        vim.validate("opts.tabpage_wins", opts.tabpage, { "nil", "table" })
    end

    --- LOW: Awkward for the same reasons as the _find_qf_win util
    local tabpage = opts.tabpage or vim.api.nvim_win_get_tabpage(ll_win)
    local tabpage_wins = opts.tabpage_wins or vim.api.nvim_tabpage_list_wins(tabpage)
    tabpage_wins = vim.tbl_filter(function(win)
        return win ~= ll_win
    end, tabpage_wins)

    local views = get_views(tabpage_wins)

    local resolved_height = resolve_ll_height(ll_win, height)
    vim.api.nvim_win_set_height(ll_win, resolved_height)

    restore_views(views)
end

--- @param qf_win integer
--- @param height? integer
--- @param opts? {tabpage_wins?:integer[]}
--- @return nil
local function resize_qf_win(qf_win, height, opts)
    opts = opts or {}

    if vim.g.qf_rancher_debug_assertions then
        local ey = require("mjm.error-list-types")
        ey._validate_win(qf_win, false)

        --- TODO: Add an "is_quickfix_win" validation
        --- Same with is_loclist_win
        local wintype = vim.fn.win_gettype(qf_win)
        local qf = wintype == "quickfix"
        assert(qf, "qf_win " .. qf_win .. "has a non quickfix type: " .. wintype)

        vim.validate("opts.tabpage_wins", opts.tabpage_wins, { "nil", "table" })
    end

    local tabpage_wins = opts.tabpage_wins
        or vim.api.nvim_tabpage_list_wins(vim.api.nvim_win_get_tabpage(qf_win))
    tabpage_wins = vim.tbl_filter(function(win)
        return win ~= qf_win
    end, tabpage_wins)

    local views = get_views(tabpage_wins)
    local resolved_height = resolve_qf_height(height)
    vim.api.nvim_win_set_height(qf_win, resolved_height)
    restore_views(views)
end

--- @param opts QfRancherOpenOpts
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

    if opts.suppress_errors == nil then
        opts.suppress_errors = false
    end
end

--- TODO: Re-organize so opens/closes and such are together. Easier to find commonalities between
--- qf and loclist code

----------------------------
--- Open/Close Functions ---
----------------------------

--- @param opts? QfRancherOpenOpts
--- @return boolean
function M._open_qflist(opts)
    opts = opts or {}
    clean_open_opts(opts)

    local cur_win = vim.api.nvim_get_current_win() --- @type integer
    local tabpage = vim.api.nvim_win_get_tabpage(cur_win) --- @type integer
    local tabpage_wins = vim.api.nvim_tabpage_list_wins(tabpage) --- @type integer[]

    local eu = require("mjm.error-list-util") --- @type QfRancherUtils
    local qf_win = eu._get_qf_win({ tabpage = tabpage }) --- @type integer|nil
    if qf_win then
        if opts.always_resize then
            resize_qf_win(qf_win, opts.height, { tabpage_wins = tabpage_wins })
            return true
        else
            if not opts.suppress_errors then
                local chunk = { "Qflist already open", "" } --- @type [string, string]
                vim.api.nvim_echo({ chunk }, false, {})
            end

            return false
        end
    end

    local ll_wins = find_ll_wins(tabpage_wins) --- @type integer[]
    tabpage_wins = vim.tbl_filter(function(win)
        return not vim.tbl_contains(ll_wins, win)
    end, tabpage_wins)

    local views = get_views(tabpage_wins) --- @type vim.fn.winsaveview.ret[]
    pclose_wins(ll_wins)
    local height = resolve_qf_height(opts.height)

    local qfsplit = vim.g.qf_rancher_qfsplit -- TODO: Validate this
    --- @diagnostic disable: missing-fields
    vim.api.nvim_cmd({ cmd = "copen", count = height, mods = { split = qfsplit } }, {})
    restore_views(views)
    if opts.keep_win then
        vim.api.nvim_set_current_win(cur_win)
    end

    return true
end

--- @return boolean
function M._close_qflist()
    local cur_win = vim.api.nvim_get_current_win() --- @type integer
    local tabpage = vim.api.nvim_win_get_tabpage(cur_win) --- @type integer
    local tabpage_wins = vim.api.nvim_tabpage_list_wins(tabpage) --- @type integer[]

    local eu = require("mjm.error-list-util") --- @type QfRancherUtils
    --- @type integer|nil
    local qf_win = eu._get_qf_win({ tabpage = tabpage })
    if not qf_win then
        return false
    end

    tabpage_wins = vim.tbl_filter(function(win)
        return win ~= qf_win
    end, tabpage_wins)

    local views = get_views(tabpage_wins) --- @type vim.fn.winsaveview.ret[]
    pwin_close(qf_win, { bdel = true, force = true })
    restore_views(views)
    return true
end

function M._toggle_qflist()
    if not M._open_qflist({ suppress_errors = true }) then
        M._close_qflist()
    end
end

--- MID: It would be better if this took win as its first arg

--- @param opts? QfRancherOpenOpts
--- @return boolean
function M._open_loclist(opts)
    opts = opts or {}
    require("mjm.error-list-types")._validate_open_opts(opts)
    clean_open_opts(opts)

    local cur_win = vim.api.nvim_get_current_win() --- @type integer
    local qf_id = vim.fn.getloclist(cur_win, { id = 0 }).id --- @type integer
    if qf_id == 0 then
        if not opts.suppress_errors then
            vim.api.nvim_echo({ { "Window has no loclist", "" } }, false, {})
        end

        return false
    end

    local tabpage = vim.api.nvim_win_get_tabpage(cur_win) --- @type integer
    local tabpage_wins = vim.api.nvim_tabpage_list_wins(tabpage) --- @type integer[]
    local eu = require("mjm.error-list-util")
    --- @type integer|nil
    local ll_win = eu._get_loclist_win_by_qf_id(qf_id, { tabpage_wins = tabpage_wins })
    if ll_win then
        if opts.always_resize then
            resize_ll_win(ll_win, opts.height, { tabpage_wins = tabpage_wins })
            return true
        else
            if not opts.suppress_errors then
                local chunk = { "Loclist is already open", "" } --- @type [string, string]
                vim.api.nvim_echo({ chunk }, false, {})
            end

            return false
        end
    end

    local qf_win = eu._get_qf_win({ tabpage = tabpage }) --- @type integer|nil
    if qf_win then
        tabpage_wins = vim.tbl_filter(function(win)
            return win ~= qf_win
        end, tabpage_wins)
    end

    local views = get_views(tabpage_wins) --- @type vim.fn.winsaveview.ret[]
    if qf_win then
        pwin_close(qf_win, { bdel = true, force = true })
    end

    local height = resolve_ll_height(cur_win, opts.height)
    --- @diagnostic disable: missing-fields
    vim.api.nvim_cmd({ cmd = "lopen", count = height }, {})
    restore_views(views)
    if opts.keep_win then
        vim.api.nvim_set_current_win(cur_win)
    end

    return true
end

--- @return boolean
function M._close_loclist()
    local cur_win = vim.api.nvim_get_current_win() --- @type integer
    local tabpage = vim.api.nvim_win_get_tabpage(cur_win) --- @type integer
    local tabpage_wins = vim.api.nvim_tabpage_list_wins(tabpage) --- @type integer[]
    local ll_wins = {}

    local eu = require("mjm.error-list-util")
    local qf_id = vim.fn.getloclist(cur_win, { id = 0 }).id ---@type integer
    if qf_id == 0 then
        local orphan_ll_wins = eu._find_orphan_loclists({ tabpage_wins = tabpage_wins })
        if #orphan_ll_wins > 0 then
            vim.list_extend(ll_wins, orphan_ll_wins)
        else
            vim.api.nvim_echo({ { "Window has no loclist", "" } }, false, {})
            return false
        end
    end

    local ll_win = eu._get_loclist_win_by_qf_id(qf_id, { tabpage = tabpage })
    if (not ll_win) and #ll_wins < 1 then
        return false
    end

    table.insert(ll_wins, ll_win)
    tabpage_wins = vim.tbl_filter(function(win)
        return not vim.tbl_contains(ll_wins, win)
    end, tabpage_wins)

    local views = get_views(tabpage_wins) --- @type vim.fn.winsaveview.ret[]
    pclose_wins(ll_wins)
    restore_views(views)
    return true
end

function M._toggle_loclist()
    if not M._open_loclist({ suppress_errors = true }) then
        M._close_loclist()
    end
end

--- @param win? integer
--- @param opts QfRancherOpenOpts
function M._open_list(win, opts)
    --- NOTE: Because these functions return booleans, cannot use the Lua ternary
    if win then
        M._open_loclist(opts)
    else
        M._open_qflist(opts)
    end
end

--- TODO: More of the weird tabpage wins syntax here

--- @param win integer
--- @return boolean
function M._close_win_save_views(win)
    if vim.g.qf_rancher_debug_assertions then
        local ey = require("mjm.error-list-types")
        ey._validate_win(win, false)
    end

    local tabpage = vim.api.nvim_win_get_tabpage(win) --- @type integer
    local tabpage_wins = vim.api.nvim_tabpage_list_wins(tabpage) --- @type integer[]
    tabpage_wins = vim.tbl_filter(function(t_win)
        return t_win ~= win
    end, tabpage_wins)

    local views = get_views(tabpage_wins) --- @type vim.fn.winsaveview.ret[]
    pwin_close(win, { bdel = true, force = true })
    restore_views(views)

    return true
end

-----------------------
--- BULK OPERATIONS ---
-----------------------

--- @param opts QfRancherTabpageOpts
function M._close_qflists(opts)
    if vim.g.qf_rancher_debug_assertions then
        local ey = require("mjm.error-list-types")
        ey._validate_tabpage_opts(opts)
    end

    local qflists = require("mjm.error-list-util")._get_qf_wins(opts)
    for _, list in ipairs(qflists) do
        M._close_win_save_views(list)
    end
end

--- TODO: Remake this to have variable scope

function M._resize_all_qf_wins()
    local qf_wins = require("mjm.error-list-util")._get_qf_wins({ all_tabpages = true })
    for _, win in ipairs(qf_wins) do
        resize_qf_win(win, nil, {})
    end
end

--- @param win integer
--- @param opts QfRancherTabpageOpts
--- @return nil
function M._resize_loclists_by_win(win, opts)
    if vim.g.qf_rancher_debug_assertions then
        local ey = require("mjm.error-list-types")
        ey._validate_win(win, false)
        ey._validate_tabpage_opts(opts)
    end

    local llists = require("mjm.error-list-util")._get_loclist_wins_by_win(win, opts)
    for _, list in ipairs(llists) do
        resize_ll_win(list)
    end
end

-- --- @param qf_id integer
-- --- @param opts QfRancherTabpageOpts
-- --- @return nil
-- function M._resize_loclists_by_qf_id(qf_id, opts)
--     if vim.g.qf_rancher_debug_assertions then
--         local ey = require("mjm.error-list-types")
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
--         local ey = require("mjm.error-list-types")
--         ey._validate_win(win, false)
--         ey._validate_tabpage_opts(opts)
--     end
--
--     local llists = require("mjm.error-list-util")._get_loclist_wins_by_win(win, opts)
--     --- TODO: Make a little close list wins iterator
--     for _, list in ipairs(llists) do
--         M._close_list_win(list)
--     end
-- end

--- @param qf_id integer
--- @param opts QfRancherTabpageOpts
--- @return nil
function M._close_loclists_by_qf_id(qf_id, opts)
    if vim.g.qf_rancher_debug_assertions then
        local ey = require("mjm.error-list-types")
        ey._validate_qf_id(qf_id)
        ey._validate_tabpage_opts(opts)
    end

    local llists = require("mjm.error-list-util")._get_loclist_wins_by_qf_id(qf_id, opts)
    for _, list in ipairs(llists) do
        M._close_win_save_views(list)
    end
end

return M

------------
--- TODO ---
------------

--- In any resizing function, we should check if we actually resized. Don't restore views if
---     we didn't

-- - Check that window height updates are triggered where appropriate
-- - Check that functions have proper visibility
-- - Check that all mappings have plugs and cmds
-- - Check that all maps/cmds/plugs have desc fieldss
-- - Check that all functions have annotations and documentation
-- - Check that the qf and loclist versions are both properly built for purpose.
--
-- All resizing operations should respect the g option and splitkeep
-- Add <leader>qP / <leader>lP as maps to set the list to max size
-- Make the various list sizing functions account for screen height

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
