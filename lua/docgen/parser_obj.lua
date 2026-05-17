local ts_parsing = require("docgen.ts_parsing")
local md_to_vimdoc = ts_parsing.luacats_md_to_vimdoc

local util = require("docgen.util")
local cbraces_add = util.add_cbraces
local checked_append = util.checked_str_append
local endswith_byte = util.endswith_byte
local help_tag_from_name = util.help_tag_from_name
local list_filter = util.list_filter
local startswith_byte = util.startswith_byte
local table_clear = util.table_clear
local table_new = util.table_new
local type_fmt_get_with_default = util.type_fmt_get_with_default

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
---@field package async_flg? boolean
---@field package class? string
---@field package classvar? string
---@field package cur_doc_item? docgen.LastDocItem
---@field package desc? string
---@field package doc_flag_desc? string
---@field package doc_flag? docgen.Visibility
---@field package doc_lines? string[] Uncommitted doc lines
---@field package fields? docgen.DocItem[]
---@field package finalized? boolean
---@field package tag? string
---@field package kind? docgen.Kind
---@field package header_tag? string
---@field package modvar? string
---@field package name? string
---@field package namevar? string
---@field package overloads? string[]
---@field package params? docgen.DocItem[]
---@field package parent? string
---@field package returns? docgen.DocItem[]
---@field package see? string[]
---@field package sep? string
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
    rawset(obj, "modvar", modvar)
    rawset(obj, "header_tag", header_tag)

    return obj
end

---------------------
-- MARK: Inlinedoc --
---------------------

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
-- LOW: It might be helpful to be able to do inlinedoc on union types. Doesn't inherently
-- blend in well though.
-- LOW: Cache these results.

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
-- MARK: Utils (Local) --
-------------------------

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
local function assert_is_kind(self, kind)
    if self.kind ~= kind then
        error("Current obj is not " .. kind .. " ( " .. tostring(self.kind) .. ")")
    end
end

---@param self docgen.ParserObj
---@param kind string
local function assert_no_kind(self, kind)
    if rawget(self, "kind") then
        error("Cannot set " .. kind .. ". Kind is already " .. tostring(self.kind))
    end
end
-- MID: The output could be nicer/more specific depending on if you are trying to set a doc item
-- or the actual kind (like a param vs. setting class state).

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
-- TODO: This, type_fixup, and the default move should all be one function. Because they all
-- modify type, they aren't really separate.

-- ---@param str string
-- ---@param to_inject string
-- ---@return string
-- local function inject_into_tag(str, to_inject)
--     local init, _ = string.find(str, "|%S+|")
--     if not init then
--         return str
--     end
--
--     local to_inject_esc = lua_pattern_get_escaped(to_inject)
--     if string.find(str, "|" .. to_inject_esc .. ".%S+|", init) ~= nil then
--         return str
--     end
--
--     str = string.gsub(str, "|(%S+)|", "|" .. to_inject_esc .. ".%1|")
--     return str
-- end
-- TODO: This should occur during the holistic step.

---@param typ string
---@return string
local function type_fixup(typ)
    typ = string.gsub(vim.trim(typ), "%s*|%s*", "|")
    typ = string.gsub(typ, "|nil", "?")
    typ = string.gsub(typ, "nil|(.*)", "%1?")
    typ = string.gsub(typ, "%?+$", "?")

    return typ
end

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

---@return string?
function M:desc_get()
    return self.desc
end

---@return string?
function M:tag_get()
    return self.tag
end
-- TODO: Fun parens should have already been added. If we're doing it here, the underlying
-- data is wrong.

---@return docgen.Kind
function M:kind_get()
    return self.kind
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

-----------------
-- MARK: Async --
-----------------

---@return boolean
function M:async_get()
    return self.async_flg == true
end

function M:async_set()
    local kind = self.kind
    if kind == "class" or kind == "brief" then
        -- TODO: emit warning
        return
    end

    self.async_flg = true
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
    self.async_flg = nil
    self.class = nil
    self.classvar = nil
    self.cur_doc_item = nil
    self.fields = nil
    self.tag = nil
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
    self.tag = self.header_tag .. "." .. parsed.name
    self.class = parsed.name
    self.parent = parsed.parent

    self.access = nil
    self.async_flg = nil
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
function M:doc_flag_desc_get()
    return self.doc_flag_desc
end

---@param parsed docgen.DocItem
function M:deprecated_set(parsed)
    if self.kind == "brief" then
        -- TODO: emit warning
        return
    end

    self.doc_flag = "deprecated"
    self.doc_flag_desc = parsed.desc
end
-- MID: Support this in briefs. Could be used for module or section level deprecation.
-- MAYBE: Use doc lines above for desc.

function M:is_deprecated()
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
        item.desc = item.desc and string.match(item.desc, "^.*%S") or nil
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
    local fun_fmt_name = fun:tag_get() --[[@as string]]
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

---@return integer
function M:field_names_max_width()
    local max_name_width = 0
    for _, field in ipairs(self.fields) do
        max_name_width = math.max(#field.name, max_name_width)
    end

    return max_name_width
end

---@param predicate fun(a:docgen.DocItem, b:docgen.DocItem): boolean
function M:fields_sort(predicate)
    if self:fields_count() == 0 then
        return
    end

    table.sort(rawget(self, "fields"), predicate)
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

    if self.classvar ~= self.modvar then
        -- TODO: Might need to save the separator info so this can be re-build properly
        -- TODO: try to re-outline this.
        self.tag = Nvim_Tools_Docgen_Help_Prefix .. "-" .. self.class .. ":" .. self.namevar
    end

    local class_fmt_name = class:tag_get() --[[@as string]]
    self:see_add({ desc = help_tag_from_name(class_fmt_name, "|") })
end

---@param namevar string
---@param classvar string
---@param sep "."|":"
function M:fun_set_from_namevar(namevar, classvar, sep)
    assert_no_kind(self, "function")

    rawset(self, "kind", "fun")
    rawset(self, "namevar", namevar)
    rawset(self, "classvar", classvar)
    rawset(self, "sep", sep)
    if classvar == self.modvar then
        -- TODO: This is required to make functions generate but I'm unsure why.
        self.class = ""
        self.tag = self.header_tag .. sep .. self.namevar
    else
        self.class = nil
        self.tag = self.header_tag .. "." .. rawget(self, "classvar") .. sep .. self.namevar
    end

    if sep == ":" then
        self:params_filter(function(param)
            return param.name ~= "self"
        end)
    end

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
    if not self.overloads then
        return
    end

    for _, overload in ipairs(self.overloads) do
        f(overload)
    end
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
    item.desc = item.desc and string.match(item.desc, "^.*%S") or nil

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
-- TODO: The LuaCATs grammar needs to have a test that, in order to return a valid param, the
-- name and type must be present.
-- TODO: Look at doing specific subtypes again for params/fields/returns. If you make them all
-- inherit doc item that should allow them to be passed around correct. Though there have been
-- issues with that with DocItem vs. Grammar.Result.

---@return integer
function M:params_count()
    return self.params ~= nil and #self.params or 0
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

---@generic T
---@param list T[]
---@return integer
local function list_count_get_checked(list)
    return list ~= nil and #list or 0
end
-- TODO: Use this internally rather than having to go through the metatable again.

---@param predicate fun(param: docgen.DocItem): boolean
function M:params_filter(predicate)
    if self:params_count() == 0 then
        return
    end

    local params = rawget(self, "params")
    local params_count = list_count_get_checked(params)
    if params_count == 0 then
        return
    end

    list_filter(params, predicate)
end

---@param f fun(param:docgen.DocItem)
function M:params_iter(f)
    if not self.params then
        return
    end

    for _, param in ipairs(self.params) do
        f(param)
    end
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

    parsed.desc = parsed.desc and string.match(parsed.desc, "^.*%S") or nil
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
        local fmt_str = "fun.name is nil. fun: %s"
        error(string.format(fmt_str, vim.inspect(self)))
    end

    self:fun_set_from_namevar(namevar, classvar, sep)
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
    end

    local parentvar
    parentvar, classvar = line:match("([a-zA-Z_]+)%.([a-zA-Z0-9_]+)%s*=%s*%{")
    if parentvar == self.modvar then
        self.classvar = classvar
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
