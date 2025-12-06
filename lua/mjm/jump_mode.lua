-- Bespoke version of https://github.com/nvim-mini/mini.jump2d

-- LOW: https://github.com/easymotion/vim-easymotion - Worth looking at. The actual plugin should
-- not be used because it overwrites buffer contents, but it has more motions than the basic
-- symbol jump
-- LOW: Also look more at amp text editor. From what I understand, Helix's gW cmd is based on it

-- TODO: Map in x mode, but for only one window
-- TODO: Apply the omode mapping
-- Use `<Cmd>...<CR>` to have proper dot-repeat
-- See https://github.com/neovim/neovim/issues/23406
-- TODO: use local functions if/when that issue is resolved
-- H.map("o", keymap, "<Cmd>lua MiniJump2d.start()<CR>", { desc = "Start 2d jumping" })

local api = vim.api
local fn = vim.fn

vim.api.nvim_set_hl(0, "MiniJump2dSpot", { reverse = true })
vim.api.nvim_set_hl(0, "MiniJump2dSpotAhead", { reverse = true })
-- TODO: I have no idea what this is for
vim.api.nvim_set_hl(0, "MiniJump2dSpotUnique", { reverse = true })

-- Per mini.jump2d, while nvim_tabpage_list_wins does currently ensure proper window layout, this
-- is not documented behavior and thus can change. The below function ensures layout
-- TODO: Explore putting this in Rancher
---@param tabpage integer
---@return integer[]
local function tabpage_list_wins_ordered(tabpage)
    local wins = vim.api.nvim_tabpage_list_wins(tabpage) ---@type integer[]
    -- LOW: Is there a better way to do this? You could put this information with the winids in
    -- one table, but then you have to re-extract the winids to return. This involves hash lookups
    -- but at least doesn't involve a a ton more ops and doesn't add time complexity
    local wins_pos = {} ---@type { [1]:integer, [2]:integer, [3]:integer }[]
    for _, win in ipairs(wins) do
        local pos = vim.api.nvim_win_get_position(win) ---@type { [1]:integer, [2]:integer }
        local config = vim.api.nvim_win_get_config(win) ---@type vim.api.keyset.win_config_ret
        wins_pos[win] = { pos[1], pos[2], config.zindex or 0 }
    end

    table.sort(wins, function(a, b)
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

    return wins
end

---@param all_wins boolean
---@return integer[]
local function get_jump_wins(all_wins)
    if all_wins then
        return tabpage_list_wins_ordered(0)
    else
        local cur_win = api.nvim_get_current_win()
        return { cur_win }
    end
end

local H = {}
local jump = {}

jump.builtin_opts = {}
jump.gen_spotter = {}

-- TODO: Build this down to just handle the word start case. There's not anything else I want at
-- the moment, and with other customizations I have more interested in, I want to turn down other
-- noise
--- Generate spotter for Vimscript pattern
---
---@param pattern string|nil Vimscript |pattern|. Default: `\k\+` to match group
---   of "keyword characters" (see 'iskeyword').
---
---@return function Spotter function.
jump.gen_spotter.vimpattern = function(pattern)
    pattern = pattern or "\\k\\+"
    if type(pattern) ~= "string" then
        error("foobar")
    end

    local r = vim.regex(pattern)
    local is_anchored = pattern:sub(1, 1) == "^" or pattern:sub(-1, -1) == "$"

    return function(line_num, _)
        local res, l, start = {}, vim.fn.getline(line_num), 1
        local n = is_anchored and 1 or (l:len() + 1)
        for _ = 1, n do
            local from, to = r:match_str(l)
            if from == nil then
                break
            end

            table.insert(res, from + start)
            l, start = l:sub(to + 1), start + to
        end

        return res
    end
end

-- TODO: silly but just go with it for the moment
local spotter = jump.gen_spotter.vimpattern("\\k\\+")

jump.config = {
    allowed_lines = {
        blank = true, -- Blank line (not sent to spotter even if `true`)
        cursor_before = true, -- Lines before cursor line
        cursor_at = true, -- Cursor line
        cursor_after = true, -- Lines after cursor line
        fold = true, -- Start of fold (not sent to spotter even if `true`)
    },
    allowed_windows = {
        current = true,
        not_current = true,
    },
    hooks = {
        before_start = nil, -- Before jump start
        after_jump = nil, -- After jump was actually done
    },
    mappings = {
        start_jumping = "<CR>",
    },
    silent = false,
}

-- TODO: The way this should work is, the keymaps should be in map.lua or something, and the
-- module should not be eager required. That way, data setups like this can happen lazily
local tokens = vim.split("abcdefghijklmnopqrstuvwxyz", "")

---@param all_wins boolean
local function get_spots(all_wins)
    local wins = get_jump_wins(all_wins) ---@type integer[]
    local spots = {}

    local function spot_find_in_line(lnum)
        local folded = fn.foldclosed(lnum)
        if folded ~= -1 then
            return {}
        end

        local prevnonblank = fn.prevnonblank(lnum)
        if prevnonblank ~= lnum then
            return {}
        end

        return spotter(lnum)
    end

    for _, win in ipairs(wins) do
        api.nvim_win_call(win, function()
            local buf = api.nvim_win_get_buf(win) ---@type integer
            local top = fn.line("w0") ---@type integer
            local bot = fn.line("w$") ---@type integer
            for i = top, bot do
                local cols = spot_find_in_line(i)
                for _, col in ipairs(cols) do
                    table.insert(spots, { line = i, column = col, buf_id = buf, win_id = win })
                end
            end
        end)
    end

    return spots
end

---@param opts table|nil
jump.start = function(all_wins, opts)
    opts = opts or {}

    opts.hl_group = opts.hl_group or "MiniJump2dSpot"
    opts.hl_group_ahead = opts.hl_group_ahead or "MiniJump2dSpotAhead"
    opts.hl_group_unique = opts.hl_group_unique or "MiniJump2dSpotUnique"

    local spots = get_spots(all_wins)
    if #spots == 0 then
        api.nvim_echo({ { "No words to jump to" } }, false, {})
        return
    end

    if #spots == 1 then
        H.perform_jump(spots[1].win_id, spots[1].line, spots[1].column)
        return
    end

    spots = H.spots_add_tokens(spots)

    H.spots_show(spots, opts)

    H.cache.spots = spots

    H.advance_jump(opts)
end

--- Stop jumping
jump.stop = function()
    H.spots_unshow()
    H.cache.spots = nil
    vim.cmd("redraw")

    if H.cache.is_in_getcharstr then
        vim.api.nvim_input("<C-c>")
    end
end

-- TODO: outline the ns to a local
H.ns_id = {
    spots = vim.api.nvim_create_namespace("MiniJump2dSpots"),
}

H.cache = {
    spots = nil,
    is_in_getcharstr = false,
}

H.keys = {
    esc = vim.api.nvim_replace_termcodes("<Esc>", true, true, true),
    cr = vim.api.nvim_replace_termcodes("<CR>", true, true, true),
    block_operator_pending = vim.api.nvim_replace_termcodes("no<C-V>", true, true, true),
}

H.spots_add_tokens = function(spots)
    local labels = {}
    for _ = 1, #spots do
        labels[#labels + 1] = {}
    end

    H.populate_labels(labels, 1)
    for i, spot in ipairs(spots) do
        spot.label = labels[i]
    end

    return spots
end

---@param labels table
---@return nil
---@private
H.populate_labels = function(labels, step)
    if #labels <= 1 or 1 < step then
        return
    end

    local base = math.floor(#labels / #tokens)
    local extra = #labels % #tokens

    local token_idx = 1
    -- I'm guessing this is like part of how it segments down the sub tokens or something
    local cur_label_tokens = {}
    local label_max_count = base + (token_idx <= extra and 1 or 0)
    for _, label in ipairs(labels) do
        table.insert(label, tokens[token_idx])
        table.insert(cur_label_tokens, label)

        if #cur_label_tokens >= label_max_count then
            -- TODO: Wait until we know this works, but then remove the recursion
            H.populate_labels(cur_label_tokens, step + 1)
            token_idx = token_idx + 1
            cur_label_tokens = {}
            -- TODO: I don't know what this actually means yet
            local label_id_lteq_extra = token_idx <= extra
            -- TODO: Same thing - I don't know what this means
            local one_or_zero = label_id_lteq_extra and 1 or 0
            label_max_count = base + one_or_zero
        end
    end
end

H.spots_show = function(spots, opts)
    spots = spots or H.cache.spots or {}

    local set_extmark = vim.api.nvim_buf_set_extmark

    for _, extmark in ipairs(H.spots_to_extmarks(spots, opts)) do
        local extmark_opts = {
            hl_mode = "combine",
            -- Use very high priority
            priority = 1000,
            virt_text = extmark.virt_text,
            virt_text_pos = "overlay",
        }
        local buf_id, line = extmark.buf_id, extmark.line
        -- TODO: Semi-weird to me that this would be pcalled
        pcall(set_extmark, buf_id, H.ns_id.spots, line, extmark.col, extmark_opts)
    end

    api.nvim_cmd({ cmd = "redraw" }, {})
end

H.spots_unshow = function(spots)
    spots = spots or H.cache.spots or {}

    local buf_ids = {}
    for _, s in ipairs(spots) do
        buf_ids[s.buf_id] = true
    end

    for _, buf_id in ipairs(vim.tbl_keys(buf_ids)) do
        pcall(vim.api.nvim_buf_clear_namespace, buf_id, H.ns_id.spots, 0, -1)
    end
end

H.spots_to_extmarks = function(spots, opts)
    if #spots == 0 then
        return {}
    end

    local hl_group, hl_group_ahead, hl_group_unique =
        opts.hl_group, opts.hl_group_ahead, opts.hl_group_unique

    -- Compute counts for first step in order to distinguish which highlight
    -- group to use: `hl_group` or `hl_group_unique`
    local first_step_counts = {}
    for _, s in ipairs(spots) do
        local cur_first_step = s.steps[1]
        local cur_count = first_step_counts[cur_first_step] or 0
        first_step_counts[cur_first_step] = cur_count + 1
    end

    -- Define how steps for single spot are added to virtual text
    local append_to_virt_text = function(virt_text_arr, steps, n_steps_to_show)
        -- Use special group if current first step is unique
        local first_hl_group = first_step_counts[steps[1]] == 1 and hl_group_unique or hl_group
        table.insert(virt_text_arr, { steps[1], first_hl_group })

        -- Add ahead steps only if they are present
        local ahead_label = table.concat(steps):sub(2, n_steps_to_show)
        if ahead_label ~= "" then
            table.insert(virt_text_arr, { ahead_label, hl_group_ahead })
        end
    end

    -- Convert all spots to array of extmarks
    local res = {}
    local buf_id, line, col, virt_text =
        spots[1].buf_id, spots[1].line - 1, spots[1].column - 1, {}

    for i = 1, #spots - 1 do
        local cur_spot, next_spot = spots[i], spots[i + 1]
        local n_steps = #cur_spot.steps

        -- Find which spot steps can be shown
        local is_in_same_line = cur_spot.buf_id == next_spot.buf_id
            and cur_spot.line == next_spot.line
        local max_allowed_steps = is_in_same_line and (next_spot.column - cur_spot.column)
            or math.huge
        local n_steps_to_show = math.min(n_steps, max_allowed_steps)

        -- Add text for shown steps
        append_to_virt_text(virt_text, cur_spot.steps, n_steps_to_show)

        -- Finish creating extmark if next spot is far enough
        local next_is_close = is_in_same_line and n_steps == max_allowed_steps
        if not next_is_close then
            table.insert(res, { buf_id = buf_id, line = line, col = col, virt_text = virt_text })
            buf_id, line, col, virt_text =
                next_spot.buf_id, next_spot.line - 1, next_spot.column - 1, {}
        end
    end

    local last_steps = spots[#spots].steps
    append_to_virt_text(virt_text, last_steps, #last_steps)
    table.insert(res, { buf_id = buf_id, line = line, col = col, virt_text = virt_text })

    return res
end

H.advance_jump = function(opts)
    local spots = H.cache.spots

    if type(spots) ~= "table" or #spots < 1 then
        H.spots_unshow(spots)
        H.cache.spots = nil
        return
    end

    -- TODO: Unsure why pcalled
    local _, key = pcall(vim.fn.getchar)

    if vim.tbl_contains(tokens, key) then
        H.spots_unshow(spots)
        spots = vim.tbl_filter(function(x)
            return x.steps[1] == key
        end, spots)

        if #spots > 1 then
            spots = H.spots_add_tokens(spots)
            H.spots_show(spots, opts)
            H.cache.spots = spots

            -- TODO: Must this be recursion?
            H.advance_jump(opts)
        end
    end

    if #spots == 1 or key == H.keys.cr then
        H.perform_jump(spots[1].win_id, spots[1].line, spots[1].column)
    end

    jump.stop()
end

-- TODO: localize
function H.perform_jump(win, row, col)
    api.nvim_cmd({ cmd = "norm", args = { "m`" }, bang = true }, {})
    vim.api.nvim_set_current_win(win)
    vim.api.nvim_win_set_cursor(win, { row, col })
    api.nvim_cmd({ cmd = "norm", args = { "zv" }, bang = true }, {})
end

return jump
