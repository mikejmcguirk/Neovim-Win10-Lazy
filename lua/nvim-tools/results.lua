---@class (exact) nvim-tools.Results
---
---@field active_idxs integer[]
---@field next_idx integer
---@field start_rows integer[]
---@field start_cols integer[]
---@field fin_rows integer[]
---@field fin_cols integer[]
---
---@field __index nvim-tools.Results
---@field new fun(size:integer): Results:nvim-tools.Results
local Results = {}
Results.__index = Results

---@brief All iterators are one indexed, as with other Lua constructs.
---The start iterator must be at least one, and is clamped to the length of the iterated list.
---The end iterator is also clamped to the length of the list.
---If the end iterator is zero or less, the limit will be the length minus that value.
---
---Example: 1, 0 - Iterate from the first index to the end
---Example: 1, -1 - Iterate from the first index to the second-to-last index

---@param start? integer
---@param stop? integer
---@param rev? boolean
---@param len integer
---@return integer, integer, integer
local function get_iters(start, stop, rev, len)
    start = start or 1
    stop = stop or len
    rev = rev or false

    if start <= 0 then
        error("Start iter index " .. start .. " cannot be less than one")
    end

    local init = math.min(start, len)
    local limit = stop <= 0 and len + stop or stop
    local iter = rev and -1 or 1

    return init, limit, iter
end
-- MAYBE: If we create an iterator that returns a function, this function needs a flag to
-- zero-index start (since the iterator always does one).

-----------------
-- MARK: Utils --
-----------------

---Returns the active references
---@param fin boolean
---@return integer[], integer[]
function Results:get_pos(fin)
    if fin then
        return self.fin_rows, self.fin_cols
    else
        return self.start_rows, self.start_cols
    end
end

-- Returns the active references
---@return integer[], integer[], integer[], integer[]
function Results:get_both_pos()
    return self.start_rows, self.start_cols, self.fin_rows, self.fin_cols
end

--------------------------
-- MARK: Initialization --
--------------------------

---@param size integer
---@return nvim-tools.Results
function Results.new(size)
    local self = setmetatable({}, Results)
    local tn = require("nvim-tools.table").new

    self.next_idx = 1
    self.active_idxs = tn(size, 0)

    self.start_rows = tn(size, 0)
    self.start_cols = tn(size, 0)
    self.fin_rows = tn(size, 0)
    self.fin_cols = tn(size, 0)

    return self
end

---@param start_row integer
---@param start_col integer
---@param fin_row integer
---@param fin_col integer
function Results:append(start_row, start_col, fin_row, fin_col)
    local next_idx = self.next_idx

    self.active_idxs[#self.active_idxs + 1] = next_idx
    self.start_rows[next_idx] = start_row
    self.start_cols[next_idx] = start_col
    self.fin_rows[next_idx] = fin_row
    self.fin_cols[next_idx] = fin_col

    self.next_idx = next_idx + 1
end

---@return integer
function Results:get_count_active_idxs()
    return #self.active_idxs
end

---@param start integer
---@param stop integer
---@param fin boolean
---@param rev boolean
---@param predicate fun(row:integer, col:integer): boolean
---@return integer|nil, integer|nil, integer|nil
function Results:find_pos(start, stop, fin, rev, predicate)
    local active_idxs = self.active_idxs
    local len_active_idxs = #active_idxs
    if len_active_idxs == 0 then
        return
    end

    local rows, cols = self:get_pos(fin)
    local init, limit, iter = get_iters(start, stop, rev, len_active_idxs)
    for i = init, limit, iter do
        local idx = active_idxs[i]
        local row = rows[idx]
        local col = cols[idx]
        if predicate(row, col) then
            return i, row, col
        end
    end

    return nil, nil, nil
end

---@param start integer
---@param stop integer
---@param mapper fun(start_row: integer, start_col: integer, fin_row: integer, fin_col: integer): integer, integer, integer, integer
function Results:map_both_pos(start, stop, mapper)
    local active_idxs = self.active_idxs
    local len_active_idxs = #active_idxs
    if len_active_idxs == 0 then
        return
    end

    local start_rows, start_cols, fin_rows, fin_cols = self:get_both_pos()
    local init, limit, iter = get_iters(start, stop, false, len_active_idxs)
    for i = init, limit, iter do
        local idx = active_idxs[i]
        local start_row = start_rows[idx]
        local start_col = start_cols[idx]
        local fin_row = fin_rows[idx]
        local fin_col = fin_cols[idx]

        start_rows[idx], start_cols[idx], fin_rows[idx], fin_cols[idx] =
            mapper(start_row, start_col, fin_row, fin_col)
    end
end

---@param start integer
---@param stop integer
---@param mapper fun(row: integer, col: integer): integer, integer
function Results:map_pos(start, stop, fin, mapper)
    local active_idxs = self.active_idxs
    local len_active_idxs = #active_idxs
    if len_active_idxs == 0 then
        return
    end

    local rows, cols = self:get_pos(fin)
    local init, limit, iter = get_iters(start, stop, false, len_active_idxs)
    for i = init, limit, iter do
        local idx = active_idxs[i]
        rows[idx], cols[idx] = mapper(rows[idx], cols[idx])
    end
end

---@param start integer
---@param stop integer
---@param fin boolean
---@param rev boolean
---@param mapper fun(row: integer, col: integer): integer, integer
function Results:map_pos_stop_on_noop(start, stop, fin, rev, mapper)
    local active_idxs = self.active_idxs
    local len_active_idxs = #active_idxs
    if len_active_idxs == 0 then
        return
    end

    local rows, cols = self:get_pos(fin)
    local init, limit, iter = get_iters(start, stop, rev, len_active_idxs)
    for i = init, limit, iter do
        local idx = active_idxs[i]
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

---@param fin boolean
---@param predicate fun(row:integer, col:integer): boolean
function Results:filter_pos(fin, predicate)
    local active_idxs = self.active_idxs
    local len_active_idxs = #active_idxs
    if len_active_idxs == 0 then
        return
    end

    local rows, cols = self:get_pos(fin)
    require("nvim-tools.list").filter(active_idxs, function(x)
        return predicate(rows[x], cols[x])
    end)
end

---@param fin boolean
---@param rev boolean
---@param predicate fun(row:integer, col:integer): boolean
function Results:filter_pos_stop_on_keep(fin, rev, predicate)
    local active_idxs = self.active_idxs
    local len_active_idxs = #active_idxs
    if len_active_idxs == 0 then
        return
    end

    local rows, cols = self:get_pos(fin)
    local slice_idx = nil
    local iter = rev and -1 or 1
    for i = 1, len_active_idxs, iter do
        local idx = active_idxs[i]
        if predicate(rows[idx], cols[idx]) then
            slice_idx = i
            break
        end
    end

    if slice_idx == nil then
        require("nvim-tools.table").clear(active_idxs)
        return
    end

    local ntl = require("nvim-tools.list")
    if rev then
        ntl.slice(active_idxs, 1, slice_idx)
    else
        ntl.slice(active_idxs, slice_idx, len_active_idxs)
    end
end

---@param predicate fun(sr_a:integer, sc_a:integer, fr_a:integer, fc_a:integer, sr_b:integer, sc_b:integer, fr_b:integer, fc_b:integer): boolean
function Results:sort(predicate)
    local active_idxs = self.active_idxs
    local len_active_idxs = #active_idxs
    if len_active_idxs == 0 then
        return
    end

    local sr = self.start_rows
    local sc = self.start_cols
    local fr = self.fin_rows
    local fc = self.fin_cols

    table.sort(active_idxs, function(a, b)
        return predicate(sr[a], sc[a], fr[a], fc[a], sr[b], sc[b], fr[b], fc[b])
    end)
end
-- DOCUMENT: The predicate function type is quite long.

return Results
