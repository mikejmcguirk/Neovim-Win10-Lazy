local api = vim.api
local fn = vim.fn

---@class farsight.jump.Target
---@field [1] integer Window ID
---@field [2] integer Buffer ID
---@field [3] integer Zero indexed row |api-indexing|
---@field [4] integer Zero index col, inclusive for extmarks |api-indexing|
---@field [5] string[] Label
---@field [6] integer extmark namespace
---@field [7] [string,string|integer][] Extmark virtual text

-- TODO: Call this max display tokens or something
local MAX_TOKENS = 2
local TOKENS = vim.split("abcdefghijklmnopqrstuvwxyz", "")

-- TODO: Document these HL groups
local HL_JUMP_STR = "FarsightJump"
local HL_JUMP_AHEAD_STR = "FarsightJumpAhead"
local HL_JUMP_TARGET_STR = "FarsightJumpTarget"

-- TODO: These are not great defaults. But some blockers to determining:
-- - What defaults would be patternful with the F/T motions?
-- - How should extmarks be config'd in general? Would need to look at the jump plugin and
-- - What looks good with vmode/omode running over the edge?
-- Flash. Ideally, the user could just provide a callback to setting extmarks. Like, they
-- would get the table of info the function generates, and you could do what you want with them
-- The biggest use case I'm not sure if that addresses is dimming. Would also need to make sure
-- the ns is passed out
-- TODO: For my purposes, it feels like the current character to type should always be obvious so
-- that it's identifiable, but then the next character should indicate if it's the conclusion or
-- a transition char
api.nvim_set_hl(0, HL_JUMP_STR, { default = true, reverse = true })
api.nvim_set_hl(0, HL_JUMP_AHEAD_STR, { default = true, underdouble = true })
api.nvim_set_hl(0, HL_JUMP_TARGET_STR, { default = true, reverse = true })

local hl_jump = api.nvim_get_hl_id_by_name(HL_JUMP_STR)
local hl_jump_ahead = api.nvim_get_hl_id_by_name(HL_JUMP_AHEAD_STR)
local hl_jump_target = api.nvim_get_hl_id_by_name(HL_JUMP_TARGET_STR)

local namespaces = { api.nvim_create_namespace("") } ---@type integer[]

-- MID: Profile this against regex:match_line()

local cword_regex = vim.regex("\\k\\+")

---@param line string
---@return boolean
local function is_blank(line)
    return string.find(line, "[^\\0-\\32\\127]") == nil
end

-- LOW: Using this function adds an extra if check for the output. Could mitigate by checking
-- a bool instead of truthiness. Could also re-inline, though that creates repetitious code

---@param row integer
---@param line string
---@return integer[]|nil
local function handle_non_rows(row, line)
    if is_blank(line) then
        return {}
    end

    local fold_row = fn.foldclosed(row)
    if fold_row ~= -1 then
        if fold_row == row then
            return { 0 }
        end

        return {}
    end

    return nil
end

-- Unlike for csearch, the string sub method works best here

---@diagnostic disable-next-line: duplicate-doc-param
---@param _ integer
---@param row integer
---@param line string
---@diagnostic disable-next-line: duplicate-doc-param
---@param _ integer
---@diagnostic disable-next-line: duplicate-doc-param
---@param _ { [1]: integer, [2]:integer }
---@return integer[]
local function locate_cwords(_, row, line, _, _)
    local non_row_cols = handle_non_rows(row, line)
    if non_row_cols then
        return non_row_cols
    end

    local cols = {} ---@type integer[]
    local start = 1

    while true do
        local from, to = cword_regex:match_str(line)
        if from == nil or to == nil then
            break
        end

        cols[#cols + 1] = from + start - 1
        line = line:sub(to + 1)
        start = start + to
    end

    return cols
end

---@diagnostic disable-next-line: duplicate-doc-param
---@param _ integer
---@param row integer
---@param line string
---@diagnostic disable-next-line: duplicate-doc-param
---@param _ integer
---@param cur_pos { [1]: integer, [2]:integer }
---@return integer[]
local function locate_cwords_with_cur_pos(_, row, line, _, cur_pos)
    local non_row_cols = handle_non_rows(row, line)
    if non_row_cols then
        return non_row_cols
    end

    local cols = {} ---@type integer[]
    local start = 1

    while true do
        local from, to = cword_regex:match_str(line)
        if from == nil or to == nil then
            break
        end

        if row > cur_pos[1] then
            cols[#cols + 1] = to + start - 2
        elseif row == cur_pos[1] then
            local to_fixed = to + start - 2
            if to_fixed > cur_pos[2] then
                cols[#cols + 1] = to + start - 2
            else
                cols[#cols + 1] = from + start - 1
            end
        else
            cols[#cols + 1] = from + start - 1
        end

        line = line:sub(to + 1)
        start = start + to
    end

    return cols
end

---@param row integer
---@param line string
---@param buf integer
---@param cur_pos { [1]: integer, [2]: integer }
---@param locator fun(win: integer, row: integer, line: string, buf: integer, cur_pos: { [1]: integer, [2]: integer }):integer[]
local function get_cols(win, row, line, buf, cur_pos, locator)
    local cols = locator(win, row, line, buf, cur_pos)
    require("farsight.util")._dedup_list(cols)
    table.sort(cols, function(a, b)
        return a < b
    end)

    return cols
end

---Edits targets in place
---@param win integer
---@param cur_pos { [1]: integer, [2]: integer }
---@param buf integer
---@param locator fun(win: integer, row: integer, line: string, buf: integer, cur_pos: { [1]: integer, [2]: integer }):integer[]
---@param ns integer
---@param targets farsight.jump.Target[]
local function add_targets_after(win, cur_pos, buf, locator, ns, targets)
    local line = fn.getline(cur_pos[1])
    local start_col_1 = (function()
        local ut = require("farsight.util")
        local cur_cword = ut._find_cword_at_col(line, cur_pos[2])
        if cur_cword then
            return cur_cword[3] + 1
        end

        local charidx = fn.charidx(line, cur_pos[2])
        local char = fn.strcharpart(line, charidx, 1, true) ---@type string
        return cur_pos[2] + #char + 1
    end)()

    local line_after = string.sub(line, start_col_1, #line)
    local cols = get_cols(win, cur_pos[1], line_after, buf, cur_pos, locator)

    local cut_len = #line - #line_after
    for i = 1, #cols do
        cols[i] = cols[i] + cut_len
    end

    local row_0 = cur_pos[1] - 1
    for _, col in ipairs(cols) do
        targets[#targets + 1] = { win, buf, row_0, col, {}, ns, {} }
    end
end

---Edits targets in place
---@param win integer
---@param cur_pos { [1]: integer, [2]: integer }
---@param buf integer
---@param locator fun(win: integer, row: integer, line: string, buf: integer, cur_pos: { [1]: integer, [2]: integer }):integer[]
---@param ns integer
---@param targets farsight.jump.Target[]
local function add_targets_before(win, cur_pos, buf, locator, ns, targets)
    local line = fn.getline(cur_pos[1])
    local ut = require("farsight.util")
    local cur_cword = ut._find_cword_at_col(line, cur_pos[2])
    local end_col_1 = cur_cword and cur_cword[2] or cur_pos[2]

    local line_before = string.sub(line, 1, end_col_1)
    local cols = get_cols(win, cur_pos[1], line_before, buf, cur_pos, locator)

    local row_0 = cur_pos[1] - 1
    for _, col in ipairs(cols) do
        targets[#targets + 1] = { win, buf, row_0, col, {}, ns, {} }
    end
end

---Edits targets in place
---@param win integer
---@param row integer
---@param buf integer
---@param cur_pos { [1]: integer, [2]: integer }
---@param locator fun(win: integer, row: integer, line: string, buf: integer, cur_pos: { [1]: integer, [2]: integer }):integer[]
---@param ns integer
---@param targets farsight.jump.Target[]
local function add_targets(win, row, buf, cur_pos, locator, ns, targets)
    local line = fn.getline(row)
    local cols = get_cols(win, row, line, buf, cur_pos, locator)

    local row_0 = row - 1
    for _, col in ipairs(cols) do
        targets[#targets + 1] = { win, buf, row_0, col, {}, ns, {} }
    end
end

---@param wins integer[]
---@param opts farsight.jump.JumpOpts
---@return farsight.jump.Target[], table<integer, integer>
local function get_targets(wins, opts)
    local targets = {} ---@type farsight.jump.Target[]
    local locator = opts.locator ---@type fun(row: integer, line: string, buf: integer, cur_pos: { [1]: integer, [2]: integer }):integer[]
    local dir = opts.dir ---@type integer
    local missing_ns = #wins - #namespaces
    for _ = 1, missing_ns do
        namespaces[#namespaces + 1] = api.nvim_create_namespace("")
    end

    local win_ns_map = {} ---@type table<integer, integer>
    local ns_buf_map = {} ---@type table<integer, integer>
    for i = 1, #wins do
        win_ns_map[wins[i]] = namespaces[i]
        api.nvim__ns_set(namespaces[i], { wins = { wins[i] } })
    end

    for _, win in ipairs(wins) do
        local cur_pos = api.nvim_win_get_cursor(win)
        local buf = api.nvim_win_get_buf(win)
        local ns = win_ns_map[win]
        ns_buf_map[ns] = buf

        api.nvim_win_call(win, function()
            local top ---@type integer
            local bot ---@type integer
            if dir <= 0 then
                top = fn.line("w0")
            end

            if dir >= 0 then
                bot = fn.line("w$")
            end

            if dir == -1 then
                bot = math.max(cur_pos[1] - 1, top)
            elseif dir == 1 then
                top = math.min(cur_pos[1] + 1, bot)
                add_targets_after(win, cur_pos, buf, locator, ns, targets)
            end

            for i = top, bot do
                add_targets(win, i, buf, cur_pos, locator, ns, targets)
            end

            if dir == -1 then
                add_targets_before(win, cur_pos, buf, locator, ns, targets)
            end
        end)
    end

    return targets, ns_buf_map
end

-- MID: The variable names in this function could be more clear
-- LOW: In theory, the best way to do this would be to figure out a way to pre-determine the length
-- of each label and allocate each only once as a string

---@param targets farsight.jump.Target[]
---@param opts farsight.jump.JumpOpts
---@return nil
local function populate_target_labels(targets, opts)
    if #targets <= 1 then
        return
    end

    -- TODO: Don't need the whole opt I don't think
    local tokens = opts.tokens ---@type string[]
    local queue = {} ---@type { [1]: integer, [2]:integer }[]
    queue[#queue + 1] = { 1, #targets }

    while #queue > 0 do
        local range = table.remove(queue, 1) ---@type { [1]: integer, [2]:integer }
        local len = range[2] - range[1] + 1

        local quotient = math.floor(len / #tokens)
        local remainder = len % #tokens
        local rem_tokens = quotient + (remainder >= 1 and 1 or 0)
        remainder = remainder > 0 and remainder - 1 or remainder

        local token_idx = 1
        local token_start = range[1]

        for i = range[1], range[2] do
            targets[i][5][#targets[i][5] + 1] = tokens[token_idx]
            rem_tokens = rem_tokens - 1
            if rem_tokens == 0 then
                rem_tokens = quotient + (remainder >= 1 and 1 or 0)
                remainder = remainder > 0 and remainder - 1 or remainder

                if i > token_start then
                    -- if i > token_start and #targets[i][5] < max_tokens then
                    queue[#queue + 1] = { token_start, i }
                end

                token_idx = token_idx + 1
                token_start = i + 1
            end
        end
    end
end

-- LOW: Profile this function to see if it could be optimized further

---@param targets farsight.jump.Target[]
---@param max_tokens integer
local function populate_target_virt_text(targets, max_tokens)
    ---@param target farsight.jump.Target
    ---@param max_display_tokens integer
    local function add_virt_text(target, max_display_tokens)
        -- TODO: Since the last untruncated token is always hl_jump_target, maybe arrive at that
        -- first then work backward?
        -- Do not waste an if check on less than one token in a hot loop, as that should never
        -- happen
        if #target[5] == 1 then
            target[7][1] = { target[5][1], hl_jump_target }
            return
        end

        target[7][1] = { target[5][1], hl_jump }
        if #target[5] > max_display_tokens then
            if max_display_tokens <= 1 then
                return
            end

            local remainder = table.concat(target[5], "", 2, max_display_tokens)
            target[7][2] = { remainder, hl_jump_ahead }
            return
        end

        if #target[5] > 2 then
            local before = table.concat(target[5], "", 2, #target[5] - 1)
            target[7][2] = { before, hl_jump_ahead }
        end

        target[7][#target[7] + 1] = { target[5][#target[5]], hl_jump_target }
    end

    ---@param target farsight.jump.Target
    ---@param next_target farsight.jump.Target
    local function get_max_display_tokens(target, next_target)
        if target[1] ~= next_target[1] then
            return max_tokens
        end

        if target[2] ~= next_target[2] then
            return max_tokens
        end

        if target[3] ~= next_target[3] then
            return max_tokens
        end

        return next_target[4] - target[4]
    end

    for i = 1, #targets - 1 do
        local max_display_tokens = get_max_display_tokens(targets[i], targets[i + 1])
        max_display_tokens = math.min(max_display_tokens, max_tokens)
        add_virt_text(targets[i], max_display_tokens)
    end

    add_virt_text(targets[#targets], max_tokens)
end

---Expects zero indexed row and col
---@param win integer
---@param buf integer
---@param row_0 integer
---@param col integer
---@param is_omode boolean
---@param opts farsight.jump.JumpOpts
---@return nil
local function do_jump(win, buf, row_0, col, is_omode, opts)
    -- Because jumplists are scoped per window, setting the pcmark in the window being left doesn't
    -- provide anything useful. By setting the pcmark in the window where the jump is performed,
    -- the user is provided the ability to undo the jump
    local cur_win = api.nvim_get_current_win()
    if cur_win ~= win then
        api.nvim_set_current_win(win)
    end

    if (not opts.keepjumps) and not is_omode then
        -- FUTURE: When the updated mark API is released, see if that can be used to set the
        -- pcmark correctly
        api.nvim_cmd({ cmd = "norm", args = { "m`" }, bang = true }, {})
    end

    local row = row_0 + 1
    -- Use visual mode so that all text within the selection is operated on, rather than the text
    -- between the start and end of the cursor movemet. In this case, staying in normal mode causes
    -- the actual character jumped to to be truncated
    if is_omode then
        api.nvim_cmd({ cmd = "norm", args = { "v" }, bang = true }, {})
        ---@type string
        local selection = api.nvim_get_option_value("selection", { scope = "global" })
        if selection == "exclusive" then
            local line = api.nvim_buf_get_lines(buf, row_0, row, false)[1]
            col = math.min(col + 1, math.max(#line - 1, 0))
        end
    end

    api.nvim_win_set_cursor(win, { row, col })
    api.nvim_cmd({ cmd = "norm", args = { "zv" }, bang = true }, {})
end

---Edits ns_buf_map and sights in place
---@param ns_buf_map table<integer, integer>
---@param sights farsight.jump.Target[]
---@param is_omode boolean
---@param opts farsight.jump.JumpOpts
---@return nil
local function advance_jump(ns_buf_map, sights, is_omode, opts)
    while true do
        local start_time = vim.uv.hrtime()
        populate_target_virt_text(sights, opts.max_tokens)
        local end_time = vim.uv.hrtime()
        local duration_ms = (end_time - start_time) / 1e6
        print(string.format("hl_forward took %.2f ms", duration_ms))

        ---@type vim.api.keyset.set_extmark
        local extmark_opts = { hl_mode = "combine", priority = 1000, virt_text_pos = "overlay" }
        for _, sight in ipairs(sights) do
            extmark_opts.virt_text = sight[7]
            pcall(api.nvim_buf_set_extmark, sight[2], sight[6], sight[3], sight[4], extmark_opts)
        end

        api.nvim__redraw({ valid = true })
        local _, input = pcall(fn.getcharstr)
        for ns, buf in pairs(ns_buf_map) do
            pcall(api.nvim_buf_clear_namespace, buf, ns, 0, -1)
        end

        local new_sights = {} ---@type farsight.jump.Target[]
        for _, sight in ipairs(sights) do
            if sight[5][1] == input then
                new_sights[#new_sights + 1] = sight
            end
        end

        sights = new_sights
        if #sights <= 1 then
            if #sights == 1 then
                do_jump(sights[1][1], sights[1][2], sights[1][3], sights[1][4], is_omode, opts)
            end

            return
        end

        local new_ns_buf_map = {} ---@type table<integer, integer>
        for _, sight in ipairs(sights) do
            new_ns_buf_map[sight[6]] = sight[2]
            table.remove(sight[5], 1)
            sight[7] = {}
        end

        ns_buf_map = new_ns_buf_map
    end
end

---@param opts farsight.jump.JumpOpts
local function resolve_jump_opts(opts, mode, is_omode)
    vim.validate("opts", opts, "table")
    local ut = require("farsight.util")

    opts.dir = opts.dir or 0
    vim.validate("opts.dir", opts.dir, function()
        if type(opts.dir) ~= "number" then
            return false
        end

        return -1 <= opts.dir and opts.dir <= 1
    end, "Dir must be -1, 0, or 1")

    opts.keepjumps = ut._resolve_bool_opt(opts.keepjumps, false)
    vim.validate("opts.keepjumps", opts.keepjumps, "boolean")

    opts.max_tokens = opts.max_tokens or MAX_TOKENS
    ut._validate_uint(opts.max_tokens)
    opts.max_tokens = math.max(opts.max_tokens, 1)

    opts.locator = (function()
        if opts.locator then
            return opts.locator
        end

        local short_mode = string.sub(mode, 1, 1)
        local is_visual = short_mode == "v" or short_mode == "V" or short_mode == "\22"
        if is_visual or is_omode then
            return locate_cwords_with_cur_pos
        else
            return locate_cwords
        end
    end)()

    vim.validate("opts.locator", opts.locator, "callable")

    opts.tokens = opts.tokens or TOKENS
    -- MID: Clumsy validation method
    ut._validate_list(opts.tokens, { item_type = "string" })
    require("farsight.util")._dedup_list(opts.tokens)
    ut._validate_list(opts.tokens, { min_len = 2 })

    opts.wins = opts.wins or { api.nvim_get_current_win() }
    ut._validate_list(opts.wins, { item_type = "number", min_len = 1 })
end

---@class farsight.StepJump
local Jump = {}

-- TODO: Flesh out this documentation

---@class farsight.jump.JumpOpts
---The input row argument is one indexed
---This function will be called in the window context being evaluated. This means, for example,
---that foldclosed() will return the proper result
---The returned columns must be zero indexed
---The returned array will be de-duplicated and sorted from least to greatest
---@field dir? integer
---@field keepjumps? boolean
---@field locator? fun(row: integer, line: string, buf: integer, cur_pos: { [1]: integer, [2]: integer }):integer[]
---@field max_tokens? integer
---@field tokens? string[]
---@field wins? integer[]

---@param opts farsight.jump.JumpOpts?
---@return nil
function Jump.jump(opts)
    opts = opts and vim.deepcopy(opts, true) or {}
    local mode = api.nvim_get_mode().mode
    local is_omode = string.sub(mode, 1, 2) == "no"
    resolve_jump_opts(opts, mode, is_omode)

    local ut = require("farsight.util")
    local focusable_wins = ut._order_focusable_wins(opts.wins)
    if #focusable_wins < 1 then
        api.nvim_echo({ { "No focusable wins provided" } }, false, {})
        return
    end

    local sights, ns_buf_map = get_targets(focusable_wins, opts)
    if #sights > 1 then
        populate_target_labels(sights, opts)
        advance_jump(ns_buf_map, sights, is_omode, opts)
    elseif #sights == 1 then
        do_jump(sights[1][1], sights[1][2], sights[1][3], sights[1][4], is_omode, opts)
    else
        api.nvim_echo({ { "No sights to jump to" } }, false, {})
    end
end

---@return integer[]
function Jump.get_hl_namespaces()
    return vim.deepcopy(namespaces, true)
end

return Jump

-- TODO: Document a couple locator examples, like CWORD
-- TODO: Document the locator behavior:
-- - It's win called to the current win
-- - cur_pos is passed by reference. Do not modify
-- As a general design philosophy and as a note, because the locator is run so many times, it
-- neds to be perf optimized, so even obvious boilerplate like checking folds is not done so that
-- nothing superfluous happens
-- TODO: Add doc examples for EasyMotion style f/t mapping
-- TODO: Show how to do two-character search like vim sneak/vim-seek
-- TODO: Plugins to research in more detail:
-- - EasyMotion (Historically important)
-- - Flash (and the listed related plugins)
-- - Hop
-- - Sneak
-- - https://github.com/neovim/neovim/discussions/36785
-- - https://antonk52.github.io/webdevandstuff/post/2025-11-30-diy-easymotion.html
-- - The text editor that Helix took its gw motion from
-- TODO: Verify farsight.nvim or nvim-farsight are available
-- TODO: Update the label gathering based on what we've learned doing csearch
-- TODO: Add jump2d to credits
-- TODO: Add quickscope to inspirations or something
-- TODO: Add alternative projects (many of them)
-- TODO: Go through the extmark opts doc to see what works here
-- TODO: Test/document dot repeat behavior
-- TODO: Create g:vars for the defaults
-- TODO: Create <Plug> maps
-- TODO: Document how the focusable wins filtering works
-- TODO: What is the default max tokens to show?
-- TODO: Should a highlight group be added to show truncated labels?
-- TODO: The above two questions get into the broader issue of - Do the current hl groups actually
-- clearly show what is going on?
-- TODO: Thinking about the defaults - I like the current <cr> jump because I can look at
-- somewhere I want to go and get their in three keystrokes. But the "I need to find something"
-- case is not addressed. A very basic obstacle is - I'm not sure where to map it. I also don't
-- want to graft is on top of search. You could maybe do something like map <C-n> to jump based on
-- search results, but that's a lot of steps. YOu could remove t motions, but they are useful for
-- operating up to but not including a paren, where mentally parsing out the individual
-- characters would be a pain. Ctrl_<cr> or Shift_<cr> are natural choices, but I'm not sure
-- all terminals/tmux send them reliably. Nvim does recoognize them though as distinct termcodes
-- TODO: Un-related to the more general find/sneak question - How do I want to handle searching
-- in general? Right now, if I have n/N, it automatically goes to the next search term. In
-- practice, this ends up being disorienting. And I think, given a broader re-think of search,
-- that we really need to look at what Flash does and be willing to graft on top of search
-- Upon further research, the most logical way to handle this is to tie displaying jump tokens to
-- hlsearch being on. But I don't know a way to track the var's status that isn't contrived. The
-- way flash does it with / and ?, IMO, is a bit much, and relies on a lot of hacks. For my own
-- purposes, and maybe as doc examples, you can do something where like n/N trigger labels, and
-- you omit n/N from the possibilities. You could also have something on like <C-n> that sets
-- hlsearch and displays labels, with n/N omitted. But this all feels very contrived. Maybe
-- you could do it where you use <C-n> to enter a "Token searching state" and a non-token exits.
-- But then what feedback do you get if there are no valid tokens on the page? I guess it just
-- quits?
-- TODO: WHen doing default mappings, can the unique flag be used rather than maparg to check if
-- it's already been mapped?

-- EasyMotion notes:
-- - EasyMotion replaces a lot of things, like w and f/t
-- - Provides a version of search where after entering the term, labels are then shown on the
-- search results
-- Flash notes:
-- - The enhanced search is neat, but my experience with it was that it was a bit much, and the
-- code within uses a lot of hacks to keep Nvim's state correct. Unsure of value relative to
-- effort

-- MID: Wins should be able to accept a list or a custom callback to get the wins

-- LOW: Would be interesting to test storing the labels as a struct of arrays

-- DOCUMENT: A couple example spotter functions
