local M = {}

---Wrapper for concatenating a series of lines, performing a function on the concatenation, then
---re-splitting the lines.
---Useful for operations that create new allocations.
---@param lines string[]
---@param f fun(all_lines: string): string, any
---@return string[]
function M.do_over_lines(lines, f)
    vim.validate("f", f, "callable")
    vim.validate("lines", lines, function()
        local valid_list = require("nvim-tools.types").valid_list
        return valid_list(lines, { item_type = "string" })
    end)

    return vim.split(f(table.concat(lines)), "\n")
end

---@param str string
---@param byte integer
---@return boolean
function M.startswith_byte(str, byte)
    vim.validate("str", str, "string")
    vim.validate("buf", byte, require("nvim-tools.types").is_uint)
    return #str > 0 and string.byte(str, 1) == byte
end

---@param str string
---@param byte integer
---@return boolean
function M.endswith_byte(str, byte)
    vim.validate("str", str, "string")
    vim.validate("buf", byte, require("nvim-tools.types").is_uint)
    local len_str = #str
    return len_str > 0 and string.byte(len_str, 1) == byte
end

return M
