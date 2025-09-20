--- FUTURE: Create updated quickfixtextfunc

------------------
-- CAPABILITIES --
------------------

--- GLOBAL CHECKLIST:
--- - Do all functions have a reasonable default sort?
--- - Are window height updates triggered where appropriate?
--- - Are the public/"private exposed"/private settings correct?
--- - Does everything have a plug?
--- - Do maps and plugs have desc fields?

--- TODO: More visibility for cdo/cfdo. Use bang by default?
--- TODO: Resize cmd
--- TODO: Copy list. no count = to next. Count = after list
--- TODO: If the list is already open, an open command should not trigger a re-size. I had ideas
--- about this in other commands, but a manual resize should just be triggered
--- TODO: Have some kind of shortcut to make the list taller. Make sure it preserves view
---     Was thinking qq for toggle, qQ for resize, maybe q<c-Q> to make bigger?
--- TODO: Go thorugh this file and get all old functionalities. Need wrap commands and
--- state management. Note history should adjust height
--- Maybe grep shouldn't be e, because deleting lists is going to be a common op, probably need
--- qe and le to be available.  qd suks. ll sucks.  qt and lt not that great.
--- A reversal of this though is that if you have qie as diag errors, then accidently doing qe
--- would be unfortunate. It might be relevant to put qd as the map and then not map anything
--- else to d
--- Feels roughly like qd for delete current/count list and qD to delete all. But also a potential
--- fat finger. Maybe have separate keys for current and specific lists
--- TODO: look at the issue/PR lists for the various qf plugins to see what people want

--- MAYBE: Should open/close cmds also run wincmd =?
--- MAYBE: Incremental preview of cdo/cfdo changes
--- MAYBE: General cmd parsing: https://github.com/niuiic/quickfix.nvim
--- MAYBE: Publish qf items as diagnostics
---     Semi related, but it would be cool to run make or a test and have the diagnostics publish
---
--- MAYBE: https://github.com/Zeioth/compiler.nvim
--- MAYBE: https://github.com/ahmedkhalf/project.nvim
--- MAYBE: https://github.com/stevearc/overseer.nvim

--- DOCUMENT: Buf greps use external grep
--- DOCUMENT: qf Buf Grep is all bufs, ll Buf Grep is current buf only
--- DOCUMENT: rg handles true multi-line greps. For programs that don't, or is used as a fallback

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
--- show current stack nr (chistory/lhistory)
--- stack nr statusline component?
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

-- TODO: The ftplugin maps should be moved to their own file, and a g_variable in the plugin's
-- ftplugin file should determine if they are mapped. Put this function documentation in the
-- file to ftplugin map
-- TODO: The g variable should either map the defaults or not. Plug mappings/documentation can be
-- provided if the user wants to do it custom

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

-- NOTE: Incomplete qf maps are nop'd to prevent falling back to other maps
local nofallback_desc = "Prevent fallback to other mappings"
vim.api.nvim_set_keymap("n", "<leader>q", "<nop>", { noremap = true, desc = nofallback_desc })
vim.api.nvim_set_keymap("n", "<leader>l", "<nop>", { noremap = true, desc = nofallback_desc })

--- @param win integer
--- @return boolean, [string, string]|nil
local function protected_win_close(win)
    if not vim.api.nvim_win_is_valid(win) then
        return false, { "Window " .. win .. " is invalid", "WarningMsg" }
    end

    local tabpage_list = vim.api.nvim_list_tabpages()
    local win_tabpage = vim.api.nvim_win_get_tabpage(win)
    local tab_wins = vim.api.nvim_tabpage_list_wins(win_tabpage)
    if #tabpage_list == 1 and #tab_wins == 1 then
        return false, { "Cannot close the last window", "" }
    end

    local ok, err = vim.api.nvim_win_close(win, true)
    if not ok then
        local msg = err or ("Unknown error closing window " .. win)
        return false, { msg, "ErrorMsg" }
    end

    return true
end

--- @param win integer
--- @return boolean
local function close_qf_win(win, print_errors)
    local ok, err = protected_win_close(win) --- @type boolean, [string, string]|nil
    if ok then
        return true
    end

    if err == "Cannot close the last window" then
        local buf = vim.api.nvim_win_get_buf(win) --- @type integer
        if not vim.api.nvim_buf_is_valid(buf) then
            local msg = "Bufnr " .. buf .. " in window " .. win .. " is not valid" --- @type string
            vim.api.nvim_echo({ { msg, "ErrorMsg" } }, true, { err = true })
        end

        vim.api.nvim_buf_delete(buf, {})
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

local function restore_view(win, view)
    if not vim.api.nvim_win_is_valid(win) then
        return
    end

    --- @type integer
    local cur_topline = vim.api.nvim_win_call(win, function()
        return vim.fn.line("w0")
    end)

    if view.topline == cur_topline then
        return
    end

    vim.api.nvim_win_call(win, function()
        vim.fn.winrestview(view)
    end)
end

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

    for _, tab in ipairs(tabpages) do
        local loclist_wins = {} --- @type integer[]
        local views = {} --- @type vim.fn.winsaveview.ret|nil[]

        for _, win in ipairs(vim.api.nvim_tabpage_list_wins(tab)) do
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

        for _, lwin in pairs(loclist_wins) do
            close_qf_win(lwin, false)
            closed_loc_list = true
        end

        if #loclist_wins > 0 then
            restore_views(views)
        end
    end

    return closed_loc_list
end

-- TODO: There should be a setting for whether or not to turn these autocmds on
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
--- @return integer
local function get_list_height(opts)
    opts = opts or {}

    if opts.height then
        return opts.height
    end

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

    local cur_win = opts.keep_win and vim.api.nvim_get_current_win() or -1 --- @type integer
    local views = {} --- @type vim.fn.winsaveview.ret|nil[]
    local is_loclist_open = false --- @type boolean

    local function win_check(win)
        local wintype = vim.fn.win_gettype(win) --- @type string
        if wintype == "quickfix" then
            return false
        elseif wintype == "loclist" then
            is_loclist_open = true
        elseif wintype == "" then
            views[win] = vim.api.nvim_win_call(win, vim.fn.winsaveview)
        end

        return true
    end

    for _, win in pairs(vim.api.nvim_tabpage_list_wins(0)) do
        if not win_check(win) then
            return false
        end
    end

    if is_loclist_open then
        M.close_all_loclists({ cur_tab = true })
    end

    local list_height = get_list_height({ height = opts.height }) --- @type integer
    --- @diagnostic disable: missing-fields
    vim.api.nvim_cmd({ cmd = "copen", count = list_height, mods = { split = "botright" } }, {})

    restore_views(views)

    if vim.api.nvim_win_is_valid(cur_win) then
        vim.api.nvim_set_current_win(cur_win)
    end

    return true
end

--- @param win integer
--- @param views vim.fn.winsaveview.ret[]
--- @return integer|nil
local function find_qf_wincheck(win, views)
    local wintype = vim.fn.win_gettype(win) --- @type string
    if wintype == "quickfix" then
        return win
    end

    if wintype == "" or wintype == "loclist" then
        views[win] = vim.api.nvim_win_call(win, vim.fn.winsaveview)
    end
end

--- @return boolean
function M.close_qflist()
    local qf_win = nil --- @type integer|nil
    local views = {} --- @type vim.fn.winsaveview.ret[]

    for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
        local checked_win = find_qf_wincheck(win, views) --- @type integer|nil
        qf_win = checked_win and checked_win or qf_win
    end

    if not qf_win then
        return false
    end

    close_qf_win(qf_win, true)
    restore_views(views)

    return true
end

--- @return boolean
-- TODO: This should take in a height value. Make sure to update get_resizelist when added
function M.resize_qflist()
    local qf_win = nil --- @type integer|nil
    local views = {} --- @type vim.fn.winsaveview.ret[]

    for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
        local checked_win = find_qf_wincheck(win, views) --- @type integer|nil
        qf_win = checked_win and checked_win or qf_win
    end

    if not qf_win then
        return false
    end

    local height = get_list_height({ win = qf_win })
    vim.api.nvim_win_set_height(qf_win, height)
    restore_views(views)

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

    local views = {} --- @type vim.fn.winsaveview.ret[]
    local qf_win = nil --- @type integer|nil
    local function win_check(win)
        local wintype = vim.fn.win_gettype(win)

        if wintype == "quickfix" then
            qf_win = win
            return true
        elseif wintype == "loclist" then
            if win == cur_win or vim.fn.getloclist(win, { id = 0 }).id == qf_id then
                return false
            end
        end

        if wintype == "" or wintype == "loclist" then
            views[win] = vim.api.nvim_win_call(win, vim.fn.winsaveview)
        end

        return true
    end

    for _, win in pairs(vim.api.nvim_tabpage_list_wins(0)) do
        if not win_check(win) then
            return false
        end
    end

    if qf_win then
        M.close_win_restview(qf_win)
    end

    local list_height = get_list_height({ height = opts.height, is_loclist = true, win = cur_win })
    vim.api.nvim_cmd({ cmd = "lopen", count = list_height }, {})
    restore_views(views)
    if opts.keep_win and vim.api.nvim_win_is_valid(cur_win) then
        vim.api.nvim_set_current_win(cur_win)
    end

    return true
end

-- PERF: Would it be faster to just iterate once to see if we have a loclist to close, then
-- iterate again to get the info to save? Applies to all open/closes
-- Maybe a way to think about it - How does each approach scale with a lot of windows?
-- But then again, the practical case is ~1-4

--- @param cur_win integer
--- @param qf_id integer
--- @param win integer
--- @param views vim.fn.winsaveview.ret[]
--- @return boolean, integer|nil
local function find_loclist_wincheck(cur_win, qf_id, win, views)
    local wintype = vim.fn.win_gettype(win)
    if wintype == "quickfix" and win == cur_win then
        local qf_err = "Cannot close loclist from a quickfix window"
        vim.api.nvim_echo({ { qf_err, "" } }, false, {})
        return false, nil
    elseif wintype == "loclist" and vim.fn.getloclist(win, { id = 0 }).id == qf_id then
        return true, win
    end

    if wintype == "" or wintype == "quickfix" or wintype == "loclist" then
        views[win] = vim.api.nvim_win_call(win, vim.fn.winsaveview)
    end

    return true, nil
end

--- @return boolean
function M.close_loclist()
    local cur_win = vim.api.nvim_get_current_win() --- @type integer
    local qf_id = vim.fn.getloclist(cur_win, { id = 0 }).id ---@type integer
    if qf_id == 0 then
        vim.api.nvim_echo({ { "Window has no loclist", "" } }, false, {})
        return false
    end

    local views = {} --- @type vim.fn.winsaveview.ret[]
    local loclist_win = nil --- @type integer|nil
    for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
        --- @type boolean, integer|nil
        local ok, found_win = find_loclist_wincheck(cur_win, qf_id, win, views)
        if not ok then
            return false
        end

        loclist_win = found_win and found_win or loclist_win
    end

    if not loclist_win then
        return false
    end

    close_qf_win(loclist_win, true)
    restore_views(views)
    return true
end

--- @return boolean
function M.resize_loclist()
    local cur_win = vim.api.nvim_get_current_win() --- @type integer
    local qf_id = vim.fn.getloclist(cur_win, { id = 0 }).id ---@type integer
    if qf_id == 0 then
        vim.api.nvim_echo({ { "Window has no loclist", "" } }, false, {})
        return false
    end

    local views = {} --- @type vim.fn.winsaveview.ret[]
    local loclist_win = nil --- @type integer|nil
    for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
        --- @type boolean, integer|nil
        local ok, found_win = find_loclist_wincheck(cur_win, qf_id, win, views)
        if not ok then
            return false
        end

        loclist_win = found_win and found_win or loclist_win
    end

    if not loclist_win then
        return false
    end

    local height = get_list_height({ is_loclist = true, win = loclist_win })
    vim.api.nvim_win_set_height(loclist_win, height)
    restore_views(views)
    return true
end

--- @return boolean
function M.close_win_restview(target_win)
    vim.validate("target_win", target_win, "number")

    if not vim.api.nvim_win_is_valid(target_win) then
        vim.api.nvim_echo({ { "Win " .. target_win .. " is invalid", "" } }, false, {})
        return false
    end

    local views = {} --- @type vim.fn.winsaveview.ret[]
    local function win_check(win)
        if win == target_win then
            return
        end

        local wintype = vim.fn.win_gettype(win)
        if wintype == "" or wintype == "quickfix" or wintype == "loclist" then
            views[win] = vim.api.nvim_win_call(win, vim.fn.winsaveview)
        end
    end

    local tabpage = vim.api.nvim_win_get_tabpage(target_win)
    for _, win in ipairs(vim.api.nvim_tabpage_list_wins(tabpage)) do
        win_check(win)
    end

    close_qf_win(target_win, true)
    restore_views(views)
    return true
end

--- @param target_win integer
--- @return boolean
--- TODO: I'm not convinced this needs to be three separate functions
function M.resize_list_win(target_win)
    vim.validate("list_win", target_win, "number")

    -- TODO: Should throw up error to handle
    if not vim.api.nvim_win_is_valid(target_win) then
        vim.api.nvim_echo({ { "Win " .. target_win .. " is invalid", "" } }, false, {})
        return false
    end

    local target_wintype = vim.fn.win_gettype(target_win)
    if not (target_wintype == "quickfix" or target_wintype == "loclist") then
        vim.api.nvim_echo({ { "Win " .. target_win .. " is non-quickfix", "" } }, false, {})
        return false
    end

    local views = {} --- @type vim.fn.winsaveview.ret|nil[]

    local function win_check(win)
        if win == target_win then
            return
        end

        local wintype = vim.fn.win_gettype(win)
        if wintype == "" or wintype == "quickfix" or wintype == "loclist" then
            views[win] = vim.api.nvim_win_call(win, vim.fn.winsaveview)
        end
    end

    local tabpage = vim.api.nvim_win_get_tabpage(target_win)
    for _, win in ipairs(vim.api.nvim_tabpage_list_wins(tabpage)) do
        win_check(win)
    end

    local is_loclist = target_win == "loclist"
    local height = get_list_height({ is_loclist = is_loclist, win = target_win })
    ---@diagnostic disable-next-line: param-type-mismatch
    vim.api.nvim_win_set_height(target_win, height)

    restore_views(views)

    return true
end

--------------------------------
--- Opening and Closing Maps ---
--------------------------------

Map("n", "cuc", M.close_qflist)
Map("n", "cup", M.open_qflist)
Map("n", "cuu", function()
    if not M.open_qflist() then
        M.close_qflist()
    end
end)

Map("n", "<leader>qQ", M.resize_qflist)

Map("n", "coc", M.close_loclist)
Map("n", "cop", M.open_loclist)
Map("n", "coo", function()
    if not M.open_loclist() then
        M.close_loclist()
    end
end)

Map("n", "<leader>lL", M.resize_loclist)

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
    Map("n", m[1], function()
        qf_scroll_wrapper(m[2], m[3], m[4])
    end)
end

return M
