---------------------------
-- qf jump function list --
---------------------------

-- TODO: The ftplugin maps should be moved to their own file, and a g_variable in the plugin's
-- ftplugin file should determine if they are mapped. Put this function documentation in the
-- file to ftplugin map
-- TODO: The g variable should either map the defaults or not. Plug mappings/documentation can be
-- provided if the user wants to do it custom
-- TODO: Set nowait here and in other buffer keymaps
-- MAYBE: show stack nr in qf statusline

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

-- TODO: The various checks for this var fail if it's not set since they use API calls. I'm fine
-- with writing a protected var call, but need to look at the vim.g code to see if I'm doing
-- more silly stuff than that
-- vim.api.nvim_set_var("qf_rancher_debug_assertions", true)

-- TODO: In the Rancher ftplugin file, setting the qf options should be done under a g value
-- DOCUMENT: Which options are set
vim.api.nvim_set_option_value("buflisted", false, { buf = 0 })
vim.api.nvim_set_option_value("cc", "", { scope = "local" })
vim.api.nvim_set_option_value("list", false, { scope = "local" })
-- TODO: Restore this. Currently off for testing
-- Or maybe not. I have splits disabled, so if the qf win is the only window, we're stuck
-- vim.opt_local.winfixbuf = true

vim.keymap.set("n", "<C-w>v", "<nop>", { buffer = true })
vim.keymap.set("n", "<C-w><C-v>", "<nop>", { buffer = true })
vim.keymap.set("n", "<C-w>s", "<nop>", { buffer = true })
vim.keymap.set("n", "<C-w><C-s>", "<nop>", { buffer = true })

-- TODO: update this
Map("n", "<leader>qo", function()
    local win = vim.api.nvim_get_current_win()
    local wintype = vim.fn.win_gettype(win)
    if wintype == "quickfix" then
        require("mjm.error-list-open")._close_win_save_views(win)
    end
end, { buffer = true })

Map("n", "<leader>lo", function()
    local win = vim.api.nvim_get_current_win()
    local wintype = vim.fn.win_gettype(win)
    if wintype == "loclist" then
        require("mjm.error-list-open")._close_win_save_views(win)
    end
end, { buffer = true })

-- TODO: validation error occurs when doing this
Map("n", "q", function()
    local win = vim.api.nvim_get_current_win()
    require("mjm.error-list-open")._close_win_save_views(win)
end, { buffer = true })

-- TODO: Reset the idx value here as well
Map("n", "dd", function()
    local win = vim.api.nvim_get_current_win()
    local row, col = unpack(vim.api.nvim_win_get_cursor(win))
    local wininfo = vim.fn.getwininfo(win)[1]

    local is_loclist = wininfo.quickfix == 1 and wininfo.loclist == 1
    local list = is_loclist and vim.fn.getloclist(win) or vim.fn.getqflist()
    table.remove(list, row)

    if is_loclist then
        vim.fn.setloclist(win, list, "r")
    else
        vim.fn.setqflist(list, "r")
    end

    require("mjm.utils").protected_set_cursor({ row, col }, { set_pcmark = true, win = win })
end, { buffer = true })

--- @return Range4
--- MAYBE: Copied from the nvim-treesitter file. One dupe now. Maybe outline
local function get_vrange4()
    local cur = vim.fn.getpos(".")
    local fin = vim.fn.getpos("v")
    local mode = vim.fn.mode()

    local region = vim.fn.getregionpos(cur, fin, { type = mode, exclusive = false })
    return { region[1][1][2], region[1][1][3], region[#region][2][2], region[#region][2][3] }
end

local norm_desc = "qf-rancher enter visual mode"
vim.api.nvim_buf_set_keymap(0, "n", "i", "v", { noremap = true, desc = norm_desc })
local line_desc = "qf-rancher enter visual line mode"
vim.api.nvim_buf_set_keymap(0, "n", "I", "V", { noremap = true, desc = line_desc })
local block_desc = "qf-rancher enter visual block mode"
vim.api.nvim_buf_set_keymap(0, "n", "<C-i>", "<C-v>", { noremap = true, desc = block_desc })

Map("x", "d", function()
    local mode = string.sub(vim.api.nvim_get_mode().mode, 1, 1) ---@type string
    if mode ~= "V" then
        return
    end

    local vrange_4 = get_vrange4()
    Cmd({ cmd = "normal", args = { "\27" }, bang = true }, {})
    Cmd({ cmd = "normal", args = { vrange_4[1] .. "G" }, bang = true }, {})

    local win = vim.api.nvim_get_current_win()
    local row, col = unpack(vim.api.nvim_win_get_cursor(win))
    local win_info = vim.fn.getwininfo(win)[1]

    local is_loclist = win_info.quickfix == 1 and win_info.loclist == 1
    local list = is_loclist and vim.fn.getloclist(win) or vim.fn.getqflist()
    for i = vrange_4[3], vrange_4[1], -1 do
        table.remove(list, i)
    end

    if is_loclist then
        vim.fn.setloclist(win, list, "r")
    else
        vim.fn.setqflist(list, "r")
    end

    require("mjm.utils").protected_set_cursor({ row, col }, { set_pcmark = true, win = win })
end, { buffer = true })

vim.api.nvim_buf_set_keymap(0, "n", "p", "", {
    noremap = true,
    callback = function()
        require("mjm.error-list-preview").toggle_preview_win()
    end,
    desc = "Toggle the qf preview window",
})

vim.api.nvim_buf_set_keymap(0, "n", "P", "", {
    noremap = true,
    callback = function()
        local cur_win = vim.api.nvim_get_current_win() --- @type integer
        require("mjm.error-list-preview")._update_preview_win_pos(cur_win)
    end,
    desc = "Manually trigger a preview window position adjustment",
})

-------------
--- Types ---
-------------

--- @alias QfOpenMethod "split"|"tabnew"|"vsplit"
--- @alias QfFinishMethod "closeList"|"focusList"|"focusWin"

--- @class QfOpenSplitFullCtx
--- @field list_win integer
--- @field buf_source mjm.OpenBufSource
--- @field buf_opts mjm.OpenBufOpts
--- @field is_loclist boolean
--- @field is_orphan_loclist boolean
--- @field open QfOpenMethod
--- @field finish QfFinishMethod

---------------------
-- Qf Open Helpers --
---------------------

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
            if buftype ~= "quickfix" then
                return win
            end
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

    if not entry then
        return false, "No entry under cursor", 2
    end

    if (not entry.bufnr) and ((not entry.filename) or entry.filename == "") then
        return false, "No buffer or file data for entry", 1
    end

    return true, entry, row
end

--------------------
-- Qf Open to Win --
--------------------

--- @param dest_win integer
--- @param finish QfFinishMethod
--- @param list_win integer
--- @return nil
local function qf_open_finish(dest_win, finish, list_win)
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

    if finish == "closeList" then
        --- For loclists, specifically closing the list win is necessary because we might have
        --- opened to a window not associated with the origin loclist, meaning lclose would do
        --- nothing. This function also handles the qflist case, so no need to differentiate
        require("mjm.error-list-open")._close_win_save_views(list_win)
    end

    vim.api.nvim_win_call(dest_win, function()
        vim.api.nvim_cmd({ cmd = "normal", args = { "zz" }, bang = true }, {})
    end)

    if finish == "focusList" then
        vim.api.nvim_set_current_win(list_win)
    end
end

--- @param dest_win integer
--- @param finish QfFinishMethod
--- @return nil
local function qf_open_handle_loclist(dest_win, list_win, list_qf_id, finish)
    if vim.g.qf_rancher_debug_assertions then
        local dest_valid = function()
            return vim.api.nvim_win_is_valid(dest_win)
        end
        vim.validate("dest_win", dest_win, dest_valid)
        local is_cur_dest_win = function()
            return vim.api.nvim_get_current_win() == dest_win
        end
        vim.validate("dest_win", dest_win, is_cur_dest_win)
        vim.validate("list_qf_id", list_qf_id, "number")
        vim.validate("list_qf_id", list_qf_id, function()
            return list_qf_id > 0
        end)
        local list_valid = function()
            return vim.api.nvim_win_is_valid(list_win)
        end
        vim.validate("list_win", list_win, list_valid)
        local list_wintype = vim.fn.win_gettype(list_win)
        vim.validate("list_win", list_win, function()
            return list_wintype == "quickfix"
        end)
        vim.validate("finish", finish, "string")
    end

    local dest_qf_id = vim.fn.getloclist(dest_win, { id = 0 }).id --- @type integer
    if dest_qf_id ~= 0 then
        -- New window can't adopt an orphan qf list
        qf_open_finish(dest_win, finish, list_win)
        return
    end

    if find_loclist_win(list_qf_id, list_win) then
        -- No orphan loclist
        qf_open_finish(dest_win, finish, list_win)
        return
    end

    --- @type table, integer
    local loclist_data, qf_stack_nr = get_loclist_data(list_win)
    local elo = require("mjm.error-list-open")
    elo._close_win_save_views(list_win)
    set_loclist_data(qf_stack_nr, dest_win, loclist_data)

    if finish == "focusList" then
        elo._open_loclist()
    elseif finish == "focusWin" then
        elo._open_loclist({ keep_win = true })
    end

    --- @diagnostic disable: missing-fields
    --- @type vim.api.keyset.cmd
    local zz_cmd = { cmd = "normal", args = { "zz" }, bang = true }
    local zz = function()
        vim.api.nvim_cmd(zz_cmd, {})
    end
    vim.api.nvim_win_call(dest_win, zz)
end

-- Because the built-in "\r" functionality was used to go to the loclist entry, the orphaned
-- loclist will be re-bound internally to the new window. Still close and re-open the loclist so
-- it will be visually aligned with its new home win, but no manual bookkeeping is necessary
--- @param dest_win integer
--- @return nil
local function qf_open_default_dest_orphan_loclist(dest_win, finish)
    if vim.g.qf_rancher_debug_assertions then
        local dest_valid = function()
            return vim.api.nvim_win_is_valid(dest_win)
        end
        vim.validate("dest_win", dest_win, dest_valid)
        local is_cur_dest_win = function()
            return vim.api.nvim_get_current_win() == dest_win
        end
        vim.validate("dest_win", dest_win, is_cur_dest_win)
    end

    local elo = require("mjm.error-list-open")
    elo._close_loclist()

    if finish ~= "closeList" then
        elo._open_loclist()
    end
    if finish == "focusWin" then
        vim.api.nvim_set_current_win(dest_win)
    end

    local zz_cmd = { cmd = "normal", args = { "zz" }, bang = true }
    local zz = function()
        vim.api.nvim_cmd(zz_cmd, {})
    end
    vim.api.nvim_win_call(dest_win, zz)
end

--- @param finish QfFinishMethod
--- @param list_win integer
--- @return nil
local function qf_open_default_dest(list_win, finish)
    if vim.g.qf_rancher_debug_assertions then
        vim.validate("finish", finish, "string")
        local list_valid = function()
            return vim.api.nvim_win_is_valid(list_win)
        end
        vim.validate("list_win", list_win, list_valid)
        local is_cur_list_win = function()
            return vim.api.nvim_get_current_win() == list_win
        end
        vim.validate("list_win", list_win, is_cur_list_win)
        local list_wintype = vim.fn.win_gettype(list_win)
        vim.validate("list_win", list_win, function()
            return list_wintype == "quickfix" or list_wintype == "loclist"
        end)
    end

    local list_qf_id = vim.fn.getloclist(list_win, { id = 0 }).id --- @type integer
    local is_loclist = list_qf_id > 0

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

    local is_orphan_loclist = is_loclist and (not find_loclist_win(list_qf_id, list_win)) or false
    local total_winnr_pre = vim.fn.winnr("$")

    vim.api.nvim_cmd({ cmd = "normal", args = { "\r" }, bang = true }, {})

    local dest_win = vim.api.nvim_get_current_win()
    local dest_qf_id = vim.fn.getloclist(dest_win, { id = 0 }).id

    if is_orphan_loclist and dest_qf_id == list_qf_id then
        qf_open_default_dest_orphan_loclist(dest_win, finish)
        return
    end

    local elo = require("mjm.error-list-open")
    if finish == "closeList" then
        elo._close_win_save_views(list_win)
    elseif total_winnr_pre == 1 then
        --- Killed function
        -- elo._resize_list_win(list_win)
    end

    if finish == "focusList" then
        vim.api.nvim_set_current_win(list_win)
    end

    local zz_cmd = { cmd = "normal", args = { "zz" }, bang = true }
    local zz = function()
        vim.api.nvim_cmd(zz_cmd, {})
    end
    vim.api.nvim_win_call(dest_win, zz)
end

--- @param finish QfFinishMethod
--- @return nil
local function qf_direct_open(finish)
    if vim.g.qf_rancher_debug_assertions then
        vim.validate("finish", finish, "string")
    end

    local list_win = vim.api.nvim_get_current_win() --- @type integer
    local list_buf = vim.api.nvim_win_get_buf(list_win) --- @type integer
    --- @type string
    local list_buftype = vim.api.nvim_get_option_value("buftype", { buf = list_buf })
    if list_buftype ~= "quickfix" then
        return
    end

    if vim.v.count < 1 then
        qf_open_default_dest(list_win, finish)
        return
    end

    local total_winnr = vim.fn.winnr("$") --- @type integer
    local dest_winnr = math.min(vim.v.count1, total_winnr) --- @type integer

    local dest_wintype = vim.fn.win_gettype(dest_winnr) --- @type string
    if dest_wintype ~= "" then
        vim.api.nvim_echo({ { "Destination win type not empty", "" } }, false, {})
        return
    end

    local dest_win = vim.fn.win_getid(dest_winnr) --- @type integer
    local dest_buf = vim.api.nvim_win_get_buf(dest_win) --- @type integer
    --- @type string
    local dest_buftype = vim.api.nvim_get_option_value("buftype", { buf = dest_buf })
    if dest_buftype ~= "" then
        vim.api.nvim_echo({ { "Destination buftype not empty", "" } }, false, {})
        return
    end

    local list_qf_id = vim.fn.getloclist(list_win, { id = 0 }).id --- @type integer
    local is_loclist = list_qf_id ~= 0 --- @type boolean

    --- @type boolean, table|string, integer
    local ok, entry, idx = get_entry_on_cursor(list_win, is_loclist)
    if (not ok) or type(entry) ~= "table" then
        entry = type(entry) == "string" and entry or "Unknown error getting list entry"
        local hl = idx == 1 and "ErrorMsg" or ""
        vim.api.nvim_echo({ { entry, hl } }, false, { err = true })
        return
    end

    --- @type mjm.OpenBufSource, mjm.OpenBufOpts
    local buf_source, buf_opts = qf_get_open_buf_opts(entry)
    if is_loclist then
        vim.fn.setloclist(list_win, {}, "r", { idx = idx })
    else
        vim.fn.setqflist({}, "r", { idx = idx })
    end

    vim.api.nvim_set_current_win(dest_win)
    if not require("mjm.utils").open_buf(buf_source, buf_opts) then
        return
    end

    if is_loclist then
        qf_open_handle_loclist(dest_win, list_win, list_qf_id, finish)
    else
        qf_open_finish(dest_win, finish, list_win)
    end
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

    local elo = require("mjm.error-list-open")
    elo._close_win_save_views(list_win)

    if finish ~= "closeList" then
        local open_opts = finish == "focusWin" and { keep_win = true } or nil
        elo._open_loclist(open_opts)
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

        if other_winnr <= 0 then
            other_winnr = total_winnr
        end

        if other_winnr == list_winnr then
            return nil
        end

        local win = vim.fn.win_getid(other_winnr) --- @type integer
        local buf = vim.api.nvim_win_get_buf(win) --- @type integer
        local buftype = vim.api.nvim_get_option_value("buftype", { buf = buf }) --- @type string

        if buftype == "" then
            return win
        end
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
    if alt_win == list_win then
        return nil
    end

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
            if win_buf == bufnr then
                return win
            end
        end
    end

    if not usetab then
        return nil
    end

    local cur_tab = vim.api.nvim_get_current_tabpage() --- @type integer
    for _, tab in ipairs(vim.api.nvim_list_tabpages()) do
        if tab ~= cur_tab then
            for _, win in ipairs(vim.api.nvim_tabpage_list_wins(tab)) do
                local win_buf = vim.api.nvim_win_get_buf(win) --- @type integer
                if win_buf == bufnr then
                    return win
                end
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

        if buftype == "help" then
            return win
        end
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

    if loclist_win then
        return loclist_win, false
    end

    -- loclist searches do not check any switchbuf properties
    --- @type integer|nil
    local win = qf_find_matching_buf(list_winnr, total_winnr, entry.bufnr, false)
    if win then
        return win, true
    end

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

    if entry.type == "\1" then
        return find_help_win(total_winnr)
    end

    --- @type string
    local switchbuf = vim.api.nvim_get_option_value("switchbuf", { scope = "global" })
    local usetab = string.match(switchbuf, "usetab") or false --- @type boolean

    --- @type integer|nil
    local win = qf_find_matching_buf(list_winnr, total_winnr, entry.bufnr, usetab)
    if win then
        return win
    end

    local uselast = string.match(switchbuf, "uselast") or usetab --- @type boolean
    local alt_win = uselast and qf_find_alt_win(list_win) or nil --- @type integer|nil
    if alt_win then
        return alt_win
    end

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

    require("mjm.utils").open_buf(ctx.buf_source, ctx.buf_opts)

    if ctx.is_orphan_loclist then
        local loclist_data, cur_stack_nr = get_loclist_data(ctx.list_win)
        set_loclist_data(cur_stack_nr, dest_win, loclist_data)
    end

    -- By default, if a valid window cannot be found for an enter open, it will open directly
    -- above the list. Move the list to emulate this behavior
    -- Spacing for horitzontal splits is a bit better if the close is done after splitting
    local elo = require("mjm.error-list-open")
    elo._close_win_save_views(ctx.list_win)

    if ctx.finish ~= "closeList" then
        local open_opts = ctx.finish == "focusWin" and { keep_win = true } or nil
        if ctx.is_loclist then
            elo._open_loclist(open_opts)
        else
            elo._open_qflist(open_opts)
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

    local elo = require("mjm.error-list-open")

    local loclist_data, cur_stack_nr = get_loclist_data(list_win)
    set_loclist_data(cur_stack_nr, dest_win, loclist_data)
    elo._close_win_save_views(list_win)

    if finish ~= "closeList" then
        local open_opts = finish == "focusWin" and { keep_win = true } or nil
        elo._open_loclist(open_opts)
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
    require("mjm.utils").open_buf(buf_source, buf_opts)

    if (not loclist_win) and is_loclist then
        qf_split_tab_handle_orphan(list_win, dest_win, finish)
        return
    end

    if finish == "focusList" then
        vim.api.nvim_set_current_win(list_win)
    end

    if finish == "closeList" then
        require("mjm.error-list-open")._close_win_save_views(list_win)
    end

    vim.api.nvim_win_call(dest_win, function()
        vim.api.nvim_cmd({ cmd = "normal", args = { "zz" }, bang = true }, {})
    end)
end

--- @param list_win integer
--- @param open QfOpenMethod
--- @param finish QfFinishMethod
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
        if open == "split" then
            return { "K" }
        end

        if vim.api.nvim_get_option_value("splitright", { scope = "global" }) then
            return { "L" }
        else
            return { "H" }
        end
    end)() --- @type string[]

    vim.api.nvim_cmd({ cmd = "wincmd", args = args }, {})

    local elo = require("mjm.error-list-open")
    if finish == "closeList" then
        elo._close_win_save_views(list_win)
        return
    end

    -- if open == "split" then
    --- TODO: killed function
    -- elo._resize_list_win(list_win)
    -- end

    if finish == "focusList" then
        vim.api.nvim_set_current_win(list_win)
    end

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
            if total_winnr <= 1 then
                return nil, false
            end

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
        if vim.v.count > 0 then
            return
        end

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

    require("mjm.utils").open_buf(buf_source, buf_opts)

    if is_loclist and is_orphan_loclist then
        qf_split_orphan_wrapup(list_win, dest_win, finish)
        return
    end

    if finish == "focusList" then
        vim.api.nvim_set_current_win(list_win)
    end

    if finish == "closeList" then
        require("mjm.error-list-open")._close_win_save_views(list_win)
    end

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

--- These cmds need to create jumplist entries. How does FzfLua do it?
