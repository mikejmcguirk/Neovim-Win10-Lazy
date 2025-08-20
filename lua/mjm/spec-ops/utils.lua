local M = {}

--- @class op_marks
--- @field start {row: integer, col: integer}
--- @field fin {row: integer, col: integer}

--- @param motion string
--- @param vmode? boolean
--- @return op_marks
function M.get_marks(motion, vmode)
    --- @type {[1]:integer, [2]:integer}
    local start = vim.api.nvim_buf_get_mark(0, vmode and "<" or "[")
    --- @type {[1]:integer, [2]:integer}
    local fin = vim.api.nvim_buf_get_mark(0, vmode and ">" or "]")
    local marks = {
        start = {
            row = start[1],
            col = start[2],
        },
        fin = {
            row = fin[1],
            col = fin[2],
        },
    } --- @type op_marks

    if motion == "block" then
        return M.sort_marks(marks)
    else
        return marks
    end
end

--- @param marks op_marks
--- @return op_marks
function M.sort_marks(marks)
    if marks.start.row > marks.fin.row then
        return {
            start = {
                row = marks.fin.row,
                col = marks.fin.col,
            },
            fin = {
                row = marks.start.row,
                col = marks.start.col,
            },
        }
    else
        return marks
    end
end

-- TODO: Move to reg file. Wait for all references to only be from it

---@return string
function M.get_default_reg()
    local clipboard = vim.split(vim.api.nvim_get_option_value("clipboard", {}), ",")
    if vim.tbl_contains(clipboard, "unnamedplus") then
        return "+"
    elseif vim.tbl_contains(clipboard, "unnamed") then
        return "*"
    else
        return '"'
    end
end

---@param reg string|nil
---@return boolean, string|nil
function M.is_valid_register(reg)
    if not reg then
        return false, "is_valid_register: No reg provided"
    end

    if type(reg) ~= "string" then
        return false, "is_valid_register: Register " .. reg .. " is not a string"
    end

    if #reg ~= 1 then
        return false, "is_valid_register: " .. reg .. " is more than one character long"
    end

    if not reg:match('["0-9a-zA-Z.*%%:#=+_%-/]') then
        return false, "is_valid_register: Register " .. reg .. " does not match a valid register"
    end

    return true, nil
end

-- TODO: Should be in reg utils

--- @param motion string
--- @return string
function M.regtype_from_motion(motion)
    if motion == "line" then
        return "V"
    elseif motion == "block" then
        return "\22"
    else
        return "v"
    end
end

-- TODO: Should be in reg utils

--- @param regtype string
--- @return boolean
function M.is_valid_regtype(regtype)
    if regtype == "v" or regtype == "V" or regtype:sub(1, 1) == "\22" then
        return true
    else
        return false
    end
end

--- @param cur_pos {[1]: integer, [2]: integer}
--- @param row integer
--- @return integer
function M.get_indent(cur_pos, row)
    local line_count = vim.api.nvim_buf_line_count(0) --- @type integer
    if row < 1 or row > line_count then
        return 0
    end

    local indentexpr = vim.api.nvim_get_option_value("indentexpr", { buf = 0 }) --- @type string
    if indentexpr ~= "" then
        vim.v.lnum = row
        vim.api.nvim_win_set_cursor(0, { row, 0 }) -- For functions getting "."

        local eval = vim.api.nvim_eval(indentexpr) --- @type integer

        vim.v.lnum = cur_pos[1]
        vim.api.nvim_win_set_cursor(0, cur_pos)

        return eval >= 0 and eval or 0
    end

    if vim.api.nvim_get_option_value("cindent", { buf = 0 }) then
        return vim.fn.cindent(row)
    end

    if vim.api.nvim_get_option_value("lisp", { buf = 0 }) then
        return vim.fn.lispindent(row)
    end

    local prev_row = row > 1 and vim.fn.prevnonblank(row - 1) or 0 --- @type integer
    if prev_row == 0 then
        return 0
    end

    --- @type string
    local prev_line = vim.api.nvim_buf_get_lines(0, prev_row - 1, prev_row, false)[1]
    local prev_indent = vim.fn.indent(prev_row) --- @type integer

    --- @type boolean
    local smartindent = vim.api.nvim_get_option_value("smartindent", { buf = 0 })
    if smartindent and prev_line():match("{$") then
        prev_indent = prev_indent + vim.api.nvim_get_option_value("shiftwidth", { buf = 0 })
    end

    return prev_indent
end

local function get_indent_str_function()
    if vim.api.nvim_get_option_value("expandtab", { buf = 0 }) then
        return function(indent)
            return string.rep(" ", indent)
        end
    end

    local tabstop = vim.api.nvim_get_option_value("tabstop", { buf = 0 })
    return function(indent)
        local tabs = math.floor(indent / tabstop)
        local spaces = indent % tabstop

        return string.rep("\t", tabs) .. string.rep(" ", spaces)
    end
end

--- @param cur_pos {[1]: integer, [2]: integer}
--- @param row integer
--- @param str_fn fun(indent: integer): string
--- @return integer
local function apply_indent(cur_pos, row, str_fn)
    local line = vim.api.nvim_buf_get_lines(0, row - 1, row, false)[1]
    if line == "" then
        return 0
    end

    local indent = M.get_indent(cur_pos, row)
    local indent_str = str_fn(indent)

    local leading_ws = line:match("^(%s*)")
    if indent_str == leading_ws then
        return 0
    end

    vim.api.nvim_buf_set_text(0, row - 1, 0, row - 1, #leading_ws, { indent_str })

    return #indent_str - #leading_ws
end

--- @param marks op_marks
--- @param cur_pos {[1]: integer, [2]: integer}
--- @return op_marks
function M.fix_indents(marks, cur_pos)
    local new_marks = marks
    local str_fn = get_indent_str_function()

    for i = marks.start.row, marks.fin.row do
        local adjustment = apply_indent(cur_pos, i, str_fn)

        if adjustment ~= 0 and i == marks.start.row then
            local new_start_col = marks.start.col + adjustment
            new_start_col = math.max(new_start_col, 0)

            vim.api.nvim_buf_set_mark(0, "[", marks.start.row, new_start_col, {})
            new_marks.start.col = new_start_col
        end

        if adjustment ~= 0 and i == marks.fin.row then
            local new_fin_col = marks.fin.col + adjustment
            new_fin_col = math.max(new_fin_col, 0)

            vim.api.nvim_buf_set_mark(0, "]", marks.fin.row, new_fin_col, {})
            new_marks.fin.col = new_fin_col
        end
    end

    return new_marks
end

return M
