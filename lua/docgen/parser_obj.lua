-- Forked version of the Neovim core docgen.

local logger = require("docgen.logger")
local log_warning = logger.log_warning

local luacats_grammar = require("docgen.luacats_grammar")

local ts_parsing = require("docgen.ts_parsing")
local md_to_vimdoc = ts_parsing.luacats_md_to_vimdoc

local util = require("docgen.util")
local cbraces_add = util.add_cbraces
local checked_append = util.checked_append
local endswith_byte = util.endswith_byte
local list_filter = util.list_filter
local rtrim = util.rtrim
local startswith_byte = util.startswith_byte
local str_has_content = util.str_has_content
local table_clear = util.table_clear
local table_new = util.table_new
local type_fmt_get_with_default = util.type_fmt_get_with_default

local const = require("docgen.const")
local NBSP = const.NBSP

--- @class docgen.DocItem : nvim.luacats.grammar.Result
--- @field classvar? string
--- @field default? string
--- @field nodoc? boolean

---@alias docgen.Kind docgen.luacats.Kind|"fun"
---@alias docgen.Access 'private'|'protected'|'package'
---@alias docgen.LastDocItem "param"|"return"|"_"
---@alias docgen.Visibility "deprecated"|"nodoc"|"inlinedoc"

---@class (exact) docgen.ParserObj
---@field package access? docgen.Access
---@field package async_flag? boolean
---@field package class? string
---@field package classvar? string
---@field package cur_doc_item? docgen.LastDocItem
---@field package desc? string
---@field package doc_flag? docgen.Visibility
---@field package doc_flag_desc? string
---@field package doc_lines? string[] Uncommitted doc lines
---@field package fields? docgen.DocItem[]
---@field package header_tag? string
---@field package kind? docgen.Kind
---@field package modvar? string
---@field package name? string
---@field package namevar? string
---@field package overloads? string[]
---@field package params? docgen.DocItem[]
---@field package parent? string
---@field package prev_indent integer
---@field package returns? docgen.DocItem[]
---@field package see? string[]
---@field package sep? string
---0: Can accept new lines
---1: Finalized and valid
---2: Finalized and invalid
---@field package status? 0|1|2
---@field package tag? string
---@field package type? docgen.DocItem
---
---@field __index fun(self:docgen.ParserObj, key:any): val:any
---@field new fun(modvar:string, module:string): parser_obj:docgen.ParserObj
local M = {}

---@generic T
---@param self docgen.ParserObj
---@param key T
---@return any
function M.__index(self, key)
    return rawget(M, key) or rawget(self, key)
end

---@param modvar string
---@param header_tag string
---@return docgen.ParserObj
function M.new(modvar, header_tag)
    local obj = setmetatable(table_new(0, 8), M)

    rawset(obj, "header_tag", header_tag)
    rawset(obj, "modvar", modvar)

    rawset(obj, "prev_indent", 0)
    rawset(obj, "status", 0)

    return obj
end

---------------------
-- MARK: Inlinedoc --
---------------------

-- MID: This code needs to be refactored:
-- - Fixups to type and desc should still be handled here, since they concern the integrity of
--   the underlying data.
-- - A table containing the inlinedoc data should be added to the item, either overwriting
--   desc or as a new field
-- - The rendering step should then format the table data, rather than duplicating code here.
-- - desc_append_see_class_tag should apply to union types where a class is found within it
-- For now, keep this code sectioned off from the rest of the module. Should only be updated for
-- bug fixes.

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

    class:fields_sort(function(a, b)
        return a.name < b.name
    end)

    local width = class:field_names_max_width() + 2
    class:fields_iter(function(field)
        local name = cbraces_add(field.name, width)
        local typ = type_fmt_get_with_default(field.type, field.default)
        -- Do now so later rendering has cleaner data to work with.
        local desc = md_to_vimdoc(field.desc or "")
        new_doc_tbl[#new_doc_tbl + 1] = table.concat({ "-", name, typ, desc }, " ")
    end)

    doc_item.desc = table.concat(new_doc_tbl, "\n")
end

---@param doc_item docgen.DocItem
---@param class docgen.ParserObj
local function desc_append_see_class_tag(doc_item, class)
    local old_desc = doc_item.desc or ""
    local len_desc = #old_desc

    local tag = "|" .. class:tag_get() .. "|"
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

--- @param classes table<string,docgen.ParserObj> All classes from all files.
function M:inlinedoc_inject(classes)
    if self.kind == "fun" then
        self:params_iter(function(r)
            local class, typ_isopt, typ_islist = type_find_class(r, classes)
            if class then
                add_class_desc_to_doc_item(r, class, typ_isopt, typ_islist)
            end
        end)

        self:returns_iter(function(r)
            local len_r = #r
            for j = 1, len_r do
                local class, typ_isopt, typ_islist = type_find_class(r[j], classes)
                if class then
                    add_class_desc_to_doc_item(r, class, typ_isopt, typ_islist)
                end
            end
        end)
    elseif self.kind == "class" then
        self:fields_iter(function(f)
            local class, typ_isopt, typ_islist = type_find_class(f, classes)
            if class then
                add_class_desc_to_doc_item(f, class, typ_isopt, typ_islist)
            end
        end)
    end
end

-------------------------
-- MARK: Local Item Utils
-------------------------

-- For these, and for the self utils, keep the item_ and self_ prefixes so their usages is
-- obvious on dot completion.

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

---@param type string
---@return boolean
local function type_can_accept_opt(type)
    return not (endswith_byte(type, 63) or string.find("nil", type, 1, true) ~= nil)
end

---@param item nvim.luacats.grammar.Result Modified in place
local function item_type_fixup(item)
    local typ = item.type ---@type string
    typ = rtrim(typ)
    typ = string.gsub(typ, "%s*|%s*", "|")
    typ = string.gsub(typ, "|nil", "?")
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
        if type_can_accept_opt(item.type) then
            item.type = typ .. opt
        end
    else
        item.type = typ
    end
end

-------------------------
-- MARK: Local Self Utils
-------------------------

---@param self docgen.ParserObj
---@param kind string
local function self_assert_is_kind(self, kind)
    local self_kind = rawget(self, "kind")
    if self_kind ~= kind then
        error("Current obj is not " .. kind .. " ( " .. tostring(self_kind) .. ")")
    end
end

---@param self docgen.ParserObj
---@param kind string
local function self_assert_no_kind(self, kind)
    local self_kind = rawget(self, "kind")
    if self_kind then
        error("Cannot set " .. kind .. ". Kind is already " .. tostring(self_kind))
    end
end
-- MID: This is a leaky abstraction. "Kind" should be a generic description of what's going on
-- that is just appended to the current kind. This way callers can send what they want without
-- worrying about bad formatting.

---@param self docgen.ParserObj
---@return boolean
local function self_is_hidden_by_annotation(self)
    local access = rawget(self, "access")
    if not (access == nil or access == "exact") then
        return true
    end

    if rawget(self, "doc_flag") == "nodoc" then
        return true
    end

    return false
end

---@param self docgen.ParserObj
---@param key string
---@return table
local function self_get_or_create_table_field(self, key)
    local val = rawget(self, key)
    if val then
        return val
    end

    local new_val = {}
    rawset(self, key, new_val)
    return new_val
end

---@generic T
---@param self docgen.ParserObj
---@param key string
---@param val T
---@return T
local function self_set_and_get(self, key, val)
    rawset(self, key, val)
    return val
end

---------------------
-- MARK: Doc Lines --
---------------------

---@param self docgen.ParserObj
---@param line string
local function doc_line_add(self, line)
    if self_is_hidden_by_annotation(self) or rawget(self, "cur_doc_item") == "_" then
        return
    end

    local doc_lines = self_get_or_create_table_field(self, "doc_lines")
    -- Save lines without content as `""` so that markdown parsing can recognize paragraph gaps.
    doc_lines[#doc_lines + 1] = rtrim(line)
end

---@param self docgen.ParserObj
---@param take? boolean Return the doc_lines to the caller. Requires self.last_doc_item to be nil
---@param new_doc_item? string
---@return string?
local function doc_lines_commit(self, take, new_doc_item)
    local doc_lines = rawget(self, "doc_lines") ---@type string[]?
    if doc_lines == nil or #doc_lines == 0 then
        rawset(self, "cur_doc_item", new_doc_item)
        return
    end

    local doc_lines_str = table.concat(doc_lines, "\n")
    table_clear(doc_lines)
    local cur_doc_item = rawget(self, "cur_doc_item") ---@type docgen.LastDocItem?
    if take then
        -- Malformed LuaCATs
        assert(
            cur_doc_item == nil,
            "Cannot take doc_lines. cur_doc_item is " .. tostring(cur_doc_item)
        )

        rawset(self, "cur_doc_item", new_doc_item)
        return doc_lines_str
    end

    if cur_doc_item == "param" then
        local params = rawget(self, "params") ---@type docgen.DocItem[]
        local last_param = params[#params]
        local desc = last_param.desc
        if str_has_content(desc) then
            last_param.desc = desc .. "\n" .. doc_lines_str
        else
            last_param.desc = doc_lines_str
        end
    elseif cur_doc_item == "return" then
        local returns = rawget(self, "returns") ---@type docgen.DocItem[]
        local last_return = returns[#returns]
        local desc = last_return.desc
        if str_has_content(desc) then
            last_return.desc = desc .. "\n" .. doc_lines_str
        else
            last_return.desc = doc_lines_str
        end
    else
        local desc = rawget(self, "desc") ---@type string?
        rawset(self, "desc", checked_append(desc, "\n", doc_lines_str))
    end

    rawset(self, "cur_doc_item", new_doc_item)
end

---------------
-- MARK: All --
---------------

---@return string?
function M:desc_get()
    return rawget(self, "desc")
end

---@return docgen.Kind
function M:kind_get()
    return rawget(self, "kind")
end

---@return string?
function M:name_get()
    return rawget(self, "name")
end

---@return string?
function M:namevar_get()
    return rawget(self, "namevar")
end

---@return string?
function M:tag_get()
    return rawget(self, "tag")
end

----------------------------
-- MARK: Access Modifiers --
----------------------------

-- TODO: You can set access with aliases with @alias (private) foo. Should be accounted for.

---@param self docgen.ParserObj
local function access_set_package(self)
    local kind = rawget(self, "kind")
    if kind == "brief" or kind == "class" then
        log_warning("Attempting to set brief or class to package access")
        return
    end

    rawset(self, "access", "package")
end

---@param self docgen.ParserObj
local function access_set_private(self)
    local kind = rawget(self, "kind")
    if kind == "brief" or kind == "class" then
        log_warning("Attempting to set brief or class to private access")
        return
    end

    rawset(self, "access", "private")
end

---@param self docgen.ParserObj
local function access_set_protected(self)
    local kind = rawget(self, "kind")
    if kind == "brief" or kind == "class" then
        log_warning("Attempting to set brief or class to protected access")
        return
    end

    rawset(self, "access", "protected")
end

----------------------
-- MARK: Alias Info --
----------------------

---@param self docgen.ParserObj
---@param parsed nvim.luacats.grammar.Result
local function alias_set(self, parsed)
    local kind = "alias"
    self_assert_no_kind(self, kind)
    rawset(self, "kind", kind)
    rawset(self, "desc", parsed.desc)
end
-- TODO: Make these render
-- Blocker: Ordered rendering is not done
-- Lua_Ls only shows what appears above the alias, we should do the same. I think parsed.desc
-- contains the actual alias name/type but need to confirm.
-- Doclines after should reject and emit warnings
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

-----------------
-- MARK: Async --
-----------------

---@return boolean
function M:async_get()
    return self.async_flag == true
end

---@param self docgen.ParserObj
local function async_set(self)
    local kind = rawget(self, "kind")
    if kind == "class" or kind == "brief" then
        log_warning("Attempting to set async on non-function object")
        return
    end

    rawset(self, "async_flag", true)
end

------------------
-- MARK: Briefs --
------------------

---@param self docgen.ParserObj
---@param parsed nvim.luacats.grammar.Result
local function brief_set(self, parsed)
    local kind = "brief"
    self_assert_no_kind(self, kind)

    rawset(self, "desc", parsed.desc)
    rawset(self, "kind", kind)

    rawset(self, "access", nil)
    rawset(self, "async_flag", nil)
    rawset(self, "class", nil)
    rawset(self, "classvar", nil)
    rawset(self, "cur_doc_item", nil)
    rawset(self, "fields", nil)
    rawset(self, "tag", nil)
    rawset(self, "name", nil)
    rawset(self, "namevar", nil)
    rawset(self, "overloads", nil)
    rawset(self, "params", nil)
    rawset(self, "parent", nil)
    rawset(self, "returns", nil)
    rawset(self, "see", nil)
    rawset(self, "type", nil)

    local doc_lines = rawget(self, "doc_lines")
    if doc_lines and #doc_lines > 0 then
        table_clear(doc_lines)
        log_warning("Doc lines before @brief annotation")
    end
end

----------------------
-- MARK: Class Info --
----------------------

---Assumes that self and class are already finalized.
---Assumes that self.classvar and class.classvar have already been externally checked to match.
---@param self docgen.ParserObj
---@param class_in docgen.ParserObj
local function fun_set_class_info_from_class(self, class_in)
    rawset(self, "parent", class_in:parent_get())
    -- Module class functions should still be tagged as part of the module. Module LuaCATs tags
    -- should not be confusing. See |vim.pos|/|vim.Pos| for an example of this done right.
    -- DOC: This behavior.
    if rawget(self, "classvar") == rawget(self, "modvar") then
        return
    end

    rawset(self, "class", class_in:class_get())

    local class_tag = class_in:tag_get()
    local sep = rawget(self, "sep")
    local namevar = rawget(self, "namevar")
    rawset(self, "tag", class_tag .. sep .. namevar .. "()")

    local see = self_get_or_create_table_field(self, "see") ---@type string[]
    see[#see + 1] = "|" .. class_tag .. "|"
end

--- @param fun docgen.ParserObj Modified in place
function M:class_attach_fun_field(fun)
    local fields = self_get_or_create_table_field(self, "fields") ---@type docgen.DocItem[]
    local fun_namevar = fun:namevar_get()
    list_filter(fields, function(field)
        return field.name ~= fun_namevar
    end)

    fun_set_class_info_from_class(fun, self)

    -- Module classes should not duplicate the module physical function definitions.
    if rawget(self, "classvar") == rawget(self, "modvar") then
        return
    end

    local type_tbl = { "fun(" } ---@type string[]
    local params = {} ---@type string[]
    fun:params_iter(function(param)
        params[#params + 1] = string.format("%s:%s", param.name, param.type)
    end)

    type_tbl[#type_tbl + 1] = table.concat(params, ", ")
    type_tbl[#type_tbl + 1] = ")"

    if self:returns_count() > 0 then
        type_tbl[#type_tbl + 1] = ": "
        local fun_ret_types = {} ---@type string[]
        fun:returns_iter(function(r)
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
        end)
    end

    local fun_tag = fun:tag_get() --[[@as string]]
    fields[#fields + 1] = {
        kind = "field",
        name = fun:namevar_get(),
        type = table.concat(type_tbl, ""),
        desc = "See: |" .. fun_tag .. "|",
    }
end
-- MID: Functions currently, properly, filter out self if they are methods when they are finalized.
-- However, function types, like the one above, need to include the self variable then they are
-- defined in LuaCATs. Colon functions should hold onto the self var when they are created, only
-- removing the self var if they attach to a class (since they would be dropped from rendering
-- otherwise). Re-adding self here de-values the function's params as a source of truth.

---@return string?
function M:class_get()
    return rawget(self, "class")
end

---@param self docgen.ParserObj
---@param parsed nvim.luacats.grammar.Result
local function class_set(self, parsed)
    local kind = "class"
    self_assert_no_kind(self, kind)

    rawset(self, "kind", kind)
    local name = parsed.name
    rawset(self, "name", name)
    -- Use help prefix because classes have global scope
    -- Dash separated because using dots to informally specify class scope is common.
    rawset(self, "tag", Nvim_Tools_Docgen_Help_Prefix .. "-" .. name)
    rawset(self, "class", name)
    rawset(self, "parent", parsed.parent)

    rawset(self, "access", nil)
    rawset(self, "async_flag", nil)
    rawset(self, "classvar", nil)
    rawset(self, "desc", nil)
    rawset(self, "fields", nil)
    rawset(self, "cur_doc_item", nil)
    rawset(self, "overloads", nil)
    rawset(self, "params", nil)
    rawset(self, "returns", nil)

    local doc_lines = doc_lines_commit(self, true)
    if doc_lines then
        rawset(self, "desc", doc_lines)
    else
        local desc = rawget(self, "desc")
        if desc then
            if #desc > 0 then
                rawset(self, "desc", rtrim(desc))
            else
                rawset(self, "desc", nil)
            end
        end
    end
end

---@return string?
function M:classvar_get()
    return rawget(self, "classvar")
end

---@return string?
function M:parent_get()
    return self.parent
end

--------------------
-- MARK: Doc Flag --
--------------------

---@return "deprecated"|"inlinedoc"|"nodoc"
function M:doc_flag_get()
    return self.doc_flag
end

---@return string?
function M:doc_flag_desc_get()
    return self.doc_flag_desc
end

---@param self docgen.ParserObj
---@param parsed nvim.luacats.grammar.Result
local function doc_flag_set_deprecated(self, parsed)
    if rawget(self, "kind") == "brief" then
        log_warning("Attemping to set brief to deprecated")
        return
    end

    rawset(self, "doc_flag", "deprecated")
    rawset(self, "doc_flag_desc", parsed.desc)
end
-- MID: Support this in briefs. Could be used for module or section level deprecation.
-- MID:DEP: Use doc lines above for the description. I'm not sure what the Lua_Ls/Emmylua_ls tags
-- themselves attach to though. Is it legal to put `@deprecated` before a param? If so then you'd
-- need to check cur_doc_item to see if you can commit. If it's not legal, then it would be an
-- error.

---@param self docgen.ParserObj
local function doc_flag_set_inlinedoc(self)
    if rawget(self, "doc_flag") == "nodoc" then
        log_warning("Attemping to set inlinedoc on nodoc object")
        return
    end

    local kind = rawget(self, "kind")
    if not (kind == nil or kind == "class") then
        log_warning("Attemping to set inlinedoc on non-class object")
        return
    end

    rawset(self, "doc_flag", "inlinedoc")
end

---@param self docgen.ParserObj
local function doc_flag_set_nodoc(self)
    rawset(self, "doc_flag", "nodoc")
end

------------------
-- MARK: Fields --
------------------

---@param self docgen.ParserObj
---@param item nvim.luacats.grammar.Result Edited in place
---@return boolean should_add
local function field_add_common(self, item)
    if rawget(self, "status") > 0 then
        -- Skip validation since we aren't dealing with LuaCATs input.
        return true
    end

    -- Errors because params without functions are invalid LuaCATs.
    self_assert_is_kind(self, "class")

    local doc_lines = doc_lines_commit(self, true)
    if item.access ~= nil or startswith_byte(item.name, 95) then
        return false
    end

    if doc_lines then
        item.desc = doc_lines
    else
        item.desc = str_has_content(item.desc) and rtrim(item.desc) or nil
    end

    item_type_fixup(item)
    item_extract_default_from_desc(item)

    return true
end
-- Outlined in case we need a prepend function.

---@param self docgen.ParserObj
---@param parsed nvim.luacats.grammar.Result
local function field_append(self, parsed)
    if not field_add_common(self, parsed) then
        return
    end

    local fields = self_get_or_create_table_field(self, "fields")
    fields[#fields + 1] = parsed --[[@as docgen.DocItem]]
end

---@return integer
function M:fields_count()
    return self.fields and #self.fields or 0
end

---@param f fun(field:docgen.DocItem)
function M:fields_iter(f)
    local fields = rawget(self, "fields")
    if not fields then
        return
    end

    for _, field in ipairs(fields) do
        f(field)
    end
end

---@return integer
function M:field_names_max_width()
    local max_name_width = 0
    local fields = rawget(self, "fields")
    if not fields then
        return max_name_width
    end

    for _, field in ipairs(fields) do
        max_name_width = math.max(#field.name, max_name_width)
    end

    return max_name_width
end

---@param predicate fun(a:docgen.DocItem, b:docgen.DocItem): boolean
function M:fields_sort(predicate)
    local fields = rawget(self, "fields")
    if not fields then
        return
    end

    table.sort(fields, predicate)
end

---------------------
-- MARK: Overloads --
---------------------

---@param self docgen.ParserObj
---@param parsed nvim.luacats.grammar.Result
local function overload_append(self, parsed)
    local kind = rawget(self, "kind")
    if not (kind == "class" or kind == "fun") then
        log_warning("Attemping to add overload to non-class/function object")
        return
    end

    local overloads = self_get_or_create_table_field(self, "overloads")
    overloads[#overloads + 1] = parsed.type
end

---@return integer
function M:overloads_count()
    local overloads = rawget(self, "overloads")
    return overloads ~= nil and #overloads or 0
end

---@param f fun(overload:string)
function M:overloads_iter(f)
    local overloads = rawget(self, "overloads")
    if not overloads then
        return
    end

    for _, overload in ipairs(overloads) do
        f(overload)
    end
end

------------------
-- MARK: Params --
------------------

---@param self docgen.ParserObj Modified in place
---@param item docgen.DocItem Modified in place
---@return boolean should_add
local function param_add_common(self, item)
    self_assert_no_kind(self, "param")

    local name = item.name ---@type string
    if startswith_byte(name, 95) then
        doc_lines_commit(self, false, "_")
        return false
    else
        local params = rawget(self, "params") ---@type docgen.DocItem[]?
        local prev_param = (params and #params > 0) and params[#params] or nil
        if prev_param then
            local prev_name = prev_param.name ---@type string
            if prev_param and startswith_byte(prev_name, 95) then
                -- This would make the param layout in the doc not match the physical function.
                error("Invalid: Public param " .. name .. "after private param " .. prev_name)
            end
        end
    end

    doc_lines_commit(self, false, "param")
    item_type_fixup(item)
    item.desc = item.desc and rtrim(item.desc) or nil

    return true
end
-- Outlined in case we need a prepend function.

---@param self docgen.ParserObj Modified in place
---@param item docgen.DocItem
local function param_append(self, item)
    if not param_add_common(self, item) then
        return
    end

    local params = self_get_or_create_table_field(self, "params") ---@type docgen.DocItem[]
    params[#params + 1] = item --[[@as docgen.DocItem]]
end
-- TEST: The LuaCATs grammar needs to have a test that, in order to return a valid param, the
-- name and type must be present.

---@return integer
function M:params_count()
    local params = rawget(self, "params") ---@type docgen.DocItem[]?
    return params ~= nil and #params or 0
end

---@return integer
function M:param_names_max_width()
    local max_name_width = 0
    for _, param in ipairs(self.params) do
        max_name_width = math.max(#param.name, max_name_width)
    end

    return max_name_width
end
-- NON: Don't outline the inner logic. Gets too convoluted.

---@param f fun(param:docgen.DocItem)
function M:params_iter(f)
    local params = rawget(self, "params")
    if not params then
        return
    end

    for _, param in ipairs(params) do
        f(param)
    end
end

-------------------
-- MARK: Returns --
-------------------

---@param self docgen.ParserObj Modified in place
---@param parsed nvim.luacats.grammar.Result
local function return_append(self, parsed)
    self_assert_no_kind(self, "return")

    list_filter(parsed, function(p)
        return p.type ~= nil and p.type ~= "nil"
    end)

    local len_parsed = #parsed
    if len_parsed == 0 then
        doc_lines_commit(self, false, "_")
        return
    else
        doc_lines_commit(self, false, "return")
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
    local returns = self_get_or_create_table_field(self, "returns")
    returns[#returns + 1] = parsed --[[@as docgen.DocItem]]
end
-- DOC: Name usage behavior
-- DOC: The return syntax.
-- - @return (`type`) {name} some amount of other characters that can be the desc
-- - @return (`type`) {optional_one_word_name}, (`type`) {optional_name} Then desc at the end
-- - Desc on its own lines will be appended to the desc of the previous return

---@return integer
function M:returns_count()
    return self.returns and #self.returns or 0
end

---@param f fun(ret:docgen.DocItem)
function M:returns_iter(f)
    local returns = rawget(self, "returns")
    if not returns then
        return
    end

    for _, r in ipairs(returns) do
        f(r)
    end
end

---------------
-- MARK: See --
---------------

---@param self docgen.ParserObj
---@param parsed nvim.luacats.grammar.Result
local function see_add(self, parsed)
    if rawget(self, "kind") == "brief" then
        log_warning("Attempting to add see tag to non-class/fun object")
        return
    end

    local see = self_get_or_create_table_field(self, "see")
    see[#see + 1] = parsed.desc
end

---@return integer
function M:see_count()
    return self.see ~= nil and #self.see or 0
end

---@param f fun(see:string)
function M:see_iter(f)
    local see = rawget(self, "see")
    if not see then
        return
    end

    for _, s in ipairs(see) do
        f(s)
    end
end

----------------
-- MARK: Type --
----------------

---@param self docgen.ParserObj
---@param parsed nvim.luacats.grammar.Result
local function type_set(self, parsed)
    if rawget(self, "kind") == "brief" then
        log_warning("Attempting to add type to non-class/fun object")
        return
    end

    rawset(self, "desc", parsed.desc)
    rawset(self, "type", parsed)
end
-- MID: When multiple functions have the same signature, it is useful to use an aliased type to
-- annotate them. Update type processing so types are actually parsed.

--------------------------
-- MARK: Building Tools --
--------------------------

local transform = {
    ["alias"] = alias_set,
    ["async"] = async_set,
    ["brief"] = brief_set,
    ["class"] = class_set,
    ["diagnostic"] = function() end,
    ["deprecated"] = doc_flag_set_deprecated,
    ["field"] = field_append,
    ["inlinedoc"] = doc_flag_set_inlinedoc,
    ["nodoc"] = doc_flag_set_nodoc,
    ["operator"] = field_append,
    ["overload"] = overload_append,
    ["package"] = access_set_package,
    ["param"] = param_append,
    ["private"] = access_set_private,
    ["protected"] = access_set_protected,
    ["return"] = return_append,
    ["see"] = see_add,
    ["type"] = type_set,
}

---@param parsed nvim.luacats.grammar.Result
function M:add_parsed(parsed)
    if self_is_hidden_by_annotation(self) then
        return
    end

    local transform_fn = transform[parsed.kind]
    if transform_fn then
        transform_fn(self, parsed)
    else
        log_warning("No transform fn for parsed tag " .. parsed.kind)
    end
end

---@param self docgen.ParserObj
---@param namevar string
---@param classvar string
---@param sep "."|":"
---@return boolean finalized
local function fun_finalize(self, classvar, sep, namevar)
    self_assert_no_kind(self, "function")

    if startswith_byte(namevar, 95) then
        return false
    end

    rawset(self, "kind", "fun")
    rawset(self, "classvar", classvar)
    rawset(self, "sep", sep)
    rawset(self, "namevar", namevar)

    local header_tag = rawget(self, "header_tag")
    if classvar == rawget(self, "modvar") then
        -- Functions need to be tied to a class name to render. Because module functions do not
        -- apply class info, set the value now.
        rawset(self, "class", header_tag)
        rawset(self, "tag", header_tag .. sep .. namevar .. "()")
    else
        rawset(self, "class", nil)
        local tag = header_tag .. "." .. classvar .. sep .. namevar .. "()"
        rawset(self, "tag", tag)
    end

    rawset(self, "fields", nil)
    rawset(self, "parent", nil)

    local params = rawget(self, "params")
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

---@param self docgen.ParserObj
---@param line string
---@return boolean Found a class function?
local function try_finalize_fun(self, line)
    local classvar, sep, namevar =
        line:match("^function%s+([a-zA-Z0-9_]+)([.:])([a-zA-Z0-9_]+)%s*%(")
    if classvar and namevar then
        return fun_finalize(self, classvar, sep, namevar)
    end

    classvar, namevar = line:match("([a-zA-Z_]+)%.([a-zA-Z0-9_]+)%s*=%s*function%s*%(")
    if classvar and namevar then
        return fun_finalize(self, classvar, ".", namevar)
    end

    return false
end

---@param self docgen.ParserObj
---@param line string
local function class_finalize(self, line)
    local classvar = line:match("^local%s+([a-zA-Z0-9_]+)%s*=")
    if classvar then
        rawset(self, "classvar", classvar)
    end

    local parentvar
    parentvar, classvar = line:match("([a-zA-Z_]+)%.([a-zA-Z0-9_]+)%s*=%s*%{")
    if parentvar == rawget(self, "modvar") then
        rawset(self, "classvar", classvar)
    end
end

--- @param line? string
function M:finalize(line)
    if self_is_hidden_by_annotation(self) then
        return self_set_and_get(self, "status", 2)
    end

    doc_lines_commit(self)

    local kind = self:kind_get()
    if kind == "brief" then
        local status = str_has_content(rawget(self, "desc")) and 1 or 2
        return self_set_and_get(self, "status", status)
    end

    if kind == "class" then
        if line then
            class_finalize(self, line)
        end

        return self_set_and_get(self, "status", 1)
    end

    if
        line == nil
        or (not str_has_content(line))
        or string.find(line, "^%s*local%s+")
        or string.find(line, "^%s*return%s+")
        or string.find(line, "^%s*%-%- luacheck:")
        or string.find(line, "^%s*[a-zA-Z_.]+%(%s+")
    then
        return self_set_and_get(self, "status", 2)
    end

    if try_finalize_fun(self, line) then
        return self_set_and_get(self, "status", 1)
    end

    return self_set_and_get(self, "status", 2)
end

---@param line string
---@return 0|1|2 status
function M:add_line(line)
    local status = rawget(self, "status")
    if status > 0 then
        error("Cannot add line to finalized object")
    end

    -- Expensive, but simplifies assumptions downstream
    line = rtrim(line)
    line = string.gsub(line, "\t", string.rep(" ", 8))
    line = string.gsub(line, NBSP, " ")

    local is_doc_line = string.find(line, "^%-%-%-")
    if is_doc_line then
        if self_is_hidden_by_annotation(self) then
            return status
        end

        line = string.sub(line, 4)
        local prev_indent_was_set = false
        line = string.gsub(line, "^(%s+)@", function(ws)
            rawset(self, "prev_indent", #ws)
            prev_indent_was_set = true
            return "@"
        end)

        if not prev_indent_was_set then
            rawset(self, "prev_indent", 0)
        end

        ---@type nvim.luacats.grammar.Result?
        local parsed = luacats_grammar:match(line)
        if parsed then
            self:add_parsed(parsed)
        else
            local prev_indent = rawget(self, "prev_indent") ---@type integer
            if prev_indent > 0 then
                line = string.gsub(line, "^%s{" .. prev_indent .. "}", "")
            end

            doc_line_add(self, line)
        end

        return status
    else
        return self:finalize(line)
    end
end
-- TEST: prev_indent sets on parsed lines and trims doc lines
-- TEST: prev_indent changes on new parsed lines

return M
