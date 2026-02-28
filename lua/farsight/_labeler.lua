local api = vim.api

---@class farsight.labeler.LabelOpts
---If, based on max_tokens, it is impossible to fully label all targets, label as much as possible.
---Otherwise, add no labels. If partial labeling is enabled, the labeler will iterate through a
---subset of the targets based on the order of the wins param and the use_upward flag. This is to
---guarantee that every returned label is unique.
---Example: If you provide the 26 alpha characters as available tokens, and max_tokens is 2, and
---partial is true, and there are more than 676 targets, only the first 676 targts will be labeled.
---@field allow_partial boolean
---If true, check the next char for each target. Remove tokens if they overlap with any of the
---next chars
---@field filter_next boolean
---Max tokens per label. Useful if you only want to label targets that can be jumped to in one key
---@field locations "none"|"start"|"finish"|"both"|"cursor_aware"
---@field max_tokens integer
---If true, then for every results set, check the upward boolean value. If upward is true,
---iterate the results from the end.
---@field use_upward boolean

local M = {}

---@param wins integer[] Ordered wins with targets
---@param win_targets table<integer, farsight.common.SearchResults>
local function setup_labels_single(wins, win_targets, count_all_labels, labels_idx, all_labels)
    local i = 1
    local len_wins = #wins
    while i <= count_all_labels do
        for j = 1, len_wins do
            local rem_labels = count_all_labels - (i - 1)
            if rem_labels == 0 then
                break
            elseif rem_labels < 0 then
                error("Too many labels added in setup_labels")
            end

            local targets = win_targets[wins[j]]
            local len_win_labels = math.min(targets[2], rem_labels)
            local targets_labels = targets[labels_idx]
            if targets_labels == vim.NIL then
                error("vim.NIL passed to setup_labels")
            end

            for k = 1, len_win_labels do
                local label = {}
                targets_labels[k] = label
                all_labels[i] = label
                i = i + 1
            end
        end
    end
end

---@param wins integer[] Ordered wins with targets
---@param win_targets table<integer, farsight.common.SearchResults>
---@param tokens integer[] As UTF-8 codepoints
---@param cursor [integer, integer, integer, integer, integer]
---@param opts farsight.labeler.LabelOpts
---@return boolean, string[][]|nil
local function setup_labels(wins, win_targets, tokens, cursor, opts)
    local total_targets = 0
    local len_wins = #wins
    local locations = opts.locations
    if opts.locations == "none" then
        return false, nil
    end

    local use_both = locations == "cursor_aware" or locations == "both"
    local multiplier = use_both and 2 or 1
    for i = 1, len_wins do
        total_targets = total_targets + (win_targets[wins[i]][2] * multiplier)
    end

    local max_possible_labels = math.pow(#tokens, opts.max_tokens)
    if max_possible_labels < total_targets and not opts.allow_partial then
        return false, nil
    end

    local count_all_labels = math.min(max_possible_labels, total_targets)
    local ut = require("farsight.util")
    local all_labels = ut._table_new(count_all_labels, 0) ---@type string[][]

    local i = 1
    if locations == "start" or "finish" then
        local label_start_idx = locations == "finish" and 9 or 8
        setup_labels_single(wins, win_targets, count_all_labels, label_start_idx, all_labels)
    elseif locations == "both" then
        while i <= count_all_labels do
            for j = 1, len_wins do
                local rem_labels = count_all_labels - (i - 1)
                if rem_labels == 0 then
                    break
                elseif rem_labels < 0 then
                    error("Too many labels added in setup_labels")
                end

                local targets = win_targets[wins[j]]
                local len_win_labels = math.min(targets[2], rem_labels)
                local targets_start_labels = targets[8]
                local targets_fin_labels = targets[9]
                if targets_start_labels == vim.NIL then
                    error("vim.NIL passed to setup_labels")
                end

                if targets_fin_labels == vim.NIL then
                    error("vim.NIL passed to setup_labels")
                end

                for k = 1, len_win_labels do
                    local start_label = {}
                    targets_start_labels[k] = start_label
                    all_labels[i] = start_label
                    i = i + 1

                    local fin_label = {}
                    targets_fin_labels[k] = fin_label
                    all_labels[i] = fin_label
                    i = i + 1
                end
            end
        end
    elseif locations == "cursor_aware" then
        while i <= count_all_labels do
            for j = 1, len_wins do
                local rem_labels = count_all_labels - (i - 1)
                if rem_labels == 0 then
                    break
                elseif rem_labels < 0 then
                    error("Too many labels added in setup_labels")
                end

                local targets = win_targets[wins[j]]
                local len_win_labels = math.min(targets[2], rem_labels)
                local targets_start_rows = targets[4]
                local targets_start_cols = targets[5]
                local targets_start_labels = targets[8]
                local targets_fin_labels = targets[9]

                if targets_start_labels == vim.NIL then
                    error("vim.NIL passed to setup_labels")
                end

                if targets_fin_labels == vim.NIL then
                    error("vim.NIL passed to setup_labels")
                end

                for k = 1, len_win_labels do
                    local start_row = targets_start_rows[k] + 1
                    local start_col = targets_start_cols[k] + 1
                    local before_cursor = start_row < cursor[2]
                    local label = {}
                    if before_cursor or start_row == cursor[2] and start_col <= cursor[3] then
                        targets_start_labels[k] = label
                    else
                        targets_fin_labels[k] = label
                    end
                    all_labels[i] = label
                    i = i + 1
                end
            end
        end
    else
        return false, nil
    end

    local len_all_labels = #all_labels
    if len_all_labels ~= count_all_labels then
        error(len_all_labels .. " added instead of " .. count_all_labels .. " in setup_labels")
    end

    return true, all_labels
end
--
-- LOW: This function vaguely points at a template for how adding the labels could be performed
-- without creating the all_labels table at all.
-- LOW: For cursor aware, you could control the fallback direction if the cursor is in the middle
-- of the target

---Edits tokens in place
---@param win_targets table<integer, farsight.common.SearchResults> 0-indexed, exclusive
---@param cache table<integer, table<integer, string>> 1 indexed
---@param tokens integer[] As UTF-8 codepoints
---@param opts farsight.labeler.LabelOpts
local function checked_filter_tokens(win_targets, cache, tokens, opts)
    if not opts.filter_next then
        return
    end

    for win, targets in pairs(win_targets) do
        local win_buf = api.nvim_win_get_buf(win)
        local buf_cache = cache[win_buf] or {}
        local get_utf_codepoint = require("farsight._util_char")._get_utf_codepoint
        local last_fin_row_1 = 0
        local list_remove = require("farsight.util")._list_remove_item
        local line

        local len_targets = targets[2]
        local target_idxs = targets[3]
        local target_fin_rows = targets[6]
        local target_fin_cols = targets[7]

        for i = 1, len_targets do
            local idx = target_idxs[i]
            local fin_row = target_fin_rows[idx]
            local fin_col = target_fin_cols[idx]

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
            local len_tokens = #tokens
            for j = 1, len_tokens do
                if tokens[j] == codepoint then
                    list_remove(tokens, j)
                    break
                end
            end
        end
    end
end
--
-- MID: I don't love the or fallback when getting b1. But I also don't want to encode too many
-- assumptions about how zero length lines are handled at a distance.

---Edits win_targets in place
---When each targets table is created, it is given a pre-allocated table to hold labels, but is not
---filled. This is to avoid allocating label tables that will end up not being used. The labeler
---must fill the tables.
---NOTE: The filter_next opt edits tokens in place! This is done so that the caller can create and
---maintain a copy of the original, rather than having to re-allocate on every labeling pass.
---@param wins integer[] Ordered wins with targets
---@param win_targets table<integer, farsight.common.SearchResults>
---@param tokens integer[] As UTF-8 codepoints
---@param cursor [integer, integer, integer, integer, integer]
---@param cache table<integer, table<integer, string>>
---@param opts farsight.labeler.LabelOpts
---@return boolean
function M.get_res_labels(wins, win_targets, tokens, cursor, cache, opts)
    checked_filter_tokens(win_targets, tokens, cache, opts)
    if #tokens < 1 then
        return false
    end

    if not setup_labels(wins, win_targets, tokens, cursor, opts) then
        return false
    end

    return true
end

return M

-- Concepts:
-- - Fair vs. Preferential labeling shouldn't be an opt, but something you get to indirectly.
--   - The res list is always going to go from or to the cursor based on the upward flag
--   - If you want preferential labeling, put your favored labels near the beginning of the list
--   - For stuff like jump, the labels will always appear from the top
--   - Obvious implication - The labels need to be read in order
-- - When filtering by next char, you have to do a pass through all the results first where you
-- get the next chars then scan the labels. This does mean that we need the labels as codepoints
-- and the caller needs to provide that (so if the caller accepts string, it needs to convert).
-- The caller also needs to create and hold a "working labels" table that is sized to match
-- the labels table, can be filtered down, and then not garbage collected, so it can be
-- continuously refilled and passed
-- - Char checking then can be thought of as a discrete step. Nothing else relies on it having
-- happened (technically. Logically, goofy things could happen)
-- - The label populator needs to track token depth. The seed item would be:
-- { 1, total_targets, 1 }. And then you would have cur_depth = queue[1][3] as a variable. When
-- you go to add new queue items, you calculate the new depth and reject if the new depth would be
-- above the max.
-- - The filtered label length and max depth should then get you to being able to calculate if
-- filling is possible and to quit if it's not. For jump I would not use this because it would
-- be confusing, I'd just let long labels fill out
-- - The original list cannot be something the labeler cares about or maintains. Token filtering
-- needs to be treated like a destructive operation, and the caller needs to deal with it
-- - For next char filtering, all possibilities should be iterated and collected as a hash table
-- first, then iterate over table keys. For large searches, this saves de-duplication cost

-- TODO: At least internally, use math.huge for unlimited tokens. Unsure if I want to do that in
-- user config, but it's not a bad thing either.
-- TODO: All caller functions should do a data validation to make sure that "\" is not a token
-- Annoying though because then you have to do the same validation multiple places. The better
-- solution I think is to put the token validation/conversion here so it's centralized, but the
-- callers have to actually run it. It's irrelevant to the labeler if a \ is a token, so that's
-- something callers have to own.
-- TODO: How do callers handle case where pattern ends in "\"?
-- TODO: For virtual text display, I'm not sure if it goes here, but since the labels always return
-- in the same format and since they are always guaranteed to be unique, the logic is basically the
-- same every time.
-- Specify:
-- - next hl
-- - hl_ahead
-- - hl_target
-- - max_dispay_tokens

-- MID: Right now, I have a definite idea for clearing out the label table entirely rather than
-- re-allocating it from scratch. Would it also be possible to avoid clearing out the individual
-- label sub tables? More complex because it involves handling the different sizing indicators.
