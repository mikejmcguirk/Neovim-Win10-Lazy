local api = vim.api
local fn = vim.fn

local M = {}

-- Range naming:
-- - Using a pos name means both the start and end parts of the range share the pos indexing.
--   - eval would be 1,1,1,1 - inclusive ends
--   - mark would be 1,0,1,0 - inclusive ends
-- - Range specific names:
--   - Treesitter/TS: 0,0,0,0 - exclusive end in the second pos
--   - Quickfix: 1,1,1,1 - exclusive end in the second pos

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

---Assumes ranges are valid, sorted, and do not overlap.
---@param ranges [integer, integer, integer, integer][]
---@param pos [integer, integer]
---@return boolean
function M.ranges_have_pos(ranges, pos)
    local ranges_len = #ranges
    if ranges_len == 0 then
        return false
    end

    if ranges_len <= 16 then
        for i = 1, ranges_len do
            if M.cmp_pos(ranges[i], pos) == 0 then
                return true
            end
        end

        return false
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
            return true
        end
    end

    return M.cmp_pos(ranges[lo], pos) == 0
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

---For ranges with end-inclusive indexing.
---- Assumes both ranges are valid, meaning the start is before or equal to the end.
---- Handles both a before b and b before a. a before b is checked first.
---- Only handles same-line adjacency.
---- Because an end-inclusive range of, say, 1,1,1,1 is valid, it is possible for two end-inclusive
---ranges to both overlap and be adjacent (unlike with end-exclusive ranges).
---- Note that end-inclusive ranges do not inherently capture multi-byte characters. This function
---does not take any of the underlying data needed to resolve them.
---@param a [integer, integer, integer, integer]
---@param b [integer, integer, integer, integer]
---@return boolean
function M.adjacent(a, b)
    return (a[3] == b[1] and a[4] == b[2] - 1) or (b[3] == a[1] and b[4] == a[2] - 1)
end

---For ranges with end-exclusive indexing.
---- Assumes both ranges are valid, meaning the start is before the end.
---- Handles both a before b and b before a. a before b is checked first.
---- Only handles same-line adjacency.
---- This could provide a false-positive for Treesitter and LSP end indexes that wrap to the next
---line. Those must be first converted to Neovim's |api-indexing|.
---@param a [integer, integer, integer, integer]
---@param b [integer, integer, integer, integer]
---@return boolean
function M.adjacent_(a, b)
    return (a[3] == b[1] and a[4] == b[2]) or (b[3] == a[1] and b[4] == a[2])
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

---@param qf_range Range4
function M.qf_to_ts(qf_range)
    vim.validate("qf_range", qf_range, "table")

    qf_range[1] = qf_range[1] - 1
    qf_range[2] = qf_range[2] - 1
    qf_range[3] = qf_range[3] - 1
    qf_range[4] = qf_range[4] - 1
end

-- TODO: find somewhere to put the LSP stuff

---@param ranges [integer, integer, integer, integer][]
---@return table<integer, true>
local function lsp_ranges_rows_needed_get(ranges)
    local rows_needed = {} ---@type table<integer, true>
    for _, range in ipairs(ranges) do
        rows_needed[range[1]] = true
        rows_needed[range[3]] = true
    end

    return rows_needed
end

---@param buf integer
---@param ranges [integer, integer, integer, integer][]
---@return table<integer, string>
local function lsp_range_lines_from_buf_loaded(buf, ranges)
    local rows_needed = lsp_ranges_rows_needed_get(ranges)
    local lines = {} ---@type table<integer, string>
    for row, _ in pairs(rows_needed) do
        lines[row] = api.nvim_buf_get_lines(buf, row, row + 1, false)[1] or ""
    end

    return lines
end

---@param buf integer
---@param ranges [integer, integer, integer, integer][]
---@return table<integer, string>
local function lsp_range_lines_get(buf, ranges)
    if api.nvim_buf_is_loaded(buf) then
        return lsp_range_lines_from_buf_loaded(buf, ranges)
    end

    if not vim.startswith(vim.uri_from_bufnr(buf), "file://") then
        fn.bufload(buf)
        return lsp_range_lines_from_buf_loaded(buf, ranges)
    end

    local lines = {}
    -- TODO: Use uv to do this.
    local ok, f_str = pcall(fn.readblob, api.nvim_buf_get_name(buf))
    if not ok then
        -- TODO: This is not a viable answer
        return lines
    end

    -- TODO: Even after switching to uv, can you split on just "\n" or do you need to account for
    -- "\r\n" and "\r"? Does that affect docgen?
    -- TODO: Is there a reason vim.gmatch was used here originally?
    -- TODO: It might be necessary for the get lines function to return the count of lines
    -- needed so we can do gsplit or gmatch here. Because I have to imagine it is slow to
    -- eagerly split all lines when we only need a subset of them.
    -- TODO: Would it be fastest to do string.find here and count the number of results, given
    -- that find does not immediately pull the substring. I think you would use the gmatch
    -- pattern there.
    local f_lines = vim.split(f_str, "\n")
    if #f_lines == 0 then
        -- TODO: again this can't be the answer
        return lines
    end

    local rows_needed = lsp_ranges_rows_needed_get(ranges)
    for row, _ in pairs(rows_needed) do
        lines[row] = f_lines[row + 1]
    end

    return lines
end

---Encoding ~= UTF-8 is not checked here to avoid redundancy. Callers should do so to avoid calling
---this function needlessly.
---@param buf integer
---@param ranges [integer, integer, integer, integer][] Modified in place!
function M.lsp_parsed_locations_convert(buf, ranges, encoding)
    local lines = lsp_range_lines_get(buf, ranges)
    for _, range in ipairs(ranges) do
        local start_row = ranges[1]
        local start_col = ranges[2]
        if start_col > 0 then
            local line = lines[start_row]
            range[2] = vim._str_byteindex(line, start_col, encoding == "utf-16")
        end

        local end_row = ranges[1]
        local end_col = ranges[2]
        if end_col > 0 then
            local line = lines[end_row]
            range[2] = vim._str_byteindex(line, end_col, encoding == "utf-16")
        end
    end
end
-- TODO: Bad naming. Implies that the data type is changing.
-- TODO: This feels bad because it doesn't use the pos helper. But there's no way to pass the
-- lines helper into there without it being illogical. If I remember right, the vim.pos helper
-- goes through the entire procedure to get a lines table even for only converting one position,
-- which is too much.

-------------------------
-- MARK: Range Helpers --
-------------------------

---@param a [integer, integer, integer, integer]
---@param b [integer, integer, integer, integer]
---@return boolean
function M.range_sort_predicate(a, b)
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
