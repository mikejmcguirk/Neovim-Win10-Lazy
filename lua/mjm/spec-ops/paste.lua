-- TODO: Handle gp and zp
-- zp note: Repeats do not add intermediate white space. so longer lines get multiplicatively
-- longer
-- TODO: Alternative cursor options
-- - Norm single line char after: Hold cursor
-- - Norm single line char before: Either hold or beginning of pasted text
-- - Norm multiline char after: Either hold or end of pasted text
-- - Norm multiline char before: End of pasted text
-- - Norm linewise: Hold cursor
-- TODO: Reg can be changed on dot repeat. Make sure this is configurable though if that's what
-- the user wants
-- TODO: Come up with some naming scheme for state. In particular so it's clear what "before" is


local blk_utils = require("mjm.spec-ops.block-utils")
local get_utils = require("mjm.spec-ops.get-utils")
local op_utils = require("mjm.spec-ops.op-utils")
local paste_utils = require("mjm.spec-ops.paste-utils")
local shared = require("mjm.spec-ops.shared")
local utils = require("mjm.spec-ops.utils")

local M = {}

local hl_group = "SpecOpsPaste" --- @type string
vim.api.nvim_set_hl(0, hl_group, { link = "IncSearch", default = true })
local hl_ns = vim.api.nvim_create_namespace("mjm.spec-ops.highlight") --- @type integer
local hl_timer = 175 --- @type integer

local op_state = {
    view = nil,
    vmode = false,
    reg = nil,
} --- @type op_state

local cb_state = {
    view = nil,
    vmode = false,
    reg = nil,
} --- @type op_state

-- TODO: Don't have bespoke implementation here if count put into op_state
local before = false --- @type boolean
local yank_old = false --- @type boolean

local function paste_norm(opts)
    opts = opts or {}
    before = opts.before

    op_utils.update_op_state(op_state)

    vim.o.operatorfunc = "v:lua.require'mjm.spec-ops.paste'.paste_norm_callback"
    return "g@l"
end

-- Outlined for architectural purposes
local function should_reindent(ctx)
    ctx = ctx or {}

    if ctx.on_blank or ctx.regtype == "V" then
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

    local marks, err = paste_utils.do_norm_paste({
        regtype = regtype,
        cur_pos = cur_pos,
        before = before,
        text = text,
        vcount = vim.v.count1,
    }) --- @type Marks|nil, string|nil

    if (not marks) or err then
        return "paste_norm: " .. (err or ("Unknown error in " .. regtype .. " paste"))
    end

    if should_reindent({ on_blank = on_blank, regtype = regtype }) then
        marks = utils.fix_indents(marks, cur_pos)
    end

    paste_utils.adj_paste_cursor_default({ marks = marks, regtype = regtype })
    shared.highlight_text(marks, hl_group, hl_ns, hl_timer, regtype)
end

vim.keymap.set("n", "<Plug>(SpecOpsPasteNormalAfterCursor)", function()
    return paste_norm()
end, { expr = true, silent = true })

vim.keymap.set("n", "<Plug>(SpecOpsPasteNormalBeforeCursor)", function()
    return paste_norm({ before = true })
end, { expr = true, silent = true })

vim.keymap.set("n", "p", "<Plug>(SpecOpsPasteNormalAfterCursor)")
vim.keymap.set("n", "P", "<Plug>(SpecOpsPasteNormalBeforeCursor)")

vim.keymap.set("n", "<M-p>", '"+<Plug>(SpecOpsPasteNormalAfterCursor)')
vim.keymap.set("n", "<M-P>", '"+<Plug>(SpecOpsPasteNormalBeforeCursor)')

return M
