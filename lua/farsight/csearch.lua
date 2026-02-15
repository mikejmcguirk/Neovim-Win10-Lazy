local api = vim.api
local fn = vim.fn

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

-- Copied from Nvim source
-- stylua: ignore
local utf8_len_tbl = {
  -- ?1 ?2 ?3 ?4 ?5 ?6 ?7 ?8 ?9 ?A ?B ?C ?D ?E ?F
  1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,  -- 0?
  1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,  -- 1?
  1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,  -- 2?
  1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,  -- 3?
  1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,  -- 4?
  1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,  -- 5?
  1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,  -- 6?
  1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,  -- 7?
  1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,  -- 8?
  1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,  -- 9?
  1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,  -- A?
  1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,  -- B?
  2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2,  -- C?
  2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2,  -- D?
  3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3,  -- E?
  4, 4, 4, 4, 4, 4, 4, 4, 5, 5, 5, 5, 6, 6, 1, 1,  -- F?
}

local on_key_repeating = 0 ---@type 0|1
local function get_repeat_state()
    return on_key_repeating
end

local function setup_repeat_tracking()
    local has_ffi, ffi = pcall(require, "ffi")
    if has_ffi then
        local has_keystuffed = pcall(ffi.cdef, "int KeyStuffed;")
        -- When a dot repeat is performed, the stored characters are moved into the stuff buffer
        -- for processing. The KeyStuffed global flags if the last char was processed from the
        -- stuff buffer. int searchc in search.c only checks the value of KeyStuffed for redoing
        -- state, so no additional checks added here
        if has_keystuffed then
            get_repeat_state = function()
                -- TODO: Does this work properly if other plugins do their own ffi cdefs?
                return ffi.C.KeyStuffed --[[@as 0|1]]
            end

            return
        end
    end

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

---@class farsight.csearch.TokenLabel
---@field [1] integer row
---@field [2] integer col
---@field [3] integer hl byte length
---@field [4] integer hl_group id

---@param jump_win integer
---@param buf integer
---@param jump_pos { [1]: integer, [2]: integer }
---@param opts farsight.csearch.CsearchOpts
local function do_jump(cur_win, jump_win, buf, cur_pos, jump_pos, opts)
    local util = require("farsight.util")
    local map_mode = util._resolve_map_mode(api.nvim_get_mode().mode)

    local common = require("farsight._common")
    ---@type farsight._common.DoJumpOpts
    local jump_opts = { on_jump = opts.on_jump, keepjumps = opts.keepjumps }
    common._do_jump(cur_win, jump_win, buf, map_mode, cur_pos, jump_pos, jump_opts)
end

---Returns cursor indexed row, col
---@param this_line string
---@param init integer See string.sub
---@param row integer Cursor indexed
---@param input string
---@param count integer
---@param pos { [1]: integer, [2]: integer }
---@return integer, { [1]: integer, [2]: integer }
local function csearch_line(this_line, init, row, input, count, pos)
    local find = string.find
    local input_len = #input
    while count > 0 do
        local start = find(this_line, input, init, true)
        if start == nil then
            break
        end

        count = count - 1
        pos[1] = row
        pos[2] = start - 1
        init = start + input_len
    end

    return count, pos
end

---@param buf integer
---@param pos { [1]: integer, [2]: integer }
---@return { [1]: integer, [2]: integer }
local function handle_t_cmd(buf, pos)
    local row = pos[1]
    local col = pos[2]
    local nvim_buf_get_lines = api.nvim_buf_get_lines

    -- LOW: Is it better to keep the line in pos than to re-query it?
    local line = nvim_buf_get_lines(buf, row - 1, row, false)[1]
    local charidx = fn.charidx(line, col)

    if charidx > 1 then
        pos[2] = fn.byteidx(line, charidx - 1)
    else
        local prev_row = row - 1
        pos[1] = math.max(prev_row, 1)

        local prev_line = nvim_buf_get_lines(buf, prev_row - 1, prev_row, false)[1]
        local strcharlen = fn.strcharlen(prev_line)
        pos[2] = fn.byteidx(prev_line, math.max(strcharlen - 1, 0))
    end

    -- MAYBE: Technically pointless, but maintains consistency with the csearch_line functions
    return pos
end

---@param count integer
---@param buf integer
---@param cur_pos { [1]: integer, [2]: integer }
---@param input string
---@param opts farsight.csearch.CsearchOpts
---@return { [1]: integer, [2]: integer }|nil
local function csearch_fwd(count, buf, cur_pos, input, opts)
    local byteidx = fn.byteidx
    local foldclosed = fn.foldclosed
    local nvim_buf_get_lines = api.nvim_buf_get_lines
    local row = cur_pos[1]
    local col = cur_pos[2]

    local cur_line = nvim_buf_get_lines(buf, row - 1, row, false)[1]
    local cur_charidx = fn.charidx(cur_line, col)
    local charlen = fn.strcharlen(cur_line)
    local valid_line = foldclosed(row) == -1 and charlen > 1
    local last_byteidx = byteidx(cur_line, math.max(charlen - 1, 0))
    local search_cur_line = valid_line and col ~= last_byteidx

    local t_cmd = opts.t_cmd
    local t_cmd_skip = opts.t_cmd_skip
    if t_cmd == 1 and t_cmd_skip then
        if search_cur_line then
            local next_charidx = cur_charidx + 1
            if fn.strcharpart(cur_line, next_charidx, 1, true) == input then
                cur_charidx = next_charidx
                col = byteidx(cur_line, next_charidx)
                search_cur_line = col ~= last_byteidx
            end
        else
            local next_row = math.min(row + 1, api.nvim_buf_line_count(buf))
            if next_row == row then
                return nil
            end

            -- LOW: Wasteful if starcharpart ~= input, as the loop grabs this again
            local next_line = nvim_buf_get_lines(buf, row, next_row, false)[1]
            if fn.strcharpart(next_line, 0, 1, true) == input then
                row = next_row
                col = 0
                cur_line = next_line
                cur_charidx = 0
                search_cur_line = true
            end
        end
    end

    local pos = {} ---@type { [1]: integer, [2]: integer }
    if search_cur_line then
        local next_col_1 = byteidx(cur_line, cur_charidx + 1) + 1
        count, pos = csearch_line(cur_line, next_col_1, row, input, count, pos)
    end

    local i = row + 1
    local bot = fn.line("w$")
    while i <= bot and count > 0 do
        if foldclosed(i) == -1 then
            local this_line = nvim_buf_get_lines(buf, i - 1, i, false)[1]
            count, pos = csearch_line(this_line, 1, i, input, count, pos)
        end

        i = i + 1
    end

    return pos
end

---@param line string
---@param init integer See string.find
---@param row integer 1 indexed
---@param input string
---@param count integer
---@param pos { [1]: integer, [2]: integer } Cursor indexed
---@return integer, { [1]: integer, [2]: integer } Cursor indexed
local function csearch_line_rev(line, init, row, input, count, pos)
    local reverse = string.reverse
    local rev_line = reverse(line)
    local rev_input = reverse(input)

    local line_len = #line
    local input_len = #input
    local rev_init = 1 + (line_len - init)

    local find = string.find
    while count > 0 do
        local start = find(rev_line, rev_input, rev_init, true)
        if not start then
            break
        end

        count = count - 1
        pos[1] = row
        pos[2] = line_len - start - input_len + 1

        rev_init = start + input_len
    end

    return count, pos
end

---@param buf integer
---@param pos { [1]: integer, [2]: integer }
local function handle_t_cmd_rev(buf, pos)
    local row = pos[1]
    local line = api.nvim_buf_get_lines(buf, row - 1, row, false)[1]
    local char_idx = fn.charidx(line, pos[2])

    if char_idx < fn.strcharlen(line) - 1 then
        pos[2] = fn.byteidx(line, char_idx + 1)
    else
        pos[1] = math.min(row + 1, api.nvim_buf_line_count(buf))
        pos[2] = 0
    end

    return pos
end

---@param count integer
---@param buf integer
---@param cur_pos { [1]: integer, [2]: integer }
---@param input string
---@param opts farsight.csearch.CsearchOpts
local function csearch_rev(count, buf, cur_pos, input, opts)
    local byteidx = fn.byteidx
    local foldclosed = fn.foldclosed
    local nvim_buf_get_lines = api.nvim_buf_get_lines
    local row = cur_pos[1]
    local col = cur_pos[2]

    local cur_line = nvim_buf_get_lines(buf, row - 1, row, false)[1]
    -- Can't just check col > 0. While non-standard, it is possible for the cursor to be in the
    -- middle of a multibyte character
    local cur_charidx = fn.charidx(cur_line, col)
    local search_cur_line = foldclosed(row) == -1 and cur_charidx > 0

    local t_cmd = opts.t_cmd
    local t_cmd_skip = opts.t_cmd_skip
    if t_cmd == 1 and t_cmd_skip then
        if search_cur_line then
            local prev_charidx = cur_charidx - 1
            if fn.strcharpart(cur_line, prev_charidx, 1, true) == input then
                cur_charidx = prev_charidx
                col = byteidx(cur_line, prev_charidx)
                search_cur_line = cur_charidx > 0
            end
        else
            local prev_row = math.max(row - 1, 1)
            if prev_row == row then
                return
            end

            local prev_line = nvim_buf_get_lines(buf, prev_row - 1, prev_row, false)[1]
            local charlen = fn.strcharlen(prev_line)
            local last_charidx = math.max(charlen - 1, 0)
            local last_byteidx = byteidx(prev_line, last_charidx)
            if fn.strcharpart(prev_line, last_byteidx, 1, true) == input then
                row = prev_row
                col = last_byteidx
                cur_line = prev_line
                cur_charidx = last_charidx
                search_cur_line = true
            end
        end
    end

    local pos = {} ---@type { [1]: integer, [2]: integer }
    if search_cur_line then
        count, pos = csearch_line_rev(cur_line, col, row, input, count, pos)
    end

    local i = row - 1
    local top = fn.line("w0")
    while i >= top and count > 0 do
        if foldclosed(i) == -1 then
            local this_line = nvim_buf_get_lines(buf, i - 1, i, false)[1]
            count, pos = csearch_line_rev(this_line, #this_line, i, input, count, pos)
        end

        i = i - 1
    end

    return pos
end

---@param win integer
---@param buf integer
---@param cur_pos { [1]: integer, [2]: integer }
---@param char string
---@param opts farsight.csearch.CsearchOpts
local function do_csearch(win, buf, cur_pos, char, opts)
    local forward = opts.forward

    local jump_pos ---@type { [1]: integer, [2]: integer }|nil
    if forward == 1 then
        jump_pos = csearch_fwd(vim.v.count1, buf, cur_pos, char, opts)
    else
        jump_pos = csearch_rev(vim.v.count1, buf, cur_pos, char, opts)
    end

    -- Can't just check nil. The csearch functions create empty tables to update in place
    if jump_pos and #jump_pos == 2 then
        if opts.t_cmd == 1 then
            if forward == 1 then
                jump_pos = handle_t_cmd(buf, jump_pos)
            else
                jump_pos = handle_t_cmd_rev(buf, jump_pos)
            end
        end

        do_jump(win, win, buf, cur_pos, jump_pos, opts)
    end
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

-- TODO: Rename to create_token_counts once old one is gone
-- TODO: Decouple comments from params
---@param tokens (integer|string)[]
---@return table<integer, integer>
local function init_token_counts(tokens)
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

-- TODO: Check this against Nvim's built-in char2nr
-- TODO: Don't have comments attached to params
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

-- TODO: Make sure these comments are separate from the params
-- TODO: Make sure this function is moved to the appropriate place
---@param opts farsight.csearch.CsearchOpts
local function get_csearch_labels(cur_pos, opts)
    local cur_row = cur_pos[1]
    local cur_col = cur_pos[2]
    local forward = opts.forward
    local max_tokens = opts.max_tokens --[[@as integer]]
    local tokens = opts.tokens --[[@as string[] ]]

    -- TODO: filter control chars from token counts
    -- TODO: early exit of token_counts is 0. print a warning
    local token_counts = init_token_counts(tokens)
    local labels = {} ---@type farsight.csearch.TokenLabel[]

    if forward == 1 then
        -- TODO: Resolve fold state/opts. Have opts.use_folds or something, and use the Nvim
        -- option to fill it if nil. fdo_hor?
        local cur_line = api.nvim_buf_get_lines(0, cur_row - 1, cur_row, false)[1]
        local line_after = string.sub(cur_line, cur_col + 1, #cur_line)
        add_labels_fwd(cur_row, line_after, max_tokens, token_counts, labels)
        local len_cut_line = #cur_line - #line_after
        for _, label in ipairs(labels) do
            label[2] = label[2] + len_cut_line
        end

        if not next(token_counts) then
            return labels
        end

        local bot = fn.line("w$")
        for i = cur_row + 1, bot do
            -- TODO: Same thing with folds here
            local line = api.nvim_buf_get_lines(0, i - 1, i, false)[1]
            add_labels_fwd(i, line, max_tokens, token_counts, labels)
            if not next(token_counts) then
                return labels
            end
        end
        -- TODO: Add extra for wrapped rows. Try to incorporate jump logic
    else
        local cur_line = api.nvim_buf_get_lines(0, cur_row - 1, cur_row, false)[1]
        local line_before = string.sub(cur_line, 1, cur_col)
        add_labels_rev(cur_row, line_before, max_tokens, token_counts, labels)
        if not next(token_counts) then
            return labels
        end

        local top = fn.line("w0")
        local prev_row = math.max(cur_row - 1, 1)
        for i = prev_row, top, -1 do
            -- TODO: Same thing with folds here
            local line = api.nvim_buf_get_lines(0, i - 1, i, false)[1]
            add_labels_rev(i, line, max_tokens, token_counts, labels)
            if not next(token_counts) then
                return labels
            end
        end
    end

    -- TODO: Current char does not count for f
    -- TODO: Very next char for t counts based on skip
    -- TODO: Respect fdo 'hor' and 'all' flags. To start, just print tokens where they would be
    -- and see what happens
    return labels
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

    opts.keepjumps = ut._use_gb_if_nil(opts.keepjumps, "farsight_csearch_keepjumps", cur_buf)
    opts.keepjumps = ut._resolve_bool_opt(opts.keepjumps, true)

    opts.tokens = ut._use_gb_if_nil(opts.tokens, "farsight_csearch_tokens", cur_buf)
    opts.tokens = opts.tokens or TOKENS
    vim.validate("opts.tokens", opts.tokens, "table")
    require("farsight.util")._list_dedup(opts.tokens)
    ut._validate_list(opts.tokens, { item_type = "string" })

    opts.on_jump = ut._use_gb_if_nil(opts.on_jump, "farsight_csearch_on_jump", cur_buf)
    vim.validate("opts.on_jump", opts.on_jump, "callable", true)

    opts.show_hl = ut._use_gb_if_nil(opts.show_hl, "farsight_csearch_show_hl", cur_buf)
    opts.show_hl = ut._resolve_bool_opt(opts.show_hl, true)

    -- TODO: Document in the type that this is only locally controlled
    opts.t_cmd = opts.t_cmd or 0
    vim.validate("opts.t_cmd", opts.t_cmd, function()
        return opts.t_cmd == 0 or opts.t_cmd == 1
    end, "opts.t_cmd must be 0 or 1")

    -- TODO: Document that the cpo option does not control here
    opts.t_cmd_skip = ut._use_gb_if_nil(opts.t_cmd_skip, "farsight_csearch_t_cmd_skip_ft", cur_buf)
    opts.t_cmd_skip = ut._resolve_bool_opt(opts.t_cmd_skip, false)

    local gb_max_tokens = "farsight_csearch_max_hl_steps"
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
---@field keepjumps? boolean
---@field on_jump? fun(win: integer, buf: integer, pos: { [1]: integer, [2]: integer })
---@field t_cmd_skip? boolean

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
            local labels = get_csearch_labels(cur_pos, opts)
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

    -- As per searchc in search.c
    if is_repeating == 0 then
        fn.setcharsearch({
            char = char,
            forward = opts.forward,
            ["until"] = opts.t_cmd,
        })
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

    local ut = require("farsight.util")
    local cur_win = api.nvim_get_current_win()
    local cur_buf = api.nvim_win_get_buf(cur_win)

    opts.keepjumps = ut._use_gb_if_nil(opts.keepjumps, "farsight_csearch_keepjumps", cur_buf)
    opts.keepjumps = ut._resolve_bool_opt(opts.keepjumps, true)

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
-- TODO: nv_csearch contains a fold adjustment at the end. What does this do? Do I need to
-- implement it?
-- TODO: Check if the user is prompted for chars when running macros on default f/t
-- TODO: During highlighting, use screenpos() to check for invalid positions

-- MID: The default tokens should be 'isk' for the current buffer. The isk strings + tokens can
-- be cached when created for the first time. For subsequent runs, re-query the opt string and
-- only rebuild the list if the string has changed
-- MID: It would be better if the user could customize how the highlight tokens are generatred.
-- Not seeing any natural hook points at the moment though. This is also on hold for isk parsing,
-- as that opens up other possibilities
-- MID: If wrap is on and a line runs off the end of the screen, you could f/t into it
-- unexpectedly. For the last line, would be good to be able to stop where it actually displays
-- MID: For token iteration, is there some kind of Rust-esque optimization where raw bytes can be
-- iterated over instead of the string/char representations?
-- MID: Multiple cases where we need to re-pull lines for corrections. Check if adding the line to
-- pos causes slowdown
-- MID: Is search() faster than using string.find? It also comes with helpful features like
-- searching backward. It might also plug into the some logic that csearch uses

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

-- PR: It would be cool if Neovim provided some kind of clear_plugin_highlights function that
-- plugins could register with. That way, users couldn't have to create bespoke highlight clearing
-- for every plugin (that said, how does Flash do it?)
-- PR: matchstrpos has a non-specific return type. This would require some digging though, as the
-- return type can differ based on the args
-- PR: It should be possible to detect if you are in the middle of a dot repeat.

-- NON: Allowing max_tokens > 3. This would result in more than four keypresses to get to a
-- location. The other Farsight modules can get you anywhere in four or less
-- NON: Multi-window. Significant perf/complexity cost for trivial practical benefit
-- NON: Persistent highlighting
-- - Creates code complexity/error surface area
-- - A bad trap with Vim motions is using repetitive presses instead of decisive motions (tapping
-- hjkl repeatedly being the classic example). Having highlights persist encourages repetitively
-- tapping ;,
-- NON: No ignorecase/smartcast support for csearch. Adds an extra cognitive layer to interpreting
-- what is being displayed that I'm not interested in
