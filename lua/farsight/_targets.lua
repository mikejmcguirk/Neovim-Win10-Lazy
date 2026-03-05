---@class farsight.targets.Targets
---@field idxs_len integer
---@field idxs integer[]
---@field idxs_rev integer[]
---@field start_rows integer[]
---@field start_cols integer[]
---@field fin_rows integer[]
---@field fin_cols integer[]
---@field start_labels_start integer
---@field start_labels_fin integer
---@field start_labels string[][]
---@field start_vtexts [string, integer|string?][][]
---@field fin_labels_start integer
---@field fin_labels_fin integer
---@field fin_labels string[][]
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

    self.idxs_len = 0
    self.idxs = tn(size, 0)
    self.idxs_rev = tn(size, 0)

    self.start_rows = tn(size, 0)
    self.start_cols = tn(size, 0)
    self.fin_rows = tn(size, 0)
    self.fin_cols = tn(size, 0)

    self.start_labels_start = 0
    self.start_labels_fin = 0
    self.start_labels = tn(size, 0)
    self.start_vtexts = tn(size, 0)

    self.fin_labels_start = 0
    self.fin_labels_fin = 0
    self.fin_labels = tn(size, 0)
    self.fin_vtexts = tn(size, 0)
end

---@param row integer
---@param col integer
---@param fin_row integer
---@param fin_col integer
function M:add_new_target(row, col, fin_row, fin_col)
    local cur_idx_len = self.idxs_len
    local idxs_fwd = self.idxs

    local cur_last_idx = idxs_fwd[cur_idx_len] or 0
    local new_idx = cur_last_idx + 1

    self.idxs_len = cur_idx_len + 1
    idxs_fwd[self.idxs_len] = new_idx
    -- TODO: This is quite unfortunate if there are a lot of targets
    table.insert(self.idxs_rev, 1, new_idx)

    self.start_rows[new_idx] = row
    self.start_cols[new_idx] = col
    self.fin_rows[new_idx] = fin_row
    self.fin_cols[new_idx] = fin_col
    self.start_labels[new_idx] = vim.NIL
    self.start_vtexts[new_idx] = vim.NIL
    self.fin_labels[new_idx] = vim.NIL
    self.fin_vtexts[new_idx] = vim.NIL
end

function M:get_len()
    return self.idxs_len
end

-- TODO: Could these label checks be improved?

function M:has_start_labels()
    return self.start_labels_start > 0
        and self.start_labels_fin > 0
        and self.start_labels_start <= self.start_labels_fin
end

function M:has_fin_labels()
    return self.fin_labels_start > 0
        and self.fin_labels_fin > 0
        and self.fin_labels_start <= self.fin_labels_fin
end

---@param i integer
function M:rm_target(i)
    local init_idxs_len = self.idxs_len
    local rev_i = init_idxs_len - i + 1

    local j = i
    for k = i + 1, init_idxs_len do
        self.idxs[j] = self.idxs[k]
        j = j + 1
    end

    j = rev_i
    for k = rev_i + 1, init_idxs_len do
        self.idxs_rev[j] = self.idxs_rev[k]
        j = j + 1
    end

    self.idxs_len = init_idxs_len - 1
end
--
-- TODO: This also needs to properly handle label start and stop indexing
-- MAYBE: Values greater than idxs_len are currently not niled since this data structure is
-- assumed to be used ephemerally. If we find that we're keeping targets around, then check
-- the max value in idxs and nil everything after.

---@param idxs_len integer
---@param start? integer
---@param stop? integer
---@param rev? boolean
local function get_iter_positions(idxs_len, start, stop, rev)
    start = start or 1
    if start == 0 then
        start = idxs_len
    elseif start < 0 then
        start = idxs_len + start
    end

    stop = stop or idxs_len
    if stop == 0 then
        stop = idxs_len
    elseif stop < 0 then
        stop = idxs_len + stop
    end

    stop = math.min(stop, idxs_len)
    if start > stop then
        return 0, 0, 0
    end

    local iter = rev and -1 or 1
    local i = (rev and stop or start) - iter
    local limit = rev and start or stop

    return i, iter, limit
end

---@param self farsight.targets.Targets
---@return integer[], integer[]
local function get_start_positions(self)
    return self.start_rows, self.start_cols
end

---@param self farsight.targets.Targets
---@return string[][], [string, integer|string?][][]
local function get_start_extmark_info(self)
    return self.start_labels, self.start_vtexts
end

---@param self farsight.targets.Targets
---@return integer, integer
local function get_start_label_iters(self)
    return self.start_labels_start, self.start_labels_fin
end

---@param self farsight.targets.Targets
---@return integer[], integer[]
local function get_fin_positions(self)
    return self.fin_rows, self.fin_cols
end

---@param self farsight.targets.Targets
---@return string[][], [string, integer|string?][][]
local function get_fin_extmark_info(self)
    return self.fin_labels, self.fin_vtexts
end

---@param self farsight.targets.Targets
---@return integer, integer
local function get_fin_label_iters(self)
    return self.fin_labels_start, self.fin_labels_fin
end

---@param start? integer
---@param stop? integer
---@param rev? boolean
function M:iter_start_pos(start, stop, rev)
    local i, iter, limit = get_iter_positions(self.idxs_len, start, stop, rev)
    if iter == 0 then
        return function()
            return nil
        end
    end

    local idxs_fwd = self.idxs
    local start_rows, start_cols = get_start_positions(self)

    return function()
        i = i + iter
        if (iter > 0 and i > limit) or (iter < 0 and i < limit) then
            return nil
        end

        local idx = idxs_fwd[i]
        return i, idx, start_rows[idx], start_cols[idx]
    end
end

---@param start? integer
---@param stop? integer
---@param rev? boolean
function M:iter_fin_rows(start, stop, rev)
    local i, iter, limit = get_iter_positions(self.idxs_len, start, stop, rev)
    if iter == 0 then
        return function()
            return nil
        end
    end

    local idxs_fwd = self.idxs
    local fin_rows = self.fin_rows

    return function()
        i = i + iter
        if (iter > 0 and i > limit) or (iter < 0 and i < limit) then
            return nil
        end

        local idx = idxs_fwd[i]
        return i, idx, fin_rows[idx]
    end
end

---@param start? integer
---@param stop? integer
---@param rev? boolean
function M:iter_fin_pos(start, stop, rev)
    local i, iter, limit = get_iter_positions(self.idxs_len, start, stop, rev)
    if iter == 0 then
        return function()
            return nil
        end
    end

    local idxs_fwd = self.idxs
    local fin_rows, fin_cols = get_fin_positions(self)

    return function()
        i = i + iter
        if (iter > 0 and i > limit) or (iter < 0 and i < limit) then
            return nil
        end

        local idx = idxs_fwd[i]
        return i, idx, fin_rows[idx], fin_cols[idx]
    end
end

---@return fun():start_row: integer|nil, start_col: integer|nil, start_vtext: [string,integer|string?][]|nil
function M:iter_start_vtexts()
    local idxs = self.idxs
    local start_rows, start_cols = get_start_positions(self)
    local start_vtexts = self.start_vtexts

    local iter_start, iter_fin = get_start_label_iters(self)
    local i = iter_start - 1

    ---@return integer|nil, integer|nil, [string, integer|string?][]|nil
    return function()
        i = i + 1
        if i > iter_fin then
            return nil
        end

        local idx = idxs[i]
        return start_rows[idx], start_cols[idx], start_vtexts[idx]
    end
end

---@return fun():fin_row: integer|nil, fin_col: integer|nil, fin_vtext: [string,integer|string?][]|nil
function M:iter_fin_vtexts()
    local idxs = self.idxs
    local fin_rows, fin_cols = get_fin_positions(self)
    local fin_vtexts = self.fin_vtexts

    local iter_start, iter_fin = get_fin_label_iters(self)
    local i = iter_start - 1

    ---@return integer|nil, integer|nil, [string, integer|string?][]|nil
    return function()
        i = i + 1
        if i > iter_fin then
            return nil, nil, nil
        end

        local idx = idxs[i]
        return fin_rows[idx], fin_cols[idx], fin_vtexts[idx]
    end
end

---@param start? integer
---@param stop? integer
---@param rev? boolean
---@param stop_on_keep? boolean
---@param predicate fun(start_row: integer): boolean
function M:filter_start_row(start, stop, rev, stop_on_keep, predicate)
    local len = self.idxs_len
    if len == 0 then
        return
    end

    local i, iter, limit = get_iter_positions(len, start, stop, rev)
    if iter == 0 then
        return
    end

    i = i + iter

    local idxs_fwd = self.idxs
    local start_rows = self.start_rows

    while true do
        if (iter > 0 and i > limit) or (iter < 0 and i < limit) then
            break
        end

        local idx = idxs_fwd[i]
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
function M:filter_pos(start, stop, rev, stop_on_keep, predicate)
    local len = self.idxs_len
    if len == 0 then
        return
    end

    local i, iter, limit = get_iter_positions(len, start, stop, rev)
    if iter == 0 then
        return
    end

    i = i + iter

    local idxs_fwd = self.idxs
    local start_rows, start_cols = get_start_positions(self)
    local fin_rows, fin_cols = get_fin_positions(self)

    while true do
        if (iter > 0 and i > limit) or (iter < 0 and i < limit) then
            break
        end

        local idx = idxs_fwd[i]
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

---@param start? integer
---@param stop? integer
---@param rev? boolean
---@param mapper fun(start_row: integer, start_col: integer): integer, integer
function M:map_start_pos(start, stop, rev, mapper)
    local len = self.idxs_len
    if len == 0 then
        return
    end

    local i, iter, limit = get_iter_positions(len, start, stop, rev)
    if iter == 0 then
        return
    end

    i = i + iter

    local idxs_fwd = self.idxs
    local start_rows, start_cols = get_start_positions(self)

    while true do
        if (iter > 0 and i > limit) or (iter < 0 and i < limit) then
            break
        end

        local idx = idxs_fwd[i]
        local start_row = start_rows[idx]
        local start_col = start_cols[idx]

        local new_start_row, new_start_col = mapper(start_row, start_col)
        start_rows[idx] = new_start_row
        start_cols[idx] = new_start_col

        i = i + iter
    end
end

---@param start? integer
---@param stop? integer
---@param rev? boolean
---@param mapper fun(start_row: integer, start_col: integer): integer, integer
function M:map_fin_pos(start, stop, rev, mapper)
    local len = self.idxs_len
    if len == 0 then
        return
    end

    local i, iter, limit = get_iter_positions(len, start, stop, rev)
    if iter == 0 then
        return
    end

    i = i + iter

    local idxs_fwd = self.idxs
    local fin_rows, fin_cols = get_fin_positions(self)

    while true do
        if (iter > 0 and i > limit) or (iter < 0 and i < limit) then
            break
        end

        local idx = idxs_fwd[i]
        local fin_row = fin_rows[idx]
        local fin_col = fin_cols[idx]

        local new_fin_row, new_fin_col = mapper(fin_row, fin_col)
        fin_rows[idx] = new_fin_row
        fin_cols[idx] = new_fin_col

        i = i + iter
    end
end

---@param start? integer
---@param stop? integer
---@param rev? boolean
---@param mapper fun(start_row: integer, start_col: integer, fin_row: integer, fin_col: integer): integer, integer, integer, integer
function M:map_pos(start, stop, rev, mapper)
    local len = self.idxs_len
    if len == 0 then
        return
    end

    local i, iter, limit = get_iter_positions(len, start, stop, rev)
    if iter == 0 then
        return
    end

    i = i + iter

    local idxs_fwd = self.idxs
    local start_rows, start_cols = get_start_positions(self)
    local fin_rows, fin_cols = get_fin_positions(self)

    while true do
        if (iter > 0 and i > limit) or (iter < 0 and i < limit) then
            break
        end

        local idx = idxs_fwd[i]
        local start_row = start_rows[idx]
        local start_col = start_cols[idx]
        local fin_row = fin_rows[idx]
        local fin_col = fin_cols[idx]

        local new_start_row, new_start_col, new_fin_row, new_fin_col =
            mapper(start_row, start_col, fin_row, fin_col)
        start_rows[idx] = new_start_row
        start_cols[idx] = new_start_col
        fin_rows[idx] = new_fin_row
        fin_cols[idx] = new_fin_col

        i = i + iter
    end
end

---@param start? integer
---@param stop? integer
---@param rev? boolean
function M:iter_alloc_start_labels(start, stop, rev)
    local len = self.idxs_len
    if len == 0 then
        return
    end

    local i, iter, limit = get_iter_positions(len, start, stop, rev)
    if iter == 0 then
        return
    end

    local idxs = self.idxs
    local start_labels = self.start_labels
    self.start_labels_start = math.max(math.min(i, limit), 1)
    self.start_labels_fin = math.max(math.max(i, limit), 1)

    return function()
        i = i + iter
        if (iter > 0 and i > limit) or (iter < 0 and i < limit) then
            return nil
        end

        local idx = idxs[i]
        local start_label = {}
        start_labels[idx] = start_label

        return start_label
    end
end

---@param start? integer
---@param stop? integer
---@param rev? boolean
function M:iter_alloc_fin_labels(start, stop, rev)
    local len = self.idxs_len
    if len == 0 then
        return
    end

    local i, iter, limit = get_iter_positions(len, start, stop, rev)
    if iter == 0 then
        return
    end

    local idxs = self.idxs
    local fin_labels = self.fin_labels
    self.fin_labels_start = math.max(math.min(i, limit), 1)
    self.fin_labels_fin = math.max(math.max(i, limit), 1)

    return function()
        i = i + iter
        if (iter > 0 and i > limit) or (iter < 0 and i < limit) then
            return nil
        end

        local idx = idxs[i]
        local fin_label = {}
        fin_labels[idx] = fin_label

        return fin_label
    end
end

---@param start? integer
---@param stop? integer
---@param rev? boolean
function M:iter_alloc_both_labels(start, stop, rev)
    local len = self.idxs_len
    if len == 0 then
        return
    end

    local i, iter, limit = get_iter_positions(len, start, stop, rev)
    if iter == 0 then
        return
    end

    local idxs = self.idxs
    local start_labels = self.start_labels
    local fin_labels = self.fin_labels
    self.start_labels_start = math.max(math.min(i, limit), 1)
    self.start_labels_fin = math.max(math.max(i, limit), 1)
    self.fin_labels_start = math.max(math.min(i, limit), 1)
    self.fin_labels_fin = math.max(math.max(i, limit), 1)

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

---@param mapper fun(label: string[]): [string, integer|string?][]
function M:map_start_vtext_from_labels(mapper)
    if not self:has_start_labels() then
        return
    end

    local idxs = self.idxs
    local start_labels, start_vtexts = get_start_extmark_info(self)

    local iter_start, iter_fin = get_start_label_iters(self)
    if iter_start == 0 or iter_fin == 0 then
        return
    end

    for i = iter_start, iter_fin do
        local idx = idxs[i]
        start_vtexts[idx] = mapper(start_labels[idx])
    end
end

---@param mapper fun(label: string[], available: integer): [string, integer|string?][]
function M:map_start_vtexts_from_labels_cmp_next_start(mapper)
    if not self:has_start_labels() then
        return
    end

    local idxs = self.idxs
    local start_rows, start_cols = get_start_positions(self)
    local start_labels, start_vtexts = get_start_extmark_info(self)

    local col_distance = require("farsight.util").col_distance

    local iter_start, iter_fin = get_start_label_iters(self)
    local most_labels = iter_fin - 1
    for i = iter_start, most_labels do
        local idx = idxs[i]
        local next_idx = idxs[i + 1]

        local start_row = start_rows[idx]
        local start_col = start_cols[idx]
        local next_start_row = start_rows[next_idx]
        local next_start_col = start_cols[next_idx]

        local available = col_distance(start_row, start_col, next_start_row, next_start_col)
        start_vtexts[idx] = mapper(start_labels[idx], available)
    end

    local idx = idxs[iter_fin]
    start_vtexts[idx] = mapper(start_labels[idx], vim.v.maxcol)
end

---@param mapper fun(label: string[], available: integer): [string, integer|string?][]
function M:map_start_vtexts_from_labels_cmp_fin(mapper)
    if not self:has_start_labels() then
        return
    end

    local idxs = self.idxs
    local start_rows, start_cols = get_start_positions(self)
    local start_labels, start_vtexts = get_start_extmark_info(self)
    local fin_rows, fin_cols = get_fin_positions(self)

    local col_distance = require("farsight.util").col_distance

    local iter_start, iter_fin = get_start_label_iters(self)
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

---@param mapper fun(label: string[]): [string, integer|string?][]
function M:map_fin_vtext_from_labels(mapper)
    if not self:has_fin_labels() then
        return
    end

    local idxs = self.idxs
    local fin_labels, fin_vtexts = get_fin_extmark_info(self)

    local iter_start, iter_fin = get_fin_label_iters(self)
    for i = iter_start, iter_fin do
        local idx = idxs[i]
        fin_vtexts[idx] = mapper(fin_labels[idx])
    end
end

---@param mapper fun(label: string[], available: integer): [string, integer|string?][]
function M:map_fin_vtexts_from_labels_cmp_next_start(mapper)
    if not self:has_fin_labels() then
        return
    end

    local idxs = self.idxs
    local fin_rows, fin_cols = get_fin_positions(self)
    local fin_labels, fin_vtexts = get_fin_extmark_info(self)
    local start_rows, start_cols = get_start_positions(self)

    local col_distance = require("farsight.util").col_distance

    local iter_start, iter_fin = get_fin_label_iters(self)
    local most_labels = iter_fin - 1
    for i = iter_start, most_labels do
        local idx = idxs[i]
        local next_idx = idxs[i + 1]

        local fin_row = fin_rows[idx]
        local fin_col = fin_cols[idx]
        local start_row = start_rows[next_idx]
        local start_col = start_cols[next_idx]

        local available = col_distance(fin_row, fin_col, start_row, start_col)
        fin_vtexts[idx] = mapper(fin_labels[idx], available)
    end

    local idx = idxs[iter_fin]
    fin_vtexts[idx] = mapper(fin_labels[idx], vim.v.maxcol)
end

---@param mapper fun(label: string[], available: integer): [string, integer|string?][]
function M:map_fin_vtexts_from_labels_cmp_next_fin(mapper)
    if not self:has_fin_labels() then
        return
    end

    local idxs = self.idxs
    local fin_rows, fin_cols = get_fin_positions(self)
    local fin_labels, fin_vtexts = get_fin_extmark_info(self)

    local col_distance = require("farsight.util").col_distance

    local iter_start, iter_fin = get_fin_label_iters(self)
    local most_labels = iter_fin - 1
    for i = iter_start, most_labels do
        local idx = idxs[i]
        local next_idx = idxs[i + 1]

        local fin_row = fin_rows[idx]
        local fin_col = fin_cols[idx]
        local next_fin_row = fin_rows[next_idx]
        local next_fin_col = fin_cols[next_idx]

        local available = col_distance(fin_row, fin_col, next_fin_row, next_fin_col)
        fin_vtexts[idx] = mapper(fin_labels[idx], available)
    end

    local idx = idxs[iter_fin]
    fin_vtexts[idx] = mapper(fin_labels[idx], vim.v.maxcol)
end

---@param idx integer
---@param fin_row integer
---@param fin_col integer
function M:set_fin_pos_from_idx(idx, fin_row, fin_col)
    self.fin_rows[idx] = fin_row
    self.fin_cols[idx] = fin_col
end

return M

-- NOTE: For any fin label placements, we are purposefully utilizing end-exclusive indexing to
-- put the label directly after the search term.

-- TODO: Try to do every iteration without the rev list. If we can use iterators + logic in here,
-- that would reduce complexity surface area.
-- TODO: The double-wrapped label iter limits are very hacky.
--
-- LOW: For the virt text fills, it is technically inefficient to always calculate the space
-- available between the target label and the next one. It is also not that slow (just arithmetic)
-- and vastly simplifies the logic. So I'm loathe to change it.
