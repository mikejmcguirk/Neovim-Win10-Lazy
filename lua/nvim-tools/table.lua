-- local api = vim.api

local M = {}

---@type fun(narray: integer, nhash: integer): table
M.table_new = (function()
    local t_new = require("table.new")
    if t_new then
        ---@diagnostic disable-next-line: undefined-field
        return table.new
    else
        return function()
            return {}
        end
    end
end)()

return M
