local api = vim.api
local fn = vim.fn

---@class FarsightSight
---@field [1] integer Window ID
---@field [2] integer Buffer ID
---@field [3] integer Zero indexed row |api-indexing|
---@field [4] integer Zero index col, inclusive for extmarks |api-indexing|
---@field [5] string[] Label
---@field [6] integer extmark namespace
---@field [7] [string,string|integer][] Extmark virtual text

local MAX_TOKENS = 2
local TOKENS = vim.split("abcdefghijklmnopqrstuvwxyz", "")

-- DOCUMENT: Advertise these HL groups
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
local function scope_cwords(row, line, _)
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
---@return FarsightSight[], table<integer, integer>
local function get_targets(wins, opts)
    local sights = {} ---@type FarsightSight[]
    ---@type fun(integer, string, integer):integer[]

    local missing_ns = #wins - #namespaces
    for _ = 1, missing_ns do
        namespaces[#namespaces + 1] = api.nvim_create_namespace("")
    end

    local win_ns_map = {}
    for i = 1, #wins do
        win_ns_map[wins[i]] = namespaces[i]
        api.nvim__ns_set(namespaces[i], { wins = { wins[i] } })
    end

    local locator = opts.locator ---@type  fun(integer, string, integer):integer[]
    local dir = opts.dir ---@type integer
    local ns_buf_map = {}
    for _, win in ipairs(wins) do
        local cur_pos = api.nvim_win_get_cursor(win)
        local buf = api.nvim_win_get_buf(win)
        local ns = win_ns_map[win]
        ns_buf_map[ns] = buf

        api.nvim_win_call(win, function()
            local top = dir == 1 and cur_pos[1] or fn.line("w0")
            local bot = dir == -1 and cur_pos[1] or fn.line("w$")
            for i = top, bot do
                local line = fn.getline(i)
                local cols = locator(i, line, buf)
                -- FARSIGHT: I think this is a version 12 function
                vim.list.unique(cols)
                table.sort(cols, function(a, b)
                    return a < b
                end)

                for _, col in ipairs(cols) do
                    local row_0 = i - 1
                    sights[#sights + 1] = { win, buf, row_0, col, {}, ns, {} }
                end
            end
        end)
    end

    return sights, ns_buf_map
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
            sights[i][5][#sights[i][5] + 1] = tokens[token_idx]
            on_token = on_token - 1
            if on_token == 0 then
                on_token = quotient + (remainder >= 1 and 1 or 0)
                remainder = remainder > 0 and remainder - 1 or remainder

                if i > token_start and #sights[i][5] < max_tokens then
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
        first_counts[sight[5][1]] = first_counts[sight[5][1]] + 1
    end

    for i = 1, #sights do
        local only_token = first_counts[sights[i][5][1]] == 1
        local first_hl_group = only_token and hl_jump_target or hl_jump
        sights[i][7][1] = { sights[i][5][1], first_hl_group }

        local max_display_tokens = (function()
            if i == #sights then
                return math.huge
            end

            -- TODO: Would need to add win check in here too I think
            local same_buf = sights[i][2] == sights[i + 1][2]
            local same_line = same_buf and sights[i][3] == sights[i + 1][3]
            return same_line and (sights[i + 1][4] - sights[i][4]) or math.huge
        end)()

        local total_tokens = math.min(#sights[i][5], max_display_tokens)
        if 2 <= total_tokens then
            local tokens_ahead = table.concat(sights[i][5], "", 2, total_tokens)
            sights[i][7][2] = { tokens_ahead, hl_jump_ahead }
        end
    end
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
---@param sights FarsightSight[]
---@param opts farsight.jump.JumpOpts
---@return nil
local function advance_jump(ns_buf_map, sights, opts)
    while true do
        populate_sight_labels(sights, opts)
        populate_virt_text(sights, opts.tokens)

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

        if not vim.list_contains(opts.tokens, input) then
            return
        end

        local new_sights = {} ---@type FarsightSight[]
        for _, sight in ipairs(sights) do
            if sight[5][1] == input then
                new_sights[#new_sights + 1] = sight
            end
        end

        sights = new_sights
        if #sights == 1 then
            do_jump(sights[1][1], sights[1][3] + 1, sights[1][4], opts)
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

    opts.locator = opts.locator or scope_cwords
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
---@field locator? fun(integer, string, integer):integer[]
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

-- LOW: Would be interesting to test storing the labels as a struct of arrays

-- DOCUMENT: A couple example spotter functions
