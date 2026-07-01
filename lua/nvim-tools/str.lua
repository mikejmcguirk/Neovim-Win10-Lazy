local M = {}

---@param sep string
---@param ... any
---@return string
function M.concat_vargs(sep, ...)
    local nargs = select("#", ...)
    if nargs == 0 then
        return ""
    end

    local keys = {}
    local vargs = { ... }
    local vargs_len = #vargs
    for i = 1, vargs_len do
        local arg = select(i, ...)
        keys[i] = type(arg) == "string" and arg or vim.inspect(arg)
    end

    return table.concat(keys, sep)
end

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

---Bespoke version to strip out guard code. Always relaxed indexing.
---@param s string
---@param encoding "utf-16"|"utf-32"
---@param idx uinteger
---@return integer
function M.str_utfindex(s, encoding, idx)
    if idx == 0 then
        return 0
    end

    local col_32, col_16 = vim._str_utfindex(s, idx) --[[@as integer?, integer?]]
    if encoding == "utf-16" then
        if col_16 then
            return col_16
        end

        -- Let the unhappy path be slow.
        local _, max_16 = vim._str_utfindex(s) --[[@as integer, integer]]
        return max_16
    end

    if col_32 then
        return col_32
    end

    -- Let the unhappy path be slow.
    local max_32, _ = vim._str_utfindex(s) --[[@as integer, integer]]
    return max_32
end

return M
