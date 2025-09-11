vim.api.nvim_set_option_value("buflisted", false, { buf = 0 })

vim.opt_local.colorcolumn = ""
vim.opt_local.list = false

Map("n", "<leader>q", function()
    local win = vim.api.nvim_get_current_win()
    local wintype = vim.fn.win_gettype(win)
    if wintype == "quickfix" then require("mjm.error-list").close_win_restview(win) end
end, { buffer = true })

Map("n", "<leader>l", function()
    local win = vim.api.nvim_get_current_win()
    local wintype = vim.fn.win_gettype(win)
    if wintype == "loclist" then require("mjm.error-list").close_win_restview(win) end
end, { buffer = true })

Map("n", "q", function()
    local win = vim.api.nvim_get_current_win()
    require("mjm.error-list").close_win_restview(win)
end, { buffer = true })

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

-- MAYBE: Copied from the nvim-treesitter file. One dupe now. Maybe outline
local function get_vrange4()
    local cur = vim.fn.getpos(".")
    local fin = vim.fn.getpos("v")
    local mode = vim.fn.mode()

    local region = vim.fn.getregionpos(cur, fin, { type = mode, exclusive = false })
    return { region[1][1][2], region[1][1][3], region[#region][2][2], region[#region][2][3] }
end

-- TODO: Not sure what the right map for visual mode here is
Map("x", "d", function()
    local mode = string.sub(vim.api.nvim_get_mode().mode, 1, 1) ---@type string
    if mode ~= "V" then return end

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

-- TODO: Need to figure out issue with s being mapped to substitute in here. Causes conflict with
-- split mapping

local bad_maps = { "<C-o>", "<C-O>", "<C-i>", "<C-I>" }
for _, map in pairs(bad_maps) do
    Map("n", map, function() vim.notify("Currently in qf buffer") end, { buffer = true })
end

---------------------
-- Qf Open Helpers --
---------------------

--- @param ctx QfOpenCtx
--- @return nil
local function get_loclist_data(ctx)
    -- TODO: Unsure if the split functions properly save this
    assert(vim.validate("ctx", ctx, "table"))
    assert(ctx.list_win)
    assert(vim.api.nvim_win_is_valid(ctx.list_win))

    ctx = ctx or {}

    local count = vim.fn.getloclist(ctx.list_win, { nr = "$" }).nr --- @type integer
    assert(count > 0)
    ctx.cur_stack_nr = vim.fn.getloclist(ctx.list_win, { nr = 0 }).nr

    ctx.loclist_data = {}

    for i = 1, count do
        --- @type table
        local list = vim.fn.getloclist(ctx.list_win, { nr = i, all = true })
        table.insert(ctx.loclist_data, list)
    end
end

--- @param ctx QfOpenCtx
--- @return nil
local function set_loclist_data(ctx)
    assert(ctx.cur_stack_nr)
    assert(ctx.dest_win)
    assert(ctx.list_win)
    assert(vim.fn.getloclist(ctx.dest_win, { id = 0 }).id == 0)

    for _, data in ipairs(ctx.loclist_data) do
        vim.fn.setloclist(ctx.dest_win, {}, " ", data)
    end

    assert(ctx.cur_stack_nr <= vim.fn.getloclist(ctx.list_win, { nr = "$" }).nr)

    --- @diagnostic disable: missing-fields
    --- @type vim.api.keyset.cmd
    local cmd = { cmd = "lhistory", count = ctx.cur_stack_nr, mods = { silent = true } }
    vim.api.nvim_win_call(ctx.dest_win, function() vim.api.nvim_cmd(cmd, {}) end)
end

--- @param ctx QfOpenCtx
--- @return integer|nil
--- Emulation of qf_find_win_with_loclist/FOR_ALL_WINDOWS_IN_TAB
local function find_loclist_win(ctx)
    assert(vim.validate("ctx", ctx, "table"))
    assert(ctx.list_winnr)
    assert(ctx.qf_id)
    assert(ctx.total_winnr)

    ctx = ctx or {}

    for i = 1, ctx.total_winnr do
        if i ~= ctx.list_winnr then
            local win = vim.fn.win_getid(i) --- @type integer
            local qf_id = vim.fn.getloclist(win, { id = 0 }).id --- @type integer

            if qf_id == ctx.qf_id then
                local buf = vim.api.nvim_win_get_buf(win) --- @type integer
                --- @type string
                local buftype = vim.api.nvim_get_option_value("buftype", { buf = buf })
                if buftype ~= "quickfix" then return win end
            end
        end
    end

    return nil
end

--- @param ctx QfOpenCtx
--- @return nil
local function qf_get_open_buf_opts(ctx)
    ctx = ctx or {}
    assert(ctx.entry)

    local buf = ctx.entry.bufnr or vim.fn.bufadd(ctx.entry.bufname) --- @type integer
    ctx.entry.bufnr = buf
    ctx.buf_source = { bufnr = ctx.entry.bufnr }

    local buftype = ctx.entry.type == "\1" and "help" or nil --- @type string|nil
    local lnum = ctx.entry.lnum or nil --- @type integer|nil
    -- qf cols are one-indexed
    local col = math.max(ctx.entry.col - 1, 0) or nil --- @type integer|nil
    --- @type {[1]:integer, [2]: integer}|nil
    local cur_pos = (lnum and col) and { lnum, col } or nil

    ctx.buf_opts = {
        buftype = buftype,
        clearjumps = true,
        cur_pos = cur_pos,
        force = true,
        open = ctx.open == "tabnew" and ctx.open or nil,
    }
end

--- @param ctx QfOpenCtx
--- @return boolean
local function get_entry_on_cursor(ctx)
    ctx = ctx or {}
    assert(ctx.list_win)

    local row = vim.api.nvim_win_get_cursor(ctx.list_win)[1] --- @type integer
    local entry = (function()
        if ctx.is_loclist then
            return vim.fn.getloclist(ctx.list_win, { id = 0, idx = row, items = true }).items[1]
        else
            return vim.fn.getqflist({ id = 0, idx = row, items = true }).items[1]
        end
    end)() --- @type table

    if not entry then
        local msg = "No entry under cursor" --- @type string
        vim.api.nvim_echo({ { msg, "ErrorMsg" } }, true, { err = true })
        return false
    end

    if (not entry.bufnr) and ((not entry.filename) or entry.filename == "") then
        local msg = "No buffer or file data for entry" --- @type string
        vim.api.nvim_echo({ { msg, "ErrorMsg" } }, true, { err = true })
        return false
    end

    ctx.entry = entry
    ctx.idx = row

    return true
end

--------------------
-- Qf Open to Win --
--------------------

--- @param ctx QfOpenCtx
--- @param finish QfOpenFinish
--- @return nil
local function qf_open_wrapup(ctx, finish)
    assert(vim.api.nvim_get_current_win() == ctx.dest_win)

    if finish == "closeList" then
        --- For loclists, specifically closing the list win is necessary because we might have
        --- opened to a window not associated with the origin loclist, meaning lclose would do
        --- nothing. This function also handles the qflist case, so no need to differentiate
        require("mjm.error-list").close_win_restview(ctx.list_win)
    end

    vim.api.nvim_cmd({ cmd = "normal", args = { "zz" }, bang = true }, {})

    if finish == "focusList" then vim.api.nvim_set_current_win(ctx.list_win) end
end

--- @param ctx QfOpenCtx
--- @param finish QfOpenFinish
--- @return nil
local function qf_open_handle_loclist(ctx, finish)
    local dest_qf_id = vim.fn.getloclist(ctx.dest_win, { id = 0 }).id --- @type integer
    if dest_qf_id ~= 0 then
        -- New window can't adopt an orphan qf list
        qf_open_wrapup(ctx, finish)
        return
    end

    local src_loclist_win = find_loclist_win(ctx) --- @type integer|nil
    if src_loclist_win then
        -- No orphan loclist
        qf_open_wrapup(ctx, finish)
        return
    end

    get_loclist_data(ctx)

    local el = require("mjm.error-list")
    el.close_win_restview(ctx.list_win)
    set_loclist_data(ctx)

    if finish == "focusList" then
        el.open_loclist()

        vim.api.nvim_win_call(
            ctx.dest_win,
            function() vim.api.nvim_cmd({ cmd = "normal", args = { "zz" }, bang = true }, {}) end
        )
        return
    end

    if finish == "focusWin" then el.open_loclist({ keep_win = true }) end

    vim.api.nvim_cmd({ cmd = "normal", args = { "zz" }, bang = true }, {})
end

-- Because the built-in "\r" functionality was used to go to the loclist entry, the orphaned
-- loclist will be re-bound internally to the new window. Still close and re-open the loclist so
-- it will be visually aligned with its new home win, but no manual bookkeeping is necessary
local function qf_open_default_dest_orphan_loclist(finish)
    local el = require("mjm.error-list")

    if finish == "closeList" then
        el.close_loclist()
        vim.api.nvim_cmd({ cmd = "normal", args = { "zz" }, bang = true }, {})
        return
    end

    local dest_win = vim.api.nvim_get_current_win()

    el.close_loclist()
    el.open_loclist()

    vim.api.nvim_win_call(
        dest_win,
        function() vim.api.nvim_cmd({ cmd = "normal", args = { "zz" }, bang = true }, {}) end
    )

    if finish == "focusWin" then
        vim.api.nvim_set_current_win(dest_win)
        return
    end
end

--- @param ctx QfOpenCtx
--- @param finish QfOpenFinish
--- @return nil
local function qf_open_default_dest(ctx, finish)
    ctx = ctx or {}

    local is_orphan_loclist = ctx.is_loclist and (not find_loclist_win(ctx)) or false

    vim.api.nvim_cmd({ cmd = "normal", args = { "\r" }, bang = true }, {})

    local dest_win = vim.api.nvim_get_current_win()
    local dest_qf_id = vim.fn.getloclist(dest_win, { id = 0 }).id

    if is_orphan_loclist and dest_qf_id == ctx.qf_id then
        qf_open_default_dest_orphan_loclist(finish)
        return
    end

    local el = require("mjm.error-list")

    if finish == "closeList" then el.close_win_restview(ctx.list_win) end

    vim.api.nvim_cmd({ cmd = "normal", args = { "zz" }, bang = true }, {})

    if finish == "focusList" then vim.api.nvim_set_current_win(ctx.list_win) end
end

--- @alias QfOpenFinish "closeList"|"focusList"|"focusWin"

--- @param finish QfOpenFinish
--- @return nil
local function qf_direct_open(finish)
    local ctx = {} --- @type QfOpenCtx

    ctx.list_win = vim.api.nvim_get_current_win()
    ctx.list_winnr = vim.fn.winnr()
    ctx.total_winnr = vim.fn.winnr("$")

    ctx.qf_id = vim.fn.getloclist(ctx.list_win, { id = 0 }).id --- @type integer
    ctx.is_loclist = ctx.qf_id ~= 0

    if vim.v.count < 1 then
        qf_open_default_dest(ctx, finish)
        return
    end

    local dest_winnr = vim.v.count1
    dest_winnr = math.min(dest_winnr, ctx.total_winnr)

    local dest_wintype = vim.fn.win_gettype(dest_winnr)
    -- Also catches the condition of trying to goto the current qf winnr
    if dest_wintype ~= "" then return end

    ctx.dest_win = vim.fn.win_getid(dest_winnr)
    local dest_buf = vim.api.nvim_win_get_buf(ctx.dest_win)
    local dest_buftype = vim.api.nvim_get_option_value("buftype", { buf = dest_buf })
    if dest_buftype ~= "" then
        vim.api.nvim_echo({ { "Buftype not empty", "" } }, false, {})
        return
    end

    if not get_entry_on_cursor(ctx) then return end
    qf_get_open_buf_opts(ctx)

    if ctx.is_loclist then
        vim.fn.setloclist(ctx.list_win, {}, "r", { idx = ctx.idx })
    else
        vim.fn.setqflist({}, "r", { idx = ctx.idx })
    end

    vim.api.nvim_set_current_win(ctx.dest_win)
    if not require("mjm.utils").open_buf(ctx.buf_source, ctx.buf_opts) then return end

    ctx.qf_id = vim.fn.getloclist(ctx.list_win, { id = 0 }).id --- @type integer
    ctx.is_loclist = ctx.qf_id ~= 0

    if ctx.is_loclist then
        qf_open_handle_loclist(ctx, finish)
        return
    end

    qf_open_wrapup(ctx, finish)
end

vim.keymap.set("n", "o", function() qf_direct_open("focusWin") end, { buffer = true })
vim.keymap.set("n", "O", function() qf_direct_open("closeList") end, { buffer = true })
vim.keymap.set("n", "<C-o>", function() qf_direct_open("focusList") end, { buffer = true })

------------------------------
-- Qf Open to Split Helpers --
------------------------------

--- @param ctx QfOpenCtx
--- @return integer|nil
--- For loclists and qflists, this reversed, wrapping loop through winnrs is the fallback if
--- the preferred destination is not found
local function qf_iter_winnr(ctx)
    ctx = ctx or {}
    assert(ctx.list_winnr)
    assert(ctx.total_winnr)

    local other_winnr = ctx.list_winnr --- @type integer

    for _ = 1, 100 do
        other_winnr = other_winnr - 1

        if other_winnr <= 0 then other_winnr = ctx.total_winnr end
        if other_winnr == ctx.list_winnr then return nil end

        local win = vim.fn.win_getid(other_winnr) --- @type integer
        local buf = vim.api.nvim_win_get_buf(win) --- @type integer
        local buftype = vim.api.nvim_get_option_value("buftype", { buf = buf }) --- @type string

        if buftype == "" then return win end
    end

    return nil
end

--- @param ctx QfOpenCtx
--- @return integer|nil
local function qf_find_alt_win(ctx)
    ctx = ctx or {}
    assert(ctx.list_winnr)

    local alt_winnr = vim.fn.winnr("#") --- @type integer
    if alt_winnr == ctx.list_winnr then return nil end

    local alt_win = vim.fn.win_getid(alt_winnr) --- @type integer
    local buf = vim.api.nvim_win_get_buf(alt_win) --- @type integer
    local buftype = vim.api.nvim_get_option_value("buftype", { buf = buf }) --- @type string

    return buftype == "" and alt_win or nil
end

--- @param ctx QfOpenCtx
--- @return integer|nil
local function qf_find_matching_buf(ctx)
    ctx = ctx or {}

    assert(ctx.buf_source.bufnr)
    assert(ctx.total_winnr)
    assert(ctx.list_winnr)

    -- Iterate through winnrs the way FOR_ALL_WINDOWS_IN_TAB does
    for i = 1, ctx.total_winnr do
        if i ~= ctx.list_winnr then
            local win = vim.fn.win_getid(i) --- @type integer
            local win_buf = vim.api.nvim_win_get_buf(win) --- @type integer
            if win_buf == ctx.buf_source.bufnr then return win end
        end
    end

    if not ctx.usetab then return nil end

    local cur_tab = vim.api.nvim_get_current_tabpage() --- @type integer
    for _, tab in pairs(vim.api.nvim_list_tabpages()) do
        if tab ~= cur_tab then
            for _, win in pairs(vim.api.nvim_tabpage_list_wins(tab)) do
                local win_buf = vim.api.nvim_win_get_buf(win) --- @type integer
                if win_buf == ctx.buf_source.bufnr then return win end
            end
        end
    end

    return nil
end

--- @param ctx QfOpenCtx
--- @return integer|nil
local function find_help_win(ctx)
    ctx = ctx or {}

    assert(ctx.total_winnr)
    assert(ctx.list_winnr)

    -- Iterate through winnrs the way FOR_ALL_WINDOWS_IN_TAB does
    for i = 1, ctx.total_winnr do
        if i ~= ctx.list_winnr then
            local win = vim.fn.win_getid(i) --- @type integer
            local buf = vim.api.nvim_win_get_buf(win) --- @type integer
            --- @type string
            local buftype = vim.api.nvim_get_option_value("buftype", { buf = buf })

            if buftype == "help" then return win end
        end
    end

    return nil
end

--- @param ctx QfOpenCtx
--- @return integer|nil
local function qf_get_new_win(ctx)
    ctx = ctx or {}
    assert(ctx.entry)
    assert(ctx.total_winnr)
    assert(ctx.total_winnr > 1)

    ctx.list_winnr = vim.fn.winnr()

    if ctx.entry.type == "\1" then return find_help_win(ctx) end

    if ctx.is_loclist then
        -- Done in two loops as per the source. While this can result in winnrs being checked
        -- twice, in practice, I suspect, this results in the loclist and backup windows being
        -- checked in the order they are most likely to actually appear. This also captures the
        -- built-in behavior that the first loclist window to be found should be used. This can be
        -- done in only one loop, but the checks per winnr would be heavier and the logic to find
        -- the correct loclist win more convoluted
        local win = find_loclist_win(ctx) --- @type integer|nil
        if win then return win end

        ctx.orphan_loclist = ctx.is_loclist and true or false
        return qf_iter_winnr(ctx)
    end

    --- @type string
    local switchbuf = vim.api.nvim_get_option_value("switchbuf", { scope = "global" })
    ctx.usetab = string.match(switchbuf, "usetab")

    local win = qf_find_matching_buf(ctx) --- @type integer|nil
    if win then return win end

    ctx.uselast = string.match(switchbuf, "uselast") or ctx.usetab
    local alt_win = ctx.uselast and qf_find_alt_win(ctx) or nil --- @type integer|nil
    if alt_win then return alt_win end

    return qf_iter_winnr(ctx)
end

--- @param ctx QfOpenCtx
--- @return nil
local function create_full_split(ctx)
    ctx = ctx or {}
    assert(ctx.buf_opts)
    assert(ctx.buf_source)
    assert(ctx.finish)
    assert(ctx.open)
    assert(ctx.list_win)

    --- @type string
    local splitright = vim.api.nvim_get_option_value("splitright", { scope = "global" })
    local cmd = ctx.open == "vsplit" and "vnew" or "new" --- @type string
    local mods = (function()
        if cmd == "vnew" and splitright then
            return { split = "botright" }
        else
            return { split = "topleft" }
        end
    end)() --- @type {split:string}

    if ctx.is_loclist then
        ctx.loclist_win_from = ctx.list_win
        get_loclist_data(ctx)
        require("mjm.error-list").close_loclist()
    else
        require("mjm.error-list").close_qflist()
    end

    vim.api.nvim_cmd({ cmd = cmd, mods = mods }, {})

    require("mjm.utils").open_buf(ctx.buf_source, ctx.buf_opts)
    local split_win = vim.api.nvim_get_current_win() --- @type integer
    assert(split_win ~= ctx.list_win)

    if ctx.is_loclist then
        ctx.loclist_win_to = split_win
        set_loclist_data(ctx)
    end

    local cur_pos = vim.api.nvim_win_get_cursor(split_win)

    if ctx.finish == "closeList" then return end

    if ctx.is_loclist then
        require("mjm.error-list").open_loclist()
    else
        require("mjm.error-list").open_qflist()
    end

    -- TODO: Not totally sure how necessary some of this is, since the cursor never
    -- actually moved
    vim.api.nvim_set_current_win(split_win)
    if ctx.finish == "focusWin" then vim.api.nvim_win_set_cursor(split_win, cur_pos) end
end

--- @param ctx QfOpenCtx
--- @return nil
local function qf_split_single_window(ctx)
    ctx = ctx or {}
    assert(ctx.open)
    assert(ctx.size)
    assert(ctx.list_win)

    local cur_pos = vim.api.nvim_win_get_cursor(ctx.list_win)
    -- The expected behavior here is that the new window will be split relative to the open
    -- list. We also expect that an orphaned loclist is tied to the new window
    -- Rather than potentially reconstruct the placement of an orphaned loclist, just use
    -- the default behavior + wincmds and keep it straightforward
    vim.api.nvim_cmd({ cmd = "normal", args = { "\r" }, bang = true }, {})

    --- @type string
    local splitright = vim.api.nvim_get_option_value("splitright", { scope = "global" })
    local args = (function()
        if splitright and ctx.open == "vsplit" then
            return { "L" }
        elseif ctx.open == "vsplit" then
            return { "H" }
        else
            return { "K" }
        end
    end)() --- @type string[]

    vim.api.nvim_cmd({ cmd = "wincmd", args = args }, {})

    if ctx.open == "split" then
        -- TODO: Need resizer function
        local builtin_qf_max_height = 10 --- @type integer
        ctx.size = ctx.size or 10
        --- @diagnostic disable: param-type-mismatch
        vim.api.nvim_win_set_height(ctx.list_win, math.min(ctx.size, builtin_qf_max_height))
    end

    -- MAYBE: close_list function that wraps both of these. Feels obfuscatory though
    if ctx.finish == "closeList" then
        if ctx.is_loclist then
            require("mjm.error-list").close_loclist()
        else
            require("mjm.error-list").close_qflist()
        end
    elseif ctx.finish == "focusList" then
        vim.api.nvim_set_current_win(ctx.list_win)
        require("mjm.utils").protected_set_cursor(cur_pos, { win = ctx.list_win })
    end
end

--- @param ctx QfOpenCtx
--- @return boolean
local function validate_qf_split_input(ctx)
    ctx = ctx or {}
    assert(ctx.open)
    assert(ctx.list_win)

    local buftype = vim.api.nvim_get_option_value("buftype", { buf = 0 }) --- @type string
    if buftype ~= "quickfix" then
        local chunk = { "Not a qf buffer", "ErrorMsg" } --- @type string[]
        vim.api.nvim_echo({ chunk }, true, { err = true })
        return false
    end

    --- @type boolean
    local valid_open = ctx.open == "vsplit" or ctx.open == "split" or ctx.open == "tabnew"
    if not valid_open then
        local chunk = { "Invalid open type in validate_qf_split", "ErrorMsg" } --- @type string[]
        vim.api.nvim_echo({ chunk }, true, { err = true })
        return false
    end

    local size = (function()
        if ctx.is_loclist then
            return vim.fn.getloclist(ctx.list_win, { size = true }).size
        else
            return vim.fn.getqflist({ size = true }).size
        end
    end)() --- @type integer

    if (not size) or size == 0 then
        local name = ctx.is_loclist and "loclist" or "qflist" --- @type string
        local chunk = { "No entries in " .. name, "" } --- @type string[]
        vim.api.nvim_echo({ chunk }, true, { err = true })

        return false
    end

    ctx.size = size

    return true
end

-- TODO: I'm not sure we need the is_loclist flag if we can just check the qf_id
-- TODO: Need more consistent naming for window moves. dest_win in non-split opening is where
-- we go to open the file. Do you make the intermediary in the split func something else?
-- (probably).
-- TODO: The set_loclist_data was moved to dest_win. The loclist win vars are out. Fix in
-- this code
-- TODO: Turned off default zz in the buf open opts. Needs to be done manually at different points
-- NOTE: The orphan loclist restoration behavior does not take place if a buf is opened in a
-- different tab

--- @class QfOpenCtx
--- @field buf_opts? mjm.OpenBufOpts
--- @field buf_source? mjm.OpenBufSource
--- @field cur_stack_nr? integer
--- @field dest_win? integer
--- @field entry? table
--- @field finish? "closeList"|"focusList"|"focusWin"
--- @field idx? integer
--- @field is_loclist? boolean
--- @field loclist_data? table[]
--- @field loclist_win_from? integer
--- @field loclist_win_to? integer
--- @field orphan_loclist? boolean
--- @field open? "split"|"tabnew"|"vsplit"
--- @field qf_id? string
--- @field size? integer
--- @field split_win? integer
--- @field total_winnr? integer
--- @field uselast? boolean
--- @field usetab? boolean
--- @field list_win? integer
--- @field list_winnr? integer

--- @param open "split"|"tabnew"|"vsplit"
--- @param finish "closeList"|"focusList"|"focusWin"
--- @return nil
local function qf_open_split(open, finish)
    -- Naming: ListWin, FindWin, SplitWin
    local win = vim.api.nvim_get_current_win() --- @type integer
    local is_loclist = vim.fn.getloclist(win, { id = 0 }).id ~= 0 --- @type boolean
    local ctx = { is_loclist = is_loclist, open = open, list_win = win } --- @type QfOpenCtx
    ctx.finish = finish
    ctx.qf_id = vim.fn.getloclist(win, { id = 0 }).id

    local ok = validate_qf_split_input(ctx) --- @type boolean
    if not ok then return end

    ctx.total_winnr = vim.fn.winnr("$")
    if ctx.total_winnr == 1 and ctx.open ~= "tabnew" then
        qf_split_single_window(ctx)
        return
    end

    local ok_e = get_entry_on_cursor(ctx) --- @type boolean
    if not ok_e then return end

    qf_get_open_buf_opts(ctx)

    if ctx.is_loclist then
        vim.fn.setloclist(ctx.list_win, {}, "r", { idx = ctx.idx })
    else
        vim.fn.setqflist({}, "r", { idx = ctx.idx })
    end

    if open == "tabnew" then
        -- TODO: go to the tabnr, or highest
        local cur_pos = vim.api.nvim_win_get_cursor(ctx.list_win)
        if ctx.finish == "closeList" then
            if ctx.is_loclist then
                require("mjm.error-list").close_loclist()
            else
                require("mjm.error-list").close_qflist()
            end
        end

        require("mjm.utils").open_buf(ctx.buf_source, ctx.buf_opts)

        vim.api.nvim_set_current_win(ctx.list_win)
        if ctx.finish == "focusList" then vim.api.nvim_win_set_cursor(ctx.list_win, cur_pos) end
        return
    end

    local new_win = (function()
        if vim.v.count < 1 then
            return qf_get_new_win(ctx)
        else
            local vwinnr = math.min(vim.v.count, ctx.total_winnr)
            local vwin = vim.fn.win_getid(vwinnr)
            local vbuf = vim.api.nvim_win_get_buf(vwin)
            local vbuftype = vim.api.nvim_get_option_value("buftype", { buf = vbuf })

            if vbuftype == "" then
                -- TODO: Will keep pointing this out. The logic is straightforward, then we have
                -- to take a detour to tend to the location list
                local vqf_id = vim.fn.getloclist(vwin, { id = 0 }).id
                if vqf_id ~= ctx.qf_id then ctx.orphan_loclist = true end
                return vwin
            else
                vim.api.nvim_echo({ { "Buftype not empty", "" } }, false, {})
                return nil
            end
        end
    end)() --- @type integer|nil

    if not new_win then
        if vim.v.count < 1 then create_full_split(ctx) end
        return
    end

    assert(vim.api.nvim_win_is_valid(new_win))
    local list_cur_pos = vim.api.nvim_win_get_cursor(ctx.list_win)

    -- TODO: The bigger version of what was mentioned above. Two different lines of logic are
    -- happening here at the same time and they melt into each other
    if ctx.orphan_loclist then
        ctx.loclist_win_from = ctx.list_win
        get_loclist_data(ctx)
        require("mjm.error-list").close_loclist()
    end

    vim.api.nvim_set_current_win(new_win)
    vim.api.nvim_cmd({ cmd = ctx.open }, {})
    ctx.split_win = vim.api.nvim_get_current_win()
    assert(ctx.split_win ~= new_win)

    require("mjm.utils").open_buf(ctx.buf_source, ctx.buf_opts)
    local cur_pos = vim.api.nvim_win_get_cursor(ctx.split_win)

    if ctx.is_loclist then
        ctx.loclist_win_to = ctx.split_win
        set_loclist_data(ctx)

        if ctx.finish == "closeList" then return end

        require("mjm.error-list").open_loclist()

        if ctx.finish == "focusWin" then
            vim.api.nvim_set_current_win(ctx.split_win)
            vim.api.nvim_win_set_cursor(ctx.split_win, cur_pos)
        end
    else
        if ctx.finish == "closeList" then
            require("mjm.error-list").close_qflist()
            return
        end

        if ctx.finish == "focusList" then
            vim.api.nvim_set_current_win(ctx.list_win)
            vim.api.nvim_win_set_cursor(ctx.list_win, list_cur_pos)
        end
    end
end

Map("n", "s", function() qf_open_split("split", "focusWin") end, { buffer = 0 })
Map("n", "S", function() qf_open_split("split", "closeList") end, { buffer = 0 })
Map("n", "<C-s>", function() qf_open_split("split", "focusList") end, { buffer = 0 })
Map("n", "v", function() qf_open_split("vsplit", "focusWin") end, { buffer = 0 })
Map("n", "V", function() qf_open_split("vsplit", "closeList") end, { buffer = 0 })
Map("n", "<C-v>", function() qf_open_split("vsplit", "focusList") end, { buffer = 0 })
Map("n", "x", function() qf_open_split("tabnew", "focusWin") end, { buffer = 0 })
Map("n", "X", function() qf_open_split("tabnew", "closeList") end, { buffer = 0 })
Map("n", "<C-x>", function() qf_open_split("tabnew", "focusList") end, { buffer = 0 })
