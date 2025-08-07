local M = {}

local is_yanking = false

vim.api.nvim_create_autocmd("ModeChanged", {
    group = vim.api.nvim_create_augroup("spec-ops_yank-flag", { clear = true }),
    pattern = "no*",
    callback = function()
        is_yanking = false
    end,
})

vim.keymap.set("o", "<Plug>(SpecOpsYankLineObject)", function()
    if is_yanking then
        is_yanking = false
        return "_" -- Mimic yy/dd/cc internal behavior
    else
        return "<esc>"
    end
end, { expr = true })

vim.keymap.set("o", "y", "<Plug>(SpecOpsYankLineObject)")

-- NOTE: Saving the whole view is inefficient now, but the coladd might be necessary to support
-- virtualedit later
local view = nil --- @type vim.fn.winsaveview.ret
local is_visual = false --- @type boolean

local function operator()
    view = vim.fn.winsaveview()
    is_yanking = true
    vim.o.operatorfunc = "v:lua.require'mjm.spec-ops.yank'.norm_callback"
    return "g@"
end

local function visual()
    view = vim.fn.winsaveview()
    is_visual = true
    vim.o.operatorfunc = "v:lua.require'mjm.spec-ops.yank'.visual_callback"
    return "g@"
end

local function eol()
    view = vim.fn.winsaveview()
    vim.o.operatorfunc = "v:lua.require'mjm.spec-ops.yank'.norm_callback"
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
--- @param vmode? boolean
local function yank_callback(motion, vmode)
    local win = vim.api.nvim_get_current_win() --- @type integer
    local buf = vim.api.nvim_win_get_buf(win) --- @type integer
    local utils = require("mjm.spec-ops.utils")
    local marks = utils.get_marks(buf, motion) --- @type Marks

    local this_view = view or vim.fn.winsaveview() --- @type vim.fn.winsaveview.ret
    if (not vmode) and motion == "block" and marks.start.row ~= marks.finish.row then
        vim.cmd("norm! gv")
        this_view.curswant = vim.fn.winsaveview().curswant
        vim.cmd("norm! \27")
    end

    local lines, err --- @type string[]|nil, string|nil
    local op_utils = require("mjm.spec-ops.op_utils")
    if motion == "char" then
        lines, err = op_utils.get_chars(buf, marks)
    elseif motion == "line" then
        lines, err = op_utils.get_lines(buf, marks)
    else
        lines, err = op_utils.get_block(buf, marks, this_view.curswant)
    end
    if (not lines) or err then
        return vim.notify(err .. " - Abandoning yank", vim.log.levels.ERROR)
    end

    local text = table.concat(lines, "\n") .. (motion == "line" and "\n" or "") --- @type string
    local reg = utils.is_valid_register(vim.v.register) and vim.v.register
        or utils.get_default_reg() --- @type string
    if motion == "block" then
        local reg_width = require("mjm.spec-ops.block-utils").get_block_reg_width(lines)
        vim.fn.setreg(reg, text, "b" .. reg_width)
    else
        vim.fn.setreg(reg, text)
    end

    vim.api.nvim_win_set_cursor(win, { this_view.lnum, this_view.col })

    local reg_type = vim.fn.getregtype(reg):sub(1, 1) or "v"
    require("mjm.spec-ops.shared").highlight_text(buf, marks, hl_group, hl_ns, hl_timer, reg_type)
end

--- @param motion string
function M.norm_callback(motion)
    yank_callback(motion)
end

--- @param motion string
function M.visual_callback(motion)
    local was_visual = is_visual --- @type boolean
    is_visual = false
    yank_callback(motion, was_visual)
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
