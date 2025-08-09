local utils = require("mjm.spec-ops.utils")

-- NOTE: The various functions to get vcols from byte or character positions are necessary
-- because the builtin virtcol2col function is based on display lines, not logical lines

-- NOTE: Because these functions are exposed and can have unexpected interactions,
-- error checks are performed for each set of parameters, even when they are likely redundant

local M = {}

-- PERF: In *theory*, any function calling this one should have already checked for a line length
-- of zero, negating the need for the zero length check

--- @param line string
--- @param col integer
--- @return boolean, string|nil
local function is_valid_col(line, col)
    if col < 0 then
        return false, "is_valid_col: Col less than zero"
    end

    if #line == 0 and col > 0 then
        --- @type string
        local err_msg = string.format(
            "is_valid_col: Input col %d greater than zero on a zero length line",
            col
        )
        return false, err_msg
    end

    if #line > 0 and col >= #line then
        return false, string.format("is_valid_col: Input col %d >= line length %d", col, #line)
    end

    return true, nil
end

--- @param lines string[]
--- @param marks Marks
--- @return integer|nil, integer|nil, string|nil
--- From a pair of byte-based marks, get the left and right virtual column boundaries
--- Virtual columns are one-indexed, unless the line length is zero, in which case the virtual
--- column is zero
function M.get_vcols_from_marks(lines, marks)
    if #lines < 1 then
        return nil, nil, "Lines is empty at get_vcols_from_marks"
    end
    marks = utils.sort_marks(marks) --- @type Marks

    --- @type integer|nil, integer|nil, string|nil
    local t_l_vcol, t_r_vcol, t_vcol_err = M.vcols_from_col(lines[1], marks.start.col)
    if (not t_l_vcol) or not t_r_vcol or t_vcol_err then
        return nil, nil, "get_block_vcols: " .. (t_vcol_err or "Unknown error in vcols_from_col")
    end

    --- @type integer|nil, integer|nil, string|nil
    local b_l_vcol, b_r_vcol, b_vcol_err = M.vcols_from_col(lines[#lines], marks.finish.col)
    if (not b_l_vcol) or not b_r_vcol or b_vcol_err then
        return nil, nil, "get_block_vcols: " .. (b_vcol_err or "Unknown error in vcols_from_col")
    end

    local l_vcol = t_l_vcol <= b_l_vcol and t_l_vcol or b_l_vcol --- @type integer
    local r_vcol = b_r_vcol >= t_r_vcol and b_r_vcol or t_r_vcol --- @type integer

    return l_vcol, r_vcol, nil
end

--- @param lines string[]
--- @return integer
function M.get_block_reg_width(lines)
    return vim.iter(lines):fold(0, function(acc, d)
        local width = vim.fn.strcharlen(d)
        if width > acc then
            return width
        else
            return acc
        end
    end)
end

--- @param line string
--- @param col integer
--- @return integer|nil, integer|nil, string|nil
--- From a line and column byte, get the virtual column boundaries of the character at the column
--- The input column should be zero indexed
--- Virtual columns are one indexed, unless the line length is zero, in which case 0, 0 will be
--- returned
function M.vcols_from_col(line, col)
    if #line <= 1 then
        local width = vim.fn.strdisplaywidth(line) --- @type integer
        -- Check #line vs. width in case there's an edge case where a one byte char has a
        -- zero display width
        return (#line <= width and #line or width), width, nil
    end

    local valid_col, valid_col_err = is_valid_col(line, col) --- @type boolean, string|nil
    if (not valid_col) or valid_col_err then
        return nil, nil, valid_col_err .. " at vcols_from_col"
    end

    --- @type integer|nil, integer|nil, string|nil
    local start_byte, end_byte, bb_err = M.byte_bounds_from_col(line, col)
    if (not start_byte) or not end_byte or bb_err then
        return nil, nil, "vcols from col: " .. (bb_err or "Unknown error in byte_bounds_from_col")
    end

    --- @type integer|nil, integer|nil, string|nil
    local start_vcol, end_vcol, vcol_err = M.vcols_from_byte_bounds(line, start_byte, end_byte)
    if (not start_vcol) or not end_vcol or vcol_err then
        local err = "vcols_from_col: " .. (vcol_err or "Unknown error in vcols_from_byte_bounds")
        return nil, nil, err
    end

    return start_vcol, end_vcol, nil
end

-- PERF: If the col is valid, shouldn't the the vim functions all have valid returns?

--- @param line string
--- @param col integer
--- @return integer|nil, integer|nil, string|nil
--- Given a line and column, find the start and end byte bounds of the character at the column
--- This function assumes a zero-indexed column input
--- The output bytes are zero indexed and end inclusive
function M.byte_bounds_from_col(line, col)
    if #line <= 1 then
        return 0, 0
    end

    local valid_col, valid_col_err = is_valid_col(line, col) --- @type boolean, string|nil
    if not valid_col then
        return nil, nil, "byte_bounds_from_col: " .. valid_col_err
    end

    local char_idx = vim.fn.charidx(line, col) --- @type integer
    if char_idx == -1 then
        --- @type string
        local err_msg = string.format(
            "byte_bounds_from_col: charidx() returned -1 for line %s and col %d",
            line,
            col
        )
        return nil, nil, err_msg
    end

    local start_byte = vim.fn.byteidx(line, char_idx) --- @type integer
    if start_byte == -1 then
        --- @type string
        local err = string.format(
            "byte_bounds_from_col: byteidx() returned -1 for line %s and col %d",
            line,
            col
        )
        return nil, nil, err
    end

    local char = vim.fn.strcharpart(line, char_idx, 1, true) --- @type string
    if char == "" then
        --- @type string
        local err = string.format(
            'byte_bounds_from_col: strcharpart() returned "" for line %s and col %d',
            line,
            col
        )
        return nil, nil, err
    end

    local end_byte = start_byte + #char - 1 --- @type integer
    local valid_end, valid_end_err = is_valid_col(line, end_byte) --- @type boolean, string|nil
    if not valid_end then
        return nil, nil, "byte_bounds_from_col: " .. valid_end_err
    end

    return start_byte, end_byte, nil
end

--- @param line string
--- @param char_idx integer
--- @param char string
--- @param char_len integer
--- @return integer|nil, integer|nil, string|nil
--- Get the inclusive virtual column bounds of a character index
--- Characters are zero indexed
--- Virtual columns are one indexed, unless the line length is zero, in which case 0, 0 will be
--- returned
function M.vcols_from_char_idx(line, char_idx, char, char_len)
    -- Handle this way because the char_idx of an empty line is -1
    if line == "" then
        return 0, 0, nil
    end

    if char_idx < 0 then
        return nil, nil, "vcols_from_char_idx: char_idx < 0"
    end

    if char_idx >= char_len then
        --- @type string
        local err_msg =
            string.format("vcols_from_char_idx: char_idx %d >= char_len %d", char_idx, char_len)
        return nil, nil, err_msg
    end

    local byte_start = vim.fn.byteidx(line, char_idx) --- @type integer
    if byte_start == -1 then
        --- @type string
        local err_msg = string.format(
            "vcols_from_char_idx: byteidx() returned -1 for char_idx %d into string %s",
            char_idx,
            line
        )
        return nil, nil, err_msg
    end
    local byte_end_1 = byte_start + #char --- @type integer

    local end_vcol = vim.fn.strdisplaywidth(line:sub(1, byte_end_1)) --- @type integer
    local vcol_width = vim.fn.strdisplaywidth(char) --- @type integer
    local start_vcol = end_vcol - vcol_width + 1 --- @type integer
    return start_vcol, end_vcol, nil
end

-- PERF: The binary search fallback could use the mid_idx of the search as the starting point
-- for iteration. But for the sake of simplicity, and because the fallback should never happen
-- anyway, just iterate through the characters like Nvim core does

--- @param line string
--- @param vcol integer
--- @return integer|nil, integer|nil, string|nil
-- For a given line and virtual column, find the virtual column bounds of the character
-- Because of combining characters, this function searches by character indexes
-- Virtual columns are one-indexed, unless the line length is zero, in which case the function
-- returns 0, 0
function M.vcols_from_vcol(line, vcol)
    local max_vcol = vim.fn.strdisplaywidth(line) --- @type integer
    if #line <= 1 then
        -- Check #line vs. max_vcol for edge case where a one byte char has a zero display width
        return (#line <= max_vcol and #line or max_vcol), max_vcol, nil
    end

    if vcol == 0 then
        return 0, 0, nil
    end

    if vcol < 0 or vcol > max_vcol then
        --- @type string
        local err = string.format("vcols_from_vcol: Invalid vcol %d. Max vcol %d", vcol, max_vcol)
        return nil, nil, err
    end

    local char_len = vim.fn.strcharlen(line) --- @type integer
    local low_idx = 0 --- @type integer
    local high_idx = char_len - 1 --- @type integer
    while low_idx <= high_idx do
        local mid_idx = math.floor((low_idx + high_idx) * 0.5) --- @type integer
        local char = vim.fn.strcharpart(line, mid_idx, 1, true) --- @type string

        --- @type integer|nil, integer|nil, string|nil
        local start_vcol, end_vcol, char_err = M.vcols_from_char_idx(line, mid_idx, char, char_len)
        if (not start_vcol) or not end_vcol or char_err then
            return nil, nil, "vcols_from_vcol: " .. char_err
        end

        if start_vcol <= vcol and vcol <= end_vcol then
            return start_vcol, end_vcol, nil
        elseif end_vcol < vcol then
            low_idx = mid_idx + 1
        else
            high_idx = mid_idx - 1
        end
    end

    local idx = 0
    while idx < char_len do
        local char = vim.fn.strcharpart(line, idx, 1, true) --- @type string

        --- @type integer|nil, integer|nil, string|nil
        local start_vcol, end_vcol, char_err = M.vcols_from_char_idx(line, idx, char, char_len)
        if (not start_vcol) or not end_vcol or char_err then
            return nil, nil, "vcols_from_vcol: " .. char_err
        end

        if start_vcol <= vcol and vcol <= end_vcol then
            return start_vcol, end_vcol, nil
        end

        idx = idx + 1
    end

    --- @type string
    local err_msg =
        string.format("vcols_from_vcol: Unable to find vcols for vcol %d in line %s", vcol, line)
    return nil, nil, err_msg
end

--- @param line string
--- @param char_idx integer
--- @param char string
--- @param char_len integer
--- @return integer|nil, integer|nil, string|nil
--- For a given line, character, and character index, get the zero-indexed, inclusive byte bounds
--- Characters are zero indexed
function M.byte_bounds_from_char_idx(line, char_idx, char, char_len)
    if line == "" then
        return 0, 0, nil
    end

    if char_idx < 0 then
        return nil, nil, "byte_bounds_from_char_idx: char_idx < 0"
    end

    if char_idx >= char_len then
        local err_msg = string.format(
            "byte_bounds_from_char_idx: char_idx %d greater than character length %d",
            char_idx,
            char_len
        )
        return nil, nil, err_msg
    end

    local start_byte = vim.fn.byteidx(line, char_idx) --- @type integer
    if start_byte == -1 then
        --- @type string
        local err_msg = string.format(
            "byte_bounds_from_char_idx: byteidx of -1 for char_idx %d in line %s",
            char_idx,
            line
        )
        return nil, nil, err_msg
    end

    return start_byte, start_byte + #char - 1, nil
end

--- @param line string
--- @param start_byte integer
--- @param end_byte integer
--- @return integer|nil, integer|nil, string|nil
--- For a given start and end byte, get the virtual column boundaries
--- The start and end bytes should be zero indexed, inclusive
--- Virtual columns are one-indexed, unless the line length is zero, in which case 0,0 will be
--- returned
function M.vcols_from_byte_bounds(line, start_byte, end_byte)
    if line == "" then
        return 0, 0, nil
    end

    if start_byte > end_byte then
        --- @type string
        local err_msg = string.format(
            "vcols_from_byte_bounds: Start byte %d > end byte %d",
            start_byte,
            end_byte
        )
        return nil, nil, err_msg
    end

    --- @type boolean, string|nil
    local valid_start_byte, start_byte_err = is_valid_col(line, start_byte)
    if (not valid_start_byte) or start_byte_err then
        --- @type string
        local err_msg = "invalid start byte at vcols_from_byte_bounds: "
            .. (start_byte_err or "nil error at is_valid_col")
        return nil, nil, err_msg
    end
    local valid_end_byte, end_byte_err = is_valid_col(line, end_byte) --- @type boolean, string|nil
    if (not valid_end_byte) or end_byte_err then
        --- @type string
        local err_msg = "invalid end byte at vcols_from_byte_bounds: "
            .. (end_byte_err or "nil error at is_valid_col")
        return nil, nil, err_msg
    end

    local end_vcol = vim.fn.strdisplaywidth(line:sub(1, end_byte + 1)) --- @type integer
    --- @type integer
    local vcol_width = vim.fn.strdisplaywidth(line:sub(start_byte + 1, end_byte + 1))
    local start_vcol = end_vcol - vcol_width + 1 --- @type integer

    return start_vcol, end_vcol, nil
end

-- FUTURE: The binary search and the fallback loop have enough common logic to be outlined.
-- Roughly, see if we get good byte bounds. If not, then do individualized iteration.
-- But I want to make sure the current logic meets enough use cases before doing so

--- @param line string
--- @param vcol integer
--- @return integer|nil, integer|nil, string|nil
--- For a given line and virtual column, get the bound bounds of the character within it
--- Virtual columns are one-indexed, unless the line length is zero, in which case the virtual
--- column is zero
--- The returned byte bounds are zero indexed, inclusive
function M.byte_bounds_from_vcol(line, vcol)
    if #line <= 1 or vcol == 0 then
        return 0, 0, nil
    end

    local max_vcol = vim.fn.strdisplaywidth(line) --- @type integer
    if vcol < 0 or vcol > max_vcol then
        --- @type string
        local err =
            string.format("byte_bounds_from_vcol: Invalid vcol %d. Max vcol %d", vcol, max_vcol)
        return nil, nil, err
    end

    local char_len = vim.fn.strcharlen(line) --- @type integer
    local low_idx = 0 --- @type integer
    local high_idx = char_len - 1 --- @type integer
    while low_idx <= high_idx do
        local mid_idx = math.floor((low_idx + high_idx) * 0.5) --- @type integer
        local char = vim.fn.strcharpart(line, mid_idx, 1, true) --- @type string

        --- @type integer|nil, integer|nil, string|nil
        local start_vcol, end_vcol, char_err = M.vcols_from_char_idx(line, mid_idx, char, char_len)
        if (not start_vcol) or not end_vcol or char_err then
            return nil, nil, "byte_bounds_from_vcol: " .. char_err
        end

        if start_vcol <= vcol and vcol <= end_vcol then
            --- @type integer|nil, integer|nil, string|nil
            local start_byte, end_byte, bb_err =
                M.byte_bounds_from_char_idx(line, mid_idx, char, char_len)
            if (not start_byte) or not end_byte or bb_err then
                return nil, nil, "byte_bounds_from_vcol: " .. bb_err
            end

            return start_byte, end_byte, nil
        elseif end_vcol < vcol then
            low_idx = mid_idx + 1
        else
            high_idx = mid_idx - 1
        end
    end

    local idx = 0 --- @type integer
    while idx < char_len do
        local char = vim.fn.strcharpart(line, idx, 1, true) --- @type string
        --- @type integer|nil, integer|nil, string|nil
        local start_vcol, end_vcol, char_err = M.vcols_from_char_idx(line, idx, char, char_len)
        if (not start_vcol) or not end_vcol or char_err then
            return nil, nil, "byte_bounds_from_vcol: " .. char_err
        end

        if start_vcol <= vcol and vcol <= end_vcol then
            --- @type integer|nil, integer|nil, string|nil
            local start_byte, end_byte, bb_err =
                M.byte_bounds_from_char_idx(line, idx, char, char_len)
            if (not start_byte) or not end_byte or bb_err then
                return nil, nil, "byte_bounds_from_vcol: " .. bb_err
            end
            return start_byte, end_byte, nil
        end

        idx = idx + 1
    end

    --- @type string
    local err_msg = string.format(
        "byte_bounds_from_vcol: Unable to find vcols for vcol %d in line %s",
        vcol,
        line
    )
    return nil, nil, err_msg
end

return M
