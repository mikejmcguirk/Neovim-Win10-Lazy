local M = {}

-----------
-- Types --
-----------

--- @class QfRancherOpenOpts
--- @field always_resize? boolean
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
--- @param is_ll? boolean
--- @return nil
local function resize_list(list_win, is_ll)
    vim.validate("is_ll", is_ll, { "boolean", "nil" })
    vim.validate("win", list_win, "number")
    vim.validate("list_win", list_win, function()
        return vim.api.nvim_win_is_valid(list_win)
    end)

    if is_ll == nil then
        local wintype = vim.fn.win_gettype(list_win)
        is_ll = wintype == "loclist"
    end

    local list_height = get_list_height(list_win, is_ll)
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
    if qf_win and opts.always_resize then
        local ll_views = get_views(ll_wins) --- @type vim.fn.winsaveview.ret[]
        resize_list(qf_win, false)
        restore_views(views)
        restore_views(ll_views)
        return false
    end

    pclose_wins(ll_wins)
    local height = get_list_height(cur_win, false) --- @type integer
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
    resize_list(qf_win, false)
    restore_views(views)
end

--- @param opts? QfRancherOpenOpts
--- @return boolean
function M.open_loclist(opts)
    opts = opts or {}
    local cur_win = vim.api.nvim_get_current_win() --- @type integer
    local qf_id = vim.fn.getloclist(cur_win, { id = 0 }).id ---@type integer
    if qf_id == 0 then
        vim.api.nvim_echo({ { "Window has no loclist", "" } }, false, {})
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
    if ll_win and opts.always_resize then
        if qf_win then
            local qf_view = get_views({ qf_win }) --- @type vim.fn.winsaveview.ret[]
            vim.list_extend(views, qf_view)
        end

        resize_list(ll_win, true)
        restore_views(views)
        return false
    end

    if qf_win then
        pwin_close({ bwipeout = true, force = true, win = qf_win })
    end

    local height = get_list_height(cur_win, false) --- @type integer
    --- @diagnostic disable: missing-fields
    vim.api.nvim_cmd({ cmd = "lopen", count = height, mods = { split = "botright" } }, {})
    restore_views(views)
    if opts.keep_win then
        vim.api.nvim_set_current_win(cur_win)
    end

    return true
end

--- @return boolean, integer|nil, vim.fn.winsaveview.ret[]|nil
local function get_ll_close_resize_info()
    local cur_win = vim.api.nvim_get_current_win() --- @type integer
    local qf_id = vim.fn.getloclist(cur_win, { id = 0 }).id ---@type integer
    if qf_id == 0 then
        vim.api.nvim_echo({ { "Window has no loclist", "" } }, false, {})
        return false, nil, nil
    end

    local wins = vim.api.nvim_tabpage_list_wins(0) --- @type integer[]
    local ll_win, ll_idx = find_ll_win_by_id(wins, qf_id) --- @type integer|nil
    if (not ll_win) or not ll_idx then
        return false, nil, nil
    end

    local views = get_views(wins) --- @type vim.fn.winsaveview.ret[]
    return true, ll_win, views
end

--- @return boolean
function M.close_loclist()
    local ok, ll_win, views = get_ll_close_resize_info()
    if (not ok) or not ll_win or not views then
        return false
    end

    pwin_close({ bwipeout = true, force = true, win = ll_win })
    restore_views(views)
    return true
end

--- @return boolean
function M.resize_loclist()
    local ok, ll_win, views = get_ll_close_resize_info()
    if (not ok) or not ll_win or not views then
        return false
    end

    resize_list(ll_win, true)
    restore_views(views)
    return true
end

-- MAYBE: You could use these two functions as the end path for any close or resize function

--- @param list_win integer
--- @return boolean
-- TODO: rename to just close_list_win
function M.close_win_restview(list_win)
    vim.validate("list_win", list_win, "number")
    vim.validate("list_win", list_win, function()
        return vim.api.nvim_win_is_valid(list_win)
    end)

    vim.validate("list_win", list_win, function()
        local wintype = vim.fn.win_gettype(list_win)
        return wintype == "qflist" or wintype == "loclist"
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
        return wintype == "qflist" or wintype == "loclist"
    end)

    local win_tabpage = vim.api.nvim_win_get_tabpage(list_win) --- @type integer
    local wins = vim.api.nvim_tabpage_list_wins(win_tabpage) --- @type integer[]
    local views = get_views(wins) --- @type vim.fn.winsaveview.ret[]
    resize_list(list_win)
    restore_views(views)

    return true
end

--------------
-- Mappings --
--------------

local nofallback_desc = "Prevent fallback to other mappings"
vim.api.nvim_set_keymap("n", "<leader>q", "<nop>", { noremap = true, desc = nofallback_desc })
vim.api.nvim_set_keymap("n", "<leader>l", "<nop>", { noremap = true, desc = nofallback_desc })

vim.api.nvim_set_keymap("n", "<leader>qp", "", {
    noremap = true,
    desc = "Open the quickfix list",
    callback = M.open_qflist,
})

-- TODO: This is the sort map
vim.api.nvim_set_keymap("n", "<leader>qo", "", {
    noremap = true,
    desc = "Close the quickfix list",
    callback = M.close_qflist,
})

vim.api.nvim_set_keymap("n", "<leader>qq", "", {
    noremap = true,
    desc = "Toggle the quickfix list",
    callback = function()
        if not M.open_qflist() then
            M.close_qflist()
        end
    end,
})

vim.api.nvim_set_keymap("n", "<leader>qQ", "", {
    noremap = true,
    desc = "Resize the quickfix list",
    callback = M.resize_qflist,
})

vim.api.nvim_set_keymap("n", "<leader>lp", "", {
    noremap = true,
    desc = "Open the location list",
    callback = M.open_loclist,
})

vim.api.nvim_set_keymap("n", "<leader>lo", "", {
    noremap = true,
    desc = "Close the location list",
    callback = M.close_loclist,
})

vim.api.nvim_set_keymap("n", "<leader>ll", "", {
    noremap = true,
    desc = "Toggle the location list",
    callback = function()
        if not M.open_loclist() then
            M.close_loclist()
        end
    end,
})

vim.api.nvim_set_keymap("n", "<leader>lL", "", {
    noremap = true,
    desc = "Resize the location list",
    callback = M.resize_loclist,
})

return M
