local change_utils = require("mjm.spec-ops.change-utils")
local get_utils = require("mjm.spec-ops.get-utils")
local op_utils = require("mjm.spec-ops.op-utils")
local reg_utils = require("mjm.spec-ops.reg-utils")

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
    -- TODO: When moving this into substitute, just copy the logic over. Should just work. Make
    -- sure the dot-repeat issue is fixed. Then create an individualized version for yank with
    -- an option, then create the abstraction for all three
    vim.keymap.set("o", "<Plug>(SpecOpsChangeWord)", function()
        local cpoptions = vim.api.nvim_get_option_value("cpoptions", { scope = "local" })
        if not (is_changing and cpoptions:find("_")) then
            return "w"
        end

        is_changing = false

        local col_1 = vim.api.nvim_win_get_cursor(0)[2] + 1
        op_state.start_line_pre = vim.api.nvim_get_current_line()
        local start_line = op_state.start_line_pre

        local on_space = vim.fn.matchstr(start_line, "\\%" .. col_1 .. "c\\s"):len() > 0
        if on_space and vim.v.count1 <= 1 then
            return "w"
        end

        local on_keyword = vim.fn.matchstr(start_line, "\\%" .. col_1 .. "c\\k"):len() > 0
        local next_keyword = vim.fn.matchstr(start_line, "\\%" .. (col_1 + 1) .. "c\\k"):len() > 0
        local next_space = vim.fn.matchstr(start_line, "\\%" .. (col_1 + 1) .. "c\\s"):len() > 0

        local double_keyword = on_keyword and next_keyword
        local double_non_keyword = not (on_keyword or next_keyword or next_space)
        if double_keyword or double_non_keyword then
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

        local col_1 = vim.api.nvim_win_get_cursor(0)[2] + 1
        op_state.start_line_pre = vim.api.nvim_get_current_line()
        local start_line = op_state.start_line_pre

        local on_char = vim.fn.matchstr(start_line, "\\%" .. col_1 .. "c\\S"):len() > 0
        local next_char = vim.fn.matchstr(start_line, "\\%" .. (col_1 + 1) .. "c\\S"):len() > 0

        if on_char and next_char then
            return "E"
        end

        if vim.v.count1 > 1 then
            return "<esc>g@" .. vim.v.count1 - 1 .. "E"
        end

        return "l"
    end, { expr = true })

    local line_obj = "<Plug>(SpecOpsChangeLineObject)"
    vim.keymap.set("o", line_obj, function()
        if not is_changing then
            return "<esc>"
        end

        is_changing = false
        return "_" -- dd/yy/cc internal behavior
    end, { expr = true })

    local change_op = "<Plug>(SpecOpsChangeOperator)"
    vim.keymap.set("n", change_op, function()
        return operator()
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
        local err = "do_change: " .. (err_c or "Unknown error at change sub-function")
        return vim.notify(err, vim.log.levels.ERROR)
    end

    local marks_post = op_state.marks_post --- @type op_marks
    vim.api.nvim_win_set_cursor(0, { marks_post.start.row, marks_post.start.col })

    if should_yank(op_state.lines) then
        reg_utils.get_reg_info(op_state)
        reg_utils.set_reges(op_state)
    end

    -- NOTE: This cannot be handled purely through marks because of one column lines. Rather than
    -- add branching logic to shared functions, centralize all behavior here (especially so since
    -- change is the only operator that needs this bookkeeping)
    -- MAYBE: Move the block change mark adjustments here as well. Though I can imagine those
    -- being hypothetically useful in other contexts
    if op_state.motion == "line" then
        -- Just run cc to handle adding/removing indentation and avoid making an autocmd
        -- x to run out the typeahead and avoid weird flickering
        vim.api.nvim_feedkeys('"_cc', "nix!", false)
        return
    end

    local start_line_post = op_state.start_line_post
    local start_charlen_post = vim.fn.strcharlen(start_line_post)
    local start_charidx_post = vim.fn.charidx(start_line_post, marks_post.start.col)
    local start_end_post = start_charidx_post == start_charlen_post - 1

    local start_char_post = vim.fn.strcharpart(start_line_post, start_charidx_post, 1, true)
    local start_iskeyword_post = (function()
        if vim.fn.matchstr(start_char_post, "\\%" .. 1 .. "c\\k"):len() > 0 then
            return true
        -- Assuming that more non-keywords want to insert before than after
        -- MAYBE: Could add "_" for users that remove it. But I'd prefer to add exceptions based on
        -- default behavior or real-world use-cases
        elseif vim.tbl_contains({ ".", " " }, start_char_post) then
            return true
        else
            return false
        end
    end)()

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
