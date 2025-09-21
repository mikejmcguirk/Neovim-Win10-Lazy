local M = {}

--- @param win integer
--- @return boolean, [string, string]|nil
local function protected_win_close(win)
    if not vim.api.nvim_win_is_valid(win) then
        return false, { "Window " .. win .. " is invalid", "WarningMsg" }
    end

    local tabpages = vim.api.nvim_list_tabpages()
    local win_tabpage = vim.api.nvim_win_get_tabpage(win)
    local win_tabpage_wins = vim.api.nvim_tabpage_list_wins(win_tabpage)
    if #tabpages == 1 and #win_tabpage_wins == 1 then
        return false, { "Cannot close the last window", "" }
    end

    local ok, err = pcall(vim.api.nvim_win_close, win, true)
    if not ok then
        local msg = err or ("Unknown error closing window " .. win)
        return false, { msg, "ErrorMsg" }
    end

    return true
end

--- @param win integer
--- @return boolean
local function close_list_win(win, print_errors)
    local ok, err = protected_win_close(win) --- @type boolean, [string, string]|nil
    if ok then
        return true
    end

    if err and err[1] == "Cannot close the last window" then
        local buf = vim.api.nvim_win_get_buf(win) --- @type integer
        if not vim.api.nvim_buf_is_valid(buf) then
            local msg = "Bufnr " .. buf .. " in window " .. win .. " is not valid" --- @type string
            vim.api.nvim_echo({ { msg, "ErrorMsg" } }, true, { err = true })
            return false
        end

        vim.api.nvim_buf_delete(buf, { force = true })
        return true
    end

    if not print_errors then
        return false
    end

    --- @type string
    local msg = (err and err[1]) and err[1] or "Unknown error in protected_win_close"
    local hl = (err and err[2]) and err[2] or "ErrorMsg" --- @type string
    vim.api.nvim_echo({ { msg, hl } }, true, { err = true })
    return false
end

--- @param wins integer[]
--- @param print_errors boolean
--- @return nil
local function close_list_wins(wins, print_errors)
    for _, win in wins do
        close_list_win(win, print_errors)
    end
end

--- @param win integer
--- @param view vim.fn.winsaveview.ret
--- @return nil
local function restore_view(win, view)
    if not vim.api.nvim_win_is_valid(win) then
        return
    end

    vim.api.nvim_win_call(win, function()
        if vim.fn.line("w0") ~= view.topline then
            vim.fn.winrestview(view)
        end
    end)
end

--- @param views vim.fn.winsaveview.ret[]
--- @return nil
local function restore_views(views)
    for win, view in pairs(views) do
        restore_view(win, view)
    end
end

-- TODO: need close all loclists

-- TODO: Don't move this, need it for comparisons later
local max_qf_height = 10

-- NOTE: This assumes nowrap
--- @param win integer
--- @param is_ll? boolean
--- @return integer
local function get_list_height(win, is_ll)
    vim.validate("win", win, "number")
    local getlist = require("mjm.error-list-util").get_getlist(win, is_ll or false)
    local cur_size = getlist({ size = true }).size

    local list_height = math.min(cur_size, max_qf_height)
    list_height = math.max(list_height, 1)
    return list_height
end

--- @param win integer
--- @param is_ll boolean
--- @return nil
local function resize_list(win, is_ll)
    local list_height = get_list_height(win, is_ll)
    vim.api.nvim_win_set_height(win, list_height)
end

--- @param wins integer[]
--- @return integer|nil, integer|nil
local function find_qf_win(wins)
    for i, win in ipairs(wins) do
        local wintype = vim.fn.win_gettype(win)
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
        local wintype = vim.fn.win_gettype(win)
        if wintype == "loclist" then
            table.insert(ll_wins, win)
        end
    end

    return ll_wins
end

--- @param wins integer[]
--- @param qf_id integer
--- @return integer|nil
local function find_ll_win_by_id(wins, qf_id)
    for _, win in pairs(wins) do
        local wintype = vim.fn.win_gettype(win)
        if wintype == "loclist" then
            local w_qf_id = vim.fn.getloclist(win, { id = 0 }).id ---@type integer
            if w_qf_id == qf_id then
                return win
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

--- @class QfRancherOpenOpts
--- @field always_resize boolean
--- @field keep_win boolean

--- @param opts QfRancherOpenOpts
--- @return boolean
--- opts:
--- - always_resize: If the qf window is already open, it will be resized
--- - keep_win: On completion, return focus to the calling win
function M.open_qflist(opts)
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

    close_list_wins(ll_wins)
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
    if not qf_win then
        return false
    end

    if qf_idx then
        table.remove(wins, qf_idx)
    end

    local views = get_views(wins) --- @type vim.fn.winsaveview.ret[]
    close_list_win(qf_win, true)
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

--- @param opts QfRancherOpenOpts
--- @return boolean
function M.open_loclist(opts)
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
        close_list_win(qf_win)
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

return M
