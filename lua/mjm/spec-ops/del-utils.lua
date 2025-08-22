local blk_utils = require("mjm.spec-ops.block-utils")

local M = {}

-- TODO: This can probably be re-generalized, but working through everything first

--- @param op_state op_state
--- @return string|nil
--- This function assumes that start_row <= fin_row is already verified
local function op_state_del_chars(op_state)
    local start_row = op_state.marks.start.row
    local start_col = op_state.marks.start.col
    local fin_row = op_state.marks.fin.row
    local fin_col = op_state.marks.fin.col

    local fin_line = vim.api.nvim_buf_get_lines(0, fin_row - 1, fin_row, false)[1]

    --- @type integer|nil, integer|nil, string|nil
    local _, fin_byte, err = blk_utils.byte_bounds_from_col(fin_line, fin_col)
    if (not fin_byte) or err then
        return "del_chars: " .. (err or "Unknown error in byte_bounds_from_col")
    end
    fin_byte = #fin_line > 0 and fin_byte + 1 or 0

    vim.api.nvim_buf_set_text(0, start_row - 1, start_col, fin_row - 1, fin_byte, {})

    start_row = math.min(start_row, vim.api.nvim_buf_line_count(0))
    vim.api.nvim_buf_set_mark(0, "[", start_row, start_col, {})
    vim.api.nvim_buf_set_mark(0, "]", start_row, start_col, {})

    op_state.marks_post = {
        start = { row = start_row, col = start_col },
        fin = { row = start_row, col = start_col },
    }

    return nil
end

---@param op_state op_state
---@return nil|string
--- This function assumes that start_row <= fin_row is already verified
local function del_lines(op_state)
    local start_row = op_state.marks.start.row
    local fin_row = op_state.marks.fin.row

    vim.api.nvim_buf_set_lines(0, start_row - 1, fin_row, false, {})

    start_row = math.min(start_row, vim.api.nvim_buf_line_count(0))
    local post_line = vim.api.nvim_buf_get_lines(0, start_row - 1, start_row, false)[1]
    local post_col = (function()
        if op_state.vmode then
            return 0
        else
            local line_len_0 = #post_line > 0 and #post_line - 1 or 0
            return math.min(line_len_0, op_state.view.curswant)
        end
    end)()

    vim.api.nvim_buf_set_mark(0, "[", start_row, post_col, {})
    vim.api.nvim_buf_set_mark(0, "]", start_row, post_col, {})

    op_state.marks_post = {
        start = { row = start_row, col = post_col },
        fin = { row = start_row, col = post_col },
    }

    return nil
end

-- TODO: Don't consolidate the set/delete/paste op making logic. It's just too confusing
-- And really, even the pastes might need to be broken up

--- @param op_state op_state
--- @param line string
--- @param l_vcol integer
--- @param r_vcol integer
--- @return block_op_info|nil, string|nil
local function get_block_del_row(op_state, line, l_vcol, r_vcol)
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

    return { text = set_line, start_byte = l_byte, fin_byte_ex = r_byte }
end

-- TODO: It might be possible to consdolidate everything here, but there has to be a reasonable
-- method to handle the different marking scenarios
-- It might be possible to use the op_type to create branching logic for mark management, since
-- the marks_after are tied to the op_state anyway
-- TODO: Need to think through edge cases here related to zero lines. Major ones seem sorted out
-- but others remain I'm sure
--- @param op_state op_state
--- @param del_info block_op_info[]
--- @return nil|string
local function do_block_del_ops(op_state, del_info)
    local marks = op_state.marks

    local start_row = marks.start.row --- @type integer
    local marks_after = { start = {}, fin = {} } --- @type op_marks

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

        if i == 1 then
            --- @type string
            local start_line = vim.api.nvim_buf_get_lines(0, row_0, row_1, false)[1]
            local start_byte = math.min(o.start_byte, #start_line - 1) --- @type integer
            start_byte = math.max(start_byte, 0)

            --- @type integer|nil, integer|nil, string|nil
            local l_byte, _, err = blk_utils.byte_bounds_from_col(start_line, start_byte)
            if (not l_byte) or err then
                return "do_block_ops: " .. (err or "Unknown error in byte_bounds_from_col")
            end

            marks_after.start.row = row_1
            marks_after.start.col = l_byte
        end

        if i == #del_info then
            --- @type string
            local fin_line = vim.api.nvim_buf_get_lines(0, row_0, row_1, false)[1]
            local fin_byte = math.min(marks_after.start.col, #fin_line - 1) --- @type integer
            fin_byte = math.max(fin_byte, 0)

            --- @type integer|nil, integer|nil, string|nil
            local l_byte, _, err = blk_utils.byte_bounds_from_col(fin_line, fin_byte)
            if (not l_byte) or err then
                return "do_block_ops: " .. (err or "Unknown error in byte_bounds_from_col")
            end

            marks_after.fin.row = row_1
            marks_after.fin.col = l_byte
        end
    end

    for i, o in pairs(del_info) do
        exec(i, o)
    end

    vim.api.nvim_buf_set_mark(0, "[", marks_after.start.row, marks_after.start.col, {})
    vim.api.nvim_buf_set_mark(0, "]", marks_after.fin.row, marks_after.fin.col, {})
    op_state.marks_post = marks_after
end

-- TODO: Can certainly be re-generalized, but trying to get the logic specific
---@param op_state op_state
---@return nil|string
--- This function assumes that the marks are already sorted so the start mark is on the
--- first row
--- This function assumes that start_row <= fin_row is already verified
local function del_block(op_state)
    local marks = op_state.marks --- @type op_marks

    --- @type string[]
    local lines = vim.api.nvim_buf_get_lines(0, marks.start.row - 1, marks.fin.row, false)

    --- @type integer|nil, integer|nil, string|nil
    local l_vcol, r_vcol, vcol_err = blk_utils.vcols_from_marks(lines, marks)
    if (not l_vcol) or not r_vcol or vcol_err then
        return "op_del_block: " .. (vcol_err or "Unknown error in vcols_from_marks")
    end

    local del_info = {} --- @type block_op_info[]

    for i = 1, #lines do
        --- @type block_op_info|nil, string|nil
        local info, err = get_block_del_row(op_state, lines[i], l_vcol, r_vcol)

        if (not info) or err then
            return "op_set_block: " .. (err or "Unknown error getting block op info")
        end

        table.insert(del_info, info)
    end

    return do_block_del_ops(op_state, del_info)
end

-- TODO: needs to be ok, err pattern

--- @param op_state op_state
--- @return string|nil
function M.do_del(op_state)
    if not op_state.marks then
        op_state.lines = nil
        return "do_del: No marks in op_state"
    end

    local start_row = op_state.marks.start.row
    local start_col = op_state.marks.start.col
    local fin_row = op_state.marks.fin.row

    if start_row > fin_row then
        local row_0 = start_row - 1
        vim.api.nvim_buf_set_text(0, row_0, start_col, row_0, start_col, {})
        return nil
    end

    op_state.motion = op_state.motion or "char"

    if op_state.motion == "line" then
        return del_lines(op_state)
    elseif op_state.motion == "block" then
        return del_block(op_state)
    else
        return op_state_del_chars(op_state)
    end
end

return M
