local blk_utils = require("mjm.spec-ops.block-utils")

local M = {}

---@param bufnr integer
---@param marks Marks
---@return string[]|nil, string|nil
function M.get_chars(bufnr, marks)
    local start_row = marks.start.row
    local start_col = marks.start.col
    local finish_row = marks.finish.row
    local finish_col = marks.finish.col

    if start_row > finish_row then
        local err = "Start row " .. start_row .. " > finish row " .. finish_row .. "in get_chars"
        return nil, err
    end

    local finish_line = vim.api.nvim_buf_get_lines(bufnr, finish_row - 1, finish_row, false)[1]
    local _, finish_byte, err = blk_utils.byte_bounds_from_col(finish_line, finish_col)
    if (not finish_byte) or err then
        return nil, (err or "Unknown error in byte_bounds_from_col") .. " in get_chars"
    end
    finish_byte = #finish_line > 0 and finish_byte + 1 or 0

    return vim.api.nvim_buf_get_text(0, start_row - 1, start_col, finish_row - 1, finish_byte, {})
end

---@param marks Marks
---@return string[]|nil, string|nil
function M.get_lines(bufnr, marks)
    local start_row = marks.start.row
    local finish_row = marks.finish.row

    if start_row > finish_row then
        return nil, "Start row " .. start_row .. " > finish row " .. finish_row .. "in get_lines"
    end

    local finish_line = vim.api.nvim_buf_get_lines(bufnr, finish_row - 1, finish_row, false)[1]
    return vim.api.nvim_buf_get_text(0, start_row - 1, 0, finish_row - 1, #finish_line, {}), nil
end

--- @param line string
--- @param l_vcol integer
--- @param r_vcol integer
--- @return string|nil, string|nil
local function get_block_line(bufnr, row_0, line, l_vcol, r_vcol, max_curswant)
    local max_vcol = vim.fn.strdisplaywidth(line)
    if max_vcol < l_vcol then
        return "", nil
    end

    local l_l_vcol, l_r_vcol, l_err = blk_utils.vcols_from_vcol(line, l_vcol)
    if (not l_l_vcol) or not l_r_vcol or l_err then
        return nil, "get_block_line: " .. l_err
    end

    local this_l_vcol = l_vcol <= l_l_vcol and l_l_vcol or l_r_vcol + 1
    if this_l_vcol > max_vcol then
        return "", nil
    end

    local this_r_vcol = math.min(r_vcol, max_vcol)
    this_r_vcol = max_curswant and max_vcol or r_vcol
    local r_l_vcol, r_r_vcol, r_err = blk_utils.vcols_from_vcol(line, this_r_vcol)
    if (not r_l_vcol) or not r_r_vcol or r_err then
        return nil, "get_block_line: " .. r_err
    end

    this_r_vcol = r_r_vcol <= this_r_vcol and this_r_vcol or r_l_vcol - 1
    if (this_r_vcol < 0) or this_r_vcol < this_l_vcol then
        return ""
    end

    local l_byte, _, lb_err = blk_utils.byte_bounds_from_vcol(line, this_l_vcol)
    if (not l_byte) or lb_err then
        return nil, "get_block: " .. (lb_err or "Unknown error in byte_bounds_from_vcol")
    end

    local _, r_byte, rb_err = blk_utils.byte_bounds_from_vcol(line, this_r_vcol)
    if (not r_byte) or rb_err then
        return nil, "get_block: " .. (rb_err or "Unknown error in byte_bounds_from_vcol")
    end

    local text = vim.api.nvim_buf_get_text(bufnr, row_0, l_byte, row_0, r_byte + 1, {})[1]
    return string.rep(" ", this_l_vcol - l_vcol) .. text
end

--- @param bufnr integer
--- @param marks Marks
--- @param curswant? integer
--- @return string[]|nil, string|nil
--- This function assumes that the marks are already sorted so the start mark is on the
--- first row
function M.get_block(bufnr, marks, curswant)
    local start_row = marks.start.row
    local finish_row = marks.finish.row
    local lines = vim.api.nvim_buf_get_lines(bufnr, start_row - 1, finish_row, false)

    local l_vcol, r_vcol, vcol_err = blk_utils.get_vcols_from_marks(lines, marks)
    if (not l_vcol) or not r_vcol or vcol_err then
        return nil, "get_block: " .. vcol_err
    end

    local max_curswant = curswant and curswant == vim.v.maxcol

    local block_lines = {}
    for i = 1, #lines do
        local row_0 = start_row + i - 2
        local this_line = get_block_line(bufnr, row_0, lines[i], l_vcol, r_vcol, max_curswant)
        table.insert(block_lines, this_line)
    end

    return block_lines, nil
end

return M
