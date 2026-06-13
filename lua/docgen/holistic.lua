local util = require("docgen.util")
local endswith_byte = util.endswith_byte
local list_copy = util.list_copy
local list_filter = util.list_filter
local list_filter_map = util.list_filter_map
local table_new = util.table_new
local table_get_or_create_subtable = util.table_get_or_create_subtable

local M = {}

---@param fun docgen.ParserObj
---@return string
local function fun_to_fun_type_annotation(fun)
    local type_tbl = { "fun(" } ---@type string[]
    local params = fun.params
    if params and #params > 0 then
        local type_params = list_filter_map(list_copy(params), function(param)
            return string.format("%s:%s", param.name, param.type)
        end)

        type_tbl[#type_tbl + 1] = table.concat(type_params, ", ")
    end

    type_tbl[#type_tbl + 1] = ")"

    local returns = fun.returns
    if returns and #returns > 0 then
        type_tbl[#type_tbl + 1] = ": "
        local fun_ret_types = {} ---@type string[]
        for _, ret in ipairs(returns) do
            for _, r in ipairs(ret) do
                local inner_r_name = r.name
                local inner_r_type = r.type
                if inner_r_name then
                    fun_ret_types[#fun_ret_types + 1] = inner_r_name .. ":" .. inner_r_type
                else
                    fun_ret_types[#fun_ret_types + 1] = inner_r_type
                end
            end
        end

        type_tbl[#type_tbl + 1] = table.concat(fun_ret_types, ", ")
    end

    return table.concat(type_tbl)
end
-- MID: Functions currently, properly, filter out self if they are methods when they are finalized.
-- However, function types, like the one above, need to include the self variable then they are
-- defined in LuaCATs. Colon functions should hold onto the self var when they are created, only
-- removing the self var if they attach to a class (since they would be dropped from rendering
-- otherwise). Re-adding self here de-values the function's params as a source of truth.
-- MID: Concrete use case for some kind of functional nested iterator construct.

---@param class docgen.ParserObj Modified in place
---@param fun docgen.ParserObj Modified in place
local function class_fun_attach(class, fun)
    local fields = table_get_or_create_subtable(class, "fields") ---@type docgen.DocItem[]
    local fun_namevar = fun.namevar
    list_filter(fields, function(field)
        return field.name ~= fun_namevar
    end)

    -- DOC: Module functions stay attached to the module. This means module classes can't have
    -- confusing names. See |vim.pos|/|vim.Pos| for an example of this done right.
    if class.classvar == class.modvar then
        return
    end

    fun.class = class.class
    local class_tag = class.tag
    local sep = fun.sep
    fun.tag = class_tag .. sep .. fun_namevar .. "()"

    local fun_see = table_get_or_create_subtable(fun, "see") ---@type string[]
    fun_see[#fun_see + 1] = "|" .. class_tag .. "|"

    local fun_tag = fun.tag --[[@as string]]
    fields[#fields + 1] = {
        kind = "field",
        name = fun_namevar,
        type = fun_to_fun_type_annotation(fun),
        desc = "See: |" .. fun_tag .. "|",
    }
end

---@param doc_item docgen.DocItem Modified in place
---@param class docgen.ParserObj
---@param typ_islist boolean
local function obj_inlinedoc_inject(doc_item, class, typ_islist, typ_isopt)
    ---@diagnostic disable-next-line: missing-fields
    local inlinedesc = {} ---@type docgen.ParserObj
    inlinedesc.kind = "class"

    local doc_desc = doc_item.desc or ""
    local class_desc = class.desc
    if class_desc then
        inlinedesc.desc = doc_desc .. " " .. class_desc
    elseif #doc_desc == 0 then
        if typ_islist then
            inlinedesc.desc = doc_desc .. " " .. "A list of objects with the following fields:"
        elseif class.parent then
            local fmt_str = "Extends |%s| with the additional fields:"
            inlinedesc.desc = doc_desc .. " " .. string.format(fmt_str, class.parent)
        else
            inlinedesc.desc = doc_desc .. " " .. "A table with the following fields:"
        end
    end

    inlinedesc.fields = class.fields
    doc_item.inlinedesc = inlinedesc

    local typ_tbl = { "table" }
    if typ_islist then
        typ_tbl[#typ_tbl + 1] = "[]"
    end

    if typ_isopt then
        typ_tbl[#typ_tbl + 1] = "?"
    end

    doc_item.type = table.concat(typ_tbl)
end

---@param doc_item docgen.DocItem
---@param class docgen.ParserObj
local function desc_append_see_class_tag(doc_item, class)
    local desc_old = doc_item.desc or ""
    local desc_len = #desc_old

    local tag = "|" .. class.tag .. "|"
    if desc_len == 0 then
        doc_item.desc = "See " .. tag .. "."
        return
    end

    if string.find(desc_old, tag, 1, true) then
        doc_item.desc = desc_old
        return
    end

    local see_text = endswith_byte(desc_old, 46) and " See " or ". See "
    doc_item.desc = desc_old .. see_text .. tag .. "."
end

--- @param doc_item docgen.DocItem Modified in place
--- @param classes table<string,docgen.ParserObj>
--- @return docgen.ParserObj?, boolean, boolean
local function type_find_class(doc_item, classes)
    local typ = doc_item.type
    if (not typ) or typ == "" then
        return nil, false, false
    end

    local list_count
    typ, list_count = string.gsub(typ, "%[%]$", "")
    local typ_islist = list_count > 0
    local q_count
    typ, q_count = string.gsub(typ, "%?", "")
    local typ_isopt = q_count > 0

    local class = classes[typ]
    if (not class) or class.doc_flag == "nodoc" then
        return nil, false, false
    end

    return class, typ_isopt, typ_islist
end
-- MID: Does not parse union types correctly.

---@param obj docgen.ParserObj
---@param classes table<string,docgen.ParserObj> All classes from all files.
local function inlinedoc_inject(obj, classes)
    if obj.kind == "fun" then
        local params = obj.params
        if not params then
            -- TODO: Don't love this because it doesn't just go to the end.
            goto do_returns
        end

        for _, param in ipairs(params) do
            local class, typ_isopt, typ_islist = type_find_class(param, classes)
            if class then
                if class.doc_flag == "inlinedoc" then
                    obj_inlinedoc_inject(param, class, typ_islist, typ_isopt)
                else
                    desc_append_see_class_tag(param, class)
                end
            end
        end

        ::do_returns::
        local returns = obj.returns
        if not returns then
            return
        end

        for _, r in ipairs(returns) do
            for _, inner_r in ipairs(r) do
                local class, typ_isopt, typ_islist = type_find_class(inner_r, classes)
                if class then
                    if class.doc_flag == "inlinedoc" then
                        obj_inlinedoc_inject(inner_r, class, typ_islist, typ_isopt)
                    else
                        desc_append_see_class_tag(inner_r, class)
                    end
                end
            end
        end
    elseif obj.kind == "class" then
        local fields = obj.fields
        if not fields then
            return
        end

        for _, field in ipairs(fields) do
            local class, typ_isopt, typ_islist = type_find_class(field, classes)
            if class then
                if class.doc_flag == "inlinedoc" then
                    obj_inlinedoc_inject(field, class, typ_islist, typ_isopt)
                else
                    desc_append_see_class_tag(field, class)
                end
            end
        end
    end
end

-- ---@param header_tags string[]
-- ---@param parsed_sources [integer, docgen.ParserObj[]] Modified in place
-- local function tags_prepare_and_check(header_tags, parsed_sources)
--     local seen = {} ---@type table<string, boolean>
--     for _, tag in ipairs(header_tags) do
--         if not seen[tag] then
--             seen[tag] = true
--         else
--             error("Duplicate tag: " .. tag)
--         end
--     end
--
--     for _, source in ipairs(parsed_sources) do
--         for _, obj in ipairs(source[2]) do
--             -- Wait until now because attaching class functions can change the function's tag.
--             local obj_tags_addtl = table_get_or_create_subtable(obj, "tags_addtl")
--             local obj_tag = obj.tag
--             if obj_tag then
--                 obj_tags_addtl[#obj_tags_addtl + 1] = obj_tag
--             end
--
--             local tags_addtl = obj.tags_addtl
--             if tags_addtl then
--                 for _, tag in ipairs(tags_addtl) do
--                     if not seen[tag] then
--                         seen[tag] = true
--                     else
--                         error("Duplicate tag: " .. tag)
--                     end
--                 end
--             end
--         end
--     end
-- end
-- -- TODO: More detailed error reporting. Maybe/probably not file info, but more info about the
-- -- objects producing the duplicates.

---@param obj_lists docgen.ParserObj[][] Modified in place
---@return table<string, docgen.ParserObj> classes
---@return integer classes_count
---@return table<string, docgen.ParserObj> funs
local function create_maps(obj_lists)
    local classes = {} ---@type table<string, docgen.ParserObj>
    local classes_count = 0
    local funs = {} ---@type table<string, docgen.ParserObj>

    for _, list in ipairs(obj_lists) do
        for _, obj in ipairs(list) do
            local kind = obj.kind
            if kind == "fun" then
                -- Use the unique tag because function namevars do not have to be globally unique.
                local tag = obj.tag --[[@as string]]
                if not funs[tag] then
                    funs[tag] = obj
                else
                    error("Duplicate fun " .. tag)
                end
                funs[tag] = obj
            elseif kind == "class" then
                -- Globally unique LuaCATs class name
                local name = obj.name --[[@as string]]
                if not classes[name] then
                    classes[name] = obj
                    classes_count = classes_count + 1
                else
                    error("Duplicate class " .. name)
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
        local classvar = class.classvar
        if classvar then
            classvar_map[classvar] = class.name
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
        local class_name = classvar_map[fun.classvar]
        if class_name == nil then
            goto continue
        end

        ---@diagnostic disable-next-line: undefined-field
        local class = classes[class_name]
        if class ~= nil then
            ---@diagnostic disable-next-line: param-type-mismatch
            class_fun_attach(class, fun)
        end

        ::continue::
    end
end

---@param obj_lists docgen.ParserObj[][] Modified in place
---@param classes table<string, docgen.ParserObj> Edited in place
---@param funs table<string, docgen.ParserObj> Edited in place
local function parsed_sources_filter_invalid(obj_lists, classes, funs)
    for _, list in ipairs(obj_lists) do
        list_filter(list, function(obj)
            local kind = obj.kind
            if kind == "fun" then
                if obj.class == nil then
                    funs[obj.tag] = nil
                    return false
                end
            elseif kind == "class" then
                if not (obj.fields and #obj.fields > 0) == 0 then
                    classes[obj.name] = nil
                    return false
                end
            end

            return true
        end)
    end

    list_filter(obj_lists, function(source)
        return #source[2] > 0
    end)
end

---@param obj_lists docgen.ParserObj[][] Modified in place
local function parsed_sources_filter_inlinedoc(obj_lists)
    for _, list in ipairs(obj_lists) do
        list_filter(list, function(obj)
            return not (obj.kind == "class" and obj.doc_flag == "inlinedoc")
        end)
    end

    list_filter(obj_lists, function(source)
        return #source[2] > 0
    end)
end
-- TODO: This cannot be the way.

---@param obj_lists docgen.ParserObj[][] Modified in place
function M.parsed_sources_resolve_holistic(obj_lists)
    vim.validate("parsed_sources", obj_lists, "table")

    local classes, classes_count, funs = create_maps(obj_lists)
    if classes_count > 0 and next(funs) then
        local classvar_map = create_classvar_map(classes, classes_count)
        class_funs_resolve_links(classes, classvar_map, funs)
    end

    -- Only do this once because it's expensive.
    parsed_sources_filter_invalid(obj_lists, classes, funs)
    if not next(classes) then
        return
    end

    -- Do here for inlinedoc.
    for _, class in pairs(classes) do
        ---@diagnostic disable-next-line: param-type-mismatch
        table.sort(class.fields, function(a, b)
            return a.name < b.name
        end)
    end

    for _, fun in pairs(funs) do
        inlinedoc_inject(fun, classes)
    end

    for _, class in pairs(classes) do
        inlinedoc_inject(class, classes)
    end

    parsed_sources_filter_inlinedoc(obj_lists)
end
-- MAYBE: If specific issues with the incoming file results repeatedly come up, add runtime
-- checking if inexpensive.

return M
