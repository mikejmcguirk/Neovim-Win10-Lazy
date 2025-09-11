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
-- qf_find_win_with_loclist
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

-- MAYBE: If you want to be fancy, for each of these qf open/close commands, you could have
-- a generalized function for win_check, and pass in function handlers for different wintype
-- conditions. Would allow for customization. But for the current case, I think the layers of
-- wrappers would add complexity

-- FUTURE: View adjustments should take into account scrolloff and screenlines so that if the
-- user re-enters the window, it doesn't shift to meet scrolloff requirements
-- screenpos() ?
-- screenrow() ?

--- @param win integer
--- @param views vim.fn.winsaveview.ret[]
--- @return nil
local function adjust_view(win, views)
    local view = views[win] --- @type vim.fn.winsaveview.ret|nil
    if not view then return end
    if not vim.api.nvim_win_is_valid(win) then return end

    --- @type integer
    local new_topline = vim.api.nvim_win_call(win, function() return vim.fn.line("w0") end)
    if view.topline == new_topline then return end

    vim.api.nvim_win_call(win, function() vim.fn.winrestview(view) end)
end

local function restore_view(win, view)
    if not vim.api.nvim_win_is_valid(win) then return end

    --- @type integer
    local new_topline = vim.api.nvim_win_call(win, function() return vim.fn.line("w0") end)
    if view.topline == new_topline then return end

    vim.api.nvim_win_call(win, function() vim.fn.winrestview(view) end)
end

-- TODO: Move everything to this function
local function restore_views(views)
    for win, view in pairs(views) do
        restore_view(win, view)
    end
end

---@param opts? {id: integer, cur_tab: boolean}
---@return boolean
function M.close_all_loclists(opts)
    opts = opts or {}

    local closed_loc_list = false ---@type boolean
    local tabpages = opts.cur_tab and { vim.api.nvim_get_current_tabpage() }
        or vim.api.nvim_list_tabpages()

    for _, tab in pairs(tabpages) do
        local loclist_wins = {} --- @type integer[]
        local views = {} --- @type vim.fn.winsaveview.ret|nil[]

        for _, win in pairs(vim.api.nvim_tabpage_list_wins(tab)) do
            local wintype = vim.fn.win_gettype(win)
            if wintype == "loclist" then
                if opts.id then
                    local qf_id = vim.fn.getloclist(win, { id = 0 }).id --- @type integer
                    if qf_id == opts.id then
                        table.insert(loclist_wins, win)
                    else
                        views[win] = vim.api.nvim_win_call(win, vim.fn.winsaveview)
                    end
                else
                    table.insert(loclist_wins, win)
                end
            elseif wintype == "" or wintype == "quickfix" then
                views[win] = vim.api.nvim_win_call(win, vim.fn.winsaveview)
            end
        end

        for _, wl in pairs(loclist_wins) do
            vim.api.nvim_win_close(wl, false)
            closed_loc_list = true
        end

        if #loclist_wins > 0 then
            for _, w in pairs(vim.api.nvim_tabpage_list_wins(tab)) do
                adjust_view(w, views)
            end
        end
    end

    return closed_loc_list
end

--- @type integer
-- local loclist_group = vim.api.nvim_create_augroup("loclist-group", { clear = true })

-- Start each window with a fresh loclist
-- vim.api.nvim_create_autocmd("WinNew", {
--     group = loclist_group,
--     pattern = "*",
--     callback = function() vim.fn.setloclist(0, {}, "f") end,
-- })

-- TODO: This does not work when the llist is the last window. Maybe purge and bufdel
-- Clean up orphaned loclists
-- vim.api.nvim_create_autocmd("WinClosed", {
--     group = loclist_group,
--     callback = function(ev)
--         local win = tonumber(ev.match) --- @type number?
--         if not type(win) == "number" then return end
--
--         local config = vim.api.nvim_win_get_config(win) --- @type vim.api.keyset.win_config
--         if config.relative and config.relative ~= "" then return end
--
--         local buf = vim.api.nvim_win_get_buf(win) --- @type integer
--         local buftype = vim.api.nvim_get_option_value("buftype", { buf = buf }) --- @type string
--         if buftype == "quickfix" then return end
--
--         local qf_id = vim.fn.getloclist(ev.match, { id = 0 }).id ---@type integer
--         if qf_id == 0 then return end
--         require("mjm.utils").close_all_loclists(qf_id)
--     end,
-- })

-------------------------------------
--- Opening and Closing Functions ---
-------------------------------------

local max_qf_height = 10

-- NOTE: This assumes nowrap
--- @param opts {height?: integer, is_loclist?: boolean, win?: integer}
--- @return nil
local function get_list_height(opts)
    opts = opts or {}

    if opts.height then return opts.height end

    opts.win = opts.win or 0
    local size = (function()
        if opts.is_loclist then
            return vim.fn.getloclist(opts.win, { size = true }).size
        else
            return vim.fn.getqflist({ size = true }).size
        end
    end)()

    local list_height = math.min(size, max_qf_height)
    list_height = math.max(list_height, 1)

    return list_height
end

--- @param opts? {height:integer, keep_win:boolean}
--- @return boolean
function M.open_qflist(opts)
    opts = opts or {}

    local cur_win = vim.api.nvim_get_current_win()
    local wins = vim.api.nvim_tabpage_list_wins(0) --- @type integer[]
    local views = {} --- @type vim.fn.winsaveview.ret|nil[]
    local is_loclist_open = false

    local function win_check(win)
        local wintype = vim.fn.win_gettype(win)

        if wintype == "quickfix" then return false end

        if wintype == "loclist" then
            is_loclist_open = true
            return true
        end

        if wintype == "" then views[win] = vim.api.nvim_win_call(win, vim.fn.winsaveview) end
        return true
    end

    for _, win in pairs(vim.api.nvim_tabpage_list_wins(0)) do
        if not win_check(win) then return false end
    end

    if is_loclist_open then M.close_all_loclists({ cur_tab = true }) end
    local list_height = get_list_height({ height = opts.height })
    --- @diagnostic disable: missing-fields
    vim.api.nvim_cmd({ cmd = "copen", count = list_height, mods = { split = "botright" } }, {})

    for _, w in pairs(wins) do
        adjust_view(w, views)
    end

    if opts.keep_win and vim.api.nvim_win_is_valid(cur_win) then
        vim.api.nvim_set_current_win(cur_win)
    end

    return true
end

--- @return boolean
function M.close_qflist()
    local is_qf_here = false --- @type boolean
    local views = {} --- @type vim.fn.winsaveview.ret|nil[]

    local function win_check(win)
        local wintype = vim.fn.win_gettype(win)

        if wintype == "quickfix" then
            is_qf_here = true
            return
        end

        local save_view = wintype == "" or wintype == "loclist"
        if not save_view then return end

        views[win] = vim.api.nvim_win_call(win, vim.fn.winsaveview)
    end

    for _, win in pairs(vim.api.nvim_tabpage_list_wins(0)) do
        win_check(win)
    end

    if not is_qf_here then return false end
    vim.api.nvim_cmd({ cmd = "ccl" }, {})

    for _, w in pairs(vim.api.nvim_tabpage_list_wins(0)) do
        adjust_view(w, views)
    end

    return true
end

--- @param opts? {height: integer, keep_win: boolean}
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
    local views = {} --- @type vim.fn.winsaveview.ret|nil[]
    local qf_err = "Cannot open loclist from qf window"
    local is_qf_open = false

    local function win_check(win)
        local wintype = vim.fn.win_gettype(win)

        if wintype == "quickfix" then
            if win == cur_win then
                vim.api.nvim_echo({ { qf_err, "" } }, false, {})
                return false
            end

            is_qf_open = true
            return true
        end

        if wintype == "loclist" then
            if win == cur_win then
                vim.api.nvim_echo({ { qf_err, "" } }, false, {})
                return false
            end

            local win_qf_id = vim.fn.getloclist(cur_win, { id = 0 }).id ---@type integer
            if win_qf_id == qf_id then return false end

            views[win] = vim.api.nvim_win_call(win, vim.fn.winsaveview)
            return true
        end

        if wintype == "" then views[win] = vim.api.nvim_win_call(win, vim.fn.winsaveview) end
        return true
    end

    for _, win in pairs(wins) do
        if not win_check(win) then return false end
    end

    if is_qf_open then M.close_qflist() end
    --- @diagnostic disable: missing-fields
    local list_height = get_list_height({ height = opts.height, is_loclist = true, win = cur_win })
    vim.api.nvim_cmd({ cmd = "lop", count = list_height }, {})

    for _, w in pairs(wins) do
        adjust_view(w, views)
    end

    if opts.keep_win and vim.api.nvim_win_is_valid(cur_win) then
        vim.api.nvim_set_current_win(cur_win)
    end

    return true
end

-- PERF: Would it be faster to just iterate once to see if we have a loclist to close, then
-- iterate again to get the info to save? Applies to all open/closes
-- Maybe a way to think about it - How does each approach scale with a lot of windows?
-- But then again, the practical case is ~1-4

--- @return boolean
function M.close_loclist()
    local cur_win = vim.api.nvim_get_current_win() --- @type integer
    local qf_id = vim.fn.getloclist(cur_win, { id = 0 }).id ---@type any
    if qf_id == 0 then
        vim.api.nvim_echo({ { "Window has no loclist", "" } }, false, {})
        return false
    end

    local views = {} --- @type vim.fn.winsaveview.ret|nil[]
    local is_loclist_open = false

    local function win_check(win)
        local wintype = vim.fn.win_gettype(win)
        if wintype == "quickfix" then
            if win == cur_win then
                local qf_err = "Cannot close loclist from a quickfix window"
                vim.api.nvim_echo({ { qf_err, "" } }, false, {})
                return false
            end

            views[win] = vim.api.nvim_win_call(win, vim.fn.winsaveview)
            return true
        end

        if wintype == "loclist" then
            local win_qf_id = vim.fn.getloclist(cur_win, { id = 0 }).id ---@type integer
            if win_qf_id == qf_id then
                is_loclist_open = true
                return true
            end

            views[win] = vim.api.nvim_win_call(win, vim.fn.winsaveview)
            return true
        end

        if wintype == "" then views[win] = vim.api.nvim_win_call(win, vim.fn.winsaveview) end
        return true
    end

    for _, win in pairs(vim.api.nvim_tabpage_list_wins(0)) do
        if not win_check(win) then return false end
    end

    if not is_loclist_open then return false end

    vim.api.nvim_cmd({ cmd = "lcl" }, {})

    for _, w in pairs(vim.api.nvim_tabpage_list_wins(0)) do
        adjust_view(w, views)
    end

    return true
end

-- TODO: Move this and its helper function to utils
--- @return boolean
function M.close_win_restview(list_win)
    vim.validate("list_win", list_win, "number")

    if not vim.api.nvim_win_is_valid(list_win) then
        vim.api.nvim_echo({ { "Win " .. list_win .. " is invalid", "" } }, false, {})
        return false
    end

    local views = {} --- @type vim.fn.winsaveview.ret|nil[]

    local function win_check(win)
        if win == list_win then return end

        local wintype = vim.fn.win_gettype(win)
        if wintype == "" or wintype == "quickfix" or wintype == "loclist" then
            views[win] = vim.api.nvim_win_call(win, vim.fn.winsaveview)
        end
    end

    for _, win in pairs(vim.api.nvim_tabpage_list_wins(0)) do
        win_check(win)
    end

    vim.api.nvim_win_close(list_win, true)

    restore_views(views)

    return true
end

--------------------------------
--- Opening and Closing Maps ---
--------------------------------

Map("n", "cuc", M.close_qflist)
Map("n", "cup", M.open_qflist)
Map("n", "cuu", function()
    if not M.open_qflist() then M.close_qflist() end
end)

Map("n", "coc", M.close_loclist)
Map("n", "cop", M.open_loclist)
Map("n", "coo", function()
    if not M.open_loclist() then M.close_loclist() end
end)

for _, map in pairs({ "cuo", "cou" }) do
    Map("n", map, function()
        M.close_all_loclists()
        M.close_qflist()
    end)
end

----------------------
-- State Management --
----------------------

Map("n", "duc", function()
    M.close_qflist()
    vim.fn.setqflist({}, "r")
end)

Map("n", "dua", function()
    vim.api.nvim_cmd({ cmd = "ccl" }, {})
    vim.fn.setqflist({}, "f")
end)

Map("n", "doc", function()
    M.close_loclist()
    vim.fn.setloclist(vim.api.nvim_get_current_win(), {}, "r")
end)

Map("n", "doa", function()
    M.close_loclist()
    vim.fn.setloclist(vim.api.nvim_get_current_win(), {}, "f")
end)

local severity_map = {
    [vim.diagnostic.severity.ERROR] = "E",
    [vim.diagnostic.severity.WARN] = "W",
    [vim.diagnostic.severity.INFO] = "I",
    [vim.diagnostic.severity.HINT] = "H",
} ---@type table<integer, string>

---@param d table
---@return table
local function convert_diag(d)
    d = d or {}

    local source = d.source and d.source .. ": " or "" ---@type string
    local message = d.message or "" ---@type string

    return {
        bufnr = d.bufnr,
        col = d.col and (d.col + 1) or nil,
        end_col = d.end_col and (d.end_col + 1) or nil,
        end_lnum = d.end_lnum and (d.end_lnum + 1) or nil,
        filename = vim.fn.bufname(d.bufnr),
        lnum = d.lnum + 1,
        nr = tonumber(d.code), -- TODO: Unsure how this formats
        text = source .. message,
        type = severity_map[d.severity],
        valid = 1,
    }
end

--- PERF: For highest severity, use diagnostic.get once then iterate manually. Can avoid a lot
--- of logic that way
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

    -- This guarantees being at the end of the stack and a new qflist. Does push down
    -- Stick with this behavior, then have yUi or whatever be overwrite current
    vim.fn.setqflist({}, " ", { nr = "$" })
    -- vim.fn.setqflist({}, "r", { title = "get_diags" })
    vim.fn.setqflist(diags_for_qflist, "a")
    M.open_qflist()
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
        M.open_loclist()
    else
        last_grep = pattern
        M.open_qflist()
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

-- TODO: Put code in here to resize the qflist for the list history ones
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
        -- TODO: Going left on chistory in no entries cuts off improperly
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

return M
