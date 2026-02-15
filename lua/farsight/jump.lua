local api = vim.api
local fn = vim.fn
local foldclosed = fn.foldclosed
local str_find = string.find

---@class farsight.jump.Target
---@field [1] integer Window ID
---@field [2] integer Buffer ID
---@field [3] integer Zero indexed row |api-indexing|
---@field [4] integer Zero index col, inclusive for extmarks |api-indexing|
---@field [5] string[] Label
---@field [6] integer Extmark namespace
---@field [7] [string,string|integer][] Extmark virtual text

local MAX_TOKENS = 2
local TOKENS = vim.split("abcdefghijklmnopqrstuvwxyz", "")

-- TODO: Document these HL groups
local HL_JUMP_STR = "FarsightJump"
local HL_JUMP_AHEAD_STR = "FarsightJumpAhead"
local HL_JUMP_TARGET_STR = "FarsightJumpTarget"
local HL_JUMP_DIM_STR = "FarsightJumpDim"

local nvim_set_hl = api.nvim_set_hl
nvim_set_hl(0, HL_JUMP_STR, { default = true, link = "DiffChange" })
nvim_set_hl(0, HL_JUMP_AHEAD_STR, { default = true, link = "DiffText" })
nvim_set_hl(0, HL_JUMP_TARGET_STR, { default = true, link = "DiffAdd" })
nvim_set_hl(0, HL_JUMP_DIM_STR, { default = true, link = "Comment" })

local nvim_get_hl_id_by_name = api.nvim_get_hl_id_by_name
local hl_jump = nvim_get_hl_id_by_name(HL_JUMP_STR)
local hl_jump_ahead = nvim_get_hl_id_by_name(HL_JUMP_AHEAD_STR)
local hl_jump_target = nvim_get_hl_id_by_name(HL_JUMP_TARGET_STR)
local hl_jump_dim = nvim_get_hl_id_by_name(HL_JUMP_DIM_STR)

local namespaces = { api.nvim_create_namespace("") } ---@type integer[]

-- MID: Profile regex:match_str() against regex:match_line()
local vim_regex = vim.regex
local cword_regex = vim_regex("\\k\\+")

---@param line string
---@return boolean
local function is_blank(line)
    return str_find(line, "[^\\0-\\32\\127]") == nil
end

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
    if is_blank(line) then
        return {}
    end

    local fold_row = foldclosed(row)
    if fold_row ~= -1 then
        return fold_row == row and { 0 } or {}
    end

    local cols = {} ---@type integer[]
    local start = 1
    local sub = string.sub

    -- Unlike for csearch, the string sub method works best here
    while true do
        local from, to = cword_regex:match_str(line)
        if from == nil or to == nil then
            break
        end

        cols[#cols + 1] = from + start - 1
        line = sub(line, to + 1)
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
    if is_blank(line) then
        return {}
    end

    local fold_row = foldclosed(row)
    if fold_row ~= -1 then
        return fold_row == row and { 0 } or {}
    end

    local cols = {} ---@type integer[]
    local start = 1
    local cur_row = cur_pos[1]
    local cur_col = cur_pos[2]
    local sub = string.sub

    while true do
        local from, to = cword_regex:match_str(line)
        if from == nil or to == nil then
            break
        end

        if row > cur_row then
            cols[#cols + 1] = to + start - 2
        elseif row == cur_row then
            cols[#cols + 1] = start - 2 > cur_col and to + start - 2 or from + start - 1
        else
            cols[#cols + 1] = from + start - 1
        end

        line = sub(line, to + 1)
        start = start + to
    end

    return cols
end

---@param jump_win integer
---@param buf integer
---@param row_0 integer
---@param col integer
---@param map_mode "n"|"v"|"o"|"l"|"t"|"x"|"s"|"i"|"c"
---@param opts farsight.jump.JumpOpts
---@return nil
local function do_jump(jump_win, buf, row_0, col, map_mode, opts)
    local cur_win = api.nvim_get_current_win()
    local cur_pos = api.nvim_win_get_cursor(cur_win)
    local jump_pos = { row_0 + 1, col }

    ---@type farsight._common.DoJumpOpts
    local jump_opts = { on_jump = opts.on_jump, keepjumps = opts.keepjumps }
    local common = require("farsight._common")
    common._do_jump(cur_win, jump_win, buf, map_mode, cur_pos, jump_pos, jump_opts)
end

---Edits targets in place
---@param targets farsight.jump.Target[]
local function clear_target_virt_text(targets)
    for _, target in ipairs(targets) do
        local virt_text = target[7]
        -- Because the virt text tables tend to have a small number of items, this is faster than
        -- overwriting them with new table allocations
        local len = #virt_text
        for i = len, 1, -1 do
            virt_text[i] = nil
        end
    end
end

---@param ns_buf_map table<integer, integer>
---@param targets farsight.jump.Target[]
---@return table<integer, integer>
local function filter_ns_buf_map(ns_buf_map, targets)
    local bk1 = next(ns_buf_map)
    local bk2 = next(ns_buf_map, bk1)
    if bk2 == nil then
        return ns_buf_map
    end

    local new_ns_buf_map = {} ---@type table<integer, integer>
    for _, target in ipairs(targets) do
        new_ns_buf_map[target[6]] = target[2]
    end

    return new_ns_buf_map
end

-- Trivial perf cost in comparison to the redraws it saves

---Edits redraws in place
---@param redraws vim.api.keyset.redraw[]
---@param targets farsight.jump.Target[]
local function filter_redraws(redraws, targets)
    if #redraws <= 1 then
        return
    end

    local targeted_wins = {} ---@type table<integer, boolean>
    for _, target in ipairs(targets) do
        targeted_wins[target[1]] = true
    end

    require("farsight.util")._list_filter(redraws, function(opt)
        return targeted_wins[opt.win]
    end)
end

-- Redrawing per window improves perf on average because:
-- - If not all wins have to be redrawn, then redrawing all, even with valid = true, is
-- non-trivially slower.
-- - If a win has to be redrawn with valid = false, we avoid having to apply that setting to all
-- windows

---@param redraw_opts vim.api.keyset.redraw[]
local function do_redraws(redraw_opts)
    local nvim__redraw = api.nvim__redraw
    for _, opt in pairs(redraw_opts) do
        nvim__redraw(opt)
    end
end

---@param targets farsight.jump.Target[]
---@param ns_buf_map table<integer, integer>
local function dim_target_lines(targets, ns_buf_map)
    local ns_rows = {}
    for _, target in ipairs(targets) do
        local ns = target[6]
        local lines = ns_rows[ns] or {}
        lines[target[3]] = true
        ns_rows[ns] = lines
    end

    local dim_extmark_opts = {
        end_col = 0,
        hl_eol = true,
        hl_group = hl_jump_dim,
        priority = 999,
    }

    local nvim_buf_set_extmark = api.nvim_buf_set_extmark
    for ns, buf in pairs(ns_buf_map) do
        for row, _ in pairs(ns_rows[ns]) do
            dim_extmark_opts.end_line = row + 1
            pcall(nvim_buf_set_extmark, buf, ns, row, 0, dim_extmark_opts)
        end
    end
end

---@param targets farsight.jump.Target[]
local function set_label_extmarks(targets)
    ---@type vim.api.keyset.set_extmark
    local extmark_opts = {
        hl_mode = "combine",
        priority = 1000,
        virt_text_pos = "overlay",
    }

    local nvim_buf_set_extmark = api.nvim_buf_set_extmark
    for _, target in ipairs(targets) do
        extmark_opts.virt_text = target[7]
        pcall(nvim_buf_set_extmark, target[2], target[6], target[3], target[4], extmark_opts)
    end
end

-- LOW: Profile this function to see if it could be optimized further

---Edits targets in place
---@param targets farsight.jump.Target[]
---@param max_tokens integer
---@param jump_level integer
local function populate_target_virt_text_max_tokens(targets, max_tokens, jump_level)
    local len_targets = #targets
    if len_targets < 1 then
        return
    end

    local start = 1 + jump_level
    local start_plus_one = start + 1
    local concat = table.concat

    ---@param target farsight.jump.Target
    ---@param max_display_tokens integer
    local function add_virt_text(target, max_display_tokens)
        local label = target[5]
        local virt_text = target[7]
        local len_full_label = #label
        local len_label = len_full_label - jump_level

        -- Unlike the max_2 case, early exiting here doesn't seem to negatively affect performance
        if len_label == 1 then
            virt_text[1] = { label[start], hl_jump_target }
            return
        end

        virt_text[1] = { label[start], hl_jump }
        if len_label <= max_display_tokens then
            if len_full_label > 2 then
                local before = concat(label, "", start_plus_one, len_full_label - 1)
                virt_text[2] = { before, hl_jump_ahead }
            end

            virt_text[#virt_text + 1] = { label[len_full_label], hl_jump_target }
        else
            local remainder = #label > 2 and concat(label, "", start_plus_one, max_display_tokens)
                or label[start_plus_one]
            virt_text[2] = { remainder, hl_jump_ahead }
        end
    end

    local max_idx = len_targets - 1
    local next_target = targets[1]
    local min = math.min
    for i = 1, max_idx do
        local target = next_target
        next_target = targets[i + 1]

        local max_display_tokens = (
            target[1] ~= next_target[1]
            or target[2] ~= next_target[2]
            or target[3] ~= next_target[3]
        )
                and max_tokens
            or min(next_target[4] - target[4], max_tokens)

        add_virt_text(targets[i], max_display_tokens)
    end

    add_virt_text(next_target, max_tokens)
end

---Edits targets in place
---@param targets farsight.jump.Target[]
---@param jump_level integer
local function populate_target_virt_text_max_2(targets, jump_level)
    local len_targets = #targets
    if len_targets < 1 then
        return
    end

    local start = 1 + jump_level
    local start_plus_one = start + 1

    ---@param target farsight.jump.Target
    ---@param max_display_tokens integer
    local function add_virt_text(target, max_display_tokens)
        local label = target[5]
        local virt_text = target[7]
        local len_label = #label - jump_level
        local has_more_tokens = len_label > 1
        local start_hl = has_more_tokens and hl_jump or hl_jump_target
        virt_text[1] = { label[start], start_hl }

        -- This seems to be faster than early returning if len == 1
        if has_more_tokens and max_display_tokens == 2 then
            local next_hl = len_label == 2 and hl_jump_target or hl_jump_ahead
            virt_text[2] = { label[start_plus_one], next_hl }
        end
    end

    local max_idx = len_targets - 1
    local next_target = targets[1]
    for i = 1, max_idx do
        local target = next_target
        next_target = targets[i + 1]

        local max_display_tokens = (
            target[1] ~= next_target[1]
            or target[2] ~= next_target[2]
            or target[3] ~= next_target[3]
            or next_target[4] - target[4] >= 2
        )
                and 2
            or 1

        add_virt_text(target, max_display_tokens)
    end

    add_virt_text(next_target, 2)
end

---Edits targets in place
---@param targets farsight.jump.Target[]
---@param jump_level integer
local function populate_target_virt_text_max_1(targets, jump_level)
    local start = 1 + jump_level
    for _, target in ipairs(targets) do
        local label = target[5]
        local hl = #label - jump_level > 1 and hl_jump or hl_jump_target
        target[7][1] = { label[start], hl }
    end
end
---Edits targets in place
---@param targets farsight.jump.Target[]
---@param max_tokens integer
---@param jump_level integer
local function populate_target_virt_text(targets, jump_level, max_tokens)
    if max_tokens == 1 then
        populate_target_virt_text_max_1(targets, jump_level)
    elseif max_tokens == 2 then
        populate_target_virt_text_max_2(targets, jump_level)
    else
        populate_target_virt_text_max_tokens(targets, max_tokens, jump_level)
    end
end

---Edits ns_buf_map, targets, and redraws in place
---@param ns_buf_map table<integer, integer>
---@param targets farsight.jump.Target[]
---@param map_mode "n"|"v"|"o"|"l"|"t"|"x"|"s"|"i"|"c"
---@param redraws vim.api.keyset.redraw[]
---@param opts farsight.jump.JumpOpts
---@return nil
local function advance_jump(ns_buf_map, targets, map_mode, redraws, opts)
    local dim = opts.dim
    local jump_level = 0
    local list_filter = require("farsight.util")._list_filter
    local max_tokens = opts.max_tokens ---@type integer

    while true do
        populate_target_virt_text(targets, jump_level, max_tokens)
        set_label_extmarks(targets)
        if dim then
            dim_target_lines(targets, ns_buf_map)
        end

        do_redraws(redraws)
        local _, input = pcall(fn.getcharstr)

        local nvim_buf_clear_namespace = api.nvim_buf_clear_namespace
        for ns, buf in pairs(ns_buf_map) do
            pcall(nvim_buf_clear_namespace, buf, ns, 0, -1)
        end

        -- Adjust before filtering targets so that labels in all previous windows are cleared
        -- Accordingly, no windows need to be filtered at the first jump level
        if jump_level > 0 then
            filter_redraws(redraws, targets)
        end

        local start = jump_level + 1
        list_filter(targets, function(target)
            return target[5][start] == input
        end)

        local targets_len = #targets
        if targets_len <= 1 then
            -- TODO: I believe in this case I only need to redraw wins where valid is false, so
            -- this function should be able to take an opt to do that
            do_redraws(redraws)
            if targets_len == 1 then
                local target = targets[1]
                do_jump(target[1], target[2], target[3], target[4], map_mode, opts)
            end

            return
        end

        ns_buf_map = filter_ns_buf_map(ns_buf_map, targets)
        clear_target_virt_text(targets)
        jump_level = jump_level + 1
    end
end

-- MID: The variable names in this function could be more clear
-- LOW: In theory, there should be some way to optimize this by pre-computing and pre-allocating
-- the label lengths rather than doing multiple appends/resizes

---Edits targets in place
---@param targets farsight.jump.Target[]
---@param tokens string[]
---@return nil
local function populate_target_labels(targets, tokens)
    local len_targets = #targets
    if len_targets <= 1 then
        return
    end

    local queue = {} ---@type { [1]: integer, [2]:integer }[]
    queue[#queue + 1] = { 1, len_targets }

    local floor = math.floor
    local list_remove = require("farsight.util")._list_remove_item
    local len_tokens = #tokens
    while #queue > 0 do
        local range = queue[1]
        local range_start = range[1]
        local range_end = range[2]
        list_remove(queue, 1)
        local len_range = range_end - range_start + 1

        local quotient = floor(len_range / len_tokens)
        local remainder = len_range % len_tokens
        local rem_tokens = quotient + (remainder >= 1 and 1 or 0)
        remainder = remainder > 0 and remainder - 1 or remainder

        local token_idx = 1
        local token_start = range_start

        local idx = range_start - 1
        while idx < range_end do
            local token = tokens[token_idx]
            for _ = 1, rem_tokens do
                idx = idx + 1
                local label = targets[idx][5]
                label[#label + 1] = token
            end

            if idx > token_start then
                queue[#queue + 1] = { token_start, idx }
            end

            rem_tokens = quotient + (remainder >= 1 and 1 or 0)
            remainder = remainder > 0 and remainder - 1 or remainder

            token_idx = token_idx + 1
            token_start = idx + 1
        end
    end
end

---Edits targets in place
---@param row integer
---@param cols integer[]
---@param win integer
---@param buf integer
---@param ns integer
---@param targets farsight.jump.Target[]
local function add_cols_to_targets(row, cols, win, buf, ns, targets)
    local row_0 = row - 1
    for _, col in ipairs(cols) do
        targets[#targets + 1] = { win, buf, row_0, col, {}, ns, {} }
    end
end

---Assumes it is called in the window context of win
---@param win integer
---@param row integer
---@param line string
---@param buf integer
---@param cur_pos { [1]: integer, [2]: integer }
---@param locator fun(win: integer, row: integer, line: string, buf: integer,
---cur_pos: { [1]: integer, [2]: integer }):integer[]
local function get_cols(win, row, line, buf, cur_pos, locator)
    local cols = locator(win, row, line, buf, cur_pos)
    require("farsight.util")._list_dedup(cols)
    table.sort(cols, function(a, b)
        return a < b
    end)

    return cols
end

---Assumes it is called in the window context of win
---@param row integer
---@param win integer
---@param buf integer
---@param cur_pos { [1]: integer, [2]: integer }
---@param locator fun(win: integer, row: integer, line: string, buf: integer,
---cur_pos: { [1]: integer, [2]: integer }):integer[]
local function get_extra_wrap_cols(row, win, buf, cur_pos, locator)
    if row >= api.nvim_buf_line_count(buf) then
        return {}
    end

    local first_screenpos = fn.screenpos(win, row, 1)
    if first_screenpos.row < 1 then
        return {}
    end

    local cur_line = fn.getline(row)
    local cols = get_cols(win, row, cur_line, buf, cur_pos, locator)
    if #cols < 1 then
        return {}
    end

    require("farsight.util")._list_filter_end_only(cols, function(col)
        local screenpos = fn.screenpos(win, row, col + 1)
        return screenpos.row > 0
    end)

    return cols
end

-- LOW: Cols covered by extends/precedes listchars are considered on screen and visible per
-- screenpos. Manually calculating/removing these characters feels quite tricky

---Edits cols in place
---@param wrap boolean
---@param cols integer[]
---@param leftcol integer
---@param maxcol integer
local function filter_nowrap_oob(wrap, cols, leftcol, maxcol)
    if wrap then
        return
    end

    local ut = require("farsight.util")
    ut._list_filter_end_only(cols, function(col)
        return col <= maxcol
    end)

    ut._list_filter_beg_only(cols, function(col)
        return col >= leftcol
    end)
end

---Edits targets in place
---Assumes it is called in the window context of win
---@param win integer
---@param cur_pos { [1]: integer, [2]: integer }
---@param buf integer
---@param locator fun(win: integer, row: integer, line: string, buf: integer,
---cur_pos: { [1]: integer, [2]: integer }):integer[]
local function get_cols_before(win, cur_pos, buf, locator)
    local row = cur_pos[1]
    local line = fn.getline(row)
    local ut = require("farsight.util")
    local cur_cword = ut._find_cword_at_col(line, cur_pos[2])
    local end_col_1 = cur_cword and cur_cword[2] or cur_pos[2]

    local line_before = string.sub(line, 1, end_col_1)
    return get_cols(win, row, line_before, buf, cur_pos, locator)
end

---Assumes it is called in the window context of win
---@param win integer
---@param cur_pos { [1]: integer, [2]: integer }
---@param buf integer
---@param locator fun(win: integer, row: integer, line: string, buf: integer,
---cur_pos: { [1]: integer, [2]: integer }):integer[]
local function get_cols_after(win, cur_pos, buf, locator)
    local row = cur_pos[1]
    local line = fn.getline(row)

    local start_col_1 ---@type integer
    local ut = require("farsight.util")
    local cur_cword = ut._find_cword_at_col(line, cur_pos[2])
    if cur_cword then
        start_col_1 = cur_cword[3] + 1
    else
        local charidx = fn.charidx(line, cur_pos[2])
        start_col_1 = fn.byteidx(line, charidx + 1) + 1
    end

    local line_after = string.sub(line, start_col_1, #line)
    local cols = get_cols(win, row, line_after, buf, cur_pos, locator)
    local count_cols = #cols
    for i = 1, count_cols do
        cols[i] = cols[i] + (#line - #line_after)
    end

    return cols
end

---Assumes it is called in the window context of the relevant win
---@param dir -1|0|1
---@return integer, integer, integer
local function get_top_bot(dir, cur_pos)
    local wS = fn.line("w$")
    if dir == 1 then
        -- Add one because the cursor line will be handled separately
        return math.min(cur_pos[1] + 1, wS), wS, wS
    elseif dir == -1 then
        local w0 = fn.line("w0")
        -- Subtract one because the cursor line will be handled separately
        return w0, math.max(cur_pos[1] - 1, w0), wS
    else
        local line = fn.line
        return line("w0"), wS, wS
    end
end

---@param win integer
---@param configs table<integer, vim.api.keyset.win_config_ret>
---@return boolean, integer, integer
local function get_wrap_info(win, configs)
    local wrap = api.nvim_get_option_value("wrap", { win = win }) ---@type boolean
    if wrap then
        return true, -1, -1
    end

    local wininfo = fn.getwininfo(win)[1]
    -- FUTURE: https://github.com/neovim/neovim/pull/37840
    ---@diagnostic disable-next-line: undefined-field
    local leftcol = wininfo.leftcol ---@type integer
    local width = configs[win].width
    local maxcol = math.max(width - wininfo.textoff - 1 + leftcol, 0)

    return wrap, leftcol, maxcol
end

---@param wins integer[]
local function add_missing_ns(wins)
    local wins_len = #wins
    local missing_ns = wins_len - #namespaces
    for _ = 1, missing_ns do
        namespaces[#namespaces + 1] = api.nvim_create_namespace("")
    end
end

---@param wins integer[]
---@param configs table<integer, vim.api.keyset.win_config_ret>
---@param opts farsight.jump.JumpOpts
---@return farsight.jump.Target[], table<integer, integer>, vim.api.keyset.redraw[]
local function get_targets(wins, configs, opts)
    add_missing_ns(wins)

    local targets = {} ---@type farsight.jump.Target[]
    local ns_buf_map = {} ---@type table<integer, integer>
    local redraws = {} ---@type vim.api.keyset.redraw[]

    local dir = opts.dir ---@type integer
    ---@type fun(row: integer, line: string, buf: integer,
    ---cur_pos: { [1]: integer, [2]: integer }):integer[]
    local locator = opts.locator
    local nvim_win_call = api.nvim_win_call
    local nvim_win_get_buf = api.nvim_win_get_buf
    local nvim_win_get_cursor = api.nvim_win_get_cursor
    local nvim__ns_set = api.nvim__ns_set

    local wins_len = #wins
    for i = 1, wins_len do
        local win = wins[i]

        local buf = nvim_win_get_buf(win)
        -- Always get/send so it's available for user functions
        local cur_pos = nvim_win_get_cursor(win)
        local ns = namespaces[i]
        nvim__ns_set(ns, { wins = { win } })
        ns_buf_map[ns] = buf
        redraws[#redraws + 1] = { win = win, valid = true }
        local wrap, leftcol, maxcol = get_wrap_info(win, configs)

        nvim_win_call(win, function()
            local top, bot, wS = get_top_bot(dir, cur_pos)

            if dir == 1 then
                local cols = get_cols_after(win, cur_pos, buf, locator)
                filter_nowrap_oob(wrap, cols, leftcol, maxcol)
                add_cols_to_targets(cur_pos[1], cols, win, buf, ns, targets)
            end

            for j = top, bot do
                local cur_line = fn.getline(j)
                local cols = get_cols(win, j, cur_line, buf, cur_pos, locator)
                filter_nowrap_oob(wrap, cols, leftcol, maxcol)
                add_cols_to_targets(j, cols, win, buf, ns, targets)
            end

            -- LOW: From what I can tell, Nvim will not allow the cursor to be in a bottom, not
            -- fully visible row in a wrap window, so that edge case does not need to be handled.
            -- Could investigate further though
            if dir == -1 then
                local cols = get_cols_before(win, cur_pos, buf, locator)
                filter_nowrap_oob(wrap, cols, leftcol, maxcol)
                add_cols_to_targets(cur_pos[1], cols, win, buf, ns, targets)
            end

            if wrap and bot == wS and dir >= 0 then
                local row = bot + 1
                local cols = get_extra_wrap_cols(row, win, buf, cur_pos, locator)
                if #cols > 0 then
                    add_cols_to_targets(row, cols, win, buf, ns, targets)
                    redraws[#redraws]["valid"] = false
                end
            end
        end)
    end

    return targets, ns_buf_map, redraws
end

---Edits opts in place
---@param opts farsight.jump.JumpOpts
---@param map_mode "n"|"v"|"o"|"l"|"t"|"x"|"s"|"i"|"c"
local function resolve_wins(opts, map_mode)
    if opts.wins == nil then
        if map_mode == "v" or map_mode == "o" then
            opts.wins = { api.nvim_get_current_win() }
        else
            opts.wins = api.nvim_tabpage_list_wins(0)
        end

        return
    end

    -- LOW: Alternatively, other tabpages could work so long as all windows belonged to the same
    -- one. Could delay the switch until we know we have at least one target
    local tabpage = api.nvim_get_current_tabpage()
    require("farsight.util")._validate_list(opts.wins, {
        item_type = "number",
        min_len = 1,
        func = function(win)
            if api.nvim_win_get_tabpage(win) == tabpage then
                return true
            else
                local msg = "Window " .. win .. " is not in the current tabpage"
                return false, msg
            end
        end,
    })
end

---Edits opts in place
---@param opts farsight.jump.JumpOpts
---@param cur_buf integer
local function resolve_on_jump(opts, cur_buf)
    local ut = require("farsight.util")
    opts.on_jump = ut._use_gb_if_nil(opts.on_jump, "farsight_on_jump", cur_buf)
    if opts.on_jump == nil then
        opts.on_jump = function(_, _, _)
            api.nvim_cmd({ cmd = "norm", args = { "zv" }, bang = true }, {})
        end

        return
    end

    vim.validate("opts.on_jump", opts.on_jump, "callable")
end

---Edits opts in place
---@param opts farsight.jump.JumpOpts
---@param map_mode "n"|"v"|"o"|"l"|"t"|"x"|"s"|"i"|"c"
local function resolve_locator(opts, cur_buf, map_mode)
    local ut = require("farsight.util")
    opts.locator = ut._use_gb_if_nil(opts.locator, "farsight_jump_locator", cur_buf)
    if opts.locator == nil then
        if map_mode == "v" or map_mode == "o" then
            opts.locator = locate_cwords_with_cur_pos
        else
            opts.locator = locate_cwords
        end

        return
    end

    vim.validate("opts.locator", opts.locator, "callable")
end

-- TODO: In the docs, mention g/b:vars when relevant. Don't waste time mentioning when they are
-- missing

---Edits opts in place
---@param opts farsight.jump.JumpOpts
---@param map_mode "n"|"v"|"o"|"l"|"t"|"x"|"s"|"i"|"c"
local function resolve_jump_opts(opts, map_mode)
    vim.validate("opts", opts, "table")
    local ut = require("farsight.util")
    local cur_buf = api.nvim_get_current_buf()

    opts.dim = ut._use_gb_if_nil(opts.dim, "farsight_dim", cur_buf)
    opts.dim = ut._resolve_bool_opt(opts.dim, false)

    if opts.dir == nil then
        opts.dir = 0
    else
        local dir = opts.dir
        vim.validate("opts.dir", dir, function()
            return dir == -1 or dir == 0 or dir == 1
        end, "Dir must be -1, 0, or 1")
    end

    opts.keepjumps = ut._use_gb_if_nil(opts.keepjumps, "farsight_jump_keepjumps", cur_buf)
    opts.keepjumps = ut._resolve_bool_opt(opts.keepjumps, false)

    resolve_locator(opts, cur_buf, map_mode)

    opts.max_tokens = ut._use_gb_if_nil(opts.max_tokens, "farsight_jump_max_tokens", cur_buf)
    opts.max_tokens = opts.max_tokens or MAX_TOKENS
    local max_tokens = opts.max_tokens
    vim.validate("opts.max_tokens", max_tokens, function()
        if max_tokens % 1 ~= 0 then
            return false
        end

        return max_tokens > 0
    end, "max_tokens must be a uint greater than zero")

    resolve_on_jump(opts, cur_buf)

    opts.tokens = ut._use_gb_if_nil(opts.tokens, "farsight_jump_tokens", cur_buf)
    opts.tokens = opts.tokens or TOKENS
    vim.validate("opts.tokens", opts.tokens, "table")
    ut._list_dedup(opts.tokens)
    ut._validate_list(opts.tokens, { item_type = "string", min_len = 2 })

    resolve_wins(opts, map_mode)
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
---@field dim? boolean
---@field dir? integer
---@field keepjumps? boolean
---@field locator? fun(win: integer, row: integer, line: string, buf: integer,
---cur_pos: { [1]: integer, [2]: integer }):integer[]
---@field max_tokens? integer
---@field on_jump? fun(win: integer, buf: integer, jump_pos: { [1]:integer, [2]: integer })
---@field tokens? string[]
---@field wins? integer[]

---@param opts farsight.jump.JumpOpts?
function Jump.jump(opts)
    opts = opts and vim.deepcopy(opts, true) or {}
    local ut = require("farsight.util")
    local map_mode = ut._resolve_map_mode(api.nvim_get_mode().mode)
    resolve_jump_opts(opts, map_mode)

    local wins, configs = ut._order_focusable_wins(opts.wins)
    if #wins < 1 then
        api.nvim_echo({ { "No focusable wins provided" } }, false, {})
        return
    end

    local targets, ns_buf_map, redraws = get_targets(wins, configs, opts)
    if #targets > 1 then
        populate_target_labels(targets, opts.tokens)
        advance_jump(ns_buf_map, targets, map_mode, redraws, opts)
    elseif #targets == 1 then
        local target = targets[1]
        do_jump(target[1], target[2], target[3], target[4], map_mode, opts)
    else
        api.nvim_echo({ { "No targets available" } }, false, {})
    end
end

---@return integer[]
function Jump.get_hl_ns()
    return vim.deepcopy(namespaces, true)
end

return Jump

-- TODO: Defaults should respect fdo 'jump' and 'all' flags
-- TODO: Document a couple locator examples:
-- - CWORD
-- - Sneak style
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
-- TODO: WHen doing default mappings, can the unique flag be used rather than maparg to check if
-- it's already been mapped?
-- TODO: Document that backup csearch jumps do not set charsearch
-- TODO: all_wins needs to be determined within the function body rather than being explicitly
-- passed in the plug map, this way gbvars can alter it

-- EasyMotion notes:
-- - EasyMotion replaces a lot of things, like w and f/t
-- - Provides a version of search where after entering the term, labels are then shown on the
-- search results
-- Flash notes:
-- - The enhanced search is neat, but my experience with it was that it was a bit much, and the
-- code within uses a lot of hacks to keep Nvim's state correct. Unsure of value relative to
-- effort

-- MID: For the backup csearch jump, should jumps from t motions offset?

-- LOW: Additional ideas for removing irrelevant locations from cols:
-- - Removing cols under float wins (most common case - TS Context)
-- - For nowrap, removing cols under extends listchars
-- Problem in both cases - Screenpos seems to be quite slow. Produces non-trivial perf loss in
-- big prose buffers. Would need to do a lot of searching to not unnecessarily run screenpos more
-- than necessary on rows not covered by floats. On rows with floats, would need to binary search
-- for positions under floats. Even in Lua space, lots of heap allocation. And the screenpos tables
-- are based on string keys (requires hashing)
-- The best possibility to work with first would be the last wrap line
-- LOW: Would be interesting to test storing the labels as a struct of arrays
-- LOW: Could explore allowing a list of wins not in the current tabpage to be passed to the jump
-- function, assuming they are all part of the same tabpage
-- LOW: Could optimize filtering ns_buf_map and redraw_map by storing a record of which wins and
-- bufs are still active in the targets. On the first filtering pass, even with only two wins,
-- could save a lot of iterating through targets, though it would also make each iteration through
-- the targets more expensive
-- LOW: A way you could optimize virt text population is to check the actual max label size when
-- building them. If you have max tokens at 3 and the biggest label is only 2, the cheaper
-- function can be used. Unsure on this given the guaranteed up front cost of calculating this vs
-- the inconsistent (at best) benefit.

-- ISSUE: Base redraw uses w_botline as the lower bound of where to redraw the window. This
-- excludes the last wrapped line if it is only partially visible. Kinda hate to open an issue for
-- this because it would potentially require re-architecting redraw to fix, which is a lot.
