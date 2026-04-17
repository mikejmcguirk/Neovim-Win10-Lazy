local api = vim.api

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

-- NOTE: These conversions assume that the provided position is valid. Position validation checks
-- are provided below, and can be combined with conversion per use case.
-- NOTE: row and call are provided as integer params rather than a tuple for flexibility and to
-- avoid allocating heap.
-- NOTE: These functions are "over-written" in the interest of making the logic as explicit as
-- possible.

-- vex > eval + vex > mark works because eval > mark is just subtraction

---@param row integer 0 indexed
---@param col_ integer 0 indexed, exclusive
---@param buf integer
---@return integer, integer 1,1 indexed, inclusive end
function M.api_to_eval(row, col_, buf)
    local is_uint = require("nvim-tools.types").is_uint
    vim.validate("row", row, is_uint)
    vim.validate("col", col_, is_uint)
    vim.validate("buf", buf, is_uint)

    local row_1 = row + 1
    local line = api.nvim_buf_get_lines(buf, row, row_1, false)[1]
    local prev_fin_idx_1 = col_

    local get_start_byte = require("nvim-tools.char").get_start_byte
    local _, prev_start_idx_1 = get_start_byte(line, prev_fin_idx_1)
    local col_1 = math.max(prev_start_idx_1, 1)

    return row_1, col_1
end

---@param row integer 0 indexed
---@param col_ integer 0 indexed, exclusive
---@param buf integer
---@return integer, integer 0,0 indexed, inclusive end
function M.api_to_ext(row, col_, buf)
    local _, col_1 = M.api_to_eval(row, col_, buf)
    local col_0 = col_1 - 1
    return row, col_0
end

---@param row integer 0 indexed
---@param col_ integer 0 indexed, exclusive
---@param buf integer
---@return integer, integer 1,0 indexed, inclusive end
function M.api_to_mark(row, col_, buf)
    local row_1, col_1 = M.api_to_eval(row, col_, buf)
    local col_0 = col_1 - 1
    return row_1, col_0
end

---@param row integer 0 indexed
---@param col_ integer 0 indexed, exclusive
---@return integer, integer 1,1 indexed, exclusive end
function M.api_to_vex(row, col_)
    local is_uint = require("nvim-tools.types").is_uint
    vim.validate("row", row, is_uint)
    vim.validate("col", col_, is_uint)

    return row + 1, col_ + 1
end

---@param row integer 1 indexed
---@param col integer 1 indexed, inclusive
---@param buf integer
---@return integer, integer 0,0 indexed, exclusive end
function M.eval_to_api(row, col, buf)
    local row_1, col__1 = M.eval_to_vex(row, col, buf)
    local row_0 = row_1 - 1
    local col__0 = col__1 - 1

    return row_0, col__0
end

---@param row integer 1 indexed
---@param col integer 1 indexed, inclusive
---@return integer, integer 0,0 indexed, inclusive end
function M.eval_to_ext(row, col)
    local is_uint = require("nvim-tools.types").is_uint
    vim.validate("row", row, is_uint)
    vim.validate("col", col, is_uint)

    return row - 1, col - 1
end

---@param row integer 1 indexed
---@param col integer 1 indexed, inclusive
---@return integer, integer 1,0 indexed, inclusive end
function M.eval_to_mark(row, col)
    local is_uint = require("nvim-tools.types").is_uint
    vim.validate("row", row, is_uint)
    vim.validate("col", col, is_uint)

    return row, col - 1
end

---@param row integer 1 indexed
---@param col integer 1 indexed, inclusive
---@param buf integer
---@return integer, integer 1,1 indexed, exclusive end
function M.eval_to_vex(row, col, buf)
    local is_uint = require("nvim-tools.types").is_uint
    vim.validate("row", row, is_uint)
    vim.validate("col", col, is_uint)
    vim.validate("buf", buf, is_uint)

    local line = api.nvim_buf_get_lines(buf, row - 1, row, false)[1]
    local b1 = string.byte(line, col)

    local get_char_len = require("nvim-tools.char").get_char_len
    local char_len = get_char_len(line, b1, col)
    local col_ = col + char_len

    return row, col_
end

---@param row integer 0 indexed
---@param col integer 0 indexed, inclusive
---@param buf integer
---@return integer, integer 0,0 indexed, exclusive end
function M.ext_to_api(row, col, buf)
    local is_uint = require("nvim-tools.types").is_uint
    vim.validate("row", row, is_uint)
    vim.validate("col", col, is_uint)
    vim.validate("buf", buf, is_uint)

    local line = api.nvim_buf_get_lines(buf, row, row + 1, false)[1]
    local col_1 = col + 1
    local b1 = string.byte(line, col_1)

    local get_char_len = require("nvim-tools.char").get_char_len
    local char_len = get_char_len(line, b1, col_1)
    local col_ = col + char_len

    return row, col_
end

---@param row integer 0 indexed
---@param col integer 0 indexed, inclusive
---@return integer, integer 1,1 indexed, inclusive end
function M.ext_to_eval(row, col)
    local is_uint = require("nvim-tools.types").is_uint
    vim.validate("row", row, is_uint)
    vim.validate("col", col, is_uint)

    return row + 1, col + 1
end

---@param row integer 0 indexed
---@param col integer 0 indexed, inclusive
---@return integer, integer 1,0 indexed, inclusive end
function M.ext_to_mark(row, col)
    local is_uint = require("nvim-tools.types").is_uint
    vim.validate("row", row, is_uint)
    vim.validate("col", col, is_uint)

    return row + 1, col
end

---@param row integer 0 indexed
---@param col integer 0 indexed, inclusive
---@param buf integer
---@return integer, integer 1,1 indexed, exclusive end
function M.ext_to_vex(row, col, buf)
    local is_uint = require("nvim-tools.types").is_uint
    vim.validate("row", row, is_uint)
    vim.validate("col", col, is_uint)
    vim.validate("buf", buf, is_uint)

    local row_1 = row + 1
    local line = api.nvim_buf_get_lines(buf, row, row_1, false)[1]
    local col_1 = col + 1
    local b1 = string.byte(line, col_1)

    local get_char_len = require("nvim-tools.char").get_char_len
    local char_len = get_char_len(line, b1, col_1)
    local col__1 = col_1 + char_len

    return row_1, col__1
end

---@param row integer 1 indexed
---@param col integer 0 indexed, inclusive
---@return integer, integer 0,0 indexed, exclusive end
function M.mark_to_api(row, col, buf)
    local is_uint = require("nvim-tools.types").is_uint
    vim.validate("row", row, is_uint)
    vim.validate("col", col, is_uint)
    vim.validate("buf", buf, is_uint)

    local row_0 = row - 1
    local line = api.nvim_buf_get_lines(buf, row_0, row, false)[1]
    local col_1 = col + 1
    local b1 = string.byte(line, col_1)

    local get_char_len = require("nvim-tools.char").get_char_len
    local char_len = get_char_len(line, b1, col_1)
    local col_ = col + char_len

    return row_0, col_
end

---@param row integer 1 indexed
---@param col integer 0 indexed, inclusive
---@return integer, integer 1,0 indexed, inclusive end
function M.mark_to_eval(row, col)
    local is_uint = require("nvim-tools.types").is_uint
    vim.validate("row", row, is_uint)
    vim.validate("col", col, is_uint)

    return row, col + 1
end

---@param row integer 1 indexed
---@param col integer 0 indexed, inclusive
---@return integer, integer 0,0 indexed, inclusive end
function M.mark_to_ext(row, col)
    local is_uint = require("nvim-tools.types").is_uint
    vim.validate("row", row, is_uint)
    vim.validate("col", col, is_uint)

    return row - 1, col
end

---@param row integer 1 indexed, inclusive
---@param col integer 0 indexed, inclusive
---@param buf integer
---@return integer, integer 1,1 indexed, exclusive end
function M.mark_to_vex(row, col, buf)
    local is_uint = require("nvim-tools.types").is_uint
    vim.validate("row", row, is_uint)
    vim.validate("col", col, is_uint)
    vim.validate("buf", buf, is_uint)

    local line = api.nvim_buf_get_lines(buf, row - 1, row, false)[1]
    local col_1 = col + 1
    local b1 = string.byte(line, col_1)

    local get_char_len = require("nvim-tools.char").get_char_len
    local char_len = get_char_len(line, b1, col_1)
    local col__1 = col_1 + char_len

    return row, col__1
end

---@param row integer 1 indexed
---@param col_ integer 1 indexed, exclusive
---@return integer, integer 0,0 indexed, exclusive end
function M.vex_to_api(row, col_)
    local is_uint = require("nvim-tools.types").is_uint
    vim.validate("row", row, is_uint)
    vim.validate("col", col_, is_uint)

    return row - 1, col_ - 1
end

---@param row integer 1 indexed
---@param col_ integer 1 indexed, exclusive
---@param buf integer
---@return integer, integer 1,1 indexed, inclusive end
function M.vex_to_eval(row, col_, buf)
    local is_uint = require("nvim-tools.types").is_uint
    vim.validate("row", row, is_uint)
    vim.validate("col", col_, is_uint)
    vim.validate("buf", buf, is_uint)

    local line = api.nvim_buf_get_lines(buf, row - 1, row, false)[1]
    local prev_fin_idx = col_ - 1

    local get_start_byte = require("nvim-tools.char").get_start_byte
    local _, prev_start_idx = get_start_byte(line, prev_fin_idx)
    local col = math.max(prev_start_idx, 1)

    return row, col
end

---@param row integer 1 indexed
---@param col_ integer 1 indexed, exclusive
---@param buf integer
---@return integer, integer 0,0 indexed, inclusive end
function M.vex_to_ext(row, col_, buf)
    local is_uint = require("nvim-tools.types").is_uint
    vim.validate("row", row, is_uint)
    vim.validate("col", col_, is_uint)
    vim.validate("buf", buf, is_uint)

    local row_0 = row - 1
    local line = api.nvim_buf_get_lines(buf, row_0, row, false)[1]
    local prev_fin_idx = col_ - 1

    local get_start_byte = require("nvim-tools.char").get_start_byte
    local _, prev_start_idx = get_start_byte(line, prev_fin_idx)
    local col = math.max(prev_start_idx, 1)
    local col_0 = col - 1

    return row_0, col_0
end

---@param row integer 1 indexed
---@param col_ integer 1 indexed, exclusive
---@param buf integer
---@return integer, integer 1,0 indexed, inclusive end
function M.vex_to_mark(row, col_, buf)
    local row_1, col_1 = M.vex_to_eval(row, col_, buf)
    local col_0 = col_1 - 1
    return row_1, col_0
end

-------------------------------
-- MARK: Position Adjustment --
-------------------------------

---@param row integer 0 indexed
---@param col_ integer 0 indexed, exclusive
---@param buf integer
---@return integer, integer 0,0 indexed, exclusive
function M.adj_api_pos(row, col_, buf)
    local is_uint = require("nvim-tools.types").is_uint
    vim.validate("row", row, is_uint)
    vim.validate("col", col_, is_uint)
    vim.validate("buf", buf, is_uint)

    local row_0 = math.min(row, api.nvim_buf_line_count(buf) - 1)

    local get_start_byte = require("nvim-tools.char").get_start_byte
    local line = api.nvim_buf_get_lines(buf, row_0, row_0 + 1, false)[1]
    local _, start_idx = get_start_byte(line, math.min(col_, #line) + 1)

    return row_0, math.max(start_idx, 1) - 1
end
-- NOTE: Properly handles zero length strings. col_ will be coerced by get_start_byte to 1, which
-- will then be re-indexed to zero. Correct since exclusive ends on zero length strings are
-- invalid.

---@param row integer 1 indexed
---@param col integer 1 indexed, inclusive
---@param buf integer
---@return integer, integer 1,1 indexed, inclusive
function M.adj_eval_pos(row, col, buf)
    local is_uint = require("nvim-tools.types").is_uint
    vim.validate("row", row, is_uint)
    vim.validate("col", col, is_uint)
    vim.validate("buf", buf, is_uint)

    local row_1 = math.min(row, api.nvim_buf_line_count(buf))

    local get_start_byte = require("nvim-tools.char").get_start_byte
    local line = api.nvim_buf_get_lines(buf, row_1 - 1, row_1, false)[1]
    local _, start_idx = get_start_byte(line, math.min(col, #line))

    return row_1, math.max(start_idx, 1)
end

---@param line string
---@param col_0 integer
---@return integer
local function adj_col_0(line, col_0)
    local get_start_byte = require("nvim-tools.char").get_start_byte
    local _, start_idx = get_start_byte(line, math.min(col_0, #line - 1) + 1)
    return math.max(start_idx, 1) - 1
end

---@param row integer 0 indexed
---@param col integer 0 indexed, inclusive
---@param buf integer
---@return integer, integer 0,0 indexed, inclusive
function M.adj_ext_pos(row, col, buf)
    local is_uint = require("nvim-tools.types").is_uint
    vim.validate("row", row, is_uint)
    vim.validate("col", col, is_uint)
    vim.validate("buf", buf, is_uint)

    local row_0 = math.min(row, api.nvim_buf_line_count(buf) - 1)
    local line = api.nvim_buf_get_lines(buf, row_0, row_0 + 1, false)[1]
    return row_0, adj_col_0(line, col)
end

---@param row integer 1 indexed
---@param col integer 0 indexed, inclusive
---@param buf integer
---@return integer, integer 1,0 indexed, inclusive
function M.adj_mark_pos(row, col, buf)
    local is_uint = require("nvim-tools.types").is_uint
    vim.validate("row", row, is_uint)
    vim.validate("col", col, is_uint)
    vim.validate("buf", buf, is_uint)

    local row_1 = math.min(row, api.nvim_buf_line_count(buf))
    local line = api.nvim_buf_get_lines(buf, row_1 - 1, row_1, false)[1]
    return row_1, adj_col_0(line, col)
end

---@param row integer 1 indexed
---@param col_ integer 1 indexed, exclusive
---@param buf integer
---@return integer, integer 1,1 indexed, exclusive
function M.adj_vex_pos(row, col_, buf)
    local is_uint = require("nvim-tools.types").is_uint
    vim.validate("row", row, is_uint)
    vim.validate("col", col_, is_uint)
    vim.validate("buf", buf, is_uint)

    local row_1 = math.min(row, api.nvim_buf_line_count(buf))

    local get_start_byte = require("nvim-tools.char").get_start_byte
    local line = api.nvim_buf_get_lines(buf, row_1 - 1, row_1, false)[1]
    local _, start_idx = get_start_byte(line, math.min(col_, #line + 1))

    return row_1, math.max(start_idx, 1)
end

return M
