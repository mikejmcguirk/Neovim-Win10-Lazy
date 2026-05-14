local fn = vim.fn
local fs = vim.fs

local luacats_grammar = require("docgen.luacats_grammar")
local parser_obj = require("docgen.parser_obj")

--- funs, classes, and briefs are edited in place.
--- @param obj docgen.ParserObj
--- @param obj_list docgen.ParserObj[]
local function commit_obj_if_valid(obj, obj_list)
    if obj:is_finalized() then
        obj_list[#obj_list + 1] = obj
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
---@return string, any
local function module_from_fname(fname)
    local module = fname:match(".*/lua/([a-z_][a-z0-9_/]+)%.lua") or fname
    local basename = fs.basename(module)
    local root = fn.fnamemodify(basename, ":r")
    return string.gsub(root, "/", ".")
end
-- TODO: The filenames need to be relative to some root dir. so like root/init.lua would give
-- you the modulename root. Of probably even just nothing and let the help prefix be the
-- root dir. Which seems like basically the most elegant way to do it.  Then you would have
-- root/foo.lua would be foo.fun() and so on. And if you had root/bar/init.lua you would have
-- bar.fun() and root/bar/buzz/lua would be bar.buzz(). Does this allow duplicates though?
-- root/bar.lua
-- root/bar/init.lua
-- I guess you would pre-parse all the roots so you know what's coming.

local M = {}

---@param lines string[]
---@param source string
---@return docgen.ParsedSource
function M.parsed_from_lines(lines, source)
    local obj_list = {} ---@type docgen.ParserObj[]

    local modvar = find_modvar(lines) or ""
    -- TODO: This needs to produce a more aesthetic result, but will defer until I know the
    -- pipeline it comes down from.
    local module = module_from_fname(source)
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
                obj:doc_line_add(line_nodash)
            end
        else
            obj:finalize(line)
            commit_obj_if_valid(obj, obj_list)
            obj = parser_obj.new(modvar, module)
        end
    end

    obj:finalize("")
    commit_obj_if_valid(obj, obj_list)

    return { source, obj_list }
end
-- TODO: For the top module name, if the file is init.lua, it should be the name of the file's
-- directory. (Assuming we keep this convention)

---@param str string
---@param source string
---@return docgen.ParsedSource
function M.parsed_from_str(str, source)
    local lines = vim.split(str, "\n")
    return M.parsed_from_lines(lines, source)
end

--- @param source string
---@return docgen.ParsedSource
function M.parsed_from_file(source)
    local f = assert(io.open(source, "r"))
    local txt = f:read("*all")
    f:close()

    return M.parsed_from_str(txt, source)
end

return M

-- DOC: Something I think is pretty standard but should be documented, is we're assuming that
-- every doc object is separated by a blank line or function or something. So if you do @alias
-- on one line, and then you have @class on the next doc line, then unintended results will
-- happen.
