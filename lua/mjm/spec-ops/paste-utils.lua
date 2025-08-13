local blk_utils = require("mjm.spec-ops.block-utils")
local op_utils = require("mjm.spec-ops.op-utils")

local M = {}

--- @param text string
--- @param vcount integer
--- @param regtype string
--- @return string[]
function M.get_paste_lines(text, vcount, regtype)
    if text == "" then
        return {}
    end

    local type = regtype:sub(1, 1)

    if type == "v" and vcount > 1 then
        text = string.rep(text, vcount)
    end

    local lines = vim.split(text:gsub("\n$", ""), "\n") ---@type string[]

    if type == "V" and vcount > 1 then
        local ext_count = vcount - 1
        local orig_lines = vim.deepcopy(lines, true)
        for _ = 1, ext_count do
            vim.list_extend(lines, orig_lines)
        end
    elseif type == "\22" and vcount > 1 then
        for i, l in ipairs(lines) do
            lines[i] = string.rep(l, vcount)
        end
    end

    return lines
end

--- @param cur_pos {[1]: integer, [2]: integer}
--- @param before boolean
--- @param lines string[]
--- @return op_marks|nil, string|nil
local function paste_chars(cur_pos, before, lines)
    local row, col = unpack(cur_pos)

    if not before then
        local start_line = vim.api.nvim_buf_get_lines(0, row - 1, row, false)[1]
        local _, fin_byte, bb_err = blk_utils.byte_bounds_from_col(start_line, col)
        if (not fin_byte) or bb_err then
            return nil, "paste chars: " .. (bb_err or "Unknown error in byte_bounds_from_col")
        end

        col = math.min(#start_line, fin_byte + 1)
    end

    vim.api.nvim_buf_set_text(0, row - 1, col, row - 1, col, lines)

    local fin_row = row + #lines - 1
    local len_last = string.len(lines[#lines])
    local fin_col = #lines == 1 and len_last + col - 1 or len_last - 1

    local fin_line = vim.api.nvim_buf_get_lines(0, fin_row - 1, fin_row, false)[1]
    local start_byte, _, bb_err = blk_utils.byte_bounds_from_col(fin_line, fin_col)
    if (not start_byte) or bb_err then
        return nil, "paste chars: " .. (bb_err or "Unknown error in byte_bounds_from_col")
    end
    fin_col = start_byte

    vim.api.nvim_buf_set_mark(0, "[", row, col, {})
    vim.api.nvim_buf_set_mark(0, "]", fin_row, fin_col, {})

    return {
        start = {
            row = row,
            col = col,
        },
        fin = {
            row = fin_row,
            col = fin_col,
        },
    }
end

-- TODO: do_block_ops can be used to paste the rows

--- @param row integer
--- @param lines string[]
--- @param target_vcol integer
--- @return op_marks|nil, string|nil
local function norm_paste_block_callback(row, lines, target_vcol, blk_width)
    local paste_info = {} --- @type block_op_info[]
    local total_rows = vim.api.nvim_buf_line_count(0)

    for i, line in ipairs(lines) do
        local row_1 = row + i - 1 --- @type integer
        if row_1 > total_rows then
            local new_line = string.rep(" ", target_vcol)
            vim.api.nvim_buf_set_lines(0, total_rows, total_rows, false, { new_line })
            total_rows = total_rows + 1
        end

        --- @type string
        local buf_line = vim.api.nvim_buf_get_lines(0, row_1 - 1, row_1, false)[1]

        --- @type block_op_info|nil, string|nil
        local info, err = op_utils.get_block_paste_row(target_vcol, line, buf_line, blk_width)
        if (not info) or err then
            err = err or "Unknown error in get_norm_block_paste_info"
            return nil, "norm_paste_block_callback: " .. err
        end

        table.insert(paste_info, info)
    end

    if #paste_info ~= #lines then
        --- @type string
        local err = "#paste_info (" .. #paste_info .. ") ~= #lines (" .. #lines .. ")"
        return nil, "norm_paste_block_callback: " .. err
    end

    local marks = { start = {}, fin = {} } --- @type op_marks
    for i, p in ipairs(paste_info) do
        local row_1 = row + i - 1 --- @type integer
        local row_0 = row_1 - 1 --- @type integer
        local byte = p.start_byte --- @type integer
        local line = p.text --- @type string

        vim.api.nvim_buf_set_text(0, row_0, byte, row_0, byte, { line })

        if i == 1 then
            marks.start.row = row_1
            marks.start.col = byte
        end

        if i == #paste_info then
            marks.fin.row = row_1
            marks.fin.col = byte + #line - 1
        end
    end

    vim.api.nvim_buf_set_mark(0, "[", marks.start.row, marks.start.col, {})
    vim.api.nvim_buf_set_mark(0, "]", marks.fin.row, marks.fin.col, {})
    return marks
end

--- @return op_marks|nil, string|nil
local function norm_paste_block(opts)
    opts = opts or {}
    local cur_pos = opts.cur_pos or vim.api.nvim_win_get_cursor(0)
    local before = opts.before or false

    if not opts.lines then
        return nil, "Nothing to paste"
    end
    local lines = opts.lines

    local row, col = unpack(cur_pos) --- @type integer, integer
    local start_line = vim.api.nvim_buf_get_lines(0, row - 1, row, false)[1] --- @type string

    --- @type integer|nil, integer|nil, string|nil
    local start_vcol, fin_vcol, vcol_err = blk_utils.vcols_from_col(start_line, col)
    if (not start_vcol) or not fin_vcol or vcol_err then
        return nil, "norm_paste_block: " .. (vcol_err or "Unknown error in vcols_from_col")
    end

    local paste_vcol = before and math.max(start_vcol - 1, 0) or fin_vcol --- @type integer
    local width = blk_utils.get_block_reg_width(lines)
    return norm_paste_block_callback(row, lines, paste_vcol, width)
end

--- @return op_marks|nil, string|nil
function M.do_norm_paste(opts)
    opts = opts or {}

    opts.regtype = opts.regtype or "v"
    opts.lines = (function()
        if opts.lines then
            return opts.lines
        elseif opts.text then
            return M.get_paste_lines(opts.text, opts.vcount or 0, opts.regtype)
        else
            return nil
        end
    end)()
    if not opts.lines then
        return nil, "No lines to paste in op_paste"
    end

    opts.cur_pos = opts.cur_pos or vim.api.nvim_win_get_cursor(0)
    opts.before = opts.before or false

    if opts.regtype == "v" then
        return paste_chars(opts.cur_pos, opts.before, opts.lines)
    elseif opts.regtype == "V" then
        return op_utils.paste_lines(opts.cur_pos[1], opts.before, opts.lines)
    else
        return norm_paste_block({
            cur_pos = opts.cur_pos,
            lines = opts.lines,
            before = opts.before,
        })
    end
end

--- @return nil
function M.adj_paste_cursor_default(opts)
    opts = opts or {}
    if not opts.marks then
        return
    end

    opts.regtype = opts.regtype or "v"

    --- @type boolean
    local is_multi_line_char = opts.regtype == "v" and opts.marks.start.row ~= opts.marks.fin.row
    local is_block = opts.regtype:sub(1, 1) == "\22" --- @type boolean
    if is_multi_line_char or is_block then
        vim.api.nvim_win_set_cursor(0, { opts.marks.start.row, opts.marks.start.col })
    elseif opts.regtype == "V" then
        local start_row = opts.marks.start.row --- @type integer
        --- @type string
        local line = vim.api.nvim_buf_get_lines(0, start_row - 1, start_row, false)[1]
        local first_char = string.find(line, "[^%s]") or 1 --- @type integer
        vim.api.nvim_win_set_cursor(0, { opts.marks.start.row, first_char - 1 })
    else
        vim.api.nvim_win_set_cursor(0, { opts.marks.fin.row, opts.marks.fin.col })
    end
end

return M
