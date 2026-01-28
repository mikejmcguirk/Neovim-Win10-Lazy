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

local MAX_TOKENS = 2
local TOKENS = vim.split("abcdefghijklmnopqrstuvwxyz", "")

-- TODO: Document these HL groups
local HL_JUMP_STR = "FarsightJump"
local HL_JUMP_AHEAD_STR = "FarsightJumpAhead"
local HL_JUMP_TARGET_STR = "FarsightJumpTarget"

-- FARSIGHT: These are not great defaults. But some blockers to determining:
-- - What defaults would be patternful with the F/T motions?
-- - How should extmarks be config'd in general? Would need to look at the jump plugin and
-- Flash. Ideally, the user could just provide a callback to setting extmarks. Like, they
-- would get the table of info the function generates, and you could do what you want with them
-- The biggest use case I'm not sure if that addresses is dimming. Would also need to make sure
-- the ns is passed out
api.nvim_set_hl(0, HL_JUMP_STR, { default = true, reverse = true })
api.nvim_set_hl(0, HL_JUMP_AHEAD_STR, { default = true, reverse = true })
api.nvim_set_hl(0, HL_JUMP_TARGET_STR, { default = true, reverse = true })

local hl_jump = api.nvim_get_hl_id_by_name(HL_JUMP_STR)
local hl_jump_ahead = api.nvim_get_hl_id_by_name(HL_JUMP_AHEAD_STR)
local hl_jump_target = api.nvim_get_hl_id_by_name(HL_JUMP_TARGET_STR)

local namespaces = { api.nvim_create_namespace("") } ---@type integer[]

-- MID: Profile this against regex:match_line()

local cword_regex = vim.regex("\\k\\+")

-- Unlike for csearch, the string sub method works best here

---@param row integer
---@param line string
---@param _ integer
---@return integer[]
local function target_cwords(row, line, _, _)
    -- TODO: for folded lines, put a label at the beginning that can zv it open
    if fn.prevnonblank(row) ~= row or fn.foldclosed(row) ~= -1 then
        return {}
    end

    local cols = {} ---@type integer[]
    local start = 1
    local len_ = (line:len() + 1)

    for _ = 1, len_ do
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

-- TODO: Vague function name
-- TODO: Issue with this function: The jump labels run off the edge of the word. Especially
-- punshing for me because it makes the reverse highlighting a mess. But if you use under
-- highlighting to identify jumps, still creates disorienting visuals where the under decorations
-- run past the word.
-- The most visually pleasing solution would be to restrict the labels to within the word. But
-- this creates a disconnect where now the labels to not match exactly to where the jump point is,
-- creating a new type of confusion.
-- I just don't think shifting the labels off from the cols they identify can be correct. I think
-- the better path forward is to consider this as a factor when creating the defaults, and
-- something to keep in mind for my own config as well.

---@param row integer
---@param line string
---@param _ integer
---@param cur_pos { [1]: integer, [2]:integer }
---@return integer[]
local function target_cwords_cur_pos(row, line, _, cur_pos)
    -- TODO: for folded lines, put a label at the beginning that can zv it open
    if fn.prevnonblank(row) ~= row or fn.foldclosed(row) ~= -1 then
        return {}
    end

    local cols = {} ---@type integer[]
    local start = 1
    local len_ = (line:len() + 1)

    -- TODO: YOu could just do while true here and remove the len_ allocation. Though it is a
    -- useful guard. And might save a regex call
    for _ = 1, len_ do
        local from, to = cword_regex:match_str(line)
        if from == nil or to == nil then
            break
        end

        -- TODO: handle same row, col after
        local after_row = row > cur_pos[1]
        if after_row then
            cols[#cols + 1] = to + start - 2
        else
            cols[#cols + 1] = from + start - 1
        end

        -- if after_row then
        --     print(
        --         tostring(from + start - 1)
        --             .. ", "
        --             .. tostring(to + start - 1)
        --             .. ", "
        --             .. tostring(cols[#cols])
        --     )
        -- end

        line = line:sub(to + 1)
        start = start + to
    end

    return cols
end

---@param row integer
---@param line string
---@param buf integer
---@param cur_pos { [1]: integer, [2]: integer }
---@param locator fun(row: integer, line: string, buf: integer, cur_pos: { [1]: integer, [2]: integer }):integer[]
local function get_cols(row, line, buf, cur_pos, locator)
    local cols = locator(row, line, buf, cur_pos)
    -- TODO: I think this is a version 12 function
    vim.list.unique(cols)
    table.sort(cols, function(a, b)
        return a < b
    end)

    return cols
end

---Edits targets in place
---@param win integer
---@param cur_pos { [1]: integer, [2]: integer }
---@param buf integer
---@param locator fun(row: integer, line: string, buf: integer, cur_pos: { [1]: integer, [2]: integer }):integer[]
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
    local cols = get_cols(cur_pos[1], line_after, buf, cur_pos, locator)

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
---@param locator fun(row: integer, line: string, buf: integer, cur_pos: { [1]: integer, [2]: integer }):integer[]
---@param ns integer
---@param targets farsight.jump.Target[]
local function add_targets_before(win, cur_pos, buf, locator, ns, targets)
    local line = fn.getline(cur_pos[1])
    local ut = require("farsight.util")
    local cur_cword = ut._find_cword_at_col(line, cur_pos[2])
    local end_col_1 = cur_cword and cur_cword[2] or cur_pos[2]

    local line_before = string.sub(line, 1, end_col_1)
    local cols = get_cols(cur_pos[1], line_before, buf, cur_pos, locator)

    local row_0 = cur_pos[1] - 1
    for _, col in ipairs(cols) do
        targets[#targets + 1] = { win, buf, row_0, col, {}, ns, {} }
    end
end

---@param win integer
---@param row integer
---@param buf integer
---@param cur_pos { [1]: integer, [2]: integer }
---@param locator fun(row: integer, line: string, buf: integer, cur_pos: { [1]: integer, [2]: integer }):integer[]
---@param ns integer
---@param targets farsight.jump.Target[]
local function add_targets(win, row, buf, cur_pos, locator, ns, targets)
    local line = fn.getline(row)
    local cols = get_cols(row, line, buf, cur_pos, locator)

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

    local tokens = opts.tokens ---@type string[]
    local max_tokens = opts.max_tokens
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

                if i > token_start and #targets[i][5] < max_tokens then
                    queue[#queue + 1] = { token_start, i }
                end

                token_idx = token_idx + 1
                token_start = i + 1
            end
        end
    end
end

-- LOW: It might be faster to build first_counts when populating the labels. Not sure how to do
-- it though without essentially writing duplicate code for the queue iteration. One for the first
-- token to add quotient to first counts, then another that doesn't touch first_counts. Don't
-- want to be if checking on subsequent iterations
-- LOW: Profile this function to see if it could be optimized further

---@param targets farsight.jump.Target[]
local function populate_target_virt_text(targets, tokens)
    local first_counts = {} ---@type table<string, integer>
    for _, token in ipairs(tokens) do
        first_counts[token] = 0
    end

    for _, target in ipairs(targets) do
        first_counts[target[5][1]] = first_counts[target[5][1]] + 1
    end

    ---@param target farsight.jump.Target
    ---@param max_display_tokens integer
    local function add_virt_text(target, max_display_tokens)
        local only_token = first_counts[target[5][1]] == 1
        local first_hl_group = only_token and hl_jump_target or hl_jump
        target[7][1] = { target[5][1], first_hl_group }

        local total_tokens = math.min(#target[5], max_display_tokens)
        if 2 <= total_tokens then
            local tokens_ahead = table.concat(target[5], "", 2, total_tokens)
            target[7][2] = { tokens_ahead, hl_jump_ahead }
        end
    end

    local function get_max_display_tokens(target, next_target)
        if target[1] ~= next_target[1] then
            return math.huge
        end

        if target[2] ~= next_target[2] then
            return math.huge
        end

        if target[3] ~= next_target[3] then
            return math.huge
        end

        return next_target[4] - target[4]
    end

    for i = 1, #targets - 1 do
        local max_display_tokens = get_max_display_tokens(targets[i], targets[i + 1])
        add_virt_text(targets[i], max_display_tokens)
    end

    add_virt_text(targets[#targets], math.huge)
end

--- Row and col are cursor indexed
---@param win integer
---@param row integer
---@param col integer
---@param opts farsight.jump.JumpOpts
---@return nil
local function do_jump(win, row, col, opts)
    local cur_win = api.nvim_get_current_win()
    if cur_win ~= win then
        api.nvim_set_current_win(win)
    end

    if not opts.keepjumps then
        -- TODO: Does this have to be disabled in omode?
        api.nvim_cmd({ cmd = "norm", args = { "m`" }, bang = true }, {})
    end

    api.nvim_win_set_cursor(win, { row, col })
    api.nvim_cmd({ cmd = "norm", args = { "zv" }, bang = true }, {})
end

---Edits ns_buf_map and sights in place
---@param ns_buf_map table<integer, integer>
---@param sights farsight.jump.Target[]
---@param opts farsight.jump.JumpOpts
---@return nil
local function advance_jump(ns_buf_map, sights, opts)
    while true do
        populate_target_labels(sights, opts)
        populate_target_virt_text(sights, opts.tokens)

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
                do_jump(sights[1][1], sights[1][3] + 1, sights[1][4], opts)
            end

            return
        end

        local new_ns_buf_map = {} ---@type table<integer, integer>
        for _, sight in ipairs(sights) do
            new_ns_buf_map[sight[6]] = sight[2]
            sight[5] = {}
            sight[7] = {}
        end

        ns_buf_map = new_ns_buf_map
    end
end

---@param opts farsight.jump.JumpOpts
local function resolve_jump_opts(opts)
    vim.validate("opts", opts, "table")
    local ut = require("farsight.util")

    opts.all_wins = ut._resolve_bool_opt(opts.all_wins, true)
    vim.validate("opts.all_wins", opts.all_wins, "boolean")

    -- TODO: Should be restricted to -1, 0, or 1
    opts.dir = opts.dir or 0
    vim.validate("opts.dir", opts.dir, "number")

    opts.keepjumps = ut._resolve_bool_opt(opts.keepjumps, false)
    vim.validate("opts.keepjumps", opts.keepjumps, "boolean")

    opts.max_tokens = opts.max_tokens or MAX_TOKENS
    ut._validate_uint(opts.max_tokens)
    opts.max_tokens = math.max(opts.max_tokens, 1)

    local short_mode = string.sub(api.nvim_get_mode().mode, 1, 1)
    opts.locator = (function()
        if opts.locator then
            return opts.locator
        end

        -- TODO: Check omode as well
        local is_visual = short_mode == "v" or short_mode == "V" or short_mode == "\22"
        if is_visual then
            return target_cwords_cur_pos
        else
            return target_cwords
        end
    end)()

    vim.validate("opts.locator", opts.locator, "callable")

    opts.tokens = opts.tokens or TOKENS
    -- MID: Clumsy validation method
    ut._validate_list(opts.tokens, { item_type = "string" })
    vim.list.unique(opts.tokens)
    ut._validate_list(opts.tokens, { min_len = 2 })
end

---@class farsight.StepJump
local Jump = {}

-- TODO: Flesh out this documentation

---@class farsight.jump.JumpOpts
---@field all_wins? boolean Place jump labels in all wins?
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

-- FARSIGHT: Add back in the ability to do before or after cursor only. You can use this
-- function to create an EasyMotion style F/T map. You can create your own wrapper to enter
-- F/T and get the character, then pass that arg into a sight_in function which is passed into
-- here in order to get the relevant locations. Would be cool example in documentation
-- NOGO: Add in opts to control how folds or blanks are handled. These are concerns within
-- the handling of the individual line and should be scoped there

---@param opts farsight.jump.JumpOpts?
---@return nil
function Jump.jump(opts)
    opts = opts and vim.deepcopy(opts, true) or {}
    resolve_jump_opts(opts)

    local ut = require("farsight.util")
    local wins = opts.all_wins and ut._get_focusable_wins_ordered(0)
        or { api.nvim_get_current_win() }

    -- TODO: The naming is somewhat confusing. For internal purposes, a sight makes sense as an
    -- encoding of the buf, row, col, and label. But how clear is this to the user? This is
    -- confused by the get_cols opt. Maybe just call that get_sights or sight_filter?
    local sights, ns_buf_map = get_targets(wins, opts)
    if #sights > 1 then
        advance_jump(ns_buf_map, sights, opts)
    elseif #sights == 1 then
        do_jump(sights[1][1], sights[1][3] + 1, sights[1][4], opts)
    else
        api.nvim_echo({ { "No sights to jump to" } }, false, {})
    end
end

---@return integer[]
function Jump.get_hl_namespaces()
    return vim.deepcopy(namespaces, true)
end

return Jump

-- TODO: The default locator in xmode and omode should go to the end of the word if it's after the
-- cursor, and the beginning if before. This requires the cursor position to be passed in. The
-- plug mappings should have the proper scopes.
-- TODO: Document a couple locator examples, like CWORD
-- TODO: Document the locator behavior:
-- - It's win called to the current win
-- - cur_pos is passed by reference. Do not modify
-- As a general design philosophy and as a note, because the locator is run so many times, it
-- neds to be perf optimized, so even obvious boilerplate like checking folds is not done so that
-- nothing superfluous happens
-- TODO: Add a pre-locator opt for before cursor or after cursor only. Add doc examples showing
-- how to make EasyMotion style f/t motions
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

-- LOW: Would be interesting to test storing the labels as a struct of arrays

-- DOCUMENT: A couple example spotter functions
