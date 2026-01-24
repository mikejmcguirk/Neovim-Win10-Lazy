-- NOTE: Doing <cr> -> letter to target has been tested and this still produces two token labels,
-- resulting in more inputs to get to the target. For the end of word case, you can consistently
-- use e or E. Problem I suppose is middle of the word case, where you would need to use f/t,
-- adding two more keys. But this is rare enough that I think this saves keys on average, not to
-- mention the lack of smoothness of the four char motion. Though some of that can be ascribed to
-- lack of practice.
-- TODO: For this and the f/t/;/, case, how is the unicode handling?
-- TODO: f/t should probably allow for customizing the function that determines the word boundary
-- somehow. You might also be able to generalize this out to the jump function. You could provide
-- CWORD (space separated) as an alternative builtin, or at least an example
-- TODO: For the f/t case, ;/, don't need to worry about caching. From a particular set of saved
-- char, direction, and t flags, we can just advance through the text and find where to go.
-- Caching would only be relevant in the particular undo state the original cmd was run, and I'm
-- not sure the perf benefit would be worth the complexity.
-- The jump functionality is a modified version of https://github.com/nvim-mini/mini.jump2d
-- TODO: Look at this: https://github.com/neovim/neovim/discussions/36785
-- TODO: A question that applies to any plugin is - If you want to do configuration through
-- function callbacks rather than g:vars, what purpose to <Plug> maps serve? In certain cases,
-- they could seve as convenience ways to map a bundle of settings. But if the mappable function
-- has the desired defaults, what does a <Plug> map do?

local api = vim.api
local fn = vim.fn

---List indexed because it is used in hot loops
---@class FarsightSight
---@field [1] integer Buffer ID
---@field [2] integer Zero indexed row |api-indexing|
---@field [3] integer Zero index col, inclusive for extmarks |api-indexing|
---@field [4] string[] Label
---@field [5] [string,string|integer][] Extmark virtual text

local MAX_TOKENS = 2
local TOKENS = vim.split("abcdefghijklmnopqrstuvwxyz", "")

-- DOCUMENT: Advertise these HL groups
local HL_JUMP = "FarsightJump"
local HL_JUMP_AHEAD = "FarsightJumpAhead"
local HL_JUMP_TARGET = "FarsightJumpTarget"

-- FARSIGHT: These are not great defaults. But some blockers to determining:
-- - What defaults would be patternful with the F/T motions?
-- - How should extmarks be config'd in general? Would need to look at the jump plugin and
-- Flash. Ideally, the user could just provide a callback to setting extmarks. Like, they
-- would get the table of info the function generates, and you could do what you want with them
-- The biggest use case I'm not sure if that addresses is dimming. Would also need to make sure
-- the ns is passed out
api.nvim_set_hl(0, HL_JUMP, { default = true, reverse = true })
api.nvim_set_hl(0, HL_JUMP_AHEAD, { default = true, reverse = true })
api.nvim_set_hl(0, HL_JUMP_TARGET, { default = true, reverse = true })

local JUMP_HL_NS = api.nvim_create_namespace("FarsightJumps")

-- Per mini.jump2d, while nvim_tabpage_list_wins does currently ensure proper window layout, this
-- is not documented behavior and thus can change. The below function ensures layout
---@param tabpage integer
---@return integer[]
local function get_focusable_wins_ordered(tabpage)
    local wins = api.nvim_tabpage_list_wins(tabpage)
    local focusable_wins = {} ---@type integer[]
    local positions = {} ---@type { [1]:integer, [2]:integer, [3]:integer }[]

    for _, win in ipairs(wins) do
        local config = api.nvim_win_get_config(win)
        if config.focusable and not config.hide then
            focusable_wins[#focusable_wins + 1] = win
            local pos = api.nvim_win_get_position(win)
            positions[win] = { pos[1], pos[2], config.zindex or 0 }
        end
    end

    table.sort(focusable_wins, function(a, b)
        local pos_a = positions[a]
        local pos_b = positions[b]

        if pos_a[3] < pos_b[3] then
            return true
        elseif pos_a[3] > pos_b[3] then
            return false
        elseif pos_a[2] < pos_b[2] then
            return true
        elseif pos_a[2] > pos_b[2] then
            return false
        else
            return pos_a[1] < pos_b[1]
        end
    end)

    return focusable_wins
end

---@param all_wins boolean
---@return integer[]
local function get_jump_wins(all_wins)
    return all_wins and get_focusable_wins_ordered(0) or { api.nvim_get_current_win() }
end

-- MID: Profile this against regex:match_line()

local cword_regex = vim.regex("\\k\\+")

---@param row integer
---@param line string
---@param _ integer
---@return integer[]
local function default_get_cols(row, line, _)
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

---@param wins integer[]
---@param opts farsight.jump.JumpOpts
---@return FarsightSight[], integer[]
local function get_sights(wins, opts)
    local sights = {} ---@type FarsightSight[]
    ---@type fun(integer, string, integer):integer[]
    local get_cols = opts.get_cols or default_get_cols

    local bufs = {} ---@type integer[]
    for _, win in ipairs(wins) do
        local buf = api.nvim_win_get_buf(win)
        bufs[#bufs + 1] = buf
        api.nvim_win_call(win, function()
            local top = fn.line("w0")
            local bot = fn.line("w$")
            for i = top, bot do
                local line = fn.getline(i)
                local cols = get_cols(i, line, buf)
                -- FARSIGHT: I think this is a version 12 function
                vim.list.unique(cols)
                table.sort(cols, function(a, b)
                    return a < b
                end)

                for _, col in ipairs(cols) do
                    local row_0 = i - 1
                    sights[#sights + 1] = { buf, row_0, col, {}, {} }
                end
            end
        end)
    end

    local count_bufs = #bufs
    vim.list.unique(bufs)
    if #bufs ~= count_bufs then
        vim.list.unique(sights, function(sight)
            return tostring(sight[1]) .. tostring(sight[2]) .. tostring(sight[3])
        end)
    end

    return sights, bufs
end

-- MID: The variable names in this function could be more clear
-- LOW: In theory, the best way to do this would be to figure out a way to pre-determine the length
-- of each label and allocate each only once as a string

---@param sights FarsightSight[]
---@param opts farsight.jump.JumpOpts
---@return nil
local function populate_sight_labels(sights, opts)
    if #sights <= 1 then
        return
    end

    -- TODO: Either use individualized casting here ot a private JumpOptsResolved type
    local tokens = opts.tokens or TOKENS
    local max_tokens = opts.max_tokens
    local queue = {} ---@type { [1]: integer, [2]:integer }[]
    queue[#queue + 1] = { 1, #sights }

    while #queue > 0 do
        local range = table.remove(queue, 1) ---@type { [1]: integer, [2]:integer }
        local len = range[2] - range[1] + 1

        local quotient = math.floor(len / #tokens)
        local remainder = len % #tokens
        local on_token = quotient + (remainder >= 1 and 1 or 0)
        remainder = remainder > 0 and remainder - 1 or remainder

        local token_idx = 1
        local token_start = range[1]

        for i = range[1], range[2] do
            sights[i][4][#sights[i][4] + 1] = tokens[token_idx]
            on_token = on_token - 1
            if on_token == 0 then
                on_token = quotient + (remainder >= 1 and 1 or 0)
                remainder = remainder > 0 and remainder - 1 or remainder

                if i > token_start and #sights[i][4] < max_tokens then
                    queue[#queue + 1] = { token_start, i }
                end

                token_idx = token_idx + 1
                token_start = i + 1
            end
        end
    end
end

-- LOW: Profile this function to see if it could be optimized further

---@param sights FarsightSight[]
local function populate_virt_text(sights, tokens)
    local first_counts = {} ---@type table<string, integer>
    for _, token in ipairs(tokens) do
        first_counts[token] = 0
    end

    for _, sight in ipairs(sights) do
        first_counts[sight[4][1]] = first_counts[sight[4][1]] + 1
    end

    for i = 1, #sights do
        local only_token = first_counts[sights[i][4][1]] == 1
        local first_hl_group = only_token and HL_JUMP_TARGET or HL_JUMP
        sights[i][5][1] = { sights[i][4][1], first_hl_group }

        local max_display_tokens = (function()
            if i == #sights then
                return math.huge
            end

            local same_buf = sights[i][1] == sights[i + 1][1]
            local same_line = same_buf and sights[i][2] == sights[i + 1][2]
            return same_line and (sights[i + 1][3] - sights[i][3]) or math.huge
        end)()

        local total_tokens = math.min(#sights[i][4], max_display_tokens)
        if 2 <= total_tokens then
            local tokens_ahead = table.concat(sights[i][4], "", 2, total_tokens)
            sights[i][5][2] = { tokens_ahead, HL_JUMP_AHEAD }
        end
    end
end

---@param cur_win integer
---@param wins integer[]
---@param buf integer
---@param row integer
---@param opts farsight.jump.JumpOpts
---@return integer
local function find_jump_win(cur_win, wins, buf, row, opts)
    local start_idx = 1
    for i, win in ipairs(wins) do
        if win == cur_win then
            start_idx = i
            break
        end
    end

    if opts.prefer_next_win then
        start_idx = start_idx < #wins and start_idx + 1 or 1
    end

    local idx = start_idx
    while true do
        local win = wins[idx]
        if api.nvim_win_get_buf(win) == buf then
            local top ---@type integer
            local bot ---@type integer
            api.nvim_win_call(win, function()
                top = fn.line("w0")
                bot = fn.line("w$")
            end)

            if top <= row and row <= bot then
                return win
            end
        end

        idx = idx < #wins and idx + 1 or 1
        if idx == start_idx then
            break
        end
    end
end

--- Row and col are cursor indexed
---@param wins integer[]
---@param buf integer
---@param row integer
---@param col integer
---@param opts farsight.jump.JumpOpts
---@return nil
local function do_jump(wins, buf, row, col, opts)
    local cur_win = api.nvim_get_current_win()
    local win = find_jump_win(cur_win, wins, buf, row, opts)
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

---Edits wins, bufs, and sights in place
---@param wins integer[]
---@param bufs integer[]
---@param sights FarsightSight[]
---@param opts farsight.jump.JumpOpts
---@return nil
local function advance_jump(wins, bufs, sights, opts)
    while true do
        populate_sight_labels(sights, opts)
        populate_virt_text(sights, opts.tokens)

        ---@type vim.api.keyset.set_extmark
        local extmark_opts = { hl_mode = "combine", priority = 1000, virt_text_pos = "overlay" }
        for _, sight in ipairs(sights) do
            extmark_opts.virt_text = sight[5]
            pcall(api.nvim_buf_set_extmark, sight[1], JUMP_HL_NS, sight[2], sight[3], extmark_opts)
        end

        api.nvim__redraw({ valid = true })
        local _, input = pcall(fn.getcharstr)
        for _, buf in ipairs(bufs) do
            pcall(api.nvim_buf_clear_namespace, buf, JUMP_HL_NS, 0, -1)
        end

        if not vim.list_contains(opts.tokens, input) then
            return
        end

        local new_sights = {} ---@type FarsightSight[]
        for _, sight in ipairs(sights) do
            if sight[4][1] == input then
                new_sights[#new_sights + 1] = sight
            end
        end

        sights = new_sights
        if #sights == 1 then
            do_jump(wins, sights[1][1], sights[1][2] + 1, sights[1][3], opts)
            return
        end

        local new_bufs = {} ---@type table<integer, boolean>
        for _, sight in ipairs(sights) do
            new_bufs[sight[1]] = true
            sight[4] = {}
            sight[5] = {}
        end

        bufs = vim.tbl_keys(new_bufs)
    end
end

---@class farsight.StepJump
local Jump = {}

---@class farsight.jump.JumpOpts
---@field all_wins? boolean Place jump labels in all wins?
---The input row argument is one indexed
---This function will be called in the window context being evaluated. This means, for example,
---that foldclosed() will return the proper result
---The returned columns must be zero indexed
---The returned array will be de-duplicated and sorted from least to greatest
---@field get_cols? fun(integer, string, integer):integer[]
---@field keepjumps? boolean
---@field max_tokens? integer
---@field tokens? string[]
---@field prefer_next_win? boolean

-- FARSIGHT: The default spotter in xmode and omode should go to the end of the word if it's
-- after the cursor, and the beginning of the word if it's before. I would guess that this info
-- would have to be passed into the spotter function, because having the user specify multiple
-- spotter functions by mode would be absurd. Make sure cursor position is passed into the
-- spotter function so it doesn't have to be repeatedly queried
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
    vim.validate("opts", opts, "table")
    vim.validate("opts.all_wins", opts.all_wins, "boolean", true)
    vim.validate("opts.get_cols", opts.get_cols, "callable", true)
    -- FARSIGHT: Use the uint validation here
    -- FARSIGHT: Validate that max_tokens >= 1
    opts.max_tokens = opts.max_tokens or MAX_TOKENS
    vim.validate("opts.max_tokens", opts.max_tokens, "number")
    -- FARSIGHT: Would need my rancher list validation here
    -- FARSIGHT: Validate that opts.tokens >=2
    -- TODO: If opts.tokens is valid, it should be de-duplicated
    opts.tokens = opts.tokens or TOKENS
    vim.validate("opts.tokens", opts.tokens, vim.islist)

    -- TODO: The naming is somewhat confusing. For internal purposes, a sight makes sense as an
    -- encoding of the buf, row, col, and label. But how clear is this to the user? This is
    -- confused by the get_cols opt. Maybe just call that get_sights or sight_filter?
    local wins = get_jump_wins(opts.all_wins)
    local sights, bufs = get_sights(wins, opts)
    if #sights > 1 then
        advance_jump(wins, bufs, sights, opts)
    elseif #sights == 1 then
        do_jump(wins, sights[1][1], sights[1][2] + 1, sights[1][3], opts)
    else
        api.nvim_echo({ { "No sights to jump to" } }, false, {})
    end
end

---@return integer
function Jump.get_hl_ns()
    return JUMP_HL_NS
end

return Jump

-- MID: https://antonk52.github.io/webdevandstuff/post/2025-11-30-diy-easymotion.html

-- LOW: The labels could be potentially optimized by doing them in a DoD/SoA way. I'm not sure
-- how much faster this would be since the arrays have to be created a step at a time as well as
-- deleted a step at a time, resulting in more(?) allocations

-- DOCUMENT: Should try to recognize and integrate the past history of these types of
-- motions and plugins, particularly EasyMotion. Also consider the text editor that Helix stole its
-- motion from
-- DOCUMENT: A couple example spotter functions
