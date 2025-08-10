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

--- @param text string
--- @param vcount integer
--- @param regtype string
--- @return string[]
function M.get_paste_lines(text, vcount, regtype)
    if text == "" then
        return {}
    end

    local type = regtype:sub(1, 1)

    if type == "v" and vcount > 1 then
        text = string.rep(text, vcount)
    end

    local lines = vim.split(text:gsub("\n$", ""), "\n") ---@type string[]

    if type == "V" and vcount > 1 then
        -- TODO: Verify this works
        local ext_count = vcount - 1
        local orig_lines = vim.deepcopy(lines, true)
        for _ = 1, ext_count do
            vim.list_extend(lines, orig_lines)
        end
    elseif type == "\22" and vcount > 1 then
        for i, l in ipairs(lines) do
            lines[i] = string.rep(l, vcount)
        end
    end

    return lines
end

return M
