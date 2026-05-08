local luacats_grammar = require("docgen.luacats_grammar")
local parser_obj = require("docgen.parser_obj")

-- TODO: remove
--- @class nvim.luacats.parser.param : nvim.luacats.grammar.Result

-- TODO: Remove this class
--- @class nvim.luacats.parser.field : nvim.luacats.grammar.Result
--- @field classvar? string
--- @field nodoc? true

--- @param obj docgen.ParserObj?
--- @param funs docgen.ParserObj[]
--- @param classes table<string,docgen.ParserObj>
--- @param briefs string[]
local function commit_obj(obj, classes, funs, briefs)
    if not obj then
        return
    end

    if obj.kind == "class" then
        if not classes[obj.name] then
            classes[obj.name] = obj
        end
    elseif obj.kind == "brief" then
        briefs[#briefs + 1] = obj.desc
    elseif obj.kind == "fun" then
        funs[#funs + 1] = obj
    end
end

--- Determine the table name used to export functions of a module
--- @param lines string[]
--- @return string?
local function find_modvar(lines)
    local len_lines = #lines
    for i = len_lines, 1, -1 do
        local line = lines[i]
        --- @type string?
        local meta_m = string.match(line, "^return%s+setmetatable%(([a-zA-Z_]+),")
        if meta_m then
            return meta_m
        end
    end

    for i = len_lines, 1, -1 do
        --- @type string?
        local m = string.match(lines[i], "^return%s+([a-zA-Z_]+)")
        if m then
            return m
        end
    end

    return nil
end
-- TODO: The nvim docgen scans for a return M line, then a return setmetatable line, returning
-- the setmetatable line if found. Since we can only have one return, wouldn't we search for
-- return M (common case) first, then use setmetatable as a fallback?

local M = {}

---@param lines string[]
---@param input string
function M.parse_lines(lines, input)
    local funs = {} --- @type docgen.ParserObj[]
    local classes = {} --- @type table<string,docgen.ParserObj>
    local briefs = {} --- @type string[]

    local classvars = {} --- @type table<string,string>
    local modvar = find_modvar(lines) or ""

    local obj = parser_obj.new(modvar, input)

    for _, line in ipairs(lines) do
        local is_doc_line = string.find(line, "^%-%-%-")
        local line_rtrim = string.match(line, "^.*%S") ---@type string
        if is_doc_line then
            local line_nodash = string.gsub(string.sub(line_rtrim, 4), "^%s+@", "@")
            ---@type nvim.luacats.grammar.Result?
            local parsed = luacats_grammar:match(line_nodash)
            if parsed then
                obj:add_parsed(parsed)
            else
                obj:doc_lines_add(line_nodash)
            end
        else
            local valid_obj = obj:finalize(line, classes, classvars)
            if valid_obj then
                commit_obj(obj, classes, funs, briefs)
            end

            obj = parser_obj.new(modvar, input)
        end
    end

    return classes, funs, briefs
end
-- TODO: For the top module name, if the file is init.lua, it should be the name of the file's
-- directory. (Assuming we keep this convention)

---@param str string
---@param input string
function M.parse_str(str, input)
    local lines = vim.split(str, "\n")
    return M.parse_lines(lines, input)
end

--- @param input string
function M.parse(input)
    local f = assert(io.open(input, "r"))
    local txt = f:read("*all")
    f:close()

    return M.parse_str(txt, input)
end

return M

-- TODO: Something I think is pretty standard but should be documented, is we're assuming that
-- every doc object is separated by a blank line or function or something. So if you do @alias
-- on one line, and then you have @class on the next doc line, then unintended results will
-- happen.
