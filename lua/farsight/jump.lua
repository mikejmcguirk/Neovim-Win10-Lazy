-- TODO: For this and the f/t/;/, case, how is the unicode handling?
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

-- MID: Because this datatype is used in hot loops, might be worth list indexing rather than
-- hash indexing

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
vim.api.nvim_set_hl(0, HL_JUMP, { default = true, reverse = true })
vim.api.nvim_set_hl(0, HL_JUMP_AHEAD, { default = true, reverse = true })
vim.api.nvim_set_hl(0, HL_JUMP_TARGET, { default = true, reverse = true })

-- FARSIGHT: Maybe provide an interface to the ns
local JUMP_HL_NS = api.nvim_create_namespace("FarsightJumps")

-- FARSIGHT: This function does a bit too much, even with the rename. The issue is I don't want
-- to pull win configs multiple times. Could cache those as well, but that's a bit goofy
-- Per mini.jump2d, while nvim_tabpage_list_wins does currently ensure proper window layout, this
-- is not documented behavior and thus can change. The below function ensures layout
---@param tabpage integer
---@return integer[]
local function get_focusable_wins_ordered(tabpage)
    local wins = api.nvim_tabpage_list_wins(tabpage)
    local configs = {} ---@type table<integer, vim.api.keyset.win_config_ret>
    for _, win in ipairs(wins) do
        configs[win] = api.nvim_win_get_config(win)
    end

    -- FARSIGHT: More naming issues. This really is - Can this have a winnr?
    local focusable_wins = vim.tbl_filter(function(win)
        return configs[win].focusable and not configs[win].hide
    end, wins)

    local wins_pos = {} ---@type { [1]:integer, [2]:integer, [3]:integer }[]
    for _, win in ipairs(focusable_wins) do
        local pos = api.nvim_win_get_position(win)
        local zindex = configs[win].zindex or 0
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
    if fn.prevnonblank(row) ~= row or fn.foldclosed(row) ~= -1 then
        return {}
    end

    local cols = {} ---@type integer[]
    local regex = vim.regex("\\k\\+")
    local start = 1
    local len_ = (line:len() + 1)

    for _ = 1, len_ do
        local from, to = regex:match_str(line)
        if from == nil or to == nil then
            break
        end

        cols[#cols + 1] = from + start - 1
        line = line:sub(to + 1)
        start = start + to
    end

    return cols
end

---@param opts farsight.jump.JumpOpts
---@return FarsightSight[]
local function get_sights(opts)
    local wins = get_jump_wins(opts.all_wins)
    local sights = {} ---@type FarsightSight[]
    local get_cols = opts.get_cols or default_get_cols ---@type farsight.GetColsFunc

    -- FARSIGHT: Basically all this info, win buf, top and bottom, is used later to find the
    -- jump win, so it should be cached.
    local bufs = {} ---@type integer[]
    for _, win in ipairs(wins) do
        api.nvim_win_call(win, function()
            local buf = api.nvim_win_get_buf(win)
            bufs[#bufs + 1] = buf
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
                    sights[#sights + 1] = { row = row_0, col = col, buf = buf, label = {} }
                end
            end
        end)
    end

    local count_bufs = #bufs
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
            local label = sights[i].label
            label[#label + 1] = tokens[token_idx]
            on_token = on_token - 1
            if on_token == 0 then
                on_token = quotient + (remainder >= 1 and 1 or 0)
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
        local first_token = sight.label[1]
        local count = first_token_counts[first_token] or 0
        first_token_counts[first_token] = count + 1
    end

    return first_token_counts
end

---@param sights FarsightSight[]
---@return FarsightExtmarkInfo[]
local function get_extmarks_from_sights(sights)
    local extmarks = {} ---@type FarsightExtmarkInfo[]
    local virt_text = {} ---@type [string,string|integer][]
    local first_token_counts = get_first_token_counts(sights)

    for i = 1, #sights do
        local buf = sights[i].buf
        local row = sights[i].row
        local col = sights[i].col
        local label = sights[i].label

        local next_sight = sights[i + 1] or {}
        local next_buf = next_sight.buf
        local next_row = next_sight.row
        local next_col = next_sight.col

        local same_line = buf == next_buf and row == next_row
        local max_display_tokens = same_line and (next_col - col) or math.huge
        local display_tokens = math.min(#label, max_display_tokens)

        local first_hl_group = first_token_counts[label[1]] == 1 and HL_JUMP_TARGET or HL_JUMP
        virt_text[#virt_text + 1] = { label[1], first_hl_group }

        local tokens_ahead = string.sub(table.concat(label), 2, display_tokens)
        if tokens_ahead ~= "" then
            table.insert(virt_text, { tokens_ahead, HL_JUMP_AHEAD })
        end

        extmarks[#extmarks + 1] = { buf = buf, row = row, col = col, virt_text = virt_text }
        virt_text = {}
    end

    return extmarks
end

---@param sights FarsightSight[]
local function display_sights(sights)
    local extmarks = get_extmarks_from_sights(sights)
    for _, extmark in ipairs(extmarks) do
        ---@type vim.api.keyset.set_extmark
        local extmark_opts = {
            hl_mode = "combine",
            priority = 1000,
            virt_text = extmark.virt_text,
            virt_text_pos = "overlay",
        }

        pcall(
            api.nvim_buf_set_extmark,
            extmark.buf,
            JUMP_HL_NS,
            extmark.row,
            extmark.col,
            extmark_opts
        )
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
    local wins = win_cache or get_focusable_wins_ordered(0)
    -- FARSIGHT: This *should* work because winnrs exclude non-focusable and hidden wins
    -- I'm also not convinced this is the most efficient way to do this
    -- FARSIGHT: This would fail though if the cursor were in a hidden window, which is technically
    -- possible. I don't know if you just set to winnr 1
    local start_winnr = api.nvim_win_get_number(0)
    local winnr = start_winnr

    -- FARSIGHT: Why would this go wrong? Informational error return
    assert(winnr > 0)
    for _ = 1, 100 do
        local win = wins[winnr]
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
---@return nil
local function do_jump(buf, row, col)
    -- TODO: I'm not sure if this is helpful if you switch windows and buffers, because the
    -- original window doesn't change, and the current one can't jump back. But I don't know if
    -- that's because of how I have my jop configured.
    -- MID: This should be an opt
    api.nvim_cmd({ cmd = "norm", args = { "m`" }, bang = true }, {})

    local win = find_jump_win(buf, row)
    -- TODO: Check the C core to see if checking the current win is worth it
    api.nvim_set_current_win(win)
    api.nvim_win_set_cursor(win, { row, col })
    api.nvim_cmd({ cmd = "norm", args = { "zv" }, bang = true }, {})
end

---@param sights FarsightSight[]
---@return nil
local function clear_sight_extmarks(sights)
    -- Use a map to avoid a separate de-duplication step
    local bufs = {} ---@type table<integer, boolean>
    for _, sight in ipairs(sights) do
        bufs[sight.buf] = true
    end

    for _, buf in ipairs(vim.tbl_keys(bufs)) do
        pcall(api.nvim_buf_clear_namespace, buf, JUMP_HL_NS, 0, -1)
    end
end

---@param sights FarsightSight[]
---@return nil
local function clear_jump_state(sights)
    clear_sight_extmarks(sights)
    win_cache = nil
    api.nvim_cmd({ cmd = "redraw" }, {})
end

---Edits sights in place
---@param sights FarsightSight[]
---@param opts farsight.jump.JumpOpts
---@return nil
local function advance_jump(sights, opts)
    while true do
        populate_sight_labels(sights, opts)
        display_sights(sights)

        local _, input = pcall(fn.getcharstr)
        if not vim.list_contains(opts.tokens, input) then
            clear_jump_state(sights)
            return
        end

        -- Clearing the old extmarks immediately feels subjectively better than doing so after
        -- filtering
        clear_sight_extmarks(sights)
        local new_sights = {} ---@type FarsightSight[]
        for _, sight in ipairs(sights) do
            if sight.label[1] == input then
                new_sights[#new_sights + 1] = sight
            end
        end

        sights = new_sights
        if #sights == 1 then
            do_jump(sights[1].buf, sights[1].row + 1, sights[1].col)
            clear_jump_state(sights)
            return
        end

        for _, sight in ipairs(sights) do
            sight.label = {}
        end
    end
end

---@class farsight.Jump
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
    local sights = get_sights(opts)
    if #sights <= 1 then
        if #sights == 1 then
            do_jump(sights[1].buf, sights[1].row + 1, sights[1].col)
        else
            api.nvim_echo({ { "No sights to jump to" } }, false, {})
        end

        clear_jump_state(sights)
        return
    end

    advance_jump(sights, opts)
end

return Jump

-- MID: https://antonk52.github.io/webdevandstuff/post/2025-11-30-diy-easymotion.html
