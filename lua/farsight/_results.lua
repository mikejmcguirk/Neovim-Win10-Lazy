---@class (exact) farsight.results.Results
---@field size integer
---@field next_idx integer
---
---@field idxs integer[]
---@field char_hl_idxs integer[]
---@field start_label_idxs integer[]
---@field fin_label_idxs integer[]
---@field both_label_idxs integer[]
---@field reused_fin_label_idxs integer[]
---@field start_vtext_idxs integer[]
---@field fin_vtext_idxs integer[]
---@field both_vtext_idxs integer[]
---
---@field start_rows integer[]
---@field start_cols integer[]
---@field fin_rows integer[]
---@field fin_cols integer[]
---@field hashed_fin_pos integer[]
---
---@field start_labels string[][]
---@field fin_labels string[][]
---@field start_vtexts [string, integer|string?][][]
---@field fin_vtexts [string, integer|string?][][]
---
---@field __index farsight.results.Results
---@field new fun(size:integer): Results:farsight.results.Results
local Results = {}
Results.__index = Results

-- ADDING VTEXTS
-- - For anything using fin_labels, the reuse labels need to be bisected in
--
-- HANDLING LABEL RE-USE
--
-- Necessary data exterior to targets:
-- - Save current tokens in a hashmap (because number could be infinite)
--
-- Old targets check:
-- - Requires hashed tokens (because number could be infinite)
-- - Export a list of old target idxs that can be re-used
--
-- New targets check:
-- - Takes in a list of idxs from old targets
-- - Initialize hashed positions here
--   - This should initially be vim.NIL
-- - For each old idx:
--   - Hash the position
--   - If new_idxs has it:
--     - Write the label data
--     - Move the idx to reused_fin_label_idxs
--     - Like with char_hls, this should be a one-pass filter over idxs
--
-- Other things:
-- - Char_hls should not be able to write if either of the label tables are len > 0
--   - Add comment as to why
-- - Make a note about saving hash keys

-----------------
-- MARK: Utils --
-----------------

---@param row integer
---@param col integer
---@return string
local function create_pos_key(row, col)
    return table.concat({ row, col }, ":")
end
-- TODO: Profile if using table.concat is faster than string concatenation

---@param fin boolean
---@return integer[], integer[]
function Results:get_positions(fin)
    local rows = fin and self.fin_rows or self.start_rows
    local cols = fin and self.fin_cols or self.start_cols
    return rows, cols
end
-- TODO: I guess this naming is fine. Should be
-- - get_pos (one position)
-- - get_positions (get tbls for start or fin)
-- - get_both_pos (get a start + fin position)
-- - get_both_positions (get start and fin pos tbls)

--------------------------
-- MARK: Initialization --
--------------------------

function Results.new(size)
    local self = setmetatable({}, Results)
    local tn = require("farsight.util")._table_new

    self.size = size
    self.next_idx = 1

    self.idxs = tn(size, 0)
    self.char_hl_idxs = vim.NIL
    self.start_label_idxs = vim.NIL
    self.fin_label_idxs = vim.NIL
    self.both_label_idxs = vim.NIL
    self.reused_fin_label_idxs = vim.NIL
    self.start_vtext_idxs = vim.NIL
    self.fin_vtext_idxs = vim.NIL
    self.both_vtext_idxs = vim.NIL

    self.start_rows = tn(size, 0)
    self.start_cols = tn(size, 0)
    self.fin_rows = tn(size, 0)
    self.fin_cols = tn(size, 0)
    self.hashed_fin_pos = vim.NIL

    -- Pre-allocate and pre-fill labels and vtexts so that maintaining list contiguousness is not
    -- dependent on other state and logic.
    self.start_labels = tn(size, 0)
    self.fin_labels = tn(size, 0)
    self.start_vtexts = tn(size, 0)
    self.fin_vtexts = tn(size, 0)

    return self
end

---@param start_row integer
---@param start_col integer
---@param fin_row integer
---@param fin_col integer
function Results:append(start_row, start_col, fin_row, fin_col)
    local next_idx = self.next_idx

    self.start_rows[next_idx] = start_row
    self.start_cols[next_idx] = start_col
    self.fin_rows[next_idx] = fin_row
    self.fin_cols[next_idx] = fin_col

    self.start_labels[next_idx] = vim.NIL
    self.fin_labels[next_idx] = vim.NIL
    self.start_vtexts[next_idx] = vim.NIL
    self.fin_vtexts[next_idx] = vim.NIL

    self.next_idx = next_idx + 1
end
-- TODO: Replace this with hoisting so it's easier to JIT.

---@param start integer
---@param stop integer
---@param fin boolean
---@param rev boolean
---@param predicate fun(row:integer, col:integer): boolean
---@return integer|nil, integer|nil, integer|nil
function Results:find_pos(start, stop, fin, rev, predicate)
    local idxs = self.idxs
    local rows, cols = self:get_positions(fin)

    local init = rev and stop or start
    local limit = rev and start or stop
    local iter = rev and -1 or 1

    for i = init, limit, iter do
        local idx = idxs[i]
        local row = rows[idx]
        local col = cols[idx]
        if predicate(row, col) then
            return i, row, col
        end
    end

    return nil, nil, nil
end
-- TODO: Start and stop need to be adjusted and converted to idx iters

---@param start integer
---@param stop integer
---@param mapper fun(start_row: integer, start_col: integer, fin_row: integer, fin_col: integer): integer, integer, integer, integer
function Results:map_both_pos(start, stop, mapper)
    local idxs = self.idxs
    local start_rows = self.start_rows
    local start_cols = self.start_cols
    local fin_rows = self.fin_rows
    local fin_cols = self.fin_cols

    for i = start, stop do
        local idx = idxs[i]
        local start_row = start_rows[idx]
        local start_col = start_cols[idx]
        local fin_row = fin_rows[idx]
        local fin_col = fin_cols[idx]

        start_rows[idx], start_cols[idx], fin_rows[idx], fin_cols[idx] =
            mapper(start_row, start_col, fin_row, fin_col)
    end
end
-- TODO: Start and stop need to be adjusted and converted to idx iters

---@param start integer
---@param stop integer
---@param mapper fun(row: integer, col: integer): integer, integer
function Results:map_pos(start, stop, fin, mapper)
    local idxs = self.idxs
    local rows, cols = self:get_positions(fin)

    for i = start, stop do
        local idx = idxs[i]
        rows[idx], cols[idx] = mapper(rows[idx], cols[idx])
    end
end
-- TODO: Start and stop need to be adjusted and converted to idx iters

---@param start integer
---@param stop integer
---@param fin boolean
---@param rev boolean
---@param mapper fun(row: integer, col: integer): integer, integer
function Results:map_pos_stop_on_noop(start, stop, fin, rev, mapper)
    local idxs = self.idxs
    local rows, cols = self:get_positions(fin)

    local init = rev and stop or start
    local limit = rev and start or stop
    local iter = rev and -1 or 1

    for i = init, limit, iter do
        local idx = idxs[i]
        local row = rows[idx]
        local col = cols[idx]

        local new_row, new_col = mapper(row, col)
        if not (row == new_row and col == new_col) then
            rows[idx] = new_row
            cols[idx] = new_col
        else
            return
        end
    end
end
-- TODO: Start and stop need to be adjusted and converted to idx iters

---@param start integer
---@param stop integer
---@param fin boolean
---@param predicate fun(row:integer, col:integer): boolean
function Results:filter_pos_stop_on_keep(start, stop, fin, rev, predicate)
    local idxs = self.idxs
    local rows, cols = self:get_positions(fin)

    local init = rev and stop or start
    local limit = rev and start or stop
    local iter = rev and -1 or 1

    local j = init
    for i = init, limit do
        local idx = idxs[i]
        if not predicate(rows[idx], cols[idx]) then
            j = j + iter
        else
            break
        end
    end

    if j == init then
        return
    end

    require("farsight.util").list_compact(idxs, start, j)
end
-- TODO: Test that this combines rev and fwd properly
-- TODO: Start and stop need to be adjusted and converted to idx iters

------------------------
-- MARK: Add Char Hls --
------------------------

---@return integer[]
function Results:init_char_hl_idxs()
    local tn = require("farsight.util")._table_new
    self.char_hl_idxs = tn((math.floor(self.size * 0.5)), 0)
    return self.char_hl_idxs
end

---@param chars_after string[]
---@param char_counts table<string, integer>
function Results:alloc_char_hls(chars_after, char_counts)
    local idxs = self.idxs
    assert(#char_counts == #idxs)

    assert(self.char_hl_idxs == vim.NIL)
    local char_hl_idxs = self:init_char_hl_idxs()

    local len = #idxs
    local j = 1

    for i = 1, len do
        local count_char = char_counts[chars_after[i]]
        if count_char ~= 1 then
            -- TODO: Verify doing this conditionally is correct
            idxs[j] = idxs[i]
            j = j + 1
        else
            char_hl_idxs[#char_hl_idxs + 1] = idxs[i]
        end
    end

    for i = j, len do
        idxs[i] = nil
    end
end
-- TODO: I don't know why you would care if this is run more than once, since a second run would
-- just do nothing. Also, this should be able to be like, a filter on idxs that internally moves
-- the filtered values to the char list
-- MID: The function naming and assertion, I think, communicate that this function should only
-- be used once. I'm fine with hard-erroring since this is internal code. I'm also fine with not
-- building-in theoretical flexibilty since this does not arbitrarily limit the underlying data
-- structure. I still think handling this problem this way is hacky.

----------------------
-- MARK: Add labels --
----------------------

---@return integer[]
function Results:init_start_label_idxs()
    local tn = require("farsight.util")._table_new
    self.start_label_idxs = tn(self.size, 0)
    return self.start_label_idxs
end

---@return integer[]
function Results:init_fin_label_idxs()
    local tn = require("farsight.util")._table_new
    self.fin_label_idxs = tn(self.size, 0)
    return self.fin_label_idxs
end

---@return integer[]
function Results:init_both_label_idxs()
    local tn = require("farsight.util")._table_new
    self.both_label_idxs = tn(self.size, 0)
    return self.both_label_idxs
end

---@param hashed_tokens table<string, boolean>
---@return integer[]
function Results:get_fin_label_reuse_candidates(hashed_tokens)
    local fin_labels = self.fin_labels
    local fin_vtext_idxs = self.fin_vtext_idxs

    local candidate_idxs = {} ---@type integer[]

    local len_fin_vtext_idxs = #fin_vtext_idxs
    for i = 1, len_fin_vtext_idxs do
        local idx = fin_vtext_idxs[i]
        local label = fin_labels[idx]
        local len_label = #label

        local is_reusable = len_label > 0
        for j = 1, len_label do
            if not hashed_tokens[label[j]] then
                is_reusable = false
                break
            end
        end

        if is_reusable then
            candidate_idxs[#candidate_idxs + 1] = idx
        end
    end

    return candidate_idxs
end
-- TODO: candidate_idxs should be sized to some initial value

---@param start integer
---@param stop integer
---@param fin boolean
function Results:alloc_labels(start, stop, fin)
    assert((fin and self.fin_label_idxs or self.start_label_idxs) == vim.NIL)
    local label_idxs = fin and self:init_fin_label_idxs() or self:init_start_label_idxs()
    local labels = fin and self.fin_labels or self.start_labels
    local idxs = self.idxs

    for i = start, stop do
        local idx = idxs[i]
        label_idxs[#label_idxs + 1] = idx
        labels[idx] = {}
    end

    require("farsight.util").list_compact(idxs, start, stop + 1)
end
-- TODO: Start and stop need to be adjusted and converted to idx iters

---@param start integer
---@param stop integer
function Results:alloc_both_labels(start, stop)
    assert(self.both_label_idxs == vim.NIL)
    local label_idxs = self:init_both_label_idxs()
    local start_labels = self.start_labels
    local fin_labels = self.fin_labels
    local idxs = self.idxs

    for i = start, stop do
        local idx = idxs[i]
        label_idxs[#label_idxs + 1] = idx
        start_labels[idx] = {}
        fin_labels[idx] = {}
    end

    require("farsight.util").list_compact(idxs, start, stop + 1)
end
-- TODO: Start and stop need to be adjusted and converted to idx iters

return Results
