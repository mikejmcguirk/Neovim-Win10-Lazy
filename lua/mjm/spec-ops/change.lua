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

-- TODO: Since we need to get the start line here anyway, it should be packed away in op_state
-- for future use

local function is_at_end_of_cword()
    local pos = vim.api.nvim_win_get_cursor(0)
    local col = pos[2] + 1
    local line = vim.api.nvim_get_current_line()
    local cur_match = vim.fn.matchstr(line, "\\%" .. col .. "c\\k"):len() > 0
    local next_match = vim.fn.matchstr(line, "\\%" .. (col + 1) .. "c\\k"):len() > 0
    return cur_match and not next_match
end

local function is_at_end_of_cWORD()
    local pos = vim.api.nvim_win_get_cursor(0)
    local col = pos[2] + 1
    local line = vim.api.nvim_get_current_line()
    local cur_match = vim.fn.matchstr(line, "\\%" .. col .. "c\\S"):len() > 0
    local next_match = vim.fn.matchstr(line, "\\%" .. (col + 1) .. "c\\S"):len() > 0
    return cur_match and not next_match
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

    -- TODO: Still existing problem case: Because is_changing is not set on dot-repeat, the
    -- special case logic does not trigger when the motion is re-run. This is acceptable for now
    -- while I'm still working through the state management
    vim.keymap.set("o", "<Plug>(SpecOpsChangeWord)", function()
        local cpoptions = vim.api.nvim_get_option_value("cpoptions", { scope = "local" })
        if not (is_changing and cpoptions:find("_")) then
            return "w"
        end

        is_changing = false

        if not is_at_end_of_cword() then
            return "e"
        end

        -- Somewhat like echasnovski's redraw hack
        if vim.v.count1 > 1 then
            return "<esc>g@" .. vim.v.count1 - 1 .. "e"
        end

        return "l"
    end, { expr = true })

    vim.keymap.set("o", "<Plug>(SpecOpsChangeWORD)", function()
        local cpoptions = vim.api.nvim_get_option_value("cpoptions", { scope = "local" })

        if not (is_changing and cpoptions:find("_")) then
            return "W"
        end

        is_changing = false

        if not is_at_end_of_cWORD() then
            return "E"
        end

        if vim.v.count1 > 1 then
            return "<esc>g@" .. vim.v.count1 - 1 .. "E"
        end

        return "l"
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
    local err_y = get_utils.do_state_get(op_state) --- @type string|nil
    if (not op_state.lines) or err_y then
        local err = "do_delete: " .. (err_y or "Unknown error at do_get")
        return vim.notify(err, vim.log.levels.ERROR)
    end

    local ok, err_c = change_utils.do_change(op_state) --- @type boolean|nil, string|nil
    if not ok then
        local err = "do_delete: " .. (err_c or "Unknown error at delete callback")
        return vim.notify(err, vim.log.levels.ERROR)
    end

    local marks_after = op_state.marks_post --- @type op_marks
    vim.api.nvim_win_set_cursor(0, { marks_after.start.row, marks_after.start.col })

    if should_yank(op_state.lines) then
        op_state.reg_info = op_state.reg_info or reg_utils.get_reg_info(op_state)
        if not reg_utils.set_reges(op_state) then
            return
        end

        -- TODO: roll the autocmd up into set_reges
        vim.api.nvim_exec_autocmds("TextYankPost", {
            buffer = vim.api.nvim_get_current_buf(),
            data = {
                inclusive = true,
                operator = "d",
                regcontents = op_state.lines,
                regname = op_state.vreg,
                regtype = utils.regtype_from_motion(op_state.motion),
                visual = op_state.vmode,
            },
        })
    end

    if op_state.motion == "line" then
        -- cc both automatically adds indentation and removes it if nothing's typed after
        -- x to run out the typeahead and avoid weird flickering
        -- ! to stay in insert mode
        vim.api.nvim_feedkeys('"_cc', "nix!", false)
        return
    end

    -- TODO: :h cw - Re-create this behavior
    -- cpoptions _ is what makes it happen

    local start_end = (function()
        if #op_state.start_line_post == 0 then
            return false
        else
            local len = vim.fn.strcharlen(op_state.start_line_post)
            local char_idx =
                vim.fn.charidx(op_state.start_line_post, op_state.marks_post.start.col)

            return char_idx == len - 1
        end
    end)()

    if op_state.motion == "char" then
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
            local char_idx = vim.fn.charidx(op_state.fin_line_post, op_state.marks_post.fin.col)

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
    op_utils.set_op_state_cb(op_state, motion)
    do_change()
    op_utils.cleanup_op_state(op_state)
end

return M
