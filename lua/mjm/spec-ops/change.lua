local blk_utils = require("mjm.spec-ops.block-utils")
local change_utils = require("mjm.spec-ops.change-utils")
local get_utils = require("mjm.spec-ops.get-utils")
local op_utils = require("mjm.spec-ops.op-utils")
local reg_utils = require("mjm.spec-ops.reg-utils")
local utils = require("mjm.spec-ops.utils")

local M = {}

local op_state = nil --- @type op_state
local is_changing = false --- @type boolean
local ofunc = "v:lua.require'mjm.spec-ops.change'.change_callback" --- @type string

local function operator()
    op_utils.set_op_state_pre(op_state)
    is_changing = true
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
    op_state = op_utils.get_new_op_state(reg_handler, "d")

    vim.api.nvim_create_autocmd("ModeChanged", {
        group = vim.api.nvim_create_augroup("spec-ops_change-flag", { clear = true }),
        pattern = "no*",
        callback = function()
            is_changing = false
        end,
    })

    vim.keymap.set("n", "<Plug>(SpecOpsChangeOperator)", function()
        return operator()
    end, { expr = true })

    vim.keymap.set("o", "<Plug>(SpecOpsChangeLineObject)", function()
        if not is_changing then
            return "<esc>"
        end

        is_changing = false
        return "_" -- dd/yy/cc internal behavior
    end, { expr = true })

    vim.keymap.set(
        "n",
        "<Plug>(SpecOpsChangeLine)",
        "<Plug>(SpecOpsChangeOperator)<Plug>(SpecOpsChangeLineObject)"
    )

    vim.keymap.set("n", "<Plug>(SpecOpsChangeEol)", function()
        return eol()
    end, { expr = true })

    vim.keymap.set("x", "<Plug>(SpecOpsChangeVisual)", function()
        return visual()
    end, { expr = true })
end

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

local function do_change()
    local post = op_state.post

    local err_y = get_utils.do_state_get(op_state) --- @type string|nil
    if (not post.lines) or err_y then
        local err = "do_delete: " .. (err_y or "Unknown error at do_get")
        return vim.notify(err, vim.log.levels.ERROR)
    end

    local ok, err_c = change_utils.do_change(op_state) --- @type boolean|nil, string|nil
    if not ok then
        local err = "do_delete: " .. (err_c or "Unknown error at delete callback")
        return vim.notify(err, vim.log.levels.ERROR)
    end

    local marks_after = op_state.post.marks_after --- @type op_marks
    vim.api.nvim_win_set_cursor(0, { marks_after.start.row, marks_after.start.col })

    if should_yank(post.lines) then
        post.reg_info = post.reg_info or reg_utils.get_reg_info(op_state)
        if not reg_utils.set_reges(op_state) then
            return
        end

        -- TODO: roll the autocmd up into set_reges
        vim.api.nvim_exec_autocmds("TextYankPost", {
            buffer = vim.api.nvim_get_current_buf(),
            data = {
                inclusive = true,
                operator = "d",
                regcontents = post.lines,
                regname = post.reg,
                regtype = utils.regtype_from_motion(post.motion),
                visual = post.vmode,
            },
        })
    end

    if op_state.post.motion == "line" then
        -- cc both automatically adds indentation and removes it if nothing's typed after
        -- x to run out the typeahead and avoid weird flickering
        -- ! to stay in insert mode
        vim.api.nvim_feedkeys('"_cc', "nix!", false)
        return
    end

    local start_end = (function()
        if #op_state.start_line_post == 0 then
            return false
        else
            local len = vim.fn.strcharlen(op_state.start_line_post)
            local char_idx =
                vim.fn.charidx(op_state.start_line_post, op_state.post.marks_after.start.col)

            return char_idx == len - 1
        end
    end)()

    if op_state.post.motion == "char" then
        if start_end then
            vim.cmd("startinsert!")
        else
            vim.cmd("startinsert")
        end

        return
    end

    local fin_end = (function()
        if #op_state.fin_line_post == 0 then
            return false
        else
            local len = vim.fn.strcharlen(op_state.fin_line_post)
            local char_idx =
                vim.fn.charidx(op_state.fin_line_post, op_state.post.marks_after.fin.col)

            return char_idx == len - 1
        end
    end)()

    if start_end or fin_end then
        vim.api.nvim_feedkeys("`[\22`]A", "nix!", false)
    else
        vim.api.nvim_feedkeys("`[\22`]I", "nix!", false)
    end
end

--- @param motion string
function M.change_callback(motion)
    op_utils.set_op_state_post(op_state, motion)
    do_change()
    op_utils.cleanup_op_state(op_state)
end

return M
