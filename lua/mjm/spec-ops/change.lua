-- TODO: Get a session manager or something. We are doing a lot of closing and re-opening
-- to the same state in order to refresh code changes

local blk_utils = require("mjm.spec-ops.block-utils")
local change_utils = require("mjm.spec-ops.change-utils")
local get_utils = require("mjm.spec-ops.get-utils")
local op_utils = require("mjm.spec-ops.op-utils")
local utils = require("mjm.spec-ops.utils")

local M = {}

local op_state = op_utils.create_new_op_state() --- @type op_state
local cb_state = op_utils.create_new_op_state() --- @type op_state

local op_in_change = false --- @type boolean

vim.api.nvim_create_autocmd("ModeChanged", {
    group = vim.api.nvim_create_augroup("spec-ops_change-flag", { clear = true }),
    pattern = "no*",
    callback = function()
        op_in_change = false
    end,
})

local function operator()
    op_utils.update_op_state(op_state)
    op_in_change = true
    vim.o.operatorfunc = "v:lua.require'mjm.spec-ops.change'.change_callback"
    return "g@"
end

local function visual()
    op_utils.update_op_state(op_state)
    vim.o.operatorfunc = "v:lua.require'mjm.spec-ops.change'.change_callback"
    return "g@"
end

local function eol()
    op_utils.update_op_state(op_state)
    vim.o.operatorfunc = "v:lua.require'mjm.spec-ops.change'.change_callback"
    return "g@$"
end

--- @param text string
--- @return boolean
local function should_yank(text)
    return string.match(text, "%S")
end

--- @param motion string
function M.change_callback(motion)
    op_utils.update_cb_from_op(op_state, cb_state, motion)

    local marks = utils.get_marks(motion, cb_state.vmode) --- @type op_marks

    -- TODO: Shouldn't be running the get at all if we don't need to, either due to using the
    -- black hole register or a config option. Does raise semi-interesting question. For users
    -- who don't want change/delete to yank at all, do you provide a config option
    -- or just have them use black hole mappings? I think the move is to do the black hole
    -- check early and push that way. Otherwise you have to do checks for both a config
    -- option and the black hole map, which is wasteful

    --- @diagnostic disable: undefined-field
    local yank_lines, err_y = get_utils.do_get({
        marks = marks,
        curswant = cb_state.view.curswant,
        motion = motion,
    }) --- @type string[]|nil, string|nil

    if (not yank_lines) or err_y then
        local err_msg = err_y or "Unknown error getting text to yank" --- @type string
        return vim.notify("change_callback: " .. err_msg, vim.log.levels.ERROR)
    end

    -- TODO: Not sure any of this should be happening unless the delete is successful. An
    -- unsuccessful delete should roll back the whole process

    --- @type string
    local text = table.concat(yank_lines, "\n") .. (motion == "line" and "\n" or "")
    -- TODO: Architecturally, this broadly makes sense. The user specified condition is distinct
    -- from the built-in notion that selecting the black hole register needs no yank. More broadly
    -- though, how the yank behavior operates would also dependon if the user selects ring,
    -- default, target only, or some other thing. Find to leave as is for now, but might be
    -- changed
    if should_yank(text) and cb_state.reg ~= "_" then
        if motion == "block" then
            vim.fn.setreg(cb_state.reg, text, "b" .. blk_utils.get_block_reg_width(yank_lines))
        else
            vim.fn.setreg(cb_state.reg, text)
        end

        vim.api.nvim_exec_autocmds("TextYankPost", {
            buffer = vim.api.nvim_get_current_buf(),
            data = {
                inclusive = true,
                operator = "y",
                regcontents = yank_lines,
                regname = cb_state.reg,
                regtype = utils.regtype_from_motion(motion),
                visual = cb_state.vmode,
            },
        })
    end

    -- TODO: This feels way too complicated for what it's doing
    -- The root issue, I think, is we're borrowing other functions to set up the marks. It should
    -- be possible to calculate what to do from the end marks, but we can't reliably do that.
    -- Yet another architecture thing I will defer for now. We could, for block ops, determine
    -- whether or not to insert after based on if the change marks match the end of a line, because
    -- we have that setup already. But the set marks are based on either sets or deletes (can't
    -- remember which) and we're grafting around them. For the set case, if you don't select to
    -- the end of the line, you shouldn't mark to it. A benefit here is that, in a normal cut,
    -- you get marks after leaving insert mode, which is automatic, so we can make the intermediate
    -- marks whatever we need
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
            if cb_state.view.curswant >= #l - 1 then
                return true
            end

            return false
        end
    end)()

    local post_marks, err_d = change_utils.do_change({
        marks = marks,
        motion = motion,
        curswant = cb_state.view.curswant,
        visual = cb_state.vmode,
    }) --- @type op_marks|nil, string|nil

    if (not post_marks) or err_d then
        local err_msg = err_d or "Unknown error at delete callback"
        return vim.notify("delete_callback: " .. err_msg, vim.log.levels.ERROR)
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

vim.keymap.set("n", "<Plug>(SpecOpsChangeOperator)", function()
    return operator()
end, { expr = true })

vim.keymap.set("o", "<Plug>(SpecOpsChangeLineObject)", function()
    if not op_in_change then
        return "<esc>"
    end

    op_in_change = false
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

vim.keymap.set("n", "c", "<Plug>(SpecOpsChangeOperator)")
vim.keymap.set("o", "c", "<Plug>(SpecOpsChangeLineObject)")
vim.keymap.set("x", "c", "<Plug>(SpecOpsChangeVisual)")
vim.keymap.set("n", "C", "<Plug>(SpecOpsChangeEol)")

vim.keymap.set("x", "C", "<nop>")

-- Helix style black hole mappings
vim.keymap.set("n", "<M-c>", '"_<Plug>(SpecOpsChangeOperator)')
vim.keymap.set("x", "<M-c>", '"_<Plug>(SpecOpsChangeVisual)')
vim.keymap.set("n", "<M-C>", '"_<Plug>(SpecOpsChangeEol)')

return M
