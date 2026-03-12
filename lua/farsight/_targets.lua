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

---@class farsight.targets.Positions
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
---@return integer, integer
function Positions:get_pos(idx, fin)
    if fin then
        return self.fin_rows[idx], self.fin_cols[idx]
    else
        return self.start_rows[idx], self.start_cols[idx]
    end
end

---@param fin boolean
---@return integer[]
function Positions:get_rows(fin)
    return fin and self.fin_rows or self.start_rows
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

---@param size integer
---@return farsight.targets.Positions
function Positions.new(size)
    local self = setmetatable({}, Positions)
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

    return self
end

---@class (exact) farsight.targets.StatData
---@field pos_idxs integer[]
---Return the new idx
---@field insert_at fun(self:farsight.targets.StatData, idx:integer, pos_idx:integer, ...:any): resolved_idx:integer
---For a given pos_idx, perform a binary search so that it can be inserted in order along with its
---related content
---@field insert_pos_idx fun(self:farsight.targets.StatData, pos_idx:integer, ...:any): resolved_idx:integer
---@field get_len fun(self:farsight.targets.StatData): len:integer
---@field get_pos_idx fun(self:farsight.targets.StatData, idx:integer): pos_idx:integer
---@field get_pos_idxs fun(self:farsight.targets.StatData): pos_idxs:integer[]
---@field clear fun(self:farsight.targets.StatData)
---@field del_at fun(self:farsight.targets.StatData, idx:integer): del_idx:integer

---@param self farsight.targets.StatData
---@param idx integer
---@return integer
local function get_pos_idx(self, idx)
    return self.pos_idxs(idx)
end

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

---@param idx integer
---@param pos_idx integer
---@return integer
function No_Stats:insert_at(idx, pos_idx)
    local pos_idxs = self.pos_idxs
    local len = #pos_idxs
    idx = adj_new_idx(idx, len)
    require("farsight.util").list_insert_at(pos_idxs, pos_idx, idx)

    return idx
end

---@param pos_idx integer
---@return integer
function No_Stats:insert_pos_idx(pos_idx)
    local bisearch_left = require("farsight.util").list_bisearch_left
    local pos_idxs = self.pos_idxs
    local idx = bisearch_left(pos_idxs, pos_idx)
    return self:insert_at(idx, pos_idx)
end

---@return integer
function No_Stats:get_len()
    return #self.pos_idxs
end

No_Stats.get_pos_idx = get_pos_idx
No_Stats.get_pos_idxs = get_pos_idxs

function No_Stats:clear()
    require("farsight.util").list_clear(self.pos_idxs)
end

---@param idx integer
---@return integer
function No_Stats:del_at(idx)
    local pos_idxs = self.pos_idxs
    local len = #pos_idxs
    if len < 1 then
        return 0
    end

    idx = adj_bounded_idx(idx, len)
    require("farsight.util").list_del_at(self.pos_idxs, idx)

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

---@param idx integer
---@param pos_idx integer
---@param char string
---@return integer
function Char_Hls:insert_at(idx, pos_idx, char)
    local len = self.len
    idx = adj_new_idx(idx, len)

    local list_insert_at_two = require("farsight.util").list_insert_at_two
    list_insert_at_two(self.pos_idxs, pos_idx, self.chars, char, idx, len)
    self.len = len + 1

    return idx
end

---@param pos_idx integer
---@param char string
---@return integer
function Char_Hls:insert_pos_idx(pos_idx, char)
    local pos_idxs = self.pos_idxs
    local idx = require("farsight.util").list_bisearch_left(pos_idxs, pos_idx)
    self:insert_at(idx, pos_idx, char)

    return idx
end

function Char_Hls:get_len()
    return self.len
end

Char_Hls.get_pos_idx = get_pos_idx
Char_Hls.get_pos_idxs = get_pos_idxs

function Char_Hls:clear()
    local len = self.len
    local list_clear_two = require("farsight.util").list_clear_two
    list_clear_two(self.pos_idxs, self.chars, len)
    self.len = 0
end

---@param idx integer
---@return integer
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

---@param idx integer
---@param char string
function Char_Hls:update_char(idx, char)
    self.chars[idx] = char
end

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

---@param pos_idx integer
---@param label string[]
---@return integer Resolved idx
function Labels:insert_pos_idx(pos_idx, label)
    local pos_idxs = self.pos_idxs
    local idx = require("farsight.util").list_bisearch_left(pos_idxs, pos_idx)
    return self:insert_at(idx, pos_idx, label)
end

function Labels:get_len()
    return self.len
end

Labels.get_pos_idx = get_pos_idx
Labels.get_pos_idxs = get_pos_idxs

---Edits self in place
function Labels:clear()
    local len = self.len
    local list_clear_two = require("farsight.util").list_clear_two
    list_clear_two(self.pos_idxs, self.labels, len)
    self.len = 0
end

---@param idx integer
---@return integer
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

---@param pos_idx integer
---@param vtext [string, integer|string?][]
---@return integer Resolved idx
function Vtexts:insert_pos_idx(pos_idx, vtext)
    local pos_idxs = self.pos_idxs
    local idx = require("farsight.util").list_bisearch_left(pos_idxs, pos_idx)
    return self:insert_at(idx, pos_idx, vtext)
end

function Vtexts:get_len()
    return self.len
end

Vtexts.get_pos_idx = get_pos_idx
Vtexts.get_pos_idxs = get_pos_idxs

function Vtexts:clear()
    local len = self.len
    local list_clear_two = require("farsight.util").list_clear_two
    list_clear_two(self.pos_idxs, self.vtexts, len)
    self.len = 0
end

---@param idx integer
---@return integer
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

---@param idx integer
---@return [string, integer|string?][]
function Vtexts:get_vtext(idx)
    return self.vtexts(idx)
end

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

---@param self farsight.targets.Targets
---@param stat ""|"c"|"sl"|"fl"|"bl"|"sv"|"fv"|"bv"
---@param start_idx integer
---@param fin_idx integer
local function del_at_from_stat(self, stat, start_idx, fin_idx)
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
        return self.no_stats:get_pos_idxs(), nil
    elseif stat == "c" then
        return self.char_hls:get_pos_idxs(), nil
    elseif stat == "sl" then
        return self.start_labels:get_pos_idxs()
    elseif stat == "fl" then
        return self.fin_labels:get_pos_idxs(), nil
    elseif stat == "bl" then
        return self.start_labels:get_pos_idxs(), self.fin_labels:get_pos_idxs()
    elseif stat == "sv" then
        return self.start_vtexts:get_pos_idxs(), nil
    elseif stat == "fv" then
        return self.fin_vtexts:get_pos_idxs(), nil
    elseif stat == "bv" then
        return self.start_vtexts:get_pos_idxs(), self.fin_vtexts:get_pos_idxs()
    end

    error("Invalid stat")
end
-- TODO: This cannot be the best way to handle this
-- PERF: Test this against a hash table of functions

---@param idx integer
---@param start_row integer
---@param start_col integer
---@param fin_row integer
---@param fin_col integer
---@return integer Resolved idx
function Targets:insert_at(idx, start_row, start_col, fin_row, fin_col)
    local positions = self.positions
    local new_idx = positions:insert_at(idx, start_row, start_col, fin_row, fin_col)

    local no_stat_idx = self.no_stats:insert_pos_idx(new_idx)
    positions:set_stat(new_idx, "", no_stat_idx, 0)

    return new_idx
end
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
local function adj_bounded_idxs(start, stop, len)
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
---@param positions farsight.targets.Positions
---@return integer, integer, integer
local function get_adj_stat_iters(start, stop, rev, len, positions, stat)
    start, stop = adj_bounded_idxs(start, stop, len)
    if not (start > 0 and stop > 0) then
        return 0, 0, 0
    end

    return get_stat_iters(start, stop, rev, positions, stat)
end

-- you have stats table
-- you have the stat start and fin index maps, which are used for handling double data. so if
-- you have both labels, the start idx is where the pos_idx is in the start labels, and fin
-- maps to wher eit is in fin_labels
-- so get stat iters is wrong because it just pulls the idx of the stat flag, but it doesn't
-- tie it back to the start idx in the stat table
-- so combinatorically you have:
-- - what stat?
-- - which idx set? (start, fin, both)
-- - which position? (start, fin, both)
-- a problem is, if we think about the design, why would we be supporting a mix of different
-- label and vtext types? You would have to do weird, hacky stuff to iterate through them
-- if I were doing it in a database, thinking through a couple of them
-- - for no_stat, I would be in the main pos table, would filter by the flag. since no_stat has
-- no additional table, there's no join. This is why no_stat here is just a list of pos_idxs
-- - If I wanted char_hls, I would also just filter on the flag. I only have the chars stored
-- here for persistence. Note too that, if this were actually a table, we wouldn't tie char_hl to
-- either start or fin. That would be program logic. Should we be doing that here?
-- - So now for labels, would I have start_labels and fin_labels in separate tables with stats
-- saying which one to join? Or would I have both labels in one table?
-- - A very important thing to remember is - if you're doing both labels, when do you change the
-- flag from label to vtext?
-- - So what it seems needs to be done is to have start_stat and fin_stat as separate constructs
-- - This then instrinsically ties stat to position, which eliminates some combinatorial
-- complexity. While this adds some additional setup nonsense, this also eliminates some weird
-- questions about data consistency. Basically, you would always setup start and stop as
-- no_stat, and then only advance the one you want
-- - note that del_at logic needs to account for this, as does insert_at
-- - you do also need to have separate StatData tables for start and stop, and the program logic
-- needs to account for that. An important argument for lazy initializing sub-tables. we have to
-- eat building no_stat for start and stop, but we don't have to allocate labels the whole way
-- - And then the final issue is how to handle "both" iterations. If I'm querying a db, it would
-- be like:
-- SELECT * FROM positions WHERE start_stat = "l" and fin_stat = "l";
-- Or it would be like some kind of list.zip thing
-- This also gets back to the inconsistent label issue. For a "both" iteration, you could step
-- through and only read positions where start and fin are "l". But if you're doing something like
-- cursor aware, then you have to do that iter step but only pull out the start label
-- hard to pre-allocate labels due to combinatorial complexity. could pre-allocate the ones that
-- matter like l/l and v/v, but hacky.
-- - also a problem because you have to build the combo label iteration twice. once to pull the
-- refs and another one or two to allocate the vtexts (this might not be quite true though due
-- to the iters not being dependent. you can do an iter over start for start to fin then an
-- iter over fin for fin to next start). But in the "both" case I think you're still locked
-- into this. Actually no you're not because if you're doing fin, you need the next active start
-- label. It doesn't matter if next start has an associated label. But raises additional weird
-- question - How do the iters know what the next label is? You can say progrma logic tells you
-- what the comparison is. But let's say different label types are layered.
-- - however the data is represented, conceptually, we need to eliminate possibilities and say
-- that only one label placement type is possible. start only, fin only, cursor aware, or
-- both. You will not do cursor aware and randomly arrive at a fin label in the middle of the
-- pre-cursor results.
-- - for labels, in a database, I would do foreign key and start/fin as separate columns. this
-- eliminates having to do two tables and elimintes having to check NULLs. and then you would
-- do stat/stat = l/l and inner join so no NULLs return. this kinda sorta points to the ideas I've
-- had above, but still points to the double iterator assembly problem.
-- - for dual iteration, we will do on-the-fly comparisons rather than allocating. we can profile
-- against allocating later.
-- - so then, roughly, in terms of the interfaces you want, although I don't want to speculatively
-- build everything:
--   - one stat, one pos
--   - one stat, both pos
--   - both stat, one pos
--   - both stat, both pos
-- So what I would want to do is not exactly build all of them, but keep this list of combos as
-- a note for like, if we need to access an iter to do something, build off of one of those
-- interfaces if we have them, make the underlying broader interface if it doesn't exist
-- The underlying primitives then need to be composable for this purpose, rather than baking
-- in assumptions at any particular step

---@param self farsight.targets.Targets
---@param start? integer
---@param stop? integer
---@param rev? boolean
---@param fin boolean
---@param stat ""|"c"|"sl"|"fl"|"bl"|"sv"|"fv"|"bv"
---@return fun(): i:integer|nil, row:integer|nil, col:integer|nil
local function iter_stat_pos(self, start, stop, rev, fin, stat)
    local positions = self.positions
    local len = positions:get_len()
    local i, limit, iter = get_adj_stat_iters(start, stop, rev, len, positions, stat)
    if not (i > 0 and limit > 0 and iter ~= 0) then
        return function() end
    end

    i = i - iter
    local pos_idxs, _ = get_stat_pos_idxs(self, stat)
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

---@param start? integer
---@param stop? integer
---@param rev? boolean
---@return fun(): idx:integer|nil, start_row:integer|nil, start_col:integer|nil
function Targets:iter_no_stat_start_pos(start, stop, rev)
    return iter_stat_pos(self, start, stop, rev, false, "")
end

---@param start? integer
---@param stop? integer
---@param rev? boolean
---@return fun(): idx:integer|nil, fin_row:integer|nil, fin_col:integer|nil
function Targets:iter_no_stat_fin_pos(start, stop, rev)
    return iter_stat_pos(self, start, stop, rev, true, "")
end

---@param self farsight.targets.Targets
---@param start? integer
---@param stop? integer
---@param rev? boolean
---@param fin boolean
---@param stat ""|"c"|"sl"|"fl"|"bl"|"sv"|"fv"|"bv"
---@return fun(): i:integer|nil, row:integer|nil, col:integer|nil
local function iter_stat_rows(self, start, stop, rev, fin, stat)
    local positions = self.positions
    local len = positions:get_len()
    local i, limit, iter = get_adj_stat_iters(start, stop, rev, len, positions, stat)
    if not (i > 0 and limit > 0 and iter ~= 0) then
        return function() end
    end

    i = i - iter
    local pos_idxs, _ = get_stat_pos_idxs(self, stat)
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
    return iter_stat_rows(self, start, stop, rev, false, "")
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
    local i, limit, iter = get_adj_stat_iters(start, stop, rev, len, positions, stat)
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
    return iter_stat_pos(self, start, stop, rev, true, "c")
end

---@param start? integer
---@param stop? integer
---@param rev? boolean
---@param stop_on_keep? boolean
---@param predicate fun(start_row: integer): boolean
function Targets:filter_no_stat_start_rows(start, stop, rev, stop_on_keep, predicate)
    local positions = self.positions
    local rows = positions:get_rows(false)
    local pos_idxs, _ = get_stat_pos_idxs(self, "")

    local len = positions:get_len()
    local i, limit, iter = get_adj_stat_iters(start, stop, rev, len, positions, "")
    if not (i > 0 and limit > 0 and iter ~= 0) then
        return
    end

    while true do
        if (iter > 0 and i > limit) or (iter < 0 and i < limit) then
            break
        end

        local pos_idx = pos_idxs[i]
        local start_row = rows[pos_idx]

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
-- PERF: Alternatives to the branching logic for iter advancement:
-- - Make iter fwd and iter rev separate functions
-- - Save the idxs to delete into a table, then run the deletes in reverse

---@param start? integer
---@param stop? integer
---@param rev? boolean
---@param stop_on_keep? boolean
---@param predicate fun(start_row: integer, start_col: integer, fin_row: integer, fin_col: integer): boolean
function Targets:filter_no_stat_both_pos(start, stop, rev, stop_on_keep, predicate)
    local pos_idxs, _ = get_stat_pos_idxs(self, "")

    local positions = self.positions
    local start_rows, start_cols = positions:get_positions(false)
    local fin_rows, fin_cols = positions:get_positions(true)

    local len = positions:get_len()
    local i, limit, iter = get_adj_stat_iters(start, stop, rev, len, positions, "")
    if not (i > 0 and limit > 0 and iter ~= 0) then
        return
    end

    while true do
        if (iter > 0 and i > limit) or (iter < 0 and i < limit) then
            break
        end

        local pos_idx = pos_idxs[i]
        local start_row = start_rows[pos_idx]
        local start_col = start_cols[pos_idx]
        local fin_row = fin_rows[pos_idx]
        local fin_col = fin_cols[pos_idx]

        if not predicate(start_row, start_col, fin_row, fin_col) then
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

---@param self farsight.targets.Targets
---@param start? integer
---@param stop? integer
---@param rev? boolean
---@param mapper fun(start_row: integer, start_col: integer): integer, integer
---@param stat ""|"c"|"sl"|"fl"|"bl"|"sv"|"fv"|"bv"
---@param fin boolean
local function map_stat_pos(self, start, stop, rev, mapper, stat, fin)
    local positions = self.positions
    local len = positions:get_len()
    local i, limit, iter = get_adj_stat_iters(start, stop, rev, len, positions, "")
    if not (i > 0 and limit > 0 and iter ~= 0) then
        return
    end

    local rows, cols = positions:get_positions(fin)
    local pos_idxs, _ = get_stat_pos_idxs(self, stat)

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
    map_stat_pos(self, start, stop, rev, mapper, "", false)
end

---@param start? integer
---@param stop? integer
---@param rev? boolean
---@param mapper fun(start_row: integer, start_col: integer): integer, integer
function Targets:map_no_stat_fin_pos(start, stop, rev, mapper)
    map_stat_pos(self, start, stop, rev, mapper, "", true)
end

---@param self farsight.targets.Targets
---@param start? integer
---@param stop? integer
---@param rev? boolean
---@param stat ""|"c"|"sl"|"fl"|"bl"|"sv"|"fv"|"bv"
---@param mapper fun(start_row: integer, start_col: integer, fin_row: integer, fin_col: integer): integer, integer, integer, integer
local function map_stat_both_pos(self, start, stop, rev, stat, mapper)
    local positions = self.positions
    local len = positions:get_len()
    local i, limit, iter = get_adj_stat_iters(start, stop, rev, len, positions, stat)
    if not (i > 0 and limit > 0 and iter ~= 0) then
        return
    end

    local start_rows, start_cols = positions:get_positions(false)
    local fin_rows, fin_cols = positions:get_positions(true)
    local pos_idxs, _ = get_stat_pos_idxs(self, stat)

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
    map_stat_both_pos(self, start, stop, rev, "", mapper)
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

---@param self farsight.targets.Targets
---@param start? integer
---@param stop? integer
---@param count? integer
---@param fin boolean
---@param stat ""|"c"|"sl"|"fl"|"bl"|"sv"|"fv"|"bv"
local function set_start_labels_on_stat(self, start, stop, count, fin, stat)
    local positions = self.positions
    local len = positions:get_len()
    local i, limit, iter = get_adj_stat_iters(start, stop, true, len, positions, stat)
    if not (i > 0 and limit > 0 and iter ~= 0) then
        return function() end
    end

    count = count or len
    count = math.min(count, len)
    local start_pos_idxs, fin_pos_idxs = get_stat_pos_idxs(self, stat)
    local pos_idxs = fin and fin_pos_idxs or start_pos_idxs
    local labels = self.start_labels
    -- TODO: Unsure how to tie together the different stat table levels

    while true do
        if (iter > 0 and i > limit) or (iter < 0 and i < limit) then
            break
        end

        local pos_idx = pos_idxs[i]
        no_stats:del_at(i)
        local label_idx = labels:insert_pos_idx(pos_idx, {})
        positions:set_stat(pos_idx, "sl", label_idx, 0)

        i = i + iter
    end
end

---@param start? integer
---@param stop? integer
---@param count? integer
function Targets:set_start_labels_on_no_stat(start, stop, count)
    local positions = self.positions
    local len = positions:get_len()
    local i, limit, iter = get_adj_stat_iters(start, stop, true, len, positions, "")
    if not (i > 0 and limit > 0 and iter ~= 0) then
        return function() end
    end

    count = count or len
    count = math.min(count, len)
    local pos_idxs, _ = get_stat_pos_idxs(self, "")
    local start_labels = self.start_labels
    local no_stats = self.no_stats

    while true do
        if (iter > 0 and i > limit) or (iter < 0 and i < limit) then
            break
        end

        local pos_idx = pos_idxs[i]
        no_stats:del_at(i)
        local label_idx = start_labels:insert_pos_idx(pos_idx, {})
        positions:set_stat(pos_idx, "sl", label_idx, 0)

        i = i + iter
    end

    set_start_labels_on_stat()
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

    del_at_from_stat(self, stat, start_idx, fin_idx)
    local char_idx = char_hls:insert_pos_idx(idx, char)
    positions:set_stat(idx, "c", 0, char_idx)
end
-- PERF: Should be okay to have an assert here.
-- PERF: It would be better if there were a way to specify append vs binary searching

---Errors if an invalid index is provided.
---@param idx integer
---@return integer Targets remaining
function Targets:rm_target(idx)
    local positions = self.positions
    local len_pos = positions:get_len()
    assert(idx >= 1 and idx <= len_pos, "Cannot delete an out of bounds target")

    del_at_from_stat(self, positions:get_stat(idx))
    positions:del_at(idx)
    return positions:get_len()
end
-- MAYBE: Could add a conditional stat filter, but that adds more branching logic.
-- PERF: Is this run enough for the assertion to be a problem?

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
-- TODO: The various insert_at functions do not handle duplicates. This might be okay, since it
-- adds complexity to the underlying algorithms, but puts pressure on targets to properly
-- mediate status.
-- TODO: While it's conceptually helpful, I'm not sure to what extent the sub-tables should be
-- treated as objects, as the indirection adds overhead. You could treat it like public read/
-- private write, but still tough because private write still adds layers of indirection in hot
-- paths.
-- TODO: I have the char_hl chars stored here on the assumption that I might need to re-use the
-- char later. If I don't, the data structure could be simplified by removing it.

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
