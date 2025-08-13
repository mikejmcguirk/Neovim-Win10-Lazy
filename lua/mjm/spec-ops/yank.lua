-- FUTURE: Is there a way to make this operator respect  the "y" cpoption?
-- TODO: Handle zy
-- FUTURE: If I exec TextYankPost autocmds after setting a block register, the register's type is
-- changed to "v". The event also contains no v:event data. Either solve these problems or
-- fire a custom event

local blk_utils = require("mjm.spec-ops.block-utils")
local get_utils = require("mjm.spec-ops.get-utils")
local op_utils = require("mjm.spec-ops.op-utils")
local shared = require("mjm.spec-ops.shared")
local utils = require("mjm.spec-ops.utils")

local M = {}

local hl_group = "SpecOpsYank" --- @type string
vim.api.nvim_set_hl(0, hl_group, { link = "IncSearch", default = true })
local hl_ns = vim.api.nvim_create_namespace("mjm.spec-ops.highlight") --- @type integer
local hl_timer = 175 --- @type integer

local op_state = op_utils.create_new_op_state() --- @type op_state
local cb_state = op_utils.create_new_op_state() --- @type op_state

local op_in_yank = false --- @type boolean

vim.api.nvim_create_autocmd("ModeChanged", {
    group = vim.api.nvim_create_augroup("spec-ops_yank-flag", { clear = true }),
    pattern = "no*",
    callback = function()
        op_in_yank = false
    end,
})

local function operator()
    op_utils.update_op_state(op_state)
    op_in_yank = true
    vim.o.operatorfunc = "v:lua.require'mjm.spec-ops.yank'.yank_callback"
    return "g@"
end

local function visual()
    op_utils.update_op_state(op_state)
    vim.o.operatorfunc = "v:lua.require'mjm.spec-ops.yank'.yank_callback"
    return "g@"
end

local function eol()
    op_utils.update_op_state(op_state)
    vim.o.operatorfunc = "v:lua.require'mjm.spec-ops.yank'.yank_callback"
    return "g@$"
end

--- @param motion string
function M.yank_callback(motion)
    op_utils.update_cb_from_op(op_state, cb_state, motion)

    local marks = utils.get_marks(motion, cb_state.vmode) --- @type Marks

    --- @diagnostic disable: undefined-field
    local lines, err = get_utils.do_get({
        marks = marks,
        curswant = cb_state.view.curswant,
        motion = motion,
    }) --- @type string[]|nil, string|nil

    if (not lines) or err then
        local err_msg = err or "Unknown error getting text to yank" --- @type string
        return vim.notify("Abandoning yank_callback: " .. err_msg, vim.log.levels.ERROR)
    end

    local text = table.concat(lines, "\n") .. (motion == "line" and "\n" or "") --- @type string
    if motion == "block" then
        vim.fn.setreg(cb_state.reg, text, "b" .. blk_utils.get_block_reg_width(lines))
    else
        vim.fn.setreg(cb_state.reg, text)
    end

    vim.api.nvim_win_set_cursor(0, { cb_state.view.lnum, cb_state.view.col })

    local reg_type = vim.fn.getregtype(cb_state.reg) --- @type string
    shared.highlight_text(marks, hl_group, hl_ns, hl_timer, reg_type)
end

vim.keymap.set("n", "<Plug>(SpecOpsYankOperator)", function()
    return operator()
end, { expr = true })

vim.keymap.set("o", "<Plug>(SpecOpsYankLineObject)", function()
    if not op_in_yank then
        return "<esc>"
    end

    op_in_yank = false
    return "_" -- yy/dd/cc internal behavior
end, { expr = true })

vim.keymap.set(
    "n",
    "<Plug>(SpecOpsYankLine)",
    "<Plug>(SpecOpsYankOperator)<Plug>(SpecOpsYankLineObject)"
)

vim.keymap.set("n", "<Plug>(SpecOpsYankEol)", function()
    return eol()
end, { expr = true })

vim.keymap.set("x", "<Plug>(SpecOpsYankVisual)", function()
    return visual()
end, { expr = true })

vim.keymap.set("n", "y", "<Plug>(SpecOpsYankOperator)")
vim.keymap.set("o", "y", "<Plug>(SpecOpsYankLineObject)")
vim.keymap.set("n", "Y", "<Plug>(SpecOpsYankEol)")
vim.keymap.set("x", "y", "<Plug>(SpecOpsYankVisual)")

vim.keymap.set("x", "Y", "<nop>")

-- Helix style system clipboard mappings
vim.keymap.set("n", "<M-y>", '"+<Plug>(SpecOpsYankOperator)')
vim.keymap.set("n", "<M-Y>", '"+<Plug>(SpecOpsYankEol)')
vim.keymap.set("x", "<M-y>", '"+<Plug>(SpecOpsYankVisual)')

return M
