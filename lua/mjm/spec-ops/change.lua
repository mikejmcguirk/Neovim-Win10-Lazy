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

-- TODO: still need to check if next is a space
-- if you're at the end of a cWord and the next char is a space, l
-- If you're at the end of a non-keyword and the next char begins a keyword, l or w
-- if you're at the end of a keyword and the next char is a non-keyword, w or l
-- Basically you need to know what your cur and next chars are, like if they're keywords or not
-- because that does determine what to do
-- TODO: Sloppy
local function is_at_end_of_cword()
    local pos = vim.api.nvim_win_get_cursor(0)
    local col = pos[2] + 1
    op_state.start_line_pre = vim.api.nvim_get_current_line()
    -- local cur_match = vim.fn.matchstr(op_state.start_line_pre, "\\%" .. col .. "c\\k"):len() > 0
    local next_match = vim.fn.matchstr(op_state.start_line_pre, "\\%" .. (col + 1) .. "c\\k"):len()
        > 0
    local next_match_space = vim.fn
        .matchstr(op_state.start_line_pre, "\\%" .. (col + 1) .. "c\\S")
        :len() > 0
    -- return cur_match and not next_match
    return not next_match
end

-- TODO: Sloppy
local function is_at_end_of_cWORD()
    local pos = vim.api.nvim_win_get_cursor(0)
    local col = pos[2] + 1
    op_state.start_line_pre = vim.api.nvim_get_current_line()
    local cur_match = vim.fn.matchstr(op_state.start_line_pre, "\\%" .. col .. "c\\S"):len() > 0
    local next_match = vim.fn.matchstr(op_state.start_line_pre, "\\%" .. (col + 1) .. "c\\S"):len()
        > 0
    return cur_match and not next_match
end

function M.setup(opts)
    opts = opts or {}

    local reg_handler = opts.reg_handler or reg_utils.get_handler()
    op_state = op_utils.get_new_op_state(nil, nil, nil, reg_handler, "d")

    vim.api.nvim_create_autocmd("ModeChanged", {
        group = vim.api.nvim_create_augroup("spec-ops_change-flag", { clear = true }),
        pattern = "no*",
        callback = function()
            is_changing = false
        end,
    })

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

    local change_op = "<Plug>(SpecOpsChangeOperator)"
    vim.keymap.set("n", change_op, function()
        return operator()
    end, { expr = true })

    local line_obj = "<Plug>(SpecOpsChangeLineObject)"
    vim.keymap.set("o", line_obj, function()
        if not is_changing then
            return "<esc>"
        end

        is_changing = false
        return "_" -- dd/yy/cc internal behavior
    end, { expr = true })

    -- TODO: do this in other ops
    vim.keymap.set("n", "<Plug>(SpecOpsChangeLine)", change_op .. line_obj)

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
    local ok_y, err_y = get_utils.do_state_get(op_state) --- @type boolean|nil, nil|string
    if (not ok_y) or err_y then
        return vim.notify(err_y or "Unknown error in do_get", vim.log.levels.ERROR)
    end

    local ok_c, err_c = change_utils.do_change(op_state) --- @type boolean|nil, string|nil
    if not ok_c then
        local err = "do_delete: " .. (err_c or "Unknown error at delete callback")
        return vim.notify(err, vim.log.levels.ERROR)
    end

    local marks_post = op_state.marks_post --- @type op_marks
    vim.api.nvim_win_set_cursor(0, { marks_post.start.row, marks_post.start.col })

    if should_yank(op_state.lines) then
        op_state.reg_info = op_state.reg_info or reg_utils.get_reg_info(op_state)
        -- TODO: This one still doesn't go to the end. 5cw just after the period
        if not reg_utils.set_reges(op_state) then
            return
        end

        -- TODO: roll the autocmd up into set_reges
        vim.api.nvim_exec_autocmds("TextYankPost", {
            buffer = vim.api.nvim_get_current_buf(),
            data = {
                inclusive = true,
                operator = "c",
                regcontents = op_state.lines,
                regname = op_state.vreg,
                regtype = utils.regtype_from_motion(op_state.motion),
                visual = op_state.vmode,
            },
        })
    end

    -- TODO: If you cw, or maybe ciw, to the end of a line where the last character is a cword
    -- delimiter, it will delete up to but not including that character (correct) but then insert
    -- after since the change mark sets on the last character. Not totally sure how to deal
    -- with this either because the undeleted char does move to where the start of the change is
    --
    if op_state.motion == "line" then
        -- cc both automatically adds indentation and removes it if nothing's typed after
        -- x to run out the typeahead and avoid weird flickering
        -- ! to stay in insert mode
        vim.api.nvim_feedkeys('"_cc', "nix!", false)
        return
    end

    local start_charlen_post = vim.fn.strcharlen(op_state.start_line_post)
    local start_charidx_post =
        vim.fn.charidx(op_state.start_line_post, op_state.marks_post.start.col)
    local start_end_post = start_charidx_post == start_charlen_post - 1

    local start_char_post =
        vim.fn.strcharpart(op_state.start_line_post, start_charidx_post, 1, true)
    local start_iskeyword_post = vim.fn.matchstr(start_char_post, "\\%" .. 1 .. "c\\k"):len() > 0
    -- Assuming that more non-keywords want to insert before than after
    if (not start_iskeyword_post) and vim.tbl_contains({ "." }, start_char_post) then
        start_iskeyword_post = true
    end

    -- if start_iskeyword_post then
    --     vim.fn.confirm("is keyboard: " .. start_char_post)
    -- else
    --     vim.fn.confirm("not keyboard: " .. start_char_post)
    -- end

    if op_state.motion == "char" then
        if start_end_post and start_iskeyword_post then
            vim.cmd("startinsert!")
        else
            vim.cmd("startinsert")
        end

        return
    end

    local start_charlen_pre = vim.fn.strcharlen(op_state.start_line_pre)
    local start_charidx_pre = vim.fn.charidx(op_state.start_line_pre, op_state.marks.start.col)
    local start_end_pre = start_charidx_pre == start_charlen_pre - 1
    local fin_charlen_pre = vim.fn.strcharlen(op_state.fin_line_pre)
    local fin_charidx_pre = vim.fn.charidx(op_state.fin_line_pre, op_state.marks.fin.col)
    local fin_end_pre = fin_charidx_pre == fin_charlen_pre - 1

    if start_end_pre or fin_end_pre then
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
