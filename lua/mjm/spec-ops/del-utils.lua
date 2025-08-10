local blk_utils = require("mjm.spec-ops.block-utils")

local M = {}

--- @param marks Marks
--- @return  Marks|nil, string|nil
local function del_chars(marks)
    local start_row = marks.start.row
    local fin_row = marks.finish.row
    if start_row > fin_row then
        return nil, "Start row " .. start_row .. " > finish row " .. fin_row .. " in get_chars"
    end

    local start_col = marks.start.col
    local fin_col = marks.finish.col

    local fin_line = vim.api.nvim_buf_get_lines(0, fin_row - 1, fin_row, false)[1]
    local _, fin_byte, err = blk_utils.byte_bounds_from_col(fin_line, fin_col)
    if (not fin_byte) or err then
        return nil, "delete_chars: " .. (err or "Unknown error in byte_bounds_from_col")
    end
    fin_byte = #fin_line > 0 and fin_byte + 1 or 0

    vim.api.nvim_buf_set_text(0, start_row - 1, start_col, fin_row - 1, fin_byte, {})
    start_row = math.min(start_row, vim.api.nvim_buf_line_count(0))
    vim.api.nvim_buf_set_mark(0, "[", start_row, start_col, {})
    vim.api.nvim_buf_set_mark(0, "]", start_row, start_col, {})

    return {
        start = { row = start_row, col = start_col },
        finish = { row = start_row, col = start_col },
    },
        nil
end

--- @param marks Marks
--- @param curswant integer
--- @param visual boolean
--- @return Marks|nil, string|nil
local function del_lines(marks, curswant, visual)
    local start_row = marks.start.row
    local fin_row = marks.finish.row
    if start_row > fin_row then
        return nil, "del_lines: Start row " .. start_row .. " > finish row " .. fin_row
    end

    vim.api.nvim_buf_set_lines(0, start_row - 1, fin_row, false, {})

    start_row = math.min(start_row, vim.api.nvim_buf_line_count(0))
    local post_line = vim.api.nvim_buf_get_lines(0, start_row - 1, start_row, false)[1]
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

--- @param line string
--- @param l_vcol integer
--- @param r_vcol integer
--- @param max_curswant boolean
--- @param row_0 integer
--- @return boolean, string|nil
local function del_block_line(line, l_vcol, r_vcol, max_curswant, row_0)
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

    vim.api.nvim_buf_set_text(0, row_0, l_byte, row_0, r_byte + 1, { padding })

    return true, nil
end

--- @param marks Marks
--- @param curswant integer
--- @return Marks|nil, string|nil
--- This function assumes that the marks are already sorted so the start mark is on the
--- first row
local function del_block(marks, curswant)
    local start_row = marks.start.row
    local fin_row = marks.finish.row
    local lines = vim.api.nvim_buf_get_lines(0, start_row - 1, fin_row, false)

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
        local ok, err = del_block_line(lines[i], l_vcol, r_vcol, max_curswant, row_0)
        if not ok then
            return nil, "del_block: " .. (err or "Unknown error in del_block_line")
        end
    end

    local start_line_after = vim.api.nvim_buf_get_lines(0, start_row - 1, start_row, false)[1]
    local max_vcol_after = vim.fn.strdisplaywidth(start_line_after)
    l_mark_vcol = math.min(l_mark_vcol, max_vcol_after)

    local l_byte, _, l_err = blk_utils.byte_bounds_from_vcol(start_line_after, l_mark_vcol)
    if (not l_byte) or l_err then
        return nil, "del_block: " .. (l_err or "Unknown error in byte_bounds_from_vcol")
    end

    local fin_line_after = vim.api.nvim_buf_get_lines(0, fin_row - 1, fin_row, false)[1]
    local r_col = math.min(l_byte, (#fin_line_after - 1))
    local r_byte, _, r_err = blk_utils.byte_bounds_from_col(fin_line_after, r_col)
    if (not r_byte) or r_err then
        return nil, "del_block: " .. (r_err or "Unknown error in byte_bounds_from_col")
    end

    vim.api.nvim_buf_set_mark(0, "[", start_row, l_byte, {})
    vim.api.nvim_buf_set_mark(0, "]", fin_row, r_byte, {})

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

--- @return Marks|nil, string|nil
function M.do_del(opts)
    opts = opts or {}

    if not opts.marks then
        return nil, "do_get: No marks to get from"
    end

    opts.motion = opts.motion or "char"
    opts.curswant = opts.curswant or vim.fn.winsaveview().curswant
    if opts.motion == "char" then
        return del_chars(opts.marks)
    elseif opts.motion == "line" then
        return del_lines(opts.marks, opts.curswant, opts.visual)
    else
        return del_block(opts.marks, opts.curswant)
    end
end

return M
