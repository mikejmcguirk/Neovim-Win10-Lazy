local api = vim.api
local fn = vim.fn

---@class farsight.csearch.TokenLabel
---@field [1] integer row_0
---@field [2] integer col
---@field [3] integer hl byte length
---@field [4] integer hl_group id

local MAX_MAX_TOKENS = 3
local DEFAULT_MAX_TOKENS = MAX_MAX_TOKENS
local TOKENS = vim.split("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ", "")

local HL_1ST_STR = "FarsightCsearch1st"
local HL_2ND_STR = "FarsightCsearch2nd"
local HL_3RD_STR = "FarsightCsearch3rd"

local nvim_set_hl = api.nvim_set_hl
nvim_set_hl(0, HL_1ST_STR, { default = true, link = "DiffChange" })
nvim_set_hl(0, HL_2ND_STR, { default = true, link = "DiffText" })
nvim_set_hl(0, HL_3RD_STR, { default = true, link = "DiffAdd" })

local nvim_get_hl_id_by_name = api.nvim_get_hl_id_by_name
local hl_1st = nvim_get_hl_id_by_name(HL_1ST_STR)
local hl_2nd = nvim_get_hl_id_by_name(HL_2ND_STR)
local hl_3rd = nvim_get_hl_id_by_name(HL_3RD_STR)
local hl_map = { hl_1st, hl_2nd, hl_3rd } ---@type integer[]

local HL_NS = api.nvim_create_namespace("FarsightCsearch")

-- Save the ref so we don't have to re-acquire it in hot loops
local utf8_len_tbl = require("farsight._lookups")._utf8_len_tbl

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
local function get_pattern(char, opts)
    local util = require("farsight.util")
    local omode = util._resolve_map_mode(api.nvim_get_mode().mode) == "o"
    ---@type string
    local selection = api.nvim_get_option_value("selection", { scope = "global" })

    local pattern = string.gsub(char, "\\", "\\\\")

    if opts.forward == 1 then
        if opts.t_cmd == 1 then
            if omode and selection == "exclusive" then
                return "\\C\\V" .. pattern
            else
                return "\\C\\m.\\ze\\V" .. pattern
            end
        else
            if omode and selection == "exclusive" then
                return "\\C\\V" .. pattern .. "\\zs\\m."
            else
                return "\\C\\V" .. pattern
            end
        end
    end

    if opts.t_cmd == 1 then
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
    local forward = opts.forward

    local count = vim.v.count1
    local pattern = get_pattern(char, opts)
    local flags_tbl = { "Wn" }
    flags_tbl[#flags_tbl + 1] = forward == 1 and "z" or "b"
    if opts.t_cmd == 1 and not opts.t_cmd_skip then
        flags_tbl[#flags_tbl + 1] = "c"
    end

    local flags = table.concat(flags_tbl, "")
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

    local util = require("farsight.util")
    local is_omode = util._resolve_map_mode(api.nvim_get_mode().mode) == "o"
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
    local on_jump = opts.on_jump
    if on_jump then
        on_jump(win, buf, jump_pos)
    end
end

---@param buf integer
---@param opts farsight.csearch.CsearchOpts
---@return string
local function get_csearch_input(buf, opts)
    local _, input = pcall(fn.getcharstr, -1)
    pcall(api.nvim_buf_clear_namespace, buf, HL_NS, 0, -1)
    local actions = opts.actions --[[@as table<string, fun()>]]
    local nvim_replace_termcodes = api.nvim_replace_termcodes
    for key, action in pairs(actions) do
        -- TODO: Document the replace_termcode behavior
        local rep_key = nvim_replace_termcodes(key, true, false, true)
        if input == rep_key then
            -- TODO: We could pass win/pos/buf into here
            action()
            return ""
        end
    end

    return input
end

---@param buf integer
---@param labels farsight.csearch.TokenLabel[]
local function highlight_labels(buf, labels)
    local extmark_opts = { priority = 1000, strict = false } ---@type vim.api.keyset.set_extmark
    for _, label in ipairs(labels) do
        extmark_opts.hl_group = label[4]
        extmark_opts.end_col = label[2] + label[3]
        pcall(api.nvim_buf_set_extmark, buf, HL_NS, label[1], label[2], extmark_opts)
    end
end

---NON: Worth the function call overhead to avoid logic duplication

---@param line string
---@param b1 integer
---@param idx integer
---@return integer, integer
local function get_utf_codepoint(line, b1, idx)
    local len_utf = utf8_len_tbl[b1]
    if len_utf == 1 or len_utf > 4 or idx + len_utf - 1 > #line then
        return b1, 1
    end

    local lshift = require("bit").lshift
    local sbyte = string.byte

    local b2 = sbyte(line, idx + 1)
    if len_utf == 2 then
        return lshift(b1 - 0xC0, 6) + (b2 - 0x80), 2
    end

    local b3 = sbyte(line, idx + 2)
    if len_utf == 3 then
        return lshift(b1 - 0xE0, 12) + lshift(b2 - 0x80, 6) + (b3 - 0x80), 3
    end

    local b4 = sbyte(line, idx + 3)
    local b1_shift = lshift(b1 - 0xF0, 18)
    local b2_shift = lshift(b2 - 0x80, 12)
    local b3_shift = lshift(b3 - 0x80, 6)
    return b1_shift + b2_shift + b3_shift + (b4 - 0x80), 4
end

---Edits token_counts and labels in place
---@param row integer
---@param line string
---@param max_tokens integer
---@param token_counts table<integer, integer>
---@param labels farsight.csearch.TokenLabel[]
local function add_labels_rev(row, line, max_tokens, token_counts, labels)
    local n = #line
    local sbyte = string.byte

    local i = n
    local row_0 = row - 1

    while i >= 1 do
        local b1 = sbyte(line, i)
        if b1 <= 0x80 or b1 >= 0xC0 then
            local char_nr, len_char = get_utf_codepoint(line, b1, i)
            local char_token_count = token_counts[char_nr]
            if char_token_count then
                token_counts[char_nr] = char_token_count + 1
                local new_char_token_count = token_counts[char_nr]
                local hl_id = hl_map[new_char_token_count]
                if hl_id then
                    labels[#labels + 1] = { row_0, i - 1, len_char, hl_id }
                end

                if new_char_token_count >= max_tokens then
                    token_counts[char_nr] = nil
                end

                if not next(token_counts) then
                    return
                end
            end
        end

        i = i - 1
    end
end

---Edits token_counts and labels in place
---@param row integer
---@param line string
---@param max_tokens integer
---@param token_counts table<integer, integer>
---@param labels farsight.csearch.TokenLabel[]
local function add_labels_fwd(row, line, max_tokens, token_counts, labels)
    local len_line = #line
    local sbyte = string.byte

    local row_0 = row - 1
    local i = 1
    while i <= len_line do
        local b1 = sbyte(line, i)
        local char_nr, len_char = get_utf_codepoint(line, b1, i)
        local char_token_count = token_counts[char_nr]
        if char_token_count then
            token_counts[char_nr] = char_token_count + 1
            local new_char_token_count = token_counts[char_nr]
            local hl_id = hl_map[new_char_token_count]
            if hl_id then
                labels[#labels + 1] = { row_0, i - 1, len_char, hl_id }
            end

            if new_char_token_count >= max_tokens then
                token_counts[char_nr] = nil
            end

            if not next(token_counts) then
                return
            end
        end

        i = i + len_char
    end
end

---Edits token_counts and labels in place
---@param cur_row integer
---@param cur_col integer
---@param max_tokens integer
---@param token_counts table<integer, integer>
---@param labels farsight.csearch.TokenLabel[]
local function get_labels_rev(cur_row, cur_col, max_tokens, token_counts, labels)
    if fn.foldclosed(cur_row) == -1 then
        local cur_line = api.nvim_buf_get_lines(0, cur_row - 1, cur_row, false)[1]
        local line_before = string.sub(cur_line, 1, cur_col)
        add_labels_rev(cur_row, line_before, max_tokens, token_counts, labels)
        if not next(token_counts) then
            return labels
        end
    end

    local top = fn.line("w0")
    local prev_row = math.max(cur_row - 1, 1)
    for i = prev_row, top, -1 do
        if fn.foldclosed(i) == -1 then
            local line = api.nvim_buf_get_lines(0, i - 1, i, false)[1]
            add_labels_rev(i, line, max_tokens, token_counts, labels)
            if not next(token_counts) then
                return labels
            end
        end
    end
end

---Edits token_counts and labels in place
---@param cur_row integer
---@param cur_col integer
---@param max_tokens integer
---@param token_counts table<integer, integer>
---@param labels farsight.csearch.TokenLabel[]
local function get_labels_fwd(cur_row, cur_col, max_tokens, token_counts, labels)
    if fn.foldclosed(cur_row) == -1 then
        local cur_line = api.nvim_buf_get_lines(0, cur_row - 1, cur_row, false)[1]
        local line_after = string.sub(cur_line, cur_col + 2, #cur_line)
        add_labels_fwd(cur_row, line_after, max_tokens, token_counts, labels)
        local len_cut_line = #cur_line - #line_after
        for _, label in ipairs(labels) do
            label[2] = label[2] + len_cut_line
        end

        if not next(token_counts) then
            return labels
        end
    end

    local bot = fn.line("w$")
    for i = cur_row + 1, bot do
        if fn.foldclosed(cur_row) == -1 then
            local line = api.nvim_buf_get_lines(0, i - 1, i, false)[1]
            add_labels_fwd(i, line, max_tokens, token_counts, labels)
            if not next(token_counts) then
                return labels
            end
        end
    end

    -- TODO: Add extra for wrapped rows. Try to incorporate jump logic
end

---@param tokens (integer|string)[]
---@return table<integer, integer>
local function create_token_counts(tokens)
    local token_counts = {} ---@type table<integer, integer>
    local start_count = 0 - (vim.v.count1 - 1)

    local char2nr = fn.char2nr

    for _, token in ipairs(tokens) do
        if type(token) == "string" then
            token_counts[char2nr(token)] = start_count
        else
            token_counts[token] = start_count
        end
    end

    return token_counts
end

---@param cur_pos { [1]: integer, [2]: integer }
---@param opts farsight.csearch.CsearchOpts
local function get_labels(cur_pos, opts)
    local cur_row = cur_pos[1]
    local cur_col = cur_pos[2]
    local forward = opts.forward
    local max_tokens = opts.max_tokens --[[@as integer]]

    local char2nr = fn.char2nr
    local tokens = vim.deepcopy(opts.tokens) --[[@as string[] ]]
    require("farsight.util")._list_map(tokens, function(token)
        if type(token) == "string" then
            return char2nr(token)
        else
            return token
        end
    end)

    -- TODO: filter control chars from token counts

    local token_counts = create_token_counts(tokens)
    local labels = {} ---@type farsight.csearch.TokenLabel[]

    if forward == 1 then
        get_labels_fwd(cur_row, cur_col, max_tokens, token_counts, labels)
    else
        get_labels_rev(cur_row, cur_col, max_tokens, token_counts, labels)
    end

    return labels
end

local function resolve_tokens(cur_buf, opts)
    local ut = require("farsight.util")

    opts.tokens = ut._use_gb_if_nil(opts.tokens, "farsight_csearch_tokens", cur_buf)
    opts.tokens = opts.tokens or TOKENS
    vim.validate("opts.tokens", opts.tokens, "table")
    require("farsight.util")._list_dedup(opts.tokens)
    ut._validate_list(opts.tokens, { item_type = { "number", "string" } })

    local sbyte = string.byte
    ut._list_filter(opts.tokens, function(token)
        if type(token) == "integer" then
            return token > 31 and token ~= 127
        else
            if #token > 1 then
                return true
            end

            local b1 = sbyte(token)
            return b1 > 31 and b1 ~= 127
        end
    end)
end

---@param opts farsight.csearch.CsearchOpts
---@param cur_buf integer
local function resolve_csearch_opts(opts, cur_buf)
    vim.validate("opts", opts, "table")
    local ut = require("farsight.util")

    opts.actions = opts.actions or {}
    vim.validate("opts.actions", opts.actions, "table")
    for k, v in pairs(opts.actions) do
        vim.validate("k", k, "string")
        vim.validate("v", v, "callable")
    end

    -- TODO: Document in the type that this is only locally controlled
    opts.forward = opts.forward or 1
    vim.validate("opts.forward", opts.forward, function()
        return opts.forward == 0 or opts.forward == 1
    end, "opts.forward must be 0 or 1")

    opts.on_jump = ut._use_gb_if_nil(opts.on_jump, "farsight_csearch_on_jump", cur_buf)
    vim.validate("opts.on_jump", opts.on_jump, "callable", true)

    opts.show_hl = ut._use_gb_if_nil(opts.show_hl, "farsight_csearch_show_hl", cur_buf)
    opts.show_hl = ut._resolve_bool_opt(opts.show_hl, true)

    resolve_tokens(cur_buf, opts)

    -- TODO: Document in the type that this is only locally controlled
    opts.t_cmd = opts.t_cmd or 0
    vim.validate("opts.t_cmd", opts.t_cmd, function()
        return opts.t_cmd == 0 or opts.t_cmd == 1
    end, "opts.t_cmd must be 0 or 1")

    -- TODO: Document that the cpo option does not control here
    opts.t_cmd_skip = ut._use_gb_if_nil(opts.t_cmd_skip, "farsight_csearch_t_cmd_skip_ft", cur_buf)
    opts.t_cmd_skip = ut._resolve_bool_opt(opts.t_cmd_skip, false)

    local gb_max_tokens = "farsight_csearch_max_tokens"
    opts.max_tokens = ut._use_gb_if_nil(opts.max_tokens, gb_max_tokens, cur_buf)
    opts.max_tokens = opts.max_tokens or DEFAULT_MAX_TOKENS
    vim.validate("opts.max_tokens", opts.max_tokens, ut._is_uint)
    opts.max_tokens = math.min(opts.max_tokens, MAX_MAX_TOKENS)
end

---@class farsight.Csearch
local Csearch = {}

-- TODO: Document these

---@class farsight.csearch.BaseOpts
---@field forward? 0|1
---@field on_jump? fun(win: integer, buf: integer, pos: { [1]: integer, [2]: integer })
---@field t_cmd_skip? boolean

-- TODO: Rename t_cmd to until. Need to rewrite how dict is accessed

---@class farsight.csearch.CsearchOpts : farsight.csearch.BaseOpts
---@field actions? table<string, fun()>
---@field tokens? string[]
---@field max_tokens? integer
---@field show_hl? boolean
---@field t_cmd? 0|1

---@param opts? farsight.csearch.CsearchOpts
function Csearch.csearch(opts)
    opts = opts and vim.deepcopy(opts, true) or {}
    local cur_win = api.nvim_get_current_win()
    local cur_buf = api.nvim_win_get_buf(cur_win)
    resolve_csearch_opts(opts, cur_buf)

    local char = ""
    local is_repeating = get_repeat_state()
    if is_repeating == 1 then
        local charsearch = fn.getcharsearch()
        char = charsearch.char
        if char == "" then
            return
        end
    end

    local cur_pos = api.nvim_win_get_cursor(cur_win)
    if char == "" then
        -- NON: Leave the function call to get highlights here. Less confusing
        if opts.show_hl then
            -- TODO: Once we have the valid logic for redraws setup, bundle the hl logic into
            -- a helper. Keep the opts check here
            local labels = get_labels(cur_pos, opts)
            if #labels > 0 then
                api.nvim__ns_set(HL_NS, { wins = { cur_win } })
                highlight_labels(cur_buf, labels)
                api.nvim__redraw({ valid = true })
            end
        end

        char = get_csearch_input(cur_buf, opts)
    end

    local input_byte = string.byte(char) or 0
    local is_ascii_control_char = input_byte <= 31 or input_byte == 127
    local no_char = char == nil or #char == 0
    if is_ascii_control_char or no_char then
        return
    end

    -- Only update if not repeating
    -- Always update before actually running the search
    if is_repeating == 0 then
        fn.setcharsearch({
            char = char,
            forward = opts.forward,
            ["until"] = opts.t_cmd,
        })
    end

    -- Wait until now as in the built-in
    if opts.forward == 0 and cur_pos[1] == 1 and cur_pos[2] == 0 then
        return
    end

    do_csearch(cur_win, cur_buf, cur_pos, char, opts)
end

---If opts.t_cmd_skip is not provided, the |cpoptions| ";" flag will be checked
---@param opts? farsight.csearch.BaseOpts
function Csearch.rep(opts)
    opts = opts and vim.deepcopy(opts, true) or {} --[[ @as farsight.csearch.CsearchOpts ]]
    opts.forward = opts.forward or 1
    vim.validate("opts.forward", opts.forward, function()
        return opts.forward == 0 or opts.forward == 1
    end, "opts.forward must be 0 or 1")

    local cur_win = api.nvim_get_current_win()
    local cur_buf = api.nvim_win_get_buf(cur_win)

    vim.validate("opts.on_jump", opts.on_jump, "callable", true)
    vim.validate("opts.t_cmd_skip", opts.t_cmd_skip, "boolean", true)

    local charsearch = fn.getcharsearch()
    local char = charsearch.char
    if char == "" then
        return
    end

    opts.t_cmd = charsearch["until"]
    opts.t_cmd_skip = (function()
        if type(opts.t_cmd_skip) ~= "nil" then
            return opts.t_cmd_skip
        end

        local cpo = api.nvim_get_option_value("cpo", {}) ---@type string
        local cpo_noskip, _, _ = string.find(cpo, ";", 1, true)
        return cpo_noskip == nil
    end)()

    -- Bitshifts are LuaJIT only
    -- TODO: Neovim has a builtin module. Fix
    opts.forward = (opts.forward == 1) and charsearch.forward or (1 - charsearch.forward)
    local cur_pos = api.nvim_win_get_cursor(cur_win)
    do_csearch(cur_win, cur_buf, cur_pos, char, opts)
end

return Csearch

-- TODO: Philosophical question - Are these motions allowed to run off the screen?
-- TODO: Add option to override fdo setting
-- TODO: Tokens should be able to be provided as either a number or a string
-- - number tokens need to be ints
-- - The list validator should be able to handle both types
-- - Use a bespoke function in the validator to test that numbers are ints
-- - We then convert all strings to numbers using nr2char()
-- TODO: Need to think through the architecture. I'm not sure utf chars even work properly
-- because right now searching is tied to keywords. User customization of searching is
-- impossible. Deeply nested strategy pattern functions. This is not good. I would even be fine
-- locking this down more, because that would be more decisive
-- Ideas :
-- - No matter what, we need to lay down as a baseline assumption that all chars will be scanned
-- This is a very bad, current inconsistency
-- - Make splitting words into its own step
-- - Forego any sort of split and just let all tokens through
-- - I'm uncomfortable with getting rid of the UTF/ASCII distinction because being able to
-- iterate ASCII only produces noticeable perf benefit
-- - Max tokens is going to be capped at three for the foreseeable future. The rainbow/long
-- extensions are fun, but there are other jumps for those things
-- - fwiw char in nv_csearch is an int I feel like that impacts what I'm doing somehow
-- - In support of not using keywords as a default word parser, it makes token customization
-- more awkward. Though what you would then do is use keyword changes as word separators
-- - It might be possible to use search(), and use the skip expression to handle count
-- - Non-ASCII highlighting has to be supported for prose/non-English users
-- TODO: Add dimming to csearch lines with tokens
-- TODO: Make the backup a single char labeler. Not the best, but does add something.
-- TODO: One last deep scan through the code
-- TODO: Check if the user is prompted for chars when running macros on default f/t
-- TODO: During highlighting, use screenpos() to check for invalid positions
-- TODO: Document lack of support for folds

-- MID: Add support for single-line f/t.
-- MID: The default tokens should be 'isk' for the current buffer. The isk strings + tokens can
-- be cached when created for the first time. For subsequent runs, re-query the opt string and
-- only rebuild the list if the string has changed
-- MID: It would be better if the user could customize how the highlight tokens are generatred.
-- Not seeing any natural hook points at the moment though. This is also on hold for isk parsing,
-- as that opens up other possibilities
-- MID: If wrap is on and a line runs off the end of the screen, you could f/t into it
-- unexpectedly. For the last line, would be good to be able to stop where it actually displays

-- LOW: Rather than niling tokens that cannot be highlighted, could separately keep track of
-- how many highlightable tokens remain. Saw slight perf gain when trying this, but not enough to
-- be sure it isn't just noise. Since a separate count also introduces another point of failure,
-- sticking with the keys based tracking.
-- LOW: For the actual search and jump, after pulling the first line, the next ~4 lines could be
-- pulled as a group (only one API call) since that's the most likely, then chunks of the rest
-- LOW: Try the labels as a struct of arrays.
-- LOW: Ignoring fold lines is in line with the built-in behavior, but is there a better solution?
-- LOW: A few different points here where we get lines over the API multiple times. Low priority
-- since those calls don't occur in hot paths, but still unfortunate
-- LOW: Allowing folds is painful because it can cause the cursor to jump somewhere not expected.
-- Can add support for folded lines if a good way to handle it is figured out.
-- - Only show highlights/enable jumping to the preview text?

-- PR: It would be cool if Neovim provided some kind of clear_plugin_highlights function that
-- plugins could register with. That way, users couldn't have to create bespoke highlight clearing
-- for every plugin (that said, how does Flash do it?)
-- PR: matchstrpos has a non-specific return type. This would require some digging though, as the
-- return type can differ based on the args
-- PR: It should be possible to detect if you are in the middle of a dot repeat.
-- PR: searchpos return type { [1]: integer, [2]: integer, [3]: integer? }

-- FUTURE: When the new mark API is released, use that to conditionally set the pcmark. This also
-- allows for bringing nokeepjumps and the keepjumps opt back to csearch

-- NON: Allowing max_tokens > 3. This would result in more than four keypresses to get to a
-- location. The other Farsight modules can get you anywhere in four or less
-- NON: Multi-window. While perf is better now, would still be a pain to architect for little
-- practical value.
-- NON: Persistent highlighting
-- - Creates code complexity/error surface area
-- - A bad trap with Vim motions is using repetitive presses instead of decisive motions (tapping
-- hjkl repeatedly being the classic example). Having highlights persist encourages repetitively
-- tapping ;,
-- NON: No ignorecase/smartcase support for csearch. Adds an extra cognitive layer to interpreting
-- what is being displayed that I'm not interested in
