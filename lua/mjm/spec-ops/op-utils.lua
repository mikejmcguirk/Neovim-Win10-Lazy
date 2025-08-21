local blk_utils = require("mjm.spec-ops.block-utils")
local utils = require("mjm.spec-ops.utils")

local M = {}

-- TODO: This should be flatter. Use "pre" for anything done in the operator, then post for
-- anything after the change/yank happens
-- Store register in op_state since vim.v.register is clobbered by some text objects

--- @class op_pre
--- @field data any
--- @field op_type "y"|"c"|"p"|"d"
--- @field reg string|nil
--- @field reg_handler fun( ctx: reg_handler_ctx): string[]
--- @field view vim.fn.winsaveview.ret
--- @field vmode boolean

--- @class op_post
--- @field data any
--- @field lines string[]
--- @field marks op_marks
--- @field marks_after op_marks
--- @field motion string
--- @field reg string|nil
--- @field reg_info reg_info[]
--- @field view vim.fn.winsaveview.ret
--- @field vmode boolean

--- @class op_state
--- @field pre op_pre
--- @field post op_post
--- @field start_line_post string
--- @field fin_line_post string

--- @param reg_handler fun( ctx: reg_handler_ctx): string[]
--- @param op_type "y"|"c"|"p"|"d"
--- @return op_state
function M.get_new_op_state(reg_handler, op_type)
    return {
        pre = {
            op_type = op_type,
            reg = nil,
            reg_handler = reg_handler,
            view = nil,
            vmode = false,
        },
        post = {
            view = nil,
            vmode = false,
            reg = nil,
        },
    }
end

--- @param op_state op_state
--- @return nil
function M.set_op_state_post(op_state, motion)
    local pre = op_state.pre
    local post = op_state.post

    post.vmode = pre.vmode
    pre.vmode = false

    post.motion = motion
    post.marks = utils.get_marks(post.motion, post.vmode)

    if pre.view then
        post.view = pre.view

        if (not post.vmode) and motion == "block" then
            vim.cmd("norm! gv")
            post.view.curswant = vim.fn.winsaveview().curswant
            vim.cmd("norm! \27")

            vim.api.nvim_win_set_cursor(0, { post.view.lnum, post.view.col })
        end
    else
        local old_curswant = post.view.curswant

        post.view = vim.fn.winsaveview()
        if old_curswant == vim.v.maxcol then
            post.view.curswant = vim.v.maxcol
        end
    end

    pre.view = nil

    -- NOTE: This will be validated later in reg handler
    post.reg = pre.reg or post.reg
    post.reg_info = nil
    pre.reg = nil
end

--- @param op_state op_state
function M.cleanup_op_state(op_state)
    op_state.post.lines = nil
    op_state.post.marks = nil
    op_state.post.marks_after = nil
    op_state.post.motion = nil
    op_state.start_line_post = nil
    op_state.fin_line_post = nil
    -- Keep reg for dot-repeat
    -- Keep view for dot repeat
    -- vmode will take the false value from op_state.pre
end

--- @return boolean
local function is_vmode()
    local short_mode = string.sub(vim.fn.mode(), 1, 1)

    if short_mode == "v" or short_mode == "V" or short_mode == "\22" then
        return true
    else
        return false
    end
end

function M.set_op_state_pre(op_state)
    op_state.pre.view = vim.fn.winsaveview()
    op_state.pre.reg = vim.v.register
    op_state.pre.vmode = is_vmode()
end

--- @class SetupTextLineOpts
--- @field motion string
--- @field regtype string
--- @field text string
--- @field vcount integer

--- @param opts SetupTextLineOpts
--- @return string[]
function M.setup_text_lines(opts)
    opts = opts or {}
    if not type(opts.text) == "string" then
        return { "" }
    end

    local short_regtype = opts.regtype:sub(1, 1) or "v"
    opts.vcount = opts.vcount or 1
    opts.motion = opts.motion or "char"

    local is_linewise = short_regtype == "V" or opts.motion == "line"

    if short_regtype == "v" and opts.vcount > 1 and not is_linewise then
        opts.text = string.rep(opts.text, opts.vcount)
    end

    local lines = vim.split(opts.text:gsub("\n$", ""), "\n") ---@type string[]

    if is_linewise and opts.vcount > 1 then
        local ext_count = opts.vcount - 1
        local orig_lines = vim.deepcopy(lines, true)
        for _ = 1, ext_count do
            vim.list_extend(lines, orig_lines)
        end
    elseif short_regtype == "\22" and opts.vcount > 1 and not is_linewise then
        for i, l in ipairs(lines) do
            lines[i] = string.rep(l, opts.vcount)
        end
    end

    return lines
end

--- @param marks op_marks
--- @return  op_marks|nil, string|nil
function M.del_chars(marks)
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

--- @param cur_pos {[1]: integer, [2]: integer}
--- @param before boolean
--- @param lines string[]
--- @return op_marks|nil, string|nil
function M.paste_chars(cur_pos, before, lines)
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

--- @param row integer
--- @param before boolean
--- @param lines string[]
--- @return op_marks|nil, string|nil
function M.paste_lines(row, before, lines)
    row = before and row - 1 or row

    vim.api.nvim_buf_set_lines(0, row, row, false, lines)

    local start_row = row + 1
    local start_col = 0
    local fin_row = row + #lines
    local fin_col = #vim.api.nvim_buf_get_lines(0, fin_row - 1, fin_row, false)[1] - 1

    local fin_line = vim.api.nvim_buf_get_lines(0, fin_row - 1, fin_row, false)[1]
    local start_byte, _, bb_err = blk_utils.byte_bounds_from_col(fin_line, fin_col)
    if (not start_byte) or bb_err then
        return nil, "paste lines: " .. (bb_err or "Unknown error in byte_bounds_from_col")
    end
    fin_col = start_byte

    vim.api.nvim_buf_set_mark(0, "[", start_row, start_col, {})
    vim.api.nvim_buf_set_mark(0, "]", fin_row, fin_col, {})

    return {
        start = {
            row = start_row,
            col = start_col,
        },
        fin = {
            row = fin_row,
            col = fin_col,
        },
    },
        nil
end

--- @class block_op_info
--- @field start_byte integer
--- @field fin_byte_ex integer
--- @field text string
--- @field l_vcol integer
--- @field r_vcol integer

--- @param set_line string|nil
--- @param l_vcol integer
--- @param r_vcol integer
--- @param blk_width integer
--- @param buf_line string
--- @param max_curswant boolean
--- @return block_op_info|nil, string|nil
local function get_block_set_row(set_line, l_vcol, r_vcol, blk_width, buf_line, max_curswant)
    local max_vcol = vim.fn.strdisplaywidth(buf_line) --- @type integer
    local target_l_vcol = math.min(l_vcol, max_vcol) --- @type integer

    if target_l_vcol < max_vcol and set_line then
        local pad_len = math.max(blk_width - vim.fn.strdisplaywidth(set_line), 0)
        set_line = pad_len > 0 and set_line .. string.rep(" ", pad_len) or set_line
    elseif set_line then
        set_line = set_line:gsub("%s+$", "")
    else
        set_line = ""
    end

    --- @type integer|nil, integer|nil, string|nil
    local this_l_vcol, _, l_err = blk_utils.vcols_from_vcol(buf_line, target_l_vcol)
    if (not this_l_vcol) or l_err then
        return nil, "get_block_set_row: " .. (l_err or "Unknown error in vcols_from_vcol")
    end

    --- @type integer|nil, integer|nil, string|nil
    local l_byte, _, lb_err = blk_utils.byte_bounds_from_vcol(buf_line, this_l_vcol)
    if (not l_byte) or lb_err then
        return nil, "get_block_set_row: " .. (lb_err or "Unknown error in byte_bounds_from_vcol")
    end

    local target_r_vcol = math.min(r_vcol, max_vcol) --- @type integer
    target_r_vcol = max_curswant and max_vcol or target_r_vcol

    --- @type integer|nil, integer|nil, string|nil
    local _, this_r_vcol, r_err = blk_utils.vcols_from_vcol(buf_line, target_r_vcol)
    if (not this_r_vcol) or r_err then
        return nil, "get_block_set_row: " .. (r_err or "Unknown error in vcols_from_vcol")
    end

    --- @type integer|nil, integer|nil, string|nil
    local _, r_byte, rb_err = blk_utils.byte_bounds_from_vcol(buf_line, this_r_vcol)
    if (not r_byte) or rb_err then
        return nil, "get_block_set_row: " .. (rb_err or "Unknown error in byte_bounds_from_vcol")
    end

    r_byte = #buf_line > 0 and r_byte + 1 or 0
    if l_byte > r_byte then
        return nil, "get_block_set_row: l_byte (" .. l_byte .. ") > r_byte (" .. r_byte .. ")"
    end

    local l_pad_len = target_l_vcol - this_l_vcol --- @type integer
    local r_pad_len = this_r_vcol - target_r_vcol --- @type integer
    local l_padding = string.rep(" ", (l_pad_len > 0 and l_pad_len or 0)) --- @type string
    local r_padding = string.rep(" ", (r_pad_len > 0 and r_pad_len or 0)) --- @type string
    set_line = l_padding .. set_line .. r_padding

    return { start_byte = l_byte, fin_byte_ex = r_byte, text = set_line }
end

--- @param target_vcol integer
--- @param paste_line string
--- @param buf_line string
--- @param blk_width integer
--- @return block_op_info|nil, string|nil
function M.get_block_paste_row(target_vcol, paste_line, buf_line, blk_width)
    local max_vcol = vim.fn.strdisplaywidth(buf_line) --- @type integer
    local paste_vcol = math.min(max_vcol, target_vcol) --- @type integer

    if paste_vcol < max_vcol then
        local pad_len = blk_width - vim.fn.strdisplaywidth(paste_line) --- @type integer
        pad_len = math.max(pad_len, 0)
        paste_line = pad_len > 0 and paste_line .. string.rep(" ", pad_len) or paste_line
    else
        paste_line = paste_line:gsub("%s+$", "")
    end

    --- @type integer|nil, integer|nil, string|nil
    local start_vcol, fin_vcol, vcol_err = blk_utils.vcols_from_vcol(buf_line, paste_vcol)
    if (not start_vcol) or not fin_vcol or vcol_err then
        return nil, "get_block_paste_row: " .. (vcol_err or "Unknown error in vcols_from_vcol")
    end

    if paste_vcol < target_vcol then
        paste_line = string.match(paste_line, "%S") and paste_line or ""
        paste_line = string.rep(" ", target_vcol - paste_vcol) .. paste_line
    elseif fin_vcol > paste_vcol then
        paste_line = string.rep(" ", paste_vcol - start_vcol + 1) .. paste_line
    end

    local paste_byte, err = (function()
        if fin_vcol > paste_vcol then
            local start_byte, _, bb_err = blk_utils.byte_bounds_from_vcol(buf_line, start_vcol)
            return start_byte, bb_err
        else
            local _, fin_byte, bb_err = blk_utils.byte_bounds_from_vcol(buf_line, fin_vcol)
            return fin_byte, bb_err
        end
    end)() --- @type integer|nil, string|nil

    if (not paste_byte) or err then
        return nil, "get_block_paste_row: " .. (err or "Unknown error in byte_bounds_from_col")
    end

    if fin_vcol <= paste_vcol then
        paste_byte = paste_vcol > 0 and paste_byte + 1 or 0
    end

    return { start_byte = paste_byte, fin_byte_ex = paste_byte, text = paste_line }
end

--- @param blk_ops block_op_info[]
--- @param marks op_marks
--- @param opts? {mark_type: string}
--- @return op_marks|nil, string|nil
local function do_block_ops(blk_ops, marks, opts)
    opts = opts or {}

    local start_row = marks.start.row --- @type integer
    local post_marks = { start = {}, fin = {} } --- @type op_marks

    for i, o in pairs(blk_ops) do
        local row_1 = start_row + i - 1 --- @type integer
        local row_0 = row_1 - 1 --- @type integer
        vim.api.nvim_buf_set_text(0, row_0, o.start_byte, row_0, o.fin_byte_ex, { o.text })

        if i == 1 then
            --- @type string
            local start_line = vim.api.nvim_buf_get_lines(0, row_0, row_1, false)[1]
            --- @type integer
            local start_byte = math.min(o.start_byte, #start_line - 1)
            start_byte = math.max(start_byte, 0)

            --- @type integer|nil, integer|nil, string|nil
            local l_byte, _, err = blk_utils.byte_bounds_from_col(start_line, start_byte)
            if (not l_byte) or err then
                return nil, "do_block_ops: " .. (err or "Unknown error in byte_bounds_from_col")
            end

            post_marks.start.row = row_1
            post_marks.start.col = l_byte
        end

        if opts.mark_type == "change" and i > 1 then
            local cur_line = vim.api.nvim_buf_get_lines(0, row_0, row_1, false)[1]
            local cur_line_len = math.max(#cur_line - 1, 0)
            post_marks.start.col = math.min(post_marks.start.col, cur_line_len)
        end

        if opts.mark_type == "delete" and i == #blk_ops then
            --- @type string
            local fin_line = vim.api.nvim_buf_get_lines(0, row_0, row_1, false)[1]
            local fin_byte = math.min(post_marks.start.col, #fin_line - 1) --- @type integer
            fin_byte = math.max(fin_byte, 0)

            --- @type integer|nil, integer|nil, string|nil
            local l_byte, _, err = blk_utils.byte_bounds_from_col(fin_line, fin_byte)
            if (not l_byte) or err then
                return nil, "do_block_ops: " .. (err or "Unknown error in byte_bounds_from_col")
            end

            post_marks.fin.row = row_1
            post_marks.fin.col = l_byte
        elseif opts.mark_type == "change" and i == #blk_ops then
            local start_line =
                vim.api.nvim_buf_get_lines(0, marks.start.row - 1, marks.start.row, false)[1]

            --- @type integer|nil, integer|nil, string|nil
            local target_vcol, _, vcol_err =
                blk_utils.vcols_from_col(start_line, post_marks.start.col)
            if (not target_vcol) or vcol_err then
                return nil, "do_block_ops" .. (vcol_err or "Unknown error in vcols_from_col")
            end

            local fin_line = vim.api.nvim_buf_get_lines(0, row_0, row_1, false)[1]
            local max_vcol = vim.fn.strdisplaywidth(fin_line)
            target_vcol = math.min(target_vcol, max_vcol)

            --- @type integer|nil, integer|nil, string|nil
            local l_byte, _, bb_err = blk_utils.byte_bounds_from_vcol(fin_line, target_vcol)
            if (not l_byte) or bb_err then
                return nil, "do_block_ops" .. (bb_err or "Unknown error in vcols_from_col")
            end

            post_marks.fin.row = row_1
            post_marks.fin.col = l_byte
        else
            post_marks.fin.row = row_1
            post_marks.fin.col = math.max(o.start_byte + #o.text - 1, 0)
        end
    end

    vim.api.nvim_buf_set_mark(0, "[", post_marks.start.row, post_marks.start.col, {})
    vim.api.nvim_buf_set_mark(0, "]", post_marks.fin.row, post_marks.fin.col, {})
    return post_marks, nil
end

--- @param marks op_marks
--- @param curswant integer
--- @param opts? {lines: string[], is_change: boolean}
--- @return op_marks|nil, string|nil
--- Assumes that the row marks have been checked beforehand
function M.op_set_block(marks, curswant, opts)
    opts = opts or {}
    opts.lines = opts.lines or {}

    --- @type string[]
    local buf_lines = vim.api.nvim_buf_get_lines(0, marks.start.row - 1, marks.fin.row, false)

    --- @type integer|nil, integer|nil, string|nil
    local l_vcol, r_vcol, vcol_err = blk_utils.vcols_from_marks(buf_lines, marks)
    if (not l_vcol) or not r_vcol or vcol_err then
        return nil, "op_set_block: " .. vcol_err
    end

    local max_iter = math.max(#buf_lines, #opts.lines) --- @type integer
    local total_rows = vim.api.nvim_buf_line_count(0) --- @type integer
    local mc = curswant and curswant == vim.v.maxcol --- @type boolean
    local width = blk_utils.get_block_width(opts.lines) --- @type integer
    local set_info = {} --- @type block_op_info[]

    for i = 1, max_iter do
        local row_1 = marks.start.row + i - 1 --- @type integer
        local set_line = opts.lines[i] or nil --- @type string|nil

        local info, err = (function()
            if i <= #opts.lines and i > #buf_lines and set_line then
                local target_vcol = l_vcol - 1 --- @type integer
                local buf_line = (function()
                    if row_1 > total_rows then
                        local new_line = string.rep(" ", target_vcol) --- @type string
                        vim.api.nvim_buf_set_opts.lines(
                            0,
                            total_rows,
                            total_rows,
                            false,
                            { new_line }
                        )

                        total_rows = total_rows + 1
                        return new_line
                    end

                    return vim.api.nvim_buf_get_lines(0, row_1 - 1, row_1, false)[1]
                end)() --- @type string

                return M.get_block_paste_row(target_vcol, set_line, buf_line, width)
            else
                local buf_line = buf_lines[i]
                return get_block_set_row(set_line, l_vcol, r_vcol, width, buf_line, mc)
            end
        end)() --- @type block_op_info|nil, string|nil

        if (not info) or err then
            return nil, "op_set_block: " .. (err or "Unknown error getting block op info")
        end

        table.insert(set_info, info)
    end

    if opts.is_change then
        return do_block_ops(set_info, marks, { mark_type = "change" })
    elseif #opts.lines == 0 then
        return do_block_ops(set_info, marks, { mark_type = "delete" })
    else
        return do_block_ops(set_info, marks)
    end
end

return M
