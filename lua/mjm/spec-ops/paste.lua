-- TODO: Handle gp and zp. An important note with zp is, because right now I'm pasting rectangles,
-- I can assume that the top mark is always left and the bottom mark is always right. Because
-- zp block pastes can have ragged edges, you might have to place marks in the top right
-- bottom left scheme, which breaks a lot of other assumptions
-- zp note: Repeats do not add intermediate white space. so longer lines get multiplicatively
-- longer
-- TODO: Alternative cursor options
-- - Norm single line char after: Hold cursor
-- - Norm single line char before: Either hold or beginning of pasted text
-- - Norm multiline char after: Either hold or end of pasted text
-- - Norm multiline char before: End of pasted text
-- - Norm linewise: Hold cursor
-- TODO: Keep linewise through visual paste implementations
-- TODO: Implement correct cursor behavior for visual pastes
-- TODO: The paste yank error is confusing if you're not yanking
-- TODO: The yank should only exit on failure if yanking or indenting
-- FUTURE: line into char visual paste creates trailing whitespace. Option to remove?
-- TODO: Unsure if TextYankPost fires when doing a delete/paste visually

local blk_utils = require("mjm.spec-ops.block-utils")
local get_utils = require("mjm.spec-ops.get-utils")
local op_utils = require("mjm.spec-ops.op-utils")
local paste_utils = require("mjm.spec-ops.paste-utils")
local set_utils = require("mjm.spec-ops.set-utils")
local shared = require("mjm.spec-ops.shared")
local utils = require("mjm.spec-ops.utils")

local M = {}

local hl_group = "SpecOpsPaste" --- @type string
vim.api.nvim_set_hl(0, hl_group, { link = "IncSearch", default = true })
local hl_ns = vim.api.nvim_create_namespace("mjm.spec-ops.highlight") --- @type integer
local hl_timer = 175 --- @type integer

local op_state = op_utils.create_new_op_state() --- @type op_state
local cb_state = op_utils.create_new_op_state() --- @type op_state

local before = false --- @type boolean
local yank_old = false --- @type boolean

local function paste_norm(opts)
    opts = opts or {}
    before = opts.before

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

-- Outlined for architectural purposes
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

    local regtype = vim.fn.getregtype(cb_state.reg) --- @type string
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

-- NOTE: Outlining for architectural purposes
-- TODO: We're starting to see the first organic case for having a config function. I don't need
-- the should_yank handler defined individually for each operator. There should be a config
-- that can set it for each one. Can also work out stuff like highlight architecture

--- @param text string
--- @return boolean
local function should_yank(text)
    return string.match(text, "%S")
end

function M.paste_visual_callback(motion)
    op_utils.update_cb_from_op(op_state, cb_state, motion)

    local marks = utils.get_marks(motion, cb_state.vmode) --- @type op_marks

    local cur_pos = vim.api.nvim_win_get_cursor(0) --- @type {[1]: integer, [2]:integer}
    -- TODO: Do all the lines matter?
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

    local curswant = cb_state.view.curswant

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

    -- TODO: While this wouldn't happen in my current setup/config, it is theoretically possible
    -- for a user to set an indent pattern that causes the start row to indent differently from
    -- the bottom row, making this adjustment method invalid
    -- For now, we will hold on this until substitute is also complete
    if #lines == 1 and regtype == "v" and motion == "block" then
        post_marks.fin.row = post_marks.start.row
        vim.api.nvim_buf_set_mark(0, "]", post_marks.fin.row, post_marks.fin.col, {})
    end

    -- TODO: The alternative method here is calculating the pythagorean distance of the cursor
    -- from the start and the end, and placing it at the closer one (or the block corners for
    -- thos selections). Holding on implementing for now though due to the same architecture
    -- issues as above. Want to see the substitute use case first
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

vim.keymap.set("x", "<Plug>(SpecOpsPasteVisual)", function()
    return paste_visual()
end, { expr = true, silent = true })

vim.keymap.set("x", "<Plug>(SpecOpsPasteVisualAndYank)", function()
    return paste_visual({ yank_old = true })
end, { expr = true, silent = true })

vim.keymap.set("n", "p", "<Plug>(SpecOpsPasteNormalAfterCursor)")
vim.keymap.set("n", "P", "<Plug>(SpecOpsPasteNormalBeforeCursor)")

vim.keymap.set("n", "<M-p>", '"+<Plug>(SpecOpsPasteNormalAfterCursor)')
vim.keymap.set("n", "<M-P>", '"+<Plug>(SpecOpsPasteNormalBeforeCursor)')

vim.keymap.set("x", "p", "<Plug>(SpecOpsPasteVisual)")
vim.keymap.set("x", "P", "<Plug>(SpecOpsPasteVisualAndYank)")

vim.keymap.set("x", "<M-p>", '"+<Plug>(SpecOpsPasteVisual)')
vim.keymap.set("x", "<M-P>", '"+<Plug>(SpecOpsPasteVisualAndYank)')

return M
