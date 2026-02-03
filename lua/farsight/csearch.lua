local api = vim.api
local fn = vim.fn

local MAX_MAX_HL_STEPS = 3
local DEFAULT_MAX_HL_STEPS = MAX_MAX_HL_STEPS
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

local HL_NS = api.nvim_create_namespace("FarsightCsearch")

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
    local strcharpart = fn.strcharpart
    for i = 0, fn.strcharlen(word[1]) - 1 do
        local char = strcharpart(word[1], i, 1, true) ---@type string
        local remaining = token_counts[char] ---@type integer?
        if remaining then
            decrement_token_count(token_counts, remaining, char)
        end
    end
end

---@param word string
---@param token_counts table<integer, integer>|table<string, integer>
local function decrement_ascii_word(word, token_counts)
    local byte = string.byte
    for i = 1, #word do
        local char = byte(word, i)
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
    local word = res[1]
    local charlen = fn.strcharlen(word)
    local priority = 0
    local idx
    local len
    local hl_id

    local byteidx = fn.byteidx
    local strcharpart = fn.strcharpart
    for i = 0, charlen - 1 do
        local char_start = byteidx(word, i)
        local char = strcharpart(word, i, 1, true) ---@type string
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
    local word = res[1]
    local charlen = fn.strcharlen(word)
    local priority = 0
    local idx
    local len
    local hl_id

    local byteidx = fn.byteidx
    local strcharpart = fn.strcharpart
    for i = charlen - 1, 1, -1 do
        local char_start = byteidx(word, i)
        local char = strcharpart(word, i, 1, true) ---@type string
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
---@return integer, integer|nil, integer, integer|nil
local function ascii_counter(res, token_counts)
    local priority = 0
    local idx
    local hl_id

    local word = res[1]
    local byte = string.byte
    for i = 1, #word do
        local str_byte = byte(word, i)
        local remaining = token_counts[str_byte] ---@type integer?
        if remaining then
            if remaining > priority then
                priority = remaining
                idx = i - 1
                hl_id = priority_map[priority]
            end

            decrement_token_count(token_counts, remaining, str_byte)
        end
    end

    return priority, idx, 1, hl_id
end

---@param res { [1]: string, [2]: integer, [3]: integer }
---@param token_counts table<integer, integer>|table<string, integer>
---@return integer, integer|nil, integer, integer|nil
local function ascii_counter_rev(res, token_counts)
    local priority = 0
    local idx
    local hl_id

    local word = res[1]
    local byte = string.byte
    for i = #word, 1, -1 do
        local str_byte = byte(word, i)
        local remaining = token_counts[str_byte] ---@type integer?
        if remaining then
            if remaining >= priority then
                priority = remaining
                idx = i - 1
                hl_id = priority_map[priority]
            end

            decrement_token_count(token_counts, remaining, str_byte)
        end
    end

    return priority, idx, 1, hl_id
end

---Edits token_counts and labels in place
---@param counter_func fun(res: { [1]: string, [2]: integer, [3]: integer }, token_counts: table<integer, integer>|table<string, integer>)
---@param line string
---@param row_0 integer
---@param token_counts table<integer, integer>|table<string,integer>
---@param labels farsight.csearch.TokenLabel[]
local function iter_tokens_forward(counter_func, line, row_0, token_counts, labels)
    local pos = 0
    local line_len = #line
    local matchstrpos = fn.matchstrpos
    while pos < line_len do
        local res = matchstrpos(line, cword_str, pos)
        local start = res[2]
        if start < 0 then
            break
        end

        local priority, idx, len, hl_id = counter_func(res, token_counts)
        if priority > 0 then
            labels[#labels + 1] = { row_0, start + idx, len, hl_id }
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
local function iter_tokens_backward(counter_func, line, row_0, token_counts, labels)
    local results = {}
    local pos = 0
    local line_len = #line
    local matchstrpos = fn.matchstrpos
    while pos < line_len do
        local res = matchstrpos(line, cword_str, pos)
        if res[2] < 0 then
            break
        end

        results[#results + 1] = res
        pos = res[3]
    end

    local len_results = #results
    for i = len_results, 1, -1 do
        local res = results[i]
        local priority, idx, len, hl_id = counter_func(res, token_counts)
        if priority > 0 then
            labels[#labels + 1] = { row_0, res[2] + idx, len, hl_id }
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
local function get_tokens_as_codes(tokens)
    local codes = {}
    local byte = string.byte
    for _, token in ipairs(tokens) do
        codes[#codes + 1] = byte(token)
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
    tokens = is_ascii and get_tokens_as_codes(tokens) or tokens
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

    local row = cur_pos[1]
    local col = cur_pos[2]
    local nvim_buf_get_lines = api.nvim_buf_get_lines
    if fn.foldclosed(row) == -1 then
        local row_0 = row - 1
        local cur_line = nvim_buf_get_lines(buf, row_0, row, false)[1]
        local col_after_1 = col + 2
        local cur_res = require("farsight.util")._find_cword_at_col(cur_line, col)
        local sub = string.sub
        if cur_res then
            local res_to = cur_res[3]
            local suffix = sub(cur_line, col_after_1, res_to)
            decrement_func(suffix, token_counts)
            col_after_1 = res_to + 1
        end

        local line_after = sub(cur_line, col_after_1)
        iter_tokens_forward(counter_func, line_after, row_0, token_counts, labels)
        for _, label in ipairs(labels) do
            local before_len = #cur_line - #line_after
            label[2] = label[2] + before_len
        end
    end

    local next_row = row + 1
    local bot = fn.line("w$")
    for i = next_row, bot do
        if not next(token_counts) then
            break
        end

        if fn.foldclosed(i) == -1 then
            local i_0 = i - 1
            local line = nvim_buf_get_lines(buf, i_0, i, false)[1]
            iter_tokens_forward(counter_func, line, i_0, token_counts, labels)
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

    local row = cur_pos[1]
    local col = cur_pos[2]
    local row_0 = row - 1
    local nvim_buf_get_lines = api.nvim_buf_get_lines
    if fn.foldclosed(row) == -1 then
        local cur_line = nvim_buf_get_lines(buf, row_0, row, false)[1]
        local col_before_1 = col
        local cur_res = require("farsight.util")._find_cword_at_col(cur_line, col)
        local sub = string.sub
        if cur_res then
            local cur_res_from = cur_res[2]
            local prefix = sub(cur_line, cur_res_from + 1, col_before_1)
            decrement_func(prefix, token_counts)
            col_before_1 = cur_res_from
        end

        local line_before = sub(cur_line, 1, col_before_1)
        iter_tokens_backward(checker_func, line_before, row_0, token_counts, labels)
    end

    local top = fn.line("w0")
    for i = row_0, top, -1 do
        if not next(token_counts) then
            break
        end

        if fn.foldclosed(i) == -1 then
            local i_0 = i - 1
            local line = nvim_buf_get_lines(buf, i_0, i, false)[1]
            iter_tokens_backward(checker_func, line, i_0, token_counts, labels)
        end
    end

    highlight_labels(buf, labels)
end

---Returns cursor indexed row, col
---@param this_line string
---@param init integer
---@param row integer
---@param input string
---@param count integer
---@param pos { [1]: integer, [2]: integer }
---@return integer, { [1]: integer, [2]: integer }
local function csearch_line_forward(this_line, init, row, input, count, pos)
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
        local strcharlen = fn.strcharlen(prev_line) ---@type integer
        pos[2] = fn.byteidx(prev_line, math.max(strcharlen - 1, 0))
    end

    -- MAYBE: Technically pointless, but maintains consistency with the csearch_line functions
    return pos
end

---@param count integer
---@param win integer
---@param cur_pos { [1]: integer, [2]: integer }
---@param buf integer
---@param input string
---@param t_cmd integer
---@param t_cmd_skip boolean
local function csearch_forward(count, win, cur_pos, buf, input, t_cmd, t_cmd_skip)
    local byteidx = fn.byteidx
    local foldclosed = fn.foldclosed
    local nvim_buf_get_lines = api.nvim_buf_get_lines

    -- TODO: Why is cur_pos being passed in as a table just to be immediately broken up?
    local row = cur_pos[1]
    local col = cur_pos[2]
    local cur_line = nvim_buf_get_lines(buf, row - 1, row, false)[1]
    local cur_charidx = fn.charidx(cur_line, col)

    local charlen = fn.strcharlen(cur_line) ---@type integer
    local valid_line = foldclosed(row) == -1 and charlen > 1
    local last_byteidx = byteidx(cur_line, math.max(charlen - 1, 0))
    local search_cur_line = valid_line and col ~= last_byteidx

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
                return
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
        count, pos = csearch_line_forward(cur_line, next_col_1, row, input, count, pos)
    end

    local i = row + 1
    local bot = fn.line("w$")
    while i <= bot and count > 0 do
        if foldclosed(i) == -1 then
            local this_line = nvim_buf_get_lines(buf, i - 1, i, false)[1]
            count, pos = csearch_line_forward(this_line, 1, i, input, count, pos)
        end

        i = i + 1
    end

    if #pos == 2 then
        if t_cmd == 1 then
            pos = handle_t_cmd(buf, pos)
        end

        api.nvim_win_set_cursor(win, pos)
    end
end

-- Reversing the string performs about as well as iterating forward through repeated calls to find

---Returns cursor indexed row, col
---@param line string
---@param init integer
---@param row integer
---@param input string
---@param count integer
---@param found_pos { [1]: integer, [2]: integer }
---@return integer, { [1]: integer, [2]: integer }
local function csearch_line_rev(line, init, row, input, count, found_pos)
    local reverse = string.reverse
    local rev_line = reverse(line)
    local rev_input = reverse(input)

    local line_len = #line
    local input_len = #input

    local min_start_rev = line_len - input_len + 2 - init
    if min_start_rev < 1 then
        min_start_rev = 1
    end

    local search_pos = min_start_rev
    local find = string.find

    while count > 0 do
        local start = find(rev_line, rev_input, search_pos, true)
        if not start then
            break
        end

        count = count - 1

        local start_0 = line_len - start - input_len + 1
        found_pos = { row, start_0 }

        search_pos = start + input_len
    end

    return count, found_pos
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
---@param t_cmd integer
---@param t_cmd_skip boolean
local function csearch_backward(count, win, cur_pos, buf, input, t_cmd, t_cmd_skip)
    local byteidx = fn.byteidx
    local foldclosed = fn.foldclosed
    local nvim_buf_get_lines = api.nvim_buf_get_lines

    local row = cur_pos[1]
    local col = cur_pos[2]
    local cur_line = nvim_buf_get_lines(buf, row - 1, row, false)[1]
    local cur_charidx = fn.charidx(cur_line, col)
    local search_cur_line = foldclosed(row) == -1 and cur_charidx > 0

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

            -- LOW: Wasteful if starcharpart ~= input, as the loop grabs this again
            local prev_line = nvim_buf_get_lines(buf, prev_row - 1, prev_row, false)[1]
            local charlen = fn.strcharlen(cur_line) ---@type integer
            local last_byteidx = byteidx(prev_line, math.max(charlen - 1, 0))
            if fn.strcharpart(prev_line, last_byteidx, 1, true) == input then
                row = prev_row
                col = last_byteidx
                cur_line = prev_line
                cur_charidx = fn.charidx(prev_line, last_byteidx)
                search_cur_line = true
            end
        end
    end
    -- TODO: finish polishing the reverse function

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

    if #pos == 2 then
        if t_cmd == 1 then
            pos = handle_t_cmd_rev(buf, pos)
        end

        -- TODO: There needs to be a goto_jump function here that handles jumping. This needs to
        -- handle going to visual for omode, the on_jump callback, as well as adjusting the pos
        -- to the end of the character for visual (I think, needs to be confirmed)
        api.nvim_win_set_cursor(win, pos)
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

    opts.forward = opts.forward or 1
    vim.validate("opts.forward", opts.forward, function()
        return opts.forward == 0 or opts.forward == 1
    end, "opts.forward must be 0 or 1")

    opts.hl = ut._resolve_bool_opt(opts.hl, true)
    vim.validate("opts.hl", opts.hl, "boolean")

    opts.t_cmd = opts.t_cmd or 0
    vim.validate("opts.t_cmd", opts.t_cmd, function()
        return opts.t_cmd == 0 or opts.t_cmd == 1
    end, "opts.t_cmd must be 0 or 1")

    opts.tokens = opts.tokens or TOKENS
    ut._validate_list(opts.tokens, { item_type = "string" })
    require("farsight.util")._list_dedup(opts.tokens)
    ut._validate_list(opts.tokens, { min_len = 2 })

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
---@field forward? integer
---@field hl? boolean
---@field max_hl_steps? integer
---@field t_cmd? integer
---@field tokens? string[]

---@param opts? farsight.csearch.CsearchOpts
function Csearch.csearch(opts)
    opts = opts and vim.deepcopy(opts, true) or {}
    resolve_csearch_opts(opts)

    local cur_win = api.nvim_get_current_win()
    local cur_pos = api.nvim_win_get_cursor(cur_win)
    local cur_buf = api.nvim_win_get_buf(cur_win)

    local forward = opts.forward ---@type integer
    if opts.hl then
        api.nvim__ns_set(HL_NS, { wins = { cur_win } })
        if forward == 1 then
            hl_forward(cur_pos, cur_buf, opts.tokens, opts.max_hl_steps)
        else
            hl_backward(cur_pos, cur_buf, opts.tokens, opts.max_hl_steps)
        end

        api.nvim__redraw({ valid = true })
    end

    local _, input = pcall(fn.getcharstr)
    pcall(api.nvim_buf_clear_namespace, cur_buf, HL_NS, 0, -1)
    local nvim_replace_termcodes = api.nvim_replace_termcodes
    for key, action in pairs(opts.actions) do
        -- TODO: Document the replace_termcode behavior
        local rep_key = nvim_replace_termcodes(key, true, false, true)
        if input == rep_key then
            -- TODO: We could pass win/pos/buf into here
            action()
            return
        end
    end

    local input_byte = string.byte(input)
    local is_ascii_control_char = input_byte <= 31 or input_byte == 127
    local no_input = input == nil or #input == 0
    if is_ascii_control_char or no_input then
        return
    end

    local t_cmd = opts.t_cmd ---@type integer
    ---@diagnostic disable-next-line: param-type-mismatch
    fn.setcharsearch({
        char = input,
        forward = forward,
        ["until"] = t_cmd,
    })

    if forward == 1 then
        csearch_forward(1, cur_win, cur_pos, cur_buf, input, t_cmd, false)
    else
        csearch_backward(1, cur_win, cur_pos, cur_buf, input, t_cmd, false)
    end
end

---@class farsight.csearch.RepOpts
---@field forward? integer
---@field skip? boolean

---@param opts? farsight.csearch.RepOpts
function Csearch.rep(opts)
    opts = opts or {}
    opts.forward = opts.forward or 1
    vim.validate("opts.forward", opts.forward, function()
        return opts.forward == 0 or opts.forward == 1
    end, "opts.forward must be 0 or 1")

    vim.validate("opts.skip", opts.skip, "boolean", true)

    ---@type { char: string, forward: integer, until: integer }
    local charsearch = fn.getcharsearch()
    local char = charsearch.char
    if char == "" then
        return
    end

    local cur_win = api.nvim_get_current_win()
    local cur_pos = api.nvim_win_get_cursor(cur_win)
    local cur_buf = api.nvim_win_get_buf(cur_win)

    -- Bitshifts are LuaJIT only
    local forward = (opts.forward == 1) and charsearch.forward or (1 - charsearch.forward)
    local t_cmd = charsearch["until"]

    local skip = (function()
        if type(opts.skip) ~= "nil" then
            return opts.skip
        end

        local cpo = api.nvim_get_option_value("cpo", {})
        local cpo_noskip = string.find(cpo, ";", 1, true)
        return cpo_noskip == nil
    end)()

    local count1 = vim.v.count1
    if forward == 1 then
        csearch_forward(count1, cur_win, cur_pos, cur_buf, char, t_cmd, skip)
    else
        csearch_backward(count1, cur_win, cur_pos, cur_buf, char, t_cmd, skip)
    end
end

return Csearch

-- Profiling code:
-- local start_time = vim.uv.hrtime()
-- local end_time = vim.uv.hrtime()
-- local duration_ms = (end_time - start_time) / 1e6
-- print(string.format("hl_forward took %.2f ms", duration_ms))

-- TODO: The issue has come up again where t cmds cannot roll over the starts and ends of lines
-- This can be observed by doing t near the top of this file, You can't go backwards over the
-- n at the end of vim.fn, and you can't go forwards over an the n in nvim at the begnning of a
-- line. What's tough is that you have to change the structure because the t skip across lines
-- can't build on the normal result
-- TODO: Add an on_jump callback to the csearch and rev opts
-- TODO: For the getcharsearch and setcharsearch data, use vim's builtin datatypes consistently
-- TODO: Add visual selection voodoo so this works in omode
-- TODO: line 1: this is a length
--       line 2: some other line
-- Do a t motion to h on line 2, then try to go back. The cursor will stop at the beginning of
-- line 2, which is correct, but it will not then go backward past the h at the end of line 1
-- The initial skip scan then need to also check the end of the last line or the beginning of the
-- next one if you are at the beginning of a line or the end of one
-- Since ctrl char literals are displayed, maybe allow them to be factored into csearch and
-- jump
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
-- - When I dot repeat d<cr> is prompts me for the jump token. I think for that function that's
-- desirable behavior. For this, I think, using f/t should prompt for input, and dot repeat should
-- use saved values. But I'm not sure we can distinguish how we're entering omode, or if there's
-- a var we can leave behind. Could also add a key listener. Acceptable fallback is to always
-- prompt. Can also see what other plugins do

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
-- PR: setcharsearch has an incorrect type annotation. The input should be:
-- string|{ char: string, forward: integer, until: integer }
-- But is currently string. I think the params definition in src/nvim/eval.lua, and then run
-- a make cmd to re-generate runtime/lua/vim/_meta/vimfn.lua
-- PR: It would be cool if Neovim provided some kind of clear_plugin_highlights function that
-- plugins could register with. That way, users couldn't have to create bespoke highlight clearing
-- for every plugin (that said, how does Flash do it?)
