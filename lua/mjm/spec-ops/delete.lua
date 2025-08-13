-- CHORE: The yank error is confusing if you don't want to delete yank

local blk_utils = require("mjm.spec-ops.block-utils")
local del_utils = require("mjm.spec-ops.del-utils")
local get_utils = require("mjm.spec-ops.get-utils")
local op_utils = require("mjm.spec-ops.op-utils")
local utils = require("mjm.spec-ops.utils")

local M = {}

local op_state = op_utils.create_new_op_state() --- @type op_state
local cb_state = op_utils.create_new_op_state() --- @type op_state

local op_in_del = false --- @type boolean

vim.api.nvim_create_autocmd("ModeChanged", {
    group = vim.api.nvim_create_augroup("spec-ops_del-flag", { clear = true }),
    pattern = "no*",
    callback = function()
        op_in_del = false
    end,
})

local function operator()
    op_utils.update_op_state(op_state)
    op_in_del = true
    vim.o.operatorfunc = "v:lua.require'mjm.spec-ops.delete'.delete_callback"
    return "g@"
end

local function visual()
    op_utils.update_op_state(op_state)
    vim.o.operatorfunc = "v:lua.require'mjm.spec-ops.delete'.delete_callback"
    return "g@"
end

local function eol()
    op_utils.update_op_state(op_state)
    vim.o.operatorfunc = "v:lua.require'mjm.spec-ops.delete'.delete_callback"
    return "g@$"
end

-- NOTE: Outlining for architectural purposes

--- @param text string
--- @return boolean
local function should_yank(text)
    return string.match(text, "%S")
end

--- @param motion string
function M.delete_callback(motion)
    op_utils.update_cb_from_op(op_state, cb_state, motion)

    local marks = utils.get_marks(motion, cb_state.vmode) --- @type op_marks

    --- @diagnostic disable: undefined-field
    local yank_lines, err_y = get_utils.do_get({
        marks = marks,
        curswant = cb_state.view.curswant,
        motion = motion,
    }) --- @type string[]|nil, string|nil

    if (not yank_lines) or err_y then
        local err_msg = err_y or "Unknown error getting text to yank" --- @type string
        return vim.notify("delete_callback: " .. err_msg, vim.log.levels.ERROR)
    end

    --- @type string
    local text = table.concat(yank_lines, "\n") .. (motion == "line" and "\n" or "")
    if should_yank(text) then
        if motion == "block" then
            vim.fn.setreg(cb_state.reg, text, "b" .. blk_utils.get_block_reg_width(yank_lines))
        else
            vim.fn.setreg(cb_state.reg, text)
        end
    end

    local post_marks, err_d = del_utils.do_del({
        marks = marks,
        motion = motion,
        curswant = cb_state.view.curswant,
        visual = cb_state.vmode,
    }) --- @type op_marks|nil, string|nil

    if (not post_marks) or err_d then
        local err_msg = err_d or "Unknown error at delete callback"
        return vim.notify("delete_callback: " .. err_msg, vim.log.levels.ERROR)
    end

    vim.api.nvim_win_set_cursor(0, { post_marks.start.row, post_marks.start.col })
end

vim.keymap.set("n", "<Plug>(SpecOpsDeleteOperator)", function()
    return operator()
end, { expr = true })

vim.keymap.set("o", "<Plug>(SpecOpsDeleteLineObject)", function()
    if not op_in_del then
        return "<esc>"
    end

    op_in_del = false
    return "_" -- dd/yy/cc internal behavior
end, { expr = true })

vim.keymap.set(
    "n",
    "<Plug>(SpecOpsDeleteLine)",
    "<Plug>(SpecOpsDeleteOperator)<Plug>(SpecOpsDeleteLineObject)"
)

vim.keymap.set("n", "<Plug>(SpecOpsDeleteEol)", function()
    return eol()
end, { expr = true })

vim.keymap.set("x", "<Plug>(SpecOpsDeleteVisual)", function()
    return visual()
end, { expr = true })

vim.keymap.set("n", "d", "<Plug>(SpecOpsDeleteOperator)")
vim.keymap.set("o", "d", "<Plug>(SpecOpsDeleteLineObject)")
vim.keymap.set("x", "d", "<Plug>(SpecOpsDeleteVisual)")
vim.keymap.set("n", "D", "<Plug>(SpecOpsDeleteEol)")

vim.keymap.set("x", "D", "<nop>")

-- Helix style black hole mappings
vim.keymap.set("n", "<M-d>", '"_<Plug>(SpecOpsDeleteOperator)')
vim.keymap.set("x", "<M-d>", '"_<Plug>(SpecOpsDeleteVisual)')
vim.keymap.set("n", "<M-D>", '"_<Plug>(SpecOpsDeleteEol)')

return M
