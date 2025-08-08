-- TODO: Can't make useful observations about how this function renders count because, for
-- the moment, it doesn't do anything with it
-- When delete is put in, can then see how count acts and work accordingly

local M = {}

local hl_group = "SpecOpsYank"
local hl_ns = vim.api.nvim_create_namespace("mjm.spec-ops.highlight")
vim.api.nvim_set_hl(0, hl_group, { link = "IncSearch", default = true })
local hl_timer = 175

local in_yank = false

-- NOTE: Saving the whole view is inefficient now, but the coladd might be necessary to support
-- virtualedit later
local op_view = nil --- @type vim.fn.winsaveview.ret|nil
local op_vmode = false --- @type boolean
-- Some text objects clobber vim.v.register, so store here
-- Works out since, by default, the register can't be edited on dot repeat
local op_vreg = nil --- @type string|nil

local cb_view = nil --- @type vim.fn.winsaveview.ret
local cb_vmode = false --- @type boolean
local cb_vreg = nil --- @type string

vim.api.nvim_create_autocmd("ModeChanged", {
    group = vim.api.nvim_create_augroup("spec-ops_yank-flag", { clear = true }),
    pattern = "no*",
    callback = function()
        in_yank = false
    end,
})

local function operator()
    in_yank = true
    op_vreg = vim.v.register
    op_view = vim.fn.winsaveview()
    op_vmode = false

    vim.o.operatorfunc = "v:lua.require'mjm.spec-ops.yank'.callback"
    return "g@"
end

local function visual()
    op_vreg = vim.v.register
    op_view = vim.fn.winsaveview()
    op_vmode = true

    vim.o.operatorfunc = "v:lua.require'mjm.spec-ops.yank'.callback"
    return "g@"
end

local function eol()
    op_vreg = vim.v.register
    op_view = vim.fn.winsaveview()
    op_vmode = false

    vim.o.operatorfunc = "v:lua.require'mjm.spec-ops.yank'.callback"
    return "g@$"
end

-- FUTURE: If I run TextYankPost after setting a block register, it changes the type to v
-- Additionally, no event data is populated. I guess the solution is to make a custom event
-- Don't want to deal with unknown effects of TextYankPost for no value anyway

local function update_cb_state()
    local utils = require("mjm.spec-ops.utils")

    cb_view = op_view or vim.fn.winsaveview()
    op_view = nil

    cb_vmode = op_vmode
    op_vmode = false

    cb_vreg = utils.is_valid_register(op_vreg) and op_vreg
        or (utils.is_valid_register(cb_vreg) and cb_vreg or utils.get_default_reg())
    op_vreg = nil
end

--- @param motion string
function M.callback(motion)
    local utils = require("mjm.spec-ops.utils")

    update_cb_state()

    local win = vim.api.nvim_get_current_win() --- @type integer
    local buf = vim.api.nvim_win_get_buf(win) --- @type integer
    local marks = utils.get_marks(buf, motion, cb_vmode) --- @type Marks

    if (not cb_vmode) and motion == "block" and marks.start.row ~= marks.finish.row then
        vim.cmd("norm! gv")
        cb_view.curswant = vim.fn.winsaveview().curswant
        vim.cmd("norm! \27")
    end

    local lines, err --- @type string[]|nil, string|nil
    local op_utils = require("mjm.spec-ops.op_utils")
    if motion == "char" then
        lines, err = op_utils.get_chars(buf, marks)
    elseif motion == "line" then
        lines, err = op_utils.get_lines(buf, marks)
    else
        lines, err = op_utils.get_block(buf, marks, cb_view.curswant)
    end
    if (not lines) or err then
        return vim.notify(err .. " - Abandoning yank", vim.log.levels.ERROR)
    end

    local text = table.concat(lines, "\n") .. (motion == "line" and "\n" or "") --- @type string
    if motion == "block" then
        local reg_width = require("mjm.spec-ops.block-utils").get_block_reg_width(lines)
        vim.fn.setreg(cb_vreg, text, "b" .. reg_width)
    else
        vim.fn.setreg(cb_vreg, text)
    end

    vim.api.nvim_win_set_cursor(win, { cb_view.lnum, cb_view.col })

    local reg_type = vim.fn.getregtype(cb_vreg):sub(1, 1) or "v"
    require("mjm.spec-ops.shared").highlight_text(buf, marks, hl_group, hl_ns, hl_timer, reg_type)
end

vim.keymap.set("o", "<Plug>(SpecOpsYankLineObject)", function()
    if in_yank then
        in_yank = false
        return "_" -- Mimic yy/dd/cc internal behavior
    else
        return "<esc>"
    end
end, { expr = true })

vim.keymap.set("o", "y", "<Plug>(SpecOpsYankLineObject)")

vim.keymap.set("n", "<Plug>(SpecOpsYankOperator)", function()
    return operator()
end, { expr = true })

vim.keymap.set("n", "<Plug>(SpecOpsYankEol)", function()
    return eol()
end, { expr = true })

vim.keymap.set("x", "<Plug>(SpecOpsYankVisual)", function()
    return visual()
end, { expr = true })

vim.keymap.set(
    "n",
    "<Plug>(SpecOpsYankLine)",
    "<Plug>(SpecOpsYankOperator)<Plug>(SpecOpsYankLineObject)"
)

-- vim.keymap.set("n", "y", "<Plug>(SpecOpsYankOperator)")
-- vim.keymap.set("x", "y", "<Plug>(SpecOpsYankVisual)")
-- vim.keymap.set("n", "Y", "<Plug>(SpecOpsYankEol)")

return M
