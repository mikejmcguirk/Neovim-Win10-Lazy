local api = vim.api
local fn = vim.fn

---@class farsight.search.HlInfo
---@field [1] integer Length
---@field [2] integer[] Start rows
---@field [3] integer[] Start cols
---@field [4] integer[] Fin rows
---@field [5] integer[] Fin cols

-- TODO: Should be an opt as well
local TIMEOUT = 500

local HL_SEARCH_DIM_STR = "FarsightJumpDim"

api.nvim_set_hl(0, HL_SEARCH_DIM_STR, { default = true, link = "Comment" })

local nvim_get_hl_id_by_name = api.nvim_get_hl_id_by_name
local hl_dim = nvim_get_hl_id_by_name(HL_SEARCH_DIM_STR)

local group = api.nvim_create_augroup("farsight-search-hl", {})
local search_ns = api.nvim_create_namespace("farsight-search-hl")
local dim_ns = api.nvim_create_namespace("farsight-search-dim")

---@param cmdprompt string
---@param cmdline string
---@return boolean, farsight.search.HlInfo
local function get_hl_info_jit(cmdprompt, cmdline)
    local tn = require("farsight.util")._table_new
    ---@type farsight.search.HlInfo
    local hl_info = { 0, tn(64, 0), tn(64, 0), tn(64, 0), tn(64, 0) }

    local hl_rows = hl_info[2]
    local hl_cols = hl_info[3]
    local hl_fin_rows = hl_info[4]
    local hl_fin_cols = hl_info[5]

    local call = vim.call
    local count1 = vim.v.count1
    local ffi_c = require("ffi").C
    local min = math.min

    local fwd = cmdprompt == "/"
    local flags = fwd and "nWz" or "nWb"
    -- TODO: Checked for wrapped bottom fill row. Add this check to puc Lua as well.
    local stop_row = fwd and call("line", "w$") or call("line", "w0")
    local ok, _ = pcall(fn.search, cmdline, flags, stop_row, TIMEOUT, function()
        if count1 <= 1 then
            hl_rows[#hl_rows + 1] = call("line", ".")

            local col = call("col", ".")
            -- Empty lines and \n chars can be matched on
            -- search() can match on \n characters and empty lines. Subtract one from col("$"), which
            -- is end-exclusive, to prevent OOB col starts
            col = min(col, call("col", "$") - 1)
            hl_cols[#hl_cols + 1] = col

            hl_fin_rows[#hl_fin_rows + 1] = ffi_c.search_match_lines --[[ @as integer ]]
            hl_fin_cols[#hl_fin_cols + 1] = ffi_c.search_match_endcol --[[ @as integer ]]

            hl_info[1] = hl_info[1] + 1
            return 1
        else
            count1 = count1 - 1
            return 1
        end
    end)

    local len_hl_info = hl_info[1]
    if ok and hl_info[1] > 0 then
        for i = 1, len_hl_info do
            -- search_match_lines is the difference from the match's start
            hl_fin_rows[i] = hl_rows[i] + hl_fin_rows[i]
        end

        return true, hl_info
    end

    return false, hl_info
end

---@param cmdprompt string
---@param cmdline string
---@return boolean, farsight.search.HlInfo
local function get_hl_info_puc(cmdprompt, cmdline)
    local tn = require("farsight.util")._table_new
    ---@type farsight.search.HlInfo
    local hl_info = { 0, tn(64, 0), tn(64, 0), tn(64, 0), tn(64, 0) }

    local hl_rows = hl_info[2]
    local hl_cols = hl_info[3]
    local hl_fin_rows = hl_info[4]
    local hl_fin_cols = hl_info[5]

    local call = vim.call
    local min = math.min

    local count1 = vim.v.count1
    local fwd = cmdprompt == "/"
    local s_flags = fwd and "nWz" or "nWb"
    local f_flags = fwd and "nWze" or "nWbe"
    local stop_row = fwd and call("line", "w$") or call("line", "w0")
    local ok_s, _ = pcall(fn.search, cmdline, s_flags, stop_row, TIMEOUT, function()
        if count1 <= 1 then
            hl_rows[#hl_rows + 1] = call("line", ".")

            local col = call("col", ".")
            -- Get now since we don't need to pull these lines later
            -- search() can match on \n characters and empty lines. Subtract one from col("$"), which
            -- is end-exclusive, to prevent OOB col starts
            col = min(col, call("col", "$") - 1)
            hl_cols[#hl_cols + 1] = col

            hl_info[1] = hl_info[1] + 1
            return 1
        else
            count1 = count1 - 1
        end
    end)

    local len_hl_info = hl_info[1]
    if not ok_s or len_hl_info < 1 then
        return false, hl_info
    end

    local ok_f, _ = pcall(fn.search, cmdline, f_flags, stop_row, TIMEOUT, function()
        if count1 <= 1 then
            hl_fin_rows[#hl_fin_rows + 1] = call("line", ".")
            hl_fin_cols[#hl_fin_cols + 1] = call("col", ".")
            return 1
        else
            count1 = count1 - 1
            return 1
        end
    end)

    if not ok_f then
        return false, hl_info
    end

    -- The backwards end iteration can create issues with zero-length results.
    local count_hl_info = #hl_info
    for i = 2, count_hl_info do
        if #hl_info[i] ~= len_hl_info then
            return false, hl_info
        end
    end

    return true, hl_info
end

local get_hl_info = (function()
    if require("farsight._common").has_ffi_search_tracking() then
        return get_hl_info_jit
    else
        return get_hl_info_puc
    end
end)()

---@param buf integer
---@param dim boolean
---@param dim_rows integer[]
local function checked_set_dim_row_extmarks(buf, dim, dim_rows)
    if not dim then
        return
    end

    local nvim_buf_set_extmark = api.nvim_buf_set_extmark
    local extmark_opts = {
        end_col = 0,
        hl_eol = true,
        hl_group = hl_dim,
        priority = 999,
    }

    for row, _ in pairs(dim_rows) do
        extmark_opts.end_line = row + 1
        pcall(nvim_buf_set_extmark, buf, dim_ns, row, 0, extmark_opts)
    end
end

---@param buf integer
---@param hl_info farsight.search.HlInfo
local function set_search_extmarks(buf, hl_info)
    local len_hl_info = hl_info[1]
    local hl_rows = hl_info[2]
    local hl_cols = hl_info[3]
    local hl_fin_rows = hl_info[4]
    local hl_fin_cols = hl_info[5]

    local start = 1
    if api.nvim_get_option_value("incsearch", { scope = "global" }) then
        start = 2
        pcall(api.nvim_buf_set_extmark, buf, search_ns, hl_rows[1], hl_cols[1], {
            priority = 1000,
            hl_group = "IncSearch",
            strict = false,
            end_row = hl_fin_rows[1],
            end_col = hl_fin_cols[1],
        })
    end

    local extmark_opts = {
        priority = 1000,
        hl_group = "Search",
        strict = false,
    }

    for i = start, len_hl_info do
        extmark_opts.end_row = hl_fin_rows[i]
        extmark_opts.end_col = hl_fin_cols[i]
        pcall(api.nvim_buf_set_extmark, buf, search_ns, hl_rows[i], hl_cols[i], extmark_opts)
    end
end

---@param hl_info farsight.search.HlInfo
---@param dim boolean
---@return table<integer, boolean>
local function checked_get_dim_rows(hl_info, dim)
    -- LOW: Is this the most efficient way to do this?
    local rows = {} ---@type table<integer, boolean>
    if not dim then
        return rows
    end

    local len_hl_info = hl_info[1]
    local hl_rows = hl_info[2]
    local hl_fin_rows = hl_info[4]

    for i = 1, len_hl_info do
        local row = hl_rows[i]
        local fin_row = hl_fin_rows[i]
        for j = row, fin_row do
            rows[j] = true
        end
    end

    return rows
end

---Edits hl_info in place
---@param buf integer
---@param hl_info farsight.search.HlInfo
local function adjust_fin_cols(buf, hl_info)
    local len_hl_info = hl_info[1]
    local hl_fin_rows = hl_info[4]
    local hl_fin_cols = hl_info[5]

    local get_utf_codepoint = require("farsight._util_char")._get_utf_codepoint
    local min = math.min
    local nvim_buf_get_lines = api.nvim_buf_get_lines
    local str_byte = string.byte

    local last_row = -1
    local line = ""

    for i = 1, len_hl_info do
        local row = hl_fin_rows[i]
        if last_row ~= row then
            -- Don't want to persist cache because that starts making too many assumptions about
            -- state. Also don't want to eagerly pull all lines because the underlying C code
            -- marshals per line
            line = nvim_buf_get_lines(buf, row, row + 1, false)[1]
            last_row = row
        end

        local len_line = #line
        if len_line > 0 then
            -- hl_fin_cols should still be one-indexed
            -- Handle results on \n chars and zero length lines
            local fin_col_1 = min(hl_fin_cols[i], len_line)
            local b1 = str_byte(line, fin_col_1) or 0
            local _, len_char = get_utf_codepoint(line, b1, fin_col_1)
            hl_fin_cols[i] = fin_col_1 + len_char - 1 -- Now set extmark indexing
        else
            hl_fin_cols[i] = 1
        end
    end
end

---Edits hl_info in place
---@param hl_info farsight.search.HlInfo
local function hl_info_cleanup(hl_info)
    local len_hl_info = hl_info[1]
    local hl_rows = hl_info[2]
    local hl_cols = hl_info[3]
    local hl_fin_rows = hl_info[4]
    local hl_fin_cols = hl_info[5]

    for i = 1, len_hl_info do
        if hl_fin_cols[i] < hl_cols[i] then
            hl_fin_cols[i] = hl_cols[i]
        end
    end

    -- Except for fin_cols, set values to extmark indexing
    for i = 1, len_hl_info do
        hl_rows[i] = hl_rows[i] - 1
        hl_cols[i] = hl_cols[i] - 1
        hl_fin_rows[i] = hl_fin_rows[i] - 1
    end
end

---@param cmdprompt string
---@param cmdline string
---@param hl_info farsight.search.HlInfo
local function echo_no_ok(cmdprompt, cmdline, hl_info)
    -- TODO: This should be hidden behind a debug flag or something
    local err_tbl = {}

    err_tbl[#err_tbl + 1] = "Prompt: " .. cmdprompt
    err_tbl[#err_tbl + 1] = ", Pattern: " .. cmdline
    err_tbl[#err_tbl + 1] = ", Total length: " .. hl_info[1]
    err_tbl[#err_tbl + 1] = ", #Start rows: " .. #hl_info[2]
    err_tbl[#err_tbl + 1] = ", #Start cols: " .. #hl_info[3]
    err_tbl[#err_tbl + 1] = ", #Fin Rows: " .. #hl_info[4]
    err_tbl[#err_tbl + 1] = ", #Fin Cols: " .. #hl_info[5]

    local err_str = table.concat(err_tbl, "")
    api.nvim_echo({ { err_str, "ErrorMsg" } }, true, {})
end

---@param buf integer
---@param dim boolean
local function checked_clear_namespaces(buf, dim)
    api.nvim_buf_clear_namespace(buf, search_ns, 0, -1)
    if dim then
        api.nvim_buf_clear_namespace(buf, dim_ns, 0, -1)
    end
end

---@param cmdprompt string
---@param cmdline_raw string
---@return string, string
local function parse_search_offset(cmdprompt, cmdline_raw)
    if #cmdline_raw == 0 then
        return "", ""
    end

    local str_byte = string.byte
    local prompt_byte = str_byte(cmdprompt)

    local i = 1
    local len = #cmdline_raw
    local escaping = false
    while i <= len do
        local c = str_byte(cmdline_raw, i)
        if escaping then
            escaping = false
        elseif c == 0x5C then
            escaping = true
        elseif c == prompt_byte then
            local cmdline = string.sub(cmdline_raw, 1, i - 1)
            local offset = string.sub(cmdline_raw, i + 1)
            return cmdline, offset
        end

        i = i + 1
    end

    return cmdline_raw, ""
end

---@param win integer
---@param buf integer
---@param prompt string
---@param opts farsight.search.SearchOpts
local function display_search_highlights(win, buf, prompt, opts)
    local cmdprompt = fn.getcmdprompt()
    if cmdprompt ~= prompt then
        -- If this actually happens, I would want as much info about Nvim's state as possible, so
        -- don't do anything to disturb it.
        return
    end

    -- TODO: This should not rely on ev.buf
    api.nvim_buf_clear_namespace(buf, search_ns, 0, -1)
    local cmdline_raw = fn.getcmdline()
    if cmdline_raw == "" then
        checked_clear_namespaces(buf, opts.dim)
        api.nvim__redraw({ valid = true, win = win })
        return
    end

    local cmdline, _ = parse_search_offset(cmdprompt, cmdline_raw)
    local ok, hl_info = get_hl_info(cmdprompt, cmdline)
    local len_hl_info = hl_info[1]
    if not ok then
        checked_clear_namespaces(buf, opts.dim)
        if len_hl_info > 0 then
            echo_no_ok(cmdprompt, cmdline, hl_info)
        end

        api.nvim__redraw({ valid = true, win = win })
        return
    end

    hl_info_cleanup(hl_info)
    adjust_fin_cols(buf, hl_info)
    local dim_rows = checked_get_dim_rows(hl_info, opts.dim)

    checked_clear_namespaces(buf, opts.dim)
    set_search_extmarks(buf, hl_info)
    checked_set_dim_row_extmarks(buf, opts.dim, dim_rows)

    api.nvim__redraw({ valid = true, win = win })
end

local function del_search_listener()
    local autocmds = api.nvim_get_autocmds({ group = group })
    for _, autocmd in ipairs(autocmds) do
        api.nvim_del_autocmd(autocmd.id)
    end
end

---@param win integer
---@param buf integer
---@param prompt string
---@param opts farsight.search.SearchOpts
local function create_search_listener(win, buf, prompt, opts)
    api.nvim_create_autocmd("CmdlineChanged", {
        group = group,
        desc = "Highlight search terms",
        callback = function()
            display_search_highlights(win, buf, prompt, opts)
            -- TODO: Pass opts into the top level function, display labels and set them up
            -- if true
        end,
    })
end

---@param win integer
---@param dim boolean
local function checked_ns_set(win, dim)
    api.nvim__ns_set(search_ns, { wins = { win } })
    if dim then
        api.nvim__ns_set(dim_ns, { wins = { win } })
    end
end

---@param cur_buf integer
---@param opts farsight.search.SearchOpts
local function resolve_search_opts(cur_buf, opts)
    vim.validate("opts", opts, "table")
    local ut = require("farsight.util")

    opts.dim = ut._use_gb_if_nil(opts.dim, "farsight_search_dim", cur_buf)
    opts.dim = ut._resolve_bool_opt(opts.dim, false)

    -- TODO: Add keepjumps option. How to make work with feedkeys?
end

local M = {}

---@class farsight.search.SearchOpts
---Dim lines with targeted characters (Default: `false`)
---@field dim? boolean

---@param fwd boolean
---@param opts? farsight.search.SearchOpts
function M.search(fwd, opts)
    opts = opts and vim.deepcopy(opts) or {}
    local cur_win = api.nvim_get_current_win()
    local cur_buf = api.nvim_win_get_buf(cur_win)
    resolve_search_opts(cur_buf, opts)

    -- TODO: Check if we are dot repeating or in a macro. If so, check if the "/" register has
    -- contents. If so, search for that and return.
    -- NOTE: Forward searches operate until just before the term. Backard searches operate until
    -- and including the beginning of the term.
    -- Since this is a direct search, wrapscan needs to be handled

    checked_clear_namespaces(0, opts.dim)
    checked_ns_set(cur_win, opts.dim)

    local prompt = fwd and "/" or "?"
    create_search_listener(cur_win, cur_buf, prompt, opts)

    -- pcall so that pressing Ctrl+c does not enter error
    local ok, pattern_raw = pcall(fn.input, prompt)

    del_search_listener()
    local pattern, _ = parse_search_offset(prompt, pattern_raw)
    if not ok or pattern == "" then
        checked_clear_namespaces(cur_buf, opts.dim)
        api.nvim_echo({ { "" } }, false, {}) -- LOW: I wish there was a less blunt way
        return
    end

    if opts.dim then
        api.nvim_buf_clear_namespace(cur_buf, dim_ns, 0, -1)
    end

    -- TODO: What is the difference between typed and mapped?
    api.nvim_feedkeys(vim.v.count1 .. prompt .. pattern_raw .. "\r", "nx", false)
    -- Running this right before running search can cause flicker
    api.nvim_buf_clear_namespace(cur_buf, search_ns, 0, -1)
end

function M.get_ns()
    return search_ns
end

return M

-- SEARCH
--
-- TODO: Handle the additional wrap filled bottom row
-- TODO: Incsearch specific highlighting should definitely only show if that option is on, but
-- shoudl Search highlighting always show? Or just the labels? IMO, I like the search highlighting.
-- I don't like the Incsearch highlighting. But I use the base Incsearch highlighting for a lot of
-- things that aren't Incsearch. And I think tying the search highlighting here to non-default hl
-- groups is a fundamental mistake.
-- TODO: Need to confirm, but I think the various searches all only consider the first result
-- within a fold. Want to make sure search() and the /? cmds behave the same. Also need to make
-- sure that Incsearch highlights properly.
-- TODO: Does the search feedkeys handle fdo?
-- TODO: Perhaps one-way "Search" highlights are always true, and the alt-color Incsearch hl plus
-- backward "Search" highlights are based on the Incsearch option. This would play better with a
-- future Ctrl-T/G implementation
-- TODO: Handle repeats and macros. I think you just get vcount1 and feed an empty search string
-- to make it repeat. Macros might not be able to get around having to input, but highlights can
-- still be disabled.
-- TODO: Verify Vim's internal timeout for search
-- TODO: Test visual mode behavior
-- TODO: Test omode behavior
-- TODO: DOCUMENT: Highlighting only one way is intentional.
-- TODO: DOCUMENT: Limitation: Ctrl-T/Ctrl-G navigation with Incsearch are not supported
-- TODO: DOCUMENT: Make some sort of useful documentation out of my error with running nohlsearch
-- on cmdline enter
-- TODO: DOCUMENT: cpo c is respected
--
-- LABELS
--
-- TODO: Labels should not accept if the cursor is not in the last position. Maybe don't even
-- show labels, or show them with a different highlight. Prevents issue with going back and
-- TODO: The default highlights here have to work with CurSearch and IncSearch. Being that this is
-- the lowest degrees of freedom module, it is the anchor point for the others.
-- modifying the search
-- TODO: Should have fold behavior similar to Csearch. Either skip folds entirely, or affix labels
-- in a reasonable manner. If there's no good way to apply labels, I'm fine with always skipping.
-- TODO: Label jumps should have an on_jump option. The default should be a reasonable application
-- of fdo
-- Should saving searchforward/histadd/searchreg for labels be an option or something handled in
-- on_jump?
-- Labels should only go in the direction of the search. Want to keep possibilities down so
-- useful labeling can be done more quickly. Omni-directional should be handled in jump
--
-- TODO: There might be interesting stuff we can do with \%V (search inside the visual area only)
-- On the baseline level, if the user wants to make that custom mapping, where you exit visual
-- mode (update the marks) and then run search with that magic pre-filled, it should do so
-- smoothly

-- MID: Is winhighlight properly respected?
-- MID: The built-in search highlights zero length lines. This comes up when dealing with
-- zero-length assertions/incomplete patterns that cover them. AFAICT, doing this would require
-- stepping through the range to see if there are zero lines within it and marking those lines for
-- virtual text overlays. Would be good for feature equivalence, but poor effort/value ratio. Not
-- a showstopper.
-- MID: Results off-screen should be reported. Intuitively, it should be a virtual text overlay
-- on the top/bottom of the window. Major blocker: What fallbacks do I use if the overlay would
-- cover a label? Easier version: Only show this if no on-screen results.
-- - Is searchcount() useful here?
-- MID: Go through the tests and see if any of the use cases give my highlighting trouble
-- - test/unit/search_spec.lua
-- - test/old/testdir/test_search.vim
-- MID: For <C-t>/<C-g> navigation:
-- - Path dependent on indicator for searches above/below the screen. Automatic screen movement
-- will not be implemented
-- - Inccsearch must be on
-- - The keys have to be remapped
--   - Needs to be a solution for entering them if the user wishes
--   - Should be able to do as part of the autocmd build-up/teardown
-- - Pressing forward moves you to the next pos
-- - Moving backwards requires getting the previous one
-- - Cursor state should actually be updated
--   - The old one should be saved
-- - When input is completed, we need to know if we have moved to a new cursor state we want to
-- keep
--   - Probably needs to be module-level state since input only returns text. Though we can use
--   pattern == "" as an indicator we need to go back
--   - If our incsearch returns no results, the original view should be restored
--   - If not, restore the old one
--   - If so, the search cmd needs to not advance past the saved position (I'm not clear on
--   exactly how you do this)
--
--
-- MAYBE: Rather than using the inner search to walk the cursor for highlighting, you could use
-- Folke's ffi hack to pull out the ending position. But since this is not  an api or fn
-- guarantee, the variable name is liable to change, or its internal behavior altered. I'm worried
-- about introducing that surface area for something that would probably be more performant, but
-- is not necessary. Would not go forward with this without some really non-trivial perf difference
--
-- NON: Do not re-implement cursor movement for IncSearch. This is performance intensive, creates
-- complexity surface area, and is visually too busy.
-- NON: Multi-window searching. Creates weird questions with wrap scan. Creates a problem where
-- even if you replicate the proper window ordering, it's not necessarily intuitive to which
-- window you will jump to.
-- NON: Multi-directional searching. Creates weird questions with how the v:vars are updated.
-- Jump handles this.
-- NON: Grafting this on top of the default search. This would require listeners/autocmds to
-- always be running, which means persistent state + the plugin insisting on itself. Harder to
-- turn off if unwanted. It also means that I don't have full-stepwise control over the relevant
-- events.
