-- TODO: Can't make useful observations about how this function renders count because, for
-- the moment, it doesn't do anything with it
-- When delete is put in, can then see how count acts and work accordingly

local M = {}

-- NOTE: Saving the whole view is inefficient now, but the coladd might be necessary to support
-- virtualedit later
local op_state = {
    in_yank = false, --- @type boolean
    view = nil, --- @type vim.fn.winsaveview.ret|nil
    vmode = false, --- @type boolean
    -- Some text objects clobber vim.v.register, so store here
    -- Works out since, by default, the register can't be edited on dot repeat
    vreg = nil, --- @type string|nil
}

local cb_state = {
    view = nil, --- @type vim.fn.winsaveview.ret|nil
    vmode = false, --- @type boolean
    vreg = nil, --- @type string
}

vim.api.nvim_create_autocmd("ModeChanged", {
    group = vim.api.nvim_create_augroup("spec-ops_yank-flag", { clear = true }),
    pattern = "no*",
    callback = function()
        op_state.in_yank = false
    end,
})

vim.keymap.set("o", "<Plug>(SpecOpsYankLineObject)", function()
    if op_state.in_yank then
        op_state.in_yank = false
        return "_" -- Mimic yy/dd/cc internal behavior
    else
        return "<esc>"
    end
end, { expr = true })

vim.keymap.set("o", "y", "<Plug>(SpecOpsYankLineObject)")

local function operator()
    op_state.vreg = vim.v.register
    op_state.view = vim.fn.winsaveview()
    op_state.in_yank = true
    vim.o.operatorfunc = "v:lua.require'mjm.spec-ops.yank'.callback"
    return "g@"
end

local function visual()
    op_state.vreg = vim.v.register
    op_state.view = vim.fn.winsaveview()
    op_state.vmode = true
    vim.o.operatorfunc = "v:lua.require'mjm.spec-ops.yank'.callback"
    return "g@"
end

local function eol()
    op_state.vreg = vim.v.register
    op_state.view = vim.fn.winsaveview()
    op_state.vmode = false
    vim.o.operatorfunc = "v:lua.require'mjm.spec-ops.yank'.callback"
    return "g@$"
end

local hl_ns = vim.api.nvim_create_namespace("mjm.spec-ops.highlight")
local hl_group = "SpecOpsYank"
vim.api.nvim_set_hl(0, hl_group, { link = "IncSearch", default = true })
local hl_timer = 175

-- FUTURE: If I run TextYankPost after setting a block register, it changes the type to v
-- Additionally, no event data is populated. I guess the solution is to make a custom event
-- Don't want to deal with unknown effects of TextYankPost for no value anyway

--- @param motion string
function M.callback(motion)
    cb_state.vmode = op_state.vmode
    op_state.vmode = false

    cb_state.view = op_state.view or vim.fn.winsaveview()
    op_state.view = nil

    local utils = require("mjm.spec-ops.utils")
    cb_state.vreg = utils.is_valid_register(op_state.vreg) and op_state.vreg
        or (utils.is_valid_register(cb_state.vreg) and cb_state.vreg or utils.get_default_reg())

    local win = vim.api.nvim_get_current_win() --- @type integer
    local buf = vim.api.nvim_win_get_buf(win) --- @type integer
    local marks = utils.get_marks(buf, motion, cb_state.vmode) --- @type Marks

    if (not cb_state.vmode) and motion == "block" and marks.start.row ~= marks.finish.row then
        vim.cmd("norm! gv")
        cb_state.view.curswant = vim.fn.winsaveview().curswant
        vim.cmd("norm! \27")
    end

    local lines, err --- @type string[]|nil, string|nil
    local op_utils = require("mjm.spec-ops.op_utils")
    if motion == "char" then
        lines, err = op_utils.get_chars(buf, marks)
    elseif motion == "line" then
        lines, err = op_utils.get_lines(buf, marks)
    else
        lines, err = op_utils.get_block(buf, marks, cb_state.view.curswant)
    end
    if (not lines) or err then
        return vim.notify(err .. " - Abandoning yank", vim.log.levels.ERROR)
    end

    local text = table.concat(lines, "\n") .. (motion == "line" and "\n" or "") --- @type string
    if motion == "block" then
        local reg_width = require("mjm.spec-ops.block-utils").get_block_reg_width(lines)
        vim.fn.setreg(cb_state.reg, text, "b" .. reg_width)
    else
        vim.fn.setreg(cb_state.reg, text)
    end

    vim.api.nvim_win_set_cursor(win, { cb_state.view.lnum, cb_state.view.col })

    local reg_type = vim.fn.getregtype(cb_state.reg):sub(1, 1) or "v"
    require("mjm.spec-ops.shared").highlight_text(buf, marks, hl_group, hl_ns, hl_timer, reg_type)
end

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

vim.keymap.set("n", "y", "<Plug>(SpecOpsYankOperator)")
vim.keymap.set("x", "y", "<Plug>(SpecOpsYankVisual)")
vim.keymap.set("n", "Y", "<Plug>(SpecOpsYankEol)")

return M
