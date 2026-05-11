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

---@param str string?
---@return boolean
function M.str_has_content(str)
    vim.validate("str", str, "string", true)
    return str ~= nil and string.match(str, "^%s*$") == nil
end

---@param target string?
---@param str string
---@param trim_leading_nl? boolean If unable to append, trim all leading newlines.
---@return string
function M.checked_str_append(target, str, trim_leading_nl)
    vim.validate("target", target, "string", true)
    vim.validate("str", str, "string")

    if target ~= nil and (M.str_has_content(target)) then
        return target .. str
    end

    if not trim_leading_nl then
        return str
    end

    local nl_trim, _ = string.gsub(str, "^\n+", "")
    return nl_trim
end
-- MID: Also do checked_str_prepend

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
