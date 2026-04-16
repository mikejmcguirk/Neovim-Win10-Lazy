local api = vim.api

---Design goal: Provide position functions that work with low overhead in a procedural context.
local M = {}

-------------------------------
-- MARK: Position Comparison --
-------------------------------

---@param row_a integer
---@param col_a integer
---@param row_b integer
---@param col_b integer
---@return -1|0|1
function M.cmp(row_a, col_a, row_b, col_b)
    local is_uint = require("nvim-tools.types").is_uint
    vim.validate("row_a", row_a, is_uint)
    vim.validate("col_a", col_a, is_uint)
    vim.validate("row_b", row_b, is_uint)
    vim.validate("col_b", col_b, is_uint)

    if row_a == row_b then
        if col_a < col_b then
            return -1
        elseif col_b < col_a then
            return 1
        else
            return 0
        end
    elseif row_a < row_b then
        return -1
    else
        return 1
    end
end

---@param row_a integer
---@param col_a integer
---@param row_b integer
---@param col_b integer
---@return boolean
function M.eq(row_a, col_a, row_b, col_b)
    local is_uint = require("nvim-tools.types").is_uint
    vim.validate("row_a", row_a, is_uint)
    vim.validate("col_a", col_a, is_uint)
    vim.validate("row_b", row_b, is_uint)
    vim.validate("col_b", col_b, is_uint)

    return row_a == row_b and col_a == col_b
end

---For >=, use not lt
---@param row_a integer
---@param col_a integer
---@param row_b integer
---@param col_b integer
---@return boolean
function M.lt(row_a, col_a, row_b, col_b)
    local is_uint = require("nvim-tools.types").is_uint
    vim.validate("row_a", row_a, is_uint)
    vim.validate("col_a", col_a, is_uint)
    vim.validate("row_b", row_b, is_uint)
    vim.validate("col_b", col_b, is_uint)

    return row_a < row_b or row_a == row_b and col_a < col_b
end

---For <=, use not gt
---@param row_a integer
---@param col_a integer
---@param row_b integer
---@param col_b integer
---@return boolean
function M.gt(row_a, col_a, row_b, col_b)
    local is_uint = require("nvim-tools.types").is_uint
    vim.validate("row_a", row_a, is_uint)
    vim.validate("col_a", col_a, is_uint)
    vim.validate("row_b", row_b, is_uint)
    vim.validate("col_b", col_b, is_uint)

    return row_a > row_b or row_a == row_b and col_a > col_b
end

-------------------------------
-- MARK: Position Conversion --
-------------------------------

---Functions to convert positions
---
---These functions are, to a degree, more demonstrative than meant to be used. If these functions
---are meant to be used in a hot path, vim.validate should almost certainly be removed. Or, if,
---for example, you were bulk converting 0 indexed rows to 1 indexed rows, you would want to get
---buf_line_count once and then pass it to the function.
---
---Because these functions might be used by callers, row and col are passed directly rather than
---as a table. This is more flexible and avoids allocating more heap.

-- TODO: Double check that vim.validate is not load bearing
-- TODO: Make sure that zero return for prev_char_len works properly

-- TODO: fix get_prev_char_len usage

---@param row integer 0 indexed, inclusive
---@param col_ integer 0 indexed, exclusive
---@param buf integer
---@return integer, integer 1 indexed, inclusive end
function M.api_to_eval(row, col_, buf)
    local is_uint = require("nvim-tools.types").is_uint
    vim.validate("row", row, is_uint)
    vim.validate("col", col_, is_uint)
    vim.validate("buf", buf, is_uint)

    local row_1 = math.min(row + 1, api.nvim_buf_get_line_count(buf))

    local line = api.nvim_buf_get_lines(buf, row, row + 1, false)[1]
    local col__1 = math.min(col_ + 1, #line)
    local col_1 = col__1 - M.get_prev_char_len(line, col__1)

    return row_1, col_1
end

---@param row integer 0 indexed, inclusive
---@param col_ integer 0 indexed, exclusive
---@param buf integer
---@return integer, integer 0 indexed, inclusive end
function M.api_to_ext(row, col_, buf)
    local is_uint = require("nvim-tools.types").is_uint
    vim.validate("row", row, is_uint)
    vim.validate("col", col_, is_uint)
    vim.validate("buf", buf, is_uint)

    local line = api.nvim_buf_get_lines(buf, row, row + 1, false)[1]
    local col_1 = math.min(col_ + 1, #line)
    local prev_char_len = M.get_prev_char_len(line, col_1)

    return row, col_ - prev_char_len
end

---@param row integer 0 indexed, inclusive
---@param col integer 0 indexed, exclusive
---@param buf integer
---@return integer, integer 0 indexed, inclusive end
function M.api_to_mark(row, col, buf)
    local is_uint = require("nvim-tools.types").is_uint
    vim.validate("row", row, is_uint)
    vim.validate("col", col, is_uint)
    vim.validate("buf", buf, is_uint)

    local row_1 = math.min(row + 1, api.nvim_buf_line_count(buf))

    local line = api.nvim_buf_get_lines(buf, row, row + 1, false)[1]
    local col_1 = math.min(col + 1, #line)
    local prev_char_len = M.get_prev_char_len(line, col_1)

    return row_1, col - prev_char_len
end

---@param row integer 0 indexed, inclusive
---@param col integer 0 indexed, exclusive
---@param buf integer
---@return integer, integer 1 indexed, exclusive end
function M.api_to_vex(row, col, buf)
    local is_uint = require("nvim-tools.types").is_uint
    vim.validate("row", row, is_uint)
    vim.validate("col", col, is_uint)
    vim.validate("buf", buf, is_uint)

    local row_1 = math.min(row + 1, api.nvim_buf_line_count(buf))
    local line = api.nvim_buf_get_lines(buf, row, row + 1, false)[1]
    local col_1 = math.min(col + 1, #line + 1)
    return row_1, col_1
end

---@param row integer 1 indexed, inclusive
---@param col integer 1 indexed, inclusive
---@param buf integer
---@return integer, integer 0 indexed, exclusive end
function M.eval_to_api(row, col, buf)
    local is_uint = require("nvim-tools.types").is_uint
    vim.validate("row", row, is_uint)
    vim.validate("col", col, is_uint)
    vim.validate("buf", buf, is_uint)

    local line = api.nvim_buf_get_lines(buf, row - 1, row, false)[1]
    local b1 = string.byte(line, col)
    local get_char_len = require("nvim-tools.char").get_char_len
    local char_len = get_char_len(line, b1, col)

    return math.max(row - 1, 0), math.max(col - 1, 0) + char_len
end

---@param row integer 1 indexed, inclusive
---@param col integer 1 indexed, inclusive
---@return integer, integer 0 indexed, exclusive end
function M.eval_to_ext(row, col)
    local is_uint = require("nvim-tools.types").is_uint
    vim.validate("row", row, is_uint)
    vim.validate("col", col, is_uint)

    return math.max(row - 1, 0), math.max(col - 1, 0)
end

---@param row integer 1 indexed, inclusive
---@param col integer 1 indexed, inclusive
---@return integer, integer 0 indexed, exclusive end
function M.eval_to_mark(row, col)
    local is_uint = require("nvim-tools.types").is_uint
    vim.validate("row", row, is_uint)
    vim.validate("col", col, is_uint)

    return row, math.max(col - 1, 0)
end

---@param row integer 1 indexed
---@param col integer 1 indexed, inclusive
---@param buf integer
---@return integer, integer 1 indexed, exclusive end
function M.eval_to_vex(row, col, buf)
    local is_uint = require("nvim-tools.types").is_uint
    vim.validate("row", row, is_uint)
    vim.validate("col", col, is_uint)
    vim.validate("buf", buf, is_uint)

    local line = api.nvim_buf_get_lines(buf, row - 1, row, false)[1]
    local b1 = string.byte(line, col)

    local get_char_len = require("nvim-tools.char").get_char_len
    local char_len = get_char_len(line, b1, col)
    return row, math.min(col + char_len, #line + 1)
end

---@param row integer 0 indexed, inclusive
---@param col integer 0 indexed, inclusive
---@param buf integer
---@return integer, integer 0 indexed, exclusive end
function M.ext_to_api(row, col, buf)
    local is_uint = require("nvim-tools.types").is_uint
    vim.validate("row", row, is_uint)
    vim.validate("col", col, is_uint)
    vim.validate("buf", buf, is_uint)

    local line = api.nvim_buf_get_lines(buf, row, row + 1, false)[1]
    local col_1 = math.min(col + 1, #line)
    local b1 = string.byte(line, col_1)

    local get_char_len = require("nvim-tools.char").get_char_len
    local char_len = get_char_len(line, b1, col_1)
    return row, col + char_len
end

---@param row integer 0 indexed, inclusive
---@param col integer 0 indexed, inclusive
---@param buf integer
---@return integer, integer 1, 0 indexed, inclusive
function M.ext_to_eval(row, col, buf)
    local is_uint = require("nvim-tools.types").is_uint
    vim.validate("row", row, is_uint)
    vim.validate("col", col, is_uint)
    vim.validate("buf", buf, is_uint)

    local row_1 = math.min(row + 1, api.nvim_buf_line_count(buf))
    local line = api.nvim_buf_get_lines(buf, row, row + 1, false)[1]

    return row_1, math.min(col + 1, #line)
end

---@param row integer 0 indexed, inclusive
---@param col integer 0 indexed, inclusive
---@param buf integer
---@return integer, integer 1, 0 indexed, inclusive
function M.ext_to_mark(row, col, buf)
    local is_uint = require("nvim-tools.types").is_uint
    vim.validate("row", row, is_uint)
    vim.validate("col", col, is_uint)
    vim.validate("buf", buf, is_uint)
    return math.min(row + 1, api.nvim_buf_line_count(buf)), col
end

---@param row integer 0 indexed, inclusive
---@param col integer 0 indexed, inclusive
---@param buf integer
---@return integer, integer 1, 1 indexed, exclusive
function M.ext_to_vex(row, col, buf)
    local is_uint = require("nvim-tools.types").is_uint
    vim.validate("row", row, is_uint)
    vim.validate("col", col, is_uint)
    vim.validate("buf", buf, is_uint)

    local row_1 = math.min(row + 1, api.nvim_buf_line_count(buf))

    local line = api.nvim_buf_get_lines(buf, row, row + 1, false)[1]
    local len_line = #line
    local col_1 = math.min(col + 1, len_line)
    local b1 = string.byte(line, col_1)

    local get_char_len = require("nvim-tools.char").get_char_len
    local char_len = get_char_len(line, b1, col_1)
    return row_1, math.min(col_1 + char_len, len_line + 1)
end

---@param row integer 1 indexed, inclusive
---@param col integer 0 indexed, inclusive
---@return integer, integer 0 indexed, exclusive end
function M.mark_to_api(row, col, buf)
    local is_uint = require("nvim-tools.types").is_uint
    vim.validate("row", row, is_uint)
    vim.validate("col", col, is_uint)
    vim.validate("buf", buf, is_uint)

    local row_0 = math.max(row - 1, 0)

    local line = api.nvim_buf_get_lines(buf, row, row + 1, false)[1]
    local col_1 = math.min(col + 1, #line)
    local b1 = string.byte(line, col_1)

    local get_char_len = require("nvim-tools.char").get_char_len
    local char_len = get_char_len(line, b1, col_1)

    return row_0, col + char_len
end

---@param row integer 0 indexed, inclusive
---@param col integer 0 indexed, inclusive
---@param buf integer
---@return integer, integer 1, 0 indexed, inclusive
function M.mark_to_eval(row, col, buf)
    local is_uint = require("nvim-tools.types").is_uint
    vim.validate("row", row, is_uint)
    vim.validate("col", col, is_uint)
    vim.validate("buf", buf, is_uint)

    local line = api.nvim_buf_get_lines(buf, row, row + 1, false)[1]
    return row, math.min(col + 1, #line)
end

---@param row integer 1 indexed, inclusive
---@param col integer 0 indexed, inclusive
---@return integer, integer 0, 0 indexed, inclusive
function M.mark_to_ext(row, col)
    local is_uint = require("nvim-tools.types").is_uint
    vim.validate("row", row, is_uint)
    vim.validate("col", col, is_uint)
    return math.max(row - 1, 0), col
end

---@param row integer 1 indexed, inclusive
---@param col integer 0 indexed, inclusive
---@param buf integer
---@return integer, integer 1, 1 indexed, exclusive
function M.mark_to_vex(row, col, buf)
    local is_uint = require("nvim-tools.types").is_uint
    vim.validate("row", row, is_uint)
    vim.validate("col", col, is_uint)
    vim.validate("buf", buf, is_uint)

    local line = api.nvim_buf_get_lines(buf, row - 1, row, false)[1]
    local col_1 = math.min(col + 1, #line)
    local b1 = string.byte(line, col_1) or 0

    local get_char_len = require("nvim-tools.char").get_char_len
    local char_len = get_char_len(line, b1, col_1)
    return row, math.min(col_1 + char_len, #line + 1)
end

---@param row integer 1 indexed
---@param col_ integer 1 indexed, exclusive
---@param buf integer
---@return integer, integer 0 indexed, exclusive
function M.vex_to_api(row, col_, buf)
    local is_uint = require("nvim-tools.types").is_uint
    vim.validate("row", row, is_uint)
    vim.validate("col", col_, is_uint)
    vim.validate("buf", buf, is_uint)

    return math.max(row - 1, 0), math.max(col_ - 1, 0)
end

---@param row integer 1 indexed
---@param col integer 1 indexed, exclusive
---@param buf integer
---@return integer, integer 1 indexed, inclusive
function M.vex_to_eval(row, col, buf)
    local is_uint = require("nvim-tools.types").is_uint
    vim.validate("row", row, is_uint)
    vim.validate("col", col, is_uint)
    vim.validate("buf", buf, is_uint)

    local line = api.nvim_buf_get_lines(buf, row - 1, row, false)[1]
    local len_line = #line

    local col_ex = math.min(col, len_line + 1)
    local last_byte = col_ex - 1
    local probe_pos = math.max(last_byte, 0)

    local get_prev_char_len = require("nvim-tools.char").get_prev_char_len
    local prev_len = get_prev_char_len(line, probe_pos)

    local col_eval = last_byte - prev_len + 1
    return row, math.max(col_eval, 1)
end

---@param row integer 1 indexed
---@param col integer 1 indexed, exclusive
---@param buf integer
---@return integer, integer 0 indexed, inclusive
function M.vex_to_ext(row, col, buf)
    local is_uint = require("nvim-tools.types").is_uint
    vim.validate("row", row, is_uint)
    vim.validate("col", col, is_uint)
    vim.validate("buf", buf, is_uint)

    local row_0 = math.max(row - 1, 0)
    local line = api.nvim_buf_get_lines(buf, row_0, row_0 + 1, false)[1] or ""
    local col_api = math.max(col - 1, 0)
    local col_1 = math.min(col_api + 1, #line)
    local prev_len = M.get_prev_char_len(line, col_1)
    local col_ext = col_api - prev_len
    return row_0, math.max(col_ext, 0)
end

---@param row integer 1 indexed
---@param col integer 1 indexed, exclusive
---@param buf integer
---@return integer, integer 1, 0 indexed, inclusive
function M.vex_to_mark(row, col, buf)
    local is_uint = require("nvim-tools.types").is_uint
    vim.validate("row", row, is_uint)
    vim.validate("col", col, is_uint)
    vim.validate("buf", buf, is_uint)

    local line = api.nvim_buf_get_lines(buf, row - 1, row, false)[1] or ""
    local col_api = math.max(col - 1, 0)
    local col_1 = math.min(col_api + 1, #line)
    local prev_len = M.get_prev_char_len(line, col_1)
    local col_mark = col_api - prev_len
    return row, math.max(col_mark, 0)
end

-------------------------------
-- MARK: Position Adjustment --
-------------------------------

-- TODO: These need to also handle a col being in an invalid position. In the inclusive case, the
-- col should always be at the start of a char. In the exclusive case, it's either the start of
-- a char or one past the end of the line.

---@param row integer 0 indexed
---@param col integer 0 indexed, exclusive
---@param buf integer
---@return integer, integer 0, 0 indexed, exclusive
function M.adj_api_pos(row, col, buf)
    local is_uint = require("nvim-tools.types").is_uint
    vim.validate("row", row, is_uint)
    vim.validate("col", col, is_uint)
    vim.validate("buf", buf, is_uint)

    row = math.min(row, api.nvim_buf_get_line_count(buf) - 1)
    local line = api.nvim_buf_get_lines(buf, row - 1, row, false)[1]
    return row, math.min(col, #line)
end

---@param row integer 1 indexed
---@param col integer 1 indexed, inclusive
---@param buf integer
---@return integer, integer 1, 1 indexed, inclusive
function M.adj_eval_pos(row, col, buf)
    local is_uint = require("nvim-tools.types").is_uint
    vim.validate("row", row, is_uint)
    vim.validate("col", col, is_uint)
    vim.validate("buf", buf, is_uint)

    row = math.min(row, api.nvim_buf_get_line_count(buf))
    local line = api.nvim_buf_get_lines(buf, row - 1, row, false)[1]
    return row, math.min(col, #line)
end

---@param row integer 0 indexed
---@param col integer 0 indexed, inclusive
---@param buf integer
---@return integer, integer 0, 0 indexed, inclusive
function M.adj_ext_pos(row, col, buf)
    local is_uint = require("nvim-tools.types").is_uint
    vim.validate("row", row, is_uint)
    vim.validate("col", col, is_uint)
    vim.validate("buf", buf, is_uint)

    row = math.min(row, api.nvim_buf_get_line_count(buf) - 1)
    local line = api.nvim_buf_get_lines(buf, row - 1, row, false)[1]
    return row, math.min(col, #line - 1)
end

---@param row integer 1 indexed
---@param col integer 0 indexed, inclusive
---@param buf integer
---@return integer, integer 1, 0 indexed, inclusive
function M.adj_mark_pos(row, col, buf)
    local is_uint = require("nvim-tools.types").is_uint
    vim.validate("row", row, is_uint)
    vim.validate("col", col, is_uint)
    vim.validate("buf", buf, is_uint)

    row = math.min(row, api.nvim_buf_get_line_count(buf))
    local line = api.nvim_buf_get_lines(buf, row - 1, row, false)[1]
    return row, math.min(col, #line - 1)
end

---@param row integer 1 indexed
---@param col integer 1 indexed, exclusive
---@param buf integer
---@return integer, integer 1, 1 indexed, exclusive
function M.adj_vex_pos(row, col, buf)
    local is_uint = require("nvim-tools.types").is_uint
    vim.validate("row", row, is_uint)
    vim.validate("col", col, is_uint)
    vim.validate("buf", buf, is_uint)

    row = math.min(row, api.nvim_buf_get_line_count(buf))
    local line = api.nvim_buf_get_lines(buf, row - 1, row, false)[1]
    return row, math.min(col, #line + 1)
end

return M
