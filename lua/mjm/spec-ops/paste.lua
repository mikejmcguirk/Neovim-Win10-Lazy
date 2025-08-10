-- TODO: Handle gp and zp
-- TODO: Alternative cursor options
-- - Norm single line char after: Hold cursor
-- - Norm single line char before: Either hold or beginning of pasted text
-- - Norm multiline char after: Either hold or end of pasted text
-- - Norm multiline char before: End of pasted text
-- - Norm linewise: Hold cursor

local op_utils = require("mjm.spec-ops.op-utils")
local shared = require("mjm.spec-ops.shared")
local utils = require("mjm.spec-ops.utils")

local M = {}

local hl_group = "SpecOpsPaste" --- @type string
vim.api.nvim_set_hl(0, hl_group, { link = "IncSearch", default = true })
local hl_ns = vim.api.nvim_create_namespace("mjm.spec-ops.paste-highlight") --- @type integer
local hl_timer = 175 --- @type integer

local vcount = 0 --- @type integer
local before = false --- @type boolean

local function paste_norm(opts)
    opts = opts or {}
    before = opts.before

    vim.o.operatorfunc = "v:lua.require'mjm.spec-ops.paste'.paste_norm_callback"
    return "g@l"
end

-- Outlined for architectural purposes
local function should_reindent(ctx)
    ctx = ctx or {}

    if ctx.on_blank or ctx.regtype == "V" then
        return true
    else
        return false
    end
end

--- @return nil
M.paste_norm_callback = function()
    vcount = vim.v.count > 0 and vim.v.count or vcount

    --- @type string
    local reg = utils.is_valid_register(vim.v.register) and vim.v.register
        or utils.get_default_reg()
    local text = vim.fn.getreg(reg) --- @type string
    if (not text) or text == "" then
        return vim.notify(reg .. " register is empty", vim.log.levels.INFO)
    end

    local regtype = vim.fn.getregtype(reg) --- @type string
    local win = vim.api.nvim_get_current_win() --- @type integer
    local cur_pos = vim.api.nvim_win_get_cursor(win) --- @type {[1]: integer, [2]:integer}
    local buf = vim.api.nvim_win_get_buf(win) --- @type integer
    local lines = utils.get_paste_lines(text, vcount, regtype) --- @type string[]

    --- @type string
    local start_line = vim.api.nvim_buf_get_lines(buf, cur_pos[1] - 1, cur_pos[1], false)[1]
    local on_blank = not start_line:match("%S") --- @type boolean

    local marks, err = (function()
        if regtype == "v" then
            return op_utils.paste_chars(cur_pos, before, buf, lines)
        elseif regtype == "V" then
            return op_utils.paste_lines(cur_pos, before, buf, lines)
        else
            return op_utils.norm_paste_block({
                buf = buf,
                cur_pos = cur_pos,
                lines = lines,
                before = before,
            })
        end
    end)() --- @type Marks|nil, string|nil

    if (not marks) or err then
        return "paste_norm: " .. (err or ("Unknown error in " .. regtype .. " paste"))
    end

    if should_reindent({ on_blank = on_blank, regtype = regtype }) then
        marks = utils.fix_indents(marks, win, cur_pos, buf)
    end

    --- @type boolean
    local is_multi_line_char = regtype == "v" and marks.start.row ~= marks.finish.row
    local is_block = regtype:sub(1, 1) == "\22" --- @type boolean
    if is_multi_line_char or is_block then
        vim.api.nvim_win_set_cursor(win, { marks.start.row, marks.start.col })
    elseif regtype == "V" then
        local start_row = marks.start.row --- @type integer
        --- @type string
        local line = vim.api.nvim_buf_get_lines(buf, start_row - 1, start_row, false)[1]
        local first_char = string.find(line, "[^%s]") or 1 --- @type integer
        vim.api.nvim_win_set_cursor(win, { marks.start.row, first_char - 1 })
    else
        vim.api.nvim_win_set_cursor(win, { marks.finish.row, marks.finish.col })
    end

    shared.highlight_text(buf, marks, hl_group, hl_ns, hl_timer, regtype)
end

vim.keymap.set("n", "<Plug>(SpecOpsPasteNormalAfterCursor)", function()
    return paste_norm()
end, { expr = true, silent = true })

vim.keymap.set("n", "<Plug>(SpecOpsPasteNormalBeforeCursor)", function()
    return paste_norm({ before = true })
end, { expr = true, silent = true })

vim.keymap.set("n", "p", "<Plug>(SpecOpsPasteNormalAfterCursor)")
vim.keymap.set("n", "P", "<Plug>(SpecOpsPasteNormalBeforeCursor)")

vim.keymap.set("n", "<M-p>", '"+<Plug>(SpecOpsPasteNormalAfterCursor)')
vim.keymap.set("n", "<M-P>", '"+<Plug>(SpecOpsPasteNormalBeforeCursor)')

return M
