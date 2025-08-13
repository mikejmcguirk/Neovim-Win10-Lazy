local blk_utils = require("mjm.spec-ops.block-utils")
local op_utils = require("mjm.spec-ops.op-utils")

local M = {}

--- @param marks op_marks
--- @return  op_marks|nil, string|nil
local function del_chars(marks)
    local start_row = marks.start.row
    local fin_row = marks.fin.row
    if start_row > fin_row then
        return nil, "Start row " .. start_row .. " > finish row " .. fin_row .. " in get_chars"
    end

    local start_col = marks.start.col
    local fin_col = marks.fin.col

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
        fin = { row = start_row, col = start_col },
    },
        nil
end

--- @param marks op_marks
--- @param curswant integer
--- @param visual boolean
--- @return op_marks|nil, string|nil
local function del_lines(marks, curswant, visual)
    local start_row = marks.start.row
    local fin_row = marks.fin.row
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
        start = { row = start_row, col = post_col },
        fin = { row = start_row, col = post_col },
    },
        nil
end

--- @return op_marks|nil, string|nil
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
        return op_utils.op_set_block(opts.marks, opts.curswant)
    end
end

return M
