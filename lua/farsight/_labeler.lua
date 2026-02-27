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
---@field max_tokens integer
---If true, then for every results set, check the upward boolean value. If upward is true,
---iterate the results from the end.
---@field use_upward boolean

local M = {}

---Edits win_res in place
---When each res table is created, it is given a pre-allocated table to hold labels, but is not
---filled. This is to avoid allocating label tables that will end up not being used. The labeler
---must fill the tables.
---NOTE: The filter_next opt edits tokens in place! This is done so that the caller can create and
---maintain a copy of the original, rather than having to re-allocate on every labeling pass.
---@param wins integer[] Ordered wins with targets
---@param win_res table<integer, farsight.common.SearchResults>
---@param cache table<integer, table<integer, string>>
---@param tokens integer[] As UTF-8 codepoints
---@param opts farsight.labeler.LabelOpts
---@return table<integer, string[][]>
function M.get_res_labels(wins, win_res, cache, tokens, opts)
    return {}
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
