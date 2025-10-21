local et = Qfr_Defer_Require("mjm.error-list-tools") ---@type QfrTools
local eu = Qfr_Defer_Require("mjm.error-list-util") ---@type QfrUtil
local ey = Qfr_Defer_Require("mjm.error-list-types") ---@type QfrTypes

local api = vim.api
local fn = vim.fn

-- DOCUMENT: Open is a bad module name

---@mod Open Open, close, and resize list wins

--- @class QfrOpen
local Open = {}

-- ============
-- == LOCALS ==
-- ============

---@param views vim.fn.winsaveview.ret[]
---@return nil
local function restore_views(views)
    for win, view in pairs(views) do
        if not api.nvim_win_is_valid(win) then return end

        api.nvim_win_call(win, function()
            if fn.line("w0") ~= view.topline then fn.winrestview(view) end
        end)
    end
end

---@param wins integer[]
---@return vim.fn.winsaveview.ret[]
local function get_views(wins)
    local views = {} ---@type vim.fn.winsaveview.ret[]
    if not eu._get_g_var("qf_rancher_always_save_views") then return views end

    ---@type string
    local splitkeep = api.nvim_get_option_value("splitkeep", { scope = "global" })
    if splitkeep == "screen" or splitkeep == "topline" then return views end

    for _, win in pairs(wins) do
        if not views[win] then
            local wintype = fn.win_gettype(win)
            if wintype == "" or wintype == "loclist" or wintype == "quickfix" then
                views[win] = api.nvim_win_call(win, fn.winsaveview)
            end
        end
    end

    return views
end

---@param src_win integer|nil
---@param height? integer
---@return integer
local function resolve_height_for_list(src_win, height)
    ey._validate_win(src_win, true)
    vim.validate("height", height, "number", true)

    if height then return height end

    if not eu._get_g_var("qf_rancher_auto_list_height") then return QFR_MAX_HEIGHT end

    local size = et._get_list(src_win, { nr = 0, size = 0 }).size ---@type integer
    if not size then return QFR_MAX_HEIGHT end
    size = math.max(size, 1)
    size = math.min(size, QFR_MAX_HEIGHT)

    return size
end

---@param opts QfrListOpenOpts
---@return nil
local function validate_and_clean_open_opts(opts)
    ey._validate_open_opts(opts)
    -- Let zero count fall back to default behavior
    if opts.height and opts.height < 1 then opts.height = nil end
end

-- MID: It would be useful when handling loclist orphans if the loclist open function returned
-- the loclist number after opening. This should be possible since lopen jumps to the list by
-- default

---@param list_win integer
---@param opts QfrListOpenOpts
---@return boolean
local function handle_open_list_win(list_win, opts)
    validate_and_clean_open_opts(opts)

    if opts.nop_if_open then return false end

    if opts.height or eu._get_g_var("qf_rancher_auto_list_height") then
        Open._resize_list_win(list_win, opts.height)
    end

    if not opts.keep_win then api.nvim_set_current_win(list_win) end

    return true
end

---@param views vim.fn.winsaveview.ret[]
---@param keep_win boolean
---@param cur_win integer
---@return boolean
local function open_cleanup(views, keep_win, cur_win)
    restore_views(views)
    if keep_win then api.nvim_set_current_win(cur_win) end
    return true
end

-- DOCUMENT: That we respect switchbuf uselast for cclose/lclose

---@param list_win integer
---@param cur_win integer
---@return integer|nil
local function get_alt_win(list_win, cur_win)
    ey._validate_win(list_win)
    ey._validate_win(cur_win)

    if list_win ~= cur_win then return nil end
    ---@type string
    local switchbuf = api.nvim_get_option_value("switchbuf", { scope = "global" })
    local uselast = string.find(switchbuf, "uselast", 1, true) ---@type integer|nil
    if not uselast then return nil end

    local alt_winnr = fn.winnr("#") ---@type integer
    return fn.win_getid(alt_winnr)
end

-- ================
-- == PUBLIC API ==
-- ================

-- MID: Add a "max" or "maxheight" arg, or maybe use bang, to open to max height from the cmd

---@param cargs vim.api.keyset.create_user_command.command_args
---@return nil
function Open.open_qflist_cmd(cargs)
    local count = cargs.count > 0 and cargs.count or nil ---@type integer|nil
    Open._open_qflist({ height = count })
end

---@param cargs vim.api.keyset.create_user_command.command_args
---@return nil
function Open.open_loclist_cmd(cargs)
    local count = cargs.count > 0 and cargs.count or nil ---@type integer|nil
    local src_win = api.nvim_get_current_win()
    Open._open_loclist(src_win, { height = count })
end

---@return nil
function Open.close_qflist_cmd()
    Open._close_qflist()
end

---@return nil
function Open.close_loclist_cmd()
    Open._close_loclist(api.nvim_get_current_win())
end

---@param cargs vim.api.keyset.create_user_command.command_args
---@return nil
function Open.toggle_qflist_cmd(cargs)
    local count = cargs.count > 0 and cargs.count or nil ---@type integer|nil
    Open._toggle_qflist({ height = count })
end

---@param cargs vim.api.keyset.create_user_command.command_args
---@return nil
function Open.toggle_loclist_cmd(cargs)
    local count = cargs.count > 0 and cargs.count or nil ---@type integer|nil
    Open._toggle_loclist(vim.api.nvim_get_current_win(), { height = count })
end

---@export Open

-- =================
-- == UNSUPPORTED ==
-- =================

-- MID: "get_filtered_tabpage_wins" might be a useful util function

---@param opts QfrListOpenOpts
---@return boolean
function Open._open_qflist(opts)
    validate_and_clean_open_opts(opts)

    local cur_win = api.nvim_get_current_win() ---@type integer
    local tabpage = api.nvim_win_get_tabpage(cur_win) ---@type integer
    local list_win = eu._get_qf_win({ tabpage = tabpage }) ---@type integer|nil

    if list_win then return handle_open_list_win(list_win, opts) end

    local ll_wins = eu._get_all_loclist_wins({ tabpage = tabpage }) ---@type integer[]
    local tabpage_wins = api.nvim_tabpage_list_wins(tabpage) ---@type integer[]
    tabpage_wins = vim.tbl_filter(function(win)
        return not vim.tbl_contains(ll_wins, win)
    end, tabpage_wins)

    local views = get_views(tabpage_wins) ---@type vim.fn.winsaveview.ret[]
    for _, ll_win in ipairs(ll_wins) do
        eu._pclose_and_rm(ll_win, true, true)
    end

    local height = resolve_height_for_list(nil, opts.height)
    local split = eu._get_g_var("qf_rancher_qfsplit") ---@type string
    ---@diagnostic disable: missing-fields
    api.nvim_cmd({ cmd = "copen", count = height, mods = { split = split } }, {})
    return open_cleanup(views, opts.keep_win, cur_win)
end

-- MID: Applies to close_loclist as well - Might want to drop src_win as a param. It muddies the
-- context between what src_win the function is called for and the user's current win
-- LOW: I don't love tying the no loclist msg to nop_if_open, but it seems to work

---@param src_win integer
---@param opts QfrListOpenOpts
---@return boolean
function Open._open_loclist(src_win, opts)
    validate_and_clean_open_opts(opts)

    local qf_id = fn.getloclist(src_win, { id = 0 }).id ---@type integer
    if qf_id == 0 then
        if not opts.nop_if_open then
            api.nvim_echo({ { "Window has no location list", "" } }, false, {})
        end

        return false
    end

    local tabpage = api.nvim_win_get_tabpage(src_win) ---@type integer
    local ll_win = eu._get_loclist_win_by_qf_id(qf_id, { tabpage = tabpage }) ---@type integer|nil
    if ll_win then return handle_open_list_win(ll_win, opts) end

    local tabpage_wins = api.nvim_tabpage_list_wins(tabpage) ---@type integer[]
    local qf_win = eu._get_qf_win({ tabpage = tabpage }) ---@type integer|nil
    if qf_win then
        tabpage_wins = vim.tbl_filter(function(win)
            return win ~= qf_win
        end, tabpage_wins)
    end

    local views = get_views(tabpage_wins) ---@type vim.fn.winsaveview.ret[]
    local height = resolve_height_for_list(src_win, opts.height) ---@type integer
    if qf_win then eu._pclose_and_rm(qf_win, true, true) end

    -- NOTE: Do not win call because Nvim will not properly jump to the opened win
    ---@diagnostic disable: missing-fields
    api.nvim_cmd({ cmd = "lopen", count = height }, {})
    return open_cleanup(views, opts.keep_win, src_win)
end

---@param src_win? integer
---@param opts QfrListOpenOpts
---@return boolean
function Open._open_list(src_win, opts)
    ey._validate_win(src_win, true)
    -- NOTE: Because these functions return booleans, cannot use the Lua ternary
    if src_win then
        return Open._open_loclist(src_win, opts)
    else
        return Open._open_qflist(opts)
    end
end

---@return boolean
function Open._close_qflist()
    local cur_win = api.nvim_get_current_win() ---@type integer
    local tabpage = api.nvim_win_get_tabpage(cur_win) ---@type integer

    local qf_win = eu._get_qf_win({ tabpage = tabpage }) ---@type integer|nil
    if not qf_win then return false end

    local tabpage_wins = api.nvim_tabpage_list_wins(tabpage) ---@type integer[]
    tabpage_wins = vim.tbl_filter(function(win)
        return win ~= qf_win
    end, tabpage_wins)

    local exit_win = get_alt_win(qf_win, cur_win) ---@type integer|nil
    local views = get_views(tabpage_wins) ---@type vim.fn.winsaveview.ret[]

    api.nvim_cmd({ cmd = "cclose" }, {})
    restore_views(views)
    if exit_win and api.nvim_win_is_valid(exit_win) then api.nvim_set_current_win(exit_win) end
    return true
end

---@param src_win integer
---@return boolean
function Open._close_loclist(src_win)
    ey._validate_win(src_win)

    local wintype = fn.win_gettype(src_win)
    local qf_id = fn.getloclist(src_win, { id = 0 }).id ---@type integer
    if qf_id == 0 and wintype ~= "loclist" then
        api.nvim_echo({ { "Window has no loclist", "" } }, false, {})
        return false
    end

    local tabpage = api.nvim_win_get_tabpage(src_win) ---@type integer
    local ll_wins = eu._get_ll_wins_by_qf_id(qf_id, { tabpage = tabpage }) ---@type integer[]
    if #ll_wins < 1 then return false end

    local tabpage_wins = api.nvim_tabpage_list_wins(tabpage) ---@type integer[]
    tabpage_wins = vim.tbl_filter(function(win)
        return not vim.tbl_contains(ll_wins, win)
    end, tabpage_wins)

    local cur_win = api.nvim_get_current_win() ---@type integer
    ---@type integer|nil
    local exit_win = vim.tbl_contains(ll_wins, cur_win) and get_alt_win(cur_win, cur_win) or nil

    local views = get_views(tabpage_wins) ---@type vim.fn.winsaveview.ret[]
    api.nvim_win_call(src_win, function()
        api.nvim_cmd({ cmd = "lclose" }, {}) -- Fire QuickFixCmd event
    end)

    for _, ll_win in ipairs(ll_wins) do
        eu._pclose_and_rm(ll_win, true, true) -- Will skip lclosed window
    end

    restore_views(views)
    if exit_win and api.nvim_win_is_valid(exit_win) then api.nvim_set_current_win(exit_win) end
    return true
end

---@param src_win? integer
---@return nil
function Open._close_list(src_win)
    ey._validate_win(src_win, true)

    if src_win then
        Open._close_loclist(src_win)
    else
        Open._close_qflist()
    end
end

---@param opts QfrListOpenOpts
---@return nil
function Open._toggle_qflist(opts)
    local toggle_opts = vim.tbl_extend("force", opts, { nop_if_open = true })
    if not Open._open_qflist(toggle_opts) then Open._close_qflist() end
end

---@param src_win integer
---@param opts QfrListOpenOpts
---@return nil
function Open._toggle_loclist(src_win, opts)
    ey._validate_win(src_win)

    local toggle_opts = vim.tbl_extend("force", opts, { nop_if_open = true })
    local opened = Open._open_loclist(src_win, toggle_opts)
    if not opened then Open._close_loclist(src_win) end
end

---@param win integer
---@return boolean
function Open._close_win_save_views(win)
    ey._validate_win(win, false)

    local tabpage = api.nvim_win_get_tabpage(win) ---@type integer
    local tabpage_wins = api.nvim_tabpage_list_wins(tabpage) ---@type integer[]
    tabpage_wins = vim.tbl_filter(function(t_win)
        return t_win ~= win
    end, tabpage_wins)

    local views = get_views(tabpage_wins) ---@type vim.fn.winsaveview.ret[]
    eu._pclose_and_rm(win, true, true)
    restore_views(views)

    return true
end

---@param list_win integer
---@param height? integer
---@return nil
function Open._resize_list_win(list_win, height)
    ey._validate_list_win(list_win)
    vim.validate("height", height, "number", true)

    local list_wintype = fn.win_gettype(list_win)
    local is_loclist = list_wintype == "loclist" ---@type boolean
    local is_qflist = list_wintype == "quickfix" ---@type boolean
    if not (is_loclist or is_qflist) then return end

    local old_height = api.nvim_win_get_height(list_win) ---@type integer
    local src_win = is_loclist and list_win or nil ---@type integer|nil
    local new_height = resolve_height_for_list(src_win, height) ---@type integer
    if old_height == new_height then return end

    local tabpage = api.nvim_win_get_tabpage(list_win) ---@type integer
    local tabpage_wins = api.nvim_tabpage_list_wins(tabpage) ---@type integer[]
    tabpage_wins = vim.tbl_filter(function(win)
        return win ~= list_win
    end, tabpage_wins)

    local views = get_views(tabpage_wins) ---@type vim.fn.winsaveview.ret[]
    api.nvim_win_set_height(list_win, new_height)
    restore_views(views)
end

-- LOW: For these operations, and anything similar in utils, the closing/saving should be done on
-- a per tabpage basis rather than a per listwin basis, so that for tabs where multiple
-- location lists are opened, the views can be saved and restored once. Low priority because the
-- most likely case of this issue occuring, opening a QfList, already works this way

---@param opts QfRancherTabpageOpts
---@return nil
function Open._close_qfwins(opts)
    ey._validate_tabpage_opts(opts)

    local qfwins = eu._get_qf_wins(opts) ---@type integer[]
    for _, list in ipairs(qfwins) do
        Open._close_win_save_views(list)
    end
end

---@param opts QfRancherTabpageOpts
---@return nil
function Open._resize_qfwins(opts)
    ey._validate_tabpage_opts(opts)

    local qfwins = eu._get_qf_wins(opts) ---@type integer[]
    for _, list in ipairs(qfwins) do
        Open._resize_list_win(list, nil)
    end
end

---@param src_win integer
---@param opts QfRancherTabpageOpts
---@return nil
function Open._resize_loclists_by_win(src_win, opts)
    ey._validate_win(src_win, false)
    ey._validate_tabpage_opts(opts)

    ---@type integer[]
    local loclists = eu._get_loclist_wins_by_win(src_win, opts)
    for _, list_win in ipairs(loclists) do
        Open._resize_list_win(list_win, nil)
    end
end

---@param src_win integer|nil
---@param opts QfRancherTabpageOpts
---@return nil
function Open._resize_lists_by_win(src_win, opts)
    ey._validate_win(src_win, true)
    if src_win then
        Open._resize_loclists_by_win(src_win, opts)
    else
        Open._resize_qfwins(opts)
    end
end

---@param qf_id integer
---@param opts QfRancherTabpageOpts
---@return nil
function Open._close_loclists_by_qf_id(qf_id, opts)
    ey._validate_uint(qf_id)
    ey._validate_tabpage_opts(opts)

    ---@type integer[]
    local llists = eu._get_ll_wins_by_qf_id(qf_id, opts)
    for _, list in ipairs(llists) do
        Open._close_win_save_views(list)
    end
end

return Open

-- TODO: Docs
-- TODO: Tests

-- MID: Implement a feature where, if you open list to a blank one, do a wrapping search forward or
--     backward for a list with items
-- - Or less obstrusively, showing history on blank lists or a statusline component

-- LOW: Make get_list_height work without nowrap
-- LOW: Make a Neovim tools repo that has the pwin close function
