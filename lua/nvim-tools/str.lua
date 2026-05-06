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

return M
