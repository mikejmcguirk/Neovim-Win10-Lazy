---@class QfRancherFiletypeFuncs
local M = {}

local eo = Qfr_Defer_Require("mjm.error-list-open") ---@type QfRancherOpen
local et = Qfr_Defer_Require("mjm.error-list-tools") ---@type QfrTools
local eu = Qfr_Defer_Require("mjm.error-list-util") ---@type QfrUtil
local ey = Qfr_Defer_Require("mjm.error-list-types") ---@type QfrTypes

local api = vim.api
local fn = vim.fn

---------------------
--- LIST DELETION ---
---------------------

---@return nil
function M._del_one_list_item()
    local list_win = api.nvim_get_current_win() ---@type integer
    local wintype = fn.win_gettype(list_win)
    if not (wintype == "quickfix" or wintype == "loclist") then
        api.nvim_echo({ { "Not inside a list window", "" } }, false, {})
        return
    end

    local src_win = wintype == "loclist" and list_win or nil ---@type integer|nil
    local list = et._get_list(src_win, { nr = 0, all = true }) ---@type table
    if #list.items < 1 then return end

    local row, col = unpack(api.nvim_win_get_cursor(list_win)) ---@type integer, integer
    table.remove(list.items, row)
    et._set_list(src_win, "u", { nr = 0, items = list.items, idx = list.idx })

    eu._protected_set_cursor(0, { row, col })
end

function M._visual_del()
    local list_win = api.nvim_get_current_win() ---@type integer
    local wintype = fn.win_gettype(list_win)
    if not (wintype == "quickfix" or wintype == "loclist") then
        api.nvim_echo({ { "Not inside a list window", "" } }, false, {})
        return
    end

    local mode = string.sub(api.nvim_get_mode().mode, 1, 1) ---@type string
    if mode ~= "V" then
        api.nvim_echo({ { "Must be in visual line mode", "" } }, false, {})
        return
    end

    local src_win = wintype == "loclist" and list_win or nil ---@type integer|nil
    local list = et._get_list(src_win, { nr = 0, all = true }) ---@type table
    if #list.items < 1 then return end
    local col = vim.api.nvim_win_get_cursor(list_win)[2] ---@type integer

    local cur = fn.getpos(".") ---@type table
    local fin = fn.getpos("v") ---@type table
    local selection = api.nvim_get_option_value("selection", { scope = "global" }) ---@type string
    local exclusive = selection == "exclusive" ---@type boolean
    local region = fn.getregionpos(cur, fin, { type = mode, exclusive = exclusive }) ---@type table

    ---@type Range4
    local vrange_4 =
        { region[1][1][2], region[1][1][3], region[#region][2][2], region[#region][2][3] }
    api.nvim_cmd({ cmd = "normal", args = { "\27" }, bang = true }, {})
    for i = vrange_4[3], vrange_4[1], -1 do
        table.remove(list.items, i)
    end

    et._set_list(src_win, "u", {
        nr = 0,
        items = list.items,
        idx = list.idx,
    })

    eu._protected_set_cursor(0, { vrange_4[1], col })
end

-------------------------
--- LIST OPEN HELPERS ---
-------------------------

---@param list_win integer
---@param buf_win integer
---@param finish QfRancherFinishMethod
---@return nil
local function handle_orphan(list_win, buf_win, finish)
    ey._validate_list_win(list_win)
    ey._validate_win(buf_win)
    ey._validate_finish_method(finish)

    local buf_win_qf_id = fn.getloclist(buf_win, { id = 0 }).id ---@type integer
    if buf_win_qf_id > 0 then return end

    local stack = et._get_stack(list_win) ---@type table[]
    eo._close_win_save_views(list_win)
    et._set_stack(buf_win, stack)

    api.nvim_set_current_win(buf_win)
    eo._open_loclist(buf_win, { keep_win = finish == "focusWin" })

    if eu._get_g_var("qf_rancher_debug_assertions") then
        local cur_win = api.nvim_get_current_win() ---@type integer
        if finish == "focusWin" then assert(cur_win == buf_win) end
        if finish == "focusList" then assert(fn.win_gettype(cur_win) == "loclist") end
    end
end

---@param win integer
---@param dest_buftype string
---@param buf? integer
---@return boolean
--- NOTE: Because this runs in loops, skip validation
local function is_valid_dest_win(win, dest_buftype, buf)
    local wintype = fn.win_gettype(win)

    local win_buf = api.nvim_win_get_buf(win) ---@type integer
    local win_buftype = api.nvim_get_option_value("buftype", { buf = win_buf }) ---@type string
    local has_buf = (function()
        if not buf then
            return true
        else
            return win_buf == buf
        end
    end)() ---@type boolean

    -- NOTE: Prefer being too restrictive about allowed wins. Handle edge cases as they come up
    local valid_buf = has_buf and win_buftype == dest_buftype ---@type boolean
    return wintype == "" and valid_buf
end

---@param tabnr integer
---@param dest_buftype string
---@param opts QfRancherFindWinInTabOpts
---@return integer|nil
local function find_win_in_tab(tabnr, dest_buftype, opts)
    ey._validate_uint(tabnr)
    vim.validate("dest_buftype", dest_buftype, "string")
    ey._validate_find_win_in_tab_opts(opts)

    local max_winnr = fn.tabpagewinnr(tabnr, "$") ---@type integer
    local skip_winnr = opts.skip_winnr ---@type integer|nil

    for i = 1, max_winnr do
        if i ~= skip_winnr then
            -- Convert now because win_gettype does not support tab context
            local win = fn.win_getid(i, tabnr)
            if is_valid_dest_win(win, dest_buftype, opts.bufnr) then return win end
        end
    end

    return nil
end

---@param list_tabnr integer
---@param dest_buftype string
---@param buf integer|nil
---@return integer|nil
local function find_win_in_tabs(list_tabnr, dest_buftype, buf)
    ey._validate_uint(list_tabnr)
    vim.validate("dest_buftype", dest_buftype, "string")
    ey._validate_uint(buf, true)

    local test_tabnr = list_tabnr ---@type integer
    local max_tabnr = fn.tabpagenr("$") ---@type integer

    for _ = 1, 100 do
        test_tabnr = test_tabnr + 1
        if test_tabnr > max_tabnr then test_tabnr = 1 end
        if test_tabnr == list_tabnr then break end

        ---@type integer|nil
        local tabpage_win = find_win_in_tab(test_tabnr, dest_buftype, { bufnr = buf })
        if tabpage_win then return tabpage_win end
    end

    return nil
end

---@param tabnr integer
---@param dest_buftype string
---@param opts QfRancherFindWinInTabOpts
---@return integer|nil
local function find_win_in_tab_reverse(tabnr, dest_buftype, opts)
    ey._validate_uint(tabnr)
    vim.validate("dest_buftype", dest_buftype, "string")
    ey._validate_find_win_in_tab_opts(opts)

    local max_winnr = fn.tabpagewinnr(tabnr, "$") ---@type integer
    local fin_winnr = opts.fin_winnr or 1 ---@type integer
    local test_winnr = fin_winnr ---@type integer
    local skip_winnr = opts.skip_winnr ---@type integer|nil

    for _ = 1, 100 do
        test_winnr = test_winnr - 1
        if test_winnr <= 0 then test_winnr = max_winnr end
        if test_winnr ~= skip_winnr then
            -- Convert now because win_gettype does not support tab context
            local win = fn.win_getid(test_winnr, tabnr) ---@type integer
            if is_valid_dest_win(win, dest_buftype, opts.bufnr) then return win end
        end

        if test_winnr == fin_winnr then break end
    end

    return nil
end

---@param list_tabnr integer
---@param dest_buftype string
---@return integer|nil
local function get_count_win(list_tabnr, dest_buftype)
    ey._validate_uint(list_tabnr)
    vim.validate("dest_buftype", dest_buftype, "string")

    local max_winnr = fn.tabpagewinnr(list_tabnr, "$") ---@type integer
    local adj_count = math.min(vim.v.count, max_winnr) ---@type integer
    local target_win = fn.win_getid(adj_count, list_tabnr) ---@type integer

    if is_valid_dest_win(target_win, dest_buftype) then return target_win end
    api.nvim_echo({ { "Winnr " .. adj_count .. " is not valid", "" } }, false, {})
    return nil
end

---@param list_win integer
---@param dest_buftype string
---@param buf integer
---@param is_loclist boolean
---@param loclist_origin? integer
---@return boolean, integer|nil
local function get_dest_win(list_win, dest_buftype, buf, is_loclist, loclist_origin)
    ey._validate_list_win(list_win)
    vim.validate("dest_buftype", dest_buftype, "string")
    ey._validate_buf(buf)
    vim.validate("is_loclist", is_loclist, "boolean")
    ey._validate_win(loclist_origin, true)

    local list_tabpage = api.nvim_win_get_tabpage(list_win) ---@type integer
    local list_tabnr = api.nvim_tabpage_get_number(list_tabpage) ---@type integer

    if vim.v.count > 0 then
        local count_win = get_count_win(list_tabnr, dest_buftype)
        if count_win then return true, count_win end
        return false, nil
    end

    local list_winnr = api.nvim_win_get_number(list_win) ---@type integer
    if dest_buftype == "help" then
        return true, find_win_in_tab(list_tabnr, dest_buftype, { skip_winnr = list_winnr })
    end

    if is_loclist and loclist_origin then return true, loclist_origin end

    local switchbuf = not is_loclist
            and api.nvim_get_option_value("switchbuf", { scope = "global" })
        or nil ---@type string

    if string.find(switchbuf, "useopen", 1, true) or is_loclist then
        ---@type QfRancherFindWinInTabOpts
        local find_opts = { bufnr = buf, skip_winnr = list_winnr }
        ---@type integer|nil
        local tabpage_buf_win = find_win_in_tab(list_tabnr, dest_buftype, find_opts)
        if tabpage_buf_win then return true, tabpage_buf_win end
    end

    if string.find(switchbuf, "usetab", 1, true) and not is_loclist then
        local usetab_win = find_win_in_tabs(list_tabnr, dest_buftype, buf) ---@type integer|nil
        if usetab_win then return true, usetab_win end
    end

    if string.find(switchbuf, "uselast", 1, true) and not is_loclist then
        local alt_winnr = fn.tabpagewinnr(list_tabnr, "#") ---@type integer
        local alt_win = fn.win_getid(alt_winnr, list_tabnr) ---@type integer
        if is_valid_dest_win(alt_win, dest_buftype, buf) then return true, alt_win end
    end

    ---@type QfRancherFindWinInTabOpts
    local find_opts = { fin_winnr = list_winnr, skip_winnr = list_winnr }
    ---@type integer|nil
    local fallback_win = find_win_in_tab_reverse(list_tabnr, dest_buftype, find_opts)

    if fallback_win then return true, fallback_win end
    return true, nil
end

-----------------------
--- LIST OPEN FUNCS ---
-----------------------

-- DOCUMENT: switchbuf behavior :
-- useopen is respected and given first priority
-- usetab is respected and given next priority
-- uselast is respected and given next priority
-- split, vsplit, and newtab are not respected

---@param list_win integer
---@param dest_win integer|nil
---@param is_orphan boolean
---@return boolean
local function should_resize_list_win(list_win, dest_win, is_orphan)
    ey._validate_list_win(list_win)
    ey._validate_win(dest_win, true)
    vim.validate("is_orphan", is_orphan, "boolean")

    if dest_win or is_orphan then return false end

    local win_tabpage = vim.api.nvim_win_get_tabpage(list_win) ---@type integer
    return #vim.api.nvim_tabpage_list_wins(win_tabpage) == 1
end

---@param dest_win integer|nil
---@param split QfRancherSplitType
---@param buf integer
---@param list_win integer
local function get_buf_win(dest_win, split, buf, list_win)
    ey._validate_win(dest_win, true)
    ey._validate_list_win(list_win)
    ey._validate_buf(buf)
    ey._validate_split(split)

    if dest_win and split == "none" then return dest_win end

    if not dest_win then
        return api.nvim_open_win(buf, false, { win = list_win, split = "above" })
    end

    if split == "split" then
        ---@type boolean
        local splitbelow = api.nvim_get_option_value("splitbelow", { scope = "global" })
        local split_dir = splitbelow and "below" or "above" ---@type string
        return api.nvim_open_win(buf, false, { win = dest_win, split = split_dir })
    end

    ---@type boolean
    local splitright = api.nvim_get_option_value("splitright", { scope = "global" })
    local split_dir = splitright and "right" or "left" ---@type string
    return api.nvim_open_win(buf, false, { win = dest_win, split = split_dir })
end

---@param finish QfRancherFinishMethod
---@return nil
local function tabnew_open(list_win, item, finish, is_orphan, pattern)
    ey._validate_list_win(list_win)
    ey._validate_list_item(item)
    ey._validate_finish_method(finish)
    vim.validate("is_orphan", is_orphan, "boolean")
    vim.validate("pattern", pattern, "string")

    local tab_count = fn.tabpagenr("$") ---@type integer
    ---@type integer
    local range = vim.v.count > 0 and math.min(vim.v.count, tab_count) or tab_count
    api.nvim_cmd({ cmd = "tabnew", range = { range } }, {})

    local buf_win = api.nvim_get_current_win() ---@type integer
    local dest_buftype = item.type == "\1" and "help" or "" ---@type string
    eu._open_item_to_win(item, { buftype = dest_buftype, win = buf_win })
    if finish == "focusList" and not is_orphan then vim.api.nvim_set_current_win(list_win) end

    if is_orphan then handle_orphan(list_win, buf_win, finish) end

    vim.api.nvim_exec_autocmds("QuickFixCmdPost", { pattern = pattern })
end

-- LOW: Can this logic be generalized? Should it be?

---@param finish QfRancherFinishMethod
---@param idx_func QfRancherIdxFunc
---@return nil
function M._open_item_from_list(split, finish, idx_func)
    ey._validate_split(split)
    ey._validate_finish_method(finish)
    vim.validate("idx_func", idx_func, "callable")

    local list_win = api.nvim_get_current_win() ---@type integer
    if not ey._is_in_list_win(list_win) then
        api.nvim_echo({ { "Not inside a list window", "" } }, false, {})
        return
    end

    local is_loclist = fn.win_gettype(list_win) == "loclist" ---@type boolean
    local src_win = is_loclist and list_win or nil ---@type integer|nil
    local loclist_origin = (is_loclist and src_win)
            and eu._find_loclist_origin(src_win, { all_tabpages = true })
        or nil ---@type integer|nil

    local is_orphan = is_loclist and not loclist_origin ---@type boolean

    local item, idx = idx_func(src_win) ---@type vim.quickfix.entry|nil, integer|nil
    if not (item and item.bufnr and item.type and idx) then return end

    local dest_buftype = item.type == "\1" and "help" or "" ---@type string
    ---@type boolean, integer|nil
    local ok, dest_win =
        get_dest_win(list_win, dest_buftype, item.bufnr, is_loclist, loclist_origin)

    if not ok then return end

    local pattern = src_win and "ll" or "cc"
    vim.api.nvim_exec_autocmds("QuickFixCmdPre", { pattern = pattern })

    et._set_list(src_win, "u", { nr = 0, idx = idx })

    if split == "tabnew" then
        tabnew_open(list_win, item, finish, is_orphan, pattern)
        return
    end

    local should_resize = should_resize_list_win(list_win, dest_win, is_orphan) ---@type boolean
    local row, col = unpack(api.nvim_win_get_cursor(list_win)) ---@type integer, integer
    if row ~= idx then
        eu._protected_set_cursor(list_win, { idx, col })
        eu._do_zzze(list_win)
    end

    local buf_win = get_buf_win(dest_win, split, item.bufnr, list_win) ---@type integer
    local clearjumps = not (split == "none" and dest_win == buf_win) ---@type boolean
    local goto_win = finish == "focusWin" ---@type boolean
    eu._open_item_to_win(
        item,
        { buftype = dest_buftype, clearjumps = clearjumps, goto_win = goto_win, win = buf_win }
    )

    if should_resize then eo._resize_list_win(list_win) end
    if is_orphan then handle_orphan(list_win, buf_win, finish) end

    vim.api.nvim_exec_autocmds("QuickFixCmdPost", { pattern = pattern })
end

-----------------------
-- MAPPING FUNCTIONS --
-----------------------

function M._open_direct_focuswin()
    M._open_item_from_list("none", "focusWin", eu._get_item_under_cursor)
end

function M._open_direct_focuslist()
    M._open_item_from_list("none", "focusList", eu._get_item_under_cursor)
end

function M._open_split_focuswin()
    M._open_item_from_list("split", "focusWin", eu._get_item_under_cursor)
end

function M._open_split_focuslist()
    M._open_item_from_list("split", "focusList", eu._get_item_under_cursor)
end

function M._open_vsplit_focuswin()
    M._open_item_from_list("vsplit", "focusWin", eu._get_item_under_cursor)
end

function M._open_vsplit_focuslist()
    M._open_item_from_list("vsplit", "focusList", eu._get_item_under_cursor)
end

function M._open_tabnew_focuswin()
    M._open_item_from_list("tabnew", "focusWin", eu._get_item_under_cursor)
end

function M._open_tabnew_focuslist()
    M._open_item_from_list("tabnew", "focusList", eu._get_item_under_cursor)
end

function M._open_prev_focuslist()
    M._open_item_from_list("none", "focusList", eu._get_item_wrapping_sub)
end

function M._open_next_focuslist()
    M._open_item_from_list("none", "focusList", eu._get_item_wrapping_add)
end

return M

-- TODO: docs
-- TODO: tests

-- MAYBE: For some of the context switching, eventignore could be useful. But very bad if we error
-- with that option on

----------------
-- REFERENCES --
----------------

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
