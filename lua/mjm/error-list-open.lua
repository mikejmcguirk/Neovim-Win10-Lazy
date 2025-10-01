local M = {}

-----------
-- TYPES --
-----------

--- @class QfRancherOpenOpts
--- @field always_resize? boolean
--- @field height? integer
--- @field keep_win? boolean
--- @field suppress_errors? boolean

--- @class QfRancherPWinCloseOpts
--- @field bdel? boolean
--- @field bwipeout? boolean
--- @field force? boolean
--- @field print_errors? boolean
--- @field win? integer

-------------------
--- MODULE DATA ---
-------------------

local max_qf_height = 10

--------------------
--- HELPER FUNCS ---
--------------------

-- TODO: Make a Neovim tools repo and put this function in here. Make sure that repo is all local
-- functions so it can't just be pulled lazily as a dep

--- Checks that the provided window is valid. If the provided window is the last one, deletes the
--- buffer instead
--- Opts:
--- - buf_delete: (default false) Delist the buffer in addition to unloading it
--- - buf_wipeout: (default false) Perform bwipeout on a deleted buffer. Overrides buf_delete
--- - force: (default false) Ignore unsaved changes
--- - print_errors: (default true) Print error messages
--- - win: (default current win) The window to close
--- @param opts QfRancherPWinCloseOpts
--- @return boolean, [string, string]|nil
local function pwin_close(opts)
    opts = opts or {}
    local win = opts.win or vim.api.nvim_get_current_win() --- @type integer
    vim.validate("opts.win", opts.win, "number")
    if not vim.api.nvim_win_is_valid(win) then
        local chunk = { "Window " .. win .. " is invalid", "WarningMsg" }
        if opts.print_errors then
            vim.api.nvim_echo({ chunk }, true, { err = true })
        end

        return false, chunk
    end

    local force = opts.force and true or false --- @type boolean
    local tabpages = vim.api.nvim_list_tabpages() --- @type integer[]
    local win_tabpage = vim.api.nvim_win_get_tabpage(win) --- @type integer
    local win_tabpage_wins = vim.api.nvim_tabpage_list_wins(win_tabpage) --- @type integer[]
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

        return true, nil
    end

    local buf = vim.api.nvim_win_get_buf(win) --- @type integer
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
        pwin_close({ bwipeout = true, force = true, win = win })
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

--- MID: It would be better if this were able to account for screenlines
--- TODO: Make a map/command (qP?) that opens the list to max height
--- TODO: this function is confusing come back to it

--- @param list_win integer
--- @param is_ll? boolean
--- @return integer
--- This assumes nowrap
local function get_list_win_height(list_win, is_ll)
    vim.validate("is_ll", is_ll, { "boolean", "nil" })
    vim.validate("win", list_win, "number")
    vim.validate("list_win", list_win, function()
        return vim.api.nvim_win_is_valid(list_win)
    end)

    if is_ll == nil then
        local wintype = vim.fn.win_gettype(list_win)
        is_ll = wintype == "loclist"
    end

    local eu = require("mjm.error-list-util")
    -- TODO: Do we get here with output opts? Might be overly elaborate for this case
    local getlist = eu._get_getlist({ loclist_source_win = list_win, is_loclist = is_ll })
    local cur_size = getlist and getlist({ size = true }).size or max_qf_height

    local list_height = math.min(cur_size, max_qf_height)
    list_height = math.max(list_height, 1)
    return list_height
end

-- TODO: this function is not clear in terms of what it is for and how it works

--- @param list_win integer
--- @param opts? {height?:integer, is_loclist?:boolean}
--- @return nil
local function resize_list_win(list_win, opts)
    opts = opts or {}
    vim.validate("opts.is_ll", opts.is_loclist, { "boolean", "nil" })
    vim.validate("opts.height", opts.height, { "number", "nil" })
    vim.validate("win", list_win, "number")
    vim.validate("list_win", list_win, function()
        return vim.api.nvim_win_is_valid(list_win)
    end)

    if opts.is_loclist == nil then
        local wintype = vim.fn.win_gettype(list_win)
        opts.is_loclist = wintype == "loclist"
    end

    local list_height = opts.height or get_list_win_height(list_win, opts.is_loclist)
    vim.api.nvim_win_set_height(list_win, list_height)
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

--- @param qf_win integer
--- @param height? integer
--- @param opts? {tabpage?: integer, tabpage_wins?:integer[]}
--- @return nil
local function resize_qf_win(qf_win, height, opts)
    opts = opts or {}

    if vim.g.qf_rancher_debug_assertions then
        vim.validate("qf_win", qf_win, "number")
        vim.validate("qf_win", qf_win, function()
            return vim.api.nvim_win_is_valid(qf_win)
        end)

        local wintype = vim.fn.win_gettype(qf_win)
        local qf = wintype == "quickfix"
        assert(qf, "qf_win " .. qf_win .. "has a non quickfix type: " .. wintype)

        vim.validate("opts.tabpage", opts.tabpage, { "nil", "number" })
        vim.validate("opts.tabpage_wins", opts.tabpage, { "nil", "table" })
    end

    --- LOW: Awkward for the same reasons as the _find_qf_win util
    local tabpage = opts.tabpage or vim.api.nvim_win_get_tabpage(qf_win)
    local tabpage_wins = opts.tabpage_wins or vim.api.nvim_tabpage_list_wins(tabpage)
    tabpage_wins = vim.tbl_filter(function(win)
        return win ~= qf_win
    end, tabpage_wins)

    local views = get_views(tabpage_wins)

    local resolved_height = resolve_qf_height(height)
    vim.api.nvim_win_set_height(qf_win, resolved_height)

    restore_views(views)
end

--- @param open_opts QfRancherOpenOpts
local function validate_open_opts(open_opts)
    vim.validate("open_opts", open_opts, "table")
    vim.validate("open_opts.always_resize", open_opts.always_resize, { "boolean", "nil" })
    vim.validate("open_opts.height", open_opts.height, { "nil", "number" })
    vim.validate("open_opts.keep_win", open_opts.keep_win, { "boolean", "nil" })
    vim.validate("open_opts.suppress_errors", open_opts.suppress_errors, { "boolean", "nil" })
end

--- @param open_opts QfRancherOpenOpts
--- Assumes that validation has already been run
local function clean_open_opts(open_opts)
    open_opts.always_resize = open_opts.always_resize == nil and false or open_opts.always_resize
    open_opts.height = (open_opts.height and open_opts.height > 0) and open_opts.height or nil
    open_opts.keep_win = open_opts.keep_win == nil and false or open_opts.keep_win
    open_opts.suppress_errors = open_opts.suppress_errors == nil and false
        or open_opts.suppress_errors
end

----------------------------
--- Open/Close Functions ---
----------------------------

--- @param opts? QfRancherOpenOpts
--- @return boolean
--- opts:
--- - always_resize?: If the qf window is already open, it will be resized
--- - height?: Set the height the list should be sized to
--- - keep_win?: On completion, return focus to the calling win
--- - suppress_errors?: Do not display error messages
function M._open_qflist(opts)
    opts = opts or {}
    validate_open_opts(opts)
    clean_open_opts(opts)

    local cur_win = vim.api.nvim_get_current_win() --- @type integer
    local tabpage = vim.api.nvim_win_get_tabpage(cur_win) --- @type integer
    local tabpage_wins = vim.api.nvim_tabpage_list_wins(tabpage) --- @type integer[]

    local eu = require("mjm.error-list-util") --- @type QfRancherUtils
    local qf_win = eu._find_qf_win({ tabpage_wins = tabpage_wins }) --- @type integer|nil
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

    --- @diagnostic disable: missing-fields
    vim.api.nvim_cmd({ cmd = "copen", count = height, mods = { split = "botright" } }, {})
    restore_views(views)
    if opts.keep_win then
        vim.api.nvim_set_current_win(cur_win)
    end

    return true
end

--- @return boolean
function M.close_qflist()
    local cur_win = vim.api.nvim_get_current_win() --- @type integer
    local tabpage = vim.api.nvim_win_get_tabpage(cur_win) --- @type integer
    local tabpage_wins = vim.api.nvim_tabpage_list_wins(tabpage) --- @type integer[]

    local eu = require("mjm.error-list-util") --- @type QfRancherUtils
    --- @type integer|nil
    local qf_win = eu._find_qf_win({ tabpage_wins = tabpage_wins })
    if not qf_win then
        return false
    end

    tabpage_wins = vim.tbl_filter(function(win)
        return win ~= qf_win
    end, tabpage_wins)

    local views = get_views(tabpage_wins) --- @type vim.fn.winsaveview.ret[]
    pwin_close({ bwipeout = true, force = true, win = qf_win })
    restore_views(views)
    return true
end

function M.toggle_qflist()
    if not M._open_qflist({ suppress_errors = true }) then
        M.close_qflist()
    end
end

function M.resize_qflist()
    local wins = vim.api.nvim_tabpage_list_wins(0) --- @type integer[]
    local eu = require("mjm.error-list-util")
    local qf_win = eu._find_qf_win() --- @type integer|nil, integer|nil
    if not qf_win then
        return false
    end

    wins = vim.tbl_filter(function(w)
        return w ~= qf_win
    end, wins)

    local views = get_views(wins) --- @type vim.fn.winsaveview.ret[]
    resize_list_win(qf_win, { is_loclist = false })
    restore_views(views)
end

--- @param opts? QfRancherOpenOpts
--- @return boolean
function M.open_loclist(opts)
    opts = opts or {}
    vim.validate("opts.height", opts.height, { "nil", "number" })
    opts.height = (opts.height and opts.height > 0) and opts.height or nil
    vim.validate("opts.suppress_errors", opts.suppress_errors, { "boolean", "nil" })
    local cur_win = vim.api.nvim_get_current_win() --- @type integer
    local eu = require("mjm.error-list-util")
    local qf_id, ll_win = eu._get_loclist_info({ win = cur_win }) --- @type integer,integer|nil
    if qf_id == 0 then
        if not opts.suppress_errors then
            vim.api.nvim_echo({ { "Window has no loclist", "" } }, false, {})
        end

        return false
    end

    if ll_win then
        if not eu._has_any_loclist({ win = cur_win }) then
            M.close_list_win(ll_win)
            return false
        end

        if not opts.always_resize then
            return false
        end
    end

    local wins = vim.api.nvim_tabpage_list_wins(0) --- @type integer[]
    local qf_win = eu._find_qf_win() --- @type integer|nil
    if qf_win then
        -- TODO: Not the best way to handle this
        wins = vim.tbl_filter(function(w)
            return w ~= qf_win
        end, wins)
    end

    local views = get_views(wins) --- @type vim.fn.winsaveview.ret[]
    -- Handling this here is ugly, but saves external callers from trying, and failing, to open the
    -- loclist then having to re-gather the data to re-size it
    if ll_win then
        if qf_win then
            local qf_view = get_views({ qf_win }) --- @type vim.fn.winsaveview.ret[]
            vim.list_extend(views, qf_view)
        end

        resize_list_win(ll_win, { is_loclist = true, height = opts.height })
        restore_views(views)
        return false
    end

    if qf_win then
        pwin_close({ bwipeout = true, force = true, win = qf_win })
    end

    local height = opts.height and opts.height or get_list_win_height(cur_win, true) --- @type integer
    --- @diagnostic disable: missing-fields
    vim.api.nvim_cmd({ cmd = "lopen", count = height }, {})
    restore_views(views)
    if opts.keep_win then
        vim.api.nvim_set_current_win(cur_win)
    end

    return true
end

--- @return boolean
function M.close_loclist()
    local ll_wins = {}
    local cur_win = vim.api.nvim_get_current_win() --- @type integer
    local qf_id = vim.fn.getloclist(cur_win, { id = 0 }).id ---@type integer
    if qf_id == 0 then
        local orphan_ll_wins = require("mjm.error-list-util")._find_orphan_loclists()
        if #orphan_ll_wins > 0 then
            vim.list_extend(ll_wins, orphan_ll_wins)
        else
            vim.api.nvim_echo({ { "Window has no loclist", "" } }, false, {})
            return false
        end
    end

    local wins = vim.api.nvim_tabpage_list_wins(0) --- @type integer[]
    local eu = require("mjm.error-list-util")
    local ll_win = eu.find_loclist_win(cur_win, qf_id)
    if not ll_win then
        return false
    end

    table.insert(ll_wins, ll_win)
    wins = vim.tbl_filter(function(w)
        return not vim.tbl_contains(ll_wins, w)
    end, wins)

    local views = get_views(wins) --- @type vim.fn.winsaveview.ret[]
    pclose_wins(ll_wins)
    restore_views(views)
    return true
end

function M.toggle_loclist()
    if not M.open_loclist({ suppress_errors = true }) then
        M.close_loclist()
    end
end

--- @return boolean
function M.resize_loclist()
    local cur_win = vim.api.nvim_get_current_win() --- @type integer
    local qf_id = vim.fn.getloclist(cur_win, { id = 0 }).id ---@type integer
    if qf_id == 0 then
        vim.api.nvim_echo({ { "Window has no loclist", "" } }, false, {})
        return false
    end

    local wins = vim.api.nvim_tabpage_list_wins(0) --- @type integer[]
    local eu = require("mjm.error-list-util")
    local ll_win = eu.find_loclist_win(cur_win, qf_id) --- @type integer|nil
    if not ll_win then
        return false
    end

    local views = get_views(wins) --- @type vim.fn.winsaveview.ret[]

    resize_list_win(ll_win, { is_loclist = true })
    restore_views(views)
    return true
end

--- @param list_win integer
--- @return boolean
function M.close_list_win(list_win)
    vim.validate("list_win", list_win, "number")
    vim.validate("list_win", list_win, function()
        return vim.api.nvim_win_is_valid(list_win)
    end)

    vim.validate("list_win", list_win, function()
        local wintype = vim.fn.win_gettype(list_win)
        return wintype == "quickfix" or wintype == "loclist"
    end)

    local win_tabpage = vim.api.nvim_win_get_tabpage(list_win) --- @type integer
    local wins = vim.api.nvim_tabpage_list_wins(win_tabpage) --- @type integer[]
    local views = get_views(wins) --- @type vim.fn.winsaveview.ret[]
    pwin_close({ bwipeout = true, force = true, win = list_win })
    restore_views(views)

    return true
end

--- @param list_win integer
--- @return boolean
function M.resize_list_win(list_win)
    vim.validate("list_win", list_win, "number")
    vim.validate("list_win", list_win, function()
        return vim.api.nvim_win_is_valid(list_win)
    end)

    vim.validate("list_win", list_win, function()
        local wintype = vim.fn.win_gettype(list_win)
        return wintype == "quickfix" or wintype == "loclist"
    end)

    local win_tabpage = vim.api.nvim_win_get_tabpage(list_win) --- @type integer
    local wins = vim.api.nvim_tabpage_list_wins(win_tabpage) --- @type integer[]
    local views = get_views(wins) --- @type vim.fn.winsaveview.ret[]
    resize_list_win(list_win)
    restore_views(views)

    return true
end

return M

--- Audit all files except ftplugin for bad/old API usage
-- TODO:

-- - Check that all functions have reasonable default sorts
-- - Check that window height updates are triggered where appropriate
-- - Check that functions have proper visibility
-- - Check that all mappings have plugs and cmds
-- - Check that all maps/cmds/plugs have desc fieldss
-- - Check that all functions have annotations and documentation
-- - Check that the qf and loclist versions are both properly built for purpose.
--      Should be able to use the loclist function for buf/win specific info
-- - Make the maps file navigable
-- - I think putting everything in one file is the simplest way to avoid perf issues, but for
-- individual groups of maps, hide what is possible behind autocmds rather than doing all maps
-- eagerly on startup
--
-- MAYBE
--
-- For opening the lists, there are two ideas you could integrate:
-- - If there are no active lists, the list doesn't open
-- - If you open to a blank list, it will automatically find a non-blank one
-- Because the first one is such a big change from the default behavior, it would have to be
-- behind an option. Also a really bad place to make mistakes in the code. Still, worth
-- considering if opening blank lists becomes too much of a nag
-- For the second, would need to work with chistory/lhistory more to know if it's a good idea
--
-- - Allow customizing where the qflist opens. But since botright is the default, and a good
-- one, leaving as is
--
-- - Use more function composition without the module
--
-- LOW
--
-- - Make get_list_height work without nowrap
--
-- PERF
--
-- - Depending on which functiosn go together, might pull win views twice
