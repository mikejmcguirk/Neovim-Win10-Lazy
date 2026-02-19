local api = vim.api
local fn = vim.fn

---@class farsight.csearch.TokenLabels
---@field [1] integer Length
---@field [2] integer[] Rows (zero indexed)
---@field [3] integer[] Cols
---@field [4] integer[] Byte lengths
---@field [5] integer[] Hl group IDs

local MAX_MAX_TOKENS = 3
local DEFAULT_MAX_TOKENS = MAX_MAX_TOKENS

local HL_1ST_STR = "FarsightCsearch1st"
local HL_2ND_STR = "FarsightCsearch2nd"
local HL_3RD_STR = "FarsightCsearch3rd"
local HL_DIM_STR = "FarsightCsearchDim"

local nvim_set_hl = api.nvim_set_hl
nvim_set_hl(0, HL_1ST_STR, { default = true, link = "DiffChange" })
nvim_set_hl(0, HL_2ND_STR, { default = true, link = "DiffText" })
nvim_set_hl(0, HL_3RD_STR, { default = true, link = "DiffAdd" })
nvim_set_hl(0, HL_DIM_STR, { default = true, link = "Comment" })

local nvim_get_hl_id_by_name = api.nvim_get_hl_id_by_name
local hl_1st = nvim_get_hl_id_by_name(HL_1ST_STR)
local hl_2nd = nvim_get_hl_id_by_name(HL_2ND_STR)
local hl_3rd = nvim_get_hl_id_by_name(HL_3RD_STR)
local hl_dim = nvim_get_hl_id_by_name(HL_DIM_STR)

-- TODO: Probably worth asserting check #hl_map == MAX_MAX_TOKENS
-- TODO: And double check that opts.max_tokens is properly clamped
local hl_map = { hl_1st, hl_2nd, hl_3rd } ---@type integer[]
local hl_ns = api.nvim_create_namespace("FarsightCsearch")

-- Save the ref so we don't have to re-acquire it in hot loops
local util_char = require("farsight._util_char")

local str_byte = string.byte
local get_utf_codepoint = util_char._get_utf_codepoint

local on_key_repeating = 0 ---@type 0|1
local function get_repeat_state()
    return on_key_repeating
end

local function setup_repeat_tracking()
    local has_ffi, ffi = pcall(require, "ffi")
    if has_ffi then
        -- When a dot repeat is performed, the stored characters are moved into the stuff buffer
        -- for processing. The KeyStuffed global flags if the last char was processed from the
        -- stuff buffer. int searchc in search.c only checks the value of KeyStuffed for redoing
        -- state, so no additional checks added here
        local has_keystuffed = pcall(ffi.cdef, "int KeyStuffed;")
        if has_keystuffed then
            get_repeat_state = function()
                return ffi.C.KeyStuffed --[[@as 0|1]]
            end

            return
        end
    end

    -- Credit folke/flash
    vim.on_key(function(key)
        if key == "." and fn.reg_executing() == "" and fn.reg_recording() == "" then
            on_key_repeating = 1
            vim.schedule(function()
                on_key_repeating = 0
            end)
        end
    end)
end

setup_repeat_tracking()

---@param char string
---@param opts farsight.csearch.CsearchOpts
---@return string
local function get_pattern(char, is_omode, opts)
    ---@type string
    local selection = api.nvim_get_option_value("selection", { scope = "global" })
    local pattern = string.gsub(char, "\\", "\\\\")

    if opts.forward == 1 then
        if opts["until"] == 1 then
            if is_omode and selection == "exclusive" then
                return "\\C\\V" .. pattern
            else
                return "\\C\\m.\\ze\\V" .. pattern
            end
        else
            if is_omode and selection == "exclusive" then
                return "\\C\\V" .. pattern .. "\\zs\\m."
            else
                return "\\C\\V" .. pattern
            end
        end
    end

    if opts["until"] == 1 then
        return "\\C\\V" .. pattern .. "\\zs\\m."
    else
        return "\\C\\V" .. pattern
    end
end

---@param win integer
---@param buf integer
---@param cur_pos { [1]: integer, [2]: integer }
---@param char string
---@param opts farsight.csearch.CsearchOpts
local function do_csearch(win, buf, cur_pos, char, opts)
    local count = vim.v.count1
    local forward = opts.forward

    local ut = require("farsight.util")
    local is_omode = ut._resolve_map_mode(api.nvim_get_mode().mode) == "o"
    local pattern = get_pattern(char, is_omode, opts)

    local flags_tbl = { "Wn" }
    flags_tbl[#flags_tbl + 1] = forward == 1 and "z" or "b"
    if opts["until"] == 1 and not opts.until_skip then
        flags_tbl[#flags_tbl + 1] = "c"
    end

    local flags = table.concat(flags_tbl, "")
    -- FUTURE: https://github.com/neovim/neovim/pull/37872
    ---@type { [1]: integer, [2]: integer, [3]: integer? }
    local jump_pos = fn.searchpos(pattern, flags, 0, 2000, function()
        if fn.foldclosed(fn.line(".")) ~= -1 then
            return 1
        end

        count = count - 1
        return count > 0 and 1 or 0
    end)

    if jump_pos[1] == 0 and jump_pos[2] == 0 then
        return
    end

    if not opts.keepjumps then
        api.nvim_cmd({ cmd = "norm", args = { "m'" }, bang = true }, {})
    end

    ---@type string
    local selection = api.nvim_get_option_value("selection", { scope = "global" })
    if forward == 0 and is_omode and selection ~= "exclusive" then
        fn.searchpos("\\m.", "Wb", cur_pos[1])
        cur_pos = api.nvim_win_get_cursor(win)
    end

    if is_omode then
        api.nvim_cmd({ cmd = "norm", args = { "v" }, bang = true }, {})
    end

    jump_pos[2] = math.max(jump_pos[2] - 1, 0)
    api.nvim_win_set_cursor(win, jump_pos)
    opts.on_jump(win, buf, jump_pos)
end

---@param win integer
---@param buf integer
---@param valid boolean
---@param opts farsight.csearch.CsearchOpts
local function checked_clear_hl(win, buf, valid, opts)
    if not opts.show_hl then
        return
    end

    pcall(api.nvim_buf_clear_namespace, buf, hl_ns, 0, -1)
    if valid == false then
        api.nvim__redraw({ win = win, valid = valid })
    end
end

---@param buf integer
---@param labels farsight.csearch.TokenLabels
local function dim_target_lines(buf, labels)
    local rows = {} ---@type table<integer, boolean>

    local len_labels = labels[1]
    local label_rows = labels[2]
    for i = 1, len_labels do
        rows[label_rows[i]] = true
    end

    local dim_extmark_opts = {
        end_col = 0,
        hl_eol = true,
        hl_group = hl_dim,
        priority = 999,
    }

    local nvim_buf_set_extmark = api.nvim_buf_set_extmark
    for row, _ in pairs(rows) do
        dim_extmark_opts.end_line = row + 1
        pcall(nvim_buf_set_extmark, buf, hl_ns, row, 0, dim_extmark_opts)
    end
end

---@param buf integer
---@param labels farsight.csearch.TokenLabels
local function do_highlights(buf, labels)
    local extmark_opts = { priority = 1000 } ---@type vim.api.keyset.set_extmark
    local len_labels = labels[1]
    local label_rows = labels[2]
    local label_cols = labels[3]
    local label_char_lens = labels[4]
    local label_hl_ids = labels[5]

    for i = 1, len_labels do
        local col = label_cols[i]
        extmark_opts.hl_group = label_hl_ids[i]
        -- TODO: Should this be done here?
        extmark_opts.end_col = col + label_char_lens[i]
        pcall(api.nvim_buf_set_extmark, buf, hl_ns, label_rows[i], col, extmark_opts)
    end
end

---Edits token_counts and labels in place
---Start is one indexed, inclusive
---@param row integer
---@param line string
---@param start integer
---@param max_tokens integer
---@param locator fun(codepoint: integer):boolean
---@param token_counts table<integer, integer>
---@param labels farsight.csearch.TokenLabels
local function add_labels_rev(row, line, start, max_tokens, locator, token_counts, labels)
    local l_rows = labels[2]
    local l_cols = labels[3]
    local l_char_lens = labels[4]
    local l_hl_ids = labels[5]
    local row_0 = row - 1

    local i = start
    while i >= 1 do
        local b1 = str_byte(line, i)
        if b1 <= 0x80 or b1 >= 0xC0 then
            local char_nr, len_char = get_utf_codepoint(line, b1, i)
            if locator(char_nr) then
                local char_token_count = token_counts[char_nr] or 0
                if char_token_count < max_tokens then
                    local new_char_token_count = char_token_count + 1
                    token_counts[char_nr] = new_char_token_count

                    labels[1] = labels[1] + 1
                    l_rows[#l_rows + 1] = row_0
                    l_cols[#l_cols + 1] = i - 1
                    l_char_lens[#l_char_lens + 1] = len_char
                    l_hl_ids[#l_hl_ids + 1] = hl_map[new_char_token_count]
                end
            end
        end

        i = i - 1
    end
end

---Edits token_counts and labels in place
---@param row integer
---@param line string
---@param start integer
---@param max_tokens integer
---@param locator fun(codepoint: integer):boolean
---@param token_counts table<integer, integer>
---@param labels farsight.csearch.TokenLabels
local function add_labels_fwd(row, line, start, max_tokens, locator, token_counts, labels)
    local len_line = #line
    local l_rows = labels[2]
    local l_cols = labels[3]
    local l_char_lens = labels[4]
    local l_hl_ids = labels[5]

    local row_0 = row - 1
    local i = start
    while i <= len_line do
        local char_nr, len_char = get_utf_codepoint(line, str_byte(line, i), i)
        if locator(char_nr) then
            local char_token_count = token_counts[char_nr] or 0
            if char_token_count < max_tokens then
                local new_char_token_count = char_token_count + 1
                token_counts[char_nr] = new_char_token_count

                labels[1] = labels[1] + 1
                l_rows[#l_rows + 1] = row_0
                l_cols[#l_cols + 1] = i - 1
                l_char_lens[#l_char_lens + 1] = len_char
                l_hl_ids[#l_hl_ids + 1] = hl_map[new_char_token_count]
            end
        end

        i = i + len_char
    end
end

---Edits token_counts and labels in place
---@param buf integer
---@param cur_pos { [1]: integer, [2]: integer }
---@param max_tokens integer
---@param locator fun(codepoint: integer):boolean
---@param labels farsight.csearch.TokenLabels
---@return boolean
local function get_labels_rev(buf, cur_pos, max_tokens, locator, labels)
    local foldclosed = fn.foldclosed
    local row = cur_pos[1]
    local col = cur_pos[2]

    local top = fn.line("w0")
    local lines = api.nvim_buf_get_lines(buf, top - 1, row, false)
    local token_counts = {} ---@type table<integer, integer>

    local offset = top - 1
    if foldclosed(row) == -1 then
        local cur_idx = row - offset
        add_labels_rev(row, lines[cur_idx], col, max_tokens, locator, token_counts, labels)
    end

    for i = math.max(row - 1, 1), top, -1 do
        if foldclosed(i) == -1 then
            local line = lines[i - offset]
            add_labels_rev(i, line, #line, max_tokens, locator, token_counts, labels)
        end
    end

    return true
end

-- TODO: This isn't quite the same as how Jump does it. Make both more consistent
-- Small thing, but the checks for row validity can be outlined
-- Definitely is_row_valid_and_visible. Not sure if it's contrived to outline the bot check

---@param buf integer
---@param bot integer
---@param max_tokens integer
---@param locator fun(codepoint: integer):boolean
---@param token_counts table<integer, integer>
---@param labels farsight.csearch.TokenLabels
local function handle_wrapped_bot_screenline(buf, bot, max_tokens, locator, token_counts, labels)
    if not api.nvim_get_option_value("wrap", { win = 0 }) then
        return
    end

    local row = math.min(bot + 1, api.nvim_buf_line_count(buf))
    if row == bot then
        return
    end

    local first_spos = fn.screenpos(0, row, 1)
    if first_spos.row < 1 then
        return
    end

    local line = api.nvim_buf_get_lines(buf, row - 1, row, false)[1]
    add_labels_fwd(row, line, 1, max_tokens, locator, token_counts, labels)
end

---Edits token_counts and labels in place
---@param buf integer
---@param cur_pos { [1]: integer, [2]: integer }
---@param max_tokens integer
---@param locator fun(codepoint: integer):boolean
---@param labels farsight.csearch.TokenLabels
---@return boolean
local function get_labels_fwd(buf, cur_pos, max_tokens, locator, labels)
    local foldclosed = fn.foldclosed
    local row = cur_pos[1]
    local col = cur_pos[2]

    local bot = fn.line("w$")
    local lines = api.nvim_buf_get_lines(buf, row - 1, bot, false)
    local token_counts = {} ---@type table<integer, integer>

    if foldclosed(row) == -1 then
        add_labels_fwd(row, lines[1], col + 2, max_tokens, locator, token_counts, labels)
    end

    local offset = row - 1
    for i = row + 1, bot do
        if foldclosed(row) == -1 then
            add_labels_fwd(i, lines[i - offset], 1, max_tokens, locator, token_counts, labels)
        end
    end

    local old_len_labels = labels[1]
    handle_wrapped_bot_screenline(buf, bot, max_tokens, locator, token_counts, labels)
    if labels[1] > old_len_labels then
        return false
    else
        return true
    end
end

---@param win integer
---@param buf integer
---@param cur_pos { [1]: integer, [2]: integer }
---@param opts farsight.csearch.CsearchOpts
---@return boolean
local function checked_show_hl(win, buf, cur_pos, opts)
    if opts.show_hl == false then
        return true
    end

    if fn.reg_executing() ~= "" then
        opts.show_hl = false
        return true
    end

    local table_new = require("farsight.util")._table_new
    ---@type farsight.csearch.TokenLabels
    local labels = {
        0,
        table_new(256, 0),
        table_new(256, 0),
        table_new(256, 0),
        table_new(256, 0),
    }

    local valid
    local locator = opts.locator ---@type fun(codepoint: integer):boolean
    local max_tokens = opts.max_tokens ---@type integer
    if opts.forward == 1 then
        valid = get_labels_fwd(buf, cur_pos, max_tokens, locator, labels)
    else
        valid = get_labels_rev(buf, cur_pos, max_tokens, locator, labels)
    end

    if labels[1] > 0 then
        api.nvim__ns_set(hl_ns, { wins = { win } })
        do_highlights(buf, labels)
        if opts.dim then
            dim_target_lines(buf, labels)
        end

        api.nvim__redraw({ win = win, valid = valid })
    end

    return valid
end

---@param cur_buf integer
---@param opts farsight.csearch.CsearchOpts
local function resolve_locator(cur_buf, opts)
    local ut = require("farsight.util")
    opts.locator = ut._use_gb_if_nil(opts.locator, "farsight_csearch_tokens", cur_buf)
    if opts.locator == nil then
        local isk = api.nvim_get_option_value("isk", { buf = cur_buf }) ---@type string
        local isk_tbl = require("farsight._util_char")._parse_isk(cur_buf, isk)
        opts.locator = function(byte)
            return isk_tbl[byte + 1] == true
        end
    else
        vim.validate("opts.locator", opts.locator, "callable")
    end
end

-- TODO: Document the types that have g/b:vars. Don't spend space calling out the ones that don't

---Must put opts in a state such that:
---- All values are present
---- All internal tables are deep copied
---@param opts farsight.csearch.CsearchOpts
---@param cur_buf integer
local function resolve_csearch_opts(opts, cur_buf)
    local validate = vim.validate
    validate("opts", opts, "table")
    local ut = require("farsight.util")

    opts.actions = opts.actions or {}
    validate("opts.actions", opts.actions, "table")
    for k, v in pairs(opts.actions) do
        validate("k", k, "string")
        validate("v", v, "callable")
    end

    opts.dim = ut._use_gb_if_nil(opts.dim, "farsight_csearch_dim", cur_buf)
    opts.dim = ut._resolve_bool_opt(opts.dim, false)

    opts.forward = opts.forward or 1
    validate("opts.forward", opts.forward, function()
        return opts.forward == 0 or opts.forward == 1
    end, "opts.forward must be 0 or 1")

    opts.keepjumps = ut._use_gb_if_nil(opts.keepjumps, "farsight_csearch_keepjumps", cur_buf)
    opts.keepjumps = ut._resolve_bool_opt(opts.keepjumps, true)

    local gb_max_tokens = "farsight_csearch_max_tokens"
    opts.max_tokens = ut._use_gb_if_nil(opts.max_tokens, gb_max_tokens, cur_buf)
    opts.max_tokens = opts.max_tokens or DEFAULT_MAX_TOKENS
    validate("opts.max_tokens", opts.max_tokens, ut._is_uint)
    opts.max_tokens = math.min(opts.max_tokens, MAX_MAX_TOKENS)

    opts.on_jump = ut._use_gb_if_nil(opts.on_jump, "farsight_csearch_on_jump", cur_buf)
    opts.on_jump = opts.on_jump or function() end
    validate("opts.on_jump", opts.on_jump, "callable")

    opts.show_hl = ut._use_gb_if_nil(opts.show_hl, "farsight_csearch_show_hl", cur_buf)
    opts.show_hl = ut._resolve_bool_opt(opts.show_hl, true)

    resolve_locator(cur_buf, opts)

    opts["until"] = opts["until"] or 0
    validate("opts.until", opts["until"], function()
        return opts["until"] == 0 or opts["until"] == 1
    end, "opts.until must be 0 or 1")

    opts.until_skip = false
end

---@class farsight.Csearch
local Csearch = {}

-- TODO: Document these

---@class farsight.csearch.BaseOpts
---@field forward? 0|1
---@field keepjumps? boolean
---@field on_jump? fun(win: integer, buf: integer, pos: { [1]: integer, [2]: integer })
---@field package until_skip? boolean

-- TODO: Document these
-- TODO: Document specifically that the csearch input is taken with simplify = false, which
-- affects the comparisons for actions

---@class farsight.csearch.CsearchOpts : farsight.csearch.BaseOpts
---@field actions? table<string, fun(win: integer, buf: integer,
---cur_pos: { [1]: integer, [2]: integer })>
---@field dim? boolean
---@field locator? fun(codepoint: integer):boolean
---@field max_tokens? integer
---@field show_hl? boolean
---@field until? 0|1

-- TODO: Document this

---@param opts? farsight.csearch.CsearchOpts
function Csearch.csearch(opts)
    opts = opts and vim.deepcopy(opts) or {}
    local cur_win = api.nvim_get_current_win()
    local cur_buf = api.nvim_win_get_buf(cur_win)
    resolve_csearch_opts(opts, cur_buf)

    local char = nil
    -- Only get once, since Nvim's internal state has no guarantees
    local is_repeating = get_repeat_state()
    if is_repeating == 1 then
        char = fn.getcharsearch().char
        if char == "" then
            return
        end
    end

    local cur_pos = api.nvim_win_get_cursor(cur_win)
    if not char then
        local valid = checked_show_hl(cur_win, cur_buf, cur_pos, opts)
        _, char = pcall(fn.getcharstr, -1, { simplify = true })
        checked_clear_hl(cur_win, cur_buf, valid, opts)

        local actions = opts.actions --[[ @as table<string, fun(win: integer, buf: integer, cur_pos: { [1]: integer, [2]: integer })> ]]
        local nvim_replace_termcodes = api.nvim_replace_termcodes
        for key, action in pairs(actions) do
            if char == nvim_replace_termcodes(key, true, false, true) then
                action(cur_win, cur_buf, cur_pos)
                return
            end
        end
    end

    if is_repeating == 0 then
        fn.setcharsearch({
            char = char,
            forward = opts.forward,
            ["until"] = opts["until"],
        })
    end

    -- Default f/t updates charsearch on unsuccessful searches, so wait until now for this check
    if opts.forward == 0 and cur_pos[1] == 1 and cur_pos[2] == 0 then
        return
    end

    do_csearch(cur_win, cur_buf, cur_pos, char, opts)
end

---The |cpoptions| ";" flag controls until skip behavior
---@param opts? farsight.csearch.BaseOpts
function Csearch.rep(opts)
    opts = opts and vim.deepcopy(opts) or {} --[[ @as farsight.csearch.CsearchOpts ]]
    opts.forward = opts.forward or 1
    vim.validate("opts.forward", opts.forward, function()
        return opts.forward == 0 or opts.forward == 1
    end, "opts.forward must be 0 or 1")

    local cur_win = api.nvim_get_current_win()
    local cur_buf = api.nvim_win_get_buf(cur_win)

    local ut = require("farsight.util")
    opts.keepjumps = ut._use_gb_if_nil(opts.keepjumps, "farsight_csearch_keepjumps", cur_buf)
    opts.keepjumps = ut._resolve_bool_opt(opts.keepjumps, true)
    opts.on_jump = ut._use_gb_if_nil(opts.on_jump, "farsight_csearch_on_jump", cur_buf)
    opts.on_jump = opts.on_jump or function() end
    vim.validate("opts.on_jump", opts.on_jump, "callable")

    local charsearch = fn.getcharsearch()
    local char = charsearch.char
    if char == "" then
        return
    end

    opts["until"] = charsearch["until"]
    local cpo = api.nvim_get_option_value("cpo", { scope = "global" }) ---@type string
    local cpo_noskip, _, _ = string.find(cpo, ";", 1, true)
    if cpo_noskip == nil then
        opts.until_skip = true
    else
        opts.until_skip = false
    end

    opts.forward = require("bit").bxor(opts.forward, charsearch.forward, 1)
    local cur_pos = api.nvim_win_get_cursor(cur_win)
    do_csearch(cur_win, cur_buf, cur_pos, char, opts)
end

return Csearch

-- TODO: For folds:
-- - When on a foldclosed line, display the acutal line with fold highlighting, then display the
-- tokens on top of it. This goes away when highlighting ends.
-- - What to do with dim though?
-- TODO: Outline string.byte to module. Perhaps others
-- TODO: Make the jump backup a single char labeler. Not the best, but does add something.
-- TODO: Document that f/t properly do not prompt for input during operator dot repeats or macro
-- execution
-- TODO: For my personal purposes, do I want to use isprint instead of isk? Too noisy as a default.
-- Raise broader question though - What if a user does want to do this? Are the functions exposed
-- that allow them to do this?
-- TODO: Strategy pattern in the token criteria. Remove token lists in favor of this

-- MID: Is there a principled way to get to a Quickscope style one label per some unit of text
-- function? The add label functions can take any arbitrary string, and could also take an
-- option or function param to add labels based on priority. But what's the data model for the
-- text?

-- LOW: Could default size the label arrays as 512 if one of the following conditions are met:
-- - keymap ~= ""
-- - arabic == true
-- - rightleft == true
-- - termbidi == true
-- - ambiwidth == double

-- PR: It would be cool if Neovim provided some kind of clear_plugin_highlights function that
-- plugins could register with. That way, users couldn't have to create bespoke highlight clearing
-- for every plugin
-- PR: matchstrpos has a non-specific return type. This would require some digging though, as the
-- return type can differ based on the args
-- PR: It should be possible to detect if you are in the middle of a dot repeat.

-- NON: Allowing max_tokens > 3. This would result in more than four keypresses to get to a
-- location. The other Farsight modules can get you anywhere in four or less
-- NON: Multi-window. While perf is better now, would still be a pain to architect for little
-- practical value.
-- NON: Persistent highlighting
-- - Creates code complexity/error surface area
-- - A bad trap with Vim motions is using repetitive presses instead of decisive motions (tapping
-- hjkl repeatedly being the classic example). Having highlights persist encourages repetitively
-- tapping ;,
-- NON: Ignorecase/smartcase support for csearch. A key appeal of the current label display is that
-- it maps 1:1 with the buffer text
