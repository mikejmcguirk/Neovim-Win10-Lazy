-- TODO: Support virtualedit onemore
-- TODO: Register behavior options should be default, only specified, or ring
-- https://github.com/gbprod/yanky.nvim -- Really though, a lot more to integrate here
-- TODO: Test behavior with count

local utils = require("mjm.spec-ops.utils")
local op_utils = require("mjm.spec-ops.op-utils")
local blk_utils = require("mjm.spec-ops.block-utils")

local M = {}

-- NOTE: Saving the whole view is inefficient now, but the coladd might be necessary to support
-- virtualedit later
local op_view = nil --- @type vim.fn.winsaveview.ret|nil
-- Some text objects clobber vim.v.register, so store here
-- Works out since, by default, the register can't be edited on dot repeat
local op_vreg = nil --- @type string|nil
local op_vmode = false --- @type boolean
local op_in_del = false --- @type boolean

local cb_view = nil --- @type vim.fn.winsaveview.ret
local cb_max_curswant = false --- @type boolean
local cb_vreg = nil --- @type string
local cb_vmode = false --- @type boolean

vim.api.nvim_create_autocmd("ModeChanged", {
    group = vim.api.nvim_create_augroup("spec-ops_del-flag", { clear = true }),
    pattern = "no*",
    callback = function()
        op_in_del = false
    end,
})

local function set_op_state(opts)
    opts = opts or {}

    op_view = vim.fn.winsaveview()
    op_vreg = vim.v.register
    op_vmode = opts.vmode
    op_in_del = opts.in_del

    vim.o.operatorfunc = "v:lua.require'mjm.spec-ops.delete'.delete_callback"
end

local function operator()
    set_op_state({ in_del = true })
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

-- NOTE: Outlining for architectural purposes

--- @param text string
--- @return boolean
local function should_yank(text)
    return string.match(text, "%S")
end

--- @param motion string
function M.delete_callback(motion)
    update_cb_state(motion)

    local win = vim.api.nvim_get_current_win() --- @type integer
    local buf = vim.api.nvim_win_get_buf(win) --- @type integer
    local marks = utils.get_marks(buf, motion, cb_vmode) --- @type Marks

    local lines, err_y = (function()
        if motion == "char" then
            return op_utils.get_chars(buf, marks)
        elseif motion == "line" then
            return op_utils.get_lines(buf, marks)
        else
            return op_utils.get_block(buf, marks, cb_view.curswant)
        end
    end)() --- @type string[]|nil, string|nil

    if (not lines) or err_y then
        local err_msg = err_y or "Unknown error getting text to yank" --- @type string
        return vim.notify("delete_callback: " .. err_msg, vim.log.levels.ERROR)
    end

    local text = table.concat(lines, "\n") .. (motion == "line" and "\n" or "") --- @type string
    if should_yank(text) then
        if motion == "block" then
            vim.fn.setreg(cb_vreg, text, "b" .. blk_utils.get_block_reg_width(lines))
        else
            vim.fn.setreg(cb_vreg, text)
        end
    end

    local post_marks, err_d = (function()
        if motion == "char" then
            return op_utils.del_chars(buf, marks)
        elseif motion == "line" then
            return op_utils.del_lines(buf, marks, cb_view.curswant, cb_vmode)
        else
            return op_utils.del_block(buf, marks, cb_view.curswant)
        end
    end)() --- @type Marks|nil, string|nil

    if (not post_marks) or err_d then
        local err_msg = err_d or "Unknown error at delete callback"
        return vim.notify("delete_callback: " .. err_msg, vim.log.levels.ERROR)
    end

    vim.api.nvim_win_set_cursor(win, { post_marks.start.row, post_marks.start.col })
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

-- Helix style black hole mappings
vim.keymap.set("n", "<M-d>", '"_<Plug>(SpecOpsDeleteOperator)')
vim.keymap.set("x", "<M-d>", '"_<Plug>(SpecOpsDeleteVisual)')
vim.keymap.set("n", "<M-D>", '"_<Plug>(SpecOpsDeleteEol)')

vim.keymap.set("x", "D", "<nop>")

return M
