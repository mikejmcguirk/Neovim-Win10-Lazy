local del_utils = require("mjm.spec-ops.del-utils")
local get_utils = require("mjm.spec-ops.get-utils")
local op_utils = require("mjm.spec-ops.op-utils")
local reg_utils = require("mjm.spec-ops.reg-utils")

local M = {}

local op_state = nil --- @type op_state
local is_deleting = false --- @type boolean
local ofunc = "v:lua.require'mjm.spec-ops.delete'.delete_callback" --- @type string

local function operator()
    op_utils.set_op_state_pre(op_state)
    is_deleting = true
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
    op_state = op_utils.get_new_op_state(nil, nil, nil, reg_handler, "d")

    vim.api.nvim_create_autocmd("ModeChanged", {
        group = vim.api.nvim_create_augroup("spec-ops_del-flag", { clear = true }),
        pattern = "no*",
        callback = function()
            is_deleting = false
        end,
    })

    vim.keymap.set("n", "<Plug>(SpecOpsDeleteOperator)", function()
        return operator()
    end, { expr = true })

    vim.keymap.set("o", "<Plug>(SpecOpsDeleteLineObject)", function()
        if not is_deleting then
            return "<esc>"
        end

        is_deleting = false
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

-- TODO: Current "should yank" criteria means dlp does not work on a space
-- TODO: Very obviously then, the various handlers should all be added to state so they can be
-- moved around fluidly

--- @param lines string[]
--- @return boolean
local function should_yank(lines)
    for _, line in pairs(lines) do
        if string.match(line, "%S") then
            return true
        end
    end

    return false
end

local function do_delete()
    local ok_y, err_y = get_utils.do_state_get(op_state) --- @type boolean|nil, nil|string
    if (not ok_y) or err_y then
        return vim.notify(err_y or "Unknown error in do_get", vim.log.levels.ERROR)
    end

    local err_d = del_utils.do_del(op_state) --- @type string|nil
    if err_d then
        local err = "do_delete: " .. (err_d or "Unknown error at delete callback")
        return vim.notify(err, vim.log.levels.ERROR)
    end

    local marks_post = op_state.marks_post --- @type op_marks
    vim.api.nvim_win_set_cursor(0, { marks_post.start.row, marks_post.start.col })

    if not should_yank(op_state.lines) then
        return
    end

    reg_utils.get_reg_info(op_state)
    reg_utils.set_reges(op_state)
end

--- @param motion string
function M.delete_callback(motion)
    op_utils.set_op_state_cb(op_state, motion)
    do_delete()
    op_utils.cleanup_op_state(op_state)
end

return M
