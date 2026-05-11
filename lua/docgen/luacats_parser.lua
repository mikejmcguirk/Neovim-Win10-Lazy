local luacats_grammar = require("docgen.luacats_grammar")
local parser_obj = require("docgen.parser_obj")

--- funs, classes, and briefs are edited in place.
--- @param obj docgen.ParserObj?
--- @param funs docgen.ParserObj[]
--- @param classes table<string,docgen.ParserObj>
--- @param briefs docgen.ParserObj[]
local function commit_obj_if_valid(obj, classes, funs, briefs)
    if not obj then
        return
    end

    if not obj:can_commit() then
        return
    end

    local kind = obj:get_kind()
    if kind == "class" then
        local obj_name = obj:get_name()
        if obj_name and not classes[obj_name] then
            classes[obj_name] = obj
        end
    elseif kind == "brief" then
        briefs[#briefs + 1] = obj
    elseif kind == "fun" then
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

---@param fname string
---@return string
local function module_from_fname(fname)
    local module = fname:match(".*/lua/([a-z_][a-z0-9_/]+)%.lua") or fname
    return module:gsub("/", ".")
end

local M = {}

---@param lines string[]
---@param fname string
---@return table<string,docgen.ParserObj>, docgen.ParserObj[], docgen.ParserObj[]
function M.parse_lines(lines, fname)
    local funs = {} --- @type docgen.ParserObj[]
    local classes = {} --- @type table<string,docgen.ParserObj>
    local briefs = {} --- @type docgen.ParserObj[]

    local classvar_map = {} --- @type table<string,string>
    local modvar = find_modvar(lines) or ""
    -- TODO: This needs to produce a more aesthetic result, but will defer until I know the
    -- pipeline it comes down from.
    local module = module_from_fname(fname)
    local obj = parser_obj.new(modvar, module)

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
                obj:add_doc_line(line_nodash)
            end
        else
            obj:finalize(line, classes, classvar_map)
            commit_obj_if_valid(obj, classes, funs, briefs)
            obj = parser_obj.new(modvar, module)
        end
    end

    obj:finalize("", classes, classvar_map)
    commit_obj_if_valid(obj, classes, funs, briefs)

    return classes, funs, briefs
end
-- TODO: For the top module name, if the file is init.lua, it should be the name of the file's
-- directory. (Assuming we keep this convention)

---@param str string
---@param input string
---@return table<string,docgen.ParserObj>, docgen.ParserObj[], docgen.ParserObj[]
function M.parse_str(str, input)
    local lines = vim.split(str, "\n")
    return M.parse_lines(lines, input)
end

--- @param input string
---@return table<string,docgen.ParserObj>, docgen.ParserObj[], docgen.ParserObj[]
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
