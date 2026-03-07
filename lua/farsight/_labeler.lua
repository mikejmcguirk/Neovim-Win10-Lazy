local api = vim.api
local vimv = vim.v

---@class farsight.labeler.LabelCtx
---If, based on max_tokens, it is impossible to fully label all targets, label as much as possible.
---Otherwise, add no labels. If partial labeling is enabled, the labeler will iterate through a
---subset of the targets based on the order of the wins param and the use_upward flag. This is to
---guarantee that every returned label is unique.
---Example: If you provide the 26 alpha characters as available tokens, and max_tokens is 2, and
---partial is true, and there are more than 676 targets, only the first 676 targts will be labeled.
---@field allow_partial boolean
---@field cursor [integer, integer, integer, integer, integer]
---If true, check the next char for each target. Remove tokens if they overlap with any of the
---next chars
---@field filter_next boolean
---Max tokens per label. Useful if you only want to label targets that can be jumped to in one key
---@field locations "none"|"start"|"finish"|"both"|"cursor_aware"
---Max amount of tokens to display
---@field max_tokens integer
---If true, then for every results set, check the upward boolean value. If upward is true,
---iterate the results from the end.
---@field is_upward boolean
---@field set_char_labels boolean

---@class farsight.labeler.VirtTextCtx
---Highlight group for the next jump input
---@field hl_next integer
---Highlight group for future jump inputs
---@field hl_ahead integer
---Highlight group for the last jump input. Overrides hl_next
---@field hl_last integer
---@field locations "none"|"start"|"finish"|"both"|"cursor_aware"

---@class farsight.labeler.SetCtx
---@field locations "none"|"start"|"finish"|"both"|"cursor_aware"

local M = {}

---@param labels string[][]
---@param tokens string[]
---@param ctx farsight.labeler.LabelCtx
local function populate_labels(labels, tokens, ctx)
    local len_tokens = #tokens
    local max_tokens = ctx.max_tokens

    local queue = { { 1, #labels, 1 } } ---@type { [1]: integer, [2]: integer, [3]: integer }[]
    local i = 1
    while i <= #queue do
        local range_start = queue[i][1]
        local range_end = queue[i][2]
        local token_level = queue[i][3]
        i = i + 1

        local len_range = range_end - range_start + 1
        local quotient = math.floor(len_range / len_tokens)
        local remainder = len_range % len_tokens
        local rem_tokens = quotient + (remainder >= 1 and 1 or 0)
        remainder = remainder > 0 and remainder - 1 or remainder

        local token_idx = 1
        local next_range_start = range_start

        local idx = range_start - 1
        while idx < range_end do
            local token = tokens[token_idx]
            for _ = 1, rem_tokens do
                idx = idx + 1
                local label = labels[idx]
                label[#label + 1] = token
            end

            if idx > next_range_start then
                local next_token_level = token_level + 1
                if next_token_level <= max_tokens then
                    queue[#queue + 1] = { next_range_start, idx, token_level + 1 }
                end
            end

            rem_tokens = quotient + (remainder >= 1 and 1 or 0)
            remainder = remainder > 0 and remainder - 1 or remainder

            token_idx = token_idx + 1
            next_range_start = idx + 1
        end
    end
end

---@param use_upward boolean
---@param len_targets integer
---@param count_new_labels integer
local function get_alloc_iters(use_upward, len_targets, count_new_labels)
    -- In the target iterators, a start of 0 is the last index, and negative numbers are that
    -- distance from the index.
    local start = use_upward and (count_new_labels * -1 + 1) or 1
    local stop = use_upward and len_targets or count_new_labels
    return start, stop
end
-- TODO: This is a bit silly because it's like doing part of the work then targets does the rest
-- of it. Would like the code to express more clearly what the intent of this operation is.
-- MID: It would be better if the location of the labels (beginning or end of targets) as well as
-- the iteration direction were separate controls.

---@param wins integer[] Ordered wins with targets
---@param win_targets table<integer, farsight.targets.Targets>
---@param count_labels integer
---@param labels string[][]
---@param ctx farsight.labeler.LabelCtx
local function alloc_labels_start(wins, win_targets, count_labels, labels, ctx)
    if api.nvim_get_var("farsight_debug") then
        assert(count_labels > 0)
    end

    local use_upward = ctx.is_upward
    local rem_labels = count_labels
    local len_wins = #wins
    for i = 1, len_wins do
        if rem_labels <= 0 then
            break
        end

        local targets = win_targets[wins[i]]
        local len_targets = targets:get_len()
        local count_new_labels = math.min(rem_labels, len_targets)
        rem_labels = rem_labels - count_new_labels
        local start, stop = get_alloc_iters(use_upward, len_targets, count_new_labels)

        for label in targets:iter_alloc_start_labels(start, stop, use_upward) do
            labels[#labels + 1] = label
        end
    end

    if api.nvim_get_var("farsight_debug") then
        assert(rem_labels == 0)
    end
end

---@param wins integer[] Ordered wins with targets
---@param win_targets table<integer, farsight.targets.Targets>
---@param count_labels integer
---@param labels string[][]
---@param ctx farsight.labeler.LabelCtx
local function alloc_labels_fin(wins, win_targets, count_labels, labels, ctx)
    if api.nvim_get_var("farsight_debug") then
        assert(count_labels > 0)
    end

    local use_upward = ctx.is_upward
    local rem_labels = count_labels
    local len_wins = #wins
    for i = 1, len_wins do
        if rem_labels <= 0 then
            break
        end

        local targets = win_targets[wins[i]]
        local len_targets = targets:get_len()
        local count_new_labels = math.min(rem_labels, len_targets)
        rem_labels = rem_labels - count_new_labels
        local start, stop = get_alloc_iters(use_upward, len_targets, count_new_labels)

        for label in targets:iter_alloc_fin_labels(start, stop, use_upward) do
            labels[#labels + 1] = label
        end
    end

    if api.nvim_get_var("farsight_debug") then
        assert(rem_labels == 0)
    end
end

---@param wins integer[] Ordered wins with targets
---@param win_targets table<integer, farsight.targets.Targets>
---@param count_labels integer
---@param labels string[][]
---@param ctx farsight.labeler.LabelCtx
local function alloc_labels_cursor(wins, win_targets, count_labels, labels, ctx)
    if api.nvim_get_var("farsight_debug") then
        assert(count_labels > 0)
    end

    local pos_lt = require("farsight.util").pos_lt
    local cursor = ctx.cursor
    local cursor_row = cursor[2]
    local cursor_col = cursor[3]
    local use_upward = ctx.is_upward
    local rem_labels = count_labels
    local len_wins = #wins
    for i = 1, len_wins do
        if rem_labels <= 0 then
            break
        end

        local targets = win_targets[wins[i]]
        local len_targets = targets:get_len()
        local count_new_labels = math.min(rem_labels, len_targets)
        rem_labels = rem_labels - count_new_labels
        local start, stop = get_alloc_iters(use_upward, len_targets, count_new_labels)

        local after_start = 1

        for j, start_row, start_col in targets:iter_start_pos(start, stop) do
            local start_row_1 = start_row + 1
            local start_col_1 = start_col + 1
            if not pos_lt(cursor_row, cursor_col, start_row_1, start_col_1) then
                after_start = j
                break
            end
        end

        -- TODO: I think this all works out correctly
        for label in targets:iter_alloc_fin_labels(start, after_start - 1, use_upward) do
            labels[#labels + 1] = label
        end

        for label in targets:iter_alloc_fin_labels(after_start, stop, use_upward) do
            labels[#labels + 1] = label
        end
    end

    if api.nvim_get_var("farsight_debug") then
        assert(rem_labels == 0)
    end
end

---@param wins integer[] Ordered wins with targets
---@param win_targets table<integer, farsight.targets.Targets>
---@param count_labels integer
---@param labels string[][]
---@param ctx farsight.labeler.LabelCtx
local function alloc_labels_both(wins, win_targets, count_labels, labels, ctx)
    if api.nvim_get_var("farsight_debug") then
        assert(count_labels > 0)
    end

    local is_upward = ctx.is_upward
    local rem_labels = count_labels
    local len_wins = #wins
    for i = 1, len_wins do
        if api.nvim_get_var("farsight_debug") then
            assert(rem_labels % 2 == 0)
        end

        if rem_labels <= 0 then
            break
        end

        local targets = win_targets[wins[i]]
        local len_targets = targets:get_len()
        local count_new_labels = math.min(rem_labels, len_targets * 2)
        rem_labels = rem_labels - count_new_labels
        local len_new_labels = count_new_labels * 0.5
        local start, stop = get_alloc_iters(is_upward, len_targets, len_new_labels)

        -- If is_upward, the iterator will return the fin label as label_1
        for label_1, label_2 in targets:iter_alloc_both_labels(start, stop, is_upward) do
            labels[#labels + 1] = label_1
            labels[#labels + 1] = label_2
        end
    end

    if api.nvim_get_var("farsight_debug") then
        assert(rem_labels == 0)
    end
end

---@param wins integer[] Ordered wins with targets
---@param win_targets table<integer, farsight.targets.Targets>
---@param tokens string[]
---@param ctx farsight.labeler.LabelCtx
---@return boolean, string[][]|nil
local function alloc_labels(wins, win_targets, tokens, ctx)
    local locations = ctx.locations
    if locations == "none" then
        return false, nil
    end

    local total_targets = 0
    local multiplier = locations == "both" and 2 or 1
    local len_wins = #wins
    for i = 1, len_wins do
        local targets = win_targets[wins[i]]
        total_targets = total_targets + (targets:get_len() * multiplier)
    end

    local max_possible_labels = math.pow(#tokens, ctx.max_tokens)
    local count_labels
    if max_possible_labels < total_targets then
        if ctx.allow_partial then
            count_labels = max_possible_labels
        else
            return false, nil
        end
    else
        count_labels = total_targets
    end

    local labels = require("farsight.util")._table_new(count_labels, 0) ---@type string[][]
    if locations == "finish" then
        alloc_labels_fin(wins, win_targets, count_labels, labels, ctx)
    elseif locations == "cursor_aware" then
        alloc_labels_cursor(wins, win_targets, count_labels, labels, ctx)
    elseif locations == "start" then
        alloc_labels_start(wins, win_targets, count_labels, labels, ctx)
    else
        alloc_labels_both(wins, win_targets, count_labels, labels, ctx)
    end

    return true, labels
end
-- LOW: This function vaguely points at out labels could be added without creating a separate
-- labels table.

---@param tokens string[]
---@return integer[]
local function get_token_codepoints(tokens)
    local ut = require("farsight.util")
    local get_utf_codepoint = require("farsight._util_char")._get_utf_codepoint
    local codepoint_tokens = ut._list_copy(tokens)
    ut._list_map(codepoint_tokens, function(t)
        local char_nr, _ = get_utf_codepoint(t, string.byte(t, 1), 1)
        return char_nr
    end)

    return codepoint_tokens
end

---@param win_targets table<integer, farsight.targets.Targets> 0-indexed, exclusive
---@param cache table<integer, table<integer, string>> 1 indexed
---@param tokens string[]
---@param ctx farsight.labeler.LabelCtx
---@return string[]
local function check_chars_after(win_targets, cache, tokens, ctx)
    local filter_next = ctx.filter_next
    local set_char_labels = ctx.set_char_labels
    if not (filter_next or set_char_labels) then
        return tokens
    end

    local ut = require("farsight.util")
    local get_utf_codepoint = require("farsight._util_char")._get_utf_codepoint

    local codepoints_after = {} ---@type table<integer, [integer,integer]>
    for win, targets in pairs(win_targets) do
        local win_buf = api.nvim_win_get_buf(win)
        local buf_cache = ut.dict_get_key_or_default(cache, win_buf, function()
            return {}
        end)

        local line
        local last_fin_row_1 = 0
        for i, fin_row, fin_col in targets:iter_fin_pos(1, 0, false) do
            local fin_row_1 = fin_row + 1
            if fin_row_1 ~= last_fin_row_1 then
                line = buf_cache[fin_row_1]
                if not line then
                    line = api.nvim_buf_get_lines(win_buf, fin_row, fin_row_1, false)[1]
                    buf_cache[fin_row_1] = line
                end
            end

            local fin_col_1 = fin_col + 1
            local b1 = string.byte(line, fin_col_1) or 0
            local codepoint = get_utf_codepoint(line, b1, fin_col_1)
            local codepoint_after = codepoints_after[codepoint]
            if not codepoint_after then
                codepoints_after[codepoint] = { win, i }
            else
                codepoint_after[1] = -1
            end
        end
    end

    if set_char_labels then
        for codepoint, data in pairs(codepoints_after) do
            local win = data[1]
            if win >= 1000 then
                local codepoint_str = vim.call("char2nr", codepoint) ---@type string
                win_targets[win]:add_char_label(data[2], codepoint_str)
            end
        end
    end

    if filter_next then
        local codepoint_tokens = get_token_codepoints(tokens)
        ut._list_map(codepoint_tokens, function(t)
            if codepoints_after[t] then
                return nil
            else
                return vim.call("nr2char", t)
            end
        end)

        return codepoint_tokens
    else
        return tokens
    end
end
-- TODO: The string.byte or 0 check reveals a more fundamental problem: Zero length lines should
-- either be handled in a principled way or excluded from the targets entirely. I can check, but
-- I don't think you can highlight zero length lines. And I don't need to label them that badly.
-- A problem is that removing zero length lines is surgery enough that I think it would need to be
-- a self function on targets. Maybe you can do it with a filter map. This would also increase the
-- value of de-duping targets as well, since multi-line targets might be shrunken down to
-- overlapping spaces. Though I'm not sure how you handle partial intersections.
-- MID: I don't love converting the tokens from strings to codepoints then back. But I don't want
-- to have to make users provide tokens as codepoints, and I don't want to make allocations for
-- string.sub calls in a hot path.

---@param wins integer[] Ordered wins with targets
---@param win_targets table<integer, farsight.targets.Targets>
local function dbg_validate_fill_labels(wins, win_targets)
    if not api.nvim_get_var("farsight_debug") then
        return
    end

    assert(next(win_targets) ~= nil)
    for _, win in ipairs(wins) do
        assert(win_targets[win])
    end
end

---Edits win_targets and cache in place
---@param wins integer[] Ordered wins with targets
---@param win_targets table<integer, farsight.targets.Targets>
---@param tokens string[]
---@param cache table<integer, table<integer, string>>
---@param ctx farsight.labeler.LabelCtx
---@return boolean
function M.fill_labels(wins, win_targets, tokens, cache, ctx)
    dbg_validate_fill_labels(wins, win_targets)
    local locations = ctx.locations
    if locations == "none" then
        return false
    end

    local filtered_tokens = check_chars_after(win_targets, cache, tokens, ctx)
    local ok, labels = alloc_labels(wins, win_targets, filtered_tokens, ctx)
    if (not ok) or not labels then
        return false
    end

    populate_labels(labels, filtered_tokens, ctx)
    return true
end

---Edits targets in place
---@param targets farsight.targets.Targets
---@param init integer
---@param max_display_tokens integer
---@param ctx farsight.labeler.VirtTextCtx
local function fill_vtext_maxt(targets, init, max_display_tokens, ctx)
    local init_0 = init - 1
    local hl_next = ctx.hl_next
    local hl_ahead = ctx.hl_ahead
    local hl_last = ctx.hl_last

    ---@param label string[]
    ---@param available integer
    ---@return [string, integer|string?][]
    local function get_vtext_maxt(label, available)
        local len_label = #label
        local len_from_init = len_label - init_0

        if len_from_init <= 1 then
            return { { label[init], hl_last } }
        end

        local display = available == vimv.maxcol and vimv.maxcol
            or math.min(available, max_display_tokens)

        if len_from_init <= display then
            if len_from_init == 2 then
                return { { label[init], hl_next }, { label[init + 1], hl_last } }
            elseif len_from_init == 3 then
                return {
                    { label[init], hl_next },
                    { label[init + 1], hl_ahead },
                    { label[len_label], hl_last },
                }
            else
                local text = table.concat(label, "", init + 1, len_label - 1)
                return {
                    { label[init], hl_next },
                    { text, hl_ahead },
                    { label[len_label], hl_last },
                }
            end
        end

        if display <= 1 then
            return { { label[init], hl_next } }
        elseif display == 2 then
            return { { label[init], hl_next }, { label[init + 1], hl_ahead } }
        else
            local concat_j = init + display - 1
            local text = table.concat(label, "", init + 1, concat_j)
            return { { label[init], hl_next }, { text, hl_ahead } }
        end
    end

    local locations = ctx.locations
    if locations == "start" or locations == "cursor_aware" then
        targets:map_start_vtexts_from_labels_cmp_next_start(get_vtext_maxt)
    end

    if locations == "finish" or locations == "cursor_aware" then
        targets:map_fin_vtexts_from_labels_cmp_next_fin(get_vtext_maxt)
    end

    if locations == "both" then
        targets:map_start_vtexts_from_labels_cmp_fin(get_vtext_maxt)
        targets:map_fin_vtexts_from_labels_cmp_next_start(get_vtext_maxt)
    end
end

---Edits targets in place
---@param targets farsight.targets.Targets
---@param init integer
---@param ctx farsight.labeler.VirtTextCtx
local function fill_vtext_max2(targets, init, ctx)
    local init_0 = init - 1
    local hl_next = ctx.hl_next
    local hl_ahead = ctx.hl_ahead
    local hl_last = ctx.hl_last

    ---@param label string[]
    ---@param available integer
    ---@return [string, integer|string?][]
    local function get_vtext_max2(label, available)
        local len = #label - init_0
        if len > 1 and available >= 2 then
            local hl_2 = len == 2 and hl_last or hl_ahead
            return { { label[init], hl_next }, { label[init + 1], hl_2 } }
        elseif len <= 1 then
            return { { label[init], hl_last } }
        else
            return { { label[init], hl_next } }
        end
    end

    local locations = ctx.locations
    if locations == "start" or locations == "cursor_aware" then
        targets:map_start_vtexts_from_labels_cmp_next_start(get_vtext_max2)
    end

    if locations == "finish" or locations == "cursor_aware" then
        targets:map_fin_vtexts_from_labels_cmp_next_fin(get_vtext_max2)
    end

    if locations == "both" then
        targets:map_start_vtexts_from_labels_cmp_fin(get_vtext_max2)
        targets:map_fin_vtexts_from_labels_cmp_next_start(get_vtext_max2)
    end
end

---Edits targets in place
---@param targets farsight.targets.Targets
---@param init integer
---@param ctx farsight.labeler.VirtTextCtx
local function fill_vtext_max1(targets, init, ctx)
    local hl_next = ctx.hl_next
    local hl_last = ctx.hl_last
    local init_0 = init - 1

    ---@param label string[]
    ---@return [string, integer|string?][]
    local function get_vtext_max1(label)
        if #label - init_0 > 1 then
            return { { label[init], hl_next } }
        else
            return { { label[init], hl_last } }
        end
    end

    targets:map_start_vtext_from_labels(get_vtext_max1)
    targets:map_fin_vtext_from_labels(get_vtext_max1)
end

---@param targets farsight.targets.Targets
local function dbg_validate_fill_virt_text(targets)
    if not api.nvim_get_var("farsight_debug") then
        return
    end

    assert(targets:get_len() >= 1)
end

---Edits targets in place
---@param targets farsight.targets.Targets
---Index to start reading the labels from
---@param init integer
---@param max_display_tokens integer
---@param ctx farsight.labeler.VirtTextCtx
---@return boolean
function M.fill_virt_text(targets, init, max_display_tokens, ctx)
    dbg_validate_fill_virt_text(targets)
    if ctx.locations == "none" then
        return false
    end
    -- TODO: Check if targets has any labels. Need to look at start and stop indexes. Can probably
    -- make a function in targets that reports it start and end label counts

    if max_display_tokens == 1 then
        fill_vtext_max1(targets, init, ctx)
    elseif max_display_tokens == 2 then
        fill_vtext_max2(targets, init, ctx)
    else
        fill_vtext_maxt(targets, init, max_display_tokens, ctx)
    end

    return true
end

---@param buf integer
---@param ns integer
---@param targets farsight.targets.Targets
---@param ctx farsight.labeler.SetCtx
function M.set_target_extmarks(buf, ns, targets, ctx)
    if ctx.locations == "none" then
        return
    end

    ---@type vim.api.keyset.set_extmark
    local extmark_opts = {
        hl_mode = "combine",
        priority = 1000,
        virt_text_pos = "overlay",
    }

    for row, col, vtext in targets:iter_start_vtexts() do
        extmark_opts.virt_text = vtext
        api.nvim_buf_set_extmark(buf, ns, row, col, extmark_opts)
    end

    for row, col, vtext in targets:iter_fin_vtexts() do
        extmark_opts.virt_text = vtext
        api.nvim_buf_set_extmark(buf, ns, row, col, extmark_opts)
    end
end

return M

-- TODO: At least internally, use math.huge for unlimited tokens. Unsure if I want to do that in
-- user config, but it's not a bad thing either.
-- TODO: All caller functions should do a data validation to make sure that "\" is not a token
-- Annoying though because then you have to do the same validation multiple places. The better
-- solution I think is to put the token validation/conversion here so it's centralized, but the
-- callers have to actually run it. It's irrelevant to the labeler if a \ is a token, so that's
-- something callers have to own.
--
-- LOW: For directional searching, it would be optimal to compare the current prompt to the last
-- one and, if it were a strict narrowing of the previous search term, filter the current targets
-- rather than create a new set. You could even cache all target sets in the current search. In
-- practice, this would be hideously complicated.
