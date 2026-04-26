---Struct of arrays containing a list of positions.
---
---Iterator functions over the class are provided to allow for typical functional style
---operations while keeping the bookkeeping internal. This also improves performance by allowing
---list changes to be performed in groups.
---
---@class (exact) nvim-tools.Results
---
---Which indexes within the lists of data are still marked added.
---@field active_idxs integer[]
---If a new index is added, which index allows for an append after the last one.
---@field next_idx integer
---@field start_rows integer[]
---@field start_cols integer[]
---@field fin_rows integer[]
---@field fin_cols integer[]
---
---@field package __index fun(self:nvim-tools.Results, k:any): any
---@field new fun(size:integer): Results:nvim-tools.Results
local Results = {}

---@param self nvim-tools.Results
---@param k any
---@return any
function Results.__index(self, k)
    return self[k]
end

---@brief All iterators are one indexed, as with other Lua constructs.
---If the value is zero or less, the resolved value will be the length of the list minus the value.
---
---Example: 1, 0 - Iterate from the first index to the end
---Example: 1, -1 - Iterate from the first index to the second-to-last index
---Example: -3, -1 - Iterate from the fouth to last to the second-to-last index.
---
---The function will error if the start/stop values + the reverse flag result in an invalid
---iteration.

---@param val integer
---@param len integer
---@return integer
local function resolve_iter_val(val, len)
    if len < 1 then
        return 0
    end

    if val <= 0 then
        return math.max(len + val, 1)
    else
        return math.min(val, len)
    end
end

---@param start? integer
---@param stop? integer
---@param rev? boolean
---@param len integer
---@return integer, integer, integer
local function get_iters(start, stop, rev, len)
    start = start or 1
    stop = stop or len
    rev = rev or false

    local init = resolve_iter_val(start, len)
    local limit = resolve_iter_val(stop, len)

    if (rev and init < limit) or ((not rev) and init > limit) then
        local arrow = rev and "<" or ">"
        local rev_str = rev and "reversed" or "forward"
        error(table.concat({ init, " ", arrow, " ", limit, " on ", rev_str, " iteration" }))
    end

    local iter = rev and -1 or 1

    return init, limit, iter
end

-----------------
-- MARK: Utils --
-----------------

---Returns the active references
---@param fin? boolean
---@return integer[], integer[]
function Results:get_pos(fin)
    vim.validate("fin", fin, "boolean", true)

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

---@param size integer
---@return nvim-tools.Results
function Results.new(size)
    vim.validate("size", size, "number")

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
    local is_uint = require("nvim-tools.types").is_uint
    vim.validate("start_row", start_row, is_uint)
    vim.validate("start_col", start_col, is_uint)
    vim.validate("fin_row", fin_row, is_uint)
    vim.validate("fin_col", fin_col, is_uint)

    local next_idx = self.next_idx

    self.active_idxs[#self.active_idxs + 1] = next_idx
    self.start_rows[next_idx] = start_row
    self.start_cols[next_idx] = start_col
    self.fin_rows[next_idx] = fin_row
    self.fin_cols[next_idx] = fin_col

    self.next_idx = next_idx + 1
end

---@return integer[] active_idxs
---@return integer len_active_idxs
---@return integer next_idx
function Results:get_active_idx_info()
    local active_idxs = self.active_idxs
    return active_idxs, #active_idxs, self.next_idx
end

---@param start? integer
---@param stop? integer
---@param mapper fun(start_row: integer, start_col: integer, fin_row: integer, fin_col: integer): integer, integer, integer, integer
function Results:map_both_pos(start, stop, mapper)
    local is_int = require("nvim-tools.types").is_int
    vim.validate("start", start, is_int, true)
    vim.validate("stop", stop, is_int, true)
    vim.validate("mapper", mapper, "function")

    local active_idxs, len_active_idxs, _ = self:get_active_idx_info()
    if len_active_idxs == 0 then
        return
    end

    local srs, scs, frs, fcs = self:get_both_pos()
    local init, limit, iter = get_iters(start, stop, false, len_active_idxs)
    for i = init, limit, iter do
        local idx = active_idxs[i]
        local sr = srs[idx]
        local sc = scs[idx]
        local fr = frs[idx]
        local fc = fcs[idx]

        srs[idx], scs[idx], frs[idx], fcs[idx] = mapper(sr, sc, fr, fc)
    end
end

---@param fin? boolean
---@param rev? boolean
---@param predicate fun(row:integer, col:integer): boolean
function Results:filter_pos(fin, rev, predicate)
    vim.validate("fin", fin, "boolean", true)
    vim.validate("rev", rev, "boolean", true)
    vim.validate("predicate", predicate, "function")

    local active_idxs, len_active_idxs, _ = self:get_active_idx_info()
    if len_active_idxs == 0 then
        return
    end

    local rows, cols = self:get_pos(fin)
    local ntl = require("nvim-tools.list")
    if rev then
        ntl.filter_from_end(active_idxs, function(x)
            return predicate(rows[x], cols[x])
        end)
    else
        ntl.filter(active_idxs, function(x)
            return predicate(rows[x], cols[x])
        end)
    end
end

---If the predicate returns nil for either row or col, the position is removed.
---@param fin? boolean
---@param predicate fun(row:integer, col:integer): row:integer|nil, col:integer|nil
function Results:filter_map_pos(fin, predicate)
    vim.validate("fin", fin, "boolean", true)
    vim.validate("predicate", predicate, "function")

    local active_idxs, len_active_idxs, _ = self:get_active_idx_info()
    if len_active_idxs == 0 then
        return
    end

    local rows, cols = self:get_pos(fin)
    require("nvim-tools.list").map(active_idxs, function(idx)
        local new_row, new_col = predicate(rows[idx], cols[idx])
        if new_row and new_col then
            rows[idx] = new_row
            cols[idx] = new_col

            return idx
        else
            return nil
        end
    end)
end

---@param fin? boolean
---@param predicate fun(row_a:integer, col_a:integer, row_b:integer, col_b:integer): boolean
function Results:sort_by_pos(fin, predicate)
    vim.validate("fin", fin, "boolean", true)
    vim.validate("predicate", predicate, "function")

    local active_idxs, len_active_idxs, _ = self:get_active_idx_info()
    if len_active_idxs == 0 then
        return
    end

    local rows, cols = self:get_pos(fin)
    table.sort(active_idxs, function(a, b)
        return predicate(rows[a], cols[a], rows[b], cols[b])
    end)
end

return Results
