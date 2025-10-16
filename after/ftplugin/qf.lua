local eo = Qfr_Defer_Require("mjm.error-list-open") --- @type QfRancherOpen
local ep = Qfr_Defer_Require("mjm.error-list-preview") --- @type QfRancherPreview
local es = Qfr_Defer_Require("mjm.error-list-stack") --- @type QfRancherStack
local et = Qfr_Defer_Require("mjm.error-list-tools") --- @type QfRancherTools
local eu = Qfr_Defer_Require("mjm.error-list-util") --- @type QfRancherUtils
local ey = Qfr_Defer_Require("mjm.error-list-types") --- @type QfRancherTypes

-- NOTE: Avoid using the util g_var function during setup to avoid eager requires

-- DOCUMENT: Which options are set
if vim.g.qf_rancher_ftplugin_set_opts then
    vim.api.nvim_set_option_value("buflisted", false, { buf = 0 })
    vim.api.nvim_set_option_value("cc", "", { scope = "local" })
    vim.api.nvim_set_option_value("list", false, { scope = "local" })
end

-- TODO: Document which defaults are removed
if vim.g.qf_rancher_ftplugin_demap then
    vim.api.nvim_buf_set_keymap(0, "n", "<C-w>v", "<nop>", { noremap = true })
    vim.api.nvim_buf_set_keymap(0, "n", "<C-w><C-v>", "<nop>", { noremap = true })
    vim.api.nvim_buf_set_keymap(0, "n", "<C-w>s", "<nop>", { noremap = true })
    vim.api.nvim_buf_set_keymap(0, "n", "<C-w><C-s>", "<nop>", { noremap = true })

    vim.api.nvim_buf_set_keymap(0, "n", "<C-i>", "<nop>", { noremap = true })
    vim.api.nvim_buf_set_keymap(0, "n", "<C-o>", "<nop>", { noremap = true })
end

if not vim.g.qf_rancher_ftplugin_keymap then return end

-- TODO: These maps need to respect the qf_prefix
-- NOTE: Cannot use simple ternaries to chose between qflist and loclist maps because the
-- function literals would be evaluated during setup, causing eager requires

local loading_wintype = vim.fn.win_gettype(0)
local loading_loclist = loading_wintype == "loclist"
local list_prefix = loading_loclist and "l" or "q"

vim.keymap.set("n", "<leader>" .. list_prefix .. "o", function()
    local cur_win = vim.api.nvim_get_current_win() --- @type integer
    eo._close_win_save_views(cur_win)
end, { buffer = true, desc = "Close the list" })

vim.keymap.set("n", "q", function()
    local cur_win = vim.api.nvim_get_current_win() --- @type integer
    eo._close_win_save_views(cur_win)
end, { buffer = true, desc = "Close the list" })

vim.keymap.set("n", "dd", function()
    local list_win = vim.api.nvim_get_current_win() --- @type integer
    ey._validate_list_win(list_win) --- @type QfRancherTypes

    local wintype = vim.fn.win_gettype(list_win)
    local src_win = wintype == "loclist" and list_win or nil --- @type integer|nil
    local list_dict = et._get_list_all(src_win, 0) --- @type table
    if #list_dict.items < 1 then return end

    local row, col = unpack(vim.api.nvim_win_get_cursor(list_win)) --- @type integer, integer
    table.remove(list_dict, row)
    et._set_list(src_win, { nr = 0, items = list_dict.items, idx = list_dict.idx })
    eu._protected_set_cursor(0, { row, col })
end, { buffer = true, desc = "Delete the current list line" })

vim.keymap.set("n", "p", function()
    local cur_win = vim.api.nvim_get_current_win()
    ep.toggle_preview_win(cur_win)
end, { buffer = true, desc = "Open the preview win" })

vim.keymap.set("n", "P", function()
    ep.update_preview_win_pos()
end, { buffer = true, desc = "Open the preview win" })

if loading_loclist then
    vim.keymap.set("n", "<", function()
        local cur_win = vim.api.nvim_get_current_win()
        es._l_older(cur_win, vim.v.count)
    end, { buffer = true, desc = "Goto older loclist history" })

    vim.keymap.set("n", ">", function()
        local cur_win = vim.api.nvim_get_current_win()
        es._l_newer(cur_win, vim.v.count)
    end, { buffer = true, desc = "Goto newer loclist history" })
else
    vim.keymap.set("n", "<", function()
        es._q_older(vim.v.count)
    end, { buffer = true, desc = "Goto older qflist history" })

    vim.keymap.set("n", ">", function()
        es._q_newer(vim.v.count)
    end, { buffer = true, desc = "Goto newer qflist history" })
end

-------------
--- Types ---
-------------

-- TODO: Move this to types module and add a validation

--- @alias QfOpenMethod "split"|"tabnew"|"vsplit"
--- @alias QfRancherFinishMethod "closeList"|"focusList"|"focusWin"

--- @class QfOpenSplitFullCtx
--- @field list_win integer
--- @field buf_source mjm.OpenBufSource
--- @field buf_opts mjm.OpenBufOpts
--- @field is_loclist boolean
--- @field is_orphan_loclist boolean
--- @field open QfOpenMethod
--- @field finish QfRancherFinishMethod

---------------------
-- Qf Open Helpers --
---------------------

--- @param list_win integer
--- @param dest_win integer
--- @param finish QfRancherFinishMethod
--- @return nil
local function handle_orphan(list_win, dest_win, finish)
    ey._validate_list_win(list_win)
    ey._validate_win(dest_win)
    vim.validate("finish", finish, "string")
    if eu._get_g_var("qf_rancher_debug_assertions") then
        local cur_win = vim.api.nvim_get_current_win()
        if finish == "closeList" or finish == "focusWin" then assert(cur_win == dest_win) end
        if finish == "focusList" then assert(cur_win == list_win) end
    end

    local dest_win_qf_id = vim.fn.getloclist(dest_win, { id = 0 }).id
    if dest_win_qf_id > 0 then
        if finish == "closeList" then eo._close_win_save_views(list_win) end
        return
    end

    local stack = et._get_stack(list_win) --- @type table[]
    if eu._get_g_var("qf_rancher_debug_assertions") then
        local max_nr = vim.fn.getloclist(list_win, { nr = "$" }).nr
        assert(#stack == max_nr)
    end

    eo._close_win_save_views(list_win)
    et._set_stack(dest_win, stack)

    if eu._get_g_var("qf_rancher_debug_assertions") then
        local max_nr = vim.fn.getloclist(dest_win, { nr = "$" }).nr
        assert(#stack == max_nr)
    end

    if finish == "closeList" then
        if eu._get_g_var("qf_rancher_debug_assertions") then
            local cur_win = vim.api.nvim_get_current_win()
            assert(cur_win == dest_win)
        end

        return
    end

    local keep_win = finish == "focusWin"
    vim.api.nvim_set_current_win(dest_win)
    eo._open_loclist({ keep_win = keep_win })

    if eu._get_g_var("qf_rancher_debug_assertions") then
        local cur_win = vim.api.nvim_get_current_win()
        if finish == "focusWin" then assert(cur_win == dest_win) end
        if finish == "focusList" then
            local cur_wintype = vim.fn.win_gettype(cur_win)
            assert(cur_wintype == "loclist")
        end
    end
end

-- TODO: This is in tools

--- @param list_win integer
--- @return table, integer
--- LOW: Return order here is not the same as input order in set_loclist_data
local function get_loclist_data(list_win)
    if vim.g.qf_rancher_debug_assertions then
        local is_valid = function()
            return vim.api.nvim_win_is_valid(list_win)
        end
        vim.validate("list_win", list_win, is_valid)
        local list_buf = vim.api.nvim_win_get_buf(list_win)
        local list_buftype = vim.api.nvim_get_option_value("buftype", { buf = list_buf })
        vim.validate("list_win", list_win, function()
            return list_buftype == "quickfix"
        end)
    end

    local count = vim.fn.getloclist(list_win, { nr = "$" }).nr --- @type integer
    local loclist_data = {}

    for i = 1, count do
        local list = vim.fn.getloclist(list_win, { nr = i, all = true }) --- @type table
        table.insert(loclist_data, list)
    end

    local cur_stack_nr = vim.fn.getloclist(list_win, { nr = 0 }).nr --- @type integer
    return loclist_data, cur_stack_nr
end

-- TODO: This is in tools

--- @param cur_stack_nr integer
--- @param dest_win integer
--- @param loclist_data table
--- @return nil
local function set_loclist_data(cur_stack_nr, dest_win, loclist_data)
    if vim.g.qf_rancher_debug_assertions then
        vim.validate("cur_stack_nr", cur_stack_nr, "number")
        vim.validate("cur_stack_nr", cur_stack_nr, function()
            return cur_stack_nr > 0
        end)
        local is_valid = function()
            return vim.api.nvim_win_is_valid(dest_win)
        end
        vim.validate("dest_win", dest_win, is_valid)
        vim.validate("loclist_data", loclist_data, "table")
        local valid_stack = function()
            return cur_stack_nr <= #loclist_data
        end
        vim.validate("cur_stack_nr", cur_stack_nr, valid_stack)
    end

    for _, data in ipairs(loclist_data) do
        vim.fn.setloclist(dest_win, {}, " ", data)
    end

    --- @type vim.api.keyset.cmd
    --- @diagnostic disable-next-line: missing-fields
    local cmd = { cmd = "lhistory", count = cur_stack_nr, mods = { silent = true } }
    vim.api.nvim_win_call(dest_win, function()
        vim.api.nvim_cmd(cmd, {})
    end)
end

-- TODO: This is in utils

--- @param list_qf_id integer
--- @param list_win integer
--- @return integer|nil
local function find_loclist_win(list_qf_id, list_win)
    if vim.g.qf_rancher_debug_assertions then
        vim.validate("list_qf_id", list_qf_id, "number")
        vim.validate("list_qf_id", list_qf_id, function()
            return list_qf_id > 0
        end)

        local is_valid = function()
            return vim.api.nvim_win_is_valid(list_win)
        end

        vim.validate("list_win", list_win, is_valid)
        local list_buf = vim.api.nvim_win_get_buf(list_win)
        local list_buftype = vim.api.nvim_get_option_value("buftype", { buf = list_buf })
        vim.validate("list_win", list_win, function()
            return list_buftype == "quickfix"
        end)
    end

    local tabpage = vim.api.nvim_win_get_tabpage(list_win)

    for _, win in ipairs(vim.api.nvim_tabpage_list_wins(tabpage)) do
        local win_qf_id = vim.fn.getloclist(win, { id = 0 }).id --- @type integer
        if win_qf_id == list_qf_id then
            local buf = vim.api.nvim_win_get_buf(win) --- @type integer
            local buftype = vim.api.nvim_get_option_value("buftype", { buf = buf })
            if buftype ~= "quickfix" then return win end
        end
    end

    return nil
end

--- @param entry table
--- @param open? QfOpenMethod
--- @return mjm.OpenBufSource, mjm.OpenBufOpts
local function qf_get_open_buf_opts(entry, open)
    if vim.g.qf_rancher_debug_assertions then
        vim.validate("entry", entry, "table")
        vim.validate("open", open, { "nil", "string" })
    end

    local buf = entry.bufnr or vim.fn.bufadd(entry.bufname) --- @type integer
    local buf_source = { bufnr = buf } --- @type mjm.OpenBufSource

    local buftype = entry.type == "\1" and "help" or nil --- @type string|nil
    local lnum = entry.lnum or nil --- @type integer|nil
    -- qf cols are one-indexed
    local col = entry.col and math.max(entry.col - 1, 0) or nil --- @type integer|nil
    --- @type {[1]:integer, [2]: integer}|nil
    local cur_pos = (lnum and col) and { lnum, col } or nil

    local buf_opts = {
        buftype = buftype,
        clearjumps = true,
        cur_pos = cur_pos,
        force = true,
    } --- @type mjm.OpenBufOpts

    return buf_source, buf_opts
end

--- @param list_win integer
--- @param is_loclist boolean
--- @return boolean, table|string, integer
local function get_entry_on_cursor(list_win, is_loclist)
    if vim.g.qf_rancher_debug_assertions then
        local is_valid = function()
            return vim.api.nvim_win_is_valid(list_win)
        end
        vim.validate("list_win", list_win, is_valid)
        local list_buf = vim.api.nvim_win_get_buf(list_win)
        local list_buftype = vim.api.nvim_get_option_value("buftype", { buf = list_buf })
        vim.validate("list_win", list_win, function()
            return list_buftype == "quickfix"
        end)
    end

    local row = vim.api.nvim_win_get_cursor(list_win)[1] --- @type integer
    local entry = (function()
        if is_loclist then
            return vim.fn.getloclist(list_win, { id = 0, idx = row, items = true }).items[1]
        else
            return vim.fn.getqflist({ id = 0, idx = row, items = true }).items[1]
        end
    end)() --- @type table

    if not entry then return false, "No entry under cursor", 2 end

    if (not entry.bufnr) and ((not entry.filename) or entry.filename == "") then
        return false, "No buffer or file data for entry", 1
    end

    return true, entry, row
end

--------------------
-- Qf Open to Win --
--------------------

-- TODO: I have to imagine this fn can be used for the split opens as well
-- TODO: When looking for buf wins, the source iterates from winnr 1 and up
-- When performing a fallback look, the source then iterates in reverse
-- It also iterates forward when looking for help wins
-- TODO: Location lists do the following:
-- - If we need a help win, iterate forward
-- - If a buf win, iterate forward to find the buf
-- - Fallback iterate backward in the current tab
-- Note that loclists do NOT check switchbuf properties

--- @class QfRancherFindWinInTabOpts
--- @field bufnr? integer
--- @field last_winnr? integer
--- @field skip_last? boolean

--- @param tabnr integer
--- @param dest_buftype string
--- @param opts QfRancherFindWinInTabOpts
--- @return integer|nil
local function find_win_in_tab(tabnr, dest_buftype, opts)
    ey._validate_uint(tabnr)
    vim.validate("dest_wintype", dest_buftype, "string")
    -- TODO: Outline this validation
    vim.validate("opts", opts, "table")
    vim.validate("opts.bufnr", opts.bufnr, "number", true)
    ey._validate_uint(opts.bufnr, true)
    ey._validate_uint(opts.last_winnr, true)
    vim.validate("opts.skip_last_winnr", opts.skip_last, "boolean", true)

    -- LOW: It would be better to use the API to pull the tabpage wins and iterate that way, but
    -- (a) I don't think it's documented behavior that list_wins pulls the wins in winnr order
    -- (b) I'm not sure what the underlying logic is for which windows are given a winnr
    local max_winnr = vim.fn.tabpagewinnr(tabnr, "$") --- @type integer
    local last_winnr = opts.last_winnr or 1 --- @type integer
    local test_winnr = last_winnr --- @type integer

    for _ = 1, 100 do
        test_winnr = test_winnr - 1
        if test_winnr <= 0 then test_winnr = max_winnr end

        if test_winnr == last_winnr and opts.skip_last then break end

        -- Convert now because win_gettype does not allow specifying a tab context
        local win = vim.fn.win_getid(test_winnr, tabnr)
        local wintype = vim.fn.win_gettype(win)
        local win_buf = vim.api.nvim_win_get_buf(win) --- @type integer
        local win_buftype = vim.api.nvim_get_option_value("buftype", { buf = win_buf })
        local has_buf = (function()
            if not opts.bufnr then
                return true
            else
                return win_buf == opts.bufnr
            end
        end)() --- @type boolean

        -- NOTE: Being permissive or restrictive about the dest_wintype can, in theory, create
        -- different edge cases. I think the restrictive approach provides the more predictable
        -- starting point to add edge case handling on top of
        local valid_buf = has_buf and win_buftype == dest_buftype
        if wintype == "" and valid_buf then return win end

        if test_winnr == last_winnr then break end
    end

    return nil
end

--- @param list_win integer
--- @param dest_buftype string
--- @param buf integer
--- @return boolean, integer|nil
local function get_dest_win(list_win, dest_buftype, buf)
    ey._validate_list_win(list_win)
    vim.validate("dest_buftype", dest_buftype, "string")
    ey._validate_buf(buf)

    local list_win_tabpage = vim.api.nvim_win_get_tabpage(list_win) --- @type integer
    local list_win_tabnr = vim.api.nvim_tabpage_get_number(list_win_tabpage) --- @type integer

    if vim.v.count > 0 then
        -- TODO: This is the same logic as alt_win
        local max_winnr = vim.fn.tabpagewinnr(list_win_tabnr, "$") --- @type integer
        local adj_count = math.min(vim.v.count, max_winnr) --- @type integer
        local target_win = vim.fn.win_getid(adj_count, list_win_tabnr) --- @type integer
        local target_wintype = vim.fn.win_gettype(target_win)
        local target_win_buf = vim.api.nvim_win_get_buf(target_win) --- @type integer
        --- @type string
        local target_buftype = vim.api.nvim_get_option_value("buftype", { buf = target_win_buf })
        if target_wintype == "" and target_buftype == dest_buftype then
            return true, target_win
        else
            vim.api.nvim_echo({ { "Winnr " .. adj_count .. " is not valid", "" } }, false, {})
            return false, nil
        end
    end

    --- @type string
    local switchbuf = vim.api.nvim_get_option_value("switchbuf", { scope = "global" })
    local list_winnr = vim.api.nvim_win_get_number(list_win) --- @type integer

    if string.find(switchbuf, "useopen", 1, true) then
        --- @type integer|nil
        local tabpage_win = find_win_in_tab(
            list_win_tabnr,
            dest_buftype,
            { bufnr = buf, last_winnr = list_winnr, skip_last = true }
        )

        if tabpage_win then return true, tabpage_win end
    end

    if string.find(switchbuf, "usetab", 1, true) then
        local test_tabnr = list_win_tabnr --- @type integer
        local max_tabnr = vim.fn.tabpagenr("$") --- @type integer

        for _ = 1, 100 do
            test_tabnr = test_tabnr + 1
            if test_tabnr > max_tabnr then test_tabnr = 1 end
            if test_tabnr == list_win_tabnr then break end

            local tabpage_win = find_win_in_tab(test_tabnr, dest_buftype, { bufnr = buf })
            if tabpage_win then return true, tabpage_win end
        end
    end

    if string.find(switchbuf, "uselast", 1, true) then
        local alt_winnr = vim.fn.tabpagewinnr(list_win_tabnr, "#") --- @type integer
        local alt_win = vim.fn.win_getid(alt_winnr, list_win_tabnr) --- @type integer
        local alt_wintype = vim.fn.win_gettype(alt_winnr) --- @type string
        local alt_win_buf = vim.api.nvim_win_get_buf(alt_win) --- @type integer
        --- @type string
        local alt_buftype = vim.api.nvim_get_option_value("buftype", { buf = alt_win_buf })
        if alt_wintype == "" and alt_buftype == dest_buftype then
            return true, vim.fn.win_getid(alt_winnr, list_win_tabnr)
        end
    end

    local fallback_win = find_win_in_tab(
        list_win_tabnr,
        dest_buftype,
        { last_winnr = list_winnr, skip_last = true }
    )

    if fallback_win then
        return true, fallback_win
    else
        return true, nil
    end
end

-- DOCUMENT: switchbuf behavior for direct open:
-- useopen is respected and given first priority
-- usetab is respected and given next priority
-- uselast is respected and given next priority
-- split, vsplit, and newtab are not respected

--- @param finish QfRancherFinishMethod
--- @return nil
local function qf_direct_open(finish)
    vim.validate("finish", finish, "string")

    local list_win = vim.api.nvim_get_current_win() --- @type integer
    if not ey._is_in_list_win(list_win) then
        vim.api.nvim_echo({ { "Not inside a list window", "" } }, false, {})
        return
    end

    -- TODO: Thinking broadly - There's a boilerplate step in opening a list item where we have
    -- to determine if opening is even possible, then there's the actual opening. If we find that
    -- we need to fallback to a split open, we don't want to do the boilerplate again. Is there
    -- a way to split the validation and opening into separate functions? How much of that logic
    -- can be shared between the direct and split opens?
    local wintype = vim.fn.win_gettype(list_win)
    local is_loclist = wintype == "loclist"
    local src_win = is_loclist and list_win or nil --- @type integer|nil
    local items = et._get_list_items(src_win, 0) --- @type vim.quickfix.entry[]
    if #items < 1 then return end

    local line = vim.fn.line(".") --- @type integer
    local item = items[line] --- @type vim.quickfix.entry
    if not (item.bufnr and vim.api.nvim_buf_is_valid(item.bufnr)) then
        vim.api.nvim_echo({ { "List item bufnr is invalid", "ErrorMsg" } }, true, { err = true })
        return
    end

    local dest_buftype = item.type == "\1" and "help" or "" --- @type string
    --- @type boolean, integer|nil
    local ok, dest_win = get_dest_win(list_win, dest_buftype, item.bufnr)
    if not ok then return end
    if not dest_win then
        -- TODO: This needs to be a split. Branch off into that logic
        vim.api.nvim_echo({ { "No available dest win. Needs to be a split", "" } }, false, {})
        return
    end

    local loclist_origin_win = (is_loclist and src_win)
            and eu._find_loclist_origin(src_win, { all_tabpages = true })
        or nil --- @type integer|nil

    et._set_list(src_win, { nr = 0, idx = line, user_data = { action = "replace" } })
    local goto_win = finish == "closeList" or finish == "focusWin"
    eu._open_item_to_win(item, { buftype = dest_buftype, goto_win = goto_win, win = dest_win })

    local is_orphan = is_loclist and not loclist_origin_win --- @type boolean
    if (not is_orphan) and finish == "closeList" then eo._close_win_save_views(list_win) end
    if finish ~= "focusList" then vim.api.nvim_set_current_win(dest_win) end

    if is_orphan then handle_orphan(list_win, dest_win, finish) end
end

vim.keymap.set("n", "o", function()
    qf_direct_open("focusWin")
end, { buffer = true })
vim.keymap.set("n", "O", function()
    qf_direct_open("closeList")
end, { buffer = true })
vim.keymap.set("n", "<C-o>", function()
    qf_direct_open("focusList")
end, { buffer = true })

------------------------------
-- Qf Open to Split Helpers --
------------------------------

--- @param list_win integer
--- @param dest_win integer
--- @param finish string
--- @return nil
local function qf_split_orphan_wrapup(list_win, dest_win, finish)
    if vim.g.qf_rancher_debug_assertions then
        local dest_valid = function()
            return vim.api.nvim_win_is_valid(dest_win)
        end
        vim.validate("dest_win", dest_win, dest_valid)
        vim.validate("finish", finish, "string")
        local list_valid = function()
            return vim.api.nvim_win_is_valid(list_win)
        end
        vim.validate("list_win", list_win, list_valid)
        local list_wintype = vim.fn.win_gettype(list_win)
        vim.validate("list_win", list_win, function()
            return list_wintype == "quickfix"
        end)
    end

    local loclist_data, cur_stack_nr = get_loclist_data(list_win)
    set_loclist_data(cur_stack_nr, dest_win, loclist_data)

    eo._close_win_save_views(list_win)

    if finish ~= "closeList" then
        local open_opts = finish == "focusWin" and { keep_win = true } or nil
        eo._open_loclist(open_opts)
    end

    local zz_cmd = { cmd = "normal", args = { "zz" }, bang = true }
    local zz = function()
        vim.api.nvim_cmd(zz_cmd, {})
    end
    vim.api.nvim_win_call(dest_win, zz)
end

--- @param list_winnr integer
--- @param total_winnr integer
--- @return integer|nil
--- Emulation of source fallback for qflist/loclist search
--- Assumes proper tab context
local function qf_iter_winnr(list_winnr, total_winnr)
    if vim.g.qf_rancher_debug_assertions then
        vim.validate("list_winnr", list_winnr, "number")
        vim.validate("total_winnr", total_winnr, "number")
        --- TODO: Not sure this is right because of differing window context. Maybe just win_call
        --- on winnr? Unsure
        vim.validate("total_winnr", total_winnr, function()
            return total_winnr <= vim.fn.winnr("$")
        end)
    end

    local other_winnr = list_winnr --- @type integer

    for _ = 1, 100 do
        other_winnr = other_winnr - 1

        if other_winnr <= 0 then other_winnr = total_winnr end

        if other_winnr == list_winnr then return nil end

        local win = vim.fn.win_getid(other_winnr) --- @type integer
        local buf = vim.api.nvim_win_get_buf(win) --- @type integer
        local buftype = vim.api.nvim_get_option_value("buftype", { buf = buf }) --- @type string

        if buftype == "" then return win end
    end

    return nil
end

--- @param list_win integer
--- @return integer|nil
local function qf_find_alt_win(list_win)
    if vim.g.qf_rancher_debug_assertions then
        vim.validate("list_win", list_win, function()
            return vim.api.nvim_win_is_valid(list_win)
        end)

        vim.validate("list_win", list_win, function()
            return vim.api.nvim_get_current_win() == list_win
        end)

        local list_wintype = vim.fn.win_gettype(list_win)
        vim.validate("list_win", list_win, function()
            return list_wintype == "quickfix"
        end)
    end

    local alt_winnr = vim.api.nvim_win_call(list_win, function()
        return vim.fn.winnr("#")
    end)

    local alt_win = vim.fn.win_getid(alt_winnr) --- @type integer
    if alt_win == list_win then return nil end

    local buf = vim.api.nvim_win_get_buf(alt_win) --- @type integer
    local buftype = vim.api.nvim_get_option_value("buftype", { buf = buf }) --- @type string

    return buftype == "" and alt_win or nil
end
--
--- @param list_winnr integer
--- @param total_winnr integer
--- @param bufnr integer
--- @param usetab boolean
--- @return integer|nil
--- Emulation of built-in qf logic
--- Assumes proper tab context
local function qf_find_matching_buf(list_winnr, total_winnr, bufnr, usetab)
    if vim.g.qf_rancher_debug_assertions then
        vim.validate("list_winnr", list_winnr, "number")

        vim.validate("total_winnr", total_winnr, "number")
        vim.validate("total_winnr", total_winnr, function()
            return total_winnr <= vim.fn.winnr("$")
        end)

        vim.validate("bufnr", bufnr, function()
            return vim.api.nvim_buf_is_valid(bufnr)
        end)

        vim.validate("usetab", usetab, "boolean")
    end

    -- Iterate through winnrs the way FOR_ALL_WINDOWS_IN_TAB does
    for i = 1, total_winnr do
        if i ~= list_winnr then
            local win = vim.fn.win_getid(i) --- @type integer
            local win_buf = vim.api.nvim_win_get_buf(win) --- @type integer
            if win_buf == bufnr then return win end
        end
    end

    if not usetab then return nil end

    local cur_tab = vim.api.nvim_get_current_tabpage() --- @type integer
    for _, tab in ipairs(vim.api.nvim_list_tabpages()) do
        if tab ~= cur_tab then
            for _, win in ipairs(vim.api.nvim_tabpage_list_wins(tab)) do
                local win_buf = vim.api.nvim_win_get_buf(win) --- @type integer
                if win_buf == bufnr then return win end
            end
        end
    end

    return nil
end
--
--- @param total_winnr integer
--- @return integer|nil
--- Assumes Neovim is in the proper tab context
local function find_help_win(total_winnr)
    if vim.g.qf_rancher_debug_assertions then
        vim.validate("total_winnr", total_winnr, "number")
        vim.validate("total_winnr", total_winnr, function()
            return total_winnr <= vim.fn.winnr("$")
        end)
    end

    for i = 1, total_winnr do
        local win = vim.fn.win_getid(i) --- @type integer
        local buf = vim.api.nvim_win_get_buf(win) --- @type integer
        local buftype = vim.api.nvim_get_option_value("buftype", { buf = buf }) --- @type string

        if buftype == "help" then return win end
    end

    return nil
end

--- @param list_qf_id integer
--- @param list_win integer
--- @param total_winnr integer
--- @param entry table
--- @return integer|nil, boolean
local function qf_get_next_win_loclist(list_qf_id, list_win, total_winnr, entry)
    if vim.g.qf_rancher_debug_assertions then
        vim.validate("list_qf_id", list_qf_id, "number")
        vim.validate("list_qf_id", list_qf_id, function()
            return list_qf_id > 0
        end)

        vim.validate("list_win", list_win, "number")
        vim.validate("list_win", list_win, function()
            return vim.api.nvim_win_is_valid(list_win)
        end)

        vim.validate("total_winnr", total_winnr, "number")
        vim.validate("total_winnr", total_winnr, function()
            return total_winnr <= vim.fn.winnr("$")
        end)

        vim.validate("entry", entry, "table")
    end

    --- @type integer
    local list_winnr = vim.api.nvim_win_call(list_win, function()
        return vim.fn.winnr()
    end)

    local loclist_win = find_loclist_win(list_qf_id, list_win) --- @type integer|nil, boolean

    if entry.type == "\1" then
        local help_win = find_help_win(total_winnr)
        return help_win, (loclist_win and false or true)
    end

    if loclist_win then return loclist_win, false end

    -- loclist searches do not check any switchbuf properties
    --- @type integer|nil
    local win = qf_find_matching_buf(list_winnr, total_winnr, entry.bufnr, false)
    if win then return win, true end

    return qf_iter_winnr(list_winnr, total_winnr), true
end

--- @param list_win integer
--- @param total_winnr integer
--- @param entry table
--- @return integer|nil
local function qf_get_next_win(list_win, total_winnr, entry)
    if vim.g.qf_rancher_debug_assertions then
        vim.validate("list_win", list_win, "number")
        local list_valid = function()
            return vim.api.nvim_win_is_valid(list_win)
        end
        vim.validate("list_win", list_win, list_valid)
        vim.validate("total_winnr", total_winnr, "number")
        local total_valid = function()
            return total_winnr <= vim.fn.winnr("$")
        end
        vim.validate("total_winnr", total_winnr, total_valid)
        vim.validate("entry", entry, "table")
    end

    --- @type integer
    local list_winnr = vim.api.nvim_win_call(list_win, function()
        return vim.fn.winnr()
    end)

    if entry.type == "\1" then return find_help_win(total_winnr) end

    --- @type string
    local switchbuf = vim.api.nvim_get_option_value("switchbuf", { scope = "global" })
    local usetab = string.match(switchbuf, "usetab") or false --- @type boolean

    --- @type integer|nil
    local win = qf_find_matching_buf(list_winnr, total_winnr, entry.bufnr, usetab)
    if win then return win end

    local uselast = string.match(switchbuf, "uselast") or usetab --- @type boolean
    local alt_win = uselast and qf_find_alt_win(list_win) or nil --- @type integer|nil
    if alt_win then return alt_win end

    return qf_iter_winnr(list_winnr, total_winnr)
end

local function validate_qf_split_full_ctx(ctx)
    vim.validate("ctx.buf_source", ctx.buf_source, "table")

    vim.validate("ctx.buf_opts", ctx.buf_opts, "table")

    vim.validate("ctx.is_loclist", ctx.is_loclist, "boolean")

    vim.validate("ctx.is_orphan_loclist", ctx.is_orphan_loclist, "boolean")

    local valid_win = function()
        return vim.api.nvim_win_is_valid(ctx.list_win)
    end
    vim.validate("ctx.list_win", ctx.list_win, valid_win)
    local list_buf = vim.api.nvim_win_get_buf(ctx.list_win)
    local list_buftype = vim.api.nvim_get_option_value("buftype", { buf = list_buf })
    vim.validate("list_buftype", list_buftype, function()
        return list_buftype == "quickfix"
    end)
    local list_wintype = vim.fn.win_gettype(ctx.list_win)
    local valid_wintype = not (list_wintype == "quickfix" and ctx.is_orphan_loclist)

    vim.validate("ctx.list_win", ctx.list_win, function()
        return valid_wintype
    end)

    vim.validate("open", ctx.open, "string")
    local is_open_split = function()
        return ctx.open == "split" or ctx.open == "vsplit"
    end
    vim.validate("open", ctx.open, is_open_split)

    vim.validate("finish", ctx.finish, "string")
end

--- @param ctx QfOpenSplitFullCtx
--- @return nil
local function qf_split_full(ctx)
    if vim.g.qf_rancher_debug_assertions then
        assert(vim.fn.winnr("$") > 1)
        validate_qf_split_full_ctx(ctx)
    end

    --- @type string
    local cmd = ctx.open == "vsplit" and "vnew" or "new" --- @type string
    local split_type = cmd == "vnew" and "splitright" or "splitbelow" --- @type string
    local split = vim.api.nvim_get_option_value(split_type, { scope = "global" }) --- @type boolean
    local mods = { split = (split and "botright" or "topleft") } --- @type {split:string}
    -- FUTURE: This should use the API. Would give more control over window scope as well
    vim.api.nvim_cmd({ cmd = cmd, mods = mods }, {})
    local dest_win = vim.api.nvim_get_current_win()

    -- TODO: Need a rancher version of this
    require("mjm.utils").open_buf(ctx.buf_source, ctx.buf_opts)

    if ctx.is_orphan_loclist then
        local loclist_data, cur_stack_nr = get_loclist_data(ctx.list_win)
        set_loclist_data(cur_stack_nr, dest_win, loclist_data)
    end

    -- By default, if a valid window cannot be found for an enter open, it will open directly
    -- above the list. Move the list to emulate this behavior
    -- Spacing for horitzontal splits is a bit better if the close is done after splitting
    eo._close_win_save_views(ctx.list_win)

    if ctx.finish ~= "closeList" then
        local open_opts = ctx.finish == "focusWin" and { keep_win = true } or nil
        if ctx.is_loclist then
            eo._open_loclist(open_opts)
        else
            eo._open_qflist(open_opts)
        end
    end

    vim.api.nvim_win_call(dest_win, function()
        vim.api.nvim_cmd({ cmd = "normal", args = { "zz" }, bang = true }, {})
    end)
end

--- @param list_win integer
--- @param dest_win integer
--- @param finish string
--- @return nil
local function qf_split_tab_handle_orphan(list_win, dest_win, finish)
    if vim.g.qf_rancher_debug_assertions then
        vim.validate("list_win", list_win, "number")
        local valid_win = function()
            return vim.api.nvim_win_is_valid(list_win)
        end
        vim.validate("list_win", list_win, valid_win)
        vim.validate("dest_win", dest_win, "number")
        local is_cur_win = function()
            return dest_win == vim.api.nvim_get_current_win()
        end
        vim.validate("dest_win", dest_win, is_cur_win)
        vim.validate("finish", finish, "string")
    end

    local loclist_data, cur_stack_nr = get_loclist_data(list_win)
    set_loclist_data(cur_stack_nr, dest_win, loclist_data)
    eo._close_win_save_views(list_win)

    if finish ~= "closeList" then
        local open_opts = finish == "focusWin" and { keep_win = true } or nil
        eo._open_loclist(open_opts)
    end

    vim.api.nvim_win_call(dest_win, function()
        vim.api.nvim_cmd({ cmd = "normal", args = { "zz" }, bang = true }, {})
    end)
end

--- @param buf_source table
--- @param buf_opts table
--- @param list_win integer
--- @param finish string
--- @param qf_id integer
--- @param is_loclist boolean
--- @return nil
local function validate_qf_split_tab(buf_source, buf_opts, list_win, finish, qf_id, is_loclist)
    vim.validate("buf_source", buf_source, "table")

    vim.validate("buf_opts", buf_opts, "table")

    vim.validate("list_win", list_win, "number")
    local is_cur_win = function()
        return list_win == vim.api.nvim_get_current_win()
    end
    vim.validate("dest_win", list_win, is_cur_win)

    vim.validate("finish", finish, "string")

    vim.validate("qf_id", qf_id, "number")

    vim.validate("is_loclist", is_loclist, "boolean")
end

--- @param buf_source table
--- @param buf_opts table
--- @param list_win integer
--- @param finish string
--- @param qf_id integer
--- @param is_loclist boolean
--- @return nil
local function qf_split_tab(buf_source, buf_opts, list_win, finish, qf_id, is_loclist)
    if vim.g.qf_rancher_debug_assertions then
        validate_qf_split_tab(buf_source, buf_opts, list_win, finish, qf_id, is_loclist)
    end

    local loclist_win = is_loclist and find_loclist_win(qf_id, list_win) or nil

    local range = (function()
        local tab_count = vim.fn.tabpagenr("$")

        if vim.v.count > 0 then
            return math.min(vim.v.count, tab_count)
        else
            return tab_count
        end
    end)()

    vim.api.nvim_cmd({ cmd = "tabnew", range = { range } }, {})
    local dest_win = vim.api.nvim_get_current_win()
    -- TODO: need a rancher version of this
    require("mjm.utils").open_buf(buf_source, buf_opts)

    if (not loclist_win) and is_loclist then
        qf_split_tab_handle_orphan(list_win, dest_win, finish)
        return
    end

    if finish == "focusList" then vim.api.nvim_set_current_win(list_win) end

    if finish == "closeList" then eo._close_win_save_views(list_win) end

    vim.api.nvim_win_call(dest_win, function()
        vim.api.nvim_cmd({ cmd = "normal", args = { "zz" }, bang = true }, {})
    end)
end

--- @param list_win integer
--- @param open QfOpenMethod
--- @param finish QfRancherFinishMethod
--- @return nil
local function qf_split_single_win(list_win, open, finish)
    if vim.g.qf_rancher_debug_assertions then
        assert(vim.fn.winnr("$") == 1)
        local list_valid = function()
            return vim.api.nvim_win_is_valid(list_win)
        end
        vim.validate("list_win", list_win, list_valid)
        local is_cur_list_win = function()
            return vim.api.nvim_get_current_win() == list_win
        end
        vim.validate("list_win", list_win, is_cur_list_win)
        local list_buf = vim.api.nvim_win_get_buf(list_win)
        local list_buftype = vim.api.nvim_get_option_value("buftype", { buf = list_buf })
        vim.validate("list_win", list_win, function()
            return list_buftype == "quickfix"
        end)
        vim.validate("open", open, "string")
        vim.validate("open", open, function()
            return open ~= "tabnew"
        end)
        vim.validate("finish", finish, "string")
    end

    vim.api.nvim_cmd({ cmd = "normal", args = { "\r" }, bang = true }, {})
    local dest_win = vim.api.nvim_get_current_win()

    -- Ignore splitbelow here. The new window should not open below the list
    local args = (function()
        if open == "split" then return { "K" } end

        if vim.api.nvim_get_option_value("splitright", { scope = "global" }) then
            return { "L" }
        else
            return { "H" }
        end
    end)() --- @type string[]

    vim.api.nvim_cmd({ cmd = "wincmd", args = args }, {})

    if finish == "closeList" then
        eo._close_win_save_views(list_win)
        return
    end

    -- if open == "split" then
    --- TODO: killed function
    -- elo._resize_list_win(list_win)
    -- end

    if finish == "focusList" then vim.api.nvim_set_current_win(list_win) end

    local zz_cmd = { cmd = "normal", args = { "zz" }, bang = true }
    vim.api.nvim_win_call(dest_win, function()
        vim.api.nvim_cmd(zz_cmd, {})
    end)
end

--- @param list_win integer
--- @param open string
--- @param finish string
--- @return boolean,[string, string]|nil
local function validate_qf_open(list_win, open, finish)
    local list_buf = vim.api.nvim_win_get_buf(list_win) --- @type integer
    --- @type string
    local list_buftype = vim.api.nvim_get_option_value("buftype", { buf = list_buf })
    if list_buftype ~= "quickfix" then
        --- @type [string, string]
        local chunk = { "list_win buftype " .. list_buftype .. " is not quickfix", "ErrorMsg" }
        return false, chunk
    end

    local valid_open = open == "vsplit" or open == "split" or open == "tabnew" --- @type boolean
    if not valid_open then
        --- @type [string, string]
        local chunk = { "Invalid open type " .. open .. " in validate_qf_open", "ErrorMsg" }
        return false, chunk
    end

    --- @type boolean
    local valid_close = finish == "focusWin" or finish == "closeList" or finish == "focusList"
    if not valid_close then
        --- @type [string, string]
        local chunk = { "Invalid close type " .. finish .. " in validate_qf_open", "ErrorMsg" }
        return false, chunk
    end

    return true, nil
end

local function qf_split(open, finish)
    local list_win = vim.api.nvim_get_current_win()

    if vim.g.qf_rancher_debug_assertions then
        --- @type boolean, [string, string]|nil
        local ok, err_chunk = validate_qf_open(list_win, open, finish)
        if not ok then
            local msg = err_chunk or { "Unknown error in validate_qf_open", "ErrorMsg" }
            vim.api.nvim_echo({ msg }, true, { err = true })
            return
        end
    end

    local qf_id = vim.fn.getloclist(list_win, { id = 0 }).id --- @type integer
    local is_loclist = qf_id ~= 0 --- @type boolean

    local list_size = (function()
        if is_loclist then
            return vim.fn.getloclist(list_win, { size = true }).size
        else
            return vim.fn.getqflist({ size = true }).size
        end
    end)() --- @type integer

    if (not list_size) or list_size == 0 then
        vim.api.nvim_echo({ { "No list entries", "" } }, false, {})
        return
    end

    local total_winnr = vim.fn.winnr("$") --- @type integer
    if total_winnr <= 1 and open ~= "tabnew" then
        qf_split_single_win(list_win, open, finish)
        return
    end

    --- @type boolean, table|string, integer
    local ok_e, entry, idx = get_entry_on_cursor(list_win, is_loclist)
    if (not ok_e) or type(entry) ~= "table" then
        entry = type(entry) == "string" and entry or "Unknown error getting list entry"
        local hl = idx == 1 and "ErrorMsg" or ""
        vim.api.nvim_echo({ { entry, hl } }, false, { err = true })
        return
    end

    --- @type mjm.OpenBufSource, mjm.OpenBufOpts
    local buf_source, buf_opts = qf_get_open_buf_opts(entry)
    entry.bufnr = buf_source.bufnr
    if is_loclist then
        vim.fn.setloclist(list_win, {}, "r", { idx = idx })
    else
        vim.fn.setqflist({}, "r", { idx = idx })
    end

    if open == "tabnew" then
        qf_split_tab(buf_source, buf_opts, list_win, finish, qf_id, is_loclist)
        return
    end

    local split_win, is_orphan_loclist = (function()
        if vim.v.count > 0 then
            if total_winnr <= 1 then return nil, false end

            local dest_winnr = math.min(vim.v.count, total_winnr)
            local wintype = vim.fn.win_gettype(dest_winnr)

            local loclist_win = is_loclist and find_loclist_win(qf_id, list_win) or nil

            local win = wintype == "" and vim.fn.win_getid(dest_winnr) or nil
            local orphan = loclist_win and false or true

            return win, orphan
        end

        if is_loclist then
            return qf_get_next_win_loclist(qf_id, list_win, total_winnr, entry)
        else
            return qf_get_next_win(list_win, total_winnr, entry)
        end
    end)()

    if not split_win then
        if vim.v.count > 0 then return end

        qf_split_full({
            list_win = list_win,
            buf_source = buf_source,
            buf_opts = buf_opts,
            is_loclist = is_loclist,
            is_orphan_loclist = (is_orphan_loclist or false),
            open = open,
            finish = finish,
        })

        return
    end

    vim.api.nvim_set_current_win(split_win)
    -- FUTURE: This should use the API. Would give more control over window scope as well
    vim.api.nvim_cmd({ cmd = open }, {})
    local dest_win = vim.api.nvim_get_current_win()

    -- TODO: Need a rancher version of this
    require("mjm.utils").open_buf(buf_source, buf_opts)

    if is_loclist and is_orphan_loclist then
        qf_split_orphan_wrapup(list_win, dest_win, finish)
        return
    end

    if finish == "focusList" then vim.api.nvim_set_current_win(list_win) end

    if finish == "closeList" then eo._close_win_save_views(list_win) end

    local zz_cmd = { cmd = "normal", args = { "zz" }, bang = true }
    vim.api.nvim_win_call(dest_win, function()
        vim.api.nvim_cmd(zz_cmd, {})
    end)
end

Map("n", "s", function()
    qf_split("split", "focusWin")
end, { buffer = true })

Map("n", "S", function()
    qf_split("split", "closeList")
end, { buffer = true })

Map("n", "<C-s>", function()
    qf_split("split", "focusList")
end, { buffer = true })

Map("n", "v", function()
    qf_split("vsplit", "focusWin")
end, { buffer = true })

Map("n", "V", function()
    qf_split("vsplit", "closeList")
end, { buffer = true })

Map("n", "<C-v>", function()
    qf_split("vsplit", "focusList")
end, { buffer = true })

Map("n", "x", function()
    qf_split("tabnew", "focusWin")
end, { buffer = true })

Map("n", "X", function()
    qf_split("tabnew", "closeList")
end, { buffer = true })

Map("n", "<C-x>", function()
    qf_split("tabnew", "focusList")
end, { buffer = true })

------------
--- TODO ---
------------

--- Make plug maps for everything
--- These cmds need to create jumplist entries. How does FzfLua do it?
--- Create plug mappings
--- These bufmappings should use nowait
---
--- Add undo_ftplugin b variable fn

-------------
--- MAYBE ---
-------------

--- For some of the context switching, eventignore could be useful. But very bad if we error
--- with that option on

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
