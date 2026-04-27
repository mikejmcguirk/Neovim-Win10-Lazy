local luacats_grammar = require("docgen.luacats_grammar")

local obj_builder = require("docgen.obj_builder")

--- @class nvim.luacats.parser.param : nvim.luacats.grammar.Result

--- @class nvim.luacats.parser.field : nvim.luacats.grammar.Result
--- @field classvar? string
--- @field nodoc? true

-- TODO: Another thing here is we need to take stuff and try to combine as much as possible.
-- nodoc/inlinedoc should all be in one variable called "docstyle"

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
    elseif obj.name then
        funs[#funs + 1] = obj
    end
end
-- MID: "Document aliases" feels like a semi-useful option.

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
    -- TODO: This is not what we want. most of the committed objects should just be in one
    -- ordered list. We do need a list of all classes for inlinedoc, but I would think that you
    -- could just make a separate table that references the main one.
    local funs = {} --- @type docgen.ParserObj[]
    local classes = {} --- @type table<string,docgen.ParserObj>
    local briefs = {} --- @type string[]

    local classvars = {} --- @type table<string,string>
    local modvar = find_modvar(lines)

    local builder = obj_builder.new()

    for _, line in ipairs(lines) do
        local is_doc_line = string.find(line, "^%-%-%-")
        local has_indent = line:match("^%s+") ~= nil
        line = vim.trim(line)

        if is_doc_line then
            local nodash_line = line:sub(4):gsub("^%s+@", "@")
            ---@type nvim.luacats.grammar.Result?
            local parsed = luacats_grammar:match(nodash_line)
            if parsed then
                builder:add_parsed_result(parsed)
            else
                builder:handle_unparsed_line(nodash_line)
            end
        else
            builder:add_doc_lines_to_obj()
            builder:set_module_info(modvar, input)

            local final_line = (not has_indent) and line or nil
            local cur_obj = builder:get_finalized_obj(final_line, classes, classvars)
            commit_obj(cur_obj, classes, funs, briefs)
            builder:reset()
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
