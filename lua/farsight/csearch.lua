-- TODO: A lot of this can probably be made to be common with jump

local api = vim.api
local fn = vim.fn

local TOKENS = vim.split("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ", "")

local HL_1ST_STR = "FarsightCsearch1st"
local HL_2ND_STR = "FarsightCsearch2nd"
local HL_3RD_STR = "FarsightCsearch3rd"

api.nvim_set_hl(0, HL_1ST_STR, { default = true, reverse = true })
api.nvim_set_hl(0, HL_2ND_STR, { default = true, undercurl = true })
api.nvim_set_hl(0, HL_3RD_STR, { default = true, underdouble = true })

-- TODO: Use this pattern in jump as well
local hl_1st = api.nvim_get_hl_id_by_name(HL_1ST_STR)
local hl_2nd = api.nvim_get_hl_id_by_name(HL_2ND_STR)
local hl_3rd = api.nvim_get_hl_id_by_name(HL_3RD_STR)

local CSEARCH_HL_NS = api.nvim_create_namespace("FarsightCsearch")

local last_dir = nil
local last_t = nil
local last_char = nil

---@class farsight.Csearch
local Csearch = {}

-- TOOD: The actual jump should use a sub-function, rather than making ;/, run through here

-- TODO: There should be transition keys you can use. You should be able to hit some key  in order
-- to center the cursor on the line, or be able to press enter in the function in order to call
-- a jump. It probably makes sense as an option to be able to map callbacks to exits. So like
-- esc, <C-c>, and <C-]> would be nil, but then you would map <cr> to a function that calls
-- jump
-- TODO: Remember that t motions need to be by charidx not just a byte shift
-- - A t motion to the very next char simply doesn't move
-- - Notable though that, for ;/, this does not get stuck
-- - For multiline, has to be able to handle beginning of line/end of line

-- TODO: This needs to be at least somewhat refined and optimized before the backward version
-- is made, since it's fairly complex.
-- TODO: Is there a way to get around the nested if logic here? Hurts caching I would
-- presume.

-- TODO: This should be customizable
local cword_regex = vim.regex("\\k\\+")
local priority_map = { hl_3rd, hl_2nd, hl_1st } ---@type integer[]

local function has_keys(t)
    for _, _ in pairs(t) do
        return true
    end

    return false
end

---@class farsight.csearch.TokenLabel
---@field [1] integer row
---@field [2] integer col
---@field [3] integer hl byte length
---@field [4] integer hl_group id

---Edits token_counts and labels in place
---@param line string
---@param row_0 integer
---@param token_counts table<string, integer>
---@param labels farsight.csearch.TokenLabel[]
local function iter_tokens_forward(line, row_0, token_counts, labels)
    local start = 1
    local len_ = (line:len() + 1)

    for _ = 1, len_ do
        local from, to = cword_regex:match_str(line)
        if from == nil or to == nil then
            break
        end

        local cword = line:sub(from + 1, to + 1) ---@type string
        local strcharlen = fn.strcharlen(cword) ---@type integer
        local priority = 0
        local idx ---@type integer?
        local len ---@type integer?
        local hl_id ---@type integer?
        for i = 0, strcharlen - 1 do
            local strcharpart = fn.strcharpart(cword, i, 1, true) ---@type string
            local remaining = token_counts[strcharpart] ---@type integer?
            if remaining then
                if remaining > priority then
                    priority = remaining
                    idx = i
                    len = #strcharpart
                    hl_id = priority_map[priority]
                end

                token_counts[strcharpart] = remaining - 1
                if token_counts[strcharpart] < 1 then
                    token_counts[strcharpart] = nil
                end
            end
        end

        if priority > 0 then
            labels[#labels + 1] = { row_0, from + start - 1 + idx, len, hl_id }
        end

        -- This function should never be called if token_counts has no keys, so wait to run
        -- this check until the counts of been modified to avoid a double check on every line.
        -- The exterior check is necessary because we don't want to iterate over every line to
        -- say "nothing to do here"
        if not has_keys(token_counts) then
            return
        end

        line = line:sub(to + 1)
        start = start + to
    end
end

---@param tokens string[]
local function hl_forward(tokens)
    local token_counts = {} ---@type table<string, integer>
    for _, token in ipairs(tokens) do
        token_counts[token] = 3
    end

    if not has_keys(token_counts) then
        return
    end

    local labels = {} ---@type farsight.csearch.TokenLabel[]

    local cur_win = api.nvim_get_current_win()
    local cur_pos = api.nvim_win_get_cursor(cur_win)
    local win_buf = api.nvim_win_get_buf(cur_win)
    if fn.foldclosed(cur_pos[1]) == -1 then
        local cur_line = api.nvim_buf_get_lines(win_buf, cur_pos[1] - 1, cur_pos[1], false)[1]
        local after_start_1 = cur_pos[2] + 2
        -- TODO: Will this cause a bad slice to be pulled?
        after_start_1 = math.min(after_start_1, #cur_line)
        local line_after = string.sub(cur_line, after_start_1, #cur_line)
        iter_tokens_forward(line_after, cur_pos[1] - 1, token_counts, labels)
        local cut_line_len = #cur_line - #line_after
        for _, label in ipairs(labels) do
            label[2] = label[2] + cut_line_len
        end
        -- print(vim.inspect(token_counts))
    end

    local bot = fn.line("w$")
    for i = cur_pos[1] + 1, bot do
        if not has_keys(token_counts) then
            return
        end

        if fn.foldclosed(i) == -1 then
            local this_line = api.nvim_buf_get_lines(win_buf, i - 1, i, false)[1]
            iter_tokens_forward(this_line, i - 1, token_counts, labels)
        end
    end

    ---@type vim.api.keyset.set_extmark
    local extmark_opts = { priority = 1000, strict = false }
    -- print(vim.inspect(labels))
    for _, label in ipairs(labels) do
        extmark_opts.hl_group = label[4]
        -- TODO: Need to be calculated basd on char idx info
        extmark_opts.end_row = label[1]
        extmark_opts.end_col = label[2] + label[3]
        pcall(api.nvim_buf_set_extmark, win_buf, CSEARCH_HL_NS, label[1], label[2], extmark_opts)
    end
end

function Csearch.csearch(opts)
    opts = opts and vim.deepcopy(opts, true) or {}
    -- TODO: Use the resolve boolean opt function from rancher
    opts.forward = (function()
        if opts.forward == nil then
            return true
        else
            return opts.forward
        end
    end)()

    -- TODO: Use the resolve boolean opt function from rancher
    -- TODO: Better var naming?
    opts.is_t = (function()
        if opts.is_t == nil then
            return true
        else
            return opts.is_t
        end
    end)()

    vim.validate("opts.is_t", opts.is_t, "boolean")
    opts.tokens = opts.tokens or TOKENS
    -- TODO: This should validate the list type and length as well
    vim.validate("opts.tokens", opts.tokens, vim.islist)

    if opts.forward then
        hl_forward(opts.tokens)
    end

    api.nvim__redraw({ valid = true })
    local _, input = pcall(fn.getcharstr)
    local exits = { "<C-c>, <esc>, <C-]>" }
    local cur_win = api.nvim_get_current_win()
    local win_buf = api.nvim_win_get_buf(cur_win)
    pcall(api.nvim_buf_clear_namespace, win_buf, CSEARCH_HL_NS, 0, -1)
    if vim.list_contains(exits, input) then
        return
    end

    local cur_pos = api.nvim_win_get_cursor(cur_win)
    -- TODO: Does not work with [] chars
    local regex = vim.regex(input)
    local cursor_line = api.nvim_buf_get_lines(win_buf, cur_pos[1] - 1, cur_pos[1], false)[1]
    if opts.forward then
        if fn.foldclosed(cur_pos[1]) == -1 then
            local after_start_1 = cur_pos[2] + 2
            after_start_1 = math.min(after_start_1, #cursor_line)
            local line_after = string.sub(cursor_line, after_start_1, #cursor_line)
            local from, _ = regex:match_str(line_after)
            if from then
                local cut_line = #cursor_line - #line_after
                local col_0 = from + cut_line
                -- print(line_after, #cursor_line .. ", " .. #line_after, ", " .. from .. ", " .. col_0)
                api.nvim_win_set_cursor(cur_win, { cur_pos[1], col_0 })
                api.nvim_cmd({ cmd = "norm", args = { "zv" }, bang = true }, {})
                return
            end
        end

        local bot = fn.line("w$")
        for i = cur_pos[1] + 1, bot do
            if fn.foldclosed(i) == -1 then
                local this_line = api.nvim_buf_get_lines(win_buf, i - 1, i, false)[1]
                local from, _ = regex:match_str(this_line)
                if from then
                    -- print(i .. ", " .. this_line .. ", " .. #this_line .. ", " .. from)
                    api.nvim_win_set_cursor(cur_win, { i, from })
                    api.nvim_cmd({ cmd = "norm", args = { "zv" }, bang = true }, {})
                    return
                end
            end
        end
    else
        local last_from
        local offset = 0
        local before_end = cur_pos[2]
        local line_before = string.sub(cursor_line, 1, before_end)
        local search_str = line_before
        if fn.foldclosed(cur_pos[1]) == -1 then
            while true do
                local from, to = regex:match_str(search_str)
                if not from then
                    break
                end
                last_from = offset + from
                offset = offset + to + 1
                search_str = string.sub(line_before, offset + 1)
            end

            if last_from then
                api.nvim_win_set_cursor(cur_win, { cur_pos[1], last_from })
                api.nvim_cmd({ cmd = "norm", args = { "zv" }, bang = true }, {})
                return
            end
        end

        local top = fn.line("w0")
        for i = cur_pos[1] - 1, top, -1 do
            if fn.foldclosed(i) == -1 then
                local this_line = api.nvim_buf_get_lines(win_buf, i - 1, i, false)[1]
                last_from = nil
                offset = 0
                search_str = this_line
                while true do
                    local from, to = regex:match_str(search_str)
                    if not from then
                        break
                    end
                    last_from = offset + from
                    offset = offset + to + 1
                    search_str = string.sub(this_line, offset + 1)
                end
                if last_from then
                    api.nvim_win_set_cursor(cur_win, { i, last_from })
                    api.nvim_cmd({ cmd = "norm", args = { "zv" }, bang = true }, {})
                    return
                end
            end
        end
    end
end

return Csearch

-- TODO: Personal thing, and also gets at the justification for having customizable defaults:
-- Since we are going multiline, would like to have more characters like underscores in the
-- tokens
-- TODO: Rough opinion, and this applies to the jump module too - The default mappings should be
-- what make sense. The Plug maps should be the default settings. And then customization should be
-- done through the APIs.
-- An alternative way to conceptualize this though - A particular mapping has some set of
-- default behavior. In this case, highlights should work in normal mode and give you two
-- follow-up chars of info. If you update the g:var, that's what the opt will do if a nil opt
-- is provided.
-- Problem - g:vars lack some degree of Lua default behaviors.
-- Still - IMO this solves the complexity issue because we are sectioning the g:vars to
-- default behavior only, rather than allowing them to be used for complex customization, which
-- still needs to be the domain of individual mappings. So like, in Lampshade, I might use a g:var
-- to, by default, show the bulb for disabled actions. But I would not use g:vars for per ft
-- customization. That gets back to making your own autocmds.
-- One problem though is handling stuff that overlaps. Let's say I make a g:var for the regex
-- word string, and then an opt for the labeller function. Or maybe overlaps isn't the best way of
-- putting it, but it can then get unclear which g:vars are nullified by which opts

-- MID: In the token iteration, we check if remaining > priority, only updating the char to
-- highlight if it will get us there quicker. Alternatively, you could use >=, which would prefer
-- sending the user to the end of the word. It would be cool if it were possible to customize how
-- the token highlights were done with some kind of passable function arg. But I can't think of a
-- sufficiently valuable use case relative to the degree of difficulty. The pieces of the char
-- highlighting are so inter-dependent.

-- LOW: For the actual search and jump, since most jumps would only be a couple lines, you could
-- probably optimize the module to pull like the first ~4 lines as a group, then pull the rest or
-- iterate if needed.
-- LOW: Try the labels as a struct of arrays. I don't think there would be enough of them to
-- justify the additional allocations up front.
-- LOW: Default f/t do not work on fold lines, so having this module ignore them is acceptable
-- behavior. It would be cool if alternative fold handling were available, like being able to pull
-- from the visible fold text and expanding it. But, not using folds myself, I don't have an
-- intuition for what would be good/useful
