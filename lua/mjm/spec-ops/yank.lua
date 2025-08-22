local get_utils = require("mjm.spec-ops.get-utils")
local op_utils = require("mjm.spec-ops.op-utils")
local reg_utils = require("mjm.spec-ops.reg-utils")
local shared = require("mjm.spec-ops.shared")

local M = {}

local is_yanking = false --- @type boolean
local ofunc = "v:lua.require'mjm.spec-ops.yank'.yank_callback"
local op_state = nil --- @type op_state

-- TODO: cw/cW behavior would actually work here. Do in Substitute first though so we can see how
-- the generalization builds out. Needs to be a configurable flag on setup

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

    local hl_group = "SpecOpsYank" --- @type string
    vim.api.nvim_set_hl(0, hl_group, { link = "IncSearch", default = true })
    local hl_ns = vim.api.nvim_create_namespace("mjm.spec-ops.highlight") --- @type integer
    local hl_timeout = 175 --- @type integer

    op_state = op_utils.get_new_op_state(hl_group, hl_ns, hl_timeout, reg_handler, "y")

    -- TODO: It feels like the flag could be stored in op_state, as you need a generalized
    -- way to be able to call linewise ops. Though paste is an uncomfortable exception. You could
    -- then use a closure to make sure the autocmd can update the flag
    -- For the paste case, just make sure the option exists to not create the flag
    -- You can then specify the group name in the setup. One issue here though is, this does
    -- make the flag public, which it really should not be. This probably points then to
    -- making a generalizable internal op state. But since we don't have data passing issues there,
    -- that should wait a while
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

-- Lifted from echasnovski's mini.operators
-- TODO: Inconsistent behavior. If I do a yank after a delete, it doesn't properly cancel
-- the Redo, but if I do it after a paste it does
-- I also notice that, if I do the cancel after a default delete, it works, but not if I do it
-- after a spec-ops delete
local cancel_redo = (function()
    local has_ffi, ffi = pcall(require, "ffi")
    if not has_ffi then
        return function() end
    end

    local has_cancel_redo = pcall(ffi.cdef, "void CancelRedo(void)")
    if not has_cancel_redo then
        return function() end
    end

    return function()
        pcall(ffi.C.CancelRedo)
    end
end)()

local function do_yank()
    vim.api.nvim_win_set_cursor(0, { op_state.view.lnum, op_state.view.col })

    local ok, err = get_utils.do_state_get(op_state) --- @type boolean|nil, nil|string
    if (not ok) or err then
        return vim.notify(err or "Unknown error in do_get", vim.log.levels.ERROR)
    end

    reg_utils.get_reg_info(op_state)
    if not reg_utils.set_reges(op_state) then
        return
    end

    local cpoptions = vim.api.nvim_get_option_value("cpoptions", { scope = "local" })
    if not cpoptions:find("y") then
        cancel_redo()
    end

    shared.highlight_text(op_state)
end

--- @param motion string
function M.yank_callback(motion)
    op_utils.set_op_state_cb(op_state, motion)
    do_yank()
    op_utils.cleanup_op_state(op_state)
end

return M
