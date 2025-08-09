local blk_utils = require("mjm.spec-ops.block-utils")

local M = {}

---@param buf integer
---@param marks Marks
---@return string[]|nil, string|nil
function M.get_chars(buf, marks)
    local start_row = marks.start.row
    local fin_row = marks.finish.row
    if start_row > fin_row then
        local err = "Start row " .. start_row .. " > finish row " .. fin_row .. " in get_chars"
        return nil, err
    end

    local start_col = marks.start.col
    local fin_col = marks.finish.col

    local fin_line = vim.api.nvim_buf_get_lines(buf, fin_row - 1, fin_row, false)[1]
    local _, fin_byte, err = blk_utils.byte_bounds_from_col(fin_line, fin_col)
    if (not fin_byte) or err then
        return nil, "get_chars: " .. (err or "Unknown error in byte_bounds_from_col")
    end
    fin_byte = #fin_line > 0 and fin_byte + 1 or 0

    return vim.api.nvim_buf_get_text(0, start_row - 1, start_col, fin_row - 1, fin_byte, {})
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
    if #line == 0 then
        return "", nil
    end

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
    this_r_vcol = max_curswant and max_vcol or this_r_vcol
    local r_l_vcol, r_r_vcol, r_err = blk_utils.vcols_from_vcol(line, this_r_vcol)
    if (not r_l_vcol) or not r_r_vcol or r_err then
        return nil, "get_block_line: " .. r_err
    end

    this_r_vcol = r_r_vcol <= this_r_vcol and this_r_vcol or r_l_vcol - 1
    if (this_r_vcol < 0) or this_r_vcol < this_l_vcol then
        return "", nil
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

--- @param buf integer
--- @param marks Marks
--- @param curswant? integer
--- @return string[]|nil, string|nil
--- This function assumes that the marks are already sorted so the start mark is on the
--- first row
function M.get_block(buf, marks, curswant)
    local start_row = marks.start.row
    local finish_row = marks.finish.row
    local lines = vim.api.nvim_buf_get_lines(buf, start_row - 1, finish_row, false)

    local l_vcol, r_vcol, vcol_err = blk_utils.get_vcols_from_marks(lines, marks)
    if (not l_vcol) or not r_vcol or vcol_err then
        return nil, "get_block: " .. vcol_err
    end

    local max_curswant = curswant and curswant == vim.v.maxcol

    local block_lines = {}
    for i = 1, #lines do
        local row_0 = start_row + i - 2
        local this_line = get_block_line(buf, row_0, lines[i], l_vcol, r_vcol, max_curswant)
        table.insert(block_lines, this_line)
    end

    return block_lines, nil
end

--- @param buf integer
--- @param marks Marks
--- @return  Marks|nil, string|nil
function M.del_chars(buf, marks)
    local start_row = marks.start.row
    local fin_row = marks.finish.row
    if start_row > fin_row then
        return nil, "Start row " .. start_row .. " > finish row " .. fin_row .. " in get_chars"
    end

    local start_col = marks.start.col
    local fin_col = marks.finish.col

    local fin_line = vim.api.nvim_buf_get_lines(buf, fin_row - 1, fin_row, false)[1]
    local _, fin_byte, err = blk_utils.byte_bounds_from_col(fin_line, fin_col)
    if (not fin_byte) or err then
        return nil, "delete_chars: " .. (err or "Unknown error in byte_bounds_from_col")
    end
    fin_byte = #fin_line > 0 and fin_byte + 1 or 0

    vim.api.nvim_buf_set_text(buf, start_row - 1, start_col, fin_row - 1, fin_byte, {})
    start_row = math.min(start_row, vim.api.nvim_buf_line_count(buf))
    vim.api.nvim_buf_set_mark(0, "[", start_row, start_col, {})
    vim.api.nvim_buf_set_mark(0, "]", start_row, start_col, {})

    return {
        start = { row = start_row, col = start_col },
        finish = { row = start_row, col = start_col },
    },
        nil
end

--- @param buf integer
--- @param marks Marks
--- @param curswant integer
--- @param visual boolean
--- @return Marks|nil, string|nil
function M.del_lines(buf, marks, curswant, visual)
    local start_row = marks.start.row
    local fin_row = marks.finish.row
    if start_row > fin_row then
        return nil, "del_lines: Start row " .. start_row .. " > finish row " .. fin_row
    end

    vim.api.nvim_buf_set_lines(buf, start_row - 1, fin_row, false, {})

    start_row = math.min(start_row, vim.api.nvim_buf_line_count(buf))
    local post_line = vim.api.nvim_buf_get_lines(buf, start_row - 1, start_row, false)[1]
    local post_col = visual and 0 or math.min((#post_line > 0 and #post_line - 1 or 0), curswant)

    vim.api.nvim_buf_set_mark(0, "[", start_row, post_col, {})
    vim.api.nvim_buf_set_mark(0, "]", start_row, post_col, {})

    return {
        start = {
            row = start_row,
            col = post_col,
        },
        finish = {
            row = start_row,
            col = post_col,
        },
    },
        nil
end

local function del_block_line(line, l_vcol, r_vcol, max_curswant, buf, row_0)
    if #line == 0 then
        return true, nil
    end

    local max_vcol = vim.fn.strdisplaywidth(line)
    if max_vcol < l_vcol then
        return true, nil
    end

    local l_byte, _, l_err = blk_utils.byte_bounds_from_vcol(line, l_vcol)
    if not l_byte then
        return false, "del_block_line: " .. (l_err or "Unknown error in byte_bounds_from_vcol")
    end

    local this_r_vcol = math.min(r_vcol, max_vcol)
    this_r_vcol = max_curswant and max_vcol or this_r_vcol
    local _, r_byte, r_err = blk_utils.byte_bounds_from_vcol(line, this_r_vcol)
    if (not r_byte) or r_err then
        return false, "del_block_line: " .. (r_err or "Unknown error in byte_bounds_from_vcol")
    end

    if l_byte > r_byte then
        return true, nil
    end

    local this_vcol_len = vim.fn.strdisplaywidth(line:sub(l_byte + 1, r_byte + 1))
    local target_vcol_len = this_r_vcol - l_vcol + 1
    local pad_len = this_vcol_len - target_vcol_len
    local padding = string.rep(" ", (pad_len >= 0 and pad_len or 0))

    vim.api.nvim_buf_set_text(buf, row_0, l_byte, row_0, r_byte + 1, { padding })

    return true, nil
end

--- @param buf integer
--- @param marks Marks
--- @param curswant integer
--- @return Marks|nil, string|nil
--- This function assumes that the marks are already sorted so the start mark is on the
--- first row
function M.del_block(buf, marks, curswant)
    local start_row = marks.start.row
    local fin_row = marks.finish.row
    local lines = vim.api.nvim_buf_get_lines(buf, start_row - 1, fin_row, false)

    local l_vcol, r_vcol, vcol_err = blk_utils.get_vcols_from_marks(lines, marks)
    if (not l_vcol) or not r_vcol or vcol_err then
        return nil, "del_block: " .. vcol_err
    end

    local max_curswant = curswant and curswant == vim.v.maxcol

    local l_mark_vcol, _, l_vcol_err = blk_utils.vcols_from_vcol(lines[1], l_vcol)
    if (not l_mark_vcol) or l_vcol_err then
        return nil, "del_block: " .. (l_vcol_err or "Unknown error in vcols_from_vcol")
    end

    for i = 1, #lines do
        local row_0 = start_row + i - 2
        local ok, err = del_block_line(lines[i], l_vcol, r_vcol, max_curswant, buf, row_0)
        if not ok then
            return nil, "del_block: " .. (err or "Unknown error in del_block_line")
        end
    end

    local start_line_after = vim.api.nvim_buf_get_lines(buf, start_row - 1, start_row, false)[1]
    local max_vcol_after = vim.fn.strdisplaywidth(start_line_after)
    l_mark_vcol = math.min(l_mark_vcol, max_vcol_after)

    local l_byte, _, l_err = blk_utils.byte_bounds_from_vcol(start_line_after, l_mark_vcol)
    if (not l_byte) or l_err then
        return nil, "del_block: " .. (l_err or "Unknown error in byte_bounds_from_vcol")
    end

    local fin_line_after = vim.api.nvim_buf_get_lines(buf, fin_row - 1, fin_row, false)[1]
    local r_col = math.min(l_byte, (#fin_line_after - 1))
    local r_byte, _, r_err = blk_utils.byte_bounds_from_col(fin_line_after, r_col)
    if (not r_byte) or r_err then
        return nil, "del_block: " .. (r_err or "Unknown error in byte_bounds_from_col")
    end

    vim.api.nvim_buf_set_mark(buf, "[", start_row, l_byte, {})
    vim.api.nvim_buf_set_mark(buf, "]", fin_row, r_byte, {})

    return {
        start = {
            row = start_row,
            col = l_byte,
        },
        finish = {
            row = fin_row,
            col = r_byte,
        },
    },
        nil
end

return M
