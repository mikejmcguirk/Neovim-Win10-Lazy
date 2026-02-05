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

-- LOW: This can't be the most efficient way to do this.

---Edits token_counts in place
---@param token_counts table<integer, integer>|table<string, integer>
---@param remaining integer
---@param char integer|string
local function decrement_tokens(token_counts, remaining, char)
    if token_counts[char] > 1 then
        token_counts[char] = remaining - 1
    else
        token_counts[char] = nil
    end
end

---Edits token_counts in place
---@param word string
---@param token_counts table<integer, integer>|table<string, integer>
local function decrement_utf_tokens(word, token_counts)
    local strcharpart = fn.strcharpart
    local last_charidx = fn.strcharlen(word[1]) - 1
    for i = 0, last_charidx do
        local char = strcharpart(word[1], i, 1, true) ---@type string
        local remaining = token_counts[char] ---@type integer?
        if remaining then
            decrement_tokens(token_counts, remaining, char)
        end
    end
end

---Edits token_counts in place
---@param word string
---@param token_counts table<integer, integer>|table<string, integer>
local function decrement_ascii_tokens(word, token_counts)
    local byte = string.byte
    local len_word = #word
    for i = 1, len_word do
        local char = byte(word, i)
        local remaining = token_counts[char] ---@type integer?
        if remaining then
            decrement_tokens(token_counts, remaining, char)
        end
    end
end

---Edits labels in place
---@param priority integer
---@param labels farsight.csearch.TokenLabel[]
---@param row_0 integer
---@param start integer
---@param len integer
---@param hl_id integer
local function checked_add_label(priority, labels, row_0, start, len, hl_id)
    if priority > 0 then
        labels[#labels + 1] = { row_0, start, len, hl_id }
    end
end

---Edits token_counts and labels in place
---@param res { [1]: string, [2]: integer, [3]: integer }
---@param token_counts table<integer, integer>|table<string, integer>
---@param labels farsight.csearch.TokenLabel[]
---@param row_0 integer
---@param step integer
---@param rem_check fun(a: integer, b: integer):boolean
local function utf_labeler(res, token_counts, labels, row_0, step, rem_check)
    local priority = 0
    local idx
    local len_char
    local hl_id

    local word = res[1]
    local start_word = res[2]
    local strcharpart = fn.strcharpart

    local iter_start = step == 1 and 0 or fn.strcharlen(word) - 1
    local iter_fin = step == 1 and fn.strcharlen(word) - 1 or 0
    for i = iter_start, iter_fin, step do
        local char = strcharpart(word, i, 1, true) ---@type string
        local remaining = token_counts[char] ---@type integer?
        if remaining then
            if rem_check(remaining, priority) then
                priority = remaining
                -- This might be skipped more often than not, so don't pre-get the reference
                idx = start_word + fn.byteidx(word, i)
                len_char = #char
                hl_id = priority_map[priority]
            end

            decrement_tokens(token_counts, remaining, char)
        end
    end

    checked_add_label(priority, labels, row_0, idx, len_char, hl_id)
end

---Edits token_counts and labels in place
---@param res { [1]: string, [2]: integer, [3]: integer }
---@param token_counts table<integer, integer>|table<string, integer>
---@param labels farsight.csearch.TokenLabel[]
---@param row_0 integer
local function utf_labeler_fwd(res, token_counts, labels, row_0)
    utf_labeler(res, token_counts, labels, row_0, 1, function(a, b)
        return a > b
    end)
end

---Edits token_counts and labels in place
---@param res { [1]: string, [2]: integer, [3]: integer }
---@param token_counts table<integer, integer>|table<string, integer>
---@param labels farsight.csearch.TokenLabel[]
---@param row_0 integer
local function utf_labeler_rev(res, token_counts, labels, row_0)
    utf_labeler(res, token_counts, labels, row_0, -1, function(a, b)
        return a >= b
    end)
end

---Edits token_counts and labels in place
---@param res { [1]: string, [2]: integer, [3]: integer }
---@param token_counts table<integer, integer>|table<string, integer>
---@param labels farsight.csearch.TokenLabel[]
---@param row_0 integer
---@param step integer
---@param rem_check fun(a: integer, b: integer):boolean
local function ascii_labeler(res, token_counts, labels, row_0, step, rem_check)
    local priority = 0
    local idx
    local hl_id

    local word = res[1]
    local start = res[2]
    local byte = string.byte

    local iter_start = step == 1 and 1 or #word
    local iter_fin = step == 1 and #word or 1
    for i = iter_start, iter_fin, step do
        local str_byte = byte(word, i)
        local remaining = token_counts[str_byte] ---@type integer?
        if remaining then
            if rem_check(remaining, priority) then
                priority = remaining
                idx = start + (i - 1)
                hl_id = priority_map[priority]
            end

            decrement_tokens(token_counts, remaining, str_byte)
        end
    end

    checked_add_label(priority, labels, row_0, idx, 1, hl_id)
end

---Edits token_counts and labels in place
---@param res { [1]: string, [2]: integer, [3]: integer }
---@param token_counts table<integer, integer>|table<string, integer>
---@param labels farsight.csearch.TokenLabel[]
---@param row_0 integer
local function ascii_labeler_fwd(res, token_counts, labels, row_0)
    ascii_labeler(res, token_counts, labels, row_0, 1, function(a, b)
        return a > b
    end)
end

---Edits token_counts and labels in place
---@param res { [1]: string, [2]: integer, [3]: integer }
---@param token_counts table<integer, integer>|table<string, integer>
---@param labels farsight.csearch.TokenLabel[]
---@param row_0 integer
local function ascii_labeler_rev(res, token_counts, labels, row_0)
    ascii_labeler(res, token_counts, labels, row_0, -1, function(a, b)
        return a >= b
    end)
end

---Edits token_counts and labels in place
---@param labeler_func fun(res: { [1]: string, [2]: integer, [3]: integer },
---token_counts: table<integer, integer>|table<string, integer>,
---labels: farsight.csearch.TokenLabel[], row_0: integer)
---@param line string
---@param init integer
---@param row_0 integer
---@param token_counts table<integer, integer>|table<string,integer>
---@param labels farsight.csearch.TokenLabel[]
local function iter_tokens_fwd(labeler_func, line, init, row_0, token_counts, labels)
    local len_line = #line
    local matchstrpos = fn.matchstrpos
    while init < len_line do
        local res = matchstrpos(line, cword_str, init)
        local start = res[2]
        if start < 0 then
            break
        end

        labeler_func(res, token_counts, labels, row_0)
        if not next(token_counts) then
            return
        end

        init = res[3] -- Already exclusive indexed
    end
end

---Edits token_counts and labels in place
---@param labeler_func fun(res: { [1]: string, [2]: integer, [3]: integer },
---token_counts: table<integer, integer>|table<string, integer>,
---labels: farsight.csearch.TokenLabel[], row_0: integer)
---@param line string
---@param row_0 integer
---@param token_counts table<integer, integer>|table<string,integer>
---@param labels farsight.csearch.TokenLabel[]
local function iter_tokens_rev(labeler_func, line, row_0, token_counts, labels)
    local results = {}
    local init = 0
    local len_line = #line
    local matchstrpos = fn.matchstrpos
    while init < len_line do
        local res = matchstrpos(line, cword_str, init)
        if res[2] < 0 then
            break
        end

        results[#results + 1] = res
        init = res[3] -- Already exclusive indexed
    end

    local len_results = #results
    for i = len_results, 1, -1 do
        labeler_func(results[i], token_counts, labels, row_0)
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
    local codes = {} ---@type integer[]
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

---@param buf integer
---@param row integer
---@param col integer
---@param tokens string[]
---@param max_hl_steps integer
local function hl_fwd(buf, row, col, tokens, max_hl_steps)
    local is_ascii = is_ascii_only(tokens)
    ---@type table<integer, integer>|table<string, integer>
    local token_counts = create_token_counts(is_ascii, tokens, max_hl_steps)
    if not next(token_counts) then
        return
    end

    local counter_func = is_ascii and ascii_labeler_fwd or utf_labeler_fwd
    local decrement_func = is_ascii and decrement_ascii_tokens or decrement_utf_tokens
    local labels = {} ---@type farsight.csearch.TokenLabel[]

    local nvim_buf_get_lines = api.nvim_buf_get_lines
    local row_0 = row - 1
    local cur_line = nvim_buf_get_lines(buf, row_0, row, false)[1]
    local col_1 = col + 1
    local foldclosed = fn.foldclosed
    if foldclosed(row) == -1 and col_1 < #cur_line then
        local init = col_1
        local cur_res = require("farsight.util")._find_cword_at_col(cur_line, col)
        local sub = string.sub
        if cur_res then
            local res_to = cur_res[3]
            local suffix = sub(cur_line, init + 1, res_to)
            decrement_func(suffix, token_counts)
            init = res_to
        end

        iter_tokens_fwd(counter_func, cur_line, init, row_0, token_counts, labels)
    end

    local next_row = row + 1
    local bot = fn.line("w$")
    for i = next_row, bot do
        if not next(token_counts) then
            break
        end

        if foldclosed(i) == -1 then
            local i_0 = i - 1
            local line = nvim_buf_get_lines(buf, i_0, i, false)[1]
            iter_tokens_fwd(counter_func, line, 0, i_0, token_counts, labels)
        end
    end

    highlight_labels(buf, labels)
end

---@param buf integer
---@param row integer
---@param col integer
---@param tokens string[]
---@param max_hl_steps integer
local function hl_rev(buf, row, col, tokens, max_hl_steps)
    local is_ascii = is_ascii_only(tokens)
    ---@type table<integer, integer>|table<string, integer>
    local token_counts = create_token_counts(is_ascii, tokens, max_hl_steps)
    if not next(token_counts) then
        return
    end

    local checker_func = is_ascii and ascii_labeler_rev or utf_labeler_rev
    local decrement_func = is_ascii and decrement_ascii_tokens or decrement_utf_tokens
    local labels = {} ---@type farsight.csearch.TokenLabel[]

    local row_0 = row - 1
    local nvim_buf_get_lines = api.nvim_buf_get_lines
    local foldclosed = fn.foldclosed
    if foldclosed(row) == -1 and col > 0 then
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
        iter_tokens_rev(checker_func, line_before, row_0, token_counts, labels)
    end

    local top = fn.line("w0")
    for i = row_0, top, -1 do
        if not next(token_counts) then
            break
        end

        -- MID: Is it faster to always get the line and then check if it's at least one byte?
        if foldclosed(i) == -1 then
            local i_0 = i - 1
            local line = nvim_buf_get_lines(buf, i_0, i, false)[1]
            iter_tokens_rev(checker_func, line, i_0, token_counts, labels)
        end
    end

    highlight_labels(buf, labels)
end

---@param win integer
---@param buf integer
---@param pos { [1]: integer, [2]: integer }
---@param opts farsight.csearch.CsearchOpts
local function do_cjump(win, buf, pos, opts)
    if string.sub(api.nvim_get_mode().mode, 1, 2) == "no" then
        -- TODO: This re-uses the data from and essentially re-creates the logic from the backward
        -- t_cmd_skip adjustment. The relevant data needs to be passed in so it isn't being
        -- pulled in duplicate. It also seems like a common function could be re-created that
        -- returns a row/col for the caller to use
        if opts.forward == 0 then
            local cur_pos = api.nvim_win_get_cursor(win)
            local cur_row = cur_pos[1]
            local cur_col = cur_pos[2]
            local cur_line = api.nvim_buf_get_lines(buf, cur_row - 1, cur_row, false)[1]
            local cur_charidx = fn.charidx(cur_line, cur_col)
            if cur_charidx > 1 then
                local prev_byteidx = fn.byteidx(cur_line, cur_charidx - 1)
                api.nvim_win_set_cursor(win, { cur_row, prev_byteidx })
            else
                local prev_row = math.max(cur_row - 1, 1)
                -- TODO: With the defaults, if you are on the first character if the first line,
                -- the backward motion is a noop. That behavior should be re-created here
                if prev_row < cur_row then
                    local prev_line = api.nvim_buf_get_lines(buf, prev_row - 1, prev_row, false)[1]
                    local prev_last_charidx = fn.strcharlen(prev_line) - 1
                    local prev_last_byteidx = fn.byteidx(prev_line, prev_last_charidx)
                    api.nvim_win_set_cursor(win, { prev_row, prev_last_byteidx })
                end
            end
        end

        api.nvim_cmd({ cmd = "norm", args = { "v" }, bang = true }, {})
        if vim.o.selection == "exclusive" then
            local row = pos[1]
            local line = api.nvim_buf_get_lines(buf, row - 1, row, false)[1]
            pos[2] = math.min(pos[2] + 1, math.max(#line - 1, 0))
        end
    end

    api.nvim_win_set_cursor(win, pos)
    local on_cjump = opts.on_cjump
    if on_cjump then
        on_cjump(win, buf, pos)
    end
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
        local strcharlen = fn.strcharlen(prev_line) ---@type integer
        pos[2] = fn.byteidx(prev_line, math.max(strcharlen - 1, 0))
    end

    -- MAYBE: Technically pointless, but maintains consistency with the csearch_line functions
    return pos
end

---@param count integer
---@param win integer
---@param buf integer
---@param row integer
---@param col integer
---@param input string
---@param opts farsight.csearch.CsearchOpts
local function csearch_fwd(count, win, buf, row, col, input, opts)
    local byteidx = fn.byteidx
    local foldclosed = fn.foldclosed
    local nvim_buf_get_lines = api.nvim_buf_get_lines

    local cur_line = nvim_buf_get_lines(buf, row - 1, row, false)[1]
    local cur_charidx = fn.charidx(cur_line, col)
    local charlen = fn.strcharlen(cur_line) ---@type integer
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

    if #pos == 2 then
        if t_cmd == 1 then
            pos = handle_t_cmd(buf, pos)
        end

        do_cjump(win, buf, pos, opts)
    end
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
---@param win integer
---@param buf integer
---@param row integer
---@param col integer
---@param input string
---@param opts farsight.csearch.CsearchOpts
local function csearch_rev(count, win, buf, row, col, input, opts)
    local byteidx = fn.byteidx
    local foldclosed = fn.foldclosed
    local nvim_buf_get_lines = api.nvim_buf_get_lines

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

            -- LOW: Wasteful if starcharpart ~= input, as the loop grabs this again
            local prev_line = nvim_buf_get_lines(buf, prev_row - 1, prev_row, false)[1]
            local charlen = fn.strcharlen(prev_line) ---@type integer
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

    if #pos == 2 then
        if t_cmd == 1 then
            pos = handle_t_cmd_rev(buf, pos)
        end

        do_cjump(win, buf, pos, opts)
    end
end

---@param opts farsight.csearch.CsearchOpts
local function resolve_csearch_opts(opts, cur_buf)
    vim.validate("opts", opts, "table")
    local ut = require("farsight.util")

    opts.actions = opts.actions or {}
    vim.validate("opts.actions", opts.actions, "table")
    for k, v in pairs(opts.actions) do
        vim.validate("k", k, "string")
        vim.validate("v", v, "callable")
    end

    -- TODO: Maybe document that there's no g:var for this.
    opts.forward = opts.forward or 1
    vim.validate("opts.forward", opts.forward, function()
        return opts.forward == 0 or opts.forward == 1
    end, "opts.forward must be 0 or 1")

    opts.show_hl = ut._use_gb_if_nil(opts.show_hl, "farsight_csearch_use_hl", cur_buf)
    opts.show_hl = ut._resolve_bool_opt(opts.show_hl, true)
    vim.validate("opts.hl", opts.show_hl, "boolean")

    -- TODO: Maybe document that there's no g:var for this.
    opts.t_cmd = opts.t_cmd or 0
    vim.validate("opts.t_cmd", opts.t_cmd, function()
        return opts.t_cmd == 0 or opts.t_cmd == 1
    end, "opts.t_cmd must be 0 or 1")

    -- TODO: Document that, for ;/, the cpo option should be used
    opts.t_cmd_skip = ut._use_gb_if_nil(opts.t_cmd_skip, "farsight_csearch_t_cmd_skip_ft", cur_buf)
    opts.t_cmd_skip = ut._resolve_bool_opt(opts.t_cmd_skip, false)
    vim.validate("opts.t_cmd_skip", opts.t_cmd_skip, "boolean")

    opts.hl_tokens = ut._use_gb_if_nil(opts.hl_tokens, "farsight_csearch_hl_tokens", cur_buf)
    opts.hl_tokens = opts.hl_tokens or TOKENS
    ut._validate_list(opts.hl_tokens, { item_type = "string" })
    require("farsight.util")._list_dedup(opts.hl_tokens)
    ut._validate_list(opts.hl_tokens, { min_len = 2 })

    local gb_max_hl_steps = "farsight_csearch_max_hl_steps"
    opts.max_hl_steps = ut._use_gb_if_nil(opts.max_hl_steps, gb_max_hl_steps, cur_buf)
    opts.max_hl_steps = opts.max_hl_steps or DEFAULT_MAX_HL_STEPS
    ut._validate_uint(opts.max_hl_steps)
    opts.max_hl_steps = math.min(opts.max_hl_steps, MAX_MAX_HL_STEPS)
end

---@class farsight.Csearch
local Csearch = {}

-- TODO: Document these
-- TODO: For actions, document that all inputs are simplified, even if manually unsimplified

---@class farsight.csearch.BaseOpts
---@field forward? integer
---@field on_cjump? fun(win: integer, buf: integer, pos: { [1]: integer, [2]: integer })
---@field t_cmd_skip? boolean

---@class farsight.csearch.CsearchOpts : farsight.csearch.BaseOpts
---@field actions? table<string, fun()>
---@field hl_tokens? string[]
---@field max_hl_steps? integer
---@field show_hl? boolean
---@field t_cmd? integer

---@param opts? farsight.csearch.CsearchOpts
function Csearch.csearch(opts)
    opts = opts and vim.deepcopy(opts, true) or {}
    local cur_win = api.nvim_get_current_win()
    local cur_buf = api.nvim_win_get_buf(cur_win)
    resolve_csearch_opts(opts, cur_buf)

    local cur_pos = api.nvim_win_get_cursor(cur_win)
    local row = cur_pos[1]
    local col = cur_pos[2]

    local forward = opts.forward ---@type integer
    if opts.show_hl then
        api.nvim__ns_set(HL_NS, { wins = { cur_win } })
        if forward == 1 then
            hl_fwd(cur_buf, row, col, opts.hl_tokens, opts.max_hl_steps)
        else
            hl_rev(cur_buf, row, col, opts.hl_tokens, opts.max_hl_steps)
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
        csearch_fwd(vim.v.count1, cur_win, cur_buf, row, col, input, opts)
    else
        csearch_rev(vim.v.count1, cur_win, cur_buf, row, col, input, opts)
    end
end

---@param opts? farsight.csearch.BaseOpts
function Csearch.rep(opts)
    opts = opts or {} --[[ @as farsight.csearch.CsearchOpts ]]
    opts.forward = opts.forward or 1
    vim.validate("opts.forward", opts.forward, function()
        return opts.forward == 0 or opts.forward == 1
    end, "opts.forward must be 0 or 1")

    vim.validate("opts.on_cjump", opts.on_cjump, "callable", true)
    vim.validate("opts.t_cmd_skip", opts.t_cmd_skip, "boolean", true)

    ---@type { char: string, forward: integer, until: integer }
    local charsearch = fn.getcharsearch()
    local char = charsearch.char
    if char == "" then
        return
    end

    local cur_win = api.nvim_get_current_win()
    local cur_pos = api.nvim_win_get_cursor(cur_win)
    local row = cur_pos[1]
    local col = cur_pos[2]
    local cur_buf = api.nvim_win_get_buf(cur_win)

    opts.t_cmd = charsearch["until"]
    opts.t_cmd_skip = (function()
        if type(opts.t_cmd_skip) ~= "nil" then
            return opts.t_cmd_skip
        end

        local cpo = api.nvim_get_option_value("cpo", {})
        local cpo_noskip = string.find(cpo, ";", 1, true)
        return cpo_noskip == nil
    end)()

    local count1 = vim.v.count1
    -- Bitshifts are LuaJIT only
    local forward = (opts.forward == 1) and charsearch.forward or (1 - charsearch.forward)
    if forward == 1 then
        csearch_fwd(count1, cur_win, cur_buf, row, col, char, opts)
    else
        csearch_rev(count1, cur_win, cur_buf, row, col, char, opts)
    end
end

return Csearch

-- Profiling code:
-- local start_time = vim.uv.hrtime()
-- local end_time = vim.uv.hrtime()
-- local duration_ms = (end_time - start_time) / 1e6
-- print(string.format("hl_forward took %.2f ms", duration_ms))

-- TODO: If count > 1, the first highlight for any particular letter needs to reflect where it
-- will actually go. The rest should be based on count1
-- TODO: The module contains a lot of functions that are only barely different. Now that the code
-- is actually written, can factor more aggressively
-- TODO: Try to refactor more aggressively. Still many similar functions
-- TODO: A lot of this can probably be made to be common with jump
-- TODO: Use the gb:var construct for the various opts
-- TODO: Go through the extmark opts doc to see what works here
-- TODO: Document that rep() checks cpo for default t skip behavior
-- TODO: Test/document dot repeat behavior for operators. Should at least match what default f/t
-- does
-- - When I dot repeat d<cr> is prompts me for the jump token. I think for that function that's
-- desirable behavior. For this, I think, using f/t should prompt for input, and dot repeat should
-- use saved values. But I'm not sure we can distinguish how we're entering omode, or if there's
-- a var we can leave behind. Could also add a key listener. Acceptable fallback is to always
-- prompt. Can also see what other plugins do
-- TODO: I'm still not completely satisfied with the backup <cr> map, because it still makes
-- you enter three more keypresses to get somewhere. EasyMotion style f/t makes more sense, but
-- that feels like something that should be more immediately available.
-- TODO: What do we do about wrapped lines that run off the edge of the screen? The highlights
-- aren't necessarily a huge deal, but what about the actual token finding?

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
-- MID: Multiple cases where we need to re-pull lines for corrections. Check if adding the line to
-- pos causes slowdown
-- MID: The highlighting capability can be extended so that max_hl can go above three. Two
-- possibilities:
-- - Accept a table so the highlight groups can be cycled like a rainbow
-- - Simply highlight anything after three with the last color
-- The former fits with the more general types of aesthetics users tend to look for, but also not
-- helpful since it's more keystrokes than just jumping. Whereas the latter is useful for getting
-- a general idea of where the chars are. A Blocker here is, I'm not sure what other types of
-- jump functionality I'm building out, that might better address other cases that extended
-- highlighting could here
-- MID: Like jump, accept an opt for wins. Default should still just be one win though

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
-- PR: Is the return type of getcharsearch correct?
-- PR: It would be cool if Neovim provided some kind of clear_plugin_highlights function that
-- plugins could register with. That way, users couldn't have to create bespoke highlight clearing
-- for every plugin (that said, how does Flash do it?)
