local api = vim.api
local fn = vim.fn

local M = {}

---@alias nvim-tools.Range [uinteger, uinteger, uinteger, uinteger]

---Buf should be in position 5 for compatibility with vim.range.
---@alias nvim-tools.range.BufRange  [uinteger, uinteger, uinteger, uinteger, uinteger]

-- Range naming:
-- - Using a pos name means both the start and end parts of the range share the pos indexing.
--   - eval would be 1,1,1,1 - inclusive ends
--   - mark would be 1,0,1,0 - inclusive ends
-- - Range specific names:
--   - Treesitter/TS: 0,0,0,0 - exclusive end in the second pos
--   - Quickfix: 1,1,1,1 - exclusive end in the second pos

----------------------
-- MARK: Comparison --
----------------------

---@param r [integer, integer, integer, integer] Must be valid.
---@param p [integer, integer]
---@return -1|0|1
function M.cmp_pos(r, p)
    local r_sr = r[1]
    local p_r = p[1]
    local r_er = r[3]
    if r_sr <= p_r and p_r <= r_er then
        local r_sc = r[2]
        local p_c = p[2]
        if r_sr == p_r and p_c < r_sc then
            return -1
        end

        local r_ec = r[4]
        if r_er == p_r and r_ec < p_c then
            return 1
        end

        return 0
    end

    if r_er < p_r then
        return -1
    end

    return 1
end
-- TODO: This is conceptually fuzzy, because if you're talking about a range relative to a pos,
-- that introduces the concept of less than vs range end only overlapping with pos, since we
-- have that concept with range vs. range. This should be in the pos module, then just saying
-- lt/eq/gt conceptually makes sense. Usages of this would need to be inverted since pos
-- becomes the "a" object.

---Assumes ranges are valid, sorted, and do not overlap.
---@param ranges [integer, integer, integer, integer][]
---@param pos [integer, integer]
---@return uinteger?
function M.find_pos(ranges, pos)
    local ranges_len = #ranges
    if ranges_len == 0 then
        return
    end

    if ranges_len <= 16 then
        for i = 1, ranges_len do
            if M.cmp_pos(ranges[i], pos) == 0 then
                return i
            end
        end

        return
    end

    local lo = 1
    local hi = ranges_len
    local bit = require("bit")
    while lo < hi do
        local mid = bit.rshift(lo + hi, 1)
        local cmp_res = M.cmp_pos(ranges[mid], pos)
        if cmp_res == -1 then
            lo = mid + 1
        elseif cmp_res == 1 then
            hi = mid
        else
            return mid
        end
    end

    return M.cmp_pos(ranges[lo], pos) == 0 and lo or nil
end
-- TODO: this should just be able to be a generic bisect with a key to transform the ranges but
-- not the pos

---@generic T
---@param ranges (nvim-tools.Range|nvim-tools.range.BufRange)[]
---@param cmp fun(r:nvim-tools.Range|nvim-tools.range.BufRange): -1|0|1
--- -1: val < r
---  0: val == r
---  1: val > r
---@return integer
---Insert at returned index to maintain order. Returns `n+1` when you must append.
function M.bisect_lo(ranges, cmp)
    local n = #ranges
    if n == 0 then
        return 1
    end

    local bit = require("bit")
    local lo = 1
    local hi = n + 1
    while lo < hi do
        local mid = bit.rshift(lo + hi, 1)
        if cmp(ranges[mid]) <= 0 then
            hi = mid
        else
            lo = mid + 1
        end
    end

    return lo
end
-- TODO: the way this is right now is too abstract and confusing. the better way to do this I
-- think is to abstract this into a more generic list bisect function that takes two keys, one
-- for the val and one for the list. So that way you can make sure that the same transformation
-- isn't being applied to both.

---@generic T
---@param ranges (nvim-tools.Range|nvim-tools.range.BufRange)[]
---@param cmp fun(r:nvim-tools.Range|nvim-tools.range.BufRange): -1|0|1
--- -1: val < r
--- 0: val == r
--- 1: val > r
---@return integer
---Insert after returned index to maintain order. Returns `0` when you must prepend.
function M.bisect_hi(ranges, cmp)
    local ranges_len = #ranges
    if ranges_len == 0 then
        return 0
    end

    local bit = require("bit")
    local lo = 1
    local hi = ranges_len + 1
    while lo < hi do
        local mid = bit.rshift(lo + hi, 1)
        if cmp(ranges[mid]) < 0 then
            hi = mid
        else
            lo = mid + 1
        end
    end

    return lo - 1
end

---For ranges with end-inclusive indexes.
---Returns false if the start position is >= the end.
---@param r [integer, integer, integer, integer] Range.
---@return boolean
function M.valid(r)
    return r[1] < r[3] or (r[1] == r[3] and r[2] <= r[4])
end

---For ranges with end-exclusive indexes.
---Returns false if the start position is >= the end.
---@param r [integer, integer, integer, integer] Range.
---@return boolean
function M.valid_(r)
    return r[1] < r[3] or (r[1] == r[3] and r[2] < r[4])
end

---@param range [uinteger, uinteger, uinteger, uinteger]
function M.bit_pack_key(range)
    return bit.lshift(range[1], 0)
        + bit.lshift(range[2], 14)
        + bit.lshift(range[3], 24)
        + bit.lshift(range[4], 38)
end

---For ranges with end-inclusive indexing.
---Assumes both ranges are valid, meaning the start is before or equal to the end.
---@param a [integer, integer, integer, integer]
---@param b [integer, integer, integer, integer]
---@return -4|-3|-2|-1|0|1|2|3|4
---- -4: (Full containment) a ~= b and a_start <= b_start and b_end <= a_end
---- -3: (Partial overlap)  a_start < b_start, b_start <= a_end, a_end < b_end
---- -2: (Adjacency)        a_start < b_start, a_end == b_start - 1 (See: |adjacent()|)
---- -1: (Strictly Before)  a_end < b_start - 1
----  0: (Equality)         a_start == b_start, a_end == b_end
----  1: (Strictly After)   b_end < a_start - 1
----  2: (Adjacency)        b_start < a_start, b_end == a_start - 1 (See: |adjacent()|)
----  3: (Partial Overlap)  b_start < a_start, a_start <= b_end, b_end < a_end
----  4: (Full containment) b ~= a and b_start <= a_start and a_end <= b_end
function M.cmp(a, b)
    local p_cmp = require("nvim-tools.pos").cmp
    local s_s = p_cmp(a[1], a[2], b[1], b[2])
    local e_e = p_cmp(a[3], a[4], b[3], b[4])
    if s_s == -1 then
        if e_e >= 0 then
            return -4
        end

        -- Pretend the end index is exclusive for the adjacency math.
        local e_s = p_cmp(a[3], a[4] + 1, b[1], b[2])
        return -2 - e_s
    end

    if s_s == 1 then
        if e_e <= 0 then
            return 4
        end

        -- Pretend the end index is exclusive for the adjacency math.
        local s_e = p_cmp(a[1], a[2] + 1, b[3], b[4])
        return 2 - s_e
    end

    return e_e * -4
end

---For ranges with end-exclusive indexing.
---Assumes both ranges are valid, meaning the start is before the end.
---@param a [integer, integer, integer, integer]
---@param b [integer, integer, integer, integer]
---@return -4|-3|-2|-1|0|1|2|3|4
---- -4: (Full containment) a ~= b and a_start <= b_start and b_end <= a_end
---- -3: (Partial overlap)  a_start < b_start, b_start < a_end, a_end < b_end
---- -2: (Adjacency)        a_start < b_start, a_end == b_start (See: |adjacent_()|)
---- -1: (Strictly Before)  a_end < b_start
----  0: (Equality)         a_start == b_start, a_end == b_end
----  1: (Strictly After)   b_end < a_start
----  2: (Adjacency)        b_start < a_start, b_end == a_start (See: |adjacent_()|)
----  3: (Partial Overlap)  b_start < a_start, a_start < b_end, b_end < a_end
----  4: (Full containment) b ~= a and b_start <= a_start and a_end <= b_end
function M.cmp_(a, b)
    local p_cmp = require("nvim-tools.pos").cmp
    local s_s = p_cmp(a[1], a[2], b[1], b[2])
    local e_e = p_cmp(a[3], a[4], b[3], b[4])
    if s_s == -1 then
        if e_e >= 0 then
            return -4
        end

        local e_s = p_cmp(a[3], a[4], b[1], b[2])
        return -2 - e_s
    end

    if s_s == 1 then
        if e_e <= 0 then
            return 4
        end

        local s_e = p_cmp(a[1], a[2], b[3], b[4])
        return 2 - s_e
    end

    return e_e * -4
end

---@param pos_1 string
---@param pos_2 string
---@param mode? string
---@param exclusive? boolean If nil, use the option value.
---@return Range4 1,1,1,1 indexed. Exclusive based on opts
function M.get_regionpos4(pos_1, pos_2, mode, exclusive)
    vim.validate("pos_1", pos_1, "string")
    vim.validate("pos_2", pos_2, "string")
    vim.validate("mode", mode, "string", true)
    vim.validate("exclusive", exclusive, "boolean", true)

    local cur = fn.getpos(pos_1)
    local fin = fn.getpos(pos_2)

    mode = mode or "v"
    if exclusive == nil then
        ---@type string
        local sel = api.nvim_get_option_value("selection", { scope = "global" })
        exclusive = sel == "exclusive"
    end

    local region_opts = { type = mode, exclusive = exclusive }
    local region = fn.getregionpos(cur, fin, region_opts)
    return {
        region[1][1][2],
        region[1][1][3],
        region[#region][2][2],
        region[#region][2][3],
    }
end

---1,1,1,1 indexed, end inclusive.
---Modified in place. Output is 0,0,0,0 indexed, end exclusive
---@param eval_range Range4
---@param buf integer
function M.eval_to_ts(eval_range, buf)
    vim.validate("eval_range", eval_range, "table")
    local is_uint = require("nvim-tools.types").is_uint
    vim.validate("buf", buf, is_uint)

    eval_range[1] = eval_range[1] - 1
    eval_range[2] = eval_range[2] - 1

    local fin_row_0 = eval_range[3] - 1
    local line = api.nvim_buf_get_lines(buf, fin_row_0, fin_row_0 + 1, false)[1]
    if #line > 0 then
        local fin_col_1 = eval_range[4]
        local distance = vim.str_utf_end(line, fin_col_1)
        eval_range[4] = fin_col_1 + distance
    else
        eval_range[4] = 0
    end

    eval_range[3] = fin_row_0
end

---@param lnum integer 1 indexed
---@param col integer 0 for omitted, or 1 indexed, inclusive
---@param end_lnum integer 0 for omitted, or 1 indexed
---@param end_col integer 0 for omitted, or 1 indexed, exclusive
---@param vcol 0|1
---@param bufnr integer
---@return Range4 1,1,1,1 indexed, end exclusive
function M.resolve_raw_qf(lnum, col, end_lnum, end_col, vcol, bufnr)
    local is_uint = require("nvim-tools.types").is_uint
    vim.validate("lnum", lnum, is_uint)
    vim.validate("col", col, is_uint)
    vim.validate("end_lnum", end_lnum, is_uint)
    vim.validate("end_col", end_col, is_uint)
    vim.validate("bufnr", bufnr, is_uint)
    vim.validate("vcol", vcol, function()
        return vcol == 0 or vcol == 1
    end)

    local line_count = api.nvim_buf_line_count(bufnr)
    local row_1 = math.min(lnum, line_count)

    local line = api.nvim_buf_get_lines(bufnr, row_1 - 1, row_1, false)[1]
    local col_1
    local charlen
    local charidx

    if col > 0 then
        if vcol == 0 then
            col_1 = math.min(col, #line)
        else
            charlen = vim.call("strcharlen", line)
            local ntv = require("nvim-tools.vcol")
            local col_0
            col_0, _, charidx = ntv.vcol_to_byte_bounds(line, col, charlen)
            col_1 = col_0 + 1
        end
    else
        col_1 = 1
    end

    local fin_row_1 = math.min(math.max(end_lnum, row_1), line_count)
    local fin_line = fin_row_1 == row_1 and line
        or api.nvim_buf_get_lines(bufnr, fin_row_1 - 1, fin_row_1, false)[1]

    local fin_col_1_
    if end_col > 0 then
        fin_col_1_ = math.min(end_col, #fin_line + 1)
        if row_1 == fin_row_1 then
            charlen = charlen or vim.call("strcharlen", line)
            charidx = charidx or vim.call("charidx", fin_line, col_1 - 1, 1)
            local next_byteidx = charidx < charlen and vim.call("byteidx", fin_line, charidx + 1)
                or #fin_line

            fin_col_1_ = math.max(fin_col_1_, next_byteidx + 1)
        end
    else
        fin_col_1_ = #fin_line + 1
    end

    return { row_1, col_1, fin_row_1, fin_col_1_ }
end
-- TODO: Document why qf ranges are exclusive. I think if you go in the code for like vimgrep
-- it does that. And I think diagnostics are end-exclusive because they're LSP indexing. But
-- I keep forgetting why this is so it's better noted down.

---@param ranges nvim-tools.Range[]
---@return table<uinteger, true>
function M.mapped_rows_from_ranges(ranges)
    local rows = {} ---@type table<uinteger, true>
    local len_ranges = #ranges
    for i = 1, len_ranges do
        local range = ranges[i]
        local start_row = range[1]
        local end_row = range[3]
        for j = start_row, end_row do
            rows[j] = true
        end
    end

    return rows
end

---Unlike the Nvim core function, this does not handle LocationLink.
---@param location lsp.Location
---@param buf uinteger
---@return nvim-tools.range.BufRange
local function location_to_range(location, buf)
    local range = location.range -- Mandatory per the spec.
    local range_start = range.start
    local range_end = range["end"]
    return {
        range_start.line,
        range_start.character,
        range_end.line,
        range_end.character,
        buf,
    }
end
-- MID: For lists, this forces us to check the range location on each object. But I'm not sure if
-- we can assume all location results are the same format.

---Unlike the Nvim core function, this does not handle LocationLink.
---@param buf uinteger
---@param locations lsp.Location[]
---@param encoding lsp.PositionEncodingKind
---@return nvim-tools.range.BufRange[] Invalid ranges (end_col <= start_col) discarded.
function M.lsp_locations_to_api(buf, locations, encoding)
    local ntt = require("nvim-tools.table")
    local ranges = ntt.i_filter_map_to(locations, function(location)
        return location_to_range(location, buf)
    end)

    if encoding == "utf-8" then
        ntt.i_keep(ranges, function(range)
            return M.valid_(range)
        end)

        return ranges
    end

    local ranges_len = #ranges
    local range_rows = M.mapped_rows_from_ranges(ranges)
    local nts = require("nvim-tools.lsp")
    local lines = nts.get_lines(buf, range_rows)
    for i = 1, ranges_len do
        local line
        local range = ranges[i]
        local start_row = range[1]
        local start_col = range[2]
        if start_col > 0 then
            line = lines[start_row]
            start_col = vim._str_byteindex(line, start_col, encoding == "utf-16")
        end

        local end_row = range[3]
        local end_col = range[4]
        if end_col > 0 then
            if end_row ~= start_row or line == nil then
                line = lines[end_row]
            end

            end_col = vim._str_byteindex(line, end_col, encoding == "utf-16")
        end
    end

    ntt.i_keep(ranges, function(range)
        return M.valid_(range)
    end)

    return ranges
end

-------------------------
-- MARK: Range Helpers --
-------------------------

---@param a [integer, integer, integer, integer]
---@param b [integer, integer, integer, integer]
---@return boolean
function M.range_sort_predicate_asc(a, b)
    if a[1] ~= b[1] then
        return a[1] < b[1]
    end

    if a[2] ~= b[2] then
        return a[2] < b[2]
    end

    if a[3] ~= b[3] then
        return a[3] < b[3]
    end

    return a[4] < b[4]
end

return M
