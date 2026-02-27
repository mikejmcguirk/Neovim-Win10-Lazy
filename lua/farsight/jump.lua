local api = vim.api
local fn = vim.fn

---@class farsight.jump.Targets
---@field [1] integer Length
---@field [2] integer[] Zero indexed rows |api-indexing|
---@field [3] integer[] Zero indexed cols, inclusive |api-indexing|
---@field [4] string[][] Labels
---@field [5] [string, string|integer][][] Virtual text chunks

---@class farsight.jump.WinInfo
---@field [1] integer Buf
---@field [2] integer Hl Ns
---@field [3] boolean Redraw valid flag

local DEFAULT_MAX_TOKENS = 2
local TOKENS = vim.split("abcdefghijklmnopqrstuvwxyz", "")

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

local fn_foldclosed = fn.foldclosed
local str_byte = string.byte
local str_find = string.find
local str_sub = string.sub

local get_char_class = require("farsight._util_char")._get_char_class
local get_utf_codepoint = require("farsight._util_char")._get_utf_codepoint

---Assumes nvim_win_call in relevant window context
---@param line string
---@param isk_tbl boolean[]
---@return integer[] Zero indexed
local function locate_cwords_cur_line(line, col, isk_tbl)
    local cols = {}
    local in_keyword = false
    local last_i = 0

    local col_1 = col + 1
    local i = 1
    local len_line = #line
    while i <= len_line do
        local char_nr, len_char = get_utf_codepoint(line, str_byte(line, i), i)
        local char_class = get_char_class(char_nr, isk_tbl)
        if char_class >= 2 then
            if i < col_1 and in_keyword == false then
                cols[#cols + 1] = i - 1
            end

            in_keyword = true
        else
            if i > col_1 and in_keyword == true then
                cols[#cols + 1] = last_i - 1
            end

            in_keyword = false
        end

        last_i = i
        i = i + len_char
    end

    return cols
end

---Assumes nvim_win_call in relevant window context
---@param line string
---@param isk_tbl boolean[]
---@return integer[] Zero indexed
local function locate_cword_fin(line, isk_tbl)
    local cols = {}
    local in_keyword = false
    local last_i = 0

    local i = 1
    local len_line = #line
    while i <= len_line do
        local char_nr, len_char = get_utf_codepoint(line, str_byte(line, i), i)
        local char_class = get_char_class(char_nr, isk_tbl)
        if char_class >= 2 then
            in_keyword = true
        else
            if in_keyword == true then
                cols[#cols + 1] = last_i - 1
            end

            in_keyword = false
        end

        last_i = i
        i = i + len_char
    end

    return cols
end

---Assumes nvim_win_call in relevant window context
---@param line string
---@param isk_tbl boolean[]
---@return integer[] Zero indexed
local function locate_cword_start(line, isk_tbl)
    local cols = {}
    local in_keyword = false

    local i = 1
    local len_line = #line
    while i <= len_line do
        local char_nr, len_char = get_utf_codepoint(line, str_byte(line, i), i)
        local char_class = get_char_class(char_nr, isk_tbl)
        if char_class >= 2 then
            if in_keyword == false then
                cols[#cols + 1] = i - 1
            end

            in_keyword = true
        else
            in_keyword = false
        end

        i = i + len_char
    end

    return cols
end

---Assumes nvim_win_call in relevant window context
---@param line string
---@param row integer
---@return integer[]|nil Returns a list if the line should NOT be iterated over
local function check_locator_line(line, row)
    if str_find(line, "[^\\0-\\32\\127]") == nil then
        return {}
    end

    local fold_row = fn_foldclosed(row)
    if fold_row ~= -1 then
        if fold_row ~= row then
            return {}
        end

        return { 0 }
    end

    return nil
end

---Assumes nvim_win_call in relevant window context
---@param _ integer
---@param line string
---@param row integer
---@param cur_pos { [1]: integer, [2]: integer }
---@param isk_tbl boolean[]
---@return integer[] Zero indexed
local function locate_cwords_with_cur_pos(_, line, row, cur_pos, isk_tbl)
    local early_cols = check_locator_line(line, row)
    if early_cols then
        return early_cols
    end

    local cur_row = cur_pos[1]
    if row < cur_row then
        return locate_cword_start(line, isk_tbl)
    elseif row > cur_row then
        return locate_cword_fin(line, isk_tbl)
    else
        return locate_cwords_cur_line(line, cur_pos[2], isk_tbl)
    end
end

---Assumes nvim_win_call in relevant window context
---@diagnostic disable-next-line: duplicate-doc-param
---@param _ integer
---@param line string
---@param row integer
---@diagnostic disable-next-line: duplicate-doc-param
---@param _ { [1]: integer, [2]: integer }
---@param isk_tbl boolean[]
---@return integer[] Zero indexed
local function locate_cwords(_, line, row, _, isk_tbl)
    local early_cols = check_locator_line(line, row)
    if early_cols then
        return early_cols
    end

    return locate_cword_start(line, isk_tbl)
end

---@param jump_win integer
---@param buf integer
---@param jump_row_0 integer
---@param jump_col integer
---@param map_mode "n"|"v"|"o"|"l"|"t"|"x"|"s"|"i"|"c"
---@param opts farsight.jump.JumpOpts
---@return nil
local function do_jump(jump_win, buf, jump_row_0, jump_col, map_mode, opts)
    local cur_win = api.nvim_get_current_win()
    local cur_pos = api.nvim_win_get_cursor(cur_win)
    local cur_row = cur_pos[1]
    local cur_col = cur_pos[2]
    local jump_row = jump_row_0 + 1

    if cur_win ~= jump_win then
        api.nvim_set_current_win(jump_win)
        -- As far as I know, changing windows always changes the state to normal mode.
        map_mode = "n"
    end

    local jump_pos = { jump_row, jump_col }
    if cur_row == jump_row and cur_col == jump_col then
        -- By not going into visual mode, the current character is properly captured when
        -- performing an operator motion only on the cursor column.
        opts.on_jump(jump_win, buf, jump_pos)
        return
    end

    -- Because jumplists are scoped per window, setting the pcmark in the window being left doesn't
    -- provide anything useful. By setting the pcmark in the window where the jump is performed,
    -- the user is provided the ability to undo the jump
    if not opts.keepjumps then
        -- FUTURE: When the updated mark API is released, see if that can be used to set the
        -- pcmark correctly
        api.nvim_cmd({ cmd = "norm", args = { "m`" }, bang = true }, {})
    end

    if map_mode == "o" then
        ---@type string
        local selection = api.nvim_get_option_value("selection", { scope = "global" })
        local is_backward = jump_row < cur_row or (jump_row == cur_row and jump_col < cur_col)

        -- If operating backward, the cursor character should not be affected.
        if selection ~= "exclusive" and is_backward then
            fn.searchpos("\\m.", "Wb", cur_row)
        -- Make sure the end of the operated range is included.
        elseif selection == "exclusive" and not is_backward then
            local line = api.nvim_buf_get_lines(buf, jump_pos[1] - 1, jump_pos[1], false)[1]
            -- Do this way rather than with searchpos() for control and to avoid a double move.
            -- Exclusive selections can go one past the line boundary.
            jump_pos[2] = math.min(jump_pos[2] + 1, #line)
        end

        -- Always use visual mode for consistency/control over the selected text.
        api.nvim_cmd({ cmd = "norm", args = { "v" }, bang = true }, {})
    end

    api.nvim_win_set_cursor(jump_win, jump_pos)
    opts.on_jump(jump_win, buf, jump_pos)
end

---j_win == -1 if no targets remain, 0 if multiple targets remain, and >= 1000 if only one target
---@param win_targets table<integer, farsight.jump.Targets>
---@return integer, integer, integer
local function get_jump_info(win_targets)
    local j_win = -1
    local j_row = -1
    local j_col = -1

    for win, targets in pairs(win_targets) do
        local len_targets = targets[1]
        if len_targets > 1 then
            return 0, 0, 0
        end

        if len_targets == 1 then
            if j_win >= 1000 then
                return 0, 0, 0
            end

            j_win = win
            j_row = targets[2][1]
            j_col = targets[3][1]
        end
    end

    return j_win, j_row, j_col
end

-- LOW: Rather than doing this, it could be possible to incrementally build/edit the virtual text.
-- But this would require doing surgery on the virtual text chunks, to optimize the part of the
-- jump where, likely, the amount of remaining targets is probably not all that much

---Edits win_targets in place
---@param win_targets table<integer, farsight.jump.Targets>
local function clear_target_virt_text(win_targets)
    for _, targets in pairs(win_targets) do
        local t_chunks = targets[5]
        local len_targets = targets[1]
        for i = 1, len_targets do
            local chunks = t_chunks[i]
            local len_chunks = #chunks
            for j = 1, len_chunks do
                chunks[j] = nil
            end
        end
    end
end

---Edits win_dim_info in place
---@param win_targets table<integer, farsight.jump.Targets>
---@param win_dim_rows table<integer, integer[]>
local function filter_dim_rows(win_targets, win_dim_rows)
    local list_filter = require("farsight.util")._list_filter
    for win, dim_rows in pairs(win_dim_rows) do
        local targets = win_targets[win]
        if not targets then
            win_dim_rows[win] = nil
        else
            local cur_rows = {} ---@type table<integer, boolean>
            local target_rows = targets[2]
            local len_target_rows = #target_rows
            for i = 1, len_target_rows do
                cur_rows[target_rows[i]] = true
            end

            list_filter(dim_rows, function(row)
                return cur_rows[row] == true
            end)
        end
    end
end

---Edits win_targets in place
---@param win_targets table<integer, farsight.jump.Targets>
---@param start integer
---@param input string
local function filter_win_targets(win_targets, start, input)
    for win, targets in pairs(win_targets) do
        local len_targets = targets[1]
        local t_rows = targets[2]
        local t_cols = targets[3]
        local t_labels = targets[4]
        local t_chunks = targets[5]

        local j = 1
        for i = 1, len_targets do
            local label = t_labels[i]
            if label[start] == input then
                t_rows[j] = t_rows[i]
                t_cols[j] = t_cols[i]
                t_labels[j] = label
                t_chunks[j] = t_chunks[i]
                j = j + 1
            end
        end

        local new_len = j - 1
        if new_len == 0 then
            win_targets[win] = nil
        else
            targets[1] = new_len
            for i = j, len_targets do
                t_rows[i] = nil
                t_cols[i] = nil
                t_labels[i] = nil
                t_chunks[i] = nil
            end
        end
    end
end

-- LOW: Redrawing is the most performance intensive part of this module. Other than per-window
-- scoping, I'm not sure how to reduce the time it takes. Doing ranges almost seems to make it
-- worse

---@param win_info table<integer, farsight.jump.WinInfo>
local function do_redraws(win_info)
    local nvim__redraw = api.nvim__redraw
    for win, info in pairs(win_info) do
        nvim__redraw({ win = win, valid = info[3] })
    end
end

---@param win_info table<integer, farsight.jump.WinInfo>
---@param win_dim_rows table<integer, integer[]>
local function dim_target_lines(win_info, win_dim_rows)
    local nvim_buf_set_extmark = api.nvim_buf_set_extmark
    ---@type vim.api.keyset.set_extmark
    local dim_opts = {
        end_col = 0,
        hl_eol = true,
        hl_group = hl_jump_dim,
        priority = 999,
    }

    for win, dim_rows in pairs(win_dim_rows) do
        local len_dim_rows = #dim_rows
        for i = 1, len_dim_rows do
            local info = win_info[win]
            local row = dim_rows[i]
            dim_opts.end_line = row + 1
            pcall(nvim_buf_set_extmark, info[1], info[2], row, 0, dim_opts)
        end
    end
end

---@param win_targets table<integer, farsight.jump.Targets>
---@param win_info table<integer, farsight.jump.WinInfo>
local function set_label_extmarks(win_targets, win_info)
    ---@type vim.api.keyset.set_extmark
    local extmark_opts = {
        hl_mode = "combine",
        priority = 1000,
        virt_text_pos = "overlay",
    }

    local nvim_buf_set_extmark = api.nvim_buf_set_extmark
    for win, targets in pairs(win_targets) do
        local info = win_info[win]
        local t_rows = targets[2]
        local t_cols = targets[3]
        local t_chunks = targets[5]

        local len_targets = targets[1]
        for i = 1, len_targets do
            extmark_opts.virt_text = t_chunks[i]
            pcall(nvim_buf_set_extmark, info[1], info[2], t_rows[i], t_cols[i], extmark_opts)
        end
    end
end

---Edits win_targets in place
---@param win_targets table<integer, farsight.jump.Targets>
---@param jump_level integer
---@param max_tokens integer
local function populate_virt_text_max_tokens(win_targets, jump_level, max_tokens)
    local concat = table.concat
    local maxcol = vim.v.maxcol
    local min = math.min
    local start = 1 + jump_level
    local start_plus_one = start + 1

    ---@param row integer
    ---@param next_row integer
    ---@param col integer
    ---@param next_col integer
    ---@param label string[]
    ---@param chunks [string,integer|string][]
    local function add_chunk_info(row, next_row, col, next_col, label, chunks)
        local len_full_label = #label
        local len_label = len_full_label - jump_level

        chunks[1] = { label[start], hl_jump }
        if len_label > 1 then
            local same_row = row == next_row
            local max_display_tokens = same_row and min(next_col - col, max_tokens) or maxcol
            if len_label <= max_display_tokens then
                local rem_label = len_full_label - start
                if rem_label == 1 then
                    chunks[2] = { label[start_plus_one], hl_jump_target }
                elseif rem_label == 2 then
                    chunks[2] = { label[start_plus_one], hl_jump_ahead }
                    chunks[3] = { label[start_plus_one + 1], hl_jump_target }
                else
                    local text = concat(label, "", start_plus_one, len_full_label - 1)
                    chunks[2] = { text, hl_jump_ahead }
                    chunks[3] = { label[len_full_label], hl_jump_target }
                end
            elseif max_display_tokens == 2 then
                chunks[2] = { label[start_plus_one], hl_jump_ahead }
            elseif max_display_tokens > 2 then
                local concat_j = start + max_display_tokens - 1
                local text = concat(label, "", start_plus_one, concat_j)
                chunks[2] = { text, hl_jump_ahead }
            end
        else
            chunks[1][2] = hl_jump_target
        end
    end

    for _, targets in pairs(win_targets) do
        local len_targets = targets[1]
        local t_rows = targets[2]
        local t_cols = targets[3]
        local t_labels = targets[4]
        local t_chunks = targets[5]

        local max_i = len_targets - 1
        for i = 1, max_i do
            local row = t_rows[i]
            local next_row = t_rows[i + 1]
            local col = t_cols[i]
            local next_col = t_cols[i + 1]
            local label = t_labels[i]
            local chunks = t_chunks[i]

            add_chunk_info(row, next_row, col, next_col, label, chunks)
        end

        local row = t_rows[len_targets]
        local col = t_cols[len_targets]
        local label = t_labels[len_targets]
        local chunks = t_chunks[len_targets]

        add_chunk_info(row, maxcol, col, maxcol, label, chunks)
    end
end

---Edits win_targets in place
---@param win_targets table<integer, farsight.jump.Targets>
---@param jump_level integer
local function populate_virt_text_max_2(win_targets, jump_level)
    local start = 1 + jump_level
    local start_plus_one = start + 1

    ---@param label string[]
    ---@param len_label integer
    ---@param chunks [string, string|integer][]
    local function add_token_2(label, len_label, chunks)
        if len_label == 2 then
            chunks[2] = { label[start_plus_one], hl_jump_target }
        else
            chunks[2] = { label[start_plus_one], hl_jump_ahead }
        end
    end

    ---@param row integer
    ---@param next_row integer
    ---@param col integer
    ---@param next_col integer
    ---@param label string[]
    ---@param chunks [string, string|integer][]
    local function add_chunk_info(row, next_row, col, next_col, label, chunks)
        chunks[1] = { label[start], hl_jump }
        local len_label = #label - jump_level
        if len_label > 1 then
            if row == next_row then
                if next_col - col >= 2 then
                    add_token_2(label, len_label, chunks)
                end
            else
                add_token_2(label, len_label, chunks)
            end
        else
            chunks[1][2] = hl_jump_target
        end
    end

    for _, targets in pairs(win_targets) do
        local len_targets = targets[1]
        local t_rows = targets[2]
        local t_cols = targets[3]
        local t_labels = targets[4]
        local t_chunks = targets[5]

        local max_i = len_targets - 1
        for i = 1, max_i do
            local row = t_rows[i]
            local next_row = t_rows[i + 1]
            local col = t_cols[i]
            local next_col = t_cols[i + 1]
            local label = t_labels[i]
            local chunks = t_chunks[i]

            add_chunk_info(row, next_row, col, next_col, label, chunks)
        end

        local row = t_rows[len_targets]
        local col = t_cols[len_targets]
        local label = t_labels[len_targets]
        local chunks = t_chunks[len_targets]

        local maxcol = vim.v.maxcol
        add_chunk_info(row, maxcol, col, maxcol, label, chunks)
    end
end

---Edits targets in place
---@param win_targets table<integer, farsight.jump.Targets>
---@param jump_level integer
local function populate_virt_text_max_1(win_targets, jump_level)
    local start = 1 + jump_level

    for _, targets in pairs(win_targets) do
        local len_targets = targets[1]
        local t_labels = targets[4]
        local t_chunks = targets[5]

        for i = 1, len_targets do
            local label = t_labels[i]
            local rem_label = #label - jump_level
            if rem_label > 1 then
                t_chunks[i][1] = { label[start], hl_jump }
            else
                t_chunks[i][1] = { label[start], hl_jump_target }
            end
        end
    end
end

---Edits targets in place
---@param win_targets table<integer, farsight.jump.Targets>
---@param max_tokens integer
---@param jump_level integer
local function populate_target_virt_text(win_targets, jump_level, max_tokens)
    if max_tokens == 1 then
        populate_virt_text_max_1(win_targets, jump_level)
    elseif max_tokens == 2 then
        populate_virt_text_max_2(win_targets, jump_level)
    else
        populate_virt_text_max_tokens(win_targets, jump_level, max_tokens)
    end
end

---Edits win_targets and win_info in place
---@param win_targets table<integer, farsight.jump.Targets>
---@param win_info table<integer, farsight.jump.WinInfo>
---@param win_dim_rows table<integer, integer[]>
---@param map_mode "n"|"v"|"o"|"l"|"t"|"x"|"s"|"i"|"c"
---@param opts farsight.jump.JumpOpts
---@return nil
local function advance_jump(win_targets, win_info, win_dim_rows, map_mode, opts)
    local jump_level = 0
    local nvim_buf_clear_namespace = api.nvim_buf_clear_namespace

    while true do
        populate_target_virt_text(win_targets, jump_level, opts.max_tokens)
        set_label_extmarks(win_targets, win_info)
        if opts.dim then
            dim_target_lines(win_info, win_dim_rows)
        end

        do_redraws(win_info)
        local _, input = pcall(fn.getcharstr)
        for _, info in pairs(win_info) do
            pcall(nvim_buf_clear_namespace, info[1], info[2], 0, -1)
        end

        -- Do before filtering targets because we need the previous level's windows for redrawing
        if jump_level > 0 then
            require("farsight.util")._dict_filter(win_info, function(k, _)
                return win_targets[k] ~= nil
            end)
        end

        local start = jump_level + 1
        filter_win_targets(win_targets, start, input)
        if opts.dim then
            filter_dim_rows(win_targets, win_dim_rows)
        end

        local j_win, j_row, j_col = get_jump_info(win_targets)
        if j_win ~= 0 then
            do_redraws(win_info)
            if j_win >= 1000 then
                do_jump(j_win, win_info[j_win][1], j_row, j_col, map_mode, opts)
            end

            return
        end

        clear_target_virt_text(win_targets)
        jump_level = jump_level + 1
    end
end

-- MID: The variable names in this function could be more clear
-- LOW: In theory, there should be some way to optimize this by pre-computing and pre-allocating
-- the label lengths rather than doing multiple appends/resizes

---Edits targets in place
---@param wins integer[]
---@param win_targets table<integer, farsight.jump.Targets>
---@param tokens string[]
---@return nil
local function populate_target_labels(wins, win_targets, tokens)
    local total_targets = 0
    local len_wins = #wins
    for i = 1, len_wins do
        total_targets = total_targets + win_targets[wins[i]][1]
    end

    local ut = require("farsight.util")
    -- More consistent performance. narray is zero indexed
    local labels = ut._table_new(total_targets + 1, 0) ---@type string[][]
    -- Use wins for lookup to preserve ordering
    for i = 1, len_wins do
        local t_labels = win_targets[wins[i]][4]
        local len_t_labels = #t_labels
        for j = 1, len_t_labels do
            labels[#labels + 1] = t_labels[j]
        end
    end

    local floor = math.floor
    local len_tokens = #tokens
    local list_remove = ut._list_remove_item

    local queue = {} ---@type { [1]: integer, [2]:integer }[]
    queue[#queue + 1] = { 1, total_targets }
    while #queue > 0 do
        local range_start = queue[1][1]
        local range_end = queue[1][2]
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
                local label = labels[idx]
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
---@param row_0 integer
---@param cols integer[]
---@param targets farsight.jump.Targets
local function add_cols_to_targets(row_0, cols, targets)
    local t_rows = targets[2]
    local t_cols = targets[3]
    local t_labels = targets[4]
    local t_chunks = targets[5]

    local len_cols = #cols
    targets[1] = targets[1] + len_cols
    for i = 1, len_cols do
        t_rows[#t_rows + 1] = row_0
        t_cols[#t_cols + 1] = cols[i]
        t_labels[#t_labels + 1] = {}
        t_chunks[#t_chunks + 1] = {}
    end
end

---Assumes it is called in the window context of win
---@param win integer
---@param buf integer
---@param cur_pos { [1]: integer, [2]: integer }
---@param row integer
---@param isk_tbl boolean[]
---@param locator fun( buf: integer, line: string, row: integer,
---cur_pos: { [1]: integer, [2]: integer }, isk_tbl: boolean[]):integer[]
local function get_extra_wrap_cols(win, buf, row, cur_pos, isk_tbl, locator)
    if row >= api.nvim_buf_line_count(buf) then
        return {}
    end

    if fn.screenpos(win, row, 1).row < 1 then
        return {}
    end

    return locator(buf, fn.getline(row), row, cur_pos, isk_tbl)
end

---Takes zero indexed col
---Returns are zero indexed, end exclusive
---Returns -1, -1 if the cursor is not in a cword
---@param line string
---@param col integer
---@return integer, integer
local function find_cword_around_col(line, col, isk_tbl)
    local col_1 = col + 1
    local cur_b1 = str_byte(line, col_1)
    local cur_char_nr, len_cur_char = get_utf_codepoint(line, cur_b1, col_1)
    local cur_char_class = get_char_class(cur_char_nr, isk_tbl)
    if cur_char_class < 2 then
        return -1, -1
    end

    local start = col_1 - 1
    local fin_ = col_1 + len_cur_char - 1

    local i = col_1 + len_cur_char
    local len_line = #line
    while i <= len_line do
        local b1 = str_byte(line, i)
        local char_nr, len_char = get_utf_codepoint(line, b1, i)
        local char_class = get_char_class(char_nr, isk_tbl)
        if char_class >= 2 then
            i = i + len_char
            fin_ = i - 1
        else
            break
        end
    end

    i = start - 1
    while i >= 1 do
        local b1 = str_byte(line, i)
        if b1 <= 0x80 or b1 >= 0xC0 then
            local char_nr, _ = get_utf_codepoint(line, b1, i)
            local char_class = get_char_class(char_nr, isk_tbl)
            if char_class >= 2 then
                start = i - 1
            else
                break
            end
        end

        i = i - 1
    end

    return start, fin_
end

---Assumes nvim_win_call in relevant window context
---@param buf integer
---@param line string
---@param cur_pos { [1]: integer, [2]: integer }
---@param isk_tbl boolean[]
---@param locator fun( buf: integer, line: string, row: integer,
---cur_pos: { [1]: integer, [2]: integer }, isk_tbl: boolean[]):integer[]
local function get_cols_before(buf, line, cur_pos, isk_tbl, locator)
    local start, _ = find_cword_around_col(line, cur_pos[2], isk_tbl)
    local end_col_1 = start > -1 and start - 1 or cur_pos[2]
    local line_before = string.sub(line, 1, end_col_1)
    return locator(buf, line_before, cur_pos[1], cur_pos, isk_tbl)
end

---Assumes nvim_win_call in relevant window context
---@param buf integer
---@param line string
---@param cur_pos { [1]: integer, [2]: integer }
---@param locator fun( buf: integer, line: string, row: integer,
---cur_pos: { [1]: integer, [2]: integer }, isk_tbl: boolean[]):integer[]
---@param isk_tbl boolean[]
local function get_cols_after(buf, line, cur_pos, locator, isk_tbl)
    local _, fin_ = find_cword_around_col(line, cur_pos[2], isk_tbl)
    local start_col_1 = fin_ > -1 and fin_ + 1 or cur_pos[2]

    -- TODO: Provide init and end indexes to the locator. Unsure on indexing/exclusivity. Should
    -- be based on what's most useful to the user, so look at matchstrpos, vim.regex, and whatever
    -- else they might use. This saves an annoying and weird assumption that you might not always
    -- get the full line, while still allowing deterministic searching for lines where the whole
    -- thing is not meant to be searched. These variables then need to be put into the function
    -- signature and documented.
    -- TODO: Do not pass isk_tbl to the locator. My functions need to get at it a different way.
    -- If we make a public interface for isk, demonstrate how to use it. It's wasteful if the
    -- user doesn't need it and aesthetically arbitrary.
    local line_after = str_sub(line, start_col_1, #line)
    local cols = locator(buf, line_after, cur_pos[1], cur_pos, isk_tbl)
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
    local fn_line = fn.line
    local wS = fn_line("w$")
    if dir == 1 then
        return math.min(cur_pos[1], wS), wS, wS
    elseif dir == -1 then
        local w0 = fn_line("w0")
        return w0, math.max(cur_pos[1], w0), wS
    else
        return fn_line("w0"), wS, wS
    end
end

---Edits win_info in place
---@param wins integer[]
---@param win_info table<integer, farsight.jump.WinInfo>
---@param opts farsight.jump.JumpOpts
---@return table<integer, farsight.jump.Targets>, table<integer, integer[]>
local function get_targets(wins, win_info, opts)
    local win_targets = {} ---@type table<integer, farsight.jump.Targets>
    local win_dim_rows = {} ---@type table<integer, integer[]>
    for _, win in ipairs(wins) do
        win_targets[win] = { 0, {}, {}, {}, {} }
        win_dim_rows[win] = {}
    end

    local dim = opts.dim ---@type boolean
    local dir = opts.dir ---@type -1|0|1
    local list_dedup = require("farsight.util")._list_dedup
    ---@type fun( buf: integer, line: string, row: integer,
    ---cur_pos: { [1]: integer, [2]: integer }, isk_tbl: boolean[]):integer[]
    local locator = opts.locator
    local nvim_buf_get_lines = api.nvim_buf_get_lines
    local nvim_win_call = api.nvim_win_call
    local nvim_win_get_cursor = api.nvim_win_get_cursor
    local nvim_get_option_value = api.nvim_get_option_value
    local parse_isk = require("farsight._util_char")._parse_isk
    local table_new = require("farsight.util")._table_new
    local tbl_sort = table.sort

    local wins_len = #wins
    for i = 1, wins_len do
        local win = wins[i]
        local buf = win_info[win][1]
        -- Always get/send so it's available for user functions
        local cur_pos = nvim_win_get_cursor(win)
        local isk = nvim_get_option_value("isk", { buf = buf }) ---@type string
        local isk_tbl = parse_isk(buf, isk)
        local wrap = nvim_get_option_value("wrap", { win = win }) ---@type boolean

        local targets = win_targets[win]
        local all_cols
        local offset

        nvim_win_call(win, function()
            local top, bot, wS = get_top_bot(dir, cur_pos)
            -- +1 because math, +1 for potential wrap line, +1 because "table.new" is zero indexed
            all_cols = table_new(bot - top + 3, 0)
            local lines = nvim_buf_get_lines(buf, top - 1, bot, false)
            offset = top - 1 -- Set before dir adjustments for proper line numbering

            if dir == 1 then
                all_cols[1] = get_cols_after(buf, lines[1], cur_pos, locator, isk_tbl)
                top = top + 1
            elseif dir == -1 then
                bot = bot - 1
            end

            for j = top, bot do
                local idx = j - offset
                all_cols[idx] = locator(buf, lines[idx], j, cur_pos, isk_tbl)
            end

            if dir == -1 then
                local idx = #lines
                all_cols[idx] = get_cols_before(buf, lines[idx], cur_pos, isk_tbl, locator)
            end

            if wrap and bot == wS and dir >= 0 then
                local row = bot + 1
                local cols = get_extra_wrap_cols(win, buf, row, cur_pos, isk_tbl, locator)
                all_cols[#lines + 1] = cols
                if #cols > 0 then
                    win_info[win][3] = false
                end
            end
        end)

        local dim_rows = win_dim_rows[win]
        local len_all_cols = #all_cols
        for j = 1, len_all_cols do
            local cols = all_cols[j]
            list_dedup(cols)
            tbl_sort(cols, function(a, b)
                return a < b
            end)

            local row_0 = j + offset - 1
            add_cols_to_targets(row_0, cols, targets)
            if #cols > 0 and dim then
                dim_rows[#dim_rows + 1] = row_0
            end
        end
    end

    return win_targets, win_dim_rows
end

---@param wins integer[]
---@return table<integer, farsight.jump.WinInfo>
local function get_win_info(wins)
    local wins_len = #wins
    local missing_ns = wins_len - #namespaces
    for _ = 1, missing_ns do
        namespaces[#namespaces + 1] = api.nvim_create_namespace("")
    end

    local nvim_win_get_buf = api.nvim_win_get_buf
    local nvim__ns_set = api.nvim__ns_set

    local win_info = {} ---@type table<integer, farsight.jump.WinInfo>
    for i = 1, wins_len do
        local win = wins[i]
        local ns = namespaces[i]
        nvim__ns_set(ns, { wins = { win } })
        win_info[win] = { nvim_win_get_buf(win), ns, true }
    end

    return win_info
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
        item_type = { "number" },
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

local function resolve_tokens(opts, cur_buf)
    local ut = require("farsight.util")
    opts.tokens = ut._use_gb_if_nil(opts.tokens, "farsight_jump_tokens", cur_buf)
    if opts.tokens == nil then
        opts.tokens = TOKENS
    else
        local tokens = opts.tokens
        vim.validate("opts.tokens", tokens, "table")
        ---@diagnostic disable-next-line: param-type-mismatch
        ut._list_dedup(tokens)
        ---@diagnostic disable-next-line: param-type-mismatch
        ut._validate_list(tokens, { item_type = { "string" }, min_len = 2 })
    end
end

---Edits opts in place
---@param opts farsight.jump.JumpOpts
---@param cur_buf integer
local function resolve_on_jump(opts, cur_buf)
    local ut = require("farsight.util")
    opts.on_jump = ut._use_gb_if_nil(opts.on_jump, "farsight_on_jump", cur_buf)
    if opts.on_jump == nil then
        opts.on_jump = function(_, _, _)
            local fdo = api.nvim_get_option_value("fdo", { scope = "global" })
            local jump, _, _ = string.find(fdo, "jump", 1, true)
            local all, _, _ = string.find(fdo, "all", 1, true)
            if all or jump then
                api.nvim_cmd({ cmd = "norm", args = { "zv" }, bang = true }, {})
            end
        end

        return
    end

    vim.validate("opts.on_jump", opts.on_jump, "callable")
end

---Edits opts in place
---@param opts farsight.jump.JumpOpts
---@param cur_buf integer
local function resolve_max_tokens(opts, cur_buf)
    local ut = require("farsight.util")
    opts.max_tokens = ut._use_gb_if_nil(opts.max_tokens, "farsight_jump_max_tokens", cur_buf)
    if opts.max_tokens == nil then
        opts.max_tokens = DEFAULT_MAX_TOKENS
    else
        local max_tokens = opts.max_tokens
        vim.validate("opts.max_tokens", max_tokens, function()
            if max_tokens % 1 ~= 0 then
                return false
            end

            return max_tokens > 0
        end, "max_tokens must be a uint greater than zero")
    end
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

---Edits opts in place
---@param opts farsight.jump.JumpOpts
---@param map_mode "n"|"v"|"o"|"l"|"t"|"x"|"s"|"i"|"c"
local function resolve_jump_opts(opts, map_mode)
    vim.validate("opts", opts, "table")
    local ut = require("farsight.util")
    local cur_buf = api.nvim_get_current_buf()

    opts.dim = ut._use_gb_if_nil(opts.dim, "farsight_jump_dim", cur_buf)
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
    resolve_max_tokens(opts, cur_buf)
    resolve_on_jump(opts, cur_buf)
    resolve_tokens(opts, cur_buf)
    resolve_wins(opts, map_mode)
end

---@class farsight.StepJump
local Jump = {}

-- TODO: DOCUMENT: Wait to document the opts until the docgen method is figured out vis-a-vis the
-- g:vars. I want to avoid writing redundant text.

---@class farsight.jump.JumpOpts
---The input row argument is one indexed
---This function will be called in the window context being evaluated. This means, for example,
---that foldclosed() will return the proper result
---The returned columns must be zero indexed
---The returned array will be de-duplicated and sorted from least to greatest
---@field dim? boolean
---@field dir? -1|0|1
---@field keepjumps? boolean
---@field locator? fun( buf: integer, line: string, row: integer,
---cur_pos: { [1]: integer, [2]: integer }, isk_tbl: boolean[]):integer[]
---@field max_tokens? integer
---@field on_jump? fun(win: integer, buf: integer, jump_pos: { [1]:integer, [2]: integer })
---@field tokens? string[]
---@field wins? integer[]

---@param opts farsight.jump.JumpOpts?
function Jump.jump(opts)
    opts = opts and vim.deepcopy(opts) or {}
    local ut = require("farsight.util")
    local map_mode = ut._resolve_map_mode(api.nvim_get_mode().mode)
    resolve_jump_opts(opts, map_mode)

    local wins = ut._order_focusable_wins(opts.wins)
    if #wins < 1 then
        api.nvim_echo({ { "No focusable wins provided" } }, false, {})
        return
    end

    local win_info = get_win_info(wins)
    local win_targets, win_dim_rows = get_targets(wins, win_info, opts)
    local j_win, j_row, j_col = get_jump_info(win_targets)
    if j_win == 0 then
        populate_target_labels(wins, win_targets, opts.tokens)
        advance_jump(win_targets, win_info, win_dim_rows, map_mode, opts)
        return
    end

    if j_win >= 1000 then
        do_jump(j_win, win_info[j_win][1], j_row, j_col, map_mode, opts)
        return
    end

    api.nvim_echo({ { "No targets available" } }, false, {})
end

---@return integer[]
function Jump.get_hl_ns()
    return require("farsight.util")._list_copy(namespaces)
end

return Jump

-- TODO: Types of jump to handle:
-- - Love typed
-- - X char based
-- - Canned search
-- TODO: Match label option:
-- - start
-- - end
-- - both
-- - cursor aware
-- TODO: I want to re-conceptualize this module some. There are three use cases it should be able
-- to handle:
-- - Incremental typed jump
-- - Type a search term, get a result back
-- - Get all labels based on a canned search
-- Actually don't do the layered patterns thing. You can do something like\(\d\|\a\)
-- TODO: For incremental typed jump, in addition to what is effectively max display labels, there
-- should be a max_actual_tokens variable or something. You want to be able to say, if a jump
-- requires more than three keypresses, don't bother.
-- TODO: Variable for fair or preferential label.
--
-- TODO_DOC: Show a CWORD locator example
-- TODO_DOC: Dot repeats always prompt for a label.
-- TODO_DOC: If any provided wins are not in the current tabpage, an error will be raised. If
-- none of the wins are focusable, the function will early exit.
-- TODO_DOC: Like csearch, default on_jump checks fdo.

-- LOW: Allow a list of wins not in the current tabpage to be passed to the jump function, assuming
-- they are all part of the same tabpage. Make advance_jump change tabpages before displaying
-- extmarks

-- MAYBE: Pass a ctx tbl to the locator function, allowing more data to be visible without the user
-- having to get it manually. For performance, could be allocated in create_targets then passed
-- around and edited in place.
