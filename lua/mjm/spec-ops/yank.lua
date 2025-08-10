-- TODO: Respect the "y" cpoption
-- TODO: Support virtualedit
-- TODO: Handle zy

local blk_utils = require("mjm.spec-ops.block-utils")
local get_utils = require("mjm.spec-ops.get-utils")
local shared = require("mjm.spec-ops.shared")
local utils = require("mjm.spec-ops.utils")

local M = {}

local hl_group = "SpecOpsYank" --- @type string
vim.api.nvim_set_hl(0, hl_group, { link = "IncSearch", default = true })
local hl_ns = vim.api.nvim_create_namespace("mjm.spec-ops.yank-highlight") --- @type integer
local hl_timer = 175 --- @type integer

-- NOTE: Saving the whole view is inefficient now, but the coladd might be necessary to support
-- virtualedit later
local op_view = nil --- @type vim.fn.winsaveview.ret|nil
-- Some text objects clobber vim.v.register, so store here
-- Works out since, by default, the register can't be edited on dot repeat
local op_vreg = nil --- @type string|nil
local op_vmode = false --- @type boolean
local op_in_yank = false --- @type boolean

local cb_view = nil --- @type vim.fn.winsaveview.ret
local cb_max_curswant = false --- @type boolean
local cb_vreg = nil --- @type string
local cb_vmode = false --- @type boolean

vim.api.nvim_create_autocmd("ModeChanged", {
    group = vim.api.nvim_create_augroup("spec-ops_yank-flag", { clear = true }),
    pattern = "no*",
    callback = function()
        op_in_yank = false
    end,
})

local function set_op_state(opts)
    opts = opts or {}

    op_view = vim.fn.winsaveview()
    op_vreg = vim.v.register
    op_vmode = opts.vmode
    op_in_yank = opts.in_yank

    vim.o.operatorfunc = "v:lua.require'mjm.spec-ops.yank'.yank_callback"
end

local function operator()
    set_op_state({ in_yank = true })
    return "g@"
end

local function visual()
    set_op_state({ vmode = true })
    return "g@"
end

local function eol()
    set_op_state()
    return "g@$"
end

-- FUTURE: If I exec TextYankPost autocmds after setting a block register, the register's type is
-- changed to "v". The event also contains no v:event data. Either solve these problems or
-- fire a custom event

--- @param motion string
local function update_cb_state(motion)
    cb_vmode = op_vmode
    op_vmode = false

    if op_view then
        cb_view = op_view

        if (not cb_vmode) and motion == "block" then
            vim.cmd("norm! gv")
            cb_view.curswant = vim.fn.winsaveview().curswant
            vim.cmd("norm! \27")
        end

        cb_max_curswant = cb_view.curswant == vim.v.maxcol
    else
        cb_view = vim.fn.winsaveview()
        cb_view.curswant = cb_max_curswant and vim.v.maxcol or cb_view.curswant
    end

    op_view = nil

    if utils.is_valid_register(op_vreg) then
        --- @diagnostic disable: cast-local-type -- Checked by is_valid_register
        cb_vreg = op_vreg
    elseif not utils.is_valid_register(cb_vreg) then
        cb_vreg = utils.get_default_reg()
    end

    op_vreg = nil
end

--- @param motion string
function M.yank_callback(motion)
    update_cb_state(motion)

    local win = vim.api.nvim_get_current_win() --- @type integer
    local marks = utils.get_marks(motion, cb_vmode) --- @type Marks

    local lines, err = get_utils.do_get({
        marks = marks,
        curswant = cb_view.curswant,
        motion = motion,
    }) --- @type string[]|nil, string|nil

    if (not lines) or err then
        local err_msg = err or "Unknown error getting text to yank" --- @type string
        return vim.notify("Abandoning yank_callback: " .. err_msg, vim.log.levels.ERROR)
    end

    local text = table.concat(lines, "\n") .. (motion == "line" and "\n" or "") --- @type string
    if motion == "block" then
        vim.fn.setreg(cb_vreg, text, "b" .. blk_utils.get_block_reg_width(lines))
    else
        vim.fn.setreg(cb_vreg, text)
    end

    vim.api.nvim_win_set_cursor(win, { cb_view.lnum, cb_view.col })

    local reg_type = vim.fn.getregtype(cb_vreg) --- @type string
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

-- Helix style system clipboard mappings
vim.keymap.set("n", "<M-y>", '"+<Plug>(SpecOpsYankOperator)')
vim.keymap.set("x", "<M-y>", '"+<Plug>(SpecOpsYankVisual)')

vim.keymap.set("x", "Y", "<Plug>(SpecOpsYankEol)")
vim.keymap.set("n", "<M-Y>", '"+<Plug>(SpecOpsYankEol)')

return M
