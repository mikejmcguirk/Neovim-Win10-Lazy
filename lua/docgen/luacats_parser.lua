-- Based on the Neovim core docgen.

local parser_obj = require("docgen.parser_obj")

---@param lines string[]
---@return string?
local function find_modvar(lines)
    local len_lines = #lines
    for i = len_lines, 1, -1 do
        --- @type string?
        local modvar = string.match(lines[i], "^return%s+([a-zA-Z_]+)")
        if modvar then
            return modvar
        end
    end

    for i = len_lines, 1, -1 do
        --- @type string?
        local modvar = string.match(lines[i], "^return%s+setmetatable%(([a-zA-Z_]+),")
        if modvar then
            return modvar
        end
    end

    return nil
end

---@class docgen.ParsedSource
---@field [1] string Formatted Source Name
---@field [2] docgen.ParserObj[] Objs

local M = {}

---@param lines string[]
---@param header_tag string
---@return docgen.ParsedSource
function M.parsed_from_lines(lines, header_tag)
    local modvar = find_modvar(lines) or ""

    local obj_list = {} ---@type docgen.ParserObj[]
    local obj = parser_obj.new(modvar, header_tag)
    for _, line in ipairs(lines) do
        local status = parser_obj.add_line(obj, line)
        if status > 0 then
            if status == 1 then
                obj_list[#obj_list + 1] = obj
            end

            obj = parser_obj.new(modvar, header_tag)
        end
    end

    local status = parser_obj.finalize(obj, "")
    if status == 1 then
        obj_list[#obj_list + 1] = obj
    end

    return { header_tag, obj_list }
end

---@param str string
---@param header_tag string
---@return docgen.ParsedSource
function M.parsed_from_str(str, header_tag)
    local lines = vim.split(str, "\n")
    return M.parsed_from_lines(lines, header_tag)
end

return M
