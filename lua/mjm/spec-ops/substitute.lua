local op_utils = require("mjm.spec-ops.op-utils")
local set_utils = require("mjm.spec-ops.set-utils")
local reg_utils = require("mjm.spec-ops.reg-utils")
local shared = require("mjm.spec-ops.shared")
local utils = require("mjm.spec-ops.utils")

local M = {}

local hl_group = "SpecOpsSubstitute" --- @type string
vim.api.nvim_set_hl(0, hl_group, { link = "DiagnosticWarn", default = true })
local hl_ns = vim.api.nvim_create_namespace("mjm.spec-ops.substitute-highlight") --- @type integer
local hl_timer = 175 --- @type integer

local reg_handler = nil ---@type fun( ctx: reg_ctx): string[]
local new_op_state = op_utils.get_new_op_state()

local is_substituting = false --- @type boolean
local is_after = true --- @type boolean

vim.api.nvim_create_autocmd("ModeChanged", {
    group = vim.api.nvim_create_augroup("spec-ops_substitute-flag", { clear = true }),
    pattern = "no*",
    callback = function()
        is_substituting = false
    end,
})

local operator_str = "v:lua.require'mjm.spec-ops.substitute'.substitute_callback"

local function operator()
    is_substituting = true
    op_utils.update_op_state_pre(new_op_state)

    vim.api.nvim_set_option_value("operatorfunc", operator_str, { scope = "global" })
    return "g@"
end

local function visual(after)
    is_after = after
    op_utils.update_op_state_pre(new_op_state)

    vim.api.nvim_set_option_value("operatorfunc", operator_str, { scope = "global" })
    return "g@"
end

local function eol()
    op_utils.update_op_state_pre(new_op_state)

    vim.api.nvim_set_option_value("operatorfunc", operator_str, { scope = "global" })
    return "g@$"
end

function M.setup(opts)
    opts = opts or {}

    reg_handler = opts.reg_handler or reg_utils.get_handler()

    vim.keymap.set("n", "<Plug>(SpecOpsSubstituteOperator)", function()
        return operator()
    end, { expr = true })

    vim.keymap.set("o", "<Plug>(SpecOpsSubstituteLineObject)", function()
        if not is_substituting then
            return "<esc>"
        end

        is_substituting = false
        return "_" -- dd/yy/cc internal behavior
    end, { expr = true })

    vim.keymap.set(
        "n",
        "<Plug>(SpecOpsSubstituteLine)",
        "<Plug>(SpecOpsSubstituteOperator)<Plug>(SpecOpsSubstituteLineObject)"
    )

    vim.keymap.set("n", "<Plug>(SpecOpsSubstituteEol)", function()
        return eol()
    end, { expr = true })

    vim.keymap.set("x", "<Plug>(SpecOpsSubstituteVisual)", function()
        return visual(true)
    end, { expr = true })

    vim.keymap.set("x", "<Plug>(SpecOpsSubstituteVisualBefore)", function()
        return visual(false)
    end, { expr = true })
end

local function should_reindent(ctx)
    ctx = ctx or {}

    if ctx.on_blank or ctx.regtype == "V" or ctx.motion == "line" then
        return true
    else
        return false
    end
end

function M.substitute_callback(motion)
    op_utils.update_op_state(new_op_state, motion)
    local post = new_op_state.post

    local marks = utils.get_marks(motion, post.vmode) --- @type op_marks

    -- TODO: This is silly right now, but the validation logic will be removed from the state
    -- update
    local reges = reg_handler({ op = "p", reg = post.reg, vmode = post.vmode })
    -- TODO: This technically works right now, but is a brittle assumption
    local reg = reges[1]

    local cur_pos = vim.api.nvim_win_get_cursor(0) --- @type {[1]: integer, [2]:integer}
    local start_line = vim.api.nvim_buf_get_lines(0, cur_pos[1] - 1, cur_pos[1], false)[1]
    local on_blank = not start_line:match("%S") --- @type boolean
    local regtype = vim.fn.getregtype(reg) --- @type string

    local text = vim.fn.getreg(reg) --- @type string
    if (not text) or text == "" then
        return vim.notify(reg .. " register is empty", vim.log.levels.INFO)
    end

    --- @diagnostic disable: undefined-field
    local curswant = post.view.curswant

    local lines = op_utils.setup_text_lines({
        text = text,
        motion = motion,
        regtype = regtype,
        vcount = 1,
    })

    --- @type op_marks|nil, string|nil
    local post_marks, err_s = set_utils.do_set(lines, marks, regtype, motion, curswant)

    if (not post_marks) or err_s then
        local err_msg = err_s or "Unknown error in do_set"
        return vim.notify("paste_visual_callback: " .. err_msg, vim.log.levels.ERROR)
    end

    if should_reindent({ on_blank = on_blank, regtype = regtype, motion = motion }) then
        marks = utils.fix_indents(post_marks, cur_pos)
    end

    if #lines == 1 and regtype == "v" and motion == "block" then
        post_marks.fin.row = post_marks.start.row
        vim.api.nvim_buf_set_mark(0, "]", post_marks.fin.row, post_marks.fin.col, {})
    end

    shared.highlight_text(post_marks, hl_group, hl_ns, hl_timer, regtype)

    if post.vmode then
        if is_after then
            vim.api.nvim_win_set_cursor(0, { post_marks.fin.row, post_marks.fin.col })
            vim.api.nvim_feedkeys("a", "nix!", false)
        else
            vim.api.nvim_win_set_cursor(0, { post_marks.start.row, post_marks.start.col })
            vim.api.nvim_feedkeys("i", "nix!", false)
        end
    else
        vim.api.nvim_win_set_cursor(0, { post.view.lnum, post.view.col })
    end
end

return M
