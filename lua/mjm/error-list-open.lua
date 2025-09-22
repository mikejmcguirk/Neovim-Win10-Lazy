--- TODO:
--- - Check that all functions have reasonable default sorts
--- - Check that window height updates are triggered where appropriate
--- - Check that functions have proper visibility
--- - Check that all mappings have plugs and cmds
--- - Check that all maps/cmds/plugs have desc fieldss
--- - Check that all functions have annotations and documentation
--- - Check that the qf and loclist versions are both properly built for purpose. Should be able
---     to use the loclist function for buf/win specific info
---
--- TODO: If there are no entries in the list, the open cmd should close the window
--- MAYBE: the open functions could imitate cwindow behavior and not open if there are no entries
--- The loclist already does this. With the quickfix window, it's inherently somewhat weird
--- In both cases, what if the current list doesn't have items, but other lists in the stack do?
--- Do you have to manually track down a full list? Applies to the above to do as well
---
--- TODO: Seeing weird stuff in the lL resize and greps where resize isn't working. My guess is
--- it's the issue I figured before about loclist id acquisition, and we need to use the updated
--- system function
--- TODO: Customize qfopen behavior. Shouldn't have to botright if you don't want to

local M = {}

-----------
-- Types --
-----------

--- @class QfRancherOpenOpts
--- @field always_resize? boolean
--- @field suppress_errors? boolean
--- @field height? integer
--- @field keep_win? boolean

--- @class QfRancherPWinCloseOpts
--- @field bdel? boolean
--- @field bwipeout? boolean
--- @field force? boolean
--- @field print_errors? boolean
--- @field win? integer

--- @param opts QfRancherPWinCloseOpts
--- @return boolean, [string, string]|nil
--- Checks that the provided window is valid. If the provided window is the last one, deletes the
--- buffer instead
--- Opts:
--- - buf_delete: (default false) Delist the buffer in addition to unloading it
--- - buf_wipeout: (default false) Perform bwipeout on a deleted buffer. Overrides buf_delete
--- - force: (default false) Ignore unsaved changes
--- - print_errors: (default true) Print error messages
--- - win: (default current win) The window to close
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

local max_qf_height = 10

-- LOW: This should work without nowrap
-- TODO: This does not work for some reason, but then it does on always_resize

--- @param list_win integer
--- @param is_ll? boolean
--- @return integer
--- This assumes nowrap
local function get_list_height(list_win, is_ll)
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
    local getlist = eu.get_getlist({ win = list_win, get_loclist = is_ll })
    local cur_size = getlist({ size = true }).size

    local list_height = math.min(cur_size, max_qf_height)
    list_height = math.max(list_height, 1)
    return list_height
end

--- @param list_win integer
--- @param opts? {height?:integer, is_loclist?:boolean}
--- @return nil
local function resize_list(list_win, opts)
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

    local list_height = opts.height or get_list_height(list_win, opts.is_loclist)
    vim.api.nvim_win_set_height(list_win, list_height)
end

--- @param wins integer[]
--- @return integer|nil, integer|nil
local function find_qf_win(wins)
    for i, win in ipairs(wins) do
        local wintype = vim.fn.win_gettype(win) --- @type string
        if wintype == "quickfix" then
            return win, i
        end
    end

    return nil
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
--- @param qf_id integer
--- @return integer|nil, integer|nil
local function find_ll_win_by_id(wins, qf_id)
    for i, win in pairs(wins) do
        local wintype = vim.fn.win_gettype(win) --- @type string
        if wintype == "loclist" then
            local w_qf_id = vim.fn.getloclist(win, { id = 0 }).id ---@type integer
            if w_qf_id == qf_id then
                return win, i
            end
        end
    end

    return nil
end

--- @param wins integer[]
--- @return vim.fn.winsaveview.ret[]
local function get_views(wins)
    local views = {}
    for _, win in pairs(wins) do
        local wintype = vim.fn.win_gettype(win)
        if wintype == "" or wintype == "loclist" or wintype == "quickfix" then
            views[win] = vim.api.nvim_win_call(win, vim.fn.winsaveview)
        end
    end

    return views
end

--- @param opts? QfRancherOpenOpts
--- @return boolean
--- opts:
--- - always_resize: If the qf window is already open, it will be resized
--- - keep_win: On completion, return focus to the calling win
function M.open_qflist(opts)
    opts = opts or {}
    vim.validate("opts.height", opts.height, { "nil", "number" })
    local cur_win = vim.api.nvim_get_current_win() --- @type integer
    local wins = vim.api.nvim_tabpage_list_wins(0) --- @type integer[]
    local qf_win, _ = find_qf_win(wins) --- @type integer|nil
    if qf_win and not opts.always_resize then
        return false
    end

    local ll_wins = find_ll_wins(wins) --- @type integer[]
    wins = vim.tbl_filter(function(w)
        return not vim.tbl_contains(ll_wins, w)
    end, wins)

    local views = get_views(wins) --- @type vim.fn.winsaveview.ret[]
    if qf_win then
        if not require("mjm.error-list-util").has_any_qflist() then
            M.close_list_win(qf_win)
            return false
        end

        if opts.always_resize then
            local ll_views = get_views(ll_wins) --- @type vim.fn.winsaveview.ret[]
            resize_list(qf_win, { is_loclist = false, height = opts.height })
            restore_views(views)
            restore_views(ll_views)
            return false
        end
    end

    pclose_wins(ll_wins)
    local height = opts.height and opts.height or get_list_height(cur_win, false) --- @type integer
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
    local wins = vim.api.nvim_tabpage_list_wins(0) --- @type integer[]
    local qf_win, qf_idx = find_qf_win(wins) --- @type integer|nil, integer|nil
    if (not qf_win) or not qf_idx then
        return false
    end

    table.remove(wins, qf_idx)
    local views = get_views(wins) --- @type vim.fn.winsaveview.ret[]
    pwin_close({ bwipeout = true, force = true, win = qf_win })
    restore_views(views)
    return true
end

function M.resize_qflist()
    local wins = vim.api.nvim_tabpage_list_wins(0) --- @type integer[]
    local qf_win, qf_idx = find_qf_win(wins) --- @type integer|nil, integer|nil
    if (not qf_win) or not qf_idx then
        return false
    end

    table.remove(wins, qf_idx)
    local views = get_views(wins) --- @type vim.fn.winsaveview.ret[]
    resize_list(qf_win, { is_loclist = false })
    restore_views(views)
end

--- @param opts? QfRancherOpenOpts
--- @return boolean
function M.open_loclist(opts)
    opts = opts or {}
    vim.validate("opts.height", opts.height, { "nil", "number" })
    vim.validate("opts.suppress_errors", opts.suppress_errors, { "boolean", "nil" })
    local cur_win = vim.api.nvim_get_current_win() --- @type integer
    local qf_id = vim.fn.getloclist(cur_win, { id = 0 }).id ---@type integer
    if qf_id == 0 then
        if not opts.suppress_errors then
            vim.api.nvim_echo({ { "Window has no loclist", "" } }, false, {})
        end

        return false
    end

    local wins = vim.api.nvim_tabpage_list_wins(0) --- @type integer[]
    local ll_win = find_ll_win_by_id(wins, qf_id) --- @type integer|nil
    if ll_win and not opts.always_resize then
        return false
    end

    local qf_win, qf_idx = find_qf_win(wins) --- @type integer|nil, integer|nil
    if qf_idx then
        table.remove(wins, qf_idx)
    end

    local views = get_views(wins) --- @type vim.fn.winsaveview.ret[]
    if ll_win then
        if not require("mjm.error-list-util").has_any_loclist({ win = cur_win }) then
            M.close_list_win(ll_win)
            return false
        end

        if opts.always_resize then
            if qf_win then
                local qf_view = get_views({ qf_win }) --- @type vim.fn.winsaveview.ret[]
                vim.list_extend(views, qf_view)
            end

            resize_list(ll_win, { is_loclist = true, height = opts.height })
            restore_views(views)
            return false
        end
    end

    if qf_win then
        pwin_close({ bwipeout = true, force = true, win = qf_win })
    end

    local height = opts.height and opts.height or get_list_height(cur_win, false) --- @type integer
    --- @diagnostic disable: missing-fields
    vim.api.nvim_cmd({ cmd = "lopen", count = height, mods = { split = "botright" } }, {})
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
        local orphan_ll_wins = require("mjm.error-list-util").find_orphan_loclists()
        if #orphan_ll_wins > 0 then
            vim.list_extend(ll_wins, orphan_ll_wins)
        else
            vim.api.nvim_echo({ { "Window has no loclist", "" } }, false, {})
            return false
        end
    end

    local wins = vim.api.nvim_tabpage_list_wins(0) --- @type integer[]
    local ll_win, ll_idx = find_ll_win_by_id(wins, qf_id) --- @type integer|nil
    if ((not ll_win) or not ll_idx) and #ll_wins < 1 then
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

-- TODO: Because this function does not take a win-id, you're stuck with the current win
-- So far this is not an issue, but a low-hanging-fruit robustness upgrade

--- @return boolean
function M.resize_loclist()
    local cur_win = vim.api.nvim_get_current_win() --- @type integer
    local qf_id = vim.fn.getloclist(cur_win, { id = 0 }).id ---@type integer
    if qf_id == 0 then
        vim.api.nvim_echo({ { "Window has no loclist", "" } }, false, {})
        return false
    end

    local wins = vim.api.nvim_tabpage_list_wins(0) --- @type integer[]
    local ll_win, ll_idx = find_ll_win_by_id(wins, qf_id) --- @type integer|nil
    if (not ll_win) or not ll_idx then
        return false
    end

    local views = get_views(wins) --- @type vim.fn.winsaveview.ret[]

    resize_list(ll_win, { is_loclist = true })
    restore_views(views)
    return true
end

-- MAYBE: You could use these two functions as the end path for any close or resize function
-- PERF: If you arrive at this function in the middle of another window management function, you
-- might need to re-pull the views

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
    resize_list(list_win)
    restore_views(views)

    return true
end

-----------------
--- Plug Maps ---
-----------------

-- DOCUMENT: How the open maps double as resizers. Note that this follows the built-in cmd
-- behavior

vim.api.nvim_set_keymap("n", "<Plug>(qf-rancher-open-qf-list)", "<nop>", {
    noremap = true,
    desc = "<Plug> Open the quickfix list",
    callback = function()
        local height = vim.v.count > 0 and vim.v.count or nil
        M.open_qflist({ always_resize = true, height = height })
    end,
})

vim.api.nvim_set_keymap("n", "<Plug>(qf-rancher-close-qf-list)", "<nop>", {
    noremap = true,
    desc = "<Plug> Close the quickfix list",
    callback = M.close_qflist,
})

vim.api.nvim_set_keymap("n", "<Plug>(qf-rancher-toggle-qf-list)", "<nop>", {
    noremap = true,
    desc = "<Plug> Toggle the quickfix list",
    callback = function()
        if not M.open_qflist() then
            M.close_qflist()
        end
    end,
})

vim.api.nvim_set_keymap("n", "<Plug>(qf-rancher-open-loclist)", "<nop>", {
    noremap = true,
    desc = "<Plug> Open the location list",
    callback = function()
        local height = vim.v.count > 0 and vim.v.count or nil
        M.open_loclist({ always_resize = true, height = height })
    end,
})

vim.api.nvim_set_keymap("n", "<Plug>(qf-rancher-close-loclist)", "<nop>", {
    noremap = true,
    desc = "<Plug> Close the location list",
    callback = M.close_loclist,
})

-- NOTE: A bit of jank here - Errors in the open function are suppressed so we don't get a
-- "window has no loclist" message before checking for orphans in the close function. If there is
-- indeed no loclist, the close function correctly reports as such, but it's not intuitive
-- that only the close function would report on global context. But also the only way to handle
-- edge cases around orphan loclists without handling it twice or without some kind of mediator
-- function
-- MAYBE: If the loclist code gets more complicated, some kind of overall loclist state becomes
-- more relevant
vim.api.nvim_set_keymap("n", "<Plug>(qf-rancher-toggle-loclist)", "<nop>", {
    noremap = true,
    desc = "<Plug> Toggle the location list",
    callback = function()
        if not M.open_loclist({ suppress_errors = true }) then
            M.close_loclist()
        end
    end,
})

--------------------
--- Default Maps ---
--------------------

---@diagnostic disable-next-line: undefined-field
if vim.g.qfrancher_setdefaultmaps then
    local nofallback_desc = "Prevent fallback to other mappings"
    vim.api.nvim_set_keymap("n", "<leader>q", "<nop>", { noremap = true, desc = nofallback_desc })
    vim.api.nvim_set_keymap("n", "<leader>l", "<nop>", { noremap = true, desc = nofallback_desc })

    vim.api.nvim_set_keymap("n", "<leader>qp", "<Plug>(qf-rancher-open-qf-list)", {
        noremap = true,
        desc = "Open the quickfix list",
    })

    vim.api.nvim_set_keymap("n", "<leader>qo", "<Plug>(qf-rancher-close-qf-list)", {
        noremap = true,
        desc = "Close the quickfix list",
    })

    vim.api.nvim_set_keymap("n", "<leader>qq", "<Plug>(qf-rancher-toggle-qf-list)", {
        noremap = true,
        desc = "Toggle the quickfix list",
    })

    vim.api.nvim_set_keymap("n", "<leader>lp", "<Plug>(qf-rancher-open-loclist)", {
        noremap = true,
        desc = "Open the location list",
    })

    vim.api.nvim_set_keymap("n", "<leader>lo", "<Plug>(qf-rancher-close-loclist)", {
        noremap = true,
        desc = "Close the location list",
    })

    vim.api.nvim_set_keymap("n", "<leader>ll", "<Plug>(qf-rancher-toggle-loclist)", {
        noremap = true,
        desc = "Toggle the location list",
    })
end

------------
--- Cmds ---
------------

---@diagnostic disable-next-line: undefined-field
if vim.g.qfrancher_setdefaultcmds then
    vim.api.nvim_create_user_command("Qopen", function(arg)
        local count = arg.count > 0 and arg.count or nil
        M.open_qflist({ always_resize = true, height = count })
    end, { count = 0 })

    vim.api.nvim_create_user_command("Lopen", function(arg)
        local count = arg.count > 0 and arg.count or nil
        M.open_loclist({ always_resize = true, height = count })
    end, { count = 0 })

    vim.api.nvim_create_user_command("Qclose", M.close_qflist, {})
    vim.api.nvim_create_user_command("Lclose", M.close_loclist, {})
end

return M
