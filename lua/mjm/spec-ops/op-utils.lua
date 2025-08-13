local blk_utils = require("mjm.spec-ops.block-utils")
local utils = require("mjm.spec-ops.utils")

--- @class block_op_info
--- @field start_byte integer
--- @field fin_byte_ex integer
--- @field text string

-- Store register in op_state since vim.v.register is clobbered by some text objects
-- TODO: Check in delete function if I need to store count here

--- @class op_state
--- @field reg string|nil
--- @field view vim.fn.winsaveview.ret|nil
--- @field vmode boolean

local M = {}

--- @return boolean
local function is_virtual_mode()
    local short_mode = string.sub(vim.fn.mode(), 1, 1)

    if short_mode == "v" or short_mode == "V" or short_mode == "\22" then
        return true
    else
        return false
    end
end

--- @param op_state op_state
--- @return nil
function M.update_op_state(op_state)
    op_state.view = vim.fn.winsaveview()
    op_state.reg = vim.v.register
    op_state.vmode = is_virtual_mode()
end

--- @param op_state op_state
--- @param cb_state op_state
--- @param motion string
--- @return nil
function M.update_cb_from_op(op_state, cb_state, motion)
    cb_state.vmode = op_state.vmode
    op_state.vmode = false

    if op_state.view then
        cb_state.view = op_state.view

        if (not cb_state.vmode) and motion == "block" then
            vim.cmd("norm! gv")
            cb_state.view.curswant = vim.fn.winsaveview().curswant
            vim.cmd("norm! \27")

            vim.api.nvim_win_set_cursor(0, { cb_state.view.lnum, cb_state.view.col })
        end
    else
        local old_curswant = cb_state.view.curswant

        cb_state.view = vim.fn.winsaveview()
        if old_curswant == vim.v.maxcol then
            cb_state.view.curswant = vim.v.maxcol
        end
    end

    op_state.view = nil

    if utils.is_valid_register(op_state.reg) then
        --- @diagnostic disable: cast-local-type -- Checked by is_valid_register
        cb_state.reg = op_state.reg
    elseif not utils.is_valid_register(cb_state.reg) then
        cb_state.reg = utils.get_default_reg()
    end

    op_state.reg = nil
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
    if not type(opts.text) == "table" then
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

-- TODO: Have the delete op use this

--- @param set_line string|nil
--- @param l_vcol integer
--- @param r_vcol integer
--- @param blk_width integer
--- @param buf_line string
--- @param max_curswant boolean
--- @return block_op_info|nil, string|nil
function M.get_block_set_row(set_line, l_vcol, r_vcol, blk_width, buf_line, max_curswant)
    local max_vcol = vim.fn.strdisplaywidth(buf_line) --- @type integer
    local target_l_vcol = math.min(l_vcol, max_vcol) --- @type integer
    if target_l_vcol < max_vcol and set_line then
        local pad_len = math.max(blk_width - vim.fn.strdisplaywidth(set_line), 0)
        set_line = set_line .. string.rep(" ", pad_len)
    elseif set_line then
        set_line = set_line:gsub("%s+$", "")
    else
        set_line = ""
    end

    --- @type integer|nil, integer|nil, string|nil
    local this_l_vcol, _, l_err = blk_utils.vcols_from_vcol(buf_line, target_l_vcol)
    if (not this_l_vcol) or l_err then
        local err = l_err or "Unknown error in vcols_from_vcol"
        return nil, "get_block_set_row: " .. err
    end

    local target_r_vcol = math.min(r_vcol, max_vcol) --- @type integer
    target_r_vcol = max_curswant and max_vcol or target_r_vcol

    --- @type integer|nil, integer|nil, string|nil
    local _, this_r_vcol, r_err = blk_utils.vcols_from_vcol(buf_line, target_r_vcol)
    if (not this_r_vcol) or r_err then
        local err = r_err or "Unknown error in vcols_from_vcol"
        return nil, "get_block_set_row: " .. err
    end

    --- @type integer|nil, integer|nil, string|nil
    local l_byte, _, lb_err = blk_utils.byte_bounds_from_vcol(buf_line, this_l_vcol)
    if (not l_byte) or lb_err then
        local err = lb_err or "Unknown error in byte_bounds_from_vcol"
        return nil, "get_block_set_row: " .. err
    end

    --- @type integer|nil, integer|nil, string|nil
    local _, r_byte, rb_err = blk_utils.byte_bounds_from_vcol(buf_line, this_r_vcol)
    if (not r_byte) or rb_err then
        local err = rb_err or "Unknown error in byte_bounds_from_vcol"
        return nil, "get_block_set_row: " .. err
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

-- TODO: Long function
-- MAYBE: Create a function to validate that a collection of lines is a set of valid block lines

--- @param blk_ops block_op_info[]
--- @param marks Marks
--- @param opts? {set_del_marks: boolean}
--- @return Marks|nil, string|nil
function M.do_block_ops(blk_ops, marks, opts)
    vim.validate("blk_ops", blk_ops, "table")
    vim.validate("marks", marks, "table")
    opts = opts or {}
    vim.validate("opts", opts, "table", true)

    local start_row = marks.start.row --- @type integer
    --- @diagnostic disable: missing-fields
    local post_marks = {} --- @type Marks
    local post_fin_row = start_row --- @type integer
    local post_fin_col = marks.start.col --- @type integer

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
            local l_byte, _, bb_err = blk_utils.byte_bounds_from_col(start_line, start_byte)
            if (not l_byte) or bb_err then
                local err = bb_err or "Unknown error in byte_bounds_from_col"
                return nil, "do_block_ops: " .. err
            end

            post_marks.start = {}
            post_marks.start.row = row_1
            post_marks.start.col = l_byte
        end

        if (not opts.set_del_marks) and #o.text > 0 then
            post_fin_row = row_1
            post_fin_col = o.start_byte + #o.text - 1
        elseif opts.set_del_marks and i == #blk_ops then
            --- @type string
            local fin_line = vim.api.nvim_buf_get_lines(0, row_0, row_1, false)[1]
            local fin_byte = math.min(post_marks.start.col, #fin_line - 1) --- @type integer
            fin_byte = math.max(fin_byte, 0)

            --- @type integer|nil, integer|nil, string|nil
            local l_byte, _, bb_err = blk_utils.byte_bounds_from_col(fin_line, fin_byte)
            if (not l_byte) or bb_err then
                local err = bb_err or "Unknown error in byte_bounds_from_col"
                return nil, "do_block_ops: " .. err
            end

            post_fin_row = row_1
            post_fin_col = l_byte
        end
    end

    post_marks.fin = {}
    post_marks.fin.row = post_fin_row
    post_marks.fin.col = post_fin_col

    vim.api.nvim_buf_set_mark(0, "[", post_marks.start.row, post_marks.start.col, {})
    vim.api.nvim_buf_set_mark(0, "]", post_marks.fin.row, post_marks.fin.col, {})
    return post_marks
end

return M
