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

---@param win integer
---@param row integer
---@param line string
---@param buf integer
---@param cur_pos { [1]: integer, [2]: integer }
---@param locator fun(win: integer, row: integer, line: string, buf: integer, cur_pos: { [1]: integer, [2]: integer }):integer[]
local function get_cols(win, row, line, buf, cur_pos, locator)
    local cols = locator(win, row, line, buf, cur_pos)
    require("farsight.util")._list_dedup(cols)
    table.sort(cols, function(a, b)
        return a < b
    end)

    return cols
end

local function is_col_covered(screenpos, fwins)
    local srow = screenpos.row
    local scol = screenpos.col

    for _, fwin in ipairs(fwins) do
        local within_height = fwin[3] <= srow and srow <= fwin[5]
        local within_width = fwin[4] <= scol and scol <= fwin[6]
        if within_height and within_width then
            return false
        end
    end

    return true
end

-- TODO: Do we have the col finder output one indexed cols? Awkward for user customization

local function filter_invisible_cols(win, row, cols, fwins)
    local screenpos = fn.screenpos
    local function is_offscreen(i, col)
        local spos = screenpos(win, row, col + 1)
        if spos.row == 0 then
            cols[i] = nil
            return true
        else
            return false
        end
    end

    local cols_start_len = #cols
    -- Handling this step separately does actually non-trivially impact perf in walls of text
    for i = cols_start_len, 1, -1 do
        if not is_offscreen(i, cols[i]) then
            break
        end
    end

    if #fwins < 1 then
        return
    end

    require("farsight.util")._list_filter(cols, function(c)
        local spos = screenpos(win, row, c + 1)
        return is_col_covered(spos, fwins)
    end)
end

---Edits targets in place
---@param win integer
---@param cur_pos { [1]: integer, [2]: integer }
---@param buf integer
---@param locator fun(win: integer, row: integer, line: string, buf: integer, cur_pos: { [1]: integer, [2]: integer }):integer[]
---@param ns integer
---@param fwins farsight.jump.FloatWin[]
---@param targets farsight.jump.Target[]
local function add_targets_after(win, cur_pos, buf, locator, ns, fwins, targets)
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
    local count_cols = #cols
    for i = 1, count_cols do
        cols[i] = cols[i] + (#line - #line_after)
    end

    local row = cur_pos[1]
    filter_invisible_cols(win, row, cols, fwins)

    local row_0 = row - 1
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
---@param fwins farsight.jump.FloatWin[]
---@param targets farsight.jump.Target[]
local function add_targets_before(win, cur_pos, buf, locator, ns, fwins, targets)
    local row = cur_pos[1]
    local line = fn.getline(row)
    local ut = require("farsight.util")
    local cur_cword = ut._find_cword_at_col(line, cur_pos[2])
    local end_col_1 = cur_cword and cur_cword[2] or cur_pos[2]

    local line_before = string.sub(line, 1, end_col_1)
    local cols = get_cols(win, row, line_before, buf, cur_pos, locator)
    filter_invisible_cols(win, row, cols, fwins)

    local row_0 = row - 1
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
---@param fwins farsight.jump.FloatWin[]
---@param targets farsight.jump.Target[]
local function add_targets(win, row, buf, cur_pos, locator, ns, fwins, targets)
    local line = fn.getline(row)
    local cols = get_cols(win, row, line, buf, cur_pos, locator)

    filter_invisible_cols(win, row, cols, fwins)
    local row_0 = row - 1
    for _, col in ipairs(cols) do
        targets[#targets + 1] = { win, buf, row_0, col, {}, ns, {} }
    end
end

---@class farsight.jump.FloatWin
---@field [1] integer winid
---@field [2] integer zindex
---@field [3] integer top
---@field [4] integer left
---@field [5] integer bot
---@field [6] integer right

-- TODO: The fwins logic is also needed for the search module. In the Csearch module, I think
-- it would be purely aesthetic, so the overhead would probably not be worth it
-- TODO: In the search case, if incsearch makes the cursor move, and that closes an LSP float,
-- how would we deal with the updated window state?

---@return farsight.jump.FloatWin[]
local function get_fwins()
    local fwins = {} ---@type farsight.jump.FloatWin[]

    local nvim_win_get_config = api.nvim_win_get_config
    local nvim_win_get_position = api.nvim_win_get_position
    local tabpage_wins = api.nvim_tabpage_list_wins(0)

    for _, win in ipairs(tabpage_wins) do
        local config = nvim_win_get_config(win)
        local zindex = config.zindex
        if zindex and zindex > 0 then
            local pos = nvim_win_get_position(win)
            -- These two already properly handle border
            local top = pos[1] + 1
            local left = pos[2] + 1

            -- LOW: Potential edge case where a table border is set that does not include the
            -- right and/or bottom border. Can handle this if it shows up in the wild
            local border_val = config.border ~= "none" and 1 or 0
            local bottom = top + config.height - 1 + border_val
            local right = left + config.width - 1 + border_val

            fwins[#fwins + 1] = { win, zindex, top, left, bottom, right }
        end
    end

    return fwins
end

-- TODO: The float win and off screen checks must be optimized, as they produce slowdown in large
-- prose files

---@param wins integer[]
---@param opts farsight.jump.JumpOpts
---@return farsight.jump.Target[], table<integer, integer>
local function get_targets(wins, opts)
    local wins_len = #wins
    local missing_ns = wins_len - #namespaces
    for _ = 1, missing_ns do
        namespaces[#namespaces + 1] = api.nvim_create_namespace("")
    end

    local fwins = get_fwins()
    local ns_buf_map = {} ---@type table<integer, integer>
    local nvim__ns_set = api.nvim__ns_set
    local targets = {} ---@type farsight.jump.Target[]

    local deepcopy = vim.deepcopy
    local dir = opts.dir ---@type integer
    local line = fn.line
    local list_filter = require("farsight.util")._list_filter
    ---@type fun(row: integer, line: string, buf: integer,
    ---cur_pos: { [1]: integer, [2]: integer }):integer[]
    local locator = opts.locator
    local max = math.max
    local min = math.min
    local nvim_win_call = api.nvim_win_call
    local nvim_win_get_buf = api.nvim_win_get_buf
    local nvim_win_get_config = api.nvim_win_get_config
    local nvim_win_get_cursor = api.nvim_win_get_cursor

    for i = 1, wins_len do
        local win = wins[i]

        local cmp_fwins = deepcopy(fwins, true)
        local zindex = nvim_win_get_config(win).zindex or 0
        list_filter(cmp_fwins, function(x)
            -- AFAIK, two floating windows with the same zindex produce undefined behavior in terms
            -- of which one displays. Therefore, don't show jump tokens for either
            return x[2] >= zindex
        end)

        local cur_pos = nvim_win_get_cursor(win)
        local buf = nvim_win_get_buf(win)
        local ns = namespaces[i]
        nvim__ns_set(ns, { wins = { win } })
        ns_buf_map[ns] = buf

        nvim_win_call(win, function()
            local w0 = line("w0")
            local wS = line("w$")
            local top ---@type integer
            local bot ---@type integer
            if dir <= 0 then
                top = w0
            end

            if dir >= 0 then
                bot = wS
            end

            if dir == -1 then
                bot = max(cur_pos[1] - 1, top)
            elseif dir == 1 then
                top = min(cur_pos[1] + 1, bot)
                add_targets_after(win, cur_pos, buf, locator, ns, cmp_fwins, targets)
            end

            if dir <= 0 then
                -- TODO: Remove invisible from beginning. Add to top row
            end

            for k = top, bot do
                add_targets(win, k, buf, cur_pos, locator, ns, cmp_fwins, targets)
            end

            if dir == -1 then
                add_targets_before(win, cur_pos, buf, locator, ns, cmp_fwins, targets)
            end
        end)
    end

    return targets, ns_buf_map
end

-- MID: The variable names in this function could be more clear
-- LOW: In theory, there should be some way to optimize this by pre-computing and pre-allocating
-- the label lengths rather than doing multiple appends/resizes

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

-- LOW: Profile this function to see if it could be optimized further

---Edits targets in place
---@param targets farsight.jump.Target[]
---@param max_tokens integer
---@param jump_level integer
local function populate_target_virt_text(targets, max_tokens, jump_level)
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

    add_virt_text(targets[#targets], max_tokens)
end

---Edits targets in place
---@param targets farsight.jump.Target[]
---@param max_tokens integer
---@param jump_level integer
local function populate_target_virt_text_from_max(targets, jump_level, max_tokens)
    if max_tokens == 1 then
        populate_target_virt_text_max_1(targets, jump_level)
    elseif max_tokens == 2 then
        populate_target_virt_text_max_2(targets, jump_level)
    else
        populate_target_virt_text(targets, max_tokens, jump_level)
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

---Expects zero indexed row and col
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

-- LOW: A way you could optimize virt text population is to check the actual max label size when
-- building them. If you have max tokens at 3 and the biggest label is only 2, the cheaper
-- function can be used. Unsure on this given the guaranteed up front cost of calculating this vs
-- the inconsistent (at best) benefit.

---Edits ns_buf_map and targets in place
---@param ns_buf_map table<integer, integer>
---@param targets farsight.jump.Target[]
---@param map_mode "n"|"v"|"o"|"l"|"t"|"x"|"s"|"i"|"c"
---@param jump_level integer
---@param opts farsight.jump.JumpOpts
---@return nil
local function advance_jump(ns_buf_map, targets, map_mode, jump_level, opts)
    local dim = opts.dim
    local max_tokens = opts.max_tokens ---@type integer
    while true do
        populate_target_virt_text_from_max(targets, jump_level, max_tokens)

        ---@type vim.api.keyset.set_extmark
        local extmark_opts = { hl_mode = "combine", priority = 1000, virt_text_pos = "overlay" }
        local nvim_buf_set_extmark = api.nvim_buf_set_extmark
        for _, target in ipairs(targets) do
            extmark_opts.virt_text = target[7]
            pcall(nvim_buf_set_extmark, target[2], target[6], target[3], target[4], extmark_opts)
        end

        if dim then
            dim_target_lines(targets, ns_buf_map)
        end

        api.nvim__redraw({ valid = true })
        local _, input = pcall(fn.getcharstr)
        local nvim_buf_clear_namespace = api.nvim_buf_clear_namespace
        for ns, buf in pairs(ns_buf_map) do
            pcall(nvim_buf_clear_namespace, buf, ns, 0, -1)
        end

        local start = jump_level + 1
        require("farsight.util")._list_filter(targets, function(target)
            return target[5][start] == input
        end)

        local targets_len = #targets
        if targets_len <= 1 then
            if targets_len == 1 then
                local target = targets[1]
                do_jump(target[1], target[2], target[3], target[4], map_mode, opts)
            end

            return
        end

        local k1 = next(ns_buf_map)
        local k2 = next(ns_buf_map, k1)
        if k2 ~= nil then
            local new_ns_buf_map = {} ---@type table<integer, integer>
            for _, target in ipairs(targets) do
                new_ns_buf_map[target[6]] = target[2]
            end

            ns_buf_map = new_ns_buf_map
        end

        for _, target in ipairs(targets) do
            local virt_text = target[7]
            -- Faster with the lower quantities in the virtual text tables
            local len = #virt_text
            for i = len, 1, -1 do
                virt_text[i] = nil
            end
        end

        jump_level = jump_level + 1
    end
end

---@param opts farsight.jump.JumpOpts
---@param map_mode "n"|"v"|"o"|"l"|"t"|"x"|"s"|"i"|"c"
local function resolve_jump_opts(opts, map_mode)
    vim.validate("opts", opts, "table")
    local ut = require("farsight.util")
    local cur_buf = api.nvim_get_current_buf()

    opts.dim = ut._use_gb_if_nil(opts.dim, "farsight_dim", cur_buf)
    opts.dim = ut._resolve_bool_opt(opts.dim, false)
    vim.validate("opts.dim", opts.dim, "boolean")

    opts.dir = opts.dir or 0
    vim.validate("opts.dir", opts.dir, ut._is_int)
    vim.validate("opts.dir", opts.dir, function()
        return -1 <= opts.dir and opts.dir <= 1
    end, "Dir must be -1, 0, or 1")

    opts.keepjumps = ut._use_gb_if_nil(opts.keepjumps, "farsight_keepjumps", cur_buf)
    opts.keepjumps = ut._resolve_bool_opt(opts.keepjumps, false)
    vim.validate("opts.keepjumps", opts.keepjumps, "boolean")

    opts.locator = (function()
        if opts.locator then
            return opts.locator
        end

        if map_mode == "v" or map_mode == "o" then
            return locate_cwords_with_cur_pos
        else
            return locate_cwords
        end
    end)()

    vim.validate("opts.locator", opts.locator, "callable")

    opts.max_tokens = ut._use_gb_if_nil(opts.max_tokens, "farsight_max_tokens", cur_buf)
    opts.max_tokens = opts.max_tokens or MAX_TOKENS
    vim.validate("opts.max_tokens", opts.max_tokens, ut._is_uint)
    vim.validate("opts.max_tokens", opts.max_tokens, function()
        return opts.max_tokens > 0
    end, "max_tokens must be at least one")

    opts.on_jump = ut._use_gb_if_nil(opts.on_jump, "farsight_on_jump", cur_buf)
    opts.on_jump = opts.on_jump
        or function(_, _, _)
            api.nvim_cmd({ cmd = "norm", args = { "zv" }, bang = true }, {})
        end

    vim.validate("opts.on_jump", opts.on_jump, "callable")

    opts.tokens = ut._use_gb_if_nil(opts.tokens, "farsight_jump_tokens", cur_buf)
    opts.tokens = opts.tokens or TOKENS
    vim.validate("opts.tokens", opts.tokens, "table")
    ut._list_dedup(opts.tokens)
    ut._validate_list(opts.tokens, { item_type = "string", min_len = 2 })

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

    local focusable_wins = ut._order_focusable_wins(opts.wins)
    if #focusable_wins < 1 then
        api.nvim_echo({ { "No focusable wins provided" } }, false, {})
        return
    end

    local targets, ns_buf_map = get_targets(focusable_wins, opts)
    if #targets > 1 then
        local jump_level = 0
        populate_target_labels(targets, opts.tokens)
        advance_jump(ns_buf_map, targets, map_mode, jump_level, opts)
    elseif #targets == 1 then
        do_jump(targets[1][1], targets[1][2], targets[1][3], targets[1][4], map_mode, opts)
    else
        api.nvim_echo({ { "No sights to jump to" } }, false, {})
    end
end

---@return integer[]
function Jump.get_hl_namespaces()
    return vim.deepcopy(namespaces, true)
end

return Jump

-- TODO: Validate that all provided wins are in the current tabpage
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

-- MID: The disadvantage of the current jump key is that you're locked to some position within the
-- word. It should be possible to jump to a specific spot. I am aware of two solutions to this:
-- - The Flash style enhanced search. You do something like /ad, and it will label each spot with
-- ad
-- - Sneak style two character motion. You do sad and it takes you to the next one forward. It
-- also adds labels and lets you use ;/, to navigate
-- My preference is to overwrite / and ? because:
-- - I use s for substitute
-- - I do not like ;/, navigation
-- - I find the default search somewhat awkward to use
-- - It is possible, I think, to hook into the entirety of the search state. You can manually
-- fill the / register, manually set v:searchforward, and manually trigger v:hlsearch
-- Obstacle: Flash uses a lot of hacks to keep its UI nice. We'll just have to go with it
-- I would be looking for the following behaviors:
-- - If only one instance of the search term is found on the screen, immediately jump there
-- - An issue with Flash's search is that the labels get in the way of the word. Would want to try
-- to avoid this
-- - If you hit <cr>, it should behave like search normally does
-- - If we jump to a specific search term, either with a label or automatically, hlsearch should
-- stay at zero. hlsearch should only set to 1 if we hit enter (unsure if there are built-in
-- controls on this to keep in mind. I think of the nohlsearch opt is set even a v value of 1
-- does nothing)
-- Concrete use case: I'm working in a function. Jump to somewhere else. Jump back. Cursor position
-- isn't the same. Unsure exactly where to jump. I want to hit /foo to identify where exactly to
-- jump
-- MID: For the backup csearch jump, should jumps from t motions offset?

-- LOW: Would be interesting to test storing the labels as a struct of arrays
-- LOW: Could explore allowing a list of wins not in the current tabpage to be passed to the jump
-- function, assuming they are all part of the same tabpage
-- PR: screenpos() return type
