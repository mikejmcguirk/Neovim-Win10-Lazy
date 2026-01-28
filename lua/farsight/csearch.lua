local api = vim.api
local fn = vim.fn

local MAX_MAX_HL_STEPS = 3
local DEFAULT_MAX_HL_STEPS = MAX_MAX_HL_STEPS
local TOKENS = vim.split("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ", "")

local HL_1ST_STR = "FarsightCsearch1st"
local HL_2ND_STR = "FarsightCsearch2nd"
local HL_3RD_STR = "FarsightCsearch3rd"

-- TODO: Can't use these defaults because they assume termguicolors
api.nvim_set_hl(0, HL_1ST_STR, { default = true, reverse = true })
api.nvim_set_hl(0, HL_2ND_STR, { default = true, undercurl = true })
api.nvim_set_hl(0, HL_3RD_STR, { default = true, underdouble = true })

local hl_1st = api.nvim_get_hl_id_by_name(HL_1ST_STR)
local hl_2nd = api.nvim_get_hl_id_by_name(HL_2ND_STR)
local hl_3rd = api.nvim_get_hl_id_by_name(HL_3RD_STR)

local HL_NS = api.nvim_create_namespace("FarsightCsearch")

local last_dir = nil
local last_t_cmd = nil
local last_input = nil

local cword_str = [[\k\+]]
local priority_map = { hl_3rd, hl_2nd, hl_1st } ---@type integer[]

---@class farsight.csearch.TokenLabel
---@field [1] integer row
---@field [2] integer col
---@field [3] integer hl byte length
---@field [4] integer hl_group id

---@param token_counts table<integer, integer>|table<string, integer>
---@param remaining integer
---@param char integer|string
local function decrement_token_count(token_counts, remaining, char)
    if token_counts[char] > 1 then
        token_counts[char] = remaining - 1
    else
        token_counts[char] = nil
    end
end

---@param word string
---@param token_counts table<integer, integer>|table<string, integer>
local function decrement_utf_word(word, token_counts)
    for i = 0, fn.strcharlen(word[1]) - 1 do
        local char = fn.strcharpart(word[1], i, 1, true) ---@type string
        local remaining = token_counts[char] ---@type integer?
        if remaining then
            decrement_token_count(token_counts, remaining, char)
        end
    end
end

---@param word string
---@param token_counts table<integer, integer>|table<string, integer>
local function decrement_ascii_word(word, token_counts)
    for i = 1, #word do
        local char = string.byte(word, i)
        local remaining = token_counts[char] ---@type integer?
        if remaining then
            decrement_token_count(token_counts, remaining, char)
        end
    end
end

---@param res { [1]: string, [2]: integer, [3]: integer }
---@param token_counts table<integer, integer>|table<string, integer>
---@return integer|nil, integer|nil, integer|nil, integer|nil
local function utf_counter(res, token_counts)
    local strcharlen = fn.strcharlen(res[1])
    local priority = 0
    local idx
    local len
    local hl_id

    for i = 0, strcharlen - 1 do
        local char_start = vim.fn.byteidx(res[1], i)
        local char = fn.strcharpart(res[1], i, 1, true) ---@type string
        local remaining = token_counts[char] ---@type integer?
        if remaining then
            if remaining > priority then
                priority = remaining
                idx = char_start
                len = #char
                hl_id = priority_map[priority]
            end

            decrement_token_count(token_counts, remaining, char)
        end
    end

    return priority, idx, len, hl_id
end

---@param res { [1]: string, [2]: integer, [3]: integer }
---@param token_counts table<integer, integer>|table<string, integer>
---@return integer|nil, integer|nil, integer|nil, integer|nil
local function utf_counter_rev(res, token_counts)
    local strcharlen = fn.strcharlen(res[1])
    local priority = 0
    local idx
    local len
    local hl_id

    for i = strcharlen - 1, 1, -1 do
        local char_start = vim.fn.byteidx(res[1], i)
        local char = fn.strcharpart(res[1], i, 1, true) ---@type string
        local remaining = token_counts[char] ---@type integer?
        if remaining then
            if remaining >= priority then
                priority = remaining
                idx = char_start
                len = #char
                hl_id = priority_map[priority]
            end

            decrement_token_count(token_counts, remaining, char)
        end
    end

    return priority, idx, len, hl_id
end

---@param res { [1]: string, [2]: integer, [3]: integer }
---@param token_counts table<integer, integer>|table<string, integer>
---@return integer|nil, integer|nil, integer|nil, integer|nil
local function ascii_counter(res, token_counts)
    local priority = 0
    local idx
    local hl_id

    for i = 1, #res[1] do
        local byte = string.byte(res[1], i)
        local remaining = token_counts[byte] ---@type integer?
        if remaining then
            if remaining > priority then
                priority = remaining
                idx = i - 1
                hl_id = priority_map[priority]
            end

            decrement_token_count(token_counts, remaining, byte)
        end
    end

    return priority, idx, 1, hl_id
end

---@param res { [1]: string, [2]: integer, [3]: integer }
---@param token_counts table<integer, integer>|table<string, integer>
---@return integer|nil, integer|nil, integer|nil, integer|nil
local function ascii_counter_rev(res, token_counts)
    local priority = 0
    local idx
    local hl_id

    for i = #res[1], 1, -1 do
        local byte = string.byte(res[1], i)
        local remaining = token_counts[byte] ---@type integer?
        if remaining then
            if remaining >= priority then
                priority = remaining
                idx = i - 1
                hl_id = priority_map[priority]
            end

            decrement_token_count(token_counts, remaining, byte)
        end
    end

    return priority, idx, 1, hl_id
end

---Edits token_counts and labels in place
---@param line string
---@param row_0 integer
---@param token_counts table<integer, integer>|table<string,integer>
---@param labels farsight.csearch.TokenLabel[]
local function iter_tokens_forward(tokener_func, line, row_0, token_counts, labels)
    local pos = 0
    while pos < #line do
        local res = vim.fn.matchstrpos(line, cword_str, pos)
        if res[2] < 0 then
            break
        end

        local priority, idx, len, hl_id = tokener_func(res, token_counts)
        if priority > 0 then
            labels[#labels + 1] = { row_0, res[2] + idx, len, hl_id }
        end

        if not next(token_counts) then
            return
        end

        pos = res[3] -- Already exclusive indexed
    end
end

---Edits token_counts and labels in place
---@param line string
---@param row_0 integer
---@param token_counts table<integer, integer>|table<string,integer>
---@param labels farsight.csearch.TokenLabel[]
local function iter_tokens_backward(tokener_func, line, row_0, token_counts, labels)
    local words = {} -- Collect all word res forward, then process backward
    local pos = 0
    while pos < #line do
        local res = vim.fn.matchstrpos(line, cword_str, pos)
        if res[2] < 0 then
            break
        end

        words[#words + 1] = res
        pos = res[3]
    end

    for i = #words, 1, -1 do
        local priority, idx, len, hl_id = tokener_func(words[i], token_counts)
        if priority > 0 then
            labels[#labels + 1] = { row_0, words[i][2] + idx, len, hl_id }
        end

        if not next(token_counts) then
            return
        end
    end
end

---@param tokens string[]
---@return boolean
local function is_ascii_only(tokens)
    for _, token in ipairs(tokens) do
        if #token > 1 then
            return false
        end
    end

    return true
end

---@param tokens string[]
---@return integer[]
local function tokens_as_codes(tokens)
    local codes = {}
    for _, token in ipairs(tokens) do
        codes[#codes + 1] = string.byte(token)
    end

    return codes
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

---@param is_ascii boolean
---@param tokens string[]
---@param max_hl_steps integer
---@return table<integer, integer>|table<string, integer>
local function create_token_counts(is_ascii, tokens, max_hl_steps)
    tokens = vim.deepcopy(tokens)
    tokens = is_ascii and tokens_as_codes(tokens) or tokens
    local token_counts = {} ---@type table<integer, integer>|table<string, integer>
    for _, token in ipairs(tokens) do
        token_counts[token] = max_hl_steps
    end

    return token_counts
end

---@param cur_pos { [1]: integer, [2]: integer }
---@param buf integer
---@param tokens string[]
---@param max_hl_steps integer
local function hl_forward(cur_pos, buf, tokens, max_hl_steps)
    local is_ascii = is_ascii_only(tokens)
    ---@type table<integer, integer>|table<string, integer>
    local token_counts = create_token_counts(is_ascii, tokens, max_hl_steps)
    if not next(token_counts) then
        return
    end

    local counter_func = is_ascii and ascii_counter or utf_counter
    local decrement_func = is_ascii and decrement_ascii_word or decrement_utf_word
    local labels = {} ---@type farsight.csearch.TokenLabel[]

    if fn.foldclosed(cur_pos[1]) == -1 then
        local cur_line = api.nvim_buf_get_lines(buf, cur_pos[1] - 1, cur_pos[1], false)[1]
        local col_after_1 = cur_pos[2] + 2
        local cur_res = require("farsight.util")._find_cword_at_col(cur_line, cur_pos[2])
        if cur_res then
            local suffix = string.sub(cur_line, col_after_1, cur_res[3])
            decrement_func(suffix, token_counts)
            col_after_1 = cur_res[3] + 1
        end

        local line_after = string.sub(cur_line, col_after_1)
        iter_tokens_forward(counter_func, line_after, cur_pos[1] - 1, token_counts, labels)
        for _, label in ipairs(labels) do
            local before_len = #cur_line - #line_after
            label[2] = label[2] + before_len
        end
    end

    for i = cur_pos[1] + 1, fn.line("w$") do
        if not next(token_counts) then
            break
        end

        if fn.foldclosed(i) == -1 then
            local line = api.nvim_buf_get_lines(buf, i - 1, i, false)[1]
            iter_tokens_forward(counter_func, line, i - 1, token_counts, labels)
        end
    end

    highlight_labels(buf, labels)
end

---@param cur_pos { [1]: integer, [2]: integer }
---@param buf integer
---@param tokens string[]
---@param max_hl_steps integer
local function hl_backward(cur_pos, buf, tokens, max_hl_steps)
    local is_ascii = is_ascii_only(tokens)
    ---@type table<integer, integer>|table<string, integer>
    local token_counts = create_token_counts(is_ascii, tokens, max_hl_steps)
    if not next(token_counts) then
        return
    end

    local checker_func = is_ascii and ascii_counter_rev or utf_counter_rev
    local decrement_func = is_ascii and decrement_ascii_word or decrement_utf_word
    local labels = {} ---@type farsight.csearch.TokenLabel[]

    if fn.foldclosed(cur_pos[1]) == -1 then
        local cur_line = api.nvim_buf_get_lines(buf, cur_pos[1] - 1, cur_pos[1], false)[1]
        local col_before_1 = cur_pos[2]
        local cur_res = require("farsight.util")._find_cword_at_col(cur_line, cur_pos[2])
        if cur_res then
            local prefix = string.sub(cur_line, cur_res[2] + 1, col_before_1)
            decrement_func(prefix, token_counts)
            col_before_1 = cur_res[2]
        end

        local line_before = string.sub(cur_line, 1, col_before_1)
        iter_tokens_backward(checker_func, line_before, cur_pos[1] - 1, token_counts, labels)
    end

    for i = cur_pos[1] - 1, fn.line("w0"), -1 do
        if not next(token_counts) then
            break
        end

        if fn.foldclosed(i) == -1 then
            local line = api.nvim_buf_get_lines(buf, i - 1, i, false)[1]
            iter_tokens_backward(checker_func, line, i - 1, token_counts, labels)
        end
    end

    highlight_labels(buf, labels)
end

---@param this_line string
---@param row integer
---@param input string
---@param count integer
---@param found_pos { [1]: integer, [2]: integer }|nil
---@return integer, { [1]: integer, [2]: integer }|nil
local function csearch_line_forward(this_line, row, input, count, found_pos)
    local search_pos = 1

    while count > 0 do
        local start = string.find(this_line, input, search_pos, true)
        if not start then
            break
        end

        count = count - 1
        local start_0 = start - 1 ---@type integer
        found_pos = { row, start_0 }
        search_pos = start + #input
    end

    return count, found_pos
end

---@param buf integer
---@param pos { [1]: integer, [2]: integer }
local function handle_t_cmd(buf, pos)
    local line = api.nvim_buf_get_lines(buf, pos[1] - 1, pos[1], false)[1]
    local char_idx = vim.fn.charidx(line, pos[2])

    if char_idx > 1 then
        pos[2] = fn.byteidx(line, char_idx - 1)
    else
        pos[1] = pos[1] - 1

        local prev_line = api.nvim_buf_get_lines(buf, pos[1] - 1, pos[1], false)[1]
        local strcharlen = fn.strcharlen(prev_line)
        pos[2] = fn.byteidx(prev_line, math.max(strcharlen - 1, 0))
    end

    return pos
end

---@param count integer
---@param win integer
---@param cur_pos { [1]: integer, [2]: integer }
---@param buf integer
---@param input string
---@param t_cmd boolean
---@param t_cmd_skip boolean
local function csearch_forward(count, win, cur_pos, buf, input, t_cmd, t_cmd_skip)
    local found_pos = nil ---@type { [1]: integer, [2]: integer }|nil

    if fn.foldclosed(cur_pos[1]) == -1 then
        local cur_line = api.nvim_buf_get_lines(buf, cur_pos[1] - 1, cur_pos[1], false)[1]
        local charidx = fn.charidx(cur_line, cur_pos[2])
        local char = fn.strcharpart(cur_line, charidx, 1, true) ---@type string
        local col_after_cursor_1 = cur_pos[2] + #char + 1

        if t_cmd and t_cmd_skip then
            local col_after_cursor = col_after_cursor_1 - 1
            local next_charidx = fn.charidx(cur_line, col_after_cursor)
            local next_char = fn.strcharpart(cur_line, next_charidx, 1, true)
            if next_char == input then
                col_after_cursor_1 = col_after_cursor_1 + #next_char
            end
        end

        -- Allow "" substrings if col_after_cursor_1 > #cur_line
        local line_after = cur_line:sub(col_after_cursor_1)
        count, found_pos = csearch_line_forward(line_after, cur_pos[1], input, count, found_pos)
        if found_pos then
            found_pos[2] = found_pos[2] + (#cur_line - #line_after)
        end
    end

    local i = cur_pos[1] + 1
    local bot = fn.line("w$")
    while i <= bot and count > 0 do
        if fn.foldclosed(i) == -1 then
            local this_line = api.nvim_buf_get_lines(buf, i - 1, i, false)[1]
            count, found_pos = csearch_line_forward(this_line, i, input, count, found_pos)
        end

        i = i + 1
    end

    if found_pos then
        if t_cmd then
            handle_t_cmd(buf, found_pos)
        end

        api.nvim_win_set_cursor(win, found_pos)
        -- api.nvim_cmd({ cmd = "norm", args = { "zv" }, bang = true }, {})
    end
end

-- Reversing the string performs about as well as iterating forward through repeated calls to find

---@param this_line string
---@param row integer
---@param input string
---@param count integer
---@param found_pos { [1]: integer, [2]: integer }|nil
---@return integer, { [1]: integer, [2]: integer }|nil
local function csearch_line_backward(this_line, row, input, count, found_pos)
    -- TODO: Profile this
    if #this_line == 0 then
        return count, found_pos
    end

    local rev_line = this_line:reverse()
    local rev_input = input:reverse()
    local search_pos = 1

    while count > 0 do
        local rev_start = rev_line:find(rev_input, search_pos, true)
        if not rev_start then
            break
        end

        count = count - 1
        local start_0 = #this_line - (rev_start + #input - 1)
        found_pos = { row, start_0 }
        search_pos = rev_start + #rev_input
    end

    return count, found_pos
end

---@param buf integer
---@param pos { [1]: integer, [2]: integer }
local function handle_t_cmd_rev(buf, pos)
    local line = api.nvim_buf_get_lines(buf, pos[1] - 1, pos[1], false)[1]
    local char_idx = vim.fn.charidx(line, pos[2])

    if char_idx < vim.fn.strcharlen(line) - 1 then
        pos[2] = fn.byteidx(line, char_idx + 1)
    else
        pos[1] = pos[1] + 1
        pos[2] = 0
    end

    return pos
end

---@param count integer
---@param win integer
---@param cur_pos { [1]: integer, [2]: integer }
---@param buf integer
---@param input string
---@param t_cmd boolean
---@param t_cmd_skip boolean
local function csearch_backward(count, win, cur_pos, buf, input, t_cmd, t_cmd_skip)
    local found_pos = nil ---@type { [1]: integer, [2]: integer }|nil

    if fn.foldclosed(cur_pos[1]) == -1 then
        local cur_line = api.nvim_buf_get_lines(buf, cur_pos[1] - 1, cur_pos[1], false)[1]
        local col_before_cursor_1 = cur_pos[2]

        if t_cmd and t_cmd_skip then
            local col_before_cursor = col_before_cursor_1 - 1
            local prev_charidx = fn.charidx(cur_line, col_before_cursor)
            if fn.strcharpart(cur_line, prev_charidx, 1, true) == input then
                col_before_cursor = fn.byteidx(cur_line, prev_charidx) - 1
                col_before_cursor_1 = col_before_cursor + 1
            end
        end

        -- Allow "" substring if before_end_1 < 1
        local line_before = string.sub(cur_line, 1, col_before_cursor_1)
        count, found_pos = csearch_line_backward(line_before, cur_pos[1], input, count, found_pos)
    end

    local i = cur_pos[1] - 1
    local top = fn.line("w0")
    while i >= top and count > 0 do
        if fn.foldclosed(i) == -1 then
            local this_line = api.nvim_buf_get_lines(buf, i - 1, i, false)[1]
            count, found_pos = csearch_line_backward(this_line, i, input, count, found_pos)
        end

        i = i - 1
    end

    if found_pos then
        if t_cmd then
            found_pos = handle_t_cmd_rev(buf, found_pos)
        end

        api.nvim_win_set_cursor(win, found_pos)
        -- api.nvim_cmd({ cmd = "norm", args = { "zv" }, bang = true }, {})
    end
end

---@param opts farsight.csearch.CsearchOpts
local function resolve_csearch_opts(opts)
    vim.validate("opts", opts, "table")
    local ut = require("farsight.util")

    -- TODO: Do we make jump on enter a default? What does <cr> do by default?
    opts.actions = opts.actions or {}
    vim.validate("opts.actions", opts.actions, "table")
    for k, v in pairs(opts.actions) do
        vim.validate("k", k, "string")
        vim.validate("v", v, "callable")
    end

    opts.forward = ut._resolve_bool_opt(opts.forward, true)
    vim.validate("opts.forward", opts.forward, "boolean")

    opts.hl = ut._resolve_bool_opt(opts.hl, true)
    vim.validate("opts.hl", opts.hl, "boolean")

    opts.t_cmd = ut._resolve_bool_opt(opts.t_cmd, false)
    vim.validate("opts.t_cmd", opts.t_cmd, "boolean")

    opts.tokens = opts.tokens or TOKENS
    ut._validate_list(opts.tokens, { item_type = "string" })

    opts.max_hl_steps = opts.max_hl_steps or DEFAULT_MAX_HL_STEPS
    ut._validate_uint(opts.max_hl_steps)
    opts.max_hl_steps = math.min(opts.max_hl_steps, MAX_MAX_HL_STEPS)
end

---@class farsight.Csearch
local Csearch = {}

-- TODO: Document this
-- TODO: No reason for this not to have the option to skip
-- TODO: For actions, document that all inputs are simplified, even if manually unsimplified

---@class farsight.csearch.CsearchOpts
---@field actions? table<string, fun()>
---@field forward? boolean
---@field hl? boolean
---@field max_hl_steps? integer
---@field t_cmd? boolean
---@field tokens? string[]

---@param opts? farsight.csearch.CsearchOpts
function Csearch.csearch(opts)
    opts = opts and vim.deepcopy(opts, true) or {}
    resolve_csearch_opts(opts)

    local cur_win = api.nvim_get_current_win()
    local cur_pos = api.nvim_win_get_cursor(cur_win)
    local cur_buf = api.nvim_win_get_buf(cur_win)

    local forward = opts.forward
    if opts.hl then
        api.nvim__ns_set(HL_NS, { wins = { cur_win } })
        if forward then
            hl_forward(cur_pos, cur_buf, opts.tokens, opts.max_hl_steps)
        else
            hl_backward(cur_pos, cur_buf, opts.tokens, opts.max_hl_steps)
        end

        api.nvim__redraw({ valid = true })
    end

    local _, input = pcall(fn.getcharstr)
    pcall(api.nvim_buf_clear_namespace, cur_buf, HL_NS, 0, -1)
    for key, action in pairs(opts.actions) do
        -- TODO: Document the replace_termcode behavior
        local rep_key = api.nvim_replace_termcodes(key, true, false, true)
        if input == rep_key then
            action()
            return
        end
    end

    local input_byte = string.byte(input)
    local is_ascii_control_char = input_byte <= 31 or input_byte == 127
    if type(input) == "nil" or is_ascii_control_char or #input == 0 then
        return
    end

    local t_cmd = opts.t_cmd ---@type boolean
    last_dir = forward
    last_t_cmd = t_cmd
    last_input = input

    if opts.forward then
        csearch_forward(1, cur_win, cur_pos, cur_buf, input, t_cmd, false)
    else
        csearch_backward(1, cur_win, cur_pos, cur_buf, input, t_cmd, false)
    end
end

---@class farsight.csearch.RepOpts
---@field reverse? boolean
---@field skip? boolean

---@param opts? farsight.csearch.RepOpts
function Csearch.rep(opts)
    opts = opts or {}
    vim.validate("opts.reverse", opts.reverse, "boolean", true)
    vim.validate("opts.skip", opts.skip, "boolean", true)

    if type(last_dir) ~= "boolean" then
        return
    end

    if type(last_t_cmd) ~= "boolean" then
        return
    end

    if type(last_input) ~= "string" then
        return
    end

    local cur_win = api.nvim_get_current_win()
    local cur_pos = api.nvim_win_get_cursor(cur_win)
    local cur_buf = api.nvim_win_get_buf(cur_win)

    local this_dir = (function()
        if opts.reverse then
            return not last_dir
        else
            return last_dir
        end
    end)()

    local skip = (function()
        if type(opts.skip) ~= "nil" then
            return opts.skip
        end

        local cpo = api.nvim_get_option_value("cpo", {})
        local default_skip = string.find(cpo, ";", 1, true)
        return type(default_skip) == "nil"
    end)()

    if this_dir then
        csearch_forward(vim.v.count1, cur_win, cur_pos, cur_buf, last_input, last_t_cmd, skip)
    else
        csearch_backward(vim.v.count1, cur_win, cur_pos, cur_buf, last_input, last_t_cmd, skip)
    end
end

return Csearch

-- Profiling code:
-- local start_time = vim.uv.hrtime()
-- local end_time = vim.uv.hrtime()
-- local duration_ms = (end_time - start_time) / 1e6
-- print(string.format("hl_forward took %.2f ms", duration_ms))

-- TODO: The module contains a lot of functions that are only barely different. Now that the code
-- is actually written, can factor more aggressively
-- TODO: A lot of this can probably be made to be common with jump
-- TODO: g:vars:
-- - default tokens
-- - max_tokens
-- - inner actions
-- - Map defaults
-- TODO: <Plug> maps: f, t, F, T, ;, ,
-- - EasyMotion fallbacks
-- - 3 hl tokens
-- - Same window
-- Problem: How do you make the inner action map responsive for all? Editing an inner actions
-- var doesn't quite do it because f/t need different actions with different opts. I really do not
-- love having a var for how to map jump by default, as that's an extra thing that doesn't really
-- fit with the default/g/plug/API scheme I have
-- TODO: The enter fallback should be an EasyMotion style f/t. So, uni-directional and restricted
-- to the same window. This would then also require Jump to have a t compensation opt
-- TODO: Rough opinion, and this applies to the jump module too - The default mappings should be
-- what make sense. The Plug maps should be the default settings. And then customization should be
-- done through the APIs.
-- TODO: Go through the extmark opts doc to see what works here
-- TODO: Document that rep() checks cpo for default t skip behavior
-- TODO: Test/document dot repeat behavior for operators. Should at least match what default f/t
-- does

-- MID: The default tokens should be 'isk' for the current buffer. The isk strings + tokens can
-- be cached when created for the first time. For subsequent runs, re-query the opt string and
-- only rebuild the list if the string has changed
-- MID: It would be better if the user could customize how the highlight tokens are generatred.
-- Not seeing any natural hook points at the moment though. This is also on hold for isk parsing,
-- as that opens up other possibilities
-- MID: Add the ability to csearch across windows. Realistically though, this can't acutally do
-- much but would cause a non-trivial perf decrease
-- MID: Add some kind of functionality like flash where, after a csearch, the chosen char remains
-- highlighted. I'm not sure how to turn it off though without setting up a key listener
-- MID: If wrap is on and a line runs off the end of the screen, you could f/t into it
-- unexpectedly. For the last line, would be good to be able to stop where it actually displays
-- MID: For token iteration, is there some kind of Rust-esque optimization where raw bytes can be
-- iterated over instead of the string/char representations?

-- LOW: Rather than niling tokens that cannot be highlighted, could separately keep track of
-- how many highlightable tokens remain. Saw slight perf gain when trying this, but not enough to
-- be sure it isn't just noise. Since a separate count also introduces another point of failure,
-- sticking with the keys based tracking.
-- LOW: For the actual search and jump, after pulling the first line, the next ~4 lines could be
-- pulled as a group (only one API call) since that's the most likely, then chunks of the rest
-- LOW: Try the labels as a struct of arrays.
-- LOW: Ignoring fold lines is in line with the built-in behavior, but is there a better solution?

-- PR: Two issues with starcharpart:
-- - The lua return type is any, but the doc says an empty string is returned on error. Check the
-- code, but the annotation looks wrong
-- - The docs talk about setting skipcc to one, but the variable in Lua takes a boolean. Unsure
-- what the cause of the mis-match here is
-- PR: It would be cool if Neovim provided some kind of clear_plugin_highlights function that
-- plugins could register with. That way, users couldn't have to create bespoke highlight clearing
-- for every plugin (that said, how does Flash do it?)
