local ts_parsing = require("docgen.ts_parsing")
local md_to_vimdoc = ts_parsing.luacats_md_to_vimdoc

local util = require("docgen.util")
local cbraces_add = util.cbraces_add
local checked_append = util.checked_str_append
local endswith_byte = util.endswith_byte
local lua_pattern_get_escaped = util.lua_pattern_escape
local help_tag_from_name = util.help_tag_from_name
local list_filter = util.list_filter
local startswith_byte = util.startswith_byte
local table_clear = util.table_clear
local table_new = util.table_new

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
---@field package async? boolean
---@field package class? string
---@field package classvar? string
---@field package cur_doc_item? docgen.LastDocItem
---@field package desc? string
---@field package doc_desc? string
---@field package doc_flag? docgen.Visibility
---@field package doc_lines? string[] Uncommitted doc lines
---@field package fields? docgen.DocItem[]
---@field package finalized? boolean
---@field package fmt_name? string
---@field package kind? docgen.Kind
---@field package module? string
---@field package modvar? string
---@field package name? string
---@field package namevar? string
---@field package overloads? string[]
---@field package params? docgen.DocItem[]
---@field package parent? string
---@field package returns? docgen.DocItem[]
---@field package see? string[]
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
    return rawget(self, key) or rawget(M, key)
end

---@param modvar string
---@param module string
---@return docgen.ParserObj
function M.new(modvar, module)
    local obj = setmetatable(table_new(0, 8), M)
    rawset(obj, "modvar", modvar)
    rawset(obj, "module", module)

    return obj
end

-----------------
-- MARK: Utils --
-----------------

---@param item docgen.DocItem|nvim.luacats.grammar.Result
local function assert_has_name(item)
    if item.name == nil or item.name == "" then
        error("Doc item has no name: " .. vim.inspect(item))
    end
end
-- MID: Why do I have to specify a type union for the Luacats grammar when DocItem is a
-- superset of it?

---@param self docgen.ParserObj
---@param kind string
local function assert_no_kind(self, kind)
    if self.kind then
        error("Cannot set " .. kind .. ". Kind is already " .. tostring(self.kind))
    end
end
-- MID: The output could be nicer/more specific depending on if you are trying to set a doc item
-- or the actual kind (like a param vs. setting class state).

---@param self docgen.ParserObj
---@param kind string
local function assert_is_kind(self, kind)
    if self.kind ~= kind then
        error("Current obj is not " .. kind .. " ( " .. tostring(self.kind) .. ")")
    end
end

---@param item docgen.ParserObj|docgen.DocItem
---@return boolean
local function item_is_visible(item)
    if item.access ~= nil and item.access ~= "exact" then
        return false
    end

    if item.doc_flag == "nodoc" then
        return false
    end

    local name = item.name
    if not name then
        return true
    end

    if startswith_byte(name, 95) then
        return false
    end

    if item.kind == "fun" and string.find(name, "[:.]_") then
        return false
    end

    return true
end

---@param type string
---@return boolean
local function type_can_accept_opt(type)
    return not (endswith_byte(type, 63) or string.find("nil", type, 1, true) ~= nil)
end

---@param item docgen.DocItem Modified in place
local function item_move_opt(item)
    local name, opt = string.match(item.name, "^([^?]*)(%??)$")
    if name and opt then
        item.name = name
        if type_can_accept_opt(item.type) then
            item.type = item.type .. "?"
        end
    end
end

---@param desc string
---@return string
local function desc_inject_help_prefix(desc)
    local init, _ = string.find(desc, "|%S+|")
    if not init then
        return desc
    end

    local prefix = lua_pattern_get_escaped(Nvim_Tools_Docgen_Help_Prefix)
    if string.find(desc, "|" .. prefix .. ".%S+|", init) ~= nil then
        return desc
    end

    desc = string.gsub(desc, "|(%S+)|", "|" .. prefix .. ".%1|")
    return desc
end

---@param typ string
---@return string
local function type_fixup(typ)
    typ = string.gsub(vim.trim(typ), "%s*|%s*", "|")
    typ = string.gsub(typ, "|nil", "?")
    typ = string.gsub(typ, "nil|(.*)", "%1?")
    typ = string.gsub(typ, "%?+$", "?")

    return typ
end

---@param typ string
---@param default? string
local function type_fmt_get_with_default(typ, default)
    if not default then
        return string.format("(`%s`)", typ)
    end

    return string.format("(`%s`, default: %s)", typ, default)
end

------------------------
-- MARK: Format Utils --
------------------------

---@param self docgen.ParserObj
---@param iter fun(self:docgen.ParserObj, f:fun(x:docgen.DocItem))
---@return integer
local function arg_fmt_names_max_width(self, iter)
    local width = 0
    iter(self, function(arg)
        -- Add two because display names are surrounded by curly braces.
        width = math.max(width, #arg.name + 2)
    end)

    return width
end
-- MAYBE: The original code included a check to see if the item has a type or description. I think
-- this was so items without those values would not contribute to the max display width. I'm not
-- sure if that's helpful. Re-add if a situation comes up where it's necessary.

---Creates a new table.
---@param self docgen.ParserObj
---@param width integer
---@param iter fun(self:docgen.ParserObj, f:fun(x:docgen.DocItem))
---@param f fun(name:string, typ:string, desc:string): string
---@return string[]
local function args_fmt_map(self, width, iter, f)
    local ret = {}
    iter(self, function(arg)
        local name = arg.kind == "operator" and ("op(" .. arg.name .. ")")
            or cbraces_add(arg.name, width)
        local typ = arg.type and type_fmt_get_with_default(arg.type, arg.default) or ""
        local desc = arg.desc and arg.desc or ""

        ret[#ret + 1] = f(name, typ, desc)
    end)

    return ret
end

----------------------------
-- MARK: Inline Doc Tools --
----------------------------

-- FUTURE: Hold any revisions to this code for now. What needs to be introduced is a
-- "Make holistic data revisions" step that edits the data based on the accumulated Parser Objects.
-- So stuff like inlinedoc or class function descriptions would all be updated then, rather than
-- during individual parsing. We'd want to handle inline doc then through that lens.

---@param is_list boolean
---@param parent string?
---@return string
local function get_class_inline_type_desc(is_list, parent)
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
local function add_class_inlinedoc(doc_item, class, is_list)
    local new_doc_tbl = table_new(4, 0) ---@type string[]

    local old_desc = doc_item.desc or ""
    local class_desc = class.desc
    if class_desc then
        new_doc_tbl[1] = old_desc .. " " .. class_desc
    elseif #old_desc == 0 then
        local inline_desc = get_class_inline_type_desc(is_list, class.parent)
        new_doc_tbl[1] = old_desc .. " " .. inline_desc
    end

    local width = class:field_fmt_names_max_width()
    class:fields_iter(function(field)
        local name = cbraces_add(field.name, width)
        local typ = type_fmt_get_with_default(field.type, field.default)
        new_doc_tbl[#new_doc_tbl + 1] = table.concat({ "-", name, typ, field.desc }, " ")
    end)

    doc_item.desc = table.concat(new_doc_tbl, "\n")
end

---@param doc_item docgen.DocItem
---@param class docgen.ParserObj
local function append_doc_item_desc_see_class_tag(doc_item, class)
    local old_desc = doc_item.desc and string.match(doc_item.desc, "^.*%S") or "" -- rtrim
    local len_desc = #old_desc

    local tag = help_tag_from_name(class.name, "|")
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
-- LOW: The rtrim here might not be necessary.

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
-- LOW: It might be helpful to be able to do inlinedoc on union types. Doesn't inherently
-- blend in well though.
-- LOW: Cache these results.

--- @param doc_item docgen.DocItem Modified in place
--- @param classes table<string,docgen.ParserObj>
--- @return docgen.ParserObj?, boolean, boolean
local function find_class_in_doc_item_type(doc_item, classes)
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

---@param is_list boolean
---@param is_optional boolean
---@return string
local function get_class_table_type(is_list, is_optional)
    local typ_tbl = { "table" }
    if is_list then
        typ_tbl[#typ_tbl + 1] = "[]"
    end

    if is_optional then
        typ_tbl[#typ_tbl + 1] = "?"
    end

    return table.concat(typ_tbl, "")
end

--- @param doc_item docgen.DocItem Modified in place
--- @param class docgen.ParserObj
--- @param typ_isopt boolean
--- @param typ_islist boolean
local function add_class_desc_to_doc_item(doc_item, class, typ_isopt, typ_islist)
    if class.doc_flag ~= "inlinedoc" then
        append_doc_item_desc_see_class_tag(doc_item, class)
        return
    end

    add_class_inlinedoc(doc_item, class, typ_islist)
    doc_item.type = get_class_table_type(typ_islist, typ_isopt)
end

--- @param classes table<string,docgen.ParserObj> All classes from all files.
function M:inlinedoc_inject(classes)
    if self.kind == "fun" then
        self:params_iter(function(r)
            local class, typ_isopt, typ_islist = find_class_in_doc_item_type(r, classes)
            if class then
                add_class_desc_to_doc_item(r, class, typ_isopt, typ_islist)
            end
        end)

        self:returns_iter(function(r)
            local len_r = #r
            for j = 1, len_r do
                local class, typ_isopt, typ_islist = find_class_in_doc_item_type(r[j], classes)
                if class then
                    add_class_desc_to_doc_item(r, class, typ_isopt, typ_islist)
                end
            end
        end)
    elseif self.kind == "class" then
        self:fields_iter(function(f)
            local class, typ_isopt, typ_islist = find_class_in_doc_item_type(f, classes)
            if class then
                add_class_desc_to_doc_item(f, class, typ_isopt, typ_islist)
            end
        end)
    end
end
-- TODO: Still unsure where this function sits. This both sets data and does style.
-- Something that could help here is to dis-entangle everything. Having one big entrypoint instead
-- of a few different ones that resolve to composable pieces makes everything bloated.
-- I also think it might be helpful to separate out detecting if inlinedoc should be injected from
-- the actual process. The current function is reasonable but I'm looking for any advantage here
-- I can get.

----------------------------------
-- MARK: Data Maintenance Utils --
----------------------------------

--- @param doc_item docgen.DocItem Modified in place
local function extract_default_type_from_desc(doc_item)
    local desc = doc_item.desc
    if not desc then
        return
    end

    local default = string.match(desc, "^%s*%([dD]efault: ([^)]+)%)")
    if default then
        doc_item.desc = string.gsub(desc, "^%s*%([dD]efault: [^)]+%)", "")
        doc_item.default = default
        return
    end

    default = string.match(desc, "\n%s*%([dD]efault: ([^)]+)%)")
    doc_item.desc = string.gsub(desc, "\n%s*%([dD]efault: [^)]+%)", "")
    doc_item.default = default
end
-- DOC: This has to be the first thing on the line or after the type to be used.
-- LOW: This function is inelegant.

---------------
-- MARK: All --
---------------

---@param parens? boolean
---@return string?
function M:fmt_name_get(parens)
    if parens then
        return self.fmt_name .. "()"
    end

    return self.fmt_name
end

---@return docgen.Kind
function M:kind_get()
    return self.kind
end

---@return string?
function M:get_fmt_desc()
    local desc = self.desc
    if desc then
        return md_to_vimdoc(desc)
    end
end

--- Assumes `self` is finalized and cross-checked against all other parser objects.
---@return boolean
function M:holistically_valid()
    local kind = self.kind
    if kind == "fun" then
        if self:class_fun_incomplete() then
            return false
        end
    end

    if kind == "class" then
        if self:fields_count() == 0 then
            return false
        end
    end

    return true
end

---@return string?
function M:name_get()
    return self.name
end

---@return string?
function M:namevar_get()
    return self.namevar
end

---@return boolean
function M:is_finalized()
    return self.finalized == true
end

----------------------------
-- MARK: Access Modifiers --
----------------------------

-- TODO: You can set access with aliases with @alias (private) foo. Should be accounted for.

function M:access_package_set()
    local kind = self.kind
    if kind == "brief" or kind == "class" then
        -- TODO: emit warning
        return
    end

    self.access = "package"
end

function M:access_private_set()
    local kind = self.kind
    if kind == "brief" or kind == "class" then
        -- TODO: emit warning
        return
    end

    self.access = "private"
end

function M:access_protected_set()
    local kind = self.kind
    if kind == "brief" or kind == "class" then
        -- TODO: emit warning
        return
    end

    self.access = "protected"
end

----------------------
-- MARK: Alias Info --
----------------------

---@param parsed nvim.luacats.grammar.Result
function M:alias_set(parsed)
    local kind = "alias"
    assert_no_kind(self, kind)

    self.kind = kind --[[@as docgen.Kind]]
    self.desc = parsed.desc
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

----------------------
-- MARK: Attributes --
----------------------

function M:async_set()
    local kind = self:kind_get()
    if kind == "class" or kind == "brief" then
        -- TODO: emit warning
        return
    end

    self.async = true
end

---@return string?
function M:get_fmt_async()
    if self.async == true then
        return "{async}"
    end
end

---@return boolean
function M:has_attributes()
    if self.kind ~= "fun" then
        return false
    end

    return self.async == true
end

---@return string?
function M:get_fmt_attributes()
    if not self:has_attributes() then
        return
    end

    local ret = {}
    if self.async == true then
        ret[#ret + 1] = self:get_fmt_async()
    end

    return table.concat(ret, "\n")
end

------------------
-- MARK: Briefs --
------------------

---@param parsed nvim.luacats.grammar.Result
function M:brief_set(parsed)
    local kind = "brief"
    assert_no_kind(self, kind)

    self.desc = parsed.desc
    self.kind = kind --[[@as docgen.Kind]]

    self.access = nil
    self.async = nil
    self.class = nil
    self.classvar = nil
    self.cur_doc_item = nil
    self.fields = nil
    self.fmt_name = nil
    self.name = nil
    self.namevar = nil
    self.overloads = nil
    self.params = nil
    self.parent = nil
    self.returns = nil
    self.see = nil
    self.type = nil

    if self:doc_lines_len() > 0 then
        table_clear(self.doc_lines)
        -- TODO: Emit warning
    end
end

---@return string
function M:get_fmt_brief()
    assert_is_kind(self, "brief")
    return md_to_vimdoc(self.desc)
end

----------------------
-- MARK: Class Info --
----------------------

---@return string?
function M:class_extends_get()
    local parent = self.parent
    if parent then
        return "Extends: " .. help_tag_from_name(parent, "|")
    end
end

---@return string?
function M:class_get()
    return self.class
end

---@return string?
function M:classvar_get()
    return self.classvar
end

---@param parsed nvim.luacats.grammar.Result
function M:class_set(parsed)
    local kind = "class"
    assert_no_kind(self, kind)
    assert_has_name(parsed)

    self.kind = kind
    self.name = parsed.name
    self.fmt_name = parsed.name
    self.class = parsed.name
    self.parent = parsed.parent

    self.access = nil
    self.async = nil
    self.classvar = nil
    self.desc = nil
    self.fields = nil
    self.cur_doc_item = nil
    self.overloads = nil
    self.params = nil
    self.returns = nil

    local doc_lines = self:doc_lines_commit(true)
    if doc_lines then
        self.desc = doc_lines
    else
        self.desc = (parsed.desc and parsed.desc ~= "") and vim.trim(parsed.desc) or nil
    end
end

---@return string?
function M:parent_get()
    return self.parent
end

---------------------
-- MARK: Doc Lines --
---------------------

---@param line string
function M:doc_line_add(line)
    if self.cur_doc_item == "_" then
        return
    end

    self.doc_lines = self.doc_lines or {}
    local doc_lines = self.doc_lines
    doc_lines[#doc_lines + 1] = line
end
-- MAYBE: The core docgen does a lot of legwork to manage indenting. Attemping to go without
-- all that, but can re-add as use cases come up.

---@param self docgen.ParserObj
---@return boolean
local function doc_lines_present(self)
    return self.doc_lines ~= nil and #self.doc_lines > 0
end
-- MAYBE: This could iterate through the doc lines to see if they contain non-whitespace content.

---@param take? boolean
---@return string?
function M:doc_lines_commit(take)
    if not doc_lines_present(self) then
        self.cur_doc_item = nil
        return
    end

    if self.cur_doc_item == "_" then
        table_clear(self.doc_lines)
        self.cur_doc_item = nil
        return
    end

    -- Already checked in doc_lines_present
    local doc_lines = self.doc_lines --[[ @as string[] ]]
    local doc_lines_str = table.concat(doc_lines, "\n")
    table_clear(self.doc_lines)
    if take then
        return doc_lines_str
    end

    if self.cur_doc_item == "param" then
        if self:params_count() == 0 then
            error("Last doc item set to params, but no params")
        end

        local last_param = self.params[#self.params]
        last_param.desc = checked_append(last_param.desc, "\n" .. doc_lines_str, true)
    elseif self.cur_doc_item == "return" then
        if self:returns_count() == 0 then
            error("Last doc item set to returns, but no returns")
        end

        local last_return = self.returns[#self.returns]
        last_return.desc = checked_append(last_return.desc, "\n" .. doc_lines_str, true)
    else
        self.desc = checked_append(self.desc, "\n" .. doc_lines_str, true)
    end

    self.cur_doc_item = nil
end

---@param doc_item string
---@param commit_prev boolean
function M:cur_doc_item_set(doc_item, commit_prev)
    if commit_prev then
        self:doc_lines_commit()
    end

    self.cur_doc_item = doc_item
end

---@return integer
function M:doc_lines_len()
    return self.doc_lines ~= nil and #self.doc_lines or 0
end

--------------------
-- MARK: Doc Flag --
--------------------

---@return "deprecated"|"inlinedoc"|"nodoc"
function M:doc_flag_get()
    return self.doc_flag
end

---@return string?
function M:fmt_doc_desc_get()
    local ret = {}
    if self.doc_flag == "deprecated" then
        ret[#ret + 1] = "DEPRECATED:"
    end

    local doc_desc = self.doc_desc
    if not doc_desc then
        return table.concat(ret, " ")
    end

    ret[#ret + 1] = md_to_vimdoc(desc_inject_help_prefix(doc_desc))
    return table.concat(ret, " ")
end
-- DOC: Document the auto-replacement behavior exactly.
-- DOC: The behavior is consistent no matter where it is used.

---@param parsed docgen.DocItem
function M:deprecated_set(parsed)
    if self.kind == "brief" then
        -- TODO: emit warning
        return
    end

    self.doc_flag = "deprecated"
    self.doc_desc = parsed.desc
end
-- MID: Support this in briefs. Could be used for module or section level deprecation.
-- MAYBE: Use doc lines above for desc.

function M:deprecated()
    return self.doc_flag == "deprecated"
end

function M:inlinedoc_set()
    if self.doc_flag == "nodoc" then
        -- TODO: emit warning
        return
    end

    if self.kind == "brief" then
        -- TODO: emit warning
        return
    end

    self.doc_flag = "inlinedoc"
end
-- TODO: Add "warn_on" function

function M:nodoc_set()
    self.doc_flag = "nodoc"
end

------------------
-- MARK: Fields --
------------------

---@param self docgen.ParserObj
---@param item docgen.DocItem Edited in place
---@return boolean should_add
local function field_add_common(self, item)
    if self.finalized then
        -- Internal code should not send mal-formed data or expect doc lines to be present.
        return true
    end

    -- Errors because params without functions are invalid LuaCATs.
    assert_has_name(item)
    assert_is_kind(self, "class")

    local doc_lines = self:doc_lines_commit(true)
    if not (item_is_visible(self) and item_is_visible(item)) then
        return false
    end

    if doc_lines then
        item.desc = doc_lines
    else
        item.desc = (item.desc and item.desc ~= "") and item.desc or nil
        item.desc = item.desc and vim.trim(item.desc) or nil
    end

    item.type = type_fixup(item.type)
    item_move_opt(item)
    extract_default_type_from_desc(item)

    return true
end
-- Outlined in case we need a prepend function.

---@param item docgen.DocItem
function M:field_append(item)
    if not field_add_common(self, item) then
        return
    end

    self.fields = self.fields or {}
    local fields = self.fields
    fields[#fields + 1] = item --[[@as docgen.DocItem]]
end

--- @param fun docgen.ParserObj
function M:field_append_from_fun(fun)
    local type_tbl = { "fun(" }
    local params = {} ---@type string[]
    fun:params_iter(function(param)
        if param.name ~= self then
            params[#params + 1] = string.format("%s:%s", param.name, param.type)
        end
    end)

    type_tbl[#type_tbl + 1] = table.concat(params, ", ")
    type_tbl[#type_tbl + 1] = ")"
    if self:returns_count() > 0 then
        type_tbl[#type_tbl + 1] = ": "
        local fun_ret_types = {} --- @type string[]
        fun:returns_iter(function(r)
            local len_r = #r
            for j = 1, len_r do
                fun_ret_types[#fun_ret_types + 1] = r[j].type
            end

            type_tbl[#type_tbl + 1] = table.concat(fun_ret_types, ", ")
        end)
    end

    -- LOW: You could also edit the original field, but this is simpler.
    self:filter_fields(function(field)
        return field.name ~= fun.namevar
    end)

    self.fields = self.fields or {}
    local fields = self.fields
    local fun_fmt_name = fun:fmt_name_get(true) --[[@as string]]
    fields[#fields + 1] = {
        kind = "field",
        name = fun:namevar_get(),
        type = table.concat(type_tbl, ""),
        desc = "See: " .. help_tag_from_name(fun_fmt_name, "|"),
    }
end

---@return integer
function M:fields_count()
    return self.fields and #self.fields or 0
end

---Edits fields in place
---@param f fun(field:docgen.DocItem): boolean
function M:filter_fields(f)
    if self:fields_count() == 0 then
        return
    end

    list_filter(self.fields, f)
end

---@return integer
function M:field_fmt_names_max_width()
    if self:fields_count() == 0 then
        return 0
    end

    return arg_fmt_names_max_width(self, M.fields_iter)
end

---@param f fun(field:docgen.DocItem)
function M:fields_iter(f)
    if self:fields_count() == 0 then
        return
    end

    local fields = self.fields ---@type docgen.DocItem
    local len_fields = #fields
    for i = 1, len_fields do
        f(fields[i])
    end
end

---Returns a new table.
---@param f fun(name:string, typ:string, desc:string): string
---@return string[]|nil
function M:map_fmt_fields(f)
    if self:fields_count() == 0 then
        return
    end

    return args_fmt_map(self, self:field_fmt_names_max_width(), M.fields_iter, f)
end

-------------------------
-- MARK: Function Info --
-------------------------

---@return boolean
function M:class_fun_incomplete()
    return self.kind == "fun" and ((self.classvar == nil) ~= (self.class == nil))
end

---Assumes that self and class are already finalized.
---Assumes that self.classvar and class.classvar have already been externally checked to match.
---Assumes that class.visibility ~= "nodoc"
---@param class docgen.ParserObj
function M:class_fun_set_from_class(class)
    self.class = class:class_get()
    self.parent = class:parent_get()

    local class_fmt_name = class:fmt_name_get() --[[@as string]]
    self:see_add({ desc = help_tag_from_name(class_fmt_name, "|") })
end

---@param classvar string
---@param namevar string
---@param modvar string
---@param module string
---@param sep "."|":"
local function fun_fmt_name_get(classvar, namevar, modvar, module, sep)
    local modclass = classvar == modvar
    local sep_res = modclass and "." or sep
    local mod = modclass and module or classvar
    return mod .. sep_res .. namevar
end

---@param name string
---@param classvar string
---@param sep "."|":"
function M:fun_set_from_name(name, classvar, sep)
    assert_no_kind(self, "function")

    self.kind = "fun"
    self.namevar = name
    self.classvar = classvar
    if classvar == self.modvar then
        self.class = ""
    else
        self.class = nil
    end

    self.fmt_name = fun_fmt_name_get(self.classvar, self.namevar, self.modvar, self.module, sep)

    -- TODO: filter self here if sep == ":"

    self.fields = nil
    self.parent = nil
end

--- If true, then the `.` class member should render like a module function.
--- @return boolean
function M:is_module_fun()
    return self.kind == "fun" and self.classvar ~= nil and self.classvar == self.modvar
end

---------------------
-- MARK: Overloads --
---------------------

---@param parsed nvim.luacats.grammar.Result
function M:overload_append(parsed)
    if self.kind == "brief" then
        -- TODO: emit warning
        return
    end

    self.overloads = self.overloads or {}
    local overloads = self.overloads
    overloads[#overloads + 1] = parsed.type
end

---@return integer
function M:overloads_count()
    return self.overloads ~= nil and #self.overloads or 0
end

---@param f fun(overload:string)
function M:overloads_iter(f)
    if self:overloads_count() == 0 then
        return
    end

    local overloads = self.overloads ---@type string[]
    local len_overloads = #overloads
    for i = 1, len_overloads do
        f(overloads[i])
    end
end

---@return string?
function M:overloads_fmt_get()
    if self:overloads_count() == 0 then
        return
    end

    local ret = {}
    self:overloads_iter(function(overload)
        ret[#ret + 1] = "• " .. md_to_vimdoc(overload)
    end)

    return table.concat(ret, "\n")
end

------------------
-- MARK: Params --
------------------

---@param self docgen.ParserObj
---@param item docgen.DocItem
---@return boolean should_add
local function param_add_common(self, item)
    if self.finalized then
        -- Internal code should not send mal-formed data or expect doc lines to be present.
        return true
    end

    -- Errors because params without functions are invalid LuaCATs.
    assert_has_name(item)
    assert_no_kind(self, "param")
    if not item_is_visible(item) then
        self:cur_doc_item_set("_", true)
        return false
    end

    self:cur_doc_item_set("param", true)
    item.type = type_fixup(item.type)
    item_move_opt(item)

    return true
end
-- Outlined in case we need a prepend function.

---@param item docgen.DocItem
function M:param_append(item)
    if not param_add_common(self, item) then
        return
    end

    self.params = self.params or {}
    local params = self.params
    params[#params + 1] = item --[[@as docgen.DocItem]]
end

---@return integer
function M:params_count()
    return self.params ~= nil and #self.params or 0
end

---@return integer
function M:param_fmt_name_max_width()
    if self:params_count() == 0 then
        return 0
    end

    return arg_fmt_names_max_width(self, M.params_iter)
end

---@param f fun(param:docgen.DocItem)
function M:params_iter(f)
    if self:params_count() == 0 then
        return
    end

    local params = self.params ---@type docgen.DocItem[]
    local len_params = #params
    for i = 1, len_params do
        f(params[i])
    end
end

---@param width integer If a `{name}`'s width is less than `width`, then right padding will be
---     added to assist with alignment.
---@return string[]|nil
function M:params_fmt_get(width)
    if self:params_count() == 0 then
        return nil
    end

    local args = {}
    self:params_iter(function(param)
        local name = param.name
        if name ~= "self" then
            args[#args + 1] = cbraces_add(name, width)
        end
    end)

    return args
end

---Returns a new table.
---@param f fun(name:string, typ:string, desc:string): string
---@return string[]|nil
function M:params_fmt_map(f)
    if self:params_count() == 0 then
        return
    end

    return args_fmt_map(self, self:param_fmt_name_max_width(), M.params_iter, f)
end

-------------------
-- MARK: Returns --
-------------------

---@param parsed docgen.DocItem
function M:return_append(parsed)
    assert_no_kind(self, "return")

    if not item_is_visible(parsed) then
        self:cur_doc_item_set("_", true)
        return
    end

    list_filter(parsed, function(p)
        return p.type ~= nil and p.type ~= "nil"
    end)

    local len_parsed = #parsed
    if len_parsed == 0 then
        self:cur_doc_item_set("_", true)
        return
    end

    local last_name = parsed[len_parsed].name
    local parsed_desc = parsed.desc
    if last_name and parsed_desc then
        local merge_last_name = true
        local len_parsed_minus_one = len_parsed - 1
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

    for _, p in ipairs(parsed) do
        p.type = type_fixup(p.type)
    end

    self:cur_doc_item_set("return", true)
    if not self.returns then
        self.returns = {}
    end

    local returns = self.returns ---@type docgen.DocItem[]
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
    if self:returns_count() == 0 then
        return
    end

    local returns = self.returns ---@type docgen.DocItem[]
    local len_returns = #returns
    for i = 1, len_returns do
        f(returns[i])
    end
end

---@return string[]
function M:returns_fmt_get()
    if self:returns_count() == 0 then
        return {}
    end

    local ret = {} ---@type string[]
    local inner_ret = {} ---@type string[]

    self:returns_iter(function(r)
        local len_r = #r
        local names_count = 0
        for _, inner_r in ipairs(r) do
            local typ = type_fmt_get_with_default(inner_r.type)
            local name = inner_r.name
            if name then
                names_count = names_count + 1
                inner_ret[#inner_ret + 1] = typ .. " " .. cbraces_add(name, 0)
            else
                inner_ret[#inner_ret + 1] = typ
            end
        end

        local desc = r.desc
        local sep
        if len_r > 1 then
            sep = "\n"
            if desc then
                inner_ret[#inner_ret + 1] = desc
            end
        else
            sep = ""
            if desc then
                inner_ret[#inner_ret + 1] = ": "
                inner_ret[#inner_ret + 1] = desc
            end
        end

        ret[#ret + 1] = md_to_vimdoc(table.concat(inner_ret, sep))
        table_clear(inner_ret)
    end)

    return ret
end
-- MID: The output for multiple returns could be smarter:
-- - Currently sensitive to if the user uses multiple annotations or puts them on one line
-- - If multiple returns, desc is always on its own line
-- - For multiple returns on different lines, no formatting based on type/name width
-- I think you would have to do something similar to params and fields, where the iter passes up
-- the pieces of data and then the caller uses a mapper to determine the formatting.

---------------
-- MARK: See --
---------------

---@param parsed nvim.luacats.grammar.Result
function M:see_add(parsed)
    if self.kind == "brief" then
        -- TODO: emit warning
        return
    end

    self.see = self.see or {}
    local see = self.see
    see[#see + 1] = parsed.desc
end
-- MID: Support in briefs.

---@return integer
function M:see_count()
    return self.see ~= nil and #self.see or 0
end

---@param f fun(see:string)
function M:see_iter(f)
    if self:see_count() == 0 then
        return
    end

    local see = self.see ---@type string[]
    local len_see = #see
    for i = 1, len_see do
        f(see[i])
    end
end

---@return string?
function M:see_fmt_get()
    if self:see_count() == 0 then
        return
    end

    local ret = {}
    self:see_iter(function(see)
        ret[#ret + 1] = "• " .. md_to_vimdoc(desc_inject_help_prefix(see))
    end)

    return table.concat(ret, "\n")
end
-- DOC: Help prefix injection occurs here

----------------
-- MARK: Type --
----------------

---@param parsed nvim.luacats.grammar.Result
function M:type_set(parsed)
    if self.kind == "brief" then
        -- TODO: emit warning
        return
    end

    self.desc = parsed.desc
    self.type = parsed --[[@as docgen.DocItem]]
end
-- MID: For now, just support this the way the core docgen does. This leaves value on the table
-- though, as using canned types can be a good way to annotate multiple functions that have the
-- same or similar inputs/outputs.

--------------------------
-- MARK: Building Tools --
--------------------------

local transform = {
    ["alias"] = M.alias_set,
    ["async"] = M.async_set,
    ["brief"] = M.brief_set,
    ["class"] = M.class_set,
    ["deprecated"] = M.deprecated_set,
    ["field"] = M.field_append,
    ["inlinedoc"] = M.inlinedoc_set,
    ["nodoc"] = M.nodoc_set,
    ["operator"] = M.field_append,
    ["overload"] = M.overload_append,
    ["package"] = M.access_package_set,
    ["param"] = M.param_append,
    ["private"] = M.access_private_set,
    ["protected"] = M.access_protected_set,
    ["return"] = M.return_append,
    ["see"] = M.see_add,
    ["type"] = M.type_set,
}

---@param parsed nvim.luacats.grammar.Result
function M:add_parsed(parsed)
    local transform_fn = transform[parsed.kind]
    if transform_fn then
        transform_fn(self, parsed)
    else
        -- Emit warning
    end
end

---@param self docgen.ParserObj
---@param namevar string
---@param classvar string
---@param sep "."|":"
local function finalize_fun(self, namevar, classvar, sep)
    -- I'm not sure how this could happen, but it is in the original docgen.
    if not namevar then
        local fmt_str = "fun.name is nil, check fn_xform(). fun: %s"
        error(string.format(fmt_str, vim.inspect(self)))
    end

    self:fun_set_from_name(namevar, classvar, sep)
    -- Check here in case it's an underline function
    if not item_is_visible(self) then
        return
    end

    -- Do now because param annotations are read down from the tag.
    self:params_iter(function(p)
        extract_default_type_from_desc(p)
    end)

    self.finalized = true
end

---@param self docgen.ParserObj
---@param line string
local function finalize_class_find_classvar(self, line)
    local classvar = line:match("^local%s+([a-zA-Z0-9_]+)%s*=")
    if classvar then
        self.classvar = classvar
        self.namevar = classvar
    end

    local parentvar
    parentvar, classvar = line:match("([a-zA-Z_]+)%.([a-zA-Z0-9_]+)%s*=%s*%{")
    if parentvar == self.modvar then
        self.classvar = classvar
        self.namevar = classvar
    end
end

---@param self docgen.ParserObj
---@param line string
---@return boolean Found a class function?
local function finalize_fun_find(self, line)
    local classvar, sep, namevar =
        line:match("^function%s+([a-zA-Z0-9_]+)([.:])([a-zA-Z0-9_]+)%s*%(")
    if classvar and namevar then
        finalize_fun(self, namevar, classvar, sep)
        return true
    end

    classvar, namevar = line:match("([a-zA-Z_]+)%.([a-zA-Z0-9_]+)%s*=%s*function%s*%(")
    if classvar and namevar then
        finalize_fun(self, namevar, classvar, ".")
        return true
    end

    return false
end

--- @param line string
function M:finalize(line)
    local kind = self:kind_get()
    if kind ~= nil and (not item_is_visible(self)) then
        return
    end

    self:doc_lines_commit()

    if kind == "brief" then
        if self.desc ~= nil and string.find(self.desc, "[^%s]") ~= nil then
            self.finalized = true
        end

        return
    end

    if kind == "class" then
        finalize_class_find_classvar(self, line)
        self.finalized = true
        return
    end

    if
        string.find(line, "[^%s]") == nil
        or string.find(line, "^%s*local%s+")
        or string.find(line, "^%s*return%s+")
        or string.find(line, "^%s*%-%- luacheck:")
        or string.find(line, "^%s*[a-zA-Z_.]+%(%s+")
    then
        return
    end

    if finalize_fun_find(self, line) then
        self.finalized = true
        return
    end
end

return M
