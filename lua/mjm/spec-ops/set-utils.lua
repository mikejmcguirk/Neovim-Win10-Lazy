-- TOOD: Handle bottom < top row the way substitute does

local blk_utils = require("mjm.spec-ops.block-utils")
local paste_utils = require("mjm.spec-ops.paste-utils")
local op_utils = require("mjm.spec-ops.op-utils")
local utils = require("mjm.spec-ops.utils")

local M = {}

local mtype = {
    SC = 1, -- Single line char reg/motion
    MC = 2, -- Multi-line char reg/motion
    L = 3, -- Linewise reg/motion
    SB = 6, -- Single line block reg/motion
    MB = 7, -- Multi-line block reg/motion
}

--- @class mtypeOpts
--- @field regtype string
--- @field lines? string[]
--- @field marks? op_marks

--- @param opts mtypeOpts
--- @return integer
--- Returns -1 on error
local function get_mtype(opts)
    opts = opts or {}

    local has_range = opts.lines or opts.marks
    local has_regtype = opts.regtype
    if not (has_range and has_regtype) then
        return -1
    end

    local multiline = (function()
        if opts.lines and #opts.lines > 1 then
            return true
        elseif opts.marks and opts.marks.start.row ~= opts.marks.fin.row then
            return true
        else
            return false
        end
    end)() --- @type boolean

    if opts.regtype == "V" then
        return mtype.L
    elseif (not multiline) and opts.regtype == "v" then
        return mtype.SC
    elseif multiline and opts.regtype == "v" then
        return mtype.MC
    elseif (not multiline) and opts.regtype:sub(1, 1) == "\22" then
        return mtype.SB
    elseif multiline and opts.regtype:sub(1, 1) == "\22" then
        return mtype.MB
    end

    return -1
end

--- @param marks op_marks
--- @param lines string[]
--- @return op_marks|nil, string|nil
--- Assumes that the row marks have been checked beforehand
local function op_set_text(marks, lines)
    local start_row = marks.start.row --- @type integer
    local start_col = marks.start.col --- @type integer
    local fin_row = marks.fin.row --- @type integer
    local fin_col = marks.fin.col --- @type integer
    local fin_line = vim.api.nvim_buf_get_lines(0, fin_row - 1, fin_row, false)[1] --- @type string

    --- @type integer|nil, integer|nil, string|nil
    local _, fin_byte, bb_err = blk_utils.byte_bounds_from_col(fin_line, fin_col)
    if (not fin_byte) or bb_err then
        return nil, "op_set_text: " .. (bb_err or "Unknown error in byte_bounds_from_col")
    end
    fin_byte = #fin_line > 0 and fin_byte + 1 or 0

    vim.api.nvim_buf_set_text(0, start_row - 1, start_col, fin_row - 1, fin_byte, lines)

    local new_fin_row = start_row + #lines - 1 --- @type integer
    local move_start = #lines[1] == 0 and #lines > 1 --- @type boolean
    start_row = move_start and start_row + 1 or start_row
    start_col = move_start and 0 or start_col

    local fin_line_len = #lines[#lines] --- @type integer
    local can_move_fin = #lines > 1 and #lines[#lines - 1] > 0 --- @type boolean
    local should_move_fin = fin_line_len == 0 and can_move_fin --- @type boolean
    new_fin_row = should_move_fin and new_fin_row - 1 or new_fin_row
    fin_line_len = should_move_fin and #lines[#lines - 1] or fin_line_len

    local new_fin_byte = #lines == 1 and fin_line_len + start_col or fin_line_len --- @type integer
    new_fin_byte = new_fin_byte > 0 and new_fin_byte - 1 or 0
    --- @type string
    local new_fin_line = vim.api.nvim_buf_get_lines(0, new_fin_row - 1, new_fin_row, false)[1]

    --- @type integer|nil, integer|nil, string|nil
    local new_fin_col, _, f_err = blk_utils.byte_bounds_from_col(new_fin_line, new_fin_byte)
    if (not new_fin_col) or f_err then
        return nil, "op_set_text: " .. (f_err or "Unknown error in byte_bounds_from_col")
    end

    local post_marks = {
        start = { row = start_row, col = start_col },
        fin = { row = new_fin_row, col = new_fin_col },
    } --- @type op_marks

    vim.api.nvim_buf_set_mark(0, "[", post_marks.start.row, post_marks.start.col, {})
    vim.api.nvim_buf_set_mark(0, "]", post_marks.fin.row, post_marks.fin.col, {})
    return post_marks, nil
end

--- @param marks op_marks
--- @param lines string[]
--- @return op_marks|nil, string|nil
local function op_set_lines_into_chars(marks, lines)
    table.insert(lines, 1, "")
    table.insert(lines, "")

    return op_set_text(marks, lines)
end

--- @param marks op_marks
--- @param lines string[]
--- @return op_marks|nil, string|nil
--- Assumes that the row marks have been checked beforehand
local function op_set_lines(marks, lines)
    local start_row = marks.start.row
    local fin_row = marks.fin.row

    vim.api.nvim_buf_set_lines(0, start_row - 1, fin_row, false, lines)

    local new_fin_row = start_row + #lines - 1
    local fin_line = lines[#lines]
    local fin_line_len_byte = #fin_line - 1

    --- @type integer|nil, integer|nil, string|nil
    local new_fin_col, _, f_err = blk_utils.byte_bounds_from_col(fin_line, fin_line_len_byte)
    if (not new_fin_col) or f_err then
        return nil, "op_set_text: " .. (f_err or "Unknown error in byte_bounds_from_col")
    end

    local new_start_col = 0
    local post_marks = {
        start = { row = start_row, col = new_start_col },
        fin = { row = new_fin_row, col = new_fin_col },
    }

    vim.api.nvim_buf_set_mark(0, "[", post_marks.start.row, post_marks.start.col, {})
    vim.api.nvim_buf_set_mark(0, "]", post_marks.fin.row, post_marks.fin.col, {})

    return post_marks, nil
end

--- @param text string
--- @param marks op_marks
--- @param regtype string
--- @param motion string
--- @param vcount integer
--- @param curswant integer
--- @return op_marks|nil, string|nil
function M.do_set(text, marks, regtype, motion, vcount, curswant)
    if not text then
        return nil, "do_set: No set text provided"
    end

    if not marks then
        return nil, "do_set: No marks provided to set to"
    end
    if marks.start.row > marks.fin.row then
        return nil, "do_set: Start row " .. marks.start.row .. " > " .. marks.fin.row
    end

    if not regtype then
        regtype = text:sub(-1) == "\n" and "V" or "v"
    end
    if not utils.is_valid_regtype(regtype) then
        return nil, "do_set: regtype " .. regtype .. " is invalid"
    end

    local set_lines = op_utils.setup_text_lines({
        motion = motion,
        regtype = regtype,
        text = text,
        vcount = vcount,
    })
    local reg_mtype = get_mtype({ lines = set_lines, regtype = regtype })
    if reg_mtype == -1 then
        local inspected = vim.insepct(set_lines)
        local err = "No motion type for regtype " .. regtype .. " and lines " .. inspected
        return nil, "do_set: " .. err
    end

    local vmotion = utils.regtype_from_motion(motion)
    local motion_mtype = get_mtype({ marks = marks, regtype = vmotion })
    if reg_mtype == -1 then
        local inspected = vim.insepct(marks)
        local err = "No motion type for regtype " .. regtype .. " and marks " .. inspected
        return nil, "do_set: " .. err
    end

    local char_mtypes = { mtype.SC, mtype.MC, mtype.SB }
    local char_reg = vim.tbl_contains(char_mtypes, reg_mtype)
    local char_motion = vim.tbl_contains(char_mtypes, motion_mtype)
    local block_reg = vim.tbl_contains({ mtype.SB, mtype.MB }, reg_mtype)
    local block_motion = vim.tbl_contains({ mtype.SB, mtype.MB }, motion_mtype)

    if char_reg and char_motion then
        return op_set_text(marks, set_lines)
    elseif motion_mtype == mtype.L then
        return op_set_lines(marks, set_lines)
    elseif reg_mtype == mtype.L and vim.tbl_contains({ mtype.SC, mtype.MC }, motion_mtype) then
        return op_set_lines_into_chars(marks, set_lines)
    elseif block_reg and (block_motion or motion_mtype == mtype.SC) then
        return op_utils.op_set_block(marks, curswant, set_lines)
    elseif reg_mtype == mtype.L and block_motion then
        local del_marks, err = op_utils.op_set_block(marks, curswant)
        if not del_marks or err then
            return nil, "do_set: " .. (err or "Unknown error in op_set_block")
        end

        return op_utils.paste_lines(del_marks.start.row, true, set_lines)
    elseif reg_mtype == mtype.SC and motion_mtype == mtype.MB then
        -- TODO: Built-in behavior places marks only on the first row. I am currently placing
        -- on the whole area
        -- Though one boarder note is, if we're going to support yank cycling, the marks have to
        -- support it. The default here, for example, would not. So would need a way to feed
        -- mark schemes to the functions
        local rows = marks.fin.row - marks.start.row + 1
        local block_lines = op_utils.setup_text_lines({
            motion = "line",
            regtype = "V",
            text = set_lines[1],
            vcount = rows,
        })

        return op_utils.op_set_block(marks, curswant, block_lines)
    elseif reg_mtype == mtype.MC and motion_mtype == mtype.MB then
        local del_marks, err = op_utils.op_set_block(marks, curswant)
        if not del_marks or err then
            return nil, "do_set: " .. (err or "Unknown error in op_set_block")
        end

        return op_utils.paste_chars({ del_marks.start.row, del_marks.start.col }, true, set_lines)
    elseif reg_mtype == mtype.MB and motion_mtype == mtype.MC then
        local del_marks, err = op_utils.del_chars(marks)
        if not del_marks or err then
            return nil, "do_set: " .. (err or "Unknown error in op_set_block")
        end

        return paste_utils.paste_block({
            cur_pos = {
                del_marks.start.row,
                del_marks.start.col,
            },
            before = true,
            lines = set_lines,
        })
    end

    return nil, "do_set: Unable to find a valid set function"
end

return M
