local blk_utils = require("mjm.spec-ops.block-utils")
local get_utils = require("mjm.spec-ops.get-utils")
local op_utils = require("mjm.spec-ops.op-utils")
local reg_utils = require("mjm.spec-ops.reg-utils")
local shared = require("mjm.spec-ops.shared")
local utils = require("mjm.spec-ops.utils")

local M = {}

local reg_handler = nil ---@type fun( ctx: reg_ctx): string[]
local op_in_yank = false --- @type boolean
local new_op_state = op_utils.get_new_op_state()
-- local op_state = op_utils.create_new_op_state() --- @type op_state
-- local cb_state = op_utils.create_new_op_state() --- @type op_state

local function operator()
    op_utils.update_op_state_pre(new_op_state)
    op_in_yank = true
    vim.o.operatorfunc = "v:lua.require'mjm.spec-ops.yank'.yank_callback"
    return "g@"
end

local function visual()
    op_utils.update_op_state_pre(new_op_state)
    vim.o.operatorfunc = "v:lua.require'mjm.spec-ops.yank'.yank_callback"
    return "g@"
end

local function eol()
    op_utils.update_op_state_pre(new_op_state)
    vim.o.operatorfunc = "v:lua.require'mjm.spec-ops.yank'.yank_callback"
    return "g@$"
end

function M.setup(opts)
    opts = opts or {}

    reg_handler = opts.reg_handler or reg_utils.get_handler()

    vim.api.nvim_create_autocmd("ModeChanged", {
        group = vim.api.nvim_create_augroup("spec-ops_yank-flag", { clear = true }),
        pattern = "no*",
        callback = function()
            op_in_yank = false
        end,
    })

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
end

local hl_group = "SpecOpsYank" --- @type string
vim.api.nvim_set_hl(0, hl_group, { link = "IncSearch", default = true })
local hl_ns = vim.api.nvim_create_namespace("mjm.spec-ops.highlight") --- @type integer
local hl_timer = 175 --- @type integer

--- @param motion string
function M.yank_callback(motion)
    op_utils.update_op_state(new_op_state, motion)
    local post = new_op_state.post

    local marks = utils.get_marks(motion, post.vmode) --- @type op_marks

    --- @diagnostic disable: undefined-field
    local lines, err = get_utils.do_get({
        marks = marks,
        curswant = post.view.curswant,
        motion = motion,
    }) --- @type string[]|nil, string|nil

    if (not lines) or err then
        local err_msg = err or "Unknown error getting text to yank" --- @type string
        return vim.notify("Abandoning yank_callback: " .. err_msg, vim.log.levels.ERROR)
    end

    vim.api.nvim_win_set_cursor(0, { post.view.lnum, post.view.col })

    --- @type string[]
    local reges = reg_handler({ lines = lines, op = "y", reg = post.reg, vmode = post.vmode })

    if (not reges) or #reges < 1 or vim.tbl_contains(reges, "_") then
        return
    end

    local text = table.concat(lines, "\n") .. (motion == "line" and "\n" or "") --- @type string
    for _, r in pairs(reges) do
        if motion == "block" then
            vim.fn.setreg(r, text, "b" .. blk_utils.get_block_reg_width(lines))
        else
            vim.fn.setreg(r, text)
        end
    end

    vim.api.nvim_exec_autocmds("TextYankPost", {
        buffer = vim.api.nvim_get_current_buf(),
        data = {
            inclusive = true,
            operator = "y",
            regcontents = lines,
            regname = reges[1],
            regtype = utils.regtype_from_motion(motion),
            visual = post.vmode,
        },
    })

    local reg_type = vim.fn.getregtype(reges[1]) --- @type string
    shared.highlight_text(marks, hl_group, hl_ns, hl_timer, reg_type)
end

return M
