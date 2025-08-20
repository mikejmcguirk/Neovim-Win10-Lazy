local get_utils = require("mjm.spec-ops.get-utils")
local op_utils = require("mjm.spec-ops.op-utils")
local reg_utils = require("mjm.spec-ops.reg-utils")
local shared = require("mjm.spec-ops.shared")
local utils = require("mjm.spec-ops.utils")

local M = {}

local is_yanking = false --- @type boolean
local op_state = nil --- @type op_state
local ofunc = "v:lua.require'mjm.spec-ops.yank'.yank_callback"

local function operator()
    is_yanking = true
    op_utils.set_op_state_pre(op_state)
    vim.api.nvim_set_option_value("operatorfunc", ofunc, { scope = "global" })
    return "g@"
end

local function visual()
    op_utils.set_op_state_pre(op_state)
    vim.api.nvim_set_option_value("operatorfunc", ofunc, { scope = "global" })
    return "g@"
end

local function eol()
    op_utils.set_op_state_pre(op_state)
    vim.api.nvim_set_option_value("operatorfunc", ofunc, { scope = "global" })
    return "g@$"
end

function M.setup(opts)
    opts = opts or {}

    local reg_handler = opts.reg_handler or reg_utils.get_handler()
    op_state = op_utils.get_new_op_state(reg_handler, "y")

    vim.api.nvim_create_autocmd("ModeChanged", {
        group = vim.api.nvim_create_augroup("spec-ops_yank-flag", { clear = true }),
        pattern = "no*",
        callback = function()
            is_yanking = false
        end,
    })

    vim.keymap.set("n", "<Plug>(SpecOpsYankOperator)", function()
        return operator()
    end, { expr = true })

    vim.keymap.set("o", "<Plug>(SpecOpsYankLineObject)", function()
        if not is_yanking then
            return "<esc>"
        end

        is_yanking = false
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

local function do_yank()
    local post = op_state.post

    local err = get_utils.do_state_get(op_state) --- @type string|nil
    if (not post.lines) or err then
        return vim.notify(err or "Unknown error in do_get", vim.log.levels.ERROR)
    end

    post.reg_info = post.reg_info or reg_utils.get_reg_info(op_state)
    if not reg_utils.set_reges(op_state) then
        return
    end

    vim.api.nvim_win_set_cursor(0, { post.view.lnum, post.view.col })
    vim.api.nvim_exec_autocmds("TextYankPost", {
        buffer = vim.api.nvim_get_current_buf(),
        data = {
            inclusive = true,
            operator = "y",
            regcontents = post.lines,
            regname = post.reg,
            regtype = utils.regtype_from_motion(post.motion),
            visual = post.vmode,
        },
    })

    -- TODO: This should just take op_state as well, but don't want to disrupt other ops at
    -- the moment
    local reg_type = vim.fn.getregtype(post.reg) --- @type string
    shared.highlight_text(post.marks, hl_group, hl_ns, hl_timer, reg_type)
end

--- @param motion string
function M.yank_callback(motion)
    op_utils.set_op_state_post(op_state, motion)
    do_yank()
    op_utils.cleanup_op_state(op_state)
end

return M
