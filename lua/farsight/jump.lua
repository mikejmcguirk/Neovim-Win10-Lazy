-- The jump functionality is a modified version of https://github.com/nvim-mini/mini.jump2d
-- TODO: Look at this: https://github.com/neovim/neovim/discussions/36785

local api = vim.api
local fn = vim.fn

---@alias farsight.GetColsFunc fun(integer, string, integer):integer[]

---@class farsight.jump.JumpOpts
---@field all_wins? boolean Place jump labels in all wins?
---The input row argument is one indexed
---This function will be called in the window context being evaluated. This means, for example,
---that foldclosed() will return the proper result
---The returned columns must be zero indexed
---The returned array will be de-duplicated and sorted from least to greatest
---@field get_cols? farsight.GetColsFunc
---@field max_tokens? integer
---@field tokens? string[]

---@class FarsightSight
---@field buf integer Buffer ID
---@field row integer Zero indexed row |api-indexing|
---@field col integer Zero index col, inclusive for extmarks |api-indexing|
---@field label string[]

-- FARSIGHT: This can just be rolled into the sights since we're no longer using sights to hold
-- win info
---@class FarsightExtmarkInfo
---@field buf integer
---@field row integer Zero indexed
---@field col integer Zero indexed
---@field virt_text [string,string|integer][]

local MAX_TOKENS = 2 ---@type integer
local TOKENS = vim.split("abcdefghijklmnopqrstuvwxyz", "") ---@type string[]

-- FARSIGHT: Advertise these HL groups
---@type table<string, string>
local hl = {
    JUMP = "FarsightJump",
    JUMP_AHEAD = "FarsightJumpAhead",
    JUMP_TARGET = "FarsightJumpTarget",
}

-- FARSIGHT: These are not great defaults. But some blockers to determining:
-- - What defaults would be patternful with the F/T motions?
-- - How should extmarks be config'd in general? Would need to look at the jump plugin and
-- Flash. Ideally, the user could just provide a callback to setting extmarks. Like, they
-- would get the table of info the function generates, and you could do what you want with them
-- The biggest use case I'm not sure if that addresses is dimming. Would also need to make sure
-- the ns is passed out
for _, h in pairs(hl) do
    vim.api.nvim_set_hl(0, h, { default = true, reverse = true })
end

-- FARSIGHT: Maybe provide an interface to the ns
local JUMP_HL_NS = api.nvim_create_namespace("FarsightJumps")

-- FARSIGHT: This function does a bit too much, even with the rename. The issue is I don't want
-- to pull win configs multiple times. Could cache those as well, but that's a bit goofy
-- Per mini.jump2d, while nvim_tabpage_list_wins does currently ensure proper window layout, this
-- is not documented behavior and thus can change. The below function ensures layout
---@param tabpage integer
---@return integer[]
local function get_focusable_wins_ordered(tabpage)
    local wins = api.nvim_tabpage_list_wins(tabpage) ---@type integer[]
    local configs = {} ---@type vim.api.keyset.win_config_ret[]
    for _, win in ipairs(wins) do
        configs[win] = api.nvim_win_get_config(win)
    end

    -- FARSIGHT: More naming issues. This really is - Can this have a winnr?
    local focusable_wins = vim.tbl_filter(function(win)
        return configs[win].focusable and not configs[win].hide
    end, wins)

    local wins_pos = {} ---@type { [1]:integer, [2]:integer, [3]:integer }[]
    for _, win in ipairs(focusable_wins) do
        local pos = api.nvim_win_get_position(win) ---@type { [1]:integer, [2]:integer }
        local zindex = configs[win].zindex or 0 ---@type integer
        wins_pos[win] = { pos[1], pos[2], zindex }
    end

    table.sort(focusable_wins, function(a, b)
        if wins_pos[a][3] < wins_pos[b][3] then
            return true
        elseif wins_pos[a][3] > wins_pos[b][3] then
            return false
        elseif wins_pos[a][2] < wins_pos[b][2] then
            return true
        elseif wins_pos[a][2] > wins_pos[b][2] then
            return false
        else
            return wins_pos[a][1] < wins_pos[b][1]
        end
    end)

    return focusable_wins
end

local sight_cache = nil ---@type FarsightSight[]|nil
local win_cache = nil ---@type integer[]|nil

---@param all_wins boolean
---@return integer[]
local function get_jump_wins(all_wins)
    if all_wins then
        return get_focusable_wins_ordered(0)
    else
        local cur_win = api.nvim_get_current_win() ---@type integer
        win_cache = { cur_win }
        return { cur_win }
    end
end

---@param row integer
---@param line string
---@param _ integer
---@return integer[]
local function default_get_cols(row, line, _)
    local prevnonblank = fn.prevnonblank(row) ---@type integer
    if prevnonblank ~= row then
        return {}
    end

    local folded = fn.foldclosed(row) ---@type integer
    if folded ~= -1 then
        return {}
    end

    local cols = {} ---@type integer[]
    local regex = vim.regex("\\k\\+") ---@type vim.regex
    local start = 1 ---@type integer

    local len_ = (line:len() + 1) ---@type integer
    for _ = 1, len_ do
        local from, to = regex:match_str(line) ---@type integer|nil, integer|nil
        if from == nil then
            break
        end

        local col = from + start - 1 ---@type integer
        cols[#cols + 1] = col

        line = line:sub(to + 1)
        start = start + to
    end

    return cols
end

---@param opts farsight.jump.JumpOpts
---@return FarsightSight[]
local function get_sights(opts)
    local wins = get_jump_wins(opts.all_wins) ---@type integer[]
    local sights = {} ---@type FarsightSight[]
    local get_cols = opts.get_cols or default_get_cols ---@type farsight.GetColsFunc

    -- FARSIGHT: Basically all this info, win buf, top and bottom, is used later to find the
    -- jump win, so it should be cached.
    local bufs = {} ---@type integer[]
    for _, win in ipairs(wins) do
        api.nvim_win_call(win, function()
            local buf = api.nvim_win_get_buf(win) ---@type integer
            bufs[#bufs + 1] = buf
            local top = fn.line("w0") ---@type integer
            local bot = fn.line("w$") ---@type integer
            for i = top, bot do
                local line = fn.getline(i) ---@type string
                local cols = get_cols(i, line, buf)
                -- FARSIGHT: I think this is a version 12 function
                vim.list.unique(cols)
                table.sort(cols, function(a, b)
                    return a < b
                end)

                for _, col in ipairs(cols) do
                    local row_0 = i - 1 ---@type integer
                    ---@type FarsightSight
                    local sight = { row = row_0, col = col, buf = buf, label = {} }
                    sights[#sights + 1] = sight
                end
            end
        end)
    end

    local count_bufs = #bufs ---@type integer
    vim.list.unique(bufs)
    if #bufs ~= count_bufs then
        vim.list.unique(sights, function(sight)
            return tostring(sight.buf) .. tostring(sight.row) .. tostring(sight.col)
        end)
    end

    -- Do late so we don't create goofiness if we edit this function later
    win_cache = wins
    return sights
end

---@param sights FarsightSight[]
---@return nil
local function clear_sight_labels(sights)
    for _, sight in ipairs(sights) do
        sight.label = {}
    end
end

-- LOW: In theory, the best way to do this would be to figure out a way to pre-determine the length
-- of each label and allocate each only once as a string
---@param sights FarsightSight[]
---@param opts farsight.jump.JumpOpts
---@return nil
local function populate_sight_labels(sights, opts)
    if #sights <= 1 then
        return
    end

    local tokens = opts.tokens or TOKENS ---@type string[]
    local max_tokens = opts.max_tokens or MAX_TOKENS ---@type integer
    local queue = {} ---@type { [1]: integer, [2]:integer }[]
    queue[#queue + 1] = { 1, #sights }

    while #queue > 0 do
        local range = table.remove(queue, 1) ---@type { [1]: integer, [2]:integer }
        local len = range[2] - range[1] + 1 ---@type integer

        local quotient = math.floor(len / #tokens) ---@type integer
        local remainder = len % #tokens ---@type integer
        local extra = remainder >= 1 and 1 or 0 ---@type integer
        local on_token = quotient + extra ---@type integer
        remainder = remainder > 0 and remainder - 1 or remainder

        local token_idx = 1 ---@type integer
        local token_start = range[1] ---@type integer

        for i = range[1], range[2] do
            local label = sights[i].label ---@type string[]
            label[#label + 1] = tokens[token_idx]
            on_token = on_token - 1
            if on_token == 0 then
                extra = remainder >= 1 and 1 or 0
                on_token = quotient + extra
                remainder = remainder > 0 and remainder - 1 or remainder

                if i > token_start and #label < max_tokens then
                    queue[#queue + 1] = { token_start, i }
                end

                token_idx = token_idx + 1
                token_start = i + 1
            end
        end
    end
end

---@param sights FarsightSight[]
---@return table<string, integer>
local function get_first_token_counts(sights)
    local first_token_counts = {} ---@type table<string, integer>
    for _, sight in ipairs(sights) do
        local first_token = sight.label[1] ---@type string
        local count = first_token_counts[first_token] or 0 ---@type integer
        first_token_counts[first_token] = count + 1
    end

    return first_token_counts
end

---@param sights FarsightSight[]
---@return FarsightExtmarkInfo[]
local function get_extmarks_from_sights(sights)
    local extmarks = {} ---@type FarsightExtmarkInfo[]
    local virt_text = {} ---@type [string,string|integer][]
    local first_token_counts = get_first_token_counts(sights) ---@type table<string, integer>

    for i = 1, #sights do
        local sight = sights[i] ---@type FarsightSight
        local buf = sight.buf ---@type integer
        local row = sight.row ---@type integer
        local col = sight.col ---@type integer
        local label = sight.label ---@type string[]

        local next_sight = sights[i + 1] or {} ---@type FarsightSight
        local next_buf = next_sight.buf ---@type integer
        local next_row = next_sight.row ---@type integer
        local next_col = next_sight.col ---@type integer

        local same_line = buf == next_buf and row == next_row ---@type boolean
        local max_display_tokens = same_line and (next_col - col) or math.huge ---@type integer
        local display_tokens = math.min(#label, max_display_tokens) ---@type integer

        ---@type integer|string
        local first_hl_group = first_token_counts[label[1]] == 1 and hl.JUMP_TARGET or hl.JUMP
        virt_text[#virt_text + 1] = { label[1], first_hl_group }

        local label_str = table.concat(label) ---@type string
        local tokens_ahead = string.sub(label_str, 2, display_tokens) ---@type string
        if tokens_ahead ~= "" then
            table.insert(virt_text, { tokens_ahead, hl.JUMP_AHEAD })
        end

        extmarks[#extmarks + 1] = { buf = buf, row = row, col = col, virt_text = virt_text }
        virt_text = {}
    end

    return extmarks
end

local function display_sights(sights)
    sights = sights or sight_cache or {}

    local extmarks = get_extmarks_from_sights(sights) ---@type FarsightExtmarkInfo[]
    for _, extmark in ipairs(extmarks) do
        ---@type vim.api.keyset.set_extmark
        local extmark_opts = {
            hl_mode = "combine",
            priority = 1000,
            virt_text = extmark.virt_text,
            virt_text_pos = "overlay",
        }

        local buf = extmark.buf ---@type integer
        local row = extmark.row ---@type integer
        local col = extmark.col ---@type integer
        pcall(api.nvim_buf_set_extmark, buf, JUMP_HL_NS, row, col, extmark_opts)
    end

    api.nvim_cmd({ cmd = "redraw" }, {})
end

-- FARSIGHT: The "prefer current win" for jumps behavior should be configurable
-- There also needs attention to be paid to how window caching and fallback works. A goofy scenario
-- lies in wait here where prefer current win is off, the cache is lost, and a non-current win is
-- pulled in and jumped to
---@param buf integer
---@param row integer
---@return integer
local function find_jump_win(buf, row)
    local wins = win_cache or get_focusable_wins_ordered(0) ---@type integer[]
    -- FARSIGHT: This *should* work because winnrs excluse non-focusable and hidden wins
    -- I'm also not convinced this is the most efficient way to do this
    -- FARSIGHT: This would fail though if the cursor were in a hidden window, which is technically
    -- possible. I don't know if you just set to winnr 1
    local start_winnr = api.nvim_win_get_number(0) ---@type integer
    local winnr = start_winnr ---@type integer

    -- FARSIGHT: Why would this go wrong? Informational error return
    assert(winnr > 0)
    for _ = 1, 100 do
        local win = wins[winnr] ---@type integer
        local win_buf = api.nvim_win_get_buf(win) ---@type integer
        if win_buf == buf then
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

        winnr = winnr - 1
        if winnr == 0 then
            winnr = #wins
        end

        if winnr == start_winnr then
            break
        end
    end

    -- FARSIGHT: Need an informational error return
    error("buf not found")
end

--- Row and col are cursor indexed
---@param buf integer
---@param row integer
---@param col integer
local function do_jump(buf, row, col)
    api.nvim_cmd({ cmd = "norm", args = { "m`" }, bang = true }, {})

    local win = find_jump_win(buf, row) ---@type integer
    api.nvim_set_current_win(win)
    api.nvim_win_set_cursor(win, { row, col })
    api.nvim_cmd({ cmd = "norm", args = { "zv" }, bang = true }, {})

    win_cache = nil
end

-- MID: This function does a lot of different things under one name
---@param sights FarsightSight[]|nil
---@return nil
local function clear_sights(sights)
    sights = sights or sight_cache or {}

    local bufs = {}
    for _, sight in ipairs(sights) do
        bufs[sight.buf] = true
    end

    for _, buf_id in ipairs(vim.tbl_keys(bufs)) do
        pcall(vim.api.nvim_buf_clear_namespace, buf_id, JUMP_HL_NS, 0, -1)
    end
end

---@param sights FarsightSight[]
---@return nil
local function stop_jump(sights)
    clear_sights(sights)
    sight_cache = nil
    win_cache = nil
    api.nvim_cmd({ cmd = "redraw" }, {})
end

---@param opts farsight.jump.JumpOpts
---@return nil
local function advance_jump(opts)
    local sights = sight_cache ---@type FarsightSight[]|nil
    if type(sights) == "nil" or #sights < 1 then
        clear_sights(sights)
        sight_cache = nil
        return
    end

    local tokens = opts.tokens or TOKENS ---@type string[]
    local _, key = pcall(fn.getcharstr) ---@type boolean, integer|string
    if vim.tbl_contains(tokens, key) then
        clear_sights(sights)
        sights = vim.tbl_filter(function(x)
            return x.label[1] == key
        end, sights)

        if #sights > 1 then
            clear_sight_labels(sights)
            populate_sight_labels(sights, opts)
            display_sights(sights)
            sight_cache = sights

            -- FARSIGHT: Make this not recursion
            advance_jump(opts)
        end
    end

    if #sights == 1 then
        do_jump(sights[1].buf, sights[1].row + 1, sights[1].col)
    end

    stop_jump(sights)
end

---@class Jump
local Jump = {}

-- FARSIGHT: The default spotter in xmode and omode should go to the end of the word if it's
-- after the cursor, and the beginning of the word if it's before. I would guess that this info
-- would have to be passed into the spotter function, because having the user specify multiple
-- spotter functions by mode would be absurd. Make sure cursor position is passed into the
-- spotter function so it doesn't have to be repeatedly queried
-- FARSIGHT: Add back in the ability to do before or after cursor only. You can use this
-- function to create an EasyMotion style F/T map. You can create your own wrapper to enter
-- F/T and get the character, then pass that arg into a sight_in function which is passed into
-- here in order to get the relevant locations. Would be cool example in documentation
-- FARSIGHT: A couple basic default spotter functions should be provided. Can look at what
-- Jump2D offers
-- NOGO: Add in opts to control how folds or blanks are handled. These are concerns within
-- the handling of the individual line and should be scoped there
---@param opts farsight.jump.JumpOpts?
---@return nil
Jump.jump = function(opts)
    opts = opts or {}
    vim.validate("opts", opts, "table")
    vim.validate("opts.all_wins", opts.all_wins, "boolean", true)
    vim.validate("opts.get_cols", opts.get_cols, "callable", true)
    -- FARSIGHT: Use the uint validation here
    -- FARSIGHT: Validate that max_tokens >= 1
    vim.validate("opts.max_tokens", opts.max_tokens, "number", true)
    -- FARSIGHT: Would need my rancher list validation here
    -- FARSIGHT: Validate that opts.tokens >=2
    vim.validate("opts.tokens", opts.tokens, vim.islist, true)

    local sights = get_sights(opts) ---@type FarsightSight[]
    if #sights == 0 then
        api.nvim_echo({ { "No sights to jump to" } }, false, {})
        return
    end

    if #sights == 1 then
        do_jump(sights[1].buf, sights[1].row + 1, sights[1].col)
        return
    end

    populate_sight_labels(sights, opts)
    display_sights(sights)

    sight_cache = sights
    advance_jump(opts)
end

return Jump

-- MID: https://antonk52.github.io/webdevandstuff/post/2025-11-30-diy-easymotion.html
