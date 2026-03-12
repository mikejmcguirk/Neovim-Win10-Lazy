-- NOTE: For iter and insertion bounds, numbers less than 1 are treated as distance from the
-- last index. For reads and deletes, 0 is the last index, -1 is second to last.
-- For insertions, 0 is an append, -1 is the last index.

local vimv = vim.v

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

---@class farsight.targets.targets.Positions
---@field len integer
---@field hashed_starts table<string, integer>
---@field start_rows integer[]
---@field start_cols integer[]
---@field hashed_fins table<string, integer>
---@field fin_rows integer[]
---@field fin_cols integer[]
---@field stats (""|"c"|"sl"|"fl"|"bl"|"sv"|"fv"|"bv")[]
---@field start_idxs integer[]
---@field fin_idxs integer[]
local Positions = {}
Positions.__index = Positions

---Edits self in-place
---@param size integer
function Positions:init(size)
    local tn = require("farsight.util")._table_new

    self.len = 0

    self.hashed_starts = tn(0, size)
    self.start_rows = tn(size, 0)
    self.start_cols = tn(size, 0)

    self.hashed_fins = tn(0, size)
    self.fin_rows = tn(size, 0)
    self.fin_cols = tn(size, 0)

    self.stats = tn(size, 0)
    self.start_idxs = tn(size, 0)
    self.fin_idxs = tn(size, 0)
end

---@param size integer
---@return farsight.targets.targets.Positions
function Positions.new(size)
    local self = setmetatable({}, Positions)
    self:init(size)
    return self
end

---Edits self in place
---idxs < 0 are treated as indexes from the end, with -1 appending.
---idx 0 is treated as idx 1
---@param idx integer
---@param start_row integer
---@param start_col integer
---@param fin_row integer
---@param fin_col integer
---@return integer Resolved idx
function Positions:insert_at(idx, start_row, start_col, fin_row, fin_col)
    local len = self.len
    idx = adj_new_idx(idx, len)

    local start_rows = self.start_rows
    local start_cols = self.start_cols
    local fin_rows = self.fin_rows
    local fin_cols = self.fin_cols

    local stats = self.stats
    local start_idxs = self.start_idxs
    local fin_idxs = self.fin_idxs

    local j = len + 1
    for i = len, idx, -1 do
        start_rows[j] = start_rows[i]
        start_cols[j] = start_cols[i]
        fin_rows[j] = fin_rows[i]
        fin_cols[j] = fin_cols[i]

        stats[j] = stats[i]
        start_idxs[j] = start_idxs[i]
        fin_idxs[j] = fin_idxs[i]

        j = j - 1
    end

    start_rows[idx] = start_row
    start_cols[idx] = start_col
    fin_rows[idx] = fin_row
    fin_cols[idx] = fin_col

    stats[idx] = ""
    start_idxs[idx] = 0
    fin_idxs[idx] = 0

    self.len = len + 1
    local start_key = create_pos_key(start_row, start_col)
    local fin_key = create_pos_key(fin_row, fin_col)
    self.hashed_starts[start_key] = idx
    self.hashed_fins[fin_key] = idx

    return idx
end

---@return integer
function Positions:get_len()
    return self.len
end

---@param idx integer
---@param fin? boolean
function Positions:get_pos(idx, fin)
    if fin then
        return self.fin_rows[idx], self.fin_cols[idx]
    else
        return self.start_rows[idx], self.start_cols[idx]
    end
end

---@param idx integer
---@return integer
function Positions:get_fin_row(idx)
    return self.fin_rows[idx]
end

---@param idx integer
---@return ""|"c"|"sl"|"fl"|"bl"|"sv"|"fv"|"bv", integer, integer
function Positions:get_stat(idx)
    return self.stats[idx], self.start_idxs[idx], self.fin_idxs[idx]
end

---@param stat ""|"c"|"sl"|"fl"|"bl"|"sv"|"fv"|"bv"
---@param start integer
---@param stop integer
---@param iter integer
local function iter_for_stat_idx(stats, stat, start, stop, iter)
    for i = start, stop, iter do
        if stats[i] == stat then
            return i
        end
    end

    return nil
end

---@param stat ""|"c"|"sl"|"fl"|"bl"|"sv"|"fv"|"bv"
---@param idx? integer
---@return integer|nil
function Positions:get_stat_start(stat, idx)
    return iter_for_stat_idx(self.stats, stat, (idx or 1), self.len, 1)
end

---@param stat ""|"c"|"sl"|"fl"|"bl"|"sv"|"fv"|"bv"
---@param idx? integer
---@return integer|nil
function Positions:get_stat_stop(stat, idx)
    return iter_for_stat_idx(self.stats, stat, (idx or self.len), 1, -1)
end

---@param idx integer
---@param stat ""|"c"|"sl"|"fl"|"bl"|"sv"|"fv"|"bv"
---@param start_idx integer
---@param fin_idx integer
function Positions:set_stat(idx, stat, start_idx, fin_idx)
    assert(idx >= 1 and idx <= self.len)
    self.stats[idx] = stat
    self.start_idxs[idx] = start_idx
    self.fin_idxs[idx] = fin_idx
end
-- PERF: This function is used a lot. I'm not sure we can do an assert here.

---Edits self in place
---idxs < 0 are treated as indexes from the end, with -1 appending.
---idx 0 is treated as idx 1
---@param idx integer
---@return integer Resolved idx. 0 if no deletion
function Positions:del_at(idx)
    local len = self.len
    idx = adj_bounded_idx(idx, len)

    local start_rows = self.start_rows
    local start_cols = self.start_cols
    local fin_rows = self.fin_rows
    local fin_cols = self.fin_cols

    local start_row = start_rows[idx]
    local start_col = start_cols[idx]
    local fin_row = fin_rows[idx]
    local fin_col = fin_cols[idx]
    local start_key = create_pos_key(start_row, start_col)
    local fin_key = create_pos_key(fin_row, fin_col)
    self.hashed_starts[start_key] = nil
    self.hashed_fins[fin_key] = nil

    local stats = self.stats
    local start_idxs = self.start_idxs
    local fin_idxs = self.fin_idxs

    local j = idx
    for i = idx + 1, len do
        start_rows[j] = start_rows[i]
        start_cols[j] = start_cols[i]
        fin_rows[j] = fin_rows[i]
        fin_cols[j] = fin_cols[i]

        stats[j] = stats[i]
        start_idxs[j] = start_idxs[i]
        fin_idxs[j] = fin_idxs[i]

        j = j + 1
    end

    start_rows[len] = nil
    start_cols[len] = nil
    fin_rows[len] = nil
    fin_cols[len] = nil

    stats[len] = nil
    start_idxs[len] = nil
    fin_idxs[len] = nil

    self.len = len - 1
    return idx
end

---@param idx integer
---@return integer
local function get_pos_idx(self, idx)
    return self.pos_idxs(idx)
end

---@class (exact) farsight.targets.targets.NoStats : farsight.meta.StatData

---@param size integer
---@return farsight.targets.targets.NoStats
local function create_new_no_stats(size)
    local tn = require("farsight.util")._table_new
    ---@type farsight.targets.targets.NoStats
    local self = {
        pos_idxs = tn(size, 0),
    }

    self.get_pos_idx = get_pos_idx

    function self:get_len()
        return #self.pos_idxs
    end

    function self:insert_at(idx, pos_idx)
        local pos_idxs = self.pos_idxs
        local len = #pos_idxs
        idx = adj_new_idx(idx, len)
        require("farsight.util").list_insert_at(pos_idxs, pos_idx, idx)

        return idx
    end

    return self
end

---Edits self in place
---Assuming self.pos_idxs is sorted least to greatest and has no duplicates, inserts the values
---pos_idx and start_label in the proper order.
---@param pos_idx integer
---@return integer Resolved idx
function No_Stats:insert_pos_idx(pos_idx)
    local pos_idxs = self.pos_idxs
    local idx = require("farsight.util").list_bisearch_left(pos_idxs, pos_idx)
    return self:insert_at(idx, pos_idx)
end

---@return integer
function No_Stats:get_len()
    return #self.pos_idxs
end

---Edits self in place
---@param idx integer
---@return integer Resolved idx. 0 if no items deleted.
function No_Stats:del_at(idx)
    local pos_idxs = self.pos_idxs
    local len = #pos_idxs
    if len < 1 then
        return 0
    end

    idx = adj_bounded_idx(idx, len)
    require("farsight.util").list_del_at(self.pos_idxs, idx)
    self.get_len = len - 1

    return idx
end

---Edits self in place
function No_Stats:clear()
    require("farsight.util").list_clear(self.pos_idxs)
end

---@class farsight.targets.targets.CharHls
---@field len integer
---@field pos_idxs integer[]
---@field chars string[]
local Char_Hls = {}
Char_Hls.__index = Char_Hls

---@param size integer
function Char_Hls:init(size)
    local tn = require("farsight.util")._table_new

    self.len = 0
    self.pos_idxs = tn(size, 0)
    self.chars = tn(size, 0)
end

---@param size integer
---@return farsight.targets.targets.CharHls
function Char_Hls.new(size)
    local self = setmetatable({}, Char_Hls)
    self:init(size)
    return self
end

---Edits self in place
---@param idx integer
---@param pos_idx integer
---@param char string
---@return integer Resolved idx
function Char_Hls:insert_at(idx, pos_idx, char)
    local len = self.len
    idx = adj_new_idx(idx, len)
    local list_insert_at_two = require("farsight.util").list_insert_at_two
    list_insert_at_two(self.pos_idxs, pos_idx, self.chars, char, idx, len)
    self.len = len + 1

    return idx
end

---Edits self in place
---Assuming self.pos_idxs is sorted least to greatest and has no duplicates, inserts the values
---pos_idx and start_label in the proper order.
---@param pos_idx integer
---@param char string
---@return integer Resolved idx
function Char_Hls:insert_pos_idx(pos_idx, char)
    local pos_idxs = self.pos_idxs
    local idx = require("farsight.util").list_bisearch_left(pos_idxs, pos_idx)
    self:insert_at(idx, pos_idx, char)

    return idx
end

---@return integer
function Char_Hls:get_len()
    return self.len
end

---@param idx integer
---@return integer
function Char_Hls:get_pos_idx(idx)
    return self.pos_idxs(idx)
end

---@param idx integer
---@param char string
function Char_Hls:update_char(idx, char)
    self.chars[idx] = char
end

---Edits self in place
---@param idx integer
---@return integer Resolved idx. 0 if no deletion.
function Char_Hls:del_at(idx)
    local len = self.len
    if len < 1 then
        return 0
    end

    idx = adj_bounded_idx(idx, len)
    local list_del_at_two = require("farsight.util").list_del_at_two
    list_del_at_two(self.pos_idxs, self.chars, idx, len)
    self.len = len - 1

    return idx
end

---Edits self in place
function Char_Hls:clear()
    local len = self.len
    local list_clear_two = require("farsight.util").list_clear_two
    list_clear_two(self.pos_idxs, self.chars, len)
    self.len = 0
end

---@class farsight.targets.targets.Labels
---@field len integer
---@field pos_idxs integer[]
---@field labels string[][]
local Labels = {}
Labels.__index = Labels

---@param size integer
function Labels:init(size)
    local tn = require("farsight.util")._table_new

    self.len = 0
    self.pos_idxs = tn(size, 0)
    self.labels = tn(size, 0)
end

---@param size integer
---@return farsight.targets.targets.Labels
function Labels.new(size)
    local self = setmetatable({}, Labels)
    self:init(size)
    return self
end

---@return integer
function Labels:get_len()
    return self.len
end

---Edits self in place
---@param idx integer
---@param pos_idx integer
---@param label string[]
---@return integer Resolved idx
function Labels:insert_at(idx, pos_idx, label)
    local len = self.len
    idx = adj_new_idx(idx, len)
    local list_insert_at_two = require("farsight.util").list_insert_at_two
    list_insert_at_two(self.pos_idxs, pos_idx, self.labels, label, idx, len)
    self.len = len + 1

    return idx
end

---Edits self in place
---Assuming self.pos_idxs is sorted least to greatest and has no duplicates, inserts the values
---pos_idx and start_label in the proper order.
---@param pos_idx integer
---@param label string[]
---@return integer Resolved idx
function Labels:insert_pos_idx(pos_idx, label)
    local pos_idxs = self.pos_idxs
    local idx = require("farsight.util").list_bisearch_left(pos_idxs, pos_idx)
    return self:insert_at(idx, pos_idx, label)
end

---Edits self in place
---@param idx integer
---@return integer Resolved idx. `0` if no deletion.
function Labels:del_at(idx)
    local len = self.len
    if len < 1 then
        return 0
    end

    idx = adj_bounded_idx(idx, len)
    local list_del_at_two = require("farsight.util").list_del_at_two
    list_del_at_two(self.pos_idxs, self.labels, idx, len)
    self.len = len - 1

    return idx
end

---Edits self in place
function Labels:clear()
    local len = self.len
    local list_clear_two = require("farsight.util").list_clear_two
    list_clear_two(self.pos_idxs, self.labels, len)
    self.len = 0
end

---@class farsight.targets.targets.Vtexts
---@field len integer
---@field pos_idxs integer[]
---@field vtexts string[][]
local Vtexts = {}
Vtexts.__index = Vtexts

---@param size integer
function Vtexts:init(size)
    local tn = require("farsight.util")._table_new

    self.len = 0
    self.pos_idxs = tn(size, 0)
    self.vtexts = tn(size, 0)
end

---@param size integer
---@return farsight.targets.targets.Vtexts
function Vtexts.new(size)
    local self = setmetatable({}, Vtexts)
    self:init(size)
    return self
end

---Edits self in place
---@param idx integer
---@param pos_idx integer
---@param vtext string[]
---@return integer Resolved idx
function Vtexts:insert_at(idx, pos_idx, vtext)
    local len = self.len
    idx = adj_new_idx(idx, len)
    local list_insert_at_two = require("farsight.util").list_insert_at_two
    list_insert_at_two(self.pos_idxs, pos_idx, self.vtexts, vtext, idx, len)
    self.len = len + 1

    return idx
end

---Edits self in place
---Assuming self.pos_idxs is sorted least to greatest and has no duplicates, inserts the values
---pos_idx and start_vtext in the proper order.
---@param pos_idx integer
---@param vtext [string, integer|string?][]
---@return integer Resolved idx
function Vtexts:insert_pos_idx(pos_idx, vtext)
    local pos_idxs = self.pos_idxs
    local idx = require("farsight.util").list_bisearch_left(pos_idxs, pos_idx)
    return self:insert_at(idx, pos_idx, vtext)
end

---@return integer
function Vtexts:get_len()
    return self.len
end

---@param idx integer
---@return integer
function Vtexts:get_pos_idx(idx)
    return self.pos_idxs(idx)
end

---@param idx integer
---@return [string, integer|string?][]
function Vtexts:get_vtext(idx)
    return self.vtexts(idx)
end

---Edits self in place
---@param idx integer
---@return integer Resolved idx. `0` if no deletion.
function Vtexts:del_at(idx)
    local len = self.len
    if len < 1 then
        return 0
    end

    idx = adj_bounded_idx(idx, len)
    local list_del_at_two = require("farsight.util").list_del_at_two
    list_del_at_two(self.pos_idxs, self.vtexts, idx, len)
    self.len = len - 1

    return idx
end

---Edits self in place
function Vtexts:clear()
    local len = self.len
    local list_clear_two = require("farsight.util").list_clear_two
    list_clear_two(self.pos_idxs, self.vtexts, len)
    self.len = 0
end

---@class farsight.targets.Targets
---@field size integer
---@field positions farsight.targets.targets.Positions
---@field no_stats farsight.targets.targets.NoStats
---@field char_hls farsight.targets.targets.CharHls
---@field start_labels farsight.targets.targets.Labels
---@field fin_labels farsight.targets.targets.Labels
---@field start_vtexts farsight.targets.targets.Vtexts
---@field fin_vtexts farsight.targets.targets.Vtexts
local Targets = {}
Targets.__index = Targets

---@param size integer
---@return farsight.targets.Targets
function Targets.new(size)
    local self = setmetatable({}, Targets)
    self:init(size)
    return self
end

---@param size integer
function Targets:init(size)
    self.size = size
    self.positions = Positions.new(size)
    self.no_stats = create_new_no_stats(size)
    self.char_hls = Char_Hls.new(size)
    self.start_labels = Labels.new(size)
    self.fin_labels = Labels.new(size)
    self.start_vtexts = Vtexts.new(size)
    self.fin_vtexts = Vtexts.new(size)
end
-- TODO: It is not necessary to create every sub-table at full size. The "join" tables should be
-- set to vim.NIL and lazily allocated. A param could also be passed for what size to allocate the
-- sub-tables (static jumps would indeed want full size. Live jumps probably only half).

---@param self farsight.targets.Targets
---@param stat ""|"c"|"sl"|"fl"|"bl"|"sv"|"fv"|"bv"
---@param start_idx integer
---@param fin_idx integer
local function del_from_stat(self, stat, start_idx, fin_idx)
    if stat == "" then
        self.no_stats:del_at(start_idx)
    elseif stat == "c" then
        self.char_hls:del_at(fin_idx)
    elseif stat == "sl" then
        self.start_labels:del_at(start_idx)
    elseif stat == "fl" then
        self.fin_labels:del_at(fin_idx)
    elseif stat == "bl" then
        self.start_labels:del_at(start_idx)
        self.fin_labels:del_at(fin_idx)
    elseif stat == "sv" then
        self.start_vtexts:del_at(start_idx)
    elseif stat == "fv" then
        self.fin_vtexts:del_at(fin_idx)
    elseif stat == "bv" then
        self.start_vtexts:del_at(start_idx)
        self.fin_vtexts:del_at(fin_idx)
    end
end
-- PERF: Test this against a hash table of functions

---@param self farsight.targets.Targets
---@param stat ""|"c"|"sl"|"fl"|"bl"|"sv"|"fv"|"bv"
---@return integer[], integer[]|nil
local function get_stat_pos_idxs(self, stat)
    if stat == "" then
        return self.no_stats.pos_idxs, nil
    elseif stat == "c" then
        return self.char_hls.pos_idxs, nil
    elseif stat == "sl" then
        return self.start_labels.pos_idxs
    elseif stat == "fl" then
        return self.fin_labels.pos_idxs, nil
    elseif stat == "bl" then
        return self.start_labels.pos_idxs, self.fin_labels.pos_idxs
    elseif stat == "sv" then
        return self.start_vtexts.pos_idxs, nil
    elseif stat == "fv" then
        return self.fin_vtexts.pos_idxs, nil
    elseif stat == "bv" then
        return self.start_vtexts.pos_idxs, self.fin_vtexts.pos_idxs
    end

    error("Invalid stat")
end
-- TODO: This cannot be the best way to handle this
-- PERF: Test this against a hash table of functions

---Edits targets in place
---@param idx integer
---@param start_row integer
---@param start_col integer
---@param fin_row integer
---@param fin_col integer
---@return integer Resolved idx
function Targets:add_new_target(idx, start_row, start_col, fin_row, fin_col)
    local positions = self.positions
    local new_idx = positions:insert_at(idx, start_row, start_col, fin_row, fin_col)

    local no_stat_idx = self.no_stats:insert_pos_idx(new_idx)
    positions:set_stat(new_idx, "", no_stat_idx, 0)

    return new_idx
end
-- PERF: Make a specific append function to skip the binary search on no_stats. Could maybe be
-- dynamically dispatched somehow.

---Errors if an invalid index is provided.
---@param idx integer
---@param char string
function Targets:set_char_hl(idx, char)
    local positions = self.positions
    local pos_len = positions:get_len()
    assert(1 <= idx and idx <= pos_len, "Cannot access an out of bounds target")

    local stat, start_idx, fin_idx = positions:get_stat(idx)
    local char_hls = self.char_hls
    if stat == "c" then
        char_hls:update_char(fin_idx, char)
        return
    end

    del_from_stat(self, stat, start_idx, fin_idx)
    local char_idx = char_hls:insert_pos_idx(idx, char)
    positions:set_stat(idx, "c", 0, char_idx)
end
-- PERF: Should be okay to have an assert here.
-- PERF: It would be better if there were a way to specify append vs binary searching

---@return integer
function Targets:get_no_stat_len()
    return self.no_stats:get_len()
end

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
---@param len integer
---@param start? integer
---@param stop? integer
---@param rev? boolean
---@return integer, integer, integer
local function get_pos_iter_bounds(len, start, stop, rev)
    if len <= 0 then
        return 0, 0, 0
    end

    start = adj_iter_input(start, 1, len)
    stop = adj_iter_input(stop, len, len)
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
    local rows = fin and self.fin_row or self.start_row
    local cols = fin and self.fin_col or self.start_col
    return rows, cols
end

---@param self farsight.targets.Targets
---@return integer[], integer[], integer[], integer[]
local function get_all_positions(self)
    return self.start_row, self.start_col, self.fin_row, self.fin_col
end

---@param self farsight.targets.Targets
---@return string[][], [string, integer|string?][][]
local function get_extmark_info(self, fin)
    local labels = fin and self.fin_labels or self.start_labels
    local vtexts = fin and self.fin_vtexts or self.start_vtexts
    return labels, vtexts
end

---@param start? integer
---@param stop? integer
---@param len integer
---@return integer, integer
local function resolve_pos_iter_bounds(start, stop, len)
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
---@param positions farsight.targets.targets.Positions
---@return integer, integer, integer
local function get_stat_iter_limits(start, stop, rev, positions, stat)
    local stat_start = positions:get_stat_start(stat, start)
    local stat_stop = positions:get_stat_stop(stat, stop)
    if not (stat_start and stat_stop and stat_start <= stat_stop) then
        return 0, 0, 0
    end

    local i = rev and stat_stop or stat_start
    local limit = rev and stat_stop or stat_start
    local iter = rev and -1 or 1
    return i, limit, iter
end

---@param start? integer
---@param stop? integer
---@param rev? boolean
---@param positions farsight.targets.targets.Positions
---@return integer, integer, integer
local function get_stat_iters(start, stop, rev, len, positions, stat)
    start, stop = resolve_pos_iter_bounds(start, stop, len)
    if not (start > 0 and stop > 0) then
        return 0, 0, 0
    end

    return get_stat_iter_limits(start, stop, rev, positions, stat)
end

---@param self farsight.targets.Targets
---@param start? integer
---@param stop? integer
---@param rev? boolean
---@param fin? boolean
---@return fun(): i:integer|nil, row:integer|nil, col:integer|nil
local function iter_no_stat_pos(self, start, stop, rev, fin)
    local positions = self.positions
    local len = positions:get_len()
    local i, limit, iter = get_stat_iters(start, stop, rev, len, positions, "")
    if not (i > 0 and limit > 0 and iter ~= 0) then
        return function() end
    end

    i = i - iter
    local no_stats = self.no_stats

    ---@return integer|nil, integer|nil, integer|nil
    return function()
        i = i + iter
        if (iter > 0 and i > limit) or (iter < 0 and i < limit) then
            return nil, nil, nil
        end

        return i, positions:get_pos(no_stats:get_pos_idx(i), fin)
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
function Targets:iter_raw_fin_pos(start, stop, rev)
    return iter_no_stat_pos(self, start, stop, rev, true)
end

---@param start? integer
---@param stop? integer
---@param rev? boolean
---@return fun(): i:integer|nil, fin_row:integer|nil
function Targets:iter_no_stat_fin_rows(start, stop, rev)
    local positions = self.positions
    local len = positions:get_len()
    local i, limit, iter = get_stat_iters(start, stop, rev, len, positions, "")
    if not (i > 0 and limit > 0 and iter ~= 0) then
        return function() end
    end

    ---@return integer|nil, integer|nil
    return function()
        i = i + iter
        if (iter > 0 and i > limit) or (iter < 0 and i < limit) then
            return nil
        end

        return i, positions:get_fin_row(i)
    end
end
-- PERF: Probably hoist fin_rows

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
    local i, limit, iter = get_stat_iters(start, stop, rev, len, positions, stat)
    if not (i > 0 and limit > 0 and iter ~= 0) then
        return function() end
    end

    i = i - iter
    local vtexts = fin and self.fin_vtexts or self.start_vtexts

    ---@return integer|nil, integer|nil, integer|nil, [string, integer|string?][]|nil
    return function()
        i = i + 1
        if (iter > 0 and i > limit) or (iter < 0 and i < limit) then
            return nil, nil, nil
        end

        local row, col = positions:get_pos(vtexts:get_pos_idx(i), fin)
        local vtext = vtexts:get_vtext(i)
        return i, row, col, vtext
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
    local positions = self.positions
    local len = positions:get_len()
    local i, limit, iter = get_stat_iters(start, stop, rev, len, positions, "c")
    if not (i > 0 and limit > 0 and iter ~= 0) then
        return function() end
    end

    local char_hls = self.char_hls
    i = i - iter

    ---@return integer|nil, integer|nil, [string, integer|string?][]|nil
    return function()
        i = i + 1
        if (iter > 0 and i > limit) or (iter < 0 and i < limit) then
            return nil, nil, nil
        end

        return i, positions:get_pos(char_hls:get_pos_idx(i), true)
    end
end

---@param start? integer
---@param stop? integer
---@param rev? boolean
---@param stop_on_keep? boolean
---@param stat? ""|"c"|"sl"|"fl"|"bl"|"sv"|"fv"|"bv"
---@param predicate fun(start_row: integer): boolean
function Targets:filter_start_row(start, stop, rev, stop_on_keep, stat, predicate)
    stat = stat or ""
    local pos_idxs, _ = get_stat_pos_idxs(self, stat)

    local positions = self.positions
    local len = positions:get_len()
    local i, limit, iter = get_stat_iters(start, stop, rev, len, positions, stat)
    if not (i > 0 and limit > 0 and iter ~= 0) then
        return
    end

    while true do
        if (iter > 0 and i > limit) or (iter < 0 and i < limit) then
            break
        end

        local pos_idx = pos_idxs[i]
        local start_row, _ = positions:get_pos(pos_idx, false)

        if not predicate(start_row) then
            self:rm_target(pos_idx)
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
-- PERF: Alternatives to the branching logic for iter advancement:
-- - Make iter fwd and iter rev separate functions
-- - Save the idxs to delete into a table, then run the deletes in reverse

---@param start? integer
---@param stop? integer
---@param rev? boolean
---@param stop_on_keep? boolean
---@param predicate fun(start_row: integer, start_col: integer, fin_row: integer, fin_col: integer): boolean
function Targets:filter_raw_both_pos(start, stop, rev, stop_on_keep, predicate)
    local idxs = self.idx
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
local function map_raw_pos(self, start, stop, rev, mapper, fin)
    local idxs = self.idx
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
function Targets:map_raw_start_pos(start, stop, rev, mapper)
    map_raw_pos(self, start, stop, rev, mapper, false)
end

---@param start? integer
---@param stop? integer
---@param rev? boolean
---@param mapper fun(start_row: integer, start_col: integer): integer, integer
function Targets:map_raw_fin_pos(start, stop, rev, mapper)
    map_raw_pos(self, start, stop, rev, mapper, true)
end

---@param start? integer
---@param stop? integer
---@param rev? boolean
---@param mapper fun(start_row: integer, start_col: integer, fin_row: integer, fin_col: integer): integer, integer, integer, integer
function Targets:map_raw_both_pos(start, stop, rev, mapper)
    local idxs = self.idx
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

---Edits label_idxs and labels in place
---@param idx integer
---@param label_idxs integer[]
---@param labels string[][]
---@return string[]
local function set_label_data(idx, label_idxs, labels)
    label_idxs[#label_idxs + 1] = idx

    local label = {}
    labels[idx] = label

    return label
end

---Edits idxs, label_idxs, and labels in place
---@param i integer
---@param idx integer
---@param idxs integer[]
---@param label_idxs integer[]
---@param labels string[][]
---@return string[]
local function set_single_label(i, idx, idxs, label_idxs, labels)
    -- local j = i
    -- local len_idxs = #idxs
    -- for k = i + 1, len_idxs do
    --     idxs[j] = idxs[k]
    --     j = j + 1
    -- end
    --
    -- idxs[len_idxs] = nil

    return set_label_data(idx, label_idxs, labels)
end

---Edits idxs, label_idxs, and labels in place
---@param i integer
---@param idx integer
---@param idxs integer[]
---@param sl_idxs integer[]
---@param sl string[][]
---@param fl_idxs integer[]
---@param fl string[][]
---@return string[], string[]
local function set_both_labels(i, idx, idxs, sl_idxs, sl, fl_idxs, fl, rev)
    -- local j = i
    -- local len_idxs = #idxs
    -- for k = i + 1, len_idxs do
    --     idxs[j] = idxs[k]
    --     j = j + 1
    -- end
    --
    -- idxs[len_idxs] = nil
    if rev then
        local fin_label = set_label_data(idx, fl_idxs, fl)
        local start_label = set_label_data(idx, sl_idxs, sl)
        return start_label, fin_label
    else
        local start_label = set_label_data(idx, sl_idxs, sl)
        local fin_label = set_label_data(idx, fl_idxs, fl)
        return start_label, fin_label
    end
end

---@param start? integer
---@param stop? integer
---@param rev? boolean
---@param count? integer
---@return fun(): string[]|nil
function Targets:alloc_start_labels(start, stop, rev, count)
    local idxs = self.idx
    local len_idxs = #idxs
    if len_idxs < 1 then
        ---@return nil
        return function()
            return nil
        end
    end

    local label_idxs = self.start_label_idxs
    local labels = self.start_labels

    count = count or len_idxs
    count = math.min(count, len_idxs)
    local i, limit, iter = get_pos_iter_bounds(len_idxs, start, stop, rev)
    i = i - iter

    ---@return string[]|nil
    return function()
        if count <= 0 then
            return nil
        end

        i = i + iter
        if (iter > 0 and i > limit) or (iter < 0 and i < limit) then
            return nil
        end

        local idx = idxs[i]
        local label = set_single_label(i, idx, idxs, label_idxs, labels)
        count = count - 1

        return label
    end
end

---@param start? integer
---@param stop? integer
---@param rev? boolean
---@param count? integer
---@return fun(): string[]|nil
function Targets:alloc_fin_labels(start, stop, rev, count)
    local idxs = self.idx
    local len_idxs = #idxs
    if len_idxs < 1 then
        ---@return nil
        return function()
            return nil
        end
    end

    local label_idxs = self.fin_label_idxs
    local labels = self.fin_labels

    count = count or len_idxs
    count = math.min(count, len_idxs)
    local i, limit, iter = get_pos_iter_bounds(len_idxs, start, stop, rev)
    i = i - iter

    ---@return string[]|nil
    return function()
        if count <= 0 then
            return nil
        end

        i = i + iter
        if (iter > 0 and i > limit) or (iter < 0 and i < limit) then
            return nil
        end

        local idx = idxs[i]
        local label = set_single_label(i, idx, idxs, label_idxs, labels)
        count = count - 1

        return label
    end
end

---@param start? integer
---@param stop? integer
---@param rev? boolean
---@param count? integer
---@return fun(): label_1:string[]|nil, label_2:string[]|nil
function Targets:alloc_both_labels(start, stop, rev, count)
    local idxs = self.idx
    local len_idxs = #idxs
    if len_idxs == 0 then
        ---@return nil
        return function()
            return nil
        end
    end

    local sl_idxs = self.start_label_idxs
    local sl = self.start_labels
    local fl_idxs = self.fin_label_idxs
    local fl = self.fin_labels

    count = count or len_idxs
    count = math.min(count, len_idxs)
    local i, limit, iter = get_pos_iter_bounds(len_idxs, start, stop, rev)
    i = i - iter

    ---@return string[]|nil, string[]|nil
    return function()
        if count < 2 then
            return nil
        end

        i = i + iter
        if (iter > 0 and i > limit) or (iter < 0 and i < limit) then
            return nil
        end

        local idx = idxs[i]
        count = count - 2
        local start_label, fin_label = set_both_labels(i, idx, idxs, sl_idxs, sl, fl_idxs, fl, rev)
        if rev then
            return fin_label, start_label
        else
            return start_label, fin_label
        end
    end
end

---@param mapper fun(label: string[]): [string, integer|string?][]
---@param label_idxs integer[]
---@param labels string[][]
---@param vtext_idxs integer[]
---@param vtexts [string, integer|string?][]
local function map_vtext_from_labels(mapper, label_idxs, labels, vtext_idxs, vtexts)
    local len_label_idxs = #label_idxs
    for i = 1, len_label_idxs do
        local idx = label_idxs[i]
        vtexts[idx] = mapper(labels[idx])
        vtext_idxs[#vtext_idxs + 1] = idx
    end
end

---@param mapper fun(label: string[]): [string, integer|string?][]
function Targets:map_start_vtext_from_labels(mapper)
    local start_label_idxs = self.start_label_idxs
    local start_labels = self.start_labels
    local start_vtext_idxs = self.start_vtext_idxs
    local start_vtexts = self.start_vtexts

    map_vtext_from_labels(mapper, start_label_idxs, start_labels, start_vtext_idxs, start_vtexts)
    local ut = require("farsight.util")
    ut.list_clear(start_label_idxs)
end

---@param mapper fun(label: string[]): [string, integer|string?][]
function Targets:map_fin_vtext_from_labels(mapper)
    local fin_label_idxs = self.fin_label_idxs
    local fin_labels = self.fin_labels
    local fin_vtext_idxs = self.fin_vtext_idxs
    local fin_vtexts = self.fin_vtexts

    map_vtext_from_labels(mapper, fin_label_idxs, fin_labels, fin_vtext_idxs, fin_vtexts)
    require("farsight.util").list_clear(fin_label_idxs)
end

---Does not verify that start and stop are valid.
---@param label_idxs integer[]
---@param r integer[]
---@param c integer[]
---@param n_r integer[]
---@param n_c integer[]
---@param labels string[][]
---@param vtext_idxs integer[]
---@param vtexts [string, integer|string?][]
---@param mapper fun(label: string[], available: integer): [string, integer|string?][]
local function map_vtexts_cmp_next(label_idxs, r, c, n_r, n_c, labels, vtext_idxs, vtexts, mapper)
    local col_distance = require("farsight.util").col_distance

    local len_label_idxs = #label_idxs
    local most_labels = len_label_idxs - 1
    for i = 1, most_labels do
        local idx = label_idxs[i]
        local row = r[idx]
        local col = c[idx]

        local next_idx = label_idxs[i + 1]
        local next_row = n_r[next_idx]
        local next_col = n_c[next_idx]

        local available = col_distance(row, col, next_row, next_col)
        vtexts[idx] = mapper(labels[idx], available)
        vtext_idxs[#vtext_idxs + 1] = idx
    end

    local idx = label_idxs[len_label_idxs]
    vtexts[idx] = mapper(labels[idx], vimv.maxcol)
    vtext_idxs[#vtext_idxs + 1] = idx
end

---@param self farsight.targets.Targets
---@param mapper fun(label: string[], available: integer): [string, integer|string?][]
---@param fin boolean
local function map_vtexts_from_labels_cmp_next_start(self, mapper, fin)
    local sl_idxs = self.start_label_idxs
    local r, c = get_positions(self, fin)
    local start_r, start_c = get_positions(self, false)
    local l, vt = get_extmark_info(self, fin)
    local vt_idxs = fin and self.fin_vtext_idxs or self.start_vtext_idxs
    map_vtexts_cmp_next(sl_idxs, r, c, start_r, start_c, l, vt_idxs, vt, mapper)
    require("farsight.util").list_clear(sl_idxs)
end

---@param mapper fun(label: string[], available: integer): [string, integer|string?][]
function Targets:map_start_vtexts_from_labels_cmp_next_start(mapper)
    map_vtexts_from_labels_cmp_next_start(self, mapper, false)
end

---@param mapper fun(label: string[], available: integer): [string, integer|string?][]
function Targets:map_fin_vtexts_from_labels_cmp_next_start(mapper)
    map_vtexts_from_labels_cmp_next_start(self, mapper, true)
end

---@param mapper fun(label: string[], available: integer): [string, integer|string?][]
function Targets:map_start_vtexts_from_labels_cmp_fin(mapper)
    local start_labels, start_vtexts = get_extmark_info(self, false)
    local start_rows, start_cols, fin_rows, fin_cols = get_all_positions(self)
    local start_vtext_idxs = self.start_vtext_idxs

    local ut = require("farsight.util")
    local col_distance = ut.col_distance

    local start_label_idxs = self.start_label_idxs
    local len_start_label_idxs = #start_label_idxs
    for i = 1, len_start_label_idxs do
        local idx = start_label_idxs[i]
        local start_row = start_rows[idx]
        local start_col = start_cols[idx]
        local fin_row = fin_rows[idx]
        local fin_col = fin_cols[idx]

        local available = col_distance(start_row, start_col, fin_row, fin_col)
        start_vtexts[idx] = mapper(start_labels[idx], available)
        start_vtext_idxs[#start_vtext_idxs + 1] = idx
    end

    ut.list_clear(start_label_idxs)
end

---@param mapper fun(label: string[], available: integer): [string, integer|string?][]
function Targets:map_fin_vtexts_from_labels_cmp_next_fin(mapper)
    local fl_idxs = self.fin_label_idxs
    local fin_r, fin_c = get_positions(self, true)
    local fin_l, fin_vt = get_extmark_info(self, true)
    local fin_vt_idxs = self.fin_vtext_idxs
    map_vtexts_cmp_next(fl_idxs, fin_r, fin_c, fin_r, fin_c, fin_l, fin_vt_idxs, fin_vt, mapper)
end

---@param i integer
---@param fin_row integer
---@param fin_col integer
function Targets:set_fin_pos(i, fin_row, fin_col)
    local idx = self.idx[i]
    self.fin_row[idx] = fin_row
    self.fin_col[idx] = fin_col
end
-- MID: This function creates redundancy because it has to get the idx after the iterator has
-- already done so. But it seems wasteful to create a complicated mapping function for one case,
-- and I don't want the iterators exposing idx.

---Errors if an invalid index is provided.
---@param idx integer
---@return integer Targets remaining
function Targets:rm_target(idx)
    local positions = self.positions
    local len_pos = positions:get_len()
    assert(idx >= 1 and idx <= len_pos, "Cannot delete an out of bounds target")

    del_from_stat(self, positions:get_stat(idx))
    positions:del_at(idx)
    return positions:get_len()
end
-- MAYBE: Could add a conditional stat filter, but that adds more branching logic.
-- PERF: Is this run enough for the assertion to be a problem?

return Targets

-- TODO: I'm not sure why any of the exposed functions in here take optional vars since they
-- aren't user facing.
-- TODO: The various insert_at functions do not handle duplicates. This might be okay, since it
-- adds complexity to the underlying algorithms, but puts pressure on targets to properly
-- mediate status.
-- TODO: While it's conceptually helpful, I'm not sure to what extent the sub-tables should be
-- treated as objects, as the indirection adds overhead. You could treat it like public read/
-- private write, but still tough because private write still adds layers of indirection in hot
-- paths.

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
