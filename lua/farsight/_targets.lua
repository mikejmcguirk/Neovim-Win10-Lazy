local vimv = vim.v

---@class farsight.targets.Targets
---@field idxs integer[]
---@field next_idx integer
---@field start_label_idx_ref integer[]
---@field start_label_idxs integer[]
---@field fin_label_idx_ref integer[]
---@field fin_label_idxs integer[]
---@field char_label_idx_ref integer[]
---@field char_label_idxs integer[]
---@field start_rows integer[]
---@field start_cols integer[]
---@field fin_rows integer[]
---@field fin_cols integer[]
---@field start_labels string[][]
---@field fin_labels string[][]
---@field char_labels string[]
---@field start_vtexts [string, integer|string?][][]
---@field fin_vtexts [string, integer|string?][][]
local M = {}
M.__index = M

---@param size integer
---@return farsight.targets.Targets
function M.new(size)
    local self = setmetatable({}, M)
    self:init(size)
    return self
end

---@param size integer
function M:init(size)
    local tn = require("farsight.util")._table_new

    self.idxs = tn(size, 0)
    self.next_idx = 1

    self.start_label_idx_ref = tn(size, 0)
    self.start_label_idxs = tn(size, 0)

    self.fin_label_idx_ref = tn(size, 0)
    self.fin_label_idxs = tn(size, 0)

    self.char_label_idx_ref = tn(size, 0)
    self.char_label_idxs = tn(size, 0)

    self.start_rows = tn(size, 0)
    self.start_cols = tn(size, 0)
    self.fin_rows = tn(size, 0)
    self.fin_cols = tn(size, 0)

    self.start_labels = tn(size, 0)
    self.fin_labels = tn(size, 0)
    self.char_labels = tn(size, 0)

    self.start_vtexts = tn(size, 0)
    self.fin_vtexts = tn(size, 0)
end
-- TODO: Consider how the sizing can be smarter. If we're cursor aware, might we allocate half of
-- the full size to start and fin labels? Based on bytes being searched, might we allocate more or
-- fewer char idxs? If default size is 32, we're getting to half a kilobyte in allocated data (not
-- including whatever superstructure LuaJIT puts around it).

---@param row integer
---@param col integer
---@param fin_row integer
---@param fin_col integer
function M:add_new_target(row, col, fin_row, fin_col)
    local idxs = self.idxs
    local new_len_idxs = #idxs + 1

    self.start_label_idx_ref[new_len_idxs] = 0
    self.fin_label_idx_ref[new_len_idxs] = 0
    self.char_label_idx_ref[new_len_idxs] = 0

    local next_idx = self.next_idx
    idxs[new_len_idxs] = next_idx

    self.start_rows[next_idx] = row
    self.start_cols[next_idx] = col
    self.fin_rows[next_idx] = fin_row
    self.fin_cols[next_idx] = fin_col

    self.start_labels[next_idx] = vim.NIL
    self.fin_labels[next_idx] = vim.NIL
    self.char_labels[next_idx] = "" -- Should be fine because of interning

    self.start_vtexts[next_idx] = vim.NIL
    self.fin_vtexts[next_idx] = vim.NIL

    -- Avoid scanning for a viable idx if next_idx < len_idxs due to a deletion
    self.next_idx = new_len_idxs
end

---Errors if an invalid index is provided.
---@param i integer
---@param char string
function M:add_char_label(i, char)
    local idxs = self.idxs
    assert(i >= 1 and i <= #idxs, "Cannot access an out of bounds target")

    local char_label_idxs = self.char_label_idxs
    local len_char_label_idxs = #char_label_idxs
    local new_len_char_label_idxs = len_char_label_idxs + 1
    local idx = idxs[i]
    char_label_idxs[new_len_char_label_idxs] = idx

    self.char_label_idx_ref[i] = new_len_char_label_idxs
    self.char_labels[i] = char
end

---@return integer
function M:get_len()
    return #self.idxs
end

---@return integer
function M:get_count_char_labels()
    return #self.char_label_idxs
end

---@param i integer
---@param label_idx_ref integer[]
---@param label_idxs integer[]
local function clear_label(i, label_idx_ref, label_idxs)
    local label_idx = label_idx_ref[i]
    if label_idx > 0 then
        local len_label_idxs = #label_idxs
        local j = label_idx
        for k = i + 1, len_label_idxs do
            label_idxs[j] = label_idxs[k]
            j = j + 1
        end

        label_idxs[len_label_idxs] = nil
    end
end

---Errors if an invalid index is provided.
---@param i integer
function M:rm_target(i)
    local idxs = self.idxs
    local old_len_idxs = #idxs
    assert(i >= 1 and i <= old_len_idxs, "Cannot delete an out of bounds target")

    local rm_idx = idxs[i]

    self.start_rows[rm_idx] = -1
    self.start_cols[rm_idx] = -1
    self.fin_rows[rm_idx] = -1
    self.fin_cols[rm_idx] = -1

    self.start_labels[rm_idx] = vim.NIL
    self.fin_labels[rm_idx] = vim.NIL
    self.char_labels[rm_idx] = ""

    self.start_vtexts[rm_idx] = vim.NIL
    self.fin_vtexts[rm_idx] = vim.NIL

    local start_label_idx_ref = self.start_label_idx_ref
    local fin_label_idx_ref = self.fin_label_idx_ref
    local char_label_idx_ref = self.char_label_idx_ref

    clear_label(i, start_label_idx_ref, self.start_label_idxs)
    clear_label(i, fin_label_idx_ref, self.fin_label_idxs)
    clear_label(i, char_label_idx_ref, self.char_label_idxs)

    local j = i
    for k = i + 1, old_len_idxs do
        idxs[j] = idxs[k]
        start_label_idx_ref[j] = self.start_label_idx_ref[k]
        fin_label_idx_ref[j] = self.fin_label_idx_ref[k]
        char_label_idx_ref[j] = self.char_label_idx_ref[k]
        j = j + 1
    end

    idxs[old_len_idxs] = nil
    start_label_idx_ref[old_len_idxs] = nil
    fin_label_idx_ref[old_len_idxs] = nil
    char_label_idx_ref[old_len_idxs] = nil

    self.next_idx = rm_idx
end
-- MAYBE: I'm not sure it's worthwhile in practice, but some ideas for re-using space:
-- - Compacting the table every X deletes
-- - Saving a list of open idxs
-- Counterpoint (and a potential issue with currently setting tables to vim.NIL), it is bad to
-- trigger garbage collection during hot paths.

---@param input integer|nil
---@param default integer
---@param idxs_len integer
---@return integer
local function adj_iter_input(input, default, idxs_len)
    input = input or default
    if input <= 0 then
        return idxs_len + input
    else
        return math.min(input, idxs_len)
    end
end

---Returns standard 1 indexed, inclusive iterator bounds.
---If input is invalid (start > stop), then 0, 0, 0 are returned.
---If rev is true, the iteration will be from stop to start.
---@param idxs_len integer
---@param start? integer
---@param stop? integer
---@param rev? boolean
---@return integer, integer, integer
local function get_pos_iter_bounds(idxs_len, start, stop, rev)
    if idxs_len <= 0 then
        return 0, 0, 0
    end

    start = adj_iter_input(start, 1, idxs_len)
    stop = adj_iter_input(stop, idxs_len, idxs_len)
    if start > stop then
        return 0, 0, 0
    end

    local i = rev and stop or start
    local limit = rev and start or stop
    local iter = rev and -1 or 1

    return i, limit, iter
end

---@param self farsight.targets.Targets
---@return integer[], integer[]
local function get_positions(self, fin)
    local rows = fin and self.fin_rows or self.start_rows
    local cols = fin and self.fin_cols or self.start_cols
    return rows, cols
end

---@param self farsight.targets.Targets
---@return integer[], integer[], integer[], integer[]
local function get_all_positions(self)
    return self.start_rows, self.start_cols, self.fin_rows, self.fin_cols
end

---@param self farsight.targets.Targets
---@param fin boolean
---@return integer, integer
local function get_label_iters(self, fin)
    local ls = fin and self.fin_labels_start or self.start_labels_start
    local lf = fin and self.fin_labels_fin or self.start_labels_fin
    assert(ls <= lf)
    assert((ls == 0) == (lf == 0))
    return ls, lf
end

---@param self farsight.targets.Targets
---@return string[][], [string, integer|string?][][]
local function get_extmark_info(self, fin)
    local labels = fin and self.fin_labels or self.start_labels
    local vtexts = fin and self.fin_vtexts or self.start_vtexts
    return labels, vtexts
end

---@param self farsight.targets.Targets
---@param start? integer
---@param stop? integer
---@param rev? boolean
---@param fin boolean
---@return fun(): i:integer|nil, start_row:integer|nil, start_col:integer|nil
local function iter_pos(self, start, stop, rev, fin)
    local idxs = self.idxs
    local i, limit, iter = get_pos_iter_bounds(#idxs, start, stop, rev)
    if iter == 0 then
        ---@return nil, nil, nil
        return function()
            return nil, nil, nil
        end
    end

    i = i - iter
    local rows, cols = get_positions(self, fin)

    ---@return integer|nil, integer|nil, integer|nil
    return function()
        i = i + iter
        if (iter > 0 and i > limit) or (iter < 0 and i < limit) then
            return nil, nil, nil
        end

        local idx = idxs[i]
        return i, rows[idx], cols[idx]
    end
end

---@param start? integer
---@param stop? integer
---@param rev? boolean
---@return fun(): i:integer|nil, start_row:integer|nil, start_col:integer|nil
function M:iter_start_pos(start, stop, rev)
    return iter_pos(self, start, stop, rev, false)
end

---@param start? integer
---@param stop? integer
---@param rev? boolean
---@return fun(): i:integer|nil, fin_row:integer|nil, fin_col:integer|nil
function M:iter_fin_pos(start, stop, rev)
    return iter_pos(self, start, stop, rev, true)
end

---@param start? integer
---@param stop? integer
---@param rev? boolean
---@return fun(): i:integer|nil, fin_row:integer|nil
function M:iter_fin_rows(start, stop, rev)
    local idxs = self.idxs
    local i, limit, iter = get_pos_iter_bounds(#idxs, start, stop, rev)
    if iter == 0 then
        ---@return nil, nil
        return function()
            return nil
        end
    end

    i = i - iter
    local fin_rows = self.fin_rows

    ---@return integer|nil, integer|nil
    return function()
        i = i + iter
        if (iter > 0 and i > limit) or (iter < 0 and i < limit) then
            return nil
        end

        return i, fin_rows[idxs[i]]
    end
end

---@param self farsight.targets.Targets
---@param vtexts [string, integer|string?][]
---@param fin boolean
---@return fun(): row:integer|nil, col:integer|nil, vtext:[string, integer|string?][]|nil
local function iter_vtexts(self, vtexts, fin)
    local i, limit = get_label_iters(self, fin)
    if i == 0 then
        ---@return nil, nil, nil
        return function()
            return nil, nil, nil
        end
    end

    i = i - 1
    local idxs = self.idxs
    local rows, cols = get_positions(self, fin)

    ---@return integer|nil, integer|nil, [string, integer|string?][]|nil
    return function()
        i = i + 1
        if i > limit then
            return nil, nil, nil
        end

        local idx = idxs[i]
        return rows[idx], cols[idx], vtexts[idx]
    end
end

---@return fun():start_row: integer|nil, start_col: integer|nil, start_vtext: [string,integer|string?][]|nil
function M:iter_start_vtexts()
    return iter_vtexts(self, self.start_vtexts, false)
end

---@return fun():fin_row: integer|nil, fin_col: integer|nil, fin_vtext: [string,integer|string?][]|nil
function M:iter_fin_vtexts()
    return iter_vtexts(self, self.fin_vtexts, true)
end

---@param start? integer
---@param stop? integer
---@param rev? boolean
---@param stop_on_keep? boolean
---@param predicate fun(start_row: integer): boolean
function M:filter_start_row(start, stop, rev, stop_on_keep, predicate)
    local idxs = self.idxs
    local len_idxs = #idxs
    if len_idxs == 0 then
        return
    end

    local start_rows = self.start_rows
    local i, limit, iter = get_pos_iter_bounds(len_idxs, start, stop, rev)
    if iter == 0 then
        return
    end

    while true do
        if (iter > 0 and i > limit) or (iter < 0 and i < limit) then
            break
        end

        local idx = idxs[i]
        local start_row = start_rows[idx]

        if not predicate(start_row) then
            self:rm_target(i)
            if rev then
                i = i + iter
            end
        elseif stop_on_keep then
            break
        else
            i = i + iter
        end
    end
end
--
-- LOW: If the if logic in here is really a problem, can make this a fwd only function, since
-- reverse filtering can be handled with iteration.

---@param start? integer
---@param stop? integer
---@param rev? boolean
---@param stop_on_keep? boolean
---@param predicate fun(start_row: integer, start_col: integer, fin_row: integer, fin_col: integer): boolean
function M:filter_both_pos(start, stop, rev, stop_on_keep, predicate)
    local idxs = self.idxs
    local len_idxs = #idxs
    if len_idxs == 0 then
        return
    end

    local start_rows, start_cols, fin_rows, fin_cols = get_all_positions(self)
    local i, limit, iter = get_pos_iter_bounds(len_idxs, start, stop, rev)
    if iter == 0 then
        return
    end

    while true do
        if (iter > 0 and i > limit) or (iter < 0 and i < limit) then
            break
        end

        local idx = idxs[i]
        local start_row = start_rows[idx]
        local start_col = start_cols[idx]
        local fin_row = fin_rows[idx]
        local fin_col = fin_cols[idx]

        if not predicate(start_row, start_col, fin_row, fin_col) then
            self:rm_target(i)
            if rev then
                i = i + iter
            end
        elseif stop_on_keep then
            break
        else
            i = i + iter
        end
    end
end
--
-- LOW: If the if logic in here is really a problem, can make this a fwd only function, since
-- reverse filtering can be handled with iteration.

---@param self farsight.targets.Targets
---@param start? integer
---@param stop? integer
---@param rev? boolean
---@param mapper fun(start_row: integer, start_col: integer): integer, integer
---@param fin boolean
local function map_pos(self, start, stop, rev, mapper, fin)
    local idxs = self.idxs
    local len_idxs = #idxs
    if len_idxs == 0 then
        return
    end

    local rows, cols = get_positions(self, fin)
    local i, limit, iter = get_pos_iter_bounds(len_idxs, start, stop, rev)
    if iter == 0 then
        return
    end

    while true do
        if (iter > 0 and i > limit) or (iter < 0 and i < limit) then
            break
        end

        local idx = idxs[i]
        local row = rows[idx]
        local col = cols[idx]

        rows[idx], cols[idx] = mapper(row, col)
        i = i + iter
    end
end

---@param start? integer
---@param stop? integer
---@param rev? boolean
---@param mapper fun(start_row: integer, start_col: integer): integer, integer
function M:map_start_pos(start, stop, rev, mapper)
    map_pos(self, start, stop, rev, mapper, false)
end

---@param start? integer
---@param stop? integer
---@param rev? boolean
---@param mapper fun(start_row: integer, start_col: integer): integer, integer
function M:map_fin_pos(start, stop, rev, mapper)
    map_pos(self, start, stop, rev, mapper, true)
end

---@param start? integer
---@param stop? integer
---@param rev? boolean
---@param mapper fun(start_row: integer, start_col: integer, fin_row: integer, fin_col: integer): integer, integer, integer, integer
function M:map_both_pos(start, stop, rev, mapper)
    local idxs = self.idxs
    local len_idxs = #idxs
    if len_idxs == 0 then
        return
    end

    local i, limit, iter = get_pos_iter_bounds(len_idxs, start, stop, rev)
    if iter == 0 then
        return
    end

    local start_rows, start_cols, fin_rows, fin_cols = get_all_positions(self)
    while true do
        if (iter > 0 and i > limit) or (iter < 0 and i < limit) then
            break
        end

        local idx = idxs[i]
        local start_row = start_rows[idx]
        local start_col = start_cols[idx]
        local fin_row = fin_rows[idx]
        local fin_col = fin_cols[idx]

        start_rows[idx], start_cols[idx], fin_rows[idx], fin_cols[idx] =
            mapper(start_row, start_col, fin_row, fin_col)

        i = i + iter
    end
end

---@param self farsight.targets.Targets
---@param start? integer
---@param stop? integer
---@param rev? boolean
---@param fin boolean
---@return fun(): label:string[]|nil
local function iter_alloc_labels(self, start, stop, rev, fin)
    local idxs = self.idxs
    local len_idxs = #idxs
    if len_idxs == 0 then
        ---@return nil
        return function()
            return nil
        end
    end

    local i, limit, iter = get_pos_iter_bounds(len_idxs, start, stop, rev)
    if iter == 0 then
        ---@return nil
        return function()
            return nil
        end
    end

    local labels = fin and self.fin_labels or self.start_labels

    local labels_start = math.min(i, limit)
    local labels_fin = math.max(i, limit)
    if fin then
        self.fin_labels_start = labels_start
        self.fin_labels_fin = labels_fin
    else
        self.start_labels_start = labels_start
        self.start_labels_fin = labels_fin
    end

    i = i - iter

    ---@return string[]|nil
    return function()
        i = i + iter
        if (iter > 0 and i > limit) or (iter < 0 and i < limit) then
            return nil
        end

        local idx = idxs[i]
        local label = {}
        labels[idx] = label

        return label
    end
end

---@param start? integer
---@param stop? integer
---@param rev? boolean
function M:iter_alloc_start_labels(start, stop, rev)
    return iter_alloc_labels(self, start, stop, rev, false)
end

---@param start? integer
---@param stop? integer
---@param rev? boolean
function M:iter_alloc_fin_labels(start, stop, rev)
    return iter_alloc_labels(self, start, stop, rev, true)
end

---@param start? integer
---@param stop? integer
---@param rev? boolean
---@return fun(): label_1:string[]|nil, label_2:string[]|nil
function M:iter_alloc_both_labels(start, stop, rev)
    local idxs = self.idxs
    local len_idxs = #idxs
    if len_idxs == 0 then
        ---@return nil
        return function()
            return nil
        end
    end

    local i, limit, iter = get_pos_iter_bounds(len_idxs, start, stop, rev)
    if iter == 0 then
        ---@return nil
        return function()
            return nil
        end
    end

    i = i - iter
    local start_labels = self.start_labels
    local fin_labels = self.fin_labels
    self.start_labels_start = math.min(i, limit)
    self.start_labels_fin = math.max(i, limit)
    self.fin_labels_start = math.min(i, limit)
    self.fin_labels_fin = math.max(i, limit)

    ---@return string[]|nil, string[]|nil
    return function()
        i = i + iter
        if (iter > 0 and i > limit) or (iter < 0 and i < limit) then
            return nil
        end

        local idx = idxs[i]
        local start_label = {}
        start_labels[idx] = start_label
        local fin_label = {}
        fin_labels[idx] = fin_label
        if rev then
            return fin_label, start_label
        else
            return start_label, fin_label
        end
    end
end

---@param self farsight.targets.Targets
---@param mapper fun(label: string[]): [string, integer|string?][]
---@param fin boolean
local function map_vtext_from_labels(self, mapper, fin)
    local iter_start, iter_fin = get_label_iters(self, fin)
    if iter_start == 0 or iter_fin == 0 then
        return
    end

    local idxs = self.idxs
    local labels, vtexts = get_extmark_info(self, fin)

    for i = iter_start, iter_fin do
        local idx = idxs[i]
        vtexts[idx] = mapper(labels[idx])
    end
end

---@param mapper fun(label: string[]): [string, integer|string?][]
function M:map_start_vtext_from_labels(mapper)
    map_vtext_from_labels(self, mapper, false)
end

---@param mapper fun(label: string[]): [string, integer|string?][]
function M:map_fin_vtext_from_labels(mapper)
    map_vtext_from_labels(self, mapper, true)
end

---Does not verify that start and stop are valid.
---@param start integer
---@param stop integer
---@param idxs integer[]
---@param r integer[]
---@param c integer[]
---@param n_r integer[]
---@param n_c integer[]
---@param labels string[][]
---@param vtexts [string, integer|string?][]
---@param mapper fun(label: string[], available: integer): [string, integer|string?][]
local function map_vtexts_cmp_next(start, stop, idxs, r, c, n_r, n_c, labels, vtexts, mapper)
    local col_distance = require("farsight.util").col_distance

    local most_labels = stop - 1
    for i = start, most_labels do
        local idx = idxs[i]
        local row = r[idx]
        local col = c[idx]

        local next_idx = idxs[i + 1]
        local next_row = n_r[next_idx]
        local next_col = n_c[next_idx]

        local available = col_distance(row, col, next_row, next_col)
        vtexts[idx] = mapper(labels[idx], available)
    end

    local idx = idxs[stop]
    vtexts[idx] = mapper(labels[idx], vimv.maxcol)
end

---@param self farsight.targets.Targets
---@param mapper fun(label: string[], available: integer): [string, integer|string?][]
---@param fin boolean
local function map_vtexts_from_labels_cmp_next_start(self, mapper, fin)
    local start, stop = get_label_iters(self, fin)
    if start == 0 or stop == 0 then
        return
    end

    local idxs = self.idxs
    local r, c = get_positions(self, fin)
    local start_r, start_c = get_positions(self, false)
    local l, vt = get_extmark_info(self, fin)

    map_vtexts_cmp_next(start, stop, idxs, r, c, start_r, start_c, l, vt, mapper)
end

---@param mapper fun(label: string[], available: integer): [string, integer|string?][]
function M:map_start_vtexts_from_labels_cmp_next_start(mapper)
    map_vtexts_from_labels_cmp_next_start(self, mapper, false)
end

---@param mapper fun(label: string[], available: integer): [string, integer|string?][]
function M:map_fin_vtexts_from_labels_cmp_next_start(mapper)
    map_vtexts_from_labels_cmp_next_start(self, mapper, true)
end

---@param mapper fun(label: string[], available: integer): [string, integer|string?][]
function M:map_start_vtexts_from_labels_cmp_fin(mapper)
    local iter_start, iter_fin = get_label_iters(self, false)
    if iter_start == 0 or iter_fin == 0 then
        return
    end

    local idxs = self.idxs
    local start_labels, start_vtexts = get_extmark_info(self, false)
    local start_rows, start_cols, fin_rows, fin_cols = get_all_positions(self)

    local col_distance = require("farsight.util").col_distance

    for i = iter_start, iter_fin do
        local idx = idxs[i]
        local start_row = start_rows[idx]
        local start_col = start_cols[idx]
        local fin_row = fin_rows[idx]
        local fin_col = fin_cols[idx]

        local available = col_distance(start_row, start_col, fin_row, fin_col)
        start_vtexts[idx] = mapper(start_labels[idx], available)
    end
end

---@param mapper fun(label: string[], available: integer): [string, integer|string?][]
function M:map_fin_vtexts_from_labels_cmp_next_fin(mapper)
    local start, stop = get_label_iters(self, true)
    if start == 0 or stop == 0 then
        return
    end

    local idxs = self.idxs
    local fin_r, fin_c = get_positions(self, true)
    local fin_l, fin_vt = get_extmark_info(self, true)
    map_vtexts_cmp_next(start, stop, idxs, fin_r, fin_c, fin_r, fin_c, fin_l, fin_vt, mapper)
end

---@param i integer
---@param fin_row integer
---@param fin_col integer
function M:set_fin_pos(i, fin_row, fin_col)
    local idx = self.idxs[i]
    self.fin_rows[idx] = fin_row
    self.fin_cols[idx] = fin_col
end
-- MID: This function creates redundancy because it has to get the idx after the iterator has
-- already done so. But it seems wasteful to create a complicated mapping function for one case,
-- and I don't want the iterators exposing idx.

return M

-- NOTE: For any fin label placements, we are purposefully utilizing end-exclusive indexing to
-- put the label directly after the search term.

-- TODO: We are going to do the unique char jump thing.
--
-- For possible labels, I'll pull len and char labels manually because I don't want to tie that
-- logic to this data structure. But then on the other hand, the label adding iteration here has
-- to skip char labels, so... maybe do that?
-- *technically*, from a data perspective, char_labels and fin_labels are mututally exclusive since
-- char labels write where fin_vtext would. You absolutely would block writing a fin label if a
-- char label was present.
-- So I think for allocating fin labels you make the block mandatory and add a comment explaining
-- why. And then for start labels it can be optional.
-- and then for count possible label reporting, like, I can't think of a superset use case for
-- a fancy function so just do it manually
-- And then for allocating labels, it should take how many labels to allocate and a rev flag.
-- There's no need ever to manually specify indexing.
--
--
--
-- Final step is writing the char idx extmarks

--
-- TODO: char labels or unique labels?
