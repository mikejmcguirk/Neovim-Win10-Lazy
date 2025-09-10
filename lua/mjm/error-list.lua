------------------
-- CAPABILITIES --
------------------

--- TODO: Create a quickfixtextfuc that's as information rich as possible without being busy
--- TODO: Filter keep/delete on as many fields as possible
--- TODO: Sort on as many fields as possible (regular/capslock for asc/desc)
--- TODO: Wrapper functions should make reasonable sorts as much as possible
--- --- How to do with vimgrep though?
--- TODO: Is there a better way to use grepprg?
--- TODO: Re-sync contents
--- TODO: Run/refresh from title. Wrappers should set it up properly
--- --- Can get rid of redo grep map
--- --- grepa might help with this
--- TODO: More visibility for cdo/cfdo. Use bang by default?
--- TODO: Filter based on regex. Maybe vim.regex'
--- TODO: Wrapper functions should trigger window height updates. Resize cmd
--- TODO: De-map split cmds in windows

--- MAYBE: Treesitter/Semantic Token Highlighting
--- MAYBE: Incremental preview of cdo/cfdo changes

--------------
-- STAYAWAY --
--------------

--- No attaching to buffers/creating persistent state
--- No modifying buffers within the qflist
--- No additional context type stuff. Previewer covers this
--- No Fuzzy finding type stuff. FzfLua does this
--- No annotations. Should be able to filter down to key items
--- Dynamic behavior. Trouble has to create a whole async runtime and data model to manage this
--- "Modernizing" the feel of the qflist. The old school feel is part of the charm

--------------
-- MAPPINGS --
--------------

--- Patterns:
--- --- Modifiers on last key only. No recursive choices
--- --- Lowercase creates new
--- --- Uppercase replaces current
--- --- Ctrl combines
--- --- Alt can be used for some other idea
--- --- Use count 1-0 to specify a specific stack position

--- GENERAL BUFFER MAPS
--- <leader>q for qf, <leader>l for loc
--- qio - diagnostics (but creates anti-pattern since not toggle, and double top)
--- qie - errors
--- qiw - warnings
--- qih - hint
--- qii or qif - info
--- qih? - highest severity
--- view count of lists
--- goto list number (unimpaired already does cycling)
--- something like qd and qD for cdo and cfdo
--- A way to copy lists, and maybe filtered copy
--- A merge kinda like deep table extend where duplicates are filtered
--- Or a merge that works like a XOR
--- Some of these more complex ideas feel more like commands
---
--- QF BUFFER:
--- p to toggle preview
--- vim-qf-preview has some reasonable maps (r mainly) for previewer

---------------
-- RESOURCES --
---------------

-- RESOURCES
-- https://github.com/romainl/vim-qf
-- https://github.com/kevinhwang91/nvim-bqf
-- https://github.com/arsham/listish.nvim
-- https://github.com/itchyny/vim-qfedit -- Simple version of quicker
-- https://github.com/mileszs/ack.vim
-- https://github.com/stevearc/qf_helper.nvim

-- PREVIEWERS:
-- https://github.com/r0nsha/qfpreview.nvim
-- https://github.com/bfrg/vim-qf-preview

---------------------------
-- qf jump function list --
---------------------------

-- qf_view_result
-- ex_cc
-- qf_jump
-- qf_jump_newwin
-- qf_jump_open_window
-- jump_to_help_window
-- qf_jump_to_usable_window
-- qf_open_new_file_win
-- qf_goto_win_with_ll_file
-- qf_goto_win_with_qfl_file

------------------------
-- Other source notes --
------------------------

-- The vimgrep code is in quickfix.c. Functions often start with "vgr"

local M = {}

----------------
--- Autocmds ---
----------------

--- @type integer
local loclist_group = vim.api.nvim_create_augroup("loclist-group", { clear = true })

-- Start each window with a fresh loclist
vim.api.nvim_create_autocmd("WinNew", {
    group = loclist_group,
    pattern = "*",
    callback = function() vim.fn.setloclist(0, {}, "f") end,
})

-- Clean up orphaned loclists
vim.api.nvim_create_autocmd("WinClosed", {
    group = loclist_group,
    callback = function(ev)
        local win = tonumber(ev.match) --- @type number?
        if not type(win) == "number" then return end

        local config = vim.api.nvim_win_get_config(win) --- @type vim.api.keyset.win_config
        if config.relative and config.relative ~= "" then return end

        local buf = vim.api.nvim_win_get_buf(win) --- @type integer
        local buftype = vim.api.nvim_get_option_value("buftype", { buf = buf }) --- @type string
        if buftype == "quickfix" then return end

        local qf_id = vim.fn.getloclist(ev.match, { id = 0 }).id ---@type integer
        -- Clean up loclists so that Nvim can purge them under the hood
        require("mjm.utils").close_all_loclists(qf_id)
    end,
})

----------------------------------
--- Window Position Resolution ---
----------------------------------

--- @param win integer
--- @return Range4|nil
local function get_win_range4(win)
    local pos = vim.api.nvim_win_get_position(win)
    if pos[1] < 0 or pos[2] < 0 then return nil end

    local height = vim.api.nvim_win_get_height(win)
    local width = vim.api.nvim_win_get_width(win)
    local bottom = pos[1] + height - 1
    local right = pos[2] + width - 1

    return { pos[1], pos[2], bottom, right }
end

--- @param win Range4
--- @param other Range4
--- @return boolean
local function is_horizontal_overlap(win, other)
    return math.max(win[2], other[2]) <= math.min(win[4], other[4])
end

--- @param win integer
--- @return boolean
local function is_bottom(win)
    local other_wins = vim.api.nvim_tabpage_list_wins(0) --- @type integer[]
    if (not other_wins) or #other_wins < 2 then return true end

    local win_bounds = get_win_range4(win) --- @type Range4?
    if not win_bounds then return false end

    local function compare_wins(other_win)
        if other_win == win then return true end

        local other_bounds = get_win_range4(other_win) --- @type Range4?
        if not other_bounds then return true end

        if not is_horizontal_overlap(win_bounds, other_bounds) then return true end

        if other_bounds[1] > win_bounds[1] then return false end

        return true
    end

    for _, o in ipairs(other_wins) do
        if not compare_wins(o) then return false end
    end

    return true
end

-------------------------------------
--- Opening and Closing Functions ---
-------------------------------------

-- FUTURE:
-- One nag still left here - If you enter the qf list scrolled far down, then move back to the
-- original window, it will shift in order to stay within the bounds of scrolloff. It is
-- theoretically possible to pull in the virtual line extmarks + the display widths of wrapped
-- lines in order to calculate and pre-move the view in the old window so this doesn't happen. But
-- at the moment the effort/value proposition is too far skewed the wrong way
--
-- An additional technical note is, right now the logic just spams winsaveviews at the bottom bufs
-- to guard against screen shifting. While I'm not seeing a perf loss from this, it is sloppy
-- In theory at least it should be possible to figure out which specific buffer it's acting on
-- YOu could maybe pull and compare winsaveview returns after the fact, but I'm not sure if that's
-- actually faster than what I'm doing right now
--
-- This logic is currently aimed at botright copens. Would need to be more flexible and precise
-- in its methodology to be more broadly useful

--- @param height? integer
--- @return boolean
local function open_qflist(height)
    require("mjm.utils").close_all_loclists()

    local wins = vim.api.nvim_tabpage_list_wins(0) --- @type integer[]
    local views = {} --- @type vim.fn.winsaveview.ret|nil[]

    local function win_check(wininfo)
        if wininfo.quickfix == 1 and wininfo.loclist ~= 1 then return false end

        --- @type vim.api.keyset.win_config
        local config = vim.api.nvim_win_get_config(wininfo.winid)
        if config.relative and config.relative ~= "" then return true end

        if not is_bottom(wininfo.winid) then return true end

        local get_view = function() views[wininfo.winid] = vim.fn.winsaveview() end
        vim.api.nvim_win_call(wininfo.winid, get_view)

        return true
    end

    for _, w in pairs(vim.api.nvim_tabpage_list_wins(0)) do
        if not win_check(vim.fn.getwininfo(w)[1]) then return false end
    end

    height = height or 10
    --- @diagnostic disable: missing-fields
    vim.api.nvim_cmd({ cmd = "copen", count = height, mods = { split = "botright" } }, {})

    local function adjust_view(w)
        local view = views[w] --- @type vim.fn.winsaveview.ret|nil
        if not view then return end

        vim.api.nvim_win_call(w, function() vim.fn.winrestview(view) end)
    end

    for _, w in pairs(wins) do
        adjust_view(w)
    end

    return true
end

--- @return boolean
local function close_qflist()
    local is_qf_here = false --- @type boolean
    local views = {} --- @type vim.fn.winsaveview.ret|nil[]

    local function win_check(wininfo)
        if wininfo.quickfix == 1 and wininfo.loclist ~= 1 then
            is_qf_here = true
            return
        end

        --- @type vim.api.keyset.win_config
        local config = vim.api.nvim_win_get_config(wininfo.winid)
        if config.relative and config.relative ~= "" then return end

        vim.api.nvim_win_call(
            wininfo.winid,
            function() views[wininfo.winid] = vim.fn.winsaveview() end
        )
    end

    for _, w in pairs(vim.api.nvim_tabpage_list_wins(0)) do
        local wininfo = vim.fn.getwininfo(w)[1] --- @type vim.fn.getwininfo.ret.item
        win_check(wininfo)
    end

    if not is_qf_here then return false end

    vim.api.nvim_cmd({ cmd = "ccl" }, {})

    local function adjust_wins(win)
        local view = views[win] --- @type vim.fn.winsaveview.ret|nil
        if not view then return end

        if not is_bottom(win) then return end

        if view then vim.api.nvim_win_call(win, function() vim.fn.winrestview(view) end) end
    end

    for _, w in pairs(vim.api.nvim_tabpage_list_wins(0)) do
        adjust_wins(w)
    end

    return true
end

--- @param height? integer
--- @return boolean
local function open_loclist(height)
    local win = vim.api.nvim_get_current_win() --- @type integer
    local qf_id = vim.fn.getloclist(win, { id = 0 }).id ---@type integer
    if qf_id == 0 then
        vim.api.nvim_echo({ { "Window has no loclist", "" } }, false, {})
        return false
    end

    local wins = vim.api.nvim_tabpage_list_wins(0) --- @type integer[]
    local views = {} --- @type vim.fn.winsaveview.ret|nil[]
    local fin_lines = {} --- @type integer[]

    local function win_check(wininfo)
        if wininfo.quickfix == 1 and wininfo.loclist ~= 1 and wininfo.winid == win then
            vim.api.nvim_echo({ { "Cannot open loclist from quickfix window", "" } }, false, {})
            return false
        end

        if wininfo.quickfix == 1 and wininfo.loclist == 1 then
            local qf_id_wi = vim.fn.getloclist(wininfo.winid, { id = 0 }).id ---@type integer
            if qf_id_wi == qf_id then return false end
        end

        local config = vim.api.nvim_win_get_config(wininfo.winid) --- @type vim.api.keyset.win_config
        if config.relative and config.relative ~= "" then return true end

        -- Because this opens belowright, only the origin window is affected
        if (not wininfo.winid) == win then return true end

        views[wininfo.winid] = vim.fn.winsaveview()

        return true
    end

    for _, w in pairs(wins) do
        if not win_check(vim.fn.getwininfo(w)[1]) then return false end
    end

    close_qflist()
    --- @diagnostic disable: missing-fields
    height = height or 10
    vim.api.nvim_cmd({ cmd = "lop", count = height, mods = { split = "belowright" } }, {})

    local function adjust_view(w)
        local view = views[w] --- @type vim.fn.winsaveview.ret|nil
        if not view then return end

        vim.api.nvim_win_call(w, function() vim.fn.winrestview(view) end)
    end

    for _, w in pairs(wins) do
        adjust_view(w)
    end

    return true
end

--- @return boolean
local function close_loclist()
    local win = vim.api.nvim_get_current_win() --- @type integer
    local qf_id = vim.fn.getloclist(win, { id = 0 }).id ---@type any
    if qf_id == 0 then
        vim.api.nvim_echo({ { "Window has no loclist", "" } }, false, {})
        return false
    end

    local views = {} --- @type vim.fn.winsaveview.ret|nil[]
    local has_loclist_focus = false

    local function win_check(wininfo)
        if wininfo.quickfix == 1 and wininfo.loclist ~= 1 and wininfo.winid == win then
            local msg = "Cannot close loclist from quickfix window"
            vim.api.nvim_echo({ { msg, "" } }, false, {})
            return false
        end

        local qf_id_wi = vim.fn.getloclist(wininfo.winid, { id = 0 }).id ---@type any
        if qf_id_wi == qf_id then
            has_loclist_focus = true
            return true
        end

        --- @type vim.api.keyset.win_config
        local config = vim.api.nvim_win_get_config(wininfo.winid)
        if config.relative and config.relative ~= "" then return true end

        vim.api.nvim_win_call(
            wininfo.winid,
            function() views[wininfo.winid] = vim.fn.winsaveview() end
        )
        return true
    end

    for _, w in pairs(vim.api.nvim_tabpage_list_wins(0)) do
        if not win_check(vim.fn.getwininfo(w)[1]) then return false end
    end

    if not has_loclist_focus then return false end

    vim.api.nvim_cmd({ cmd = "lcl" }, {})

    for _, w in pairs(vim.api.nvim_tabpage_list_wins(0)) do
        local view = views[w]
        if view then vim.api.nvim_win_call(w, function() vim.fn.winrestview(view) end) end
    end

    return true
end

--------------------------------
--- Opening and Closing Maps ---
--------------------------------

Map("n", "cuc", close_qflist)
Map("n", "cup", open_qflist)
Map("n", "cuu", function()
    if not open_qflist() then close_qflist() end
end)

Map("n", "coc", close_loclist)
Map("n", "cop", open_loclist)
Map("n", "coo", function()
    if not open_loclist() then close_loclist() end
end)

for _, map in pairs({ "cuo", "cou" }) do
    Map("n", map, function()
        require("mjm.utils").close_all_loclists()
        close_qflist()
    end)
end

Map("n", "duc", function()
    close_qflist()
    vim.fn.setqflist({}, "r")
end)

Map("n", "dua", function()
    vim.api.nvim_cmd({ cmd = "ccl" }, {})
    vim.fn.setqflist({}, "f")
end)

Map("n", "doc", function()
    close_loclist()
    vim.fn.setloclist(vim.api.nvim_get_current_win(), {}, "r")
end)

Map("n", "doa", function()
    close_loclist()
    vim.fn.setloclist(vim.api.nvim_get_current_win(), {}, "f")
end)

local severity_map = {
    [vim.diagnostic.severity.ERROR] = "E",
    [vim.diagnostic.severity.WARN] = "W",
    [vim.diagnostic.severity.INFO] = "I",
    [vim.diagnostic.severity.HINT] = "H",
} ---@type table<integer, string>

---@param diag table
---@return table
local function convert_diag(diag)
    diag = diag or {}

    local source = diag.source and diag.source .. ": " or "" ---@type string
    local code = diag.code and "[" .. diag.code .. "]" or "" --- @type string
    local message = diag.message or "" ---@type string

    return {
        bufnr = diag.bufnr,
        filename = vim.fn.bufname(diag.bufnr),
        lnum = diag.lnum + 1,
        end_lnum = diag.end_lnum + 1,
        col = diag.col + 1,
        end_col = diag.end_col,
        text = source .. code .. message,
        type = severity_map[diag.severity],
    }
end

-- LOW: I doubt this is the best way to get the highest severity, as it requires two pulls
-- from vim.diagnostic.get(). It might also be cleaner to use iter functions
-- FUTURE: Consider using vim.diagnostic.setqflist if enough features are added
---@param opts? {highest:boolean, err_only:boolean}
---@return nil
local function all_diags_to_qflist(opts)
    opts = opts or {}

    local severity = (function()
        if opts.highest then
            return require("mjm.utils").get_top_severity({ buf = nil })
        elseif opts.err_only then
            return vim.diagnostic.severity.ERROR
        else
            return { min = vim.diagnostic.severity.HINT }
        end
    end)() ---@type integer|{min:integer}

    ---@diagnostic disable: undefined-doc-name
    local raw_diags = vim.diagnostic.get(nil, { severity = severity }) ---@type vim.diagnostic[]
    if #raw_diags == 0 then
        local name = opts.err_only and "errors" or "diagnostics" ---@type string
        vim.api.nvim_cmd({ cmd = "ccl" }, {})

        vim.notify("No " .. name)
        return
    end

    local diags_for_qflist = vim.tbl_map(convert_diag, raw_diags) ---@type table
    assert(#raw_diags == #diags_for_qflist, "Coverted diags were filtered")

    vim.fn.setqflist(diags_for_qflist, "r")
    open_qflist()
end

---@param opts? {highest:boolean, err_only:boolean}
---@return nil
local function buf_diags_to_loclist(opts)
    opts = opts or {}

    local win = vim.api.nvim_get_current_win() ---@type integer
    local buf = vim.api.nvim_win_get_buf(win) ---@type integer
    if not require("mjm.utils").check_modifiable(buf) then return end

    local severity = (function()
        if opts.highest then
            return require("mjm.utils").get_top_severity({ buf = buf })
        elseif opts.err_only then
            return vim.diagnostic.severity.ERROR
        else
            return { min = vim.diagnostic.severity.HINT }
        end
    end)() ---@type integer|{min:integer}

    ---@diagnostic disable: undefined-doc-name
    local raw_diags = vim.diagnostic.get(buf, { severity = severity }) ---@type vim.diagnostic[]
    if #raw_diags == 0 then
        local name = opts.err_only and "errors" or "diagnostics" ---@type string
        vim.api.nvim_cmd({ cmd = "lcl" }, {})

        vim.notify("No " .. name)
        return
    end

    local diags_for_loclist = vim.tbl_map(convert_diag, raw_diags) ---@type table
    assert(#raw_diags == #diags_for_loclist, "Coverted diags were filtered")

    vim.fn.setloclist(win, diags_for_loclist, "r")
    vim.api.nvim_cmd({ cmd = "ccl" }, {})
    vim.api.nvim_cmd({ cmd = "lop" }, {})
end

Map("n", "yui", function() all_diags_to_qflist() end)

Map("n", "yue", function() all_diags_to_qflist({ err_only = true }) end)

Map("n", "yuh", function() all_diags_to_qflist({ highest = true }) end)

Map("n", "yoi", function() buf_diags_to_loclist() end)

Map("n", "yoe", function() buf_diags_to_loclist({ err_only = true }) end)

Map("n", "yoh", function() buf_diags_to_loclist({ highest = true }) end)

---@param opts? {loclist:boolean, remove:boolean}
---@return nil
local function filter_wrapper(opts)
    opts = opts or {}

    if opts.loclist and vim.fn.getloclist(vim.api.nvim_get_current_win(), { id = 0 }).id == 0 then
        vim.notify("Current window has no location list")
        return
    end

    local list = opts.loclist and "Location" or "Quickfix" ---@type string

    if opts.loclist and #vim.fn.getloclist(vim.api.nvim_get_current_win()) <= 0 then
        vim.notify(list .. " list is empty")
        return
    elseif (not opts.loclist) and #vim.fn.getqflist() <= 0 then
        vim.notify(list .. " list is empty")
        return
    end

    local action = opts.remove and "remove: " or "keep: " --- @type string
    local prompt = list .. " pattern to " .. action --- @type string
    local ok, pattern = require("mjm.utils").get_input(prompt) --- @type boolean, string
    if not ok then
        local msg = pattern or "Unknown error getting input" --- @type string
        vim.api.nvim_echo({ { msg, "ErrorMsg" } }, true, { err = true })
        return
    elseif pattern == "" then
        return
    end

    local prefix = opts.loclist and "L" or "C" ---@type string
    vim.api.nvim_cmd({ cmd = prefix .. "filter", bang = opts.remove, args = { pattern } }, {})
end

Map("n", "duk", function() filter_wrapper() end)

Map("n", "dur", function() filter_wrapper({ remove = true }) end)

Map("n", "dok", function() filter_wrapper({ loclist = true }) end)

Map("n", "dor", function() filter_wrapper({ loclist = true, remove = true }) end)

local last_grep = nil
local last_lgrep = nil

---@param opts table
---@return nil
local function grep_wrapper(opts)
    opts = opts or {}
    if opts.loclist and vim.api.nvim_get_option_value("filetype", { buf = 0 }) == "qf" then
        return vim.notify("Inside qf buffer")
    end

    local ok, pattern = (function()
        if opts.pattern then
            return true, opts.pattern
        else
            return require("mjm.utils").get_input("Enter Grep pattern: ")
        end
    end)() --- @type boolean, string

    if not ok then
        local msg = pattern or "Unknown error getting input" --- @type string
        vim.api.nvim_echo({ { msg, "ErrorMsg" } }, true, { err = true })
        return
    elseif pattern == "" and opts.pattern then
        vim.api.nvim_echo({ { "Empty grep pattern", "WarningMsg" } }, true, {})
        return
    elseif pattern == "" then
        return
    end

    local args = { pattern } ---@type table
    if opts.insensitive then table.insert(args, "-i") end
    if opts.loclist then table.insert(args, "%") end

    vim.api.nvim_cmd({
        args = args,
        bang = true,
        cmd = opts.loclist and "lgrep" or "grep",
        --- @diagnostic disable: missing-fields
        mods = { emsg_silent = true },
        magic = opts.loclist and { file = true } or {},
    }, {})

    if opts.loclist then
        last_lgrep = pattern
        open_loclist()
    else
        last_grep = pattern
        open_qflist()
    end
end

Map("n", "yugs", function() grep_wrapper({}) end)

Map("n", "yogs", function() grep_wrapper({ loclist = true }) end)

Map("n", "yugi", function() grep_wrapper({ insensitive = true }) end)

Map("n", "yogi", function() grep_wrapper({ insensitive = true, loclist = true }) end)

Map("n", "yugr", function() grep_wrapper({ pattern = last_grep }) end)

Map("n", "yogr", function() grep_wrapper({ pattern = last_lgrep, loclist = true }) end)

Map("n", "yugv", function() print(last_grep) end)

Map("n", "yogv", function() print(last_lgrep) end)

local function qf_scroll_wrapper(main, alt, end_err)
    local main_with_count = vim.tbl_extend("force", main, { count = vim.v.count1 })
    local ok, err = pcall(vim.api.nvim_cmd, main_with_count, {})

    if (not ok) and (err:match("E42") or err:match("E776")) then
        vim.notify(err:sub(#"Vim:" + 1))
        return
    end

    if (not ok) and err:match(end_err) then
        ok, err = pcall(vim.api.nvim_cmd, alt, {})
    end

    if not ok then
        err = err and err:sub(#"Vim:" + 1) or "Unknown qf_scroll error"
        vim.notify(err, vim.log.levels.WARN)
        return
    end

    vim.cmd("norm! zz")
end

local scroll_maps = {
    { "[q", { cmd = "cprevious" }, { cmd = "clast" }, "E553" },
    { "]q", { cmd = "cnext" }, { cmd = "crewind" }, "E553" },
    { "[l", { cmd = "lprevious" }, { cmd = "llast" }, "E553" },
    { "]l", { cmd = "lnext" }, { cmd = "lrewind" }, "E553" },
    { "[<C-q>", { cmd = "cpfile" }, { cmd = "clast" }, "E553" },
    { "]<C-q>", { cmd = "cnfile" }, { cmd = "crewind" }, "E553" },
    { "[<C-l>", { cmd = "lpfile" }, { cmd = "llast" }, "E553" },
    { "]<C-l>", { cmd = "lnfile" }, { cmd = "lrewind" }, "E553" },
    {
        "[<M-q>",
        { cmd = "colder" },
        { cmd = "execute", args = { "getqflist({'nr' : '$'}).nr . 'chistory'" } },
        "E380",
    },
    { "]<M-q>", { cmd = "cnewer" }, { cmd = "chistory", count = 1 }, "E381" },
    {
        "[<M-l>",
        { cmd = "lolder" },
        { cmd = "execute", args = { "getloclist(0, {'nr' : '$'}).nr . 'lhistory'" } },
        "E380",
    },
    { "]<M-l>", { cmd = "lnewer" }, { cmd = "lhistory", count = 1 }, "E381" },
}

for _, m in pairs(scroll_maps) do
    Map("n", m[1], function() qf_scroll_wrapper(m[2], m[3], m[4]) end)
end
