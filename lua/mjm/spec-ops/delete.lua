local blk_utils = require("mjm.spec-ops.block-utils")
local del_utils = require("mjm.spec-ops.del-utils")
local get_utils = require("mjm.spec-ops.get-utils")
local op_utils = require("mjm.spec-ops.op-utils")
local reg_utils = require("mjm.spec-ops.reg-utils")
local utils = require("mjm.spec-ops.utils")

local M = {}

local reg_handler = nil ---@type fun( ctx: reg_ctx): string[]
local op_state = op_utils.get_new_op_state()

local op_in_del = false --- @type boolean

vim.api.nvim_create_autocmd("ModeChanged", {
    group = vim.api.nvim_create_augroup("spec-ops_del-flag", { clear = true }),
    pattern = "no*",
    callback = function()
        op_in_del = false
    end,
})

local function operator()
    op_utils.update_op_state_pre(op_state)
    op_in_del = true
    vim.o.operatorfunc = "v:lua.require'mjm.spec-ops.delete'.delete_callback"
    return "g@"
end

local function visual()
    op_utils.update_op_state_pre(op_state)
    vim.o.operatorfunc = "v:lua.require'mjm.spec-ops.delete'.delete_callback"
    return "g@"
end

local function eol()
    op_utils.update_op_state_pre(op_state)
    vim.o.operatorfunc = "v:lua.require'mjm.spec-ops.delete'.delete_callback"
    return "g@$"
end

function M.setup(opts)
    opts = opts or {}

    reg_handler = opts.reg_handler or reg_utils.get_handler()

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
end

-- TODO: Means that doing "dlp" when starting on a space does not work

--- @param text string
--- @return boolean
local function should_yank(text)
    return string.match(text, "%S")
end

--- @param motion string
function M.delete_callback(motion)
    op_utils.update_op_state(op_state, motion)
    local post = op_state.post

    local marks = utils.get_marks(motion, post.vmode) --- @type op_marks

    --- @diagnostic disable: undefined-field
    local yank_lines, err_y = get_utils.do_get({
        marks = marks,
        curswant = post.view.curswant,
        motion = motion,
    }) --- @type string[]|nil, string|nil

    if (not yank_lines) or err_y then
        local err_msg = err_y or "Unknown error getting text to yank" --- @type string
        return vim.notify("delete_callback: " .. err_msg, vim.log.levels.ERROR)
    end

    local post_marks, err_d = del_utils.do_del({
        marks = marks,
        motion = motion,
        curswant = post.view.curswant,
        visual = post.vmode,
    }) --- @type op_marks|nil, string|nil

    if (not post_marks) or err_d then
        local err_msg = err_d or "Unknown error at delete callback"
        return vim.notify("delete_callback: " .. err_msg, vim.log.levels.ERROR)
    end

    vim.api.nvim_win_set_cursor(0, { post_marks.start.row, post_marks.start.col })

    --- @type string[]
    local reges = reg_handler({ lines = yank_lines, op = "d", reg = post.reg, vmode = post.vmode })

    local text = table.concat(yank_lines, "\n") .. (motion == "line" and "\n" or "")
    if should_yank(text) and reges and #reges >= 1 and not vim.tbl_contains(reges, "_") then
        for _, r in pairs(reges) do
            if motion == "block" then
                vim.fn.setreg(r, text, "b" .. blk_utils.get_block_reg_width(yank_lines))
            else
                vim.fn.setreg(r, text)
            end
        end

        vim.api.nvim_exec_autocmds("TextYankPost", {
            buffer = vim.api.nvim_get_current_buf(),
            data = {
                inclusive = true,
                operator = "y",
                regcontents = yank_lines,
                regname = post.reg,
                regtype = utils.regtype_from_motion(motion),
                visual = post.vmode,
            },
        })
    end
end

return M
