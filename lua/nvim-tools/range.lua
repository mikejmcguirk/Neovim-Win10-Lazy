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

---Inclusive indexed
---@param row_a integer
---@param col_a integer
---@param fin_row_a integer
---@param fin_col_a integer
---@param row_b integer
---@param col_b integer
---@return -1|0|1
function M.cmp_pos(row_a, col_a, fin_row_a, fin_col_a, row_b, col_b)
    local is_uint = require("nvim-tools.types").is_uint
    vim.validate("row_a", row_a, is_uint)
    vim.validate("col_a", col_a, is_uint)
    vim.validate("fin_row_a", fin_row_a, is_uint)
    vim.validate("fin_col_a", fin_col_a, is_uint)
    vim.validate("row_b", row_b, is_uint)
    vim.validate("col_b", col_b, is_uint)

    if row_a <= row_b and row_b <= fin_row_a then
        if row_b == row_a and col_b < col_a then
            return -1
        elseif fin_row_a == row_b and fin_col_a < col_b then
            return 1
        else
            return 0
        end
    elseif row_b < row_a then
        return -1
    else
        return 1
    end
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

return M
