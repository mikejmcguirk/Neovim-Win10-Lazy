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

-----------------
-- MARK: Utils --
-----------------

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

---@param start integer
---@param stop integer
---@param fin boolean
---@param rev boolean
---@param predicate fun(row:integer, col:integer): boolean
---@return integer|nil, integer|nil, integer|nil
function Results:find_pos(start, stop, fin, rev, predicate)
    local idxs = self.active_idxs
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
    local idxs = self.active_idxs
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
    local idxs = self.active_idxs
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
    local idxs = self.active_idxs
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
    local idxs = self.active_idxs
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

    -- TODO: wat?
    require("farsight.util").list_compact(idxs, start, j)
end
-- TODO: Test that this combines rev and fwd properly
-- TODO: Start and stop need to be adjusted and converted to idx iters

return Results
