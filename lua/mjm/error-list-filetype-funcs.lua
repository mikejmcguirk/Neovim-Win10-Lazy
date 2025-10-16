--- @class QfRancherFiletypeFuncs
local M = {}

local eo = Qfr_Defer_Require("mjm.error-list-open") --- @type QfRancherOpen
local en = Qfr_Defer_Require("mjm.error-list-nav-action") --- @type QfRancherNav
local et = Qfr_Defer_Require("mjm.error-list-tools") --- @type QfRancherTools
local eu = Qfr_Defer_Require("mjm.error-list-util") --- @type QfRancherUtils
local ey = Qfr_Defer_Require("mjm.error-list-types") --- @type QfRancherTypes

local api = vim.api
local fn = vim.fn

---------------------
--- LIST DELETION ---
---------------------

-- TODO: The default map for vsplits simply cannot include V. Even outside multi-line deletion,
-- it is broadly useful for yanking. Change that map, then re-create the multi-line visual
-- delete

function M._del_one_list_item()
    local list_win = api.nvim_get_current_win() --- @type integer
    if not ey._is_in_list_win(list_win) then return end

    local src_win = fn.win_gettype(list_win) == "loclist" and list_win or nil --- @type integer|nil
    local list_dict = et._get_list(src_win, { nr = 0, all = true }) --- @type table
    if #list_dict.items < 1 then return end

    local row, col = unpack(api.nvim_win_get_cursor(list_win)) --- @type integer, integer
    table.remove(list_dict.items, row)
    et._set_list(src_win, {
        nr = 0,
        items = list_dict.items,
        idx = list_dict.idx,
        user_data = { action = "replace" },
    })

    eu._protected_set_cursor(0, { row, col })
end

-----------------------
--- LIST NAVIGATION ---
-----------------------

-- --- @param src_win integer|nil
-- --- @param count integer
-- --- @param opts {keep_win?:boolean}
-- --- @param func function
-- --- @return nil
-- local function list_nav(src_win, count, opts, func)
--     ey._validate_uint(src_win, true)
--     vim.validate("opts", opts, "table")
--
--     local cur_win = src_win --- @type integer|nil
--     if not cur_win then cur_win = vim.api.nvim_get_current_win() end
--     if not ey._is_in_list_win(cur_win) then return end
--
--     local adj_opts = vim.tbl_extend("force", opts, { keep_win = true }) --- @type table
--     if not func(src_win, count, adj_opts) then return end
--
--     local cur_idx = et._get_list(src_win, { nr = 0, idx = 0 }).idx --- @type integer
--     local col = vim.api.nvim_win_get_cursor(cur_win)[2] --- @type integer
--     eu._protected_set_cursor(cur_win, { cur_idx, col })
--     eu._do_zzze(cur_win)
-- end
--
-- --- @param src_win integer|nil
-- --- @param count integer
-- --- @param opts {keep_win?:boolean}
-- --- @return nil
-- function M._list_prev(src_win, count, opts)
--     list_nav(src_win, count, opts, en._prev)
-- end
--
-- --- @param src_win integer|nil
-- --- @param count integer
-- --- @param opts {keep_win?:boolean}
-- --- @return nil
-- function M._list_next(src_win, count, opts)
--     list_nav(src_win, count, opts, en._next)
-- end

-------------------------
--- LIST OPEN HELPERS ---
-------------------------

-- TODO: Is there a way to consolidate this with the one in preview?

--- @param src_win integer|nil
--- @return vim.quickfix.entry|nil, integer|nil
local function get_list_item(src_win)
    ey._validate_win(src_win, true)

    --- @type vim.quickfix.entry[]
    local items = et._get_list(src_win, { nr = 0, items = true }).items
    if #items < 1 then return nil, nil end

    local line = fn.line(".") --- @type integer
    local item = items[line] --- @type vim.quickfix.entry
    if item.bufnr and api.nvim_buf_is_valid(item.bufnr) then return item, line end

    api.nvim_echo({ { "List item bufnr is invalid", "ErrorMsg" } }, true, { err = true })
    return nil, nil
end

--- @return integer|nil, integer|nil, boolean
local function get_list_info()
    local list_win = api.nvim_get_current_win() --- @type integer
    if not ey._is_in_list_win(list_win) then
        api.nvim_echo({ { "Not inside a list window", "" } }, false, {})
        return nil, nil, false
    end

    local is_loclist = fn.win_gettype(list_win) == "loclist" --- @type boolean
    local src_win = is_loclist and list_win or nil --- @type integer|nil

    local loclist_origin_win = (is_loclist and src_win)
            and eu._find_loclist_origin(src_win, { all_tabpages = true })
        or nil --- @type integer|nil

    local is_orphan = is_loclist and not loclist_origin_win --- @type boolean

    return list_win, src_win, is_orphan
end

--- @param list_win integer
--- @param dest_win integer
--- @param finish QfRancherFinishMethod
--- @return nil
local function handle_orphan(list_win, dest_win, finish)
    ey._validate_list_win(list_win)
    ey._validate_win(dest_win)
    ey._validate_finish_method(finish)
    if eu._get_g_var("qf_rancher_debug_assertions") then
        local cur_win = api.nvim_get_current_win() --- @type integer
        if finish == "closeList" or finish == "focusWin" then assert(cur_win == dest_win) end
        if finish == "focusList" then assert(cur_win == list_win) end
    end

    local dest_win_qf_id = fn.getloclist(dest_win, { id = 0 }).id
    if dest_win_qf_id > 0 then
        if finish == "closeList" then eo._close_win_save_views(list_win) end
        return
    end

    local stack = et._get_stack(list_win) --- @type table[]
    eo._close_win_save_views(list_win)
    et._set_stack(dest_win, stack)

    if finish == "closeList" then
        if eu._get_g_var("qf_rancher_debug_assertions") then
            assert(api.nvim_get_current_win() == dest_win)
        end

        return
    end

    local keep_win = finish == "focusWin" --- @type boolean
    -- Cannot ensure proper context with nvim_win_call because open_loclist is meant
    -- to use lopen to move to the list win if keep_win is false
    api.nvim_set_current_win(dest_win)
    eo._open_loclist(dest_win, { keep_win = keep_win })

    if eu._get_g_var("qf_rancher_debug_assertions") then
        local cur_win = api.nvim_get_current_win() --- @type integer
        if finish == "focusWin" then assert(cur_win == dest_win) end
        if finish == "focusList" then assert(fn.win_gettype(cur_win) == "loclist") end
    end
end

--- @param win integer
--- @param dest_buftype string
--- @param buf? integer
--- @return boolean
--- NOTE: Because this runs in loops, skip validation
local function is_valid_dest_win(win, dest_buftype, buf)
    local wintype = fn.win_gettype(win)

    local win_buf = api.nvim_win_get_buf(win) --- @type integer
    local win_buftype = api.nvim_get_option_value("buftype", { buf = win_buf }) --- @type string
    local has_buf = (function()
        if not buf then
            return true
        else
            return win_buf == buf
        end
    end)() --- @type boolean

    -- NOTE: Prefer being too restrictive about allowed wins. Handle edge cases as they come up
    local valid_buf = has_buf and win_buftype == dest_buftype --- @type boolean
    return wintype == "" and valid_buf
end

--- @param tabnr integer
--- @param dest_buftype string
--- @param opts QfRancherFindWinInTabOpts
--- @return integer|nil
local function find_win_in_tab(tabnr, dest_buftype, opts)
    ey._validate_uint(tabnr)
    vim.validate("dest_buftype", dest_buftype, "string")
    ey._validate_find_win_in_tab_opts(opts)

    local max_winnr = fn.tabpagewinnr(tabnr, "$") --- @type integer
    local skip_winnr = opts.skip_winnr --- @type integer|nil

    for i = 1, max_winnr do
        if i ~= skip_winnr then
            -- Convert now because win_gettype does not support tab context
            local win = fn.win_getid(i, tabnr)
            if is_valid_dest_win(win, dest_buftype, opts.bufnr) then return win end
        end
    end
end

--- @param list_tabnr integer
--- @param dest_buftype string
--- @param buf integer|nil
--- @return integer|nil
local function find_win_in_tabs(list_tabnr, dest_buftype, buf)
    ey._validate_uint(list_tabnr)
    vim.validate("dest_buftype", dest_buftype, "string")
    ey._validate_uint(buf, true)

    local test_tabnr = list_tabnr --- @type integer
    local max_tabnr = fn.tabpagenr("$") --- @type integer

    for _ = 1, 100 do
        test_tabnr = test_tabnr + 1
        if test_tabnr > max_tabnr then test_tabnr = 1 end
        if test_tabnr == list_tabnr then break end

        --- @type integer|nil
        local tabpage_win = find_win_in_tab(test_tabnr, dest_buftype, { bufnr = buf })
        if tabpage_win then return tabpage_win end
    end

    return nil
end

--- @param tabnr integer
--- @param dest_buftype string
--- @param opts QfRancherFindWinInTabOpts
--- @return integer|nil
local function find_win_in_tab_reverse(tabnr, dest_buftype, opts)
    ey._validate_uint(tabnr)
    vim.validate("dest_buftype", dest_buftype, "string")
    ey._validate_find_win_in_tab_opts(opts)

    local max_winnr = fn.tabpagewinnr(tabnr, "$") --- @type integer
    local fin_winnr = opts.fin_winnr or 1 --- @type integer
    local test_winnr = fin_winnr --- @type integer
    local skip_winnr = opts.skip_winnr --- @type integer|nil

    for _ = 1, 100 do
        test_winnr = test_winnr - 1
        if test_winnr <= 0 then test_winnr = max_winnr end
        if test_winnr ~= skip_winnr then
            -- Convert now because win_gettype does not support tab context
            local win = fn.win_getid(test_winnr, tabnr)
            if is_valid_dest_win(win, dest_buftype, opts.bufnr) then return win end
        end

        if test_winnr == fin_winnr then break end
    end

    return nil
end

--- @param list_tabnr integer
--- @param dest_buftype string
--- @return integer|nil
local function get_count_win(list_tabnr, dest_buftype)
    ey._validate_uint(list_tabnr)
    vim.validate("dest_buftype", dest_buftype, "string")

    local max_winnr = fn.tabpagewinnr(list_tabnr, "$") --- @type integer
    local adj_count = math.min(vim.v.count, max_winnr) --- @type integer
    local target_win = fn.win_getid(adj_count, list_tabnr) --- @type integer

    if is_valid_dest_win(target_win, dest_buftype) then return target_win end
    api.nvim_echo({ { "Winnr " .. adj_count .. " is not valid", "" } }, false, {})
    return nil
end

--- @param list_win integer
--- @param dest_buftype string
--- @param buf? integer
--- @return boolean, integer|nil
local function get_ll_dest_win(list_win, dest_buftype, buf)
    ey._validate_list_win(list_win)
    vim.validate("dest_buftype", dest_buftype, "string")
    ey._validate_uint(buf, true)

    local list_tabpage = api.nvim_win_get_tabpage(list_win) --- @type integer
    local list_tabnr = api.nvim_tabpage_get_number(list_tabpage) --- @type integer

    if vim.v.count > 0 then
        local count_win = get_count_win(list_tabnr, dest_buftype)
        if count_win then return true, count_win end
        return false, nil
    end

    if dest_buftype == "help" then return true, find_win_in_tab(list_tabnr, dest_buftype, {}) end

    --- @type integer|nil
    local loclist_origin = eu._find_loclist_origin(list_win, { tabpage = list_tabpage })
    if loclist_origin then return true, loclist_origin end

    local list_winnr = api.nvim_win_get_number(list_win) --- @type integer
    --- @type QfRancherFindWinInTabOpts
    local find_buf_opts = { bufnr = buf, skip_winnr = list_winnr }
    --- @type integer|nil
    local tabpage_buf_win = find_win_in_tab(list_tabnr, dest_buftype, find_buf_opts)
    if tabpage_buf_win then return true, tabpage_buf_win end

    --- @type QfRancherFindWinInTabOpts
    local find_opts = { fin_winnr = list_winnr, skip_winnr = list_winnr }
    --- @type integer|nil
    local fallback_win = find_win_in_tab_reverse(list_tabnr, dest_buftype, find_opts)

    if fallback_win then return true, fallback_win end
    return true, nil
end

--- @param list_win integer
--- @param dest_buftype string
--- @param buf? integer
--- @return boolean, integer|nil
local function get_qf_dest_win(list_win, dest_buftype, buf)
    ey._validate_list_win(list_win)
    vim.validate("dest_buftype", dest_buftype, "string")
    ey._validate_uint(buf, true)

    local list_tabpage = api.nvim_win_get_tabpage(list_win) --- @type integer
    local list_tabnr = api.nvim_tabpage_get_number(list_tabpage) --- @type integer

    if vim.v.count > 0 then
        local count_win = get_count_win(list_tabnr, dest_buftype)
        if count_win then return true, count_win end
        return false, nil
    end

    if dest_buftype == "help" then return true, find_win_in_tab(list_tabnr, dest_buftype, {}) end

    --- @type string
    local switchbuf = api.nvim_get_option_value("switchbuf", { scope = "global" })
    local list_winnr = api.nvim_win_get_number(list_win) --- @type integer

    if string.find(switchbuf, "useopen", 1, true) then
        --- @type QfRancherFindWinInTabOpts
        local find_opts = { bufnr = buf, skip_winnr = list_winnr }
        --- @type integer|nil
        local tabpage_buf_win = find_win_in_tab(list_tabnr, dest_buftype, find_opts)
        if tabpage_buf_win then return true, tabpage_buf_win end
    end

    if string.find(switchbuf, "usetab", 1, true) then
        local usetab_win = find_win_in_tabs(list_tabnr, dest_buftype, buf) --- @type integer|nil
        if usetab_win then return true, usetab_win end
    end

    if string.find(switchbuf, "uselast", 1, true) then
        local alt_winnr = fn.tabpagewinnr(list_tabnr, "#") --- @type integer
        local alt_win = fn.win_getid(alt_winnr, list_tabnr) --- @type integer
        if is_valid_dest_win(alt_win, dest_buftype, buf) then return true, alt_win end
    end

    --- @type QfRancherFindWinInTabOpts
    local find_opts = { fin_winnr = list_winnr, skip_winnr = list_winnr }
    --- @type integer|nil
    local fallback_win = find_win_in_tab_reverse(list_tabnr, dest_buftype, find_opts)

    if fallback_win then return true, fallback_win end
    return true, nil
end

--- @param list_win integer
--- @param dest_win integer|nil
--- @param open QfRancherOpenMethod
--- @return vim.api.keyset.win_config
local function get_split_config(list_win, dest_win, open)
    local adj_dest_win = dest_win or list_win --- @type integer
    if adj_dest_win == list_win then return { win = adj_dest_win, split = "above" } end

    if open == "split" then
        --- @type boolean
        local splitbelow = api.nvim_get_option_value("splitbelow", { scope = "global" })
        local split_dir = splitbelow and "below" or "above" --- @type string
        return { win = adj_dest_win, split = split_dir }
    end

    --- @type boolean
    local splitright = api.nvim_get_option_value("splitright", { scope = "global" })
    local split_dir = splitright and "right" or "left" --- @type string
    return { win = adj_dest_win, split = split_dir }
end

-----------------------
--- LIST OPEN FUNCS ---
-----------------------

-- DOCUMENT: switchbuf behavior for direct open:
-- useopen is respected and given first priority
-- usetab is respected and given next priority
-- uselast is respected and given next priority
-- split, vsplit, and newtab are not respected

-- MID: It would be cool if the qf vs ll find path were determined at ftplugin load time, since
-- the buf should not switch list types

--- @param finish QfRancherFinishMethod
--- @return nil
function M._direct_open(finish)
    ey._validate_finish_method(finish)

    --- @type integer|nil, integer|nil, boolean
    local list_win, src_win, is_orphan = get_list_info()
    if not list_win then return end

    local item, line = get_list_item(src_win) --- @type vim.quickfix.entry|nil, integer|nil
    if not (item and line) then return end

    local dest_buftype = item.type == "\1" and "help" or "" --- @type string
    local ok, dest_win = (function()
        if src_win then return get_ll_dest_win(list_win, dest_buftype, item.bufnr) end
        return get_qf_dest_win(list_win, dest_buftype, item.bufnr)
    end)() --- @type boolean, integer|nil

    if not ok then return end
    if not dest_win then
        -- TODO: This needs to be a split. Branch off into that logic
        -- Use a g_var to say switchbuf, vsplit, or split to open
        api.nvim_echo({ { "No available dest win. Needs to be a split", "" } }, false, {})
        return
    end

    local goto_win = finish ~= "focusList" --- @type boolean
    et._set_list(src_win, { nr = 0, idx = line, user_data = { action = "replace" } })
    eu._open_item_to_win(item, { buftype = dest_buftype, goto_win = goto_win, win = dest_win })

    if (not is_orphan) and finish == "closeList" then eo._close_win_save_views(list_win) end

    if is_orphan then handle_orphan(list_win, dest_win, finish) end
end

--- @param open QfRancherOpenMethod
--- @param finish QfRancherFinishMethod
--- @return nil
function M._split_open(open, finish)
    ey._validate_open_method(open)
    ey._validate_finish_method(finish)

    --- @type integer|nil, integer|nil, boolean
    local list_win, src_win, is_orphan = get_list_info()
    if not list_win then return end

    local item, line = get_list_item(src_win) --- @type vim.quickfix.entry|nil, integer|nil
    if not (item and line) then return end

    local dest_buftype = item.type == "\1" and "help" or "" --- @type string
    local ok, dest_win = (function()
        if src_win then return get_ll_dest_win(list_win, dest_buftype, item.bufnr) end
        return get_qf_dest_win(list_win, dest_buftype, item.bufnr)
    end)() --- @type boolean, integer|nil

    if not ok then return end

    --- @type vim.api.keyset.win_config
    local split_config = get_split_config(list_win, dest_win, open)
    local goto_win = finish ~= "focusList" --- @type boolean
    et._set_list(src_win, { nr = 0, idx = line, user_data = { action = "replace" } })
    local split_win = api.nvim_open_win(item.bufnr, false, split_config) --- @type integer
    eu._open_item_to_win(
        item,
        { buftype = dest_buftype, clearjumps = true, goto_win = goto_win, win = split_win }
    )

    if (not is_orphan) and finish == "closeList" then eo._close_win_save_views(list_win) end

    if is_orphan then handle_orphan(list_win, split_win, finish) end
end

--- TODO: Do we just take tabnew out of the finish opts and have it be a split opt?

--- @param finish QfRancherFinishMethod
--- @return nil
function M._tabnew_open(finish)
    ey._validate_finish_method(finish)

    --- @type integer|nil, integer|nil, boolean
    local list_win, src_win, is_orphan = get_list_info()
    if not list_win then return end

    local item, line = get_list_item(src_win) --- @type vim.quickfix.entry|nil, integer|nil
    if not (item and line) then return end

    local tab_count = fn.tabpagenr("$") --- @type integer
    --- @type integer
    local range = vim.v.count > 0 and math.min(vim.v.count, tab_count) or tab_count
    local dest_buftype = item.type == "\1" and "help" or "" --- @type string

    et._set_list(src_win, { nr = 0, idx = line, user_data = { action = "replace" } })
    api.nvim_cmd({ cmd = "tabnew", range = { range } }, {})
    local dest_win = api.nvim_get_current_win() --- @type integer
    eu._open_item_to_win(item, { buftype = dest_buftype, win = dest_win })

    -- TODO: Silly if you have an orphan, but here for the moment because direct/splits end up
    -- here
    if finish == "focusList" then vim.api.nvim_set_current_win(list_win) end
    if (not is_orphan) and finish == "closeList" then eo._close_win_save_views(list_win) end

    if is_orphan then handle_orphan(list_win, dest_win, finish) end
end

return M

-- TODO: Remove closeList handling
-- TODO: Re-add the multi-line visual delete
-- TODO: Create stevearc's {} maps for scrolling in the list

-- MID: This file is essentially a set of funcs to re-create the list-opening behavior plus a
-- couple different ways to access them. It would be good to generalize and factor these out,
-- including the autocmd firing, so that they can be applied to other funcs, such as performing
-- list nav without losing window focus

-----------
-- MAYBE --
-----------

-- MAYBE: For some of the context switching, eventignore could be useful. But very bad if we error
-- with that option on

------------------
--- REFERENCES ---
------------------

-- qf_view_result
-- ex_cc
-- qf_jump
-- qf_jump_newwin
-- qf_jump_open_window
-- jump_to_help_window
-- qf_jump_to_usable_window
-- qf_find_win_with_loclist
-- qf_open_new_file_win
-- qf_goto_win_with_ll_file
-- qf_goto_win_with_qfl_file
