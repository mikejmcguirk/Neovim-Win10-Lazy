local api = vim.api
local call = vim.call
local fn = vim.fn

---@class farsight.search.HlInfo
---@field [1] integer Length
---@field [2] integer[] Start rows
---@field [3] integer[] Start cols
---@field [4] integer[] Fin rows
---@field [5] integer[] Fin cols

local TIMEOUT = 500

local HL_SEARCH_DIM_STR = "FarsightJumpDim"
api.nvim_set_hl(0, HL_SEARCH_DIM_STR, { default = true, link = "Comment" })

local nvim_get_hl_id_by_name = api.nvim_get_hl_id_by_name
local hl_dim = nvim_get_hl_id_by_name(HL_SEARCH_DIM_STR)

local group = api.nvim_create_augroup("farsight-search-hl", {})
local search_ns = api.nvim_create_namespace("farsight-search-hl")
local dim_ns = api.nvim_create_namespace("farsight-search-dim")

---@param win integer
---@param buf integer
---@param cmdprompt string
---@return string, string, integer, boolean
local function get_search_args(win, buf, cmdprompt)
    if cmdprompt == "/" then
        local common = require("farsight._common")
        local wS = fn.line("w$")
        return "nWz", "nWze", common.get_wrap_checked_bot_row(win, buf, wS)
    end

    return "nWb", "nWbe", fn.line("w0"), true
end

---@return farsight.search.HlInfo
local function create_new_hl_info()
    local tn = require("farsight.util")._table_new
    return { 0, tn(64, 0), tn(64, 0), tn(64, 0), tn(64, 0) }
end

---@param win integer
---@param buf integer
---@param cmdprompt string
---@param cmdline string
---@param opts farsight.search.SearchOpts
---@return boolean, farsight.search.HlInfo, boolean
local function get_hl_info_jit(win, buf, cmdprompt, cmdline, opts)
    local hl_info = create_new_hl_info()
    local hl_rows = hl_info[2]
    local hl_cols = hl_info[3]
    local hl_fin_rows = hl_info[4]
    local hl_fin_cols = hl_info[5]

    local ffi_c = require("ffi").C
    local min = math.min

    local count1 = vim.v.count1
    local flags, _, stop_row, valid = get_search_args(win, buf, cmdprompt)
    local ok, _ = pcall(fn.search, cmdline, flags, stop_row, opts.timeout, function()
        if count1 <= 1 then
            hl_rows[#hl_rows + 1] = call("line", ".")

            local col = call("col", ".")
            -- Because search() can match on empty lines and \n characters, col can be out of
            -- bounds. We aren't getting lines for the start cols, so correct now. Subtract one
            -- from col("$") because it is end-exclusive.
            col = min(col, call("col", "$") - 1)
            hl_cols[#hl_cols + 1] = col

            hl_fin_rows[#hl_fin_rows + 1] = ffi_c.search_match_lines --[[ @as integer ]]
            -- These will be corrected later
            hl_fin_cols[#hl_fin_cols + 1] = ffi_c.search_match_endcol --[[ @as integer ]]

            hl_info[1] = hl_info[1] + 1
            return 1
        else
            count1 = count1 - 1
            return 1
        end
    end)

    if ok then
        local len_hl_info = hl_info[1]
        for i = 1, len_hl_info do
            -- Convert search_match_lines to end cols
            hl_fin_rows[i] = hl_rows[i] + hl_fin_rows[i]
        end

        return true, hl_info, valid
    end

    return false, hl_info, valid
end

---@param win integer
---@param buf integer
---@param cmdprompt string
---@param cmdline string
---@param opts farsight.search.SearchOpts
---@return boolean, farsight.search.HlInfo, boolean
local function get_hl_info_puc(win, buf, cmdprompt, cmdline, opts)
    local hl_info = create_new_hl_info()
    local hl_rows = hl_info[2]
    local hl_cols = hl_info[3]
    local hl_fin_rows = hl_info[4]
    local hl_fin_cols = hl_info[5]

    local min = math.min

    local count1 = vim.v.count1
    local s_flags, f_flags, stop_row, valid = get_search_args(win, buf, cmdprompt)
    local ok_s, _ = pcall(fn.search, cmdline, s_flags, stop_row, opts.timeout, function()
        if count1 <= 1 then
            hl_rows[#hl_rows + 1] = call("line", ".")

            local col = call("col", ".")
            -- Because search() can match on empty lines and \n characters, col can be out of
            -- bounds. We aren't getting lines for the start cols, so correct now. Subtract one
            -- from col("$") because it is end-exclusive.
            col = min(col, call("col", "$") - 1)
            hl_cols[#hl_cols + 1] = col

            hl_info[1] = hl_info[1] + 1
            return 1
        else
            count1 = count1 - 1
        end
    end)

    if not ok_s then
        return false, hl_info, valid
    end

    count1 = vim.v.count1
    local ok_f, _ = pcall(fn.search, cmdline, f_flags, stop_row, opts.timeout, function()
        if count1 <= 1 then
            hl_fin_rows[#hl_fin_rows + 1] = call("line", ".")
            -- These will be corrected later
            hl_fin_cols[#hl_fin_cols + 1] = call("col", ".")
            return 1
        else
            count1 = count1 - 1
            return 1
        end
    end)

    if not ok_f then
        return false, hl_info, valid
    end

    local len_hl_info = hl_info[1]
    -- The backwards end iteration can create issues with zero-length results.
    local count_hl_info = #hl_info
    for i = 2, count_hl_info do
        if #hl_info[i] ~= len_hl_info then
            return false, hl_info, valid
        end
    end

    return true, hl_info, valid
end

local get_raw_hl_info = (function()
    if require("farsight._common").has_ffi_search_globals() then
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
---@param incsearch boolean
local function set_search_extmarks(buf, hl_info, incsearch)
    local len_hl_info = hl_info[1]
    local hl_rows = hl_info[2]
    local hl_cols = hl_info[3]
    local hl_fin_rows = hl_info[4]
    local hl_fin_cols = hl_info[5]

    local start = 1
    if incsearch then
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
    local tn = require("farsight.util")._table_new
    local rows = tn(0, 32) ---@type table<integer, boolean>
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
---@return string
local function get_hl_info_err_str(cmdprompt, cmdline, hl_info)
    local err_tbl = {}

    err_tbl[#err_tbl + 1] = "Prompt: " .. cmdprompt
    err_tbl[#err_tbl + 1] = ", Pattern: " .. cmdline
    err_tbl[#err_tbl + 1] = ", Total length: " .. hl_info[1]
    err_tbl[#err_tbl + 1] = ", #Start rows: " .. #hl_info[2]
    err_tbl[#err_tbl + 1] = ", #Start cols: " .. #hl_info[3]
    err_tbl[#err_tbl + 1] = ", #Fin Rows: " .. #hl_info[4]
    err_tbl[#err_tbl + 1] = ", #Fin Cols: " .. #hl_info[5]

    return table.concat(err_tbl, "")
end

---@param buf integer
---@param dim boolean
local function checked_clear_namespaces(buf, dim)
    api.nvim_buf_clear_namespace(buf, search_ns, 0, -1)
    if dim then
        api.nvim_buf_clear_namespace(buf, dim_ns, 0, -1)
    end
end

---@param win integer
---@param buf integer
---@param dim boolean
---@param valid boolean
local function clear_and_redraw(win, buf, dim, valid)
    checked_clear_namespaces(buf, dim)
    api.nvim__redraw({ valid = valid, win = win })
end

---@param hl_info farsight.search.HlInfo|string
---@param valid boolean
---@param opts farsight.search.SearchOpts
local function handle_hl_info_err(win, buf, hl_info, valid, opts)
    if opts.debug_msgs and type(hl_info) == "string" then
        api.nvim_echo({ { hl_info, "ErrorMsg" } }, true, {})
    end

    clear_and_redraw(win, buf, opts.dim, valid)
end

---@return boolean, farsight.search.HlInfo|string, boolean
local function get_hl_info(win, buf, cmdprompt, cmdline, opts)
    local ok, hl_info, valid = get_raw_hl_info(win, buf, cmdprompt, cmdline, opts)
    if not ok then
        local err_str = get_hl_info_err_str(cmdprompt, cmdline, hl_info)
        return false, err_str, valid
    end

    hl_info_cleanup(hl_info)
    adjust_fin_cols(buf, hl_info)

    return true, hl_info, valid
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
---@param cmdprompt string
---@param incsearch boolean
---@param dim boolean
local function handle_empty_cmdline(win, buf, cmdprompt, incsearch, dim)
    checked_clear_namespaces(buf, dim)
    local _, _, _, valid = get_search_args(win, buf, cmdprompt)
    if incsearch then
        local rev_cmdprompt = cmdprompt == "/" and "?" or "/"
        local _, _, _, rev_valid = get_search_args(win, buf, rev_cmdprompt)
        if rev_valid == false then
            valid = false
        end
    end

    api.nvim__redraw({ valid = valid, win = win })
end

---@param win integer
---@param buf integer
---@param prompt string
---@param opts farsight.search.SearchOpts
local function display_search_highlights(win, buf, prompt, opts)
    local cmdprompt = fn.getcmdprompt()
    if cmdprompt ~= prompt then
        return
    end

    ---@type boolean
    local incsearch = api.nvim_get_option_value("incsearch", { scope = "global" })
    local cmdline_raw = fn.getcmdline()
    if cmdline_raw == "" then
        handle_empty_cmdline(win, buf, cmdprompt, incsearch, opts.dim)
        return
    end

    local cmdline, _ = parse_search_offset(cmdprompt, cmdline_raw)
    local ok, hl_info, valid = get_hl_info(win, buf, cmdprompt, cmdline, opts)
    local rev_ok, rev_hl_info, rev_valid
    if incsearch then
        -- Get rev_hl_info before handling hl_info because we need the valid value in case it is
        -- false. Otherwise, wrapped filler rows might not be redrawn
        local rev_cmdprompt = cmdprompt == "/" and "?" or "/"
        rev_ok, rev_hl_info, rev_valid = get_hl_info(win, buf, rev_cmdprompt, cmdline, opts)
        if rev_valid == false then
            valid = rev_valid
        end

        if (not rev_ok) or type(rev_hl_info) ~= "table" then
            handle_hl_info_err(win, buf, rev_hl_info, valid, opts)
            return
        elseif hl_info[1] == 0 and rev_hl_info[1] == 0 then
            clear_and_redraw(win, buf, opts.dim, valid)
            return
        end
    end

    if (not ok) or type(hl_info) ~= "table" then
        handle_hl_info_err(win, buf, hl_info, valid, opts)
        return
    elseif (not incsearch) and hl_info[1] == 0 then
        clear_and_redraw(win, buf, opts.dim, valid)
        return
    end

    local dim_rows = checked_get_dim_rows(hl_info, opts.dim)
    checked_clear_namespaces(buf, opts.dim)
    set_search_extmarks(buf, hl_info, incsearch)
    checked_set_dim_row_extmarks(buf, opts.dim, dim_rows)
    if incsearch then
        -- Always pass false. Search will not jump here
        set_search_extmarks(buf, rev_hl_info, false)
        -- Reverse IncSearch highlights are not valid targets. Don't dim.
    end

    api.nvim__redraw({ valid = valid, win = win })
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

    opts.debug_msgs = ut._use_gb_if_nil(opts.debug_msgs, "farsight_search_debug_msgs", cur_buf)
    opts.debug_msgs = ut._resolve_bool_opt(opts.debug_msgs, false)

    opts.dim = ut._use_gb_if_nil(opts.dim, "farsight_search_dim", cur_buf)
    opts.dim = ut._resolve_bool_opt(opts.dim, false)

    opts.timeout = ut._use_gb_if_nil(opts.timeout, "farsight_search_timeout", cur_buf)
    if opts.timeout == nil then
        opts.timeout = TIMEOUT
    else
        vim.validate("opts.timeout", opts.timeout, ut._is_int)
    end

    -- TODO: Add keepjumps option. How to make work with feedkeys?
end

local M = {}

---@class farsight.search.SearchOpts
---Dim lines with targeted characters (Default: `false`)
---@field debug_msgs? boolean
---@field dim? boolean
---@field timeout? integer

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

    -- TODO: This looks nicer but might create an extra redraw step. Profile
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

-- TODO: The cursor location should be visible during searches.
-- TODO: Properly support folds. My understanding so far:
-- - Only the first result in a fold is considered
-- - If a highlight would be in a fold, it is discarded
--   - Removing extmarks from within folds is an obvious win, but double-check the actual
--   behavior as well as what is considered standard for something like this
-- TODO: Does performing search with feedkeys properly handle fdo?
-- TODO: Handle repeats and macros. I think you just get vcount1 and feed an empty search string
-- to make it repeat. Macros might not be able to get around having to input, but highlights can
-- still be disabled.
-- TODO: Verify Vim's internal timeout for search
-- TODO: Test visual mode behavior
-- TODO: Test omode behavior
-- TODO: Go through the tests to make sure there aren't any functionalities or corner cases I
-- need to cover.
-- - test/unit/search_spec.lua
-- - test/old/testdir/test_search.vim
-- TODO: IncSearch hl priority should be > Search.

-- TODO: DOCUMENT: IncSearch emulation is incomplete. Setting IncSearch to true will produce
-- IncSearch style highlighting. However, the cursor will not automatically advance and
-- <C-t>/<C-g> commands will not work.
-- TODO: DOCUMENT: Farsight will always display "Search" highlights in the direction the user
-- entered. With IncSearch on, backward facing labels will also be displayed. IncSearch will also
-- cause the next result to display with an IncSearch highlight. Labels will only be calculated
-- and added to results after the cursor.
-- TODO: DOCUMENT: |search-offset| is supported
-- TODO: DOCUMENT: Search highlights will always show in the direction you are searching
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
-- TODO: There might be interesting stuff we can do with \%V (search inside the visual area only)
-- On the baseline level, if the user wants to make that custom mapping, where you exit visual
-- mode (update the marks) and then run search with that magic pre-filled, it should do so
-- smoothly

-- MID: Is winhighlight properly respected?
-- MID: The built-in search highlights zero length lines. Extmark highlights do not display on
-- them. The only way I can think of to deal with this is to manually traverse the results and pick
-- out the zero-length lines within. Those lines can then have virtual text laid on top of them.
-- MID: Results off-screen should be reported. Intuitively, it should be a virtual text overlay
-- on the top/bottom of the window. Blocker: What fallbacks should be used if the overlay would
-- cover a label? Easier version: Only show this if no on-screen results.
-- - Is searchcount() useful here?
-- MID: Implement <C-t>/<C-g> navigation.
-- Blocker questions:
-- - Should IncSearch's auto-forward cursor movement be supported? I do not use it, but it's a
-- core component of how IncSearch functions. Because this version of search has non-IncSearch
-- highlights I'm comfortable with, I'm directionally okay with making IncSearch match its
-- default behavior
-- - Is any sort of displaying being done for searches above/below the screen? Might influence how
-- IncSearch should behave
-- Questions about built-in behavior:
-- - Do <C-t>/<C-g> accept count?
-- - Do they respect wrapscan?
-- - What happens if you go into a fold?
-- - Based on user input, when is the temporary home abandoned? When does the temporary home
-- advance? Go back? My approximate answers from light testing:
--   - If the user adds text, the cursor tries to advance forward, either at the current position
--   or to a future one if it's found. This seems to respect wrapscan
--   - If the user removes search characters, the cursor tries to find a location backwards but
--   closest to its temporary home
--   - The cursor does not go backward past the origin
--   - If a match produces no results, but there is text in the cmdline, the temporary home will
--   not be abandoned. If the cmdline is cleared, it will be
--   - How is the current position considered? It seems to straightforwardly be a matter of if the
--   cursor overlaps with the search. But there could be nuance I'm missing.
-- - Other Questions:
--   - How would <Ctrl-t>/<Ctrl-g> be intercepted and processed? Naive but possibly correct answer:
--     Look at the last character of the cmdline, manually edit the cmdline, then process the char
--   - How can the cursor be moved without triggering scrolloff? This is also relevant for
--   potentially removing backward searches from the codebase
--   - How would the original cur_pos be stored? I think you can pass it as part of the autocmd
--   closure
--   - Does the temporary home need to be stored in module level state? Or, if the cursor is
--   being moved, is getting the current cur_pos sufficient?
--   - When cmdline is updated, how do we check if the cursor is on a valid match? I would guess
--   using search() with the "c" flag
-- MID: In buffers with large amounts of text, searching backwards can be slow. The issue gets
-- worse when using regex expressions. I'd speculate this is because it makes backwards traversal
-- more complicated.
-- Questions:
-- - How do the built-ins avoid this problem?
-- Potential solutions:
-- - Start the cursor at the beginning of the visible buffer. Problem: I'd imagine this triggers
-- scrolloff when you move the cursor.
--
-- LOW: A potential optimization would be to look for contiguous search results and merging them
-- together. Since the end_cols are end-exclusive indexed, this is not infeasible. You would make
-- a loop that iterates through and merges in the next index if possible, then niling the
-- remainder. This *could* help with redraws. Low priority because it's complexity surface area
-- and extmark rendering is not the biggest bottleneck at the moment.
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
