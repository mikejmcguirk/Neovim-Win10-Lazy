local util = require("docgen.util")
local list_filter = util.list_filter
local table_new = util.table_new

local M = {}

---@param parsed_sources docgen.ParsedSource[]
---@return table<string, docgen.ParserObj> classes
---@return integer classes_count
---@return table<string, docgen.ParserObj> funs
local function create_maps(parsed_sources)
    local classes = {} ---@type table<string, docgen.ParserObj>
    local classes_count = 0
    local funs = {} ---@type table<string, docgen.ParserObj>

    for _, source in ipairs(parsed_sources) do
        for _, obj in ipairs(source[2]) do
            local kind = obj:kind_get()
            if kind == "fun" then
                -- Use the unique tag because function namevars do not have to be globally unique.
                local tag = obj:tag_get() --[[@as string]]
                if not funs[tag] then
                    funs[tag] = obj
                else
                    error("Duplicate fun " .. tag .. " from source " .. source[1])
                end
                funs[obj:tag_get()] = obj
            elseif kind == "class" then
                -- Globally unique LuaCATs class name
                local name = obj:name_get() --[[@as string]]
                if not classes[name] then
                    classes[name] = obj
                    classes_count = classes_count + 1
                else
                    error("Duplicate class " .. name .. " from source " .. source[1])
                end
            end
        end
    end

    return classes, classes_count, funs
end
-- FUTURE: Build this while creating parsed inputs. Obvious perf gain since you don't have to
-- iterate past briefs and aliases. Keeping it here at the moment though more logically scopes
-- the data.

---@param classes table<string, docgen.ParserObj>
---@param classes_count integer
---@return table<string, string> classvar_map
local function create_classvar_map(classes, classes_count)
    local classvar_map = table_new(0, math.floor(classes_count * 0.25))
    for _, class in pairs(classes) do
        local classvar = class:classvar_get()
        if classvar then
            classvar_map[classvar] = class:name_get()
        end
    end

    return classvar_map
end
-- MID: I'm not sure this is faster than just getting it along with classes and funs. Though it
-- does save memory in files without functions (niche case?).

---@param classes table<string, docgen.ParserObj> Edited in place
---@param classvar_map table<string, string>
---@param funs table<string, docgen.ParserObj> Edited in place
local function class_funs_resolve_links(classes, classvar_map, funs)
    for _, fun in pairs(funs) do
        local class_name = classvar_map[fun:classvar_get()]
        if class_name == nil then
            goto continue
        end

        local class = classes[class_name]
        if class then
            class:class_attach_fun_field(fun)
        end

        ::continue::
    end
end

---@param parsed_sources docgen.ParsedSource[] Edited in place
---@param classes table<string, docgen.ParserObj> Edited in place
---@param funs table<string, docgen.ParserObj> Edited in place
local function parsed_sources_filter_invalid(parsed_sources, classes, funs)
    for _, source in ipairs(parsed_sources) do
        local obj_list = source[2]
        list_filter(obj_list, function(obj)
            local kind = obj:kind_get()
            if kind == "fun" then
                if obj:class_get() == nil then
                    funs[obj:tag_get()] = nil
                    return false
                end
            elseif kind == "class" then
                if obj:fields_count() == 0 then
                    classes[obj:name_get()] = nil
                    return false
                end
            end

            return true
        end)
    end

    list_filter(parsed_sources, function(input)
        return #input > 0
    end)
end
-- MAYBE: Unlike with parsing finalization, there aren't enough criteria here to justify putting
-- into the metatable. If the criteria become more complex, that can be revisited.

---@param parsed_sources docgen.ParsedSource[] Edited in place
local function parsed_sources_filter_inlinedoc(parsed_sources)
    for _, source in ipairs(parsed_sources) do
        local obj_list = source[2]
        list_filter(obj_list, function(obj)
            return not (obj:kind_get() == "class" and obj:doc_flag_get() == "inlinedoc")
        end)
    end

    list_filter(parsed_sources, function(input)
        return #input > 0
    end)
end
-- TODO: This cannot be the way.

---Assumes that all underlying parser objects are finalized and valid.
---@param parsed_sources docgen.ParsedSource[] Modified in place
function M.parsed_sources_resolve_holistic(parsed_sources)
    vim.validate("parsed_sources", parsed_sources, function()
        return type(parsed_sources) == "table" and #parsed_sources > 0
    end)

    local classes, classes_count, funs = create_maps(parsed_sources)
    if classes_count > 0 and next(funs) then
        local classvar_map = create_classvar_map(classes, classes_count)
        class_funs_resolve_links(classes, classvar_map, funs)
    end

    -- Only do this once because it's expensive.
    parsed_sources_filter_invalid(parsed_sources, classes, funs)
    if not next(classes) then
        return
    end

    for _, fun in pairs(funs) do
        fun:inlinedoc_inject(classes)
    end

    for _, class in pairs(classes) do
        class:inlinedoc_inject(classes)
    end

    parsed_sources_filter_inlinedoc(parsed_sources)
end
-- MAYBE: If specific issues with the incoming file results repeatedly come up, add runtime
-- checking if inexpensive.

return M
