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

-- These conversions assume that the provided position is valid. See below for
-- validation/adjustment.
-- Row and col are taken as separate params for flexibility and to avoid forcing the allocation
-- of new heap.
-- For outlining of duplicate logic, the conversion that preserves indexing numbers is used as
-- the "base" for conceptual simplicity. This can create duplicate logic. Adjust as needed in your
-- own interpretation.

---@param row integer 0 indexed
---@param col_ integer 0 indexed, exclusive
---@param buf integer
---@return integer, integer 1,1 indexed, inclusive end
function M.api_to_eval(row, col_, buf)
    local row_0, col_0 = M.api_to_ext(row, col_, buf)
    local row_1 = row_0 + 1
    local col_1 = col_0 + 1

    return row_1, col_1
end

---@param row integer 0 indexed
---@param col_ integer 0 indexed, exclusive
---@param buf integer
---@return integer, integer 0,0 indexed, inclusive end
function M.api_to_ext(row, col_, buf)
    local is_uint = require("nvim-tools.types").is_uint
    vim.validate("row", row, is_uint)
    vim.validate("col", col_, is_uint)
    vim.validate("buf", buf, is_uint)

    local line = api.nvim_buf_get_lines(buf, row, row + 1, false)[1]
    if #line > 0 then
        local prev_fin_idx_1 = col_
        local distance = vim.str_utf_start(line, prev_fin_idx_1)
        local col_1 = prev_fin_idx_1 + distance
        local col_0 = col_1 - 1

        return row, col_0
    end

    return row, 0
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
    if #line > 0 then
        local distance = vim.str_utf_end(line, col)
        local col_ = col + distance + 1

        return row, col_
    end

    return row, 1
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
    if #line > 0 then
        local col_1 = col + 1
        local distance = vim.str_utf_end(line, col_1)
        local col_ = col + distance + 1

        return row, col_
    end

    return row, 0
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
    local _, col__0 = M.ext_to_api(row, col, buf)
    local row_1 = row + 1
    local col__1 = col__0 + 1

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
    if #line > 0 then
        local col_1 = col + 1
        local distance = vim.str_utf_end(line, col_1)
        local col_ = col + distance + 1

        return row_0, col_
    end

    return row_0, 0
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
    local _, col__0 = M.mark_to_api(row, col, buf)
    local col__1 = col__0 + 1

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
    if #line > 0 then
        local prev_fin_idx = col_ - 1
        local distance = vim.str_utf_start(line, prev_fin_idx)
        local col = prev_fin_idx + distance

        return row, col
    end

    return row, 1
end

---@param row integer 1 indexed
---@param col_ integer 1 indexed, exclusive
---@param buf integer
---@return integer, integer 0,0 indexed, inclusive end
function M.vex_to_ext(row, col_, buf)
    local _, col_1 = M.vex_to_eval(row, col_, buf)
    local row_0 = row - 1
    local col_0 = col_1 - 1

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
    if not api.nvim_buf_is_valid(buf) then
        error("Buffer " .. buf .. " is not valid")
    end

    local row_0 = math.min(row, api.nvim_buf_line_count(buf) - 1)
    local line = api.nvim_buf_get_lines(buf, row_0, row_0 + 1, false)[1]
    local len_line = #line

    local col__0 = math.min(col_, len_line) -- Zero on zero length lines
    local get_distance = col__0 < len_line and len_line > 0
    local distance = get_distance and vim.str_utf_start(line, col__0 + 1) or 0
    return row_0, col__0 + distance
end

---@param row integer 1 indexed
---@param col integer 1 indexed, inclusive
---@param buf integer
---@return integer, integer 1,1 indexed, inclusive
function M.adj_eval_pos(row, col, buf)
    local is_uint = require("nvim-tools.types").is_uint
    vim.validate("row", row, is_uint)
    vim.validate("col", col, is_uint)
    vim.validate("buf", buf, is_uint)
    if not api.nvim_buf_is_valid(buf) then
        error("Buffer " .. buf .. " is not valid")
    end

    local row_1 = math.min(row, api.nvim_buf_line_count(buf))
    local line = api.nvim_buf_get_lines(buf, row_1 - 1, row_1, false)[1]
    local len_line = #line

    local col_1 = math.max(math.min(col, len_line), 1)
    local distance = len_line > 0 and vim.str_utf_start(line, col_1) or 0
    return row_1, col_1 + distance
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
    if not api.nvim_buf_is_valid(buf) then
        error("Buffer " .. buf .. " is not valid")
    end

    local row_0 = math.min(row, api.nvim_buf_line_count(buf) - 1)
    local line = api.nvim_buf_get_lines(buf, row_0, row_0 + 1, false)[1]
    local len_line = #line

    local col_0 = math.max(math.min(col, len_line - 1), 0)
    local distance = len_line > 0 and vim.str_utf_start(line, col_0 + 1) or 0
    return row_0, col_0 + distance
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
    if not api.nvim_buf_is_valid(buf) then
        error("Buffer " .. buf .. " is not valid")
    end

    local row_1 = math.min(row, api.nvim_buf_line_count(buf))
    local line = api.nvim_buf_get_lines(buf, row_1 - 1, row_1, false)[1]
    local len_line = #line

    local col_0 = math.max(math.min(col, len_line - 1), 0)
    local distance = len_line > 0 and vim.str_utf_start(line, col_0 + 1) or 0
    return row_1, col_0 + distance
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
    if not api.nvim_buf_is_valid(buf) then
        error("Buffer " .. buf .. " is not valid")
    end

    local row_1 = math.min(row, api.nvim_buf_line_count(buf))
    local line = api.nvim_buf_get_lines(buf, row_1 - 1, row_1, false)[1]
    local len_line = #line

    local col__1 = math.min(col_, len_line + 1) -- Clamp like API indexing
    local get_distance = col__1 <= len_line and len_line > 0
    local distance = get_distance and vim.str_utf_start(line, col__1) or 0
    return row_1, col__1 + distance
end

return M
