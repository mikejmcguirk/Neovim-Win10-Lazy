local ts_parsing = require("docgen.ts_parsing")
local md_to_vimdoc = ts_parsing.luacats_md_to_vimdoc

local util = require("docgen.util")
local cbraces_add = util.add_cbraces
local endswith_byte = util.endswith_byte
local list_filter = util.list_filter
local list_fold = util.list_fold
local table_new = util.table_new
local table_get_or_create_subtable = util.table_get_or_create_subtable
local type_fmt_get_with_default = util.type_fmt_get_with_default

local M = {}

---Assumes that obj and class are already finalized.
---Assumes that obj.classvar and class.classvar have already been externally checked to match.
---@param fun docgen.ParserObj
---@param class_in docgen.ParserObj
local function fun_set_class_info_from_class(fun, class_in)
    rawset(fun, "parent", class_in.parent)
    -- Module class functions should still be tagged as part of the module. Module LuaCATs tags
    -- should not be confusing. See |vim.pos|/|vim.Pos| for an example of this done right.
    -- DOC: This behavior.
    if rawget(fun, "classvar") == rawget(fun, "modvar") then
        return
    end

    rawset(fun, "class", class_in.class)

    local class_tag = class_in.tag
    local sep = rawget(fun, "sep")
    local namevar = rawget(fun, "namevar")
    rawset(fun, "tag", class_tag .. sep .. namevar .. "()")

    local see = table_get_or_create_subtable(fun, "see") ---@type string[]
    see[#see + 1] = "|" .. class_tag .. "|"
end

---@param class docgen.ParserObj
---@param fun docgen.ParserObj Modified in place
local function class_attach_fun_field(class, fun)
    local fields = table_get_or_create_subtable(class, "fields") ---@type docgen.DocItem[]
    local fun_namevar = fun.name
    list_filter(fields, function(field)
        return field.name ~= fun_namevar
    end)

    fun_set_class_info_from_class(fun, class)

    -- Module classes should not duplicate the module physical function definitions.
    if rawget(class, "classvar") == rawget(class, "modvar") then
        return
    end

    local type_tbl = { "fun(" } ---@type string[]
    local params = {} ---@type string[]
    for _, param in ipairs(fun.params) do
        params[#params + 1] = string.format("%s:%s", param.name, param.type)
    end

    type_tbl[#type_tbl + 1] = table.concat(params, ", ")
    type_tbl[#type_tbl + 1] = ")"

    local returns = fun.returns
    if returns and #returns > 0 then
        type_tbl[#type_tbl + 1] = ": "
        local fun_ret_types = {} ---@type string[]
        for _, r in ipairs(returns) do
            for _, inner_r in ipairs(r) do
                local inner_r_name = inner_r.name
                local inner_r_type = inner_r.type
                if inner_r_name then
                    fun_ret_types[#fun_ret_types + 1] = inner_r_name .. ":" .. inner_r_type
                else
                    fun_ret_types[#fun_ret_types + 1] = inner_r_type
                end
            end

            type_tbl[#type_tbl + 1] = table.concat(fun_ret_types, ", ")
        end
    end

    local fun_tag = fun.tag --[[@as string]]
    fields[#fields + 1] = {
        kind = "field",
        name = fun.namevar,
        type = table.concat(type_tbl, ""),
        desc = "See: |" .. fun_tag .. "|",
    }
end
-- TODO: Is it necessary to outline the fun part? Maybe too OOP.
-- MID: Functions currently, properly, filter out self if they are methods when they are finalized.
-- However, function types, like the one above, need to include the self variable then they are
-- defined in LuaCATs. Colon functions should hold onto the self var when they are created, only
-- removing the self var if they attach to a class (since they would be dropped from rendering
-- otherwise). Re-adding self here de-values the function's params as a source of truth.

-- MID: This code needs to be refactored:
-- - Fixups to type and desc should still be handled here, since they concern the integrity of
--   the underlying data.
-- - A table containing the inlinedoc data should be added to the item, either overwriting
--   desc or as a new field
-- - The rendering step should then format the table data, rather than duplicating code here.
-- - desc_append_see_class_tag should apply to union types where a class is found within it
-- Until that's done, only update this code for bug fixes.

---@param is_list boolean
---@param parent string?
---@return string
local function inlinedoc_get_defaut_desc(is_list, parent)
    if is_list then
        return "A list of objects with the following fields:"
    elseif parent then
        return string.format("Extends |%s| with the additional fields:", parent)
    else
        return "A table with the following fields:"
    end
end

---@param doc_item docgen.DocItem Modified in place
---@param class docgen.ParserObj
---@param is_list boolean
local function inlinedoc_inject_into_desc(doc_item, class, is_list)
    local new_doc_tbl = table_new(4, 0) ---@type string[]

    local old_desc = doc_item.desc or ""
    local class_desc = class.desc
    if class_desc then
        new_doc_tbl[1] = old_desc .. " " .. class_desc
    elseif #old_desc == 0 then
        local inline_desc = inlinedoc_get_defaut_desc(is_list, class.parent)
        new_doc_tbl[1] = old_desc .. " " .. inline_desc
    end

    local fields = class.fields ---@type docgen.DocItem[]
    table.sort(class.fields, function(a, b)
        return a.name < b.name
    end)

    local field_name_width_max = list_fold(fields, 0, function(field, acc)
        return math.max(#field.name, acc)
    end)

    for _, field in ipairs(class.fields) do
        local name = cbraces_add(field.name, field_name_width_max)
        local typ = type_fmt_get_with_default(field.type, field.default)
        -- Do now so later rendering has cleaner data to work with.
        local desc = md_to_vimdoc(field.desc or "")
        new_doc_tbl[#new_doc_tbl + 1] = table.concat({ "-", name, typ, desc }, " ")
    end

    doc_item.desc = table.concat(new_doc_tbl, "\n")
end

---@param doc_item docgen.DocItem
---@param class docgen.ParserObj
local function desc_append_see_class_tag(doc_item, class)
    local old_desc = doc_item.desc or ""
    local len_desc = #old_desc

    local tag = "|" .. class.tag .. "|"
    if len_desc == 0 then
        doc_item.desc = "See " .. tag .. "."
        return
    end

    if string.find(old_desc, tag) then
        doc_item.desc = old_desc
        return
    end

    local punctuation = endswith_byte(old_desc, 46) and " " or ". "
    doc_item.desc = old_desc .. punctuation .. "See " .. tag .. "."
end

---Assumes that typ has already had nils and extra spaces cleaned up.
---@param typ string
---@return string base, boolean is_optional, boolean is_list
local function parse_clean_class_type(typ)
    if (not typ) or typ == "" then
        return "", false, false
    end

    local list_count
    typ, list_count = string.gsub(typ, "%[%]$", "")
    local q_count
    typ, q_count = string.gsub(typ, "%?", "")

    return typ, q_count > 0, list_count > 0
end

--- @param doc_item docgen.DocItem Modified in place
--- @param classes table<string,docgen.ParserObj>
--- @return docgen.ParserObj?, boolean, boolean
local function type_find_class(doc_item, classes)
    local typ = doc_item.type
    if not typ then
        return nil, false, false
    end

    local typ_clean, typ_isopt, typ_islist = parse_clean_class_type(typ)
    local class = classes[typ_clean]
    if (not class) or class.doc_flag == "nodoc" then
        return nil, false, false
    end

    return class, typ_isopt, typ_islist
end

--- @param doc_item docgen.DocItem Modified in place
--- @param class docgen.ParserObj
--- @param typ_isopt boolean
--- @param typ_islist boolean
local function add_class_desc_to_doc_item(doc_item, class, typ_isopt, typ_islist)
    if class.doc_flag ~= "inlinedoc" then
        desc_append_see_class_tag(doc_item, class)
        return
    end

    inlinedoc_inject_into_desc(doc_item, class, typ_islist)

    local typ_tbl = { "table" }
    if typ_islist then
        typ_tbl[#typ_tbl + 1] = "[]"
    end

    if typ_isopt then
        typ_tbl[#typ_tbl + 1] = "?"
    end

    doc_item.type = table.concat(typ_tbl)
end

---@param obj docgen.ParserObj
---@param classes table<string,docgen.ParserObj> All classes from all files.
local function inlinedoc_inject(obj, classes)
    if obj.kind == "fun" then
        local params = obj.params
        if not params then
            -- TODO: Don't love this because it doesn't just go to the end.
            goto do_returns
        end

        for _, param in ipairs(obj.params) do
            local class, typ_isopt, typ_islist = type_find_class(param, classes)
            if class then
                add_class_desc_to_doc_item(param, class, typ_isopt, typ_islist)
            end
        end

        ::do_returns::
        local returns = obj.returns
        if not returns then
            return
        end

        for _, r in ipairs(returns) do
            local len_r = #r
            for j = 1, len_r do
                local class, typ_isopt, typ_islist = type_find_class(r[j], classes)
                if class then
                    add_class_desc_to_doc_item(r, class, typ_isopt, typ_islist)
                end
            end
        end
    elseif obj.kind == "class" then
        for _, field in ipairs(obj.fields) do
            local class, typ_isopt, typ_islist = type_find_class(field, classes)
            if class then
                add_class_desc_to_doc_item(field, class, typ_isopt, typ_islist)
            end
        end
    end
end

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
            local kind = obj.kind
            if kind == "fun" then
                -- Use the unique tag because function namevars do not have to be globally unique.
                local tag = obj.tag --[[@as string]]
                if not funs[tag] then
                    funs[tag] = obj
                else
                    error("Duplicate fun " .. tag .. " from source " .. source[1])
                end
                funs[obj.tag] = obj
            elseif kind == "class" then
                -- Globally unique LuaCATs class name
                local name = obj.name --[[@as string]]
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

        local class = classes[class_name]
        if class then
            class_attach_fun_field(class, fun)
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
            return not (obj.kind == "class" and obj.doc_flag == "inlinedoc")
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
        inlinedoc_inject(fun, classes)
    end

    for _, class in pairs(classes) do
        inlinedoc_inject(class, classes)
    end

    parsed_sources_filter_inlinedoc(parsed_sources)
end
-- MAYBE: If specific issues with the incoming file results repeatedly come up, add runtime
-- checking if inexpensive.

return M
