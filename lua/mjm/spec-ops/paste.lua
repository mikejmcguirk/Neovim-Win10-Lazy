local blk_utils = require("mjm.spec-ops.block-utils")
local get_utils = require("mjm.spec-ops.get-utils")
local op_utils = require("mjm.spec-ops.op-utils")
local paste_utils = require("mjm.spec-ops.paste-utils")
local set_utils = require("mjm.spec-ops.set-utils")
local shared = require("mjm.spec-ops.shared")
local utils = require("mjm.spec-ops.utils")

local M = {}

local hl_group = "SpecOpsPaste" --- @type string
vim.api.nvim_set_hl(0, hl_group, { link = "Boolean", default = true })
local hl_ns = vim.api.nvim_create_namespace("mjm.spec-ops.paste-highlight") --- @type integer
local hl_timer = 175 --- @type integer

local op_state = op_utils.create_new_op_state() --- @type op_state
local cb_state = op_utils.create_new_op_state() --- @type op_state

local before = false --- @type boolean
local force_linewise = false --- @type boolean
local yank_old = false --- @type boolean

local function paste_norm(opts)
    opts = opts or {}
    before = opts.before
    force_linewise = opts.force_linewise

    op_utils.update_op_state(op_state)

    vim.o.operatorfunc = "v:lua.require'mjm.spec-ops.paste'.paste_norm_callback"
    return "g@l"
end

local function paste_visual(opts)
    opts = opts or {}
    yank_old = opts.yank_old

    op_utils.update_op_state(op_state)

    vim.o.operatorfunc = "v:lua.require'mjm.spec-ops.paste'.paste_visual_callback"
    return "g@"
end

local function should_reindent(ctx)
    ctx = ctx or {}

    if ctx.on_blank or ctx.regtype == "V" or ctx.motion == "line" then
        return true
    else
        return false
    end
end

--- @return nil
M.paste_norm_callback = function(motion)
    op_utils.update_cb_from_op(op_state, cb_state, motion)

    local text = vim.fn.getreg(cb_state.reg) --- @type string
    if (not text) or text == "" then
        return vim.notify(cb_state.reg .. " register is empty", vim.log.levels.INFO)
    end

    local regtype = force_linewise and "V" or vim.fn.getregtype(cb_state.reg) --- @type string
    local cur_pos = vim.api.nvim_win_get_cursor(0) --- @type {[1]: integer, [2]:integer}

    --- @type string
    local start_line = vim.api.nvim_buf_get_lines(0, cur_pos[1] - 1, cur_pos[1], false)[1]
    local on_blank = not start_line:match("%S") --- @type boolean

    local marks, err = paste_utils.do_paste({
        regtype = regtype,
        cur_pos = cur_pos,
        before = before,
        text = text,
        vcount = vim.v.count1,
    }) --- @type op_marks|nil, string|nil

    if (not marks) or err then
        return "paste_norm: " .. (err or ("Unknown error in " .. regtype .. " paste"))
    end

    if should_reindent({ on_blank = on_blank, regtype = regtype, motion = motion }) then
        marks = utils.fix_indents(marks, cur_pos)
    end

    paste_utils.adj_paste_cursor_default({ marks = marks, regtype = regtype })
    shared.highlight_text(marks, hl_group, hl_ns, hl_timer, regtype)
end

--- @param text string
--- @return boolean
local function should_yank(text)
    return string.match(text, "%S")
end

function M.paste_visual_callback(motion)
    op_utils.update_cb_from_op(op_state, cb_state, motion)

    local marks = utils.get_marks(motion, cb_state.vmode) --- @type op_marks

    local cur_pos = vim.api.nvim_win_get_cursor(0) --- @type {[1]: integer, [2]:integer}
    --- @type string
    local start_line = vim.api.nvim_buf_get_lines(0, cur_pos[1] - 1, cur_pos[1], false)[1]
    local on_blank = not start_line:match("%S") --- @type boolean

    --- @diagnostic disable: undefined-field
    local yanked, err_y = get_utils.do_get({
        marks = marks,
        curswant = cb_state.view.curswant,
        motion = motion,
    }) --- @type string[]|nil, string|nil

    if (not yanked) or err_y then
        local err_msg = err_y or "Unknown error getting text to yank" --- @type string
        return vim.notify("paste_visual_callback: " .. err_msg, vim.log.levels.ERROR)
    end

    local regtype = vim.fn.getregtype(cb_state.reg) --- @type string
    local text = vim.fn.getreg(cb_state.reg) --- @type string
    if (not text) or text == "" then
        return vim.notify(cb_state.reg .. " register is empty", vim.log.levels.INFO)
    end

    local curswant = cb_state.view.curswant --- @type integer

    local lines = op_utils.setup_text_lines({
        text = text,
        motion = motion,
        regtype = regtype,
        vcount = vim.v.count1,
    })

    --- @type op_marks|nil, string|nil
    local post_marks, err_s = set_utils.do_set(lines, marks, regtype, motion, curswant)

    if (not post_marks) or err_s then
        local err_msg = err_s or "Unknown error in do_set"
        return vim.notify("paste_visual_callback: " .. err_msg, vim.log.levels.ERROR)
    end

    if should_reindent({ on_blank = on_blank, regtype = regtype, motion = motion }) then
        post_marks = utils.fix_indents(post_marks, cur_pos)
    end

    if #lines == 1 and regtype == "v" and motion == "block" then
        post_marks.fin.row = post_marks.start.row
        vim.api.nvim_buf_set_mark(0, "]", post_marks.fin.row, post_marks.fin.col, {})
    end

    if #lines == 1 and regtype == "v" then
        vim.api.nvim_win_set_cursor(0, { post_marks.fin.row, post_marks.fin.col })
    else
        vim.api.nvim_win_set_cursor(0, { post_marks.start.row, post_marks.start.col })
    end

    --- @type string
    if yank_old and cb_state.reg ~= "_" then
        local yank_text = table.concat(yanked, "\n") .. (motion == "line" and "\n" or "")
        if should_yank(yank_text) then
            if motion == "block" then
                vim.fn.setreg(
                    cb_state.reg,
                    yank_text,
                    "b" .. blk_utils.get_block_reg_width(yanked)
                )
            else
                vim.fn.setreg(cb_state.reg, yank_text)
            end

            vim.api.nvim_exec_autocmds("TextYankPost", {
                buffer = vim.api.nvim_get_current_buf(),
                data = {
                    inclusive = true,
                    operator = "y",
                    regcontents = lines,
                    regname = cb_state.reg,
                    regtype = utils.regtype_from_motion(motion),
                    visual = cb_state.vmode,
                },
            })
        end
    end

    shared.highlight_text(post_marks, hl_group, hl_ns, hl_timer, regtype)
end

vim.keymap.set("n", "<Plug>(SpecOpsPasteNormalAfterCursor)", function()
    return paste_norm()
end, { expr = true, silent = true })

vim.keymap.set("n", "<Plug>(SpecOpsPasteNormalBeforeCursor)", function()
    return paste_norm({ before = true })
end, { expr = true, silent = true })

vim.keymap.set("n", "<Plug>(SpecOpsPasteLinewiseAfter)", function()
    return paste_norm({ force_linewise = true })
end, { expr = true, silent = true })

vim.keymap.set("n", "<Plug>(SpecOpsPasteLinewiseBefore)", function()
    return paste_norm({ force_linewise = true, before = true })
end, { expr = true, silent = true })

vim.keymap.set("x", "<Plug>(SpecOpsPasteVisual)", function()
    return paste_visual()
end, { expr = true, silent = true })

vim.keymap.set("x", "<Plug>(SpecOpsPasteVisualAndYank)", function()
    return paste_visual({ yank_old = true })
end, { expr = true, silent = true })

return M
