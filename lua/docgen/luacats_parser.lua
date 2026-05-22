local logger = require("docgen.logger")
local log_warning = logger.log_warning

local luacats_grammar = require("docgen.luacats_grammar")

local util = require("docgen.util")
local checked_append = util.checked_append
local endswith_byte = util.endswith_byte
local list_filter = util.list_filter
local rtrim = util.rtrim
local startswith_byte = util.startswith_byte
local table_clear = util.table_clear
local table_new = util.table_new
local table_get_or_create_subtable = util.table_get_or_create_subtable

local const = require("docgen.const")
local NBSP = const.NBSP

--- @class docgen.DocItem : nvim.luacats.grammar.Result
--- @field classvar? string
--- @field default? string
--- @field inlinedesc? docgen.ParserObj
--- @field nodoc? boolean

---@alias docgen.Kind docgen.luacats.Kind|"fun"
---@alias docgen.Access 'private'|'protected'|'package'
---@alias docgen.LastDocItem "param"|"return"|"_"
---@alias docgen.Visibility "deprecated"|"nodoc"|"inlinedoc"

---@class docgen.ParserObj
---@field access? docgen.Access
---@field async_flag? boolean
---@field class? string
---@field classvar? string
---@field cur_doc_item? docgen.LastDocItem
---@field desc? string
---@field doc_flag? docgen.Visibility
---@field doc_flag_desc? string
---@field doc_lines? string[] Uncommitted doc lines
---@field fields? docgen.DocItem[]
---@field header_tag? string
---@field kind? docgen.luacats.Kind
---@field modvar? string
---@field name? string
---@field namevar? string
---@field overloads? string[]
---@field params? docgen.DocItem[]
---@field parent? string
---@field prev_indent? integer
---@field returns? docgen.DocItem[]
---@field see? string[]
---@field sep? string
---0: Can accept new lines
---1: Finalized and valid
---2: Finalized and invalid
---@field status? 0|1|2
---@field tag? string
---@field type? docgen.DocItem

--- @param item nvim.luacats.grammar.Result|docgen.DocItem Modified in place
local function item_extract_default_from_desc(item)
    local desc = item.desc
    if not desc then
        return
    end

    local default = string.match(desc, "^%s*%([dD]efault: ([^)]+)%)")
    if default then
        item.desc = string.gsub(desc, "^%s*%([dD]efault: [^)]+%)", "")
        item.default = default
        return
    end

    default = string.match(desc, "\n%s*%([dD]efault: ([^)]+)%)")
    if default then
        item.desc = string.gsub(desc, "\n%s*%([dD]efault: [^)]+%)", "")
        item.default = default
    end
end
-- DOC: This has to be the first thing on the line or after the type to be used.
-- TEST: Removes at beginning of line and after \n. Handles variable whitespace
-- TEST: Does not remove in the middle of the line.

---@param item nvim.luacats.grammar.Result Modified in place
local function item_type_fixup(item)
    local typ = item.type ---@type string
    typ = rtrim(typ)
    typ = string.gsub(typ, "%s*|%s*", "|")
    typ = string.gsub(typ, "|nil$", "?")
    typ = string.gsub(typ, "nil|(.*)", "%1?")
    typ = string.gsub(typ, "%?+$", "?")

    local name = item.name
    if not name then
        item.type = typ
        return
    end

    local name_part, opt = string.match(name, "^([^?]*)(%??)$")
    if opt == "?" then
        item.name = name_part
        if not (endswith_byte(typ, 63) or string.find("nil", typ, 1, true)) then
            item.type = typ .. opt
        end
    else
        item.type = typ
    end
end

---@param obj docgen.ParserObj
---@param kind string
local function obj_assert_no_kind(obj, kind)
    local obj_kind = obj.kind
    if obj_kind then
        error("Cannot set " .. kind .. ". Kind is already " .. tostring(obj_kind))
    end
end
-- MID: This is a leaky abstraction. "Kind" should be a generic description of what's going on
-- that is just appended to the current kind. This way callers can send what they want without
-- worrying about bad formatting.

---@param obj docgen.ParserObj
---@param target_kind docgen.Kind|nil
---@param msg string
local function obj_kind_assert(obj, target_kind, msg)
    local kind = obj.kind
    if kind ~= target_kind then
        error("Obj kind " .. kind .. ": " .. msg)
    end
end

---@param obj docgen.ParserObj
---@return boolean
local function obj_hidden_by_annotations(obj)
    local access = obj.access
    if not (access == nil or access == "exact") then
        return true
    elseif obj.doc_flag == "nodoc" then
        return true
    else
        return false
    end
end

---@generic T
---@param obj docgen.ParserObj Modified in place
---@param key string
---@param val T
---@return T
local function obj_set_and_get(obj, key, val)
    rawset(obj, key, val)
    return val
end

---@param obj docgen.ParserObj Modified in place
---@param line string
local function obj_doc_line_append(obj, line)
    if obj_hidden_by_annotations(obj) or obj.cur_doc_item == "_" then
        return
    end

    local doc_lines = table_get_or_create_subtable(obj, "doc_lines")
    -- Always save the line, even if rtrim turns it into `""`, to preserve paragraph gaps.
    doc_lines[#doc_lines + 1] = rtrim(line)
end

---@param obj docgen.ParserObj Modified in place
---@param take? boolean Return the doc_lines to the caller. Requires obj.last_doc_item to be nil
---@param new_doc_item? string
---@return string?
local function obj_doc_lines_commit(obj, take, new_doc_item)
    local doc_lines = rawget(obj, "doc_lines") ---@type string[]?
    if doc_lines == nil or #doc_lines == 0 then
        rawset(obj, "cur_doc_item", new_doc_item)
        return
    end

    local doc_lines_str = table.concat(doc_lines, "\n")
    table_clear(doc_lines)
    local cur_doc_item = rawget(obj, "cur_doc_item") ---@type docgen.LastDocItem?
    if take then
        -- Malformed LuaCATs
        assert(
            cur_doc_item == nil,
            "Cannot take doc_lines. cur_doc_item is " .. tostring(cur_doc_item)
        )

        rawset(obj, "cur_doc_item", new_doc_item)
        return doc_lines_str
    end

    if cur_doc_item == "param" then
        local params = rawget(obj, "params") ---@type docgen.DocItem[]
        local last_param = params[#params]
        local desc = last_param.desc
        if desc and string.find(desc, "[^%s]") ~= nil then
            last_param.desc = desc .. "\n" .. doc_lines_str
        else
            last_param.desc = doc_lines_str
        end
    elseif cur_doc_item == "return" then
        local returns = rawget(obj, "returns") ---@type docgen.DocItem[]
        local last_return = returns[#returns]
        local desc = last_return.desc
        if desc and string.find(desc, "[^%s]") ~= nil then
            last_return.desc = desc .. "\n" .. doc_lines_str
        else
            last_return.desc = doc_lines_str
        end
    else
        local desc = rawget(obj, "desc") ---@type string?
        rawset(obj, "desc", checked_append(desc, "\n", doc_lines_str))
    end

    rawset(obj, "cur_doc_item", new_doc_item)
end

---@param obj docgen.ParserObj Modified in place
local function obj_access_set_package(obj)
    local kind = rawget(obj, "kind")
    if kind == "brief" or kind == "class" then
        log_warning("Attempting to set brief or class to package access")
        return
    end

    rawset(obj, "access", "package")
end

---@param obj docgen.ParserObj Modified in place
local function obj_access_set_private(obj)
    local kind = rawget(obj, "kind")
    if kind == "brief" or kind == "class" then
        log_warning("Attempting to set brief or class to private access")
        return
    end

    rawset(obj, "access", "private")
end

---@param obj docgen.ParserObj Modified in place
local function obj_access_set_protected(obj)
    local kind = rawget(obj, "kind")
    if kind == "brief" or kind == "class" then
        log_warning("Attempting to set brief or class to protected access")
        return
    end

    rawset(obj, "access", "protected")
end

---Commits obj doc lines and sets cur_doc_item to nil
---@param obj docgen.ParserObj Modified in place
---@param parsed nvim.luacats.grammar.Result'
local function obj_desc_set_from_doc_lines_or_parsed(obj, parsed)
    local doc_lines = obj_doc_lines_commit(obj, true)
    if doc_lines and string.find(doc_lines, "[^%s]") ~= nil then
        obj.desc = doc_lines
        return
    end

    local parsed_desc = parsed.desc
    if parsed_desc and string.find(parsed_desc, "[^%s]") ~= nil then
        obj.desc = rtrim(parsed_desc)
    end
end

---@param obj docgen.ParserObj Modified in place
---@param parsed nvim.luacats.grammar.Result
local function obj_kind_alias_set(obj, parsed)
    if obj.kind == "class" then
        -- Creates an invalid class definition
        error("Cannot set an alias within a class definition")
    elseif obj.kind == "brief" then
        log_warning("Alias definition within brief. Discarding")
        return
    end

    obj.kind = "alias"
    obj_desc_set_from_doc_lines_or_parsed(obj, parsed)
end
-- TODO: Make these render
-- Lua_Ls only shows what appears above the alias, we should do the same. I think parsed.desc
-- contains the actual alias name/type but need to confirm.
-- any lines afterwards should emit warnings
-- Should support inlinedoc
-- - For inline doc, does Lua_Ls show the real type or the alias name?
-- Unsure about generics
-- Unsure about deprecation
-- Should obviously support nodoc
-- For the display, display in curly braces like classes with the formatted type name
-- next to it, either on the same line or below. A line break feels extra.
-- Need to be able to parse multiline definitions. Pipe separated.
-- - LuaCATs and Lua_Ls recognize '' and "" quoted
-- - You can do as many as you want on the first line (obviously)
-- - Additional values can only be one per line, and the pipe character has to be the first
-- non-whitespace
-- There needs to be support for checking for aliases and then linking to their helptags when
-- they show up
-- - This includes nested aliases
-- TODO: You can set access with aliases with @alias (private) foo. Should be accounted for.

---@param obj docgen.ParserObj Modified in place
local function obj_async_set(obj)
    local kind = rawget(obj, "kind")
    if kind == "class" or kind == "brief" then
        log_warning("Async tag on an object that already has a kind. Discarding.")
        return
    end

    obj.async_flag = true
end

---@param obj docgen.ParserObj Modified in place
---@param parsed nvim.luacats.grammar.Result
local function obj_kind_brief_set(obj, parsed)
    if obj.kind ~= nil then
        log_warning("Cannot set brief. Obj kind is already " .. obj.kind)
        return
    end

    obj.kind = "brief"
    obj.desc = parsed.desc

    local doc_lines = obj.doc_lines
    if doc_lines and #doc_lines > 0 then
        table_clear(doc_lines)
        log_warning("Doc lines present before @brief annotation. Discarding.")
    end
end

---@param obj docgen.ParserObj Modified in place
---@param parsed nvim.luacats.grammar.Result
local function obj_kind_class_set(obj, parsed)
    obj_kind_assert(obj, nil, "Cannot create class in object with a kind")

    obj.kind = "class"
    local name = parsed.name
    obj.name = name
    obj.class = name
    obj.parent = parsed.parent

    -- Use help prefix because classes have global scope
    -- Dash separated because using dots to informally specify class scope is common.
    obj.tag = Nvim_Tools_Docgen_Help_Prefix .. "-" .. name
    obj_desc_set_from_doc_lines_or_parsed(obj, parsed)
end

---@param obj docgen.ParserObj Modified in place
---@param parsed nvim.luacats.grammar.Result
local function obj_doc_flag_set_deprecated(obj, parsed)
    if rawget(obj, "kind") == "brief" then
        log_warning("Cannot deprecate a brief. Discarding.")
        return
    end

    obj.doc_flag = "deprecated"
    obj.doc_flag_desc = parsed.desc
end
-- MID: Support this in briefs. Could be used for module or section level deprecation.
-- MID:DEP: Use doc_lines above for the description.
-- - I don't want to build this out more until I know if we're using a `@replaces` tag or
-- something similar.
-- - This would need to detect if the object kind is a class or if cur_doc_item ~= nil. The
-- single deprecation line can be used, but this should still emit a warning.

---@param obj docgen.ParserObj Modified in place
local function obj_doc_flag_set_inlinedoc(obj)
    local kind = obj.kind
    if not (kind == nil or kind == "class") then
        log_warning("Cannot set inlinedoc on non-class object. Discarding.")
        return
    end

    if obj.doc_flag == "nodoc" then
        log_warning("Cannot set a @nodoc object to @inline doc. Discarding.")
        return
    end

    obj.doc_flag = "inlinedoc"
end

---@param obj docgen.ParserObj Modified in place
local function obj_doc_flag_set_nodoc(obj)
    obj.doc_flag = "nodoc"
end

---@param obj docgen.ParserObj Modified in place
---@param parsed nvim.luacats.grammar.Result
local function obj_field_append(obj, parsed)
    obj_kind_assert(obj, "class", "Fields must be declared after @class.")

    local doc_lines = obj_doc_lines_commit(obj, true)
    if parsed.access ~= nil or startswith_byte(parsed.name, 95) then
        return
    end

    if doc_lines ~= nil and string.find(doc_lines, "[^%s]") ~= nil then
        parsed.desc = doc_lines
    elseif parsed.desc ~= nil and string.find(parsed.desc, "[^%s]") ~= nil then
        parsed.desc = rtrim(parsed.desc)
    else
        parsed.desc = nil
    end

    item_type_fixup(parsed)
    item_extract_default_from_desc(parsed)

    local fields = table_get_or_create_subtable(obj, "fields")
    fields[#fields + 1] = parsed --[[@as docgen.DocItem]]
end

---@param obj docgen.ParserObj Modified in place
---@param parsed nvim.luacats.grammar.Result
local function obj_overload_append(obj, parsed)
    local kind = rawget(obj, "kind")
    if kind == "brief" then
        log_warning("Cannot add an overload to a brief. Discarding.")
        return
    end

    local overloads = table_get_or_create_subtable(obj, "overloads")
    overloads[#overloads + 1] = parsed.type
end

---@param obj docgen.ParserObj Modified in place
---@param item docgen.DocItem Modified in place
---@return boolean should_add
local function param_add_common(obj, item)
    obj_assert_no_kind(obj, "param")

    local name = item.name ---@type string
    if startswith_byte(name, 95) then
        obj_doc_lines_commit(obj, false, "_")
        return false
    else
        local params = rawget(obj, "params") ---@type docgen.DocItem[]?
        local prev_param = (params and #params > 0) and params[#params] or nil
        if prev_param then
            local prev_name = prev_param.name ---@type string
            if prev_param and startswith_byte(prev_name, 95) then
                -- This would make the param layout in the doc not match the physical function.
                error("Invalid: Public param " .. name .. "after private param " .. prev_name)
            end
        end
    end

    obj_doc_lines_commit(obj, false, "param")
    item_type_fixup(item)
    item.desc = item.desc and rtrim(item.desc) or nil

    return true
end
-- Outlined in case we need a prepend function.

---@param obj docgen.ParserObj Modified in place
---@param item docgen.DocItem
local function obj_param_append(obj, item)
    if not param_add_common(obj, item) then
        return
    end

    local params = table_get_or_create_subtable(obj, "params") ---@type docgen.DocItem[]
    params[#params + 1] = item --[[@as docgen.DocItem]]
end
-- TEST: The LuaCATs grammar needs to have a test that, in order to return a valid param, the
-- name and type must be present.

---@param obj docgen.ParserObj Modified in place
---@param parsed nvim.luacats.grammar.Result
local function obj_return_append(obj, parsed)
    obj_assert_no_kind(obj, "return")

    list_filter(parsed, function(p)
        return p.type ~= nil and p.type ~= "nil"
    end)

    local len_parsed = #parsed
    if len_parsed == 0 then
        obj_doc_lines_commit(obj, false, "_")
        return
    else
        obj_doc_lines_commit(obj, false, "return")
    end

    local last_name = parsed[len_parsed].name
    local parsed_desc = parsed.desc
    if last_name and parsed_desc then
        local merge_last_name = true
        local len_parsed_minus_one = len_parsed - 1
        -- Intentionally leave merge_last_name == true if only one return
        for i = 1, len_parsed_minus_one do
            if parsed[i].name ~= nil then
                merge_last_name = false
                break
            end
        end

        if merge_last_name then
            parsed.desc = last_name .. " " .. parsed_desc
            parsed[len_parsed].name = nil
        end
    end

    parsed.desc = parsed.desc and rtrim(parsed.desc) or nil
    for _, p in ipairs(parsed) do
        item_type_fixup(p)
    end

    ---@type docgen.DocItem[]
    local returns = table_get_or_create_subtable(obj, "returns")
    returns[#returns + 1] = parsed --[[@as docgen.DocItem]]
end
-- DOC: Name usage behavior
-- DOC: The return syntax.
-- - @return (`type`) {name} some amount of other characters that can be the desc
-- - @return (`type`) {optional_one_word_name}, (`type`) {optional_name} Then desc at the end
-- - Desc on its own lines will be appended to the desc of the previous return

---@param obj docgen.ParserObj Modified in place
---@param parsed nvim.luacats.grammar.Result
local function obj_see_add(obj, parsed)
    if rawget(obj, "kind") == "brief" then
        log_warning("Attempting to add see tag to non-class/fun object")
        return
    end

    local see = table_get_or_create_subtable(obj, "see")
    see[#see + 1] = parsed.desc
end

---@param obj docgen.ParserObj Modified in place
---@param parsed nvim.luacats.grammar.Result
local function obj_type_set(obj, parsed)
    if rawget(obj, "kind") == "brief" then
        log_warning("Attempting to add type to non-class/fun object")
        return
    end

    rawset(obj, "desc", parsed.desc)
    rawset(obj, "type", parsed)
end
-- MID: When multiple functions have the same signature, it is useful to use an aliased type to
-- annotate them. Update type processing so types are actually parsed.

--------------------------
-- MARK: Building Tools --
--------------------------

local transform = {
    ["alias"] = obj_kind_alias_set,
    ["async"] = obj_async_set,
    ["brief"] = obj_kind_brief_set,
    ["class"] = obj_kind_class_set,
    ["deprecated"] = obj_doc_flag_set_deprecated,
    ["diagnostic"] = function() end,
    ["field"] = obj_field_append,
    ["inlinedoc"] = obj_doc_flag_set_inlinedoc,
    ["nodoc"] = obj_doc_flag_set_nodoc,
    ["operator"] = obj_field_append,
    ["overload"] = obj_overload_append,
    ["package"] = obj_access_set_package,
    ["param"] = obj_param_append,
    ["private"] = obj_access_set_private,
    ["protected"] = obj_access_set_protected,
    ["return"] = obj_return_append,
    ["see"] = obj_see_add,
    ["type"] = obj_type_set,
}

---@param obj docgen.ParserObj Modified in place
---@param parsed nvim.luacats.grammar.Result
local function obj_process_parsed(obj, parsed)
    local transform_fn = transform[parsed.kind]
    if transform_fn then
        transform_fn(obj, parsed)
    else
        log_warning("No transform fn for parsed tag " .. parsed.kind)
    end
end

---@param obj docgen.ParserObj Modified in place
---@param namevar string
---@param classvar string
---@param sep "."|":"
---@return boolean finalized
local function fun_finalize(obj, classvar, sep, namevar)
    obj_assert_no_kind(obj, "function")

    if startswith_byte(namevar, 95) then
        return false
    end

    rawset(obj, "kind", "fun")
    rawset(obj, "classvar", classvar)
    rawset(obj, "sep", sep)
    rawset(obj, "namevar", namevar)

    local header_tag = rawget(obj, "header_tag")
    if classvar == rawget(obj, "modvar") then
        -- Functions need to be tied to a class name to render. Because module functions do not
        -- apply class info, set the value now.
        rawset(obj, "class", header_tag)
        rawset(obj, "tag", header_tag .. sep .. namevar .. "()")
    else
        rawset(obj, "class", nil)
        local tag = header_tag .. "." .. classvar .. sep .. namevar .. "()"
        rawset(obj, "tag", tag)
    end

    rawset(obj, "fields", nil)
    rawset(obj, "parent", nil)

    local params = rawget(obj, "params")
    if params then
        if sep == ":" then
            list_filter(params, function(param)
                return param.name ~= "self"
            end)
        end

        -- Wait until now because param annotations are read down from the tag.
        for _, param in ipairs(params) do
            item_extract_default_from_desc(param)
        end
    end

    return true
end

---@param obj docgen.ParserObj Modified in place
---@param line string
---@return boolean Found a class function?
local function try_finalize_fun(obj, line)
    local classvar, sep, namevar =
        line:match("^function%s+([a-zA-Z0-9_]+)([.:])([a-zA-Z0-9_]+)%s*%(")
    if classvar and namevar then
        return fun_finalize(obj, classvar, sep, namevar)
    end

    classvar, namevar = line:match("([a-zA-Z_]+)%.([a-zA-Z0-9_]+)%s*=%s*function%s*%(")
    if classvar and namevar then
        return fun_finalize(obj, classvar, ".", namevar)
    end

    return false
end

---@param obj docgen.ParserObj Modified in place
---@param line string
local function class_finalize(obj, line)
    local classvar = line:match("^local%s+([a-zA-Z0-9_]+)%s*=")
    if classvar then
        rawset(obj, "classvar", classvar)
        return
    end

    local parentvar
    parentvar, classvar = line:match("([a-zA-Z_]+)%.([a-zA-Z0-9_]+)%s*=%s*%{")
    if parentvar == rawget(obj, "modvar") then
        rawset(obj, "classvar", classvar)
    end
end

---@param obj docgen.ParserObj Modified in place
---@param line? string
local function finalize(obj, line)
    if obj_hidden_by_annotations(obj) then
        return obj_set_and_get(obj, "status", 2)
    end

    obj_doc_lines_commit(obj)

    local kind = obj.kind
    if kind == "brief" then
        obj.status = obj.desc ~= nil and string.find(obj.desc, "[^%s]") ~= nil and 1 or 2
        return obj.status
    end

    if kind == "class" then
        if line then
            class_finalize(obj, line)
        end

        return obj_set_and_get(obj, "status", 1)
    end

    if
        line == nil
        or string.find(line, "[^%s]") == nil
        or string.find(line, "^%s*local%s+")
        or string.find(line, "^%s*return%s+")
        or string.find(line, "^%s*%-%- luacheck:")
        or string.find(line, "^%s*[a-zA-Z_.]+%(%s+")
    then
        return obj_set_and_get(obj, "status", 2)
    end

    if try_finalize_fun(obj, line) then
        return obj_set_and_get(obj, "status", 1)
    end

    return obj_set_and_get(obj, "status", 2)
end

---@param obj docgen.ParserObj Modified in place
---@param line string
---@return 0|1|2 status
local function obj_append_line(obj, line)
    line = rtrim(line)
    line = string.gsub(line, "\t", string.rep(" ", 8))
    line = string.gsub(line, NBSP, " ")

    local is_doc_line = string.find(line, "^%-%-%-")
    if is_doc_line then
        if obj_hidden_by_annotations(obj) then
            return obj.status
        end

        line = string.sub(line, 4)
        local did_set_prev_indent = false
        line = string.gsub(line, "^(%s+)@", function(ws)
            obj.prev_indent = #ws
            did_set_prev_indent = true
            return "@"
        end)

        if not did_set_prev_indent then
            obj.prev_indent = 0
        end

        ---@type nvim.luacats.grammar.Result?
        local parsed = luacats_grammar:match(line)
        if parsed then
            obj_process_parsed(obj, parsed)
        else
            local prev_indent = obj.prev_indent
            if prev_indent > 0 then
                line = string.gsub(line, "^%s{" .. prev_indent .. "}", "")
            end

            obj_doc_line_append(obj, line)
        end

        return obj.status
    else
        return finalize(obj, line)
    end
end
-- TEST: prev_indent sets on parsed lines and trims doc lines
-- TEST: prev_indent changes on new parsed lines

local M = {}

---@param modvar string
---@param header_tag string
---@return docgen.ParserObj
local function obj_new(header_tag, modvar)
    local obj = table_new(0, 8)
    obj.header_tag = header_tag
    obj.modvar = modvar
    obj.prev_indent = 0
    obj.status = 0

    return obj
end

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

---@param lines string[]
---@param header_tag string
---@return docgen.ParsedSource
function M.parsed_from_lines(lines, header_tag)
    local modvar = find_modvar(lines) or ""

    local obj_list = {} ---@type docgen.ParserObj[]
    local obj = obj_new(header_tag, modvar)
    for _, line in ipairs(lines) do
        local status = obj_append_line(obj, line)
        if status > 0 then
            if status == 1 then
                obj_list[#obj_list + 1] = obj
            end

            obj = obj_new(header_tag, modvar)
        end
    end

    local status = finalize(obj, "")
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
