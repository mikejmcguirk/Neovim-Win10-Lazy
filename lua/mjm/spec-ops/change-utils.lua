local blk_utils = require("mjm.spec-ops.block-utils")

local M = {}

--- @param op_state op_state
--- @return boolean|nil, string|nil
--- Modifies op_state in place
--- Assumes that start_row <= fin_row is already verified
local function chg_chars(op_state)
    local start_row = op_state.marks.start.row
    local start_col = op_state.marks.start.col
    local fin_row = op_state.marks.fin.row
    local fin_col = op_state.marks.fin.col

    local fin_line = vim.api.nvim_buf_get_lines(0, fin_row - 1, fin_row, false)[1]

    --- @type integer|nil, integer|nil, string|nil
    local _, fin_byte, err = blk_utils.byte_bounds_from_col(fin_line, fin_col)
    if (not fin_byte) or err then
        return nil, "del_chars: " .. (err or "Unknown error in byte_bounds_from_col")
    end
    fin_byte = #fin_line > 0 and fin_byte + 1 or 0

    vim.api.nvim_buf_set_text(0, start_row - 1, start_col, fin_row - 1, fin_byte, {})

    -- Store to determine enter insert cmd later
    op_state.start_line_post = vim.api.nvim_buf_get_lines(0, start_row - 1, start_row, false)[1]
    op_state.fin_line_post = vim.api.nvim_buf_get_lines(0, fin_row - 1, fin_row, false)[1]

    local start_col_post = math.min(start_col, #op_state.start_line_post - 1)
    --- @type integer|nil, integer|nil, string|nil
    local l_byte, _, bb_err =
        blk_utils.byte_bounds_from_col(op_state.start_line_post, start_col_post)
    if (not l_byte) or bb_err then
        return nil, "chg_chars: " .. (err or "Unknown error in byte_bounds_from_col")
    end

    op_state.marks_post = {
        start = { row = start_row, col = l_byte },
        fin = { row = start_row, col = l_byte },
    }

    -- TODO: Naming convention must be shorter
    -- TODO: Got burnt here because I didn't use the op_state marks as single source of truth
    -- redo other instances of this to fix
    vim.api.nvim_buf_set_mark(
        0,
        "[",
        op_state.marks_post.start.row,
        op_state.marks_post.start.col,
        {}
    )
    vim.api.nvim_buf_set_mark(0, "]", op_state.marks_post.fin.row, op_state.marks_post.fin.col, {})

    return true, nil
end

--- @param op_state op_state
--- @return boolean|nil, string|nil
--- Modifies op_state in place
--- Assumes that start_row <= fin_row is already verified
local function chg_lines(op_state)
    local start_row = op_state.marks.start.row
    local fin_row = op_state.marks.fin.row

    vim.api.nvim_buf_set_lines(0, start_row - 1, fin_row, false, { "" })

    vim.api.nvim_buf_set_mark(0, "[", start_row, 0, {})
    vim.api.nvim_buf_set_mark(0, "]", start_row, 0, {})

    op_state.marks_post = {
        start = { row = start_row, col = 0 },
        fin = { row = start_row, col = 0 },
    }

    return true, nil
end

--- @param op_state op_state
--- @param line string
--- @param l_vcol integer
--- @param r_vcol integer
--- @return block_op_info|nil, nil|string
local function get_block_chg_row(op_state, line, l_vcol, r_vcol)
    local max_vcol = vim.fn.strdisplaywidth(line) --- @type integer
    if max_vcol < l_vcol then
        return {}
    end

    if #line == 0 then
        return { start_byte = 0, fin_byte_ex = 0 }
    end

    --- @type integer|nil, integer|nil, string|nil
    local this_l_vcol, _, l_err = blk_utils.vcols_from_vcol(line, l_vcol)
    if (not this_l_vcol) or l_err then
        return nil, "get_block_del_row: " .. (l_err or "Unknown error in vcols_from_vcol")
    end

    --- @type integer|nil, integer|nil, string|nil
    local l_byte, _, lb_err = blk_utils.byte_bounds_from_vcol(line, this_l_vcol)
    if (not l_byte) or lb_err then
        return nil, "get_block_del_row: " .. (lb_err or "Unknown error in byte_bounds_from_vcol")
    end

    local target_r_vcol = math.min(r_vcol, max_vcol) --- @type integer
    target_r_vcol = op_state.view.curswant == vim.v.maxcol and max_vcol or target_r_vcol

    --- @type integer|nil, integer|nil, string|nil
    local _, this_r_vcol, r_err = blk_utils.vcols_from_vcol(line, target_r_vcol)
    if (not this_r_vcol) or r_err then
        return nil, "get_block_del_row: " .. (r_err or "Unknown error in vcols_from_vcol")
    end

    --- @type integer|nil, integer|nil, string|nil
    local _, r_byte, rb_err = blk_utils.byte_bounds_from_vcol(line, this_r_vcol)
    if (not r_byte) or rb_err then
        return nil, "get_block_del_row: " .. (rb_err or "Unknown error in byte_bounds_from_vcol")
    end

    r_byte = #line > 0 and r_byte + 1 or 0
    if l_byte > r_byte then
        return {}, nil
    end

    local set_line = ""
    local l_pad_len = l_vcol - this_l_vcol --- @type integer
    local r_pad_len = this_r_vcol - target_r_vcol --- @type integer
    local l_padding = string.rep(" ", (l_pad_len > 0 and l_pad_len or 0)) --- @type string
    local r_padding = string.rep(" ", (r_pad_len > 0 and r_pad_len or 0)) --- @type string
    set_line = l_padding .. set_line .. r_padding

    return {
        text = set_line,
        start_byte = l_byte,
        fin_byte_ex = r_byte,
        l_vcol = this_l_vcol,
        r_vcol = this_r_vcol,
    }
end

-- TODO: It might be possible to consdolidate everything here, but there has to be a reasonable
-- method to handle the different marking scenarios
-- It might be possible to use the op_type to create branching logic for mark management, since
-- the marks_after are tied to the op_state anyway
-- TODO: Need to think through edge cases here related to zero lines. Major ones seem sorted out
-- but others remain I'm sure
--- @param op_state op_state
--- @param chg_info block_op_info[]
--- @return boolean|nil, nil|string
local function do_block_chg_ops(op_state, chg_info)
    -- TODO: Not exposed so doesn't need extensive validation, but should catch mistakes
    local marks = op_state.marks

    local start_row = marks.start.row --- @type integer
    local marks_after = { start = {}, fin = {} } --- @type op_marks
    local start_l_vcol = chg_info[1].l_vcol

    --- @param i integer
    --- @param o block_op_info
    local function exec(i, o)
        if not (o.start_byte and o.fin_byte_ex) then
            return
        end

        local row_1 = start_row + i - 1 --- @type integer
        local row_0 = row_1 - 1 --- @type integer
        local new = o.text or ""
        vim.api.nvim_buf_set_text(0, row_0, o.start_byte, row_0, o.fin_byte_ex, { new })

        op_state.start_line_post = vim.api.nvim_buf_get_lines(0, row_0, row_1, false)[1]

        if i == 1 then
            --- @type integer
            local start_byte = math.min(o.start_byte, #op_state.start_line_post - 1)
            start_byte = math.max(start_byte, 0)

            --- @type integer|nil, integer|nil, string|nil
            local l_byte, _, err =
                blk_utils.byte_bounds_from_col(op_state.start_line_post, start_byte)
            if (not l_byte) or err then
                return nil, "do_block_ops: " .. (err or "Unknown error in byte_bounds_from_col")
            end

            marks_after.start.row = row_1
            marks_after.start.col = l_byte

            -- Need to re-calculate here in case the first line is deleted all the way to the end
            --- @type integer|nil, integer|nil, string|nil
            local l_vcol, _, v_err = blk_utils.vcols_from_col(op_state.start_line_post, l_byte)
            if (not l_vcol) or v_err then
                return nil, "do_block_ops: " .. (err or "Unknown error in vcols_from_col")
            end

            start_l_vcol = l_vcol
        end

        if i == #chg_info then
            --- @type string
            op_state.fin_line_post = vim.api.nvim_buf_get_lines(0, row_0, row_1, false)[1]
            local max_fin_vcol = vim.fn.strdisplaywidth(op_state.fin_line_post)
            local fin_vcol = math.min(max_fin_vcol, start_l_vcol)

            if fin_vcol < start_l_vcol then
                --- @type integer|nil, integer|nil, string|nil
                local l_byte, _, err =
                    blk_utils.byte_bounds_from_vcol(op_state.start_line_post, fin_vcol)
                if (not l_byte) or err then
                    return "do_block_ops: " .. (err or "Unknown error in byte_bounds_from_vcol")
                end

                marks_after.start.col = l_byte
            end

            --- @type integer|nil, integer|nil, string|nil
            local l_byte, _, err =
                blk_utils.byte_bounds_from_vcol(op_state.fin_line_post, fin_vcol)
            if (not l_byte) or err then
                return "do_block_ops: " .. (err or "Unknown error in byte_bounds_from_vcol")
            end

            marks_after.fin.row = row_1
            marks_after.fin.col = l_byte
        end
    end

    for i, o in pairs(chg_info) do
        exec(i, o)
    end

    vim.api.nvim_buf_set_mark(0, "[", marks_after.start.row, marks_after.start.col, {})
    vim.api.nvim_buf_set_mark(0, "]", marks_after.fin.row, marks_after.fin.col, {})
    op_state.marks_post = marks_after

    return true, nil
end

-- TODO: Can certainly be re-generalized, but trying to get the logic specific
---@param op_state op_state
---@return boolean|nil, nil|string
--- This function assumes that the marks are already sorted so the start mark is on the first row
--- This function assumes that start_row <= fin_row is already verified
local function chg_block(op_state)
    local marks = op_state.marks --- @type op_marks

    --- @type string[]
    local lines = vim.api.nvim_buf_get_lines(0, marks.start.row - 1, marks.fin.row, false)

    --- @type integer|nil, integer|nil, string|nil
    local l_vcol, r_vcol, vcol_err = blk_utils.vcols_from_marks(lines, marks)
    if (not l_vcol) or not r_vcol or vcol_err then
        return nil, "op_del_block: " .. (vcol_err or "Unknown error in vcols_from_marks")
    end

    local chg_info = {} --- @type block_op_info[]

    for i = 1, #lines do
        --- @type block_op_info|nil, string|nil
        local info, err = get_block_chg_row(op_state, lines[i], l_vcol, r_vcol)

        if (not info) or err then
            return nil, "op_set_block: " .. (err or "Unknown error getting block op info")
        end

        table.insert(chg_info, info)
    end

    return do_block_chg_ops(op_state, chg_info)
end

-- TODO: A smaller and a bigger thought in here
-- The smaller thought: For any exposed functions, there simply must be validation of the
-- incoming data. It adds execution time, but we cannot make assumptions about the incoming data
-- The bigger thought relates to error handling. One change we've made that's been good is to
-- implement fallback behavior where possible. This makes errors harder to track in theory,
-- but in practice provides a smoother experience and makes the code easier to maintain. Could
-- maybe be more willing to return more errors once extui is actually live. I'm also wondering
-- about the error handling in general. On one hand, the errors I have are extremely useful
-- for debugging weird things like bad column transformations. On the other, it makes the code
-- much less ergonomic to work with. Especially in this case, where we are editing op_state
-- in place but then we have to return an error value for checking.

--- @param op_state op_state
--- @return boolean|nil, nil|string
function M.do_change(op_state)
    if not op_state.marks then
        op_state.lines = nil
        return nil, "do_change: No marks in op_state"
    end

    local start_row = op_state.marks.start.row
    local start_col = op_state.marks.start.col
    local fin_row = op_state.marks.fin.row

    if start_row > fin_row then
        local row_0 = start_row - 1
        vim.api.nvim_buf_set_text(0, row_0, start_col, row_0, start_col, {})
        return true, nil
    end

    op_state.motion = op_state.motion or "char"

    if op_state.motion == "line" then
        return chg_lines(op_state)
    elseif op_state.motion == "block" then
        return chg_block(op_state)
    else
        return chg_chars(op_state)
    end
end

return M
