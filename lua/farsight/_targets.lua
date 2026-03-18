local vimv = vim.v

local bisect_left = require("farsight.util").list_bisect_left
local list_del_at = require("farsight.util").list_del_at
local list_insert_at = require("farsight.util").list_insert_at

---@param idx integer
---@param len integer
---@return integer
local function adj_new_idx(idx, len)
    if idx <= 0 then
        idx = len + idx + 1
    end

    if idx < 1 then
        idx = 1
    elseif idx > len + 1 then
        idx = len + 1
    end

    return idx
end

---@param idx integer
---@param len integer
---@return integer
local function adj_bounded_idx(idx, len)
    if len < 1 then
        return 0
    end

    if idx <= 0 then
        idx = len + idx
    end

    if idx < 1 then
        idx = 1
    elseif idx > len then
        idx = len
    end

    return idx
end

---@param row integer
---@param col integer
---@return string
local function create_pos_key(row, col)
    return table.concat({ row, col }, ":")
end

---@class farsight.targets.Positions
---@field len integer
---@field start_rows integer[]
---@field start_cols integer[]
---@field fin_rows integer[]
---@field fin_cols integer[]
---@field hashed_starts table<string, integer>
---@field hashed_fins table<string, integer>
---@field stats (""|"c"|"sl"|"fl"|"bl"|"sv"|"fv"|"bv")[]
---@field stat_idxs integer[]
local Positions = {}
Positions.__index = Positions

---Returns the new idx
---@param idx integer
---@param start_row integer
---@param start_col integer
---@param fin_row integer
---@param fin_col integer
---@return integer
function Positions:insert_at(idx, start_row, start_col, fin_row, fin_col)
    local len = self.len
    idx = adj_new_idx(idx, len)

    local start_rows = self.start_rows
    local start_cols = self.start_cols
    local fin_rows = self.fin_rows
    local fin_cols = self.fin_cols

    local stats = self.stats
    local stat_idxs = self.stat_idxs

    local j = len + 1
    for i = len, idx, -1 do
        start_rows[j] = start_rows[i]
        start_cols[j] = start_cols[i]
        fin_rows[j] = fin_rows[i]
        fin_cols[j] = fin_cols[i]

        stats[j] = stats[i]
        stat_idxs[j] = stat_idxs[i]

        j = j - 1
    end

    start_rows[idx] = start_row
    start_cols[idx] = start_col
    fin_rows[idx] = fin_row
    fin_cols[idx] = fin_col

    stats[idx] = ""
    stat_idxs[idx] = 0

    self.len = len + 1
    local start_key = create_pos_key(start_row, start_col)
    local fin_key = create_pos_key(fin_row, fin_col)
    self.hashed_starts[start_key] = idx
    self.hashed_fins[fin_key] = idx

    return idx
end

---@param stat ""|"c"|"sl"|"fl"|"bl"|"sv"|"fv"|"bv"
---@param pos_idx integer
---@return integer|nil
function Positions:find_stat_pos_idx(stat, pos_idx, rev)
    local stats = self.stats
    local stop = rev and 1 or self.len
    local iter = rev and -1 or 1
    for i = pos_idx, stop, iter do
        if stats[i] == stat then
            return i
        end
    end

    return nil
end

---@return integer[], integer[], integer[], integer[]
function Positions:get_both_positions()
    return self.start_rows, self.start_cols, self.fin_rows, self.fin_cols
end

---@return integer
function Positions:get_len()
    return self.len
end

---@param fin boolean
---@return integer[], integer[]
function Positions:get_positions(fin)
    if fin then
        return self.fin_rows, self.fin_cols
    else
        return self.start_rows, self.start_cols
    end
end

---@param fin boolean
---@return integer[]
function Positions:get_rows(fin)
    return fin and self.fin_rows or self.start_rows
end

---@param pos_idx integer
---@return ""|"c"|"sl"|"fl"|"bl"|"sv"|"fv"|"bv", integer
function Positions:get_stat_at(pos_idx)
    return self.stats[pos_idx], self.stat_idxs[pos_idx]
end

---@return (""|"c"|"sl"|"fl"|"bl"|"sv"|"fv"|"bv")[], integer[]
function Positions:get_stat_info()
    return self.stats, self.stat_idxs
end

---@return table<string, integer>, table<string, integer>
function Positions:get_both_hashed()
    return self.hashed_starts, self.hashed_fins
end

---@param pos_idx integer
---@return integer
function Positions:get_stat_idx(pos_idx)
    return self.stat_idxs[pos_idx]
end

---@param pos_idx integer
---@param row integer
---@param col integer
function Positions:set_fin_pos(pos_idx, row, col)
    self.fin_rows[pos_idx] = row
    self.fin_cols[pos_idx] = col
end

---@param pos_idx integer
---@param stat ""|"c"|"sl"|"fl"|"bl"|"sv"|"fv"|"bv"
---@param stat_idx integer
function Positions:set_stat(pos_idx, stat, stat_idx)
    self.stats[pos_idx] = stat
    self.stat_idxs[pos_idx] = stat_idx
end

---@param self farsight.targets.Positions
---@param idx integer
---@param srs integer[]
---@param scs integer[]
---@param frs integer[]
---@param fcs integer[]
---@param hs table<string, integer>
---@param hf table<string, integer>
---@param stats (""|"c"|"sl"|"fl"|"bl"|"sv"|"fv"|"bv")[]
---@param stat_idxs integer[]
local function positions_del_at(self, idx, srs, scs, frs, fcs, hs, hf, stats, stat_idxs)
    local len = self.len
    idx = adj_bounded_idx(idx, len)
    if idx < 1 then
        return 0
    end

    hs[create_pos_key(srs[idx], scs[idx])] = nil
    hf[create_pos_key(frs[idx], fcs[idx])] = nil

    local j = idx
    for i = idx + 1, len do
        srs[j] = srs[i]
        scs[j] = scs[i]
        frs[j] = frs[i]
        fcs[j] = fcs[i]

        stats[j] = stats[i]
        stat_idxs[j] = stat_idxs[i]

        j = j + 1
    end

    srs[len] = nil
    scs[len] = nil
    frs[len] = nil
    fcs[len] = nil

    stats[len] = nil
    stat_idxs[len] = nil

    self.len = len - 1
    return idx
end
-- TODO: This function points to needing to re-introduce the idxs list. This function is run in
-- hot paths and it is bad to shove all this data into those iters to be run intermittently.
-- Issues:
-- - Not totally sure how to make insert_at work. I would guess it inserts into the middle of the
-- idxs list but puts a new items at the end.

---@param size integer
---@return farsight.targets.Positions
function Positions.new(size)
    local self = setmetatable({}, Positions)
    local tn = require("farsight.util")._table_new

    self.len = 0

    self.start_rows = tn(size, 0)
    self.start_cols = tn(size, 0)
    self.fin_rows = tn(size, 0)
    self.fin_cols = tn(size, 0)

    self.hashed_starts = tn(0, size)
    self.hashed_fins = tn(0, size)
    self.stats = tn(size, 0)
    self.stat_idxs = tn(size, 0)

    return self
end

---@class (exact) farsight.targets.StatData
---@field pos_idxs integer[]
---@field get_len fun(self:farsight.targets.StatData): len:integer
---@field get_pos_idxs fun(self:farsight.targets.StatData): pos_idxs:integer[]

-- TODO: Add append functions to the StatData tables. They can check the new pos_idx against the
-- last one, and fall back to bisecting if they are less.

---@param self farsight.targets.StatData
---@return integer[]
local function get_pos_idxs(self)
    return self.pos_idxs
end

---@class (exact) farsight.targets.NoStats : farsight.targets.StatData
---@field __index farsight.targets.NoStats
---@field new fun(size:integer): No_Stats:farsight.targets.NoStats
local No_Stats = {}
No_Stats.__index = No_Stats

-- TODO: I think what actually needs to be done is - The targets are only actually deleted
-- right after they're pulled from search. So you do one struct that's just rows and cols, then
-- you create the one with the associated stuff. And you assume that from there, each target
-- makes a one-way trip to its final status.
-- And I think for something like static jumps, we only want to care about deleting from vtexts
-- yeah?
-- Another very simple reality - Each sub-table requires two connective tissue tables. You're
-- almost better off just duplicating the pos data.
-- TODO: Unsure of how this works, because del_at creates a gap, not an accurate representation.
-- This actually makes more sense with the idxs list.
-- I think a delete needs to also have a decrement step on/after idx to sync the values.
-- A status change is a straight up delete.
-- Likewise, an insertion needs to cause an increment. A stat change back just inserts.

---@param pos_idx integer
---@param pos_idxs integer[]
---@return integer
local function no_stats_insert_pos_idx(pos_idx, pos_idxs)
    local idx, found = bisect_left(pos_idxs, pos_idx)
    if not found then
        list_insert_at(pos_idxs, pos_idx, idx)
        return idx
    end

    return idx
end

---@return integer
function No_Stats:get_len()
    return #self.pos_idxs
end

No_Stats.get_pos_idxs = get_pos_idxs

---@param idx integer
---@param pos_idxs integer[]
---@return integer
local function no_stats_del_at(idx, pos_idxs)
    idx = adj_bounded_idx(idx, #pos_idxs)
    if idx == 0 then
        return 0
    end

    list_del_at(pos_idxs, idx)
    return idx
end

function No_Stats.new(size)
    local self = setmetatable({}, No_Stats)
    local tn = require("farsight.util")._table_new

    self.pos_idxs = tn(size, 0)

    return self
end

---@class (exact) farsight.targets.CharHls : farsight.targets.StatData
---@field len integer
---@field chars string[]
---@field __index farsight.targets.CharHls
---@field new fun(size:integer): char_hls:farsight.targets.CharHls
local Char_Hls = {}
Char_Hls.__index = Char_Hls
-- MAYBE: If we don't find a use case for reading the char, can just be removed

---@param pos_idx integer
---@param pos_idxs integer[]
---@return integer
local function char_hls_insert_pos_idx(pos_idx, pos_idxs, char, chars)
    local idx, found = bisect_left(pos_idxs, pos_idx)
    if not found then
        list_insert_at(pos_idxs, pos_idx, idx)
        list_insert_at(chars, char, idx)
        return idx
    end

    chars[idx] = char
    return idx
end

function Char_Hls:get_chars()
    return self.chars
end

function Char_Hls:get_len()
    return self.len
end

Char_Hls.get_pos_idxs = get_pos_idxs

function Char_Hls.new(size)
    local self = setmetatable({}, Char_Hls)
    local tn = require("farsight.util")._table_new

    self.len = 0
    self.pos_idxs = tn(size, 0)
    self.chars = tn(size, 0)

    return self
end

---@class (exact) farsight.targets.Labels : farsight.targets.StatData
---@field len integer
---@field pos_idxs integer[]
---@field labels string[][]
---@field __index farsight.targets.Labels
---@field new fun(size:integer): Labels:farsight.targets.Labels
local Labels = {}
Labels.__index = Labels

---@param pos_idx integer
---@param pos_idxs integer[]
---@return integer
local function labels_insert_pos_idx(pos_idx, pos_idxs, label, labels)
    local idx, found = bisect_left(pos_idxs, pos_idx)
    if not found then
        list_insert_at(pos_idxs, pos_idx, idx)
        list_insert_at(labels, label, idx)
        return idx
    end

    labels[idx] = label
    return idx
end

---@return string[][]
function Labels:get_labels()
    return self.labels
end

function Labels:get_len()
    return self.len
end

Labels.get_pos_idxs = get_pos_idxs

function Labels.new(size)
    local self = setmetatable({}, Labels)
    local tn = require("farsight.util")._table_new

    self.len = 0
    self.pos_idxs = tn(size, 0)
    self.labels = tn(size, 0)

    return self
end

---@class (exact) farsight.targets.Vtexts : farsight.targets.StatData
---@field len integer
---@field pos_idxs integer[]
---@field vtexts string[][]
---@field __index farsight.targets.Vtexts
---@field new fun(size:integer): No_Stats:farsight.targets.Vtexts
local Vtexts = {}
Vtexts.__index = Vtexts

---@param pos_idx integer
---@param pos_idxs integer[]
---@return integer
local function vtexts_insert_pos_idx(pos_idx, pos_idxs, vtext, vtexts)
    local idx, found = bisect_left(pos_idxs, pos_idx)
    if not found then
        list_insert_at(pos_idxs, pos_idx, idx)
        list_insert_at(vtexts, vtext, idx)
        return idx
    end

    vtexts[idx] = vtext
    return idx
end

function Vtexts:get_len()
    return self.len
end

Vtexts.get_pos_idxs = get_pos_idxs

---@return [string, integer|string?][][]
function Vtexts:get_vtexts()
    return self.vtexts
end

function Vtexts.new(size)
    local self = setmetatable({}, Vtexts)
    local tn = require("farsight.util")._table_new

    self.len = 0
    self.pos_idxs = tn(size, 0)
    self.vtexts = tn(size, 0)

    return self
end

---@class farsight.targets.Targets
---@field size integer
---@field positions farsight.targets.Positions
---@field no_stats farsight.targets.NoStats
---@field char_hls farsight.targets.CharHls
---@field start_labels farsight.targets.Labels
---@field fin_labels farsight.targets.Labels
---@field start_vtexts farsight.targets.Vtexts
---@field fin_vtexts farsight.targets.Vtexts
local Targets = {}
Targets.__index = Targets

---@param idx integer
---@param start_row integer
---@param start_col integer
---@param fin_row integer
---@param fin_col integer
---@return integer Resolved idx
function Targets:insert_at(idx, start_row, start_col, fin_row, fin_col)
    local positions = self.positions
    local new_idx = positions:insert_at(idx, start_row, start_col, fin_row, fin_col)

    local pos_idxs = self.no_stats.pos_idxs
    local no_stat_idx = no_stats_insert_pos_idx(new_idx, pos_idxs)
    positions:set_stat(new_idx, "", no_stat_idx)

    return new_idx
end
-- TODO: This one's a bit awkward because you have to put it in the search callback. I guess you
-- could move the insert_at logic into here to strip a layer of indirection, but I think it would
-- be unwise design to actually start hoisting out the module internals
-- PERF: Make a specific append function to skip the binary search on no_stats. Could maybe be
-- dynamically dispatched somehow.

---@return integer
function Targets:get_no_stat_len()
    return self.no_stats:get_len()
end

---@param start? integer
---@param stop? integer
---@param len integer
---@return integer, integer
local function adj_bounded_iters(start, stop, len)
    start = adj_bounded_idx((start or 1), len)
    stop = adj_bounded_idx((stop or len), len)
    if start > stop then
        return 0, 0
    else
        return start, stop
    end
end

---@param start integer
---@param stop integer
---@param rev? boolean
---@param positions farsight.targets.Positions
---@return integer, integer, integer
local function get_stat_iters(start, stop, rev, positions, stat)
    local start_pos_idx = positions:find_stat_pos_idx(stat, start, false)
    local fin_pos_idx = positions:find_stat_pos_idx(stat, stop, true)
    if not (start_pos_idx and fin_pos_idx and start_pos_idx <= fin_pos_idx) then
        return 0, 0, 0
    end

    local start_stat_idx = positions:get_stat_idx(start_pos_idx)
    local fin_stat_idx = positions:get_stat_idx(fin_pos_idx)

    local i = rev and fin_stat_idx or start_stat_idx
    local limit = rev and fin_stat_idx or start_stat_idx
    local iter = rev and -1 or 1
    return i, limit, iter
end

---@param start? integer
---@param stop? integer
---@param rev? boolean
---@param positions farsight.targets.Positions
---@return integer, integer, integer
local function pos_to_stat_iters(start, stop, rev, len, positions, stat)
    start, stop = adj_bounded_iters(start, stop, len)
    if not (start > 0 and stop > 0) then
        return 0, 0, 0
    end

    return get_stat_iters(start, stop, rev, positions, stat)
end

---@param self farsight.targets.Targets
---@param start? integer
---@param stop? integer
---@param rev? boolean
---@param fin boolean
---@return fun(): i:integer|nil, row:integer|nil, col:integer|nil
local function iter_no_stat_pos(self, start, stop, rev, fin)
    local positions = self.positions
    local len = positions:get_len()
    local i, limit, iter = pos_to_stat_iters(start, stop, rev, len, positions, "")
    if not (i > 0 and limit > 0 and iter ~= 0) then
        return function() end
    end

    i = i - iter
    local pos_idxs = self.no_stats:get_pos_idxs()
    local rows, cols = positions:get_positions(fin)

    ---@return integer|nil, integer|nil, integer|nil
    return function()
        i = i + iter
        if (iter > 0 and i > limit) or (iter < 0 and i < limit) then
            return nil, nil, nil
        end

        local pos_idx = pos_idxs[i]
        return i, rows[pos_idx], cols[pos_idx]
    end
end
-- PERF: Good example here of where object orientation in Lua breaks down. For each run of the
-- iter function, we have to do two hashes (the function and the sub-table) to get pos_idx, then
-- another three hashes (function, two subtables) to get the position. I could profile this.
-- Maybe Lua caches the lookups, but I think what needs to be done here is to hoist references to
-- the sub-tables so you can just do lookups on them directly. It would be useful if this could
-- be done with a meta-table to error on write, but that still adds read overhead.
-- Also (almost certainly) necessary to hoist here because we only want to do the start vs fin
-- check once, rather than per idx.

---@param self farsight.targets.Targets
---@param start? integer
---@param stop? integer
---@param rev? boolean
---@param fin boolean
---@return fun(): i:integer|nil, row:integer|nil, col:integer|nil
local function iter_char_pos(self, start, stop, rev, fin)
    local positions = self.positions
    local len = positions:get_len()
    local i, limit, iter = pos_to_stat_iters(start, stop, rev, len, positions, "c")
    if not (i > 0 and limit > 0 and iter ~= 0) then
        return function() end
    end

    i = i - iter
    local pos_idxs = self.char_hls:get_pos_idxs()
    local rows, cols = positions:get_positions(fin)

    ---@return integer|nil, integer|nil, integer|nil
    return function()
        i = i + iter
        if (iter > 0 and i > limit) or (iter < 0 and i < limit) then
            return nil, nil, nil
        end

        local pos_idx = pos_idxs[i]
        return i, rows[pos_idx], cols[pos_idx]
    end
end

---@param start? integer
---@param stop? integer
---@param rev? boolean
---@return fun(): idx:integer|nil, start_row:integer|nil, start_col:integer|nil
function Targets:iter_no_stat_start_pos(start, stop, rev)
    return iter_no_stat_pos(self, start, stop, rev, false)
end

---@param start? integer
---@param stop? integer
---@param rev? boolean
---@return fun(): idx:integer|nil, fin_row:integer|nil, fin_col:integer|nil
function Targets:iter_no_stat_fin_pos(start, stop, rev)
    return iter_no_stat_pos(self, start, stop, rev, true)
end

---@param self farsight.targets.Targets
---@param start? integer
---@param stop? integer
---@param rev? boolean
---@param fin boolean
---@return fun(): i:integer|nil, row:integer|nil, col:integer|nil
local function iter_no_stat_rows(self, start, stop, rev, fin)
    local positions = self.positions
    local len = positions:get_len()
    local i, limit, iter = pos_to_stat_iters(start, stop, rev, len, positions, "")
    if not (i > 0 and limit > 0 and iter ~= 0) then
        return function() end
    end

    i = i - iter
    local pos_idxs = self.no_stats:get_pos_idxs()
    local rows = positions:get_rows(fin)

    ---@return integer|nil, integer|nil, integer|nil
    return function()
        i = i + iter
        if (iter > 0 and i > limit) or (iter < 0 and i < limit) then
            return nil, nil, nil
        end

        return i, rows[pos_idxs[i]]
    end
end

---@param start? integer
---@param stop? integer
---@param rev? boolean
---@return fun(): i:integer|nil, fin_row:integer|nil
function Targets:iter_no_stat_fin_rows(start, stop, rev)
    return iter_no_stat_rows(self, start, stop, rev, false)
end

---@param self farsight.targets.Targets
---@param start? integer
---@param stop? integer
---@param rev? boolean
---@param fin boolean
---@return fun(): idx:integer|nil, label:string[]|nil
local function iter_labels(self, start, stop, rev, fin)
    local positions = self.positions
    local len = positions:get_len()
    local stat = fin and "fl" or "sl"
    local i, limit, iter = pos_to_stat_iters(start, stop, rev, len, positions, stat)
    if not (i > 0 and limit > 0 and iter ~= 0) then
        return function() end
    end

    i = i - iter
    local labels_tbl = fin and self.fin_labels or self.start_labels
    local labels = labels_tbl:get_labels()

    ---@return integer|nil, integer|nil, integer|nil, string[]|nil
    return function()
        i = i + iter
        if (iter > 0 and i > limit) or (iter < 0 and i < limit) then
            return nil, nil
        end

        return i, labels[i]
    end
end

---@param start? integer
---@param stop? integer
---@param rev? boolean
---@return fun(): idx:integer|nil, label:string[]|nil
function Targets:iter_labels_start(start, stop, rev)
    return iter_labels(self, start, stop, rev, false)
end

---@param start? integer
---@param stop? integer
---@param rev? boolean
---@return fun(): idx:integer|nil, label:string[]|nil
function Targets:iter_labels_fin(start, stop, rev)
    return iter_labels(self, start, stop, rev, true)
end

---@param self farsight.targets.Targets
---@param start? integer
---@param stop? integer
---@param rev? boolean
---@return fun(): idx:integer|nil, start_label:string[]|nil, fin_label:string[]|nil
function Targets:iter_both_labels(start, stop, rev)
    local positions = self.positions
    local len = positions:get_len()
    local i, limit, iter = pos_to_stat_iters(start, stop, rev, len, positions, "bl")
    if not (i > 0 and limit > 0 and iter ~= 0) then
        return function() end
    end

    i = i - iter
    local start_labels = self.start_labels:get_labels()
    local fin_labels = self.fin_labels:get_labels()

    ---@return integer|nil, string[]|nil, string[]|nil
    return function()
        i = i + 1
        if (iter > 0 and i > limit) or (iter < 0 and i < limit) then
            return nil, nil, nil
        end

        if rev then
            return i, fin_labels[i], start_labels[i]
        else
            return i, start_labels[i], fin_labels[i]
        end
    end
end

---@param self farsight.targets.Targets
---@param start? integer
---@param stop? integer
---@param rev? boolean
---@param fin boolean
---@return fun(): idx:integer|nil, row:integer|nil, col:integer|nil, vtext:[string, integer|string?][]|nil
local function iter_vtexts(self, start, stop, rev, fin)
    local positions = self.positions
    local len = positions:get_len()
    local stat = fin and "fv" or "sv"
    local i, limit, iter = pos_to_stat_iters(start, stop, rev, len, positions, stat)
    if not (i > 0 and limit > 0 and iter ~= 0) then
        return function() end
    end

    i = i - iter
    local rows, cols = positions:get_positions(fin)
    local vt = fin and self.fin_vtexts or self.start_vtexts
    local pos_idxs = vt:get_pos_idxs()
    local vtexts = vt:get_vtexts()

    ---@return integer|nil, integer|nil, integer|nil, [string, integer|string?][]|nil
    return function()
        i = i + 1
        if (iter > 0 and i > limit) or (iter < 0 and i < limit) then
            return nil, nil, nil
        end

        local pos_idx = pos_idxs[i]
        return i, rows[pos_idx], cols[pos_idx], vtexts[i]
    end
end

---@param start? integer
---@param stop? integer
---@param rev? boolean
---@return fun():idx:integer|nil, start_row: integer|nil, start_col: integer|nil, start_vtext: [string,integer|string?][]|nil
function Targets:iter_vtexts_start(start, stop, rev)
    return iter_vtexts(self, start, stop, rev, false)
end

---@param start? integer
---@param stop? integer
---@param rev? boolean
---@return fun():idx:integer|nil, fin_row: integer|nil, fin_col: integer|nil, fin_vtext: [string,integer|string?][]|nil
function Targets:iter_vtexts_fin(start, stop, rev)
    return iter_vtexts(self, start, stop, rev, true)
end

---@param start? integer
---@param stop? integer
---@param rev? boolean
---@return fun(): idx:integer|nil, fin_rows:integer|nil, fin_cols:integer|nil
function Targets:iter_char_pos(start, stop, rev)
    return iter_char_pos(self, start, stop, rev, true)
end

---@param self farsight.targets.Targets
---@param start? integer
---@param stop? integer
---@param rev? boolean
---@param stop_on_keep? boolean
---@param fin boolean
---@param predicate fun(start_row: integer): boolean
local function filter_no_stat_rows(self, start, stop, rev, stop_on_keep, fin, predicate)
    local positions = self.positions
    local srs, scs, frs, fcs = positions:get_both_positions()
    local rows = fin and frs or srs
    local hs, hf = positions:get_both_hashed()
    local stats, stat_idxs = positions:get_stat_info()
    local len = positions:get_len()

    local no_stats = self.no_stats
    local pos_idxs = no_stats:get_pos_idxs()

    local i, limit, iter = pos_to_stat_iters(start, stop, rev, len, positions, "")
    if not (i > 0 and limit > 0 and iter ~= 0) then
        return
    end

    while true do
        if (iter > 0 and i > limit) or (iter < 0 and i < limit) then
            break
        end

        local pos_idx = pos_idxs[i]
        local row = rows[pos_idx]

        if not predicate(row) then
            no_stats_del_at(i, pos_idxs)
            positions_del_at(positions, pos_idx, srs, scs, frs, fcs, hs, hf, stats, stat_idxs)
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
-- PERF: Alternatives to the branching logic for iter advancement:
-- - Make iter fwd and iter rev separate functions
-- - Save the idxs to delete into a table, then run the deletes in reverse

---@param start? integer
---@param stop? integer
---@param rev? boolean
---@param stop_on_keep? boolean
---@param predicate fun(start_row: integer): boolean
function Targets:filter_no_stat_start_rows(start, stop, rev, stop_on_keep, predicate)
    filter_no_stat_rows(self, start, stop, rev, stop_on_keep, false, predicate)
end

---@param self farsight.targets.Targets
---@param start? integer
---@param stop? integer
---@param rev? boolean
---@param stop_on_keep? boolean
---@param stat ""|"c"|"sl"|"fl"|"bl"|"sv"|"fv"|"bv"
---@param predicate fun(start_row: integer, start_col: integer, fin_row: integer, fin_col: integer): boolean
local function filter_stat_both_pos(self, start, stop, rev, stop_on_keep, stat, predicate)
    local positions = self.positions
    local srs, scs, frs, fcs = positions:get_both_positions()
    local hs, hf = positions:get_both_hashed()
    local stats, stat_idxs = positions:get_stat_info()

    local no_stats = self.no_stats
    local pos_idxs = no_stats:get_pos_idxs()

    local len = positions:get_len()
    local i, limit, iter = pos_to_stat_iters(start, stop, rev, len, positions, stat)
    if not (i > 0 and limit > 0 and iter ~= 0) then
        return
    end

    while true do
        if (iter > 0 and i > limit) or (iter < 0 and i < limit) then
            break
        end

        local pos_idx = pos_idxs[i]
        local start_row = srs[pos_idx]
        local start_col = scs[pos_idx]
        local fin_row = frs[pos_idx]
        local fin_col = fcs[pos_idx]

        if not predicate(start_row, start_col, fin_row, fin_col) then
            no_stats_del_at(i, pos_idxs)
            positions_del_at(positions, pos_idx, srs, scs, frs, fcs, hs, hf, stats, stat_idxs)
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

---@param start? integer
---@param stop? integer
---@param rev? boolean
---@param stop_on_keep? boolean
---@param predicate fun(start_row: integer, start_col: integer, fin_row: integer, fin_col: integer): boolean
function Targets:filter_no_stat_both_pos(start, stop, rev, stop_on_keep, predicate)
    filter_stat_both_pos(self, start, stop, rev, stop_on_keep, "", predicate)
end

---@param self farsight.targets.Targets
---@param start? integer
---@param stop? integer
---@param rev? boolean
---@param mapper fun(start_row: integer, start_col: integer): integer, integer
---@param fin boolean
local function map_no_stat_pos(self, start, stop, rev, mapper, fin)
    local positions = self.positions
    local len = positions:get_len()
    local i, limit, iter = pos_to_stat_iters(start, stop, rev, len, positions, "")
    if not (i > 0 and limit > 0 and iter ~= 0) then
        return
    end

    local rows, cols = positions:get_positions(fin)
    local pos_idxs = self.no_stats:get_pos_idxs()

    while true do
        if (iter > 0 and i > limit) or (iter < 0 and i < limit) then
            break
        end

        local pos_idx = pos_idxs[i]
        rows[pos_idx], cols[pos_idx] = mapper(rows[pos_idx], cols[pos_idx])
        i = i + iter
    end
end

---@param start? integer
---@param stop? integer
---@param rev? boolean
---@param mapper fun(start_row: integer, start_col: integer): integer, integer
function Targets:map_no_stat_start_pos(start, stop, rev, mapper)
    map_no_stat_pos(self, start, stop, rev, mapper, false)
end

---@param start? integer
---@param stop? integer
---@param rev? boolean
---@param mapper fun(start_row: integer, start_col: integer): integer, integer
function Targets:map_no_stat_fin_pos(start, stop, rev, mapper)
    map_no_stat_pos(self, start, stop, rev, mapper, true)
end

---@param self farsight.targets.Targets
---@param start? integer
---@param stop? integer
---@param rev? boolean
---@param stat ""|"c"|"sl"|"fl"|"bl"|"sv"|"fv"|"bv"
---@param mapper fun(start_row: integer, start_col: integer, fin_row: integer, fin_col: integer): integer, integer, integer, integer
local function map_no_stat_both_pos(self, start, stop, rev, stat, mapper)
    local positions = self.positions
    local len = positions:get_len()
    local i, limit, iter = pos_to_stat_iters(start, stop, rev, len, positions, stat)
    if not (i > 0 and limit > 0 and iter ~= 0) then
        return
    end

    local start_rows, start_cols = positions:get_positions(false)
    local fin_rows, fin_cols = positions:get_positions(true)
    local pos_idxs = self.no_stats:get_pos_idxs()

    while true do
        if (iter > 0 and i > limit) or (iter < 0 and i < limit) then
            break
        end

        local pos_idx = pos_idxs[i]
        local start_row = start_rows[pos_idx]
        local start_col = start_cols[pos_idx]
        local fin_row = fin_rows[pos_idx]
        local fin_col = fin_cols[pos_idx]
        start_rows[pos_idx], start_cols[pos_idx], fin_rows[pos_idx], fin_cols[pos_idx] =
            mapper(start_row, start_col, fin_row, fin_col)
        i = i + iter
    end
end

---@param start? integer
---@param stop? integer
---@param rev? boolean
---@param mapper fun(start_row: integer, start_col: integer, fin_row: integer, fin_col: integer): integer, integer, integer, integer
function Targets:map_no_stat_both_pos(start, stop, rev, mapper)
    map_no_stat_both_pos(self, start, stop, rev, "", mapper)
end

---@param self farsight.targets.Targets
---@param start? integer
---@param stop? integer
---@param count? integer
---@param fin boolean
local function map_no_stat_to_labels(self, start, stop, count, fin)
    local positions = self.positions
    local len = positions:get_len()
    local i, limit, iter = pos_to_stat_iters(start, stop, true, len, positions, "")
    if not (i > 0 and limit > 0 and iter == -1) then
        return
    end

    count = count or len
    count = math.min(count, len)
    local no_stats = self.no_stats
    local pos_idxs = no_stats:get_pos_idxs()
    local labels_tbl = fin and self.fin_labels or self.start_labels
    local labels = labels_tbl:get_labels()
    local stat = fin and "fl" or "sl"

    while i >= limit do
        local pos_idx = pos_idxs[i]
        no_stats_del_at(i, pos_idxs)
        local label_idx = labels_insert_pos_idx(pos_idx, pos_idxs, {}, labels)
        positions:set_stat(pos_idx, stat, label_idx)

        i = i + iter
        count = count - 1
        if count <= 0 then
            break
        end
    end
end
-- TODO: This would be map_stat_to_blank_label, which would always be valid

---@param start? integer
---@param stop? integer
---@param count? integer
function Targets:map_no_stat_to_start_labels(start, stop, count)
    map_no_stat_to_labels(self, start, stop, count, false)
end

---@param start? integer
---@param stop? integer
---@param count? integer
function Targets:map_no_stat_to_fin_labels(start, stop, count)
    map_no_stat_to_labels(self, start, stop, count, true)
end

---@param self farsight.targets.Targets
---@param start? integer
---@param stop? integer
---@param count? integer
---@param stat ""|"c"|"sl"|"fl"|"bl"|"sv"|"fv"|"bv"
local function map_stat_to_both_labels(self, start, stop, count, stat)
    local positions = self.positions
    local len = positions:get_len()
    local i, limit, iter = pos_to_stat_iters(start, stop, true, len, positions, stat)
    if not (i > 0 and limit > 0 and iter ~= 0) then
        return
    end

    count = count or len
    count = math.min(count, len)
    local start_labels_tbl = self.start_labels
    local fin_labels_tbl = self.fin_labels
    local start_labels = start_labels_tbl:get_labels()
    local fin_labels = fin_labels_tbl:get_labels()
    local start_pos_idxs = start_labels_tbl:get_pos_idxs()
    local fin_pos_idxs = fin_labels_tbl:get_pos_idxs()

    while true do
        if (iter > 0 and i > limit) or (iter < 0 and i < limit) then
            break
        end

        local start_pos_idx = start_pos_idxs[i]
        local fin_pos_idx = fin_pos_idxs[i]
        labels_insert_pos_idx(start_pos_idx, start_pos_idxs, {}, start_labels)
        labels_insert_pos_idx(fin_pos_idx, fin_pos_idxs, {}, fin_labels)

        i = i + iter
        count = count - 1
        if count <= 0 then
            break
        end
    end
end
-- TODO: iter is always false. fix iter condition
-- MID: This should obviously be "map_stat_to_stat" but I don't have a generalized form of the
-- set stat function.
-- PERF: Current user of set_stat_both_labels is fine, but it re-hashes tons of data repeatedly
-- under the hood that we don't need to here. You can get refs to the underlying tables and set
-- directly.

---@param start? integer
---@param stop? integer
---@param count? integer
function Targets:map_no_stat_to_both_labels(start, stop, count)
    map_stat_to_both_labels(self, start, stop, count, "")
end

---@param self farsight.targets.Targets
---@param start? integer
---@param stop? integer
---@param fin boolean
---@param mapper fun(label: string[]): [string, integer|string?][]
local function map_vtext_from_labels(self, start, stop, fin, mapper)
    local positions = self.positions
    local len = positions:get_len()
    local stat = fin and "fl" or "sl"
    local i, limit, iter = pos_to_stat_iters(start, stop, true, len, positions, stat)
    if not (i > 0 and limit > 0 and iter == 1) then
        return
    end

    local vtexts_tbl = fin and self.fin_vtexts or self.start_vtexts
    local vtexts = vtexts_tbl:get_vtexts()
    local vtext_pos_idxs = vtexts_tbl:get_pos_idxs()

    local labels_tbl = fin and self.fin_labels or self.start_labels
    local labels = labels_tbl:get_labels()
    local label_pos_idxs = labels_tbl:get_pos_idxs()

    while i >= limit do
        local label_pos_idx = label_pos_idxs[i]
        local vtext = mapper(labels[i])
        local vtext_idx = vtexts_insert_pos_idx(label_pos_idx, vtext_pos_idxs, vtext, vtexts)
        positions:set_stat(label_pos_idx, stat, vtext_idx)
        i = i + iter
    end
end

---@param start? integer
---@param stop? integer
---@param mapper fun(label: string[]): [string, integer|string?][]
function Targets:map_start_vtext_from_labels(start, stop, mapper)
    map_vtext_from_labels(self, start, stop, false, mapper)
end

---@param start? integer
---@param stop? integer
---@param mapper fun(label: string[]): [string, integer|string?][]
function Targets:map_fin_vtext_from_labels(start, stop, mapper)
    map_vtext_from_labels(self, start, stop, true, mapper)
end

---@param self farsight.targets.Targets
---@param start? integer
---@param stop? integer
---@param fin boolean
---@param next_fin boolean
---@param mapper fun(label: string[], available: integer): [string, integer|string?][]
local function map_vtexts_from_labels_cmp_next(self, start, stop, fin, next_fin, mapper)
    local col_distance = require("farsight.util").col_distance
    local positions = self.positions
    local len = positions:get_len()
    local stat = fin and "fl" or "sl"
    local i, limit, iter = pos_to_stat_iters(start, stop, false, len, positions, stat)
    if not (i > 0 and limit > 0 and iter == 1) then
        return
    end

    local vtexts_tbl = fin and self.fin_vtexts or self.start_vtexts
    local vtexts = vtexts_tbl:get_vtexts()
    local vtext_pos_idxs = vtexts_tbl:get_pos_idxs()

    local labels_tbl = fin and self.fin_labels or self.start_labels
    local labels = labels_tbl:get_labels()
    local label_pos_idxs = labels_tbl:get_pos_idxs()

    local rows, cols = positions:get_positions(fin)
    local next_rows, next_cols = positions:get_positions(next_fin)

    local most_labels = limit - 1
    while i <= most_labels do
        local label_pos_idx = label_pos_idxs[i]
        local row = rows[label_pos_idx]
        local col = cols[label_pos_idx]

        local next_pos_idx = label_pos_idxs[i + 1]
        local next_row = next_rows[next_pos_idx]
        local next_col = next_cols[next_pos_idx]

        local available = col_distance(row, col, next_row, next_col)

        local vtext = mapper(labels[i], available)
        local vtext_idx = vtexts_insert_pos_idx(label_pos_idx, vtext_pos_idxs, vtext, vtexts)
        positions:set_stat(label_pos_idx, stat, vtext_idx)

        i = i + iter
    end

    local label_pos_idx = label_pos_idxs[i]
    local vtext = mapper(labels[i], vimv.maxcol)
    local vtext_idx = vtexts_insert_pos_idx(label_pos_idx, vtext_pos_idxs, vtext, vtexts)
    positions:set_stat(label_pos_idx, stat, vtext_idx)
end
-- TODO: This needs to set the vtexts first, then go through again and remove the label stat data.
-- Or... does it actually? Because static jumps re-use the label data.
-- This would mean that we are now dealing with layered statuses rather than mutually exclusive
-- ones. So like, the vtexts would expect to have corresponding label data under them. To some
-- extent then, we don't actually want hyper-flexible functions in here. The nature of the
-- functions should outline the territory on which they are supposed to be used. So like,
-- we don't want functions that can just turn labels into other things, since a label should be
-- destined to become a vtext.

---@param start? integer
---@param stop? integer
---@param mapper fun(label: string[], available: integer): [string, integer|string?][]
function Targets:map_start_vtexts_from_labels_cmp_next_start(start, stop, mapper)
    map_vtexts_from_labels_cmp_next(self, start, stop, false, false, mapper)
end

---@param start? integer
---@param stop? integer
---@param mapper fun(label: string[], available: integer): [string, integer|string?][]
function Targets:map_fin_vtexts_from_labels_cmp_next_start(start, stop, mapper)
    map_vtexts_from_labels_cmp_next(self, start, stop, true, false, mapper)
end

---@param start? integer
---@param stop? integer
---@param mapper fun(label: string[], available: integer): [string, integer|string?][]
function Targets:map_fin_vtexts_from_labels_cmp_next_fin(start, stop, mapper)
    map_vtexts_from_labels_cmp_next(self, start, stop, true, true, mapper)
end

---@param start? integer
---@param stop? integer
---@param mapper fun(label: string[], available: integer): [string, integer|string?][]
function Targets:map_start_vtexts_from_labels_cmp_fin(start, stop, mapper)
    local col_distance = require("farsight.util").col_distance
    local positions = self.positions
    local len = positions:get_len()
    local i, limit, iter = pos_to_stat_iters(start, stop, false, len, positions, "sl")
    if not (i > 0 and limit > 0 and iter == 1) then
        return
    end

    local vtexts_tbl = self.start_vtexts
    local vtexts = vtexts_tbl:get_vtexts()
    local vtext_pos_idxs = vtexts_tbl:get_pos_idxs()

    local labels_tbl = self.start_labels
    local labels = labels_tbl:get_labels()
    local label_pos_idxs = labels_tbl:get_pos_idxs()

    local rows, cols = positions:get_positions(false)
    local next_rows, next_cols = positions:get_positions(true)

    while i <= limit do
        local label_pos_idx = label_pos_idxs[i]
        local row = rows[label_pos_idx]
        local col = cols[label_pos_idx]
        local next_row = next_rows[label_pos_idx]
        local next_col = next_cols[label_pos_idx]

        local available = col_distance(row, col, next_row, next_col)

        local vtext = mapper(labels[i], available)
        local vtext_idx = vtexts_insert_pos_idx(label_pos_idx, vtext_pos_idxs, vtext, vtexts)
        positions:set_stat(label_pos_idx, "sv", vtext_idx)

        i = i + iter
    end
end

---@param pos_idx integer
---@param char string
function Targets:set_stat_char_hl(pos_idx, char)
    local positions = self.positions
    local cur_stat, stat_idx = positions:get_stat_at(pos_idx)
    if cur_stat ~= "" then
        return
    end

    no_stats_del_at(stat_idx, self.no_stats:get_pos_idxs())

    local char_hls = self.char_hls
    local pos_idxs = char_hls:get_pos_idxs()
    local chars = char_hls:get_chars()
    local char_idx = char_hls_insert_pos_idx(pos_idx, pos_idxs, char, chars)

    positions:set_stat(pos_idx, "c", char_idx)
end

-- STATUS SETTING
--
-- High level problems:
-- - Data validity. Certain stats must be transformed in certain ways
-- - Speed. Stats are changed in hot loops. We cannot be re-gathering references to underlying
-- tables that have already been pulled once for transformation
-- - Steps - Some statuses have to be transformed in stages
-- - Args. Really don't want to bake in the one var assumption
--
-- Use cases:
-- - nostat > char
--   - This is done one at a time
--
-- - nostat > blank label
--   - done in bulk
--
-- - nostat > filled label
--   - Done one at a time
--
-- - blank label > filled label
--   - Done in bulk
--
-- - filled label > vtext
--   - done in bulk
--   - Keeps the underlying label data
--
-- Another way of thinking - What is valid and invalid?
-- - nostat
--   - nostat > char_hl
--   - nostat > empty_label
--   - nostat > filled_label
--   - nostat > vtext
--     - This one is interesting because, in order for this to be valid, it would need to
--     contain the label data as well
--
-- Another way - What data transformations need to be done for each change?
-- - nostat > char_hl : del nostat. add char_hl with char
-- - nostat > empty_label: del nostat. add label with empty table
-- - nostat > filled_label : del nostat. add label with filled param
-- - nostat > vtext : del nostat. take params for filled label and filled vtext
-- - char_hl > nostat : del char_hl, add nostat
-- - char_hl > blank_label : del char_hl. add empty label
-- - char_hl > filled_label : del char_hl. add filled label param
-- - char_hl > vtext : del_char_hl. add filled label param and vtext param
-- - empty_label > nostat : del empty label. add nostat
-- - empty_label > char_hl : del empty label. add char_hl
-- - empty_label > filled_label : add label param data to empty label
-- - empty_label > vtext : add label param data to empty label. Add vtext param
-- - filled_label > nostat : del filled label. add nostat
-- - filled_label > char_hl : del filled lable. add char_hl
-- - filled_label > empty_label : del label data and change stat.
-- - filled_label > vtext : map vtext from label. keep label data
-- - vtext > nostat : del vtext and label. add nostat
-- - vtext > char_hl : del vtext and label. add char_hl
-- - vtext > empty_label : del vtext, clear label. set empty stat
-- - vtext > filled_label : del or clear vtext data. reset stat
--
-- The problem here is even if you write useful primitives and built up from the, they might hurt
-- perf later. I am already having to look at how del_at is done because it re-references
-- pos_idxs data that I'm already using for iteration. If I just look at my basic
-- map no stats to labels we have:
-- - del_at, which re-references pos_idxs
-- - insert_pos_idx, which re-references multiple fields in labels
-- - positions:set_stat, which re-references the stats part of positions
-- And this is all hot code too.
--
-- So I think the first thing, really, that has to be done is to actually unwind some of the
-- object orientation, because if the underlying assumptions become too deeply rooted, it will
-- become impossible to fix perf later.
--
-- I would also broadly consider it a failure of architecture that, essentially, we have failed to
-- prioritize optimizing for the JIT compiler. I think some of the metatable architecture and
-- dynamic dispatch is okay, but stuff like del_at_from_stat really resists being jitted, as do
-- the recursive calls within a lot of the OOP functions. Something like the no_stats_del_at
-- function I think are the way forward, where they are object_orientedish but take refs that are
-- stable in the caller, which makes it easier to JIT. So I guess doing this wasn't a *bad*
-- exercise, because I think the hybrid method is actually valuable, and the self methods were
-- a bridge to get there. But it also raises the question of - When are you not prematurely
-- optimizing and when are you architecting fundamentally incorrectly?
--
-- But anyway, as this concept is further explored - focus on decreasing nesting, doing more
-- hoisting, and eliminating dynamic dispatch where possible. I think/hope this gives us a better
-- window into where the actual patterns reside.

---@param pos_idx integer
---@param row integer
---@param col integer
function Targets:set_fin_pos(pos_idx, row, col)
    self.positions:set_fin_pos(pos_idx, row, col)
end

---@param size integer
---@return farsight.targets.Targets
function Targets.new(size)
    local self = setmetatable({}, Targets)

    self.size = size
    self.positions = Positions.new(size)
    self.no_stats = No_Stats.new(size)
    self.char_hls = Char_Hls.new(size)
    self.start_labels = Labels.new(size)
    self.fin_labels = Labels.new(size)
    self.start_vtexts = Vtexts.new(size)
    self.fin_vtexts = Vtexts.new(size)

    return self
end
-- TODO: It is not necessary to create every sub-table at full size. The "join" tables should be
-- set to vim.NIL and lazily allocated. A param could also be passed for what size to allocate the
-- sub-tables (static jumps would indeed want full size. Live jumps probably only half).

return Targets

-- TODO: I'm not sure why any of the exposed functions in here take optional vars since they
-- aren't user facing.
--
-- MID: The stat setting involves a lot of redundant code. But I'm not sure how to do it in a way
-- that isn't contrived due to the different function args. Could use a v:any pattern, but that
-- locks in the assumption that each stat table only has one value. Since the code runs in
-- hot paths, ok with redundancy for now. Don't want to pre-maturely factor.

-- TODO FOR LABELING AND HIGHLIGHTING
--
-- What if you treated targets like a mini state machine?
-- - There are four target states we care about
--   - New target
--   - Labeled
--   - Char hl
--   - Vtext
--   So just move the idxs between those four lists, rather than holding refs
-- - Issue: Ordering, especially for label re-use.
--   - You pull labels to re-use from the old targets and put them in the labels list
--   - You create new labels from targets and add them to the label list
--   - Do you then have to run a sort?
--
-- - Change raw to hl char exterior data structure and iteration
-- - Don't do alloc labels as iters, do them as functions, because you can iter then delete
-- from idxs. Then get the labels in a separate function.
-- - You could stage deletes and then have the metatable run them. But that feels contrived
--
-- - Add iterators for label re-use
--   - for start and fin labels
--   - return label, vtext, and hashed position
-- - In the win_targets iteration, rather than pre-calculating expected labels, feed the avail
-- label count to the alloc function. Get the change in the size of the labels table. Subtract, and
-- that is your new avail labels. If the last win has lower count than its total avail, then they
-- won't all be allocated. If there are more possible labels, that's fine. Point being that this
-- fixes the potential breakage where the numbers didn't all line up. Now it just all calcs
-- through.
-- Make a note that I'm not sure how addition and subtraction and min and max work on math.huge
-- and infinity
--
-- Label Re-Use
-- - Add live opt for re-use uppercase (folke has default false)
--   - Use vimfns for now
-- - Create win_targets archive by pattern
-- - Check the robustness of how between-keystroke data is saved and deleted (for gc).
--   - Save is_upward in live so it can be used on enter searches
-- - Save previous pattern (better than string subbing, simpler to handle removals)
-- - Filtered tokens should already be being passed to the labeler
-- - Make sure the function checks for max_width == 1
-- - Add a note to labeler - Since this should be only used for single labels, and since the
-- max should be 52 labels, we're at the upper limit of what should be the max (for each lookup,
-- assuming a full iter) of what's shorter than a hash lookup. A table<string, string> could be
-- created to compare the label to the hashed position. But I would not want to allocate this
-- heap without verifying through profiling it's faster.
-- do fin label re-use iter:
-- - skip if skipping upper
-- - linear scan tokens to see if it's in there
-- - if it's in tokens
--   - see if we have the hashed position in new targets
--   - if hashed fin position is in new target hashed fin positions:
--     - copy over label and vtext
-- - As before, allocate labels based on the available tokens and target label slots
--   - Use the canned target label length functions to do this
-- - After confirmed working, re-create built-in upper case check
--
-- Dimming
-- - See what hl_eol vs row boundaries actually does. Do which?
-- - Create universal dim function based on start and end pos
--   - Since it's just start and end pos resolution, I think it just goes in the extmarks module
--   - Include pos_lt validation?
--   - Per folke, highlight by row
--
-- Search positions
-- - In the highlight module, make a datatype and function to extract the search positions
--   - Add iter_both_pos for this purpose, since we need to use idxs
--   - Pre-allocate the new search datastructure based on len_idxs
--   - Re-create the position merging function
-- - In the extmarks module, add a function to set the merged positions
--
-- Extmark Module Wrap-up
-- - Add a function to highlight the cursor
--   - Base on getcurpos()
--   - How do you determine the color?
--   - Add to live jump
-- - Add a TODO comment that csearch extmarks need to go here
--
-- TODO: Have an option in add_target to not hash
--
-- MID: It would be better for the alloc_labels iters to be more consolidated considering how
-- similar the logic is.
--
-- MAYBE: Pre-allocate and store label states so they don't have to be calculated in iteration
-- - Problem is combinatorial complexity
--   - Start or fin has two override states (four possibilities)
--   - Both has four possibilities (char labels never overridden)
--   - Cursor aware needs to save stats based on cursor position
-- MAYBE: For the various stat iters, I think you could roll them up into one set of dynamically
-- dispatched logic. I hate to do this though, because a benefit of the current approach is that
-- it's reasonably flexible. Say you wanted to break out vtext text and vtext hls into separate
-- lists. You could just go through everything and add that. Whereas if you had a master
-- abstraction for stat iteration, now you also have to go through and unwind that.
