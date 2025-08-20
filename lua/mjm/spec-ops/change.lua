local blk_utils = require("mjm.spec-ops.block-utils")
local change_utils = require("mjm.spec-ops.change-utils")
local get_utils = require("mjm.spec-ops.get-utils")
local op_utils = require("mjm.spec-ops.op-utils")
local reg_utils = require("mjm.spec-ops.reg-utils")
local utils = require("mjm.spec-ops.utils")

local M = {}

local reg_handler = nil ---@type fun( ctx: reg_handler_ctx): string[]
local op_state = op_utils.get_new_op_state() --- @type op_state

local is_changing = false --- @type boolean

vim.api.nvim_create_autocmd("ModeChanged", {
    group = vim.api.nvim_create_augroup("spec-ops_change-flag", { clear = true }),
    pattern = "no*",
    callback = function()
        is_changing = false
    end,
})

local function operator()
    op_utils.set_op_state_pre(op_state)
    is_changing = true
    vim.o.operatorfunc = "v:lua.require'mjm.spec-ops.change'.change_callback"
    return "g@"
end

local function visual()
    op_utils.set_op_state_pre(op_state)
    vim.o.operatorfunc = "v:lua.require'mjm.spec-ops.change'.change_callback"
    return "g@"
end

local function eol()
    op_utils.set_op_state_pre(op_state)
    vim.o.operatorfunc = "v:lua.require'mjm.spec-ops.change'.change_callback"
    return "g@$"
end

function M.setup(opts)
    opts = opts or {}

    reg_handler = opts.reg_handler or reg_utils.get_handler()

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

--- @param text string
--- @return boolean
local function should_yank(text)
    return string.match(text, "%S")
end

--- @param motion string
function M.change_callback(motion)
    op_utils.set_op_state_post(op_state, motion)
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
        return vim.notify("change_callback: " .. err_msg, vim.log.levels.ERROR)
    end

    local insert_after = (function()
        local buf_lines = vim.api.nvim_buf_get_lines(0, marks.start.row - 1, marks.fin.row, false)
        local fin_line_len = math.max(#buf_lines[#buf_lines] - 1, 0)
        if marks.fin.col >= fin_line_len then
            return true
        end

        if motion ~= "block" then
            return false
        end

        for _, l in pairs(buf_lines) do
            if post.view.curswant >= #l - 1 then
                return true
            end

            return false
        end
    end)() --- @type boolean

    local post_marks, err_d = change_utils.do_change({
        marks = marks,
        motion = motion,
        curswant = post.view.curswant,
        visual = post.vmode,
    }) --- @type op_marks|nil, string|nil

    if (not post_marks) or err_d then
        local err_msg = err_d or "Unknown error at delete callback"
        return vim.notify("delete_callback: " .. err_msg, vim.log.levels.ERROR)
    end

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

    vim.api.nvim_win_set_cursor(0, { post_marks.start.row, post_marks.start.col })

    if motion == "line" then
        -- cc both automatically adds indentation and removes it if nothing's typed after
        -- x to run out the typeahead and avoid weird flickering
        -- ! to stay in insert mode
        vim.api.nvim_feedkeys('"_cc', "nix!", false)
    elseif motion == "block" then
        if insert_after then
            vim.api.nvim_feedkeys("`[\22`]A", "nix!", false)
        else
            vim.api.nvim_feedkeys("`[\22`]I", "nix!", false)
        end
    else
        if insert_after then
            vim.cmd("startinsert!")
        else
            vim.cmd("startinsert")
        end
    end
end

return M
