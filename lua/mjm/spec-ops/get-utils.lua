local blk_utils = require("mjm.spec-ops.block-utils")

local M = {}

---@param marks op_marks
---@return string[]|nil, string|nil
local function get_chars(marks)
    local start_row = marks.start.row
    local fin_row = marks.fin.row
    if start_row > fin_row then
        local err = "Start row " .. start_row .. " > finish row " .. fin_row .. " in get_chars"
        return nil, err
    end

    local start_col = marks.start.col
    local fin_col = marks.fin.col

    local fin_line = vim.api.nvim_buf_get_lines(0, fin_row - 1, fin_row, false)[1]
    local _, fin_byte, err = blk_utils.byte_bounds_from_col(fin_line, fin_col)
    if (not fin_byte) or err then
        return nil, "get_chars: " .. (err or "Unknown error in byte_bounds_from_col")
    end
    fin_byte = #fin_line > 0 and fin_byte + 1 or 0

    return vim.api.nvim_buf_get_text(0, start_row - 1, start_col, fin_row - 1, fin_byte, {})
end

---@param op_state op_state
---@return string[]|nil, string|nil
--- This function assumes that start_row <= fin_row is already verified
local function op_state_get_chars(op_state)
    local start_row = op_state.marks.start.row
    local start_col = op_state.marks.start.col
    local fin_row = op_state.marks.fin.row
    local fin_col = op_state.marks.fin.col

    local fin_line = vim.api.nvim_buf_get_lines(0, fin_row - 1, fin_row, false)[1]
    local _, fin_byte, err = blk_utils.byte_bounds_from_col(fin_line, fin_col)
    if (not fin_byte) or err then
        return nil, "get_chars: " .. (err or "Unknown error in byte_bounds_from_col")
    end
    fin_byte = #fin_line > 0 and fin_byte + 1 or 0

    return vim.api.nvim_buf_get_text(0, start_row - 1, start_col, fin_row - 1, fin_byte, {})
end

---@param marks op_marks
---@return string[]|nil, string|nil
local function get_lines(marks)
    local start_row = marks.start.row
    local fin_row = marks.fin.row

    if start_row > fin_row then
        return nil, "Start row " .. start_row .. " > finish row " .. fin_row .. "in get_lines"
    end

    local fin_line = vim.api.nvim_buf_get_lines(0, fin_row - 1, fin_row, false)[1]
    return vim.api.nvim_buf_get_text(0, start_row - 1, 0, fin_row - 1, #fin_line, {}), nil
end

---@param op_state op_state
---@return string[]|nil, string|nil
--- This function assumes that start_row <= fin_row is already verified
local function op_state_get_lines(op_state)
    local start_row = op_state.marks.start.row
    local fin_row = op_state.marks.fin.row

    local fin_line = vim.api.nvim_buf_get_lines(0, fin_row - 1, fin_row, false)[1]
    return vim.api.nvim_buf_get_text(0, start_row - 1, 0, fin_row - 1, #fin_line, {}), nil
end

--- @param line string
--- @param l_vcol integer
--- @param r_vcol integer
--- @return string|nil, string|nil
local function get_block_line(row_0, line, l_vcol, r_vcol, max_curswant)
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

    local text = vim.api.nvim_buf_get_text(0, row_0, l_byte, row_0, r_byte + 1, {})[1]
    return string.rep(" ", this_l_vcol - l_vcol) .. text
end

-- TODO: Right now this is actually asking like "zy" because we don't add extra space up to the
-- block width. I'm... actually fine with that being default behavior, but nonetheless we should
-- emulate Nvim accurately
-- Since we now have the op_state variable, what we would do is pass the ctx value down with it
-- and then, if I'm understanding right, we should just be able to add r_padding based on the
-- difference between this_r_vcol and r_vcol

--- @param line string
--- @param l_vcol integer
--- @param r_vcol integer
--- @return string|nil, string|nil
local function op_state_get_block_line(op_state, row_0, line, l_vcol, r_vcol)
    local max_vcol = vim.fn.strdisplaywidth(line)

    if #line == 0 or max_vcol < l_vcol then
        return "", nil
    end

    local l_l_vcol, l_r_vcol, l_err = blk_utils.vcols_from_vcol(line, l_vcol)
    if (not l_l_vcol) or not l_r_vcol or l_err then
        return nil, "get_block_line: " .. (l_err or "Unknown error in vcols_from_vcol")
    end

    local this_l_vcol = l_vcol <= l_l_vcol and l_l_vcol or l_r_vcol + 1
    if this_l_vcol > max_vcol then
        return "", nil
    end

    local this_r_vcol = math.min(r_vcol, max_vcol)
    this_r_vcol = op_state.curswant == vim.v.maxcol and max_vcol or this_r_vcol
    local r_l_vcol, r_r_vcol, r_err = blk_utils.vcols_from_vcol(line, this_r_vcol)
    if (not r_l_vcol) or not r_r_vcol or r_err then
        return nil, "get_block_line: " .. (r_err or "Unknown error in vcols_from_vcol")
    end

    this_r_vcol = r_r_vcol <= this_r_vcol and this_r_vcol or r_l_vcol - 1
    if this_r_vcol < 0 or this_r_vcol < this_l_vcol then
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

    local text = vim.api.nvim_buf_get_text(0, row_0, l_byte, row_0, r_byte + 1, {})[1]
    return string.rep(" ", this_l_vcol - l_vcol) .. text
end
--- @param marks op_marks
--- @param curswant? integer
--- @return string[]|nil, string|nil
--- This function assumes that the marks are already sorted so the start mark is on the
--- first row
--- This function assumes that start_row <= fin_row is already verified
local function get_block(marks, curswant)
    local start_row = marks.start.row
    local fin_row = marks.fin.row
    local lines = vim.api.nvim_buf_get_lines(0, start_row - 1, fin_row, false)

    local l_vcol, r_vcol, vcol_err = blk_utils.vcols_from_marks(lines, marks)
    if (not l_vcol) or not r_vcol or vcol_err then
        return nil, "get_block: " .. vcol_err
    end

    local max_curswant = curswant and curswant == vim.v.maxcol

    local block_lines = {}
    for i = 1, #lines do
        local row_0 = start_row + i - 2
        local this_line = get_block_line(row_0, lines[i], l_vcol, r_vcol, max_curswant)
        table.insert(block_lines, this_line)
    end

    return block_lines, nil
end

--- @param op_state op_state
--- @return string[]|nil, string|nil
--- This function assumes that the marks are already sorted so the start mark is on the
--- first row
local function op_state_get_block(op_state)
    local start_row = op_state.marks.start.row
    local fin_row = op_state.marks.fin.row
    local lines = vim.api.nvim_buf_get_lines(0, start_row - 1, fin_row, false)

    local l_vcol, r_vcol, vcol_err = blk_utils.vcols_from_marks(lines, op_state.marks)
    if (not l_vcol) or not r_vcol or vcol_err then
        return nil, "get_block: " .. (vcol_err or "Unknown error in vcols_from_marks")
    end

    local block_lines = {}
    for i = 1, #lines do
        local row_0 = start_row + i - 2
        local this_line = op_state_get_block_line(op_state, row_0, lines[i], l_vcol, r_vcol)
        table.insert(block_lines, this_line)
    end

    return block_lines, nil
end

--- @return string[]|nil, string|nil
function M.do_get(opts)
    opts = opts or {}

    if not opts.marks then
        return nil, "do_get: No marks to get from"
    end

    opts.motion = opts.motion or "char"
    if opts.motion == "char" then
        return get_chars(opts.marks)
    elseif opts.motion == "line" then
        return get_lines(opts.marks)
    else
        opts.curswant = opts.curswant or vim.fn.winsaveview().curswant
        return get_block(opts.marks, opts.curswant)
    end
end

-- TODO: Obviously rename this when done
--- @param op_state op_state
--- @return boolean|nil, nil|string
function M.do_state_get(op_state)
    if not op_state.marks then
        op_state.lines = nil
        return nil, "do_get: No marks in op_state"
    end

    local start_row = op_state.marks.start.row
    local start_col = op_state.marks.start.col
    local fin_row = op_state.marks.fin.row

    if start_row > fin_row then
        local row_0 = start_row - 1
        op_state.lines = vim.api.nvim_buf_get_text(0, row_0, start_col, row_0, start_col, {})
        return nil
    end

    op_state.motion = op_state.motion or "char"
    local lines, err = (function()
        if op_state.motion == "line" then
            return op_state_get_lines(op_state)
        elseif op_state.motion == "block" then
            return op_state_get_block(op_state)
        else
            return op_state_get_chars(op_state)
        end
    end)()

    if (not lines) or err then
        return nil, "do_get: " .. (err or "Unknown error in sub-function")
    end

    -- TODO: Unsure of how to handle the typing here
    op_state.lines = lines
    op_state.marks_post = op_state.marks
    return true, nil
end

return M
