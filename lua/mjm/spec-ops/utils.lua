local M = {}

--- @class Marks
--- @field start {row: integer, col: integer}
--- @field finish {row: integer, col: integer}

--- @param bufnr integer
--- @param motion string
--- @param vmode? boolean
--- @return Marks
function M.get_marks(bufnr, motion, vmode)
    --- @type {[1]:integer, [2]:integer}
    local start = vim.api.nvim_buf_get_mark(bufnr, vmode and "<" or "[")
    --- @type {[1]:integer, [2]:integer}
    local finish = vim.api.nvim_buf_get_mark(bufnr, vmode and ">" or "]")
    local marks = {
        start = {
            row = start[1],
            col = start[2],
        },
        finish = {
            row = finish[1],
            col = finish[2],
        },
    }

    if motion == "block" then
        return M.sort_marks(marks)
    else
        return marks
    end
end

--- @param marks Marks
--- @return Marks
function M.sort_marks(marks)
    if marks.start.row > marks.finish.row then
        return {
            start = {
                row = marks.finish.row,
                col = marks.finish.col,
            },
            finish = {
                row = marks.start.row,
                col = marks.start.col,
            },
        }
    else
        return marks
    end
end

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
        local err_msg = "No regname to check in is_valid_register"
        return false, err_msg
    end

    if not type(reg) == "string" then
        local err_msg = "Register " .. reg .. " in is_valid_register is not a string"
        return false, err_msg
    end

    if #reg ~= 1 then
        local err_msg = "Register " .. reg .. " is more than one character long"
        return false, err_msg
    end

    if reg:match('["0-9a-zA-Z.*%%:#=+_%-/]') then
        return true, nil
    else
        local err_msg = "Register " .. reg .. " is invalid"
        return false, err_msg
    end
end

return M
