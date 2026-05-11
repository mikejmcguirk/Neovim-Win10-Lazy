local ts_parsing = require("docgen.ts_parsing")
local md_to_vimdoc = ts_parsing.luacats_md_to_vimdoc

local util = require("docgen.util")
local checked_append = util.checked_str_append
local list_filter = util.list_filter
local list_find = util.list_find
local startswith_byte = util.startswith_byte
local endswith_byte = util.endswith_byte
local table_clear = util.table_clear
local table_new = util.table_new

--- @class docgen.DocItem : nvim.luacats.grammar.Result
--- @field classvar? string
--- @field default? string
--- @field nodoc? boolean

---@alias docgen.Kind docgen.luacats.Kind|"fun"
---@alias docgen.Access 'private'|'protected'|'package'
---@alias docgen.LastDocItem "param"|"return"
---@alias docgen.Visibility "deprecate"|"nodoc"|"inlinedoc"

---@class (exact) docgen.ParserObj
---@field package access? docgen.Access
---@field package async? boolean
---@field package class? string
---@field package classvar? string
---@field package desc? string
---@field package doc_lines? string[] Uncommitted doc lines
---@field package fields? docgen.DocItem[]
---@field package kind? docgen.Kind
---@field package last_doc_item? docgen.LastDocItem
---@field package module? string
---@field package modvar? string
---@field package name? string
---@field package overloads? string[]
---@field package params? docgen.DocItem[]
---@field package parent? string
---@field package returns? docgen.DocItem[]
---@field package see? string[]
---@field package type? docgen.DocItem
---@field package visibility? docgen.Visibility
---
---@field __index fun(self:docgen.ParserObj, key:any): val:any
---@field new fun(modvar:string, module:string): parser_obj:docgen.ParserObj
local M = {}

---@generic T
---@param self docgen.ParserObj
---@param key T
---@return any
function M.__index(self, key)
    local val = rawget(self, key)
    return val or rawget(M, key)
end

---@param modvar string
---@param module string
---@return docgen.ParserObj
function M.new(modvar, module)
    local obj = setmetatable(table_new(0, 22), M)
    rawset(obj, "modvar", modvar)
    rawset(obj, "module", module)

    return obj
end

-----------------
-- MARK: Utils --
-----------------

---@param self docgen.ParserObj
---@param kind string
local function assert_no_kind(self, kind)
    local msg = "Cannot set " .. kind .. ". Kind is already " .. tostring(self.kind)
    assert(not self.kind, msg)
end

---@param self docgen.ParserObj
---@param kind string
local function assert_is_kind(self, kind)
    local msg = "Current obj is not " .. kind .. " ( " .. tostring(self.kind) .. ")"
    assert(self.kind == kind, msg)
end

------------------------
-- MARK: Format Utils --
------------------------

-- --- @param fun nvim.gen_vimdoc.HelptagTarget
-- --- @return string
-- local function fn_helptag_fmt_common(fun)
--     local fn_sfx = fun.table and "" or "()"
--     if is_module_fun(fun) then
--         return fmt("%s.%s%s", fun.module, fun.name, fn_sfx)
--     end
--     if fun.classvar then
--         return fmt("%s:%s%s", fun.classvar, fun.name, fn_sfx)
--     end
--     if fun.module then
--         return fmt("%s.%s%s", fun.module, fun.name, fn_sfx)
--     end
--     return fun.name .. fn_sfx
-- end

---@param item docgen.ParserObj|docgen.DocItem
---@param help_prefix string
local function fmt_item_name_as_helptag(item, help_prefix)
    local name = item.name -- Since DocItems can be passed into here
    if not name then
        -- TODO: Improve
        error("Item has no name")
    end

    local ret = {}
    if #help_prefix > 0 then
        ret[#ret + 1] = help_prefix
        ret[#ret + 1] = "."
    end

    -- TODO: Using get metatable is hacky, and is quite a load-bearing assumption.
    if not getmetatable(item) then
        ret[#ret + 1] = name
        local item_type = item.type
        if type(item_type) == "string" then
            if string.sub(item_type, 1, 3) == "fun" then
                ret[#ret + 1] = "()"
            end
        end

        return table.concat(ret)
    end

    local _, module = item:get_module_info()
    if item:is_module_fun() then
        ret[#ret + 1] = module
        ret[#ret + 1] = "."
        ret[#ret + 1] = name
        ret[#ret + 1] = "()"
        return table.concat(ret)
    end

    if item:is_class_fun() then
        ret[#ret + 1] = module
        ret[#ret + 1] = ":"
        ret[#ret + 1] = name
        ret[#ret + 1] = "()"
        return table.concat(ret)
    end

    if item:is_module() then
        ret[#ret + 1] = module
        ret[#ret + 1] = ":"
        ret[#ret + 1] = name
        return table.concat(ret)
    end

    if item.kind == "class" then
        ret[#ret + 1] = name
        return table.concat(ret)
    end

    ret[#ret + 1] = name
    ret[#ret + 1] = "()"
    return table.concat(ret)
end
-- TODO: Consolidate logic in here.
-- TODO: This needs to bring in the master header to prepend to the namings.
-- TODO: I also now see the core's wisdom in figuring out the suffix beforehand

--- @param xs docgen.DocItem[]
--- @return integer
local function get_max_name_width(xs)
    local width = 0
    if not xs then
        return width
    end

    local len_xs = #xs
    for i = 1, len_xs do
        local x = xs[i]
        if x.type or x.desc then
            -- Add one for each curly brace
            width = math.max(width, #x.name + 2)
        end
    end

    return width
end
-- LOW: This should be an iterator like the one that handles formatting.

--- @param name string
--- @param width integer
--- @return string name
local function fmt_fp_name(name, width)
    local name_iso, opt = name:match("^([^?]*)(%??)$")
    local raw_width = #name_iso + #opt
    local remain = math.max(width - raw_width - 2, 0)

    return "{" .. name_iso .. "}" .. opt .. string.rep(" ", remain)
end
-- MID: I don't love the math.max, but an assert feels heavy-handed.

---@param typ string
---@param fmt_nil boolean
---@param default? string
local function get_fmt_type(typ, fmt_nil, default)
    typ = vim.trim(typ)
    typ = typ:gsub("%s*|%s*", "|")
    if fmt_nil ~= false then
        typ = typ:gsub("|nil", "?")
        typ = typ:gsub("nil|(.*)", "%1?")
    end

    if not default then
        return string.format("(`%s`)", typ)
    end

    return string.format("(`%s`, default: %s)", typ, default)
end
-- TODO: Does this handle question marks correctly? Like, does it add one if there's nil + ?

---@param self docgen.ParserObj
---@param width integer
---@param help_prefix string
---@param iter fun(self:docgen.ParserObj, f:fun(x:docgen.DocItem))
---@param f fun(name:string, typ:string, desc:string): string
---@return string[]
local function map_fmt_fp(self, width, help_prefix, iter, f)
    local ret = {}
    local is_classvar = self.kind == "class" and self.classvar ~= nil
    iter(self, function(field)
        local name = field.kind == "operator" and ("op(" .. field.name .. ")")
            or fmt_fp_name(field.name, width)
        local typ = field.type and get_fmt_type(field.type, true, field.default) or ""
        local desc = is_classvar
                and ("See |" .. fmt_item_name_as_helptag(field, help_prefix) .. "|.")
            or (field.desc and field.desc or "")

        ret[#ret + 1] = f(name, typ, desc)
    end)

    return ret
end

----------------------------
-- MARK: Inline Doc Tools --
----------------------------

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

    local width = class:get_max_field_name_width()
    class:iter_fields(function(field)
        if not field.access then
            local name = fmt_fp_name(field.name, width)
            local typ = get_fmt_type(field.type, true, field.default)
            new_doc_tbl[#new_doc_tbl + 1] = table.concat({ "-", name, typ, field.desc }, " ")
        end
    end)

    doc_item.desc = table.concat(new_doc_tbl, "\n")
end

---@param doc_item docgen.DocItem
---@param class docgen.ParserObj
local function append_doc_item_desc_see_class_tag(doc_item, class)
    local old_desc = doc_item.desc and string.match(doc_item.desc, "^.*%S") or "" -- rtrim
    local len_desc = #old_desc

    local tag = "|" .. class.name .. "|"
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

--- @param typ string
--- @return string base, boolean is_optional, boolean is_list
local function parse_clean_class_type(typ)
    if (not typ) or typ == "" then
        return "", false, false
    end

    local t = string.gsub(vim.trim(typ), "%s*|%s*", "|")

    local list_count
    t, list_count = string.gsub(t, "%[%]$", "")
    local n1
    t, n1 = string.gsub(t, "|nil", "")
    local n2
    t, n2 = string.gsub(t, "nil|", "")
    local n3
    t, n3 = string.gsub(t, "%?", "")

    return t, (n1 + n2 + n3) > 0, list_count > 0
end
-- TODO: This does not properly handle cases like `class_type|string`. Do we do a split  on `|`
-- here? Pass the types around as a list? This presumably has up and downstream effects because
-- everything else is built around the assumptions encoded here.
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
    if (not class) or class.visibility == "nodoc" then
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
    if class.visibility ~= "inlinedoc" then
        append_doc_item_desc_see_class_tag(doc_item, class)
        return
    end

    add_class_inlinedoc(doc_item, class, typ_islist)
    doc_item.type = get_class_table_type(typ_islist, typ_isopt)
end

--- @param classes? table<string,docgen.ParserObj> All classes from all files.
function M:update_fps_with_class_info(classes)
    assert(self.kind == "fun" or self.kind == "class")

    if not classes then
        return
    end

    if self.kind == "fun" then
        self:iter_params(function(r)
            local class, typ_isopt, typ_islist = find_class_in_doc_item_type(r, classes)
            if class then
                add_class_desc_to_doc_item(r, class, typ_isopt, typ_islist)
            end
        end)

        self:iter_returns(function(r)
            local len_r = #r
            for j = 1, len_r do
                local class, typ_isopt, typ_islist = find_class_in_doc_item_type(r[j], classes)
                if class then
                    add_class_desc_to_doc_item(r, class, typ_isopt, typ_islist)
                end
            end
        end)
    elseif self.kind == "class" then
        self:iter_fields(function(f)
            local class, typ_isopt, typ_islist = find_class_in_doc_item_type(f, classes)
            if class then
                add_class_desc_to_doc_item(f, class, typ_isopt, typ_islist)
            end
        end)
    end
end
-- TODO: Still unsure where this function sits. This both sets data and does style.
-- MID: Unclear function name.
-- MID: It would be better if this used a pattern like the param and field iters, where you have
-- `update_fun_with_class_info` as a shim and then it calls some underlying common function.

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
    end
end
-- DOC: Note that default has to be the first thing on the line for it to be pulled up.
-- TODO: See if there's a reason why the docgen has it anchored to a leading newline. Easiest
-- thing to do would be to just make the change and run `make doc`
-- - Can also check git history
-- PR: Easy to change the anchor to beginning of line if that works.

---------------
-- MARK: All --
---------------

---@return boolean
function M:can_commit()
    local kind = self.kind
    if not kind then
        return false
    end

    if self.visibility == "nodoc" then
        return false
    end

    if not list_find({ "class", "fun", "brief" }, kind) then
        return false
    end

    if kind == "brief" then
        return self.desc ~= nil
    end

    if self.name == nil then
        return false
    end

    if self.kind == "fun" and self:is_uline_fun() then
        return false
    end

    -- Don't remove classes yet without fields. They might be assigned function defined fields
    -- later.

    return self.access == nil
end
-- TODO: Filter data at various chokepoints to help with this.

---@return docgen.Kind
function M:get_kind()
    return self.kind
end

---@return string?
function M:get_fmt_desc()
    local desc = self.desc
    if desc then
        return md_to_vimdoc(desc)
    end
end
-- TODO: Does this generalize beyond class? Briefs at least can use it.

---@return string modvar, string module
function M:get_module_info()
    return self.modvar, self.module
end

---@return string?
function M:get_name()
    return self.name
end

---@param help_prefix string
---@return string
function M:get_name_as_helptag(help_prefix)
    return fmt_item_name_as_helptag(self, help_prefix)
end

----------------------------
-- MARK: Access Modifiers --
----------------------------

function M:set_package()
    local kind = self.kind
    if kind == "brief" or kind == "class" then
        -- TODO: emit warning
        return
    end

    self.access = "package"
end

function M:set_private()
    local kind = self.kind
    if kind == "brief" or kind == "class" then
        -- TODO: emit warning
        return
    end

    self.access = "private"
end

function M:set_protected()
    local kind = self.kind
    if kind == "brief" or kind == "class" then
        -- TODO: emit warning
        return
    end

    self.access = "protected"
end

-- TODO: Do aliases need to be ignored as well?

----------------------
-- MARK: Alias Info --
----------------------

---@param parsed nvim.luacats.grammar.Result
function M:set_alias(parsed)
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

function M:set_async()
    local kind = self:get_kind()
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
function M:set_brief(parsed)
    local kind = "brief"
    assert_no_kind(self, kind)

    self.desc = parsed.desc
    self.kind = kind --[[@as docgen.Kind]]

    self.access = nil
    self.async = nil
    self.class = nil
    self.classvar = nil
    self.fields = nil
    self.last_doc_item = nil
    self.name = nil
    self.overloads = nil
    self.params = nil
    self.parent = nil
    self.returns = nil
    self.see = nil
    self.type = nil

    if self:has_doc_lines() then
        table_clear(self.doc_lines)
        -- TODO: Emit warning
    end
end

---@return string
function M:get_fmt_brief()
    assert_is_kind(self, "brief")
    assert(self.desc)
    return md_to_vimdoc(self.desc)
end

-- TODO: Make sure @nodoc is supported for briefs. This allows a user to disable rendering a brief
-- by simply adding the tag rather than having to use a hack like deleting the third dash.

----------------------
-- MARK: Class Info --
----------------------

function M:is_module()
    return self.kind == "class" and self.modvar == self.classvar
end

---@return string?
function M:get_class()
    return self.class
end

---@param parsed nvim.luacats.grammar.Result
function M:set_class(parsed)
    local kind = "class"
    assert_no_kind(self, kind)

    self.class = parsed.name
    self.kind = kind
    self.name = parsed.name
    self.parent = parsed.parent

    self.access = nil
    self.async = nil
    self.classvar = nil
    self.desc = nil
    self.fields = nil
    self.last_doc_item = nil
    self.overloads = nil
    self.params = nil
    self.returns = nil

    local doc_lines = self:commit_doc_lines(true)
    if doc_lines then
        self.desc = doc_lines
    else
        self.desc = (parsed.desc and parsed.desc ~= "") and vim.trim(parsed.desc) or nil
    end
end

---@return string?
function M:get_parent()
    return self.parent
end

---------------------
-- MARK: Doc Lines --
---------------------

---@param take? boolean
---@return string?
function M:commit_doc_lines(take)
    local doc_lines = self.doc_lines
    if not doc_lines then
        return
    end

    local doc_lines_str = table.concat(doc_lines, "\n")
    self.doc_lines = nil
    if take then
        return doc_lines_str
    end

    if self.last_doc_item == "param" then
        if not self:has_params() then
            error("Last doc item set to params, but no params")
        end

        local last_param = self.params[#self.params]
        last_param.desc = checked_append(last_param.desc, "\n" .. doc_lines_str, true)
    elseif self.last_doc_item == "return" then
        if not self:has_returns() then
            error("Last doc item set to returns, but no returns")
        end

        local last_return = self.returns[#self.returns]
        last_return.desc = checked_append(last_return.desc, "\n" .. doc_lines_str, true)
    else
        self.desc = checked_append(self.desc, "\n" .. doc_lines_str, true)
    end

    self.last_doc_item = nil
end

---@param doc_item string
---@param commit_prev boolean
function M:set_last_doc_item(doc_item, commit_prev)
    if commit_prev then
        self:commit_doc_lines()
    end

    self.last_doc_item = doc_item
end

---@param line string
function M:add_doc_line(line)
    -- TODO: This should just be startswith_byte
    if line:match("^ ") then
        line = line:sub(2)
    end

    self.doc_lines = self.doc_lines or {}
    local doc_lines = self.doc_lines
    doc_lines[#doc_lines + 1] = line
end

---@return boolean
function M:has_doc_lines()
    return self.doc_lines ~= nil and #self.doc_lines > 0
end

--------------------------
-- MARK: Doc Visibility --
--------------------------

---@return boolean
function M:is_visible()
    return self.visibility == nil
end

function M:set_deprecate()
    if self.kind == "brief" then
        -- TODO: emit warning
        return
    end

    self.visibility = "deprecate"
end
-- TODO: If this is true, the only thing that should show in the description is a notice like
-- gitsigns does. See undo_stage_hunk. I'm not sure then how you algorithmically attach an
-- alternative. You could have a @replaces tag that ties it together, but then you need to
-- cross-reference the lists, including having an all_funs map
-- This should also set last_doc_item so additional doc_lines can be put into it, or at least
-- unset it. I'm not sure if the Luacasts grammar supports desc for this
-- MID: This could feasibly be useful for briefs.

function M:set_inlinedoc()
    if self.visibility == "nodoc" then
        -- TODO: emit warning
        return
    end

    if self.kind == "brief" then
        -- TODO: emit warning
        return
    end

    self.visibility = "inlinedoc"
end

function M:set_nodoc()
    self.visibility = "nodoc"
end

---@param obj docgen.ParserObj?
function M:set_nodoc_from_obj(obj)
    if not obj then
        return
    end

    local obj_visibility = obj.visibility
    if obj_visibility == "nodoc" then
        self.visibility = obj_visibility
    end
end
-- TODO: Should also handle deprecate. What we really want is to not set inlinedoc.

------------------
-- MARK: Fields --
------------------

---@param parsed nvim.luacats.grammar.Result
function M:add_field(parsed)
    assert_is_kind(self, "class")

    local doc_lines = self:commit_doc_lines(true)
    if doc_lines then
        parsed.desc = doc_lines
    else
        parsed.desc = (parsed.desc and parsed.desc ~= "") and parsed.desc or nil
        parsed.desc = parsed.desc and vim.trim(parsed.desc) or nil
    end

    local access = self.access
    if access then
        parsed.access = access
        self.access = nil
    end

    self.fields = self.fields or {}
    local fields = self.fields
    fields[#fields + 1] = parsed --[[@as docgen.DocItem]]
end

--- @param fun docgen.ParserObj
function M:add_field_from_fun(fun)
    assert_is_kind(self, "class")
    assert_is_kind(fun, "fun")

    local type_tbl = { "fun(" }
    local params = {} ---@type string[]
    fun:iter_params(function(param)
        params[#params + 1] = string.format("%s:%s", param.name, param.type)
    end)

    type_tbl[#type_tbl + 1] = table.concat(params, ", ")
    type_tbl[#type_tbl + 1] = ")"
    if fun:has_returns() then
        type_tbl[#type_tbl + 1] = ": "
        local fun_ret_types = {} --- @type string[]
        fun:iter_returns(function(r)
            local len_r = #r
            for j = 1, len_r do
                fun_ret_types[#fun_ret_types + 1] = r[j].type
            end

            type_tbl[#type_tbl + 1] = table.concat(fun_ret_types, ", ")
        end)
    end

    -- LOW: You could also edit the original field, but this is simpler.
    self:filter_fields(function(field)
        return field.name ~= fun.name
    end)

    self.fields = self.fields or {}
    local fields = self.fields
    fields[#fields + 1] = {
        kind = "field",
        name = fun.name,
        type = table.concat(type_tbl, ""),
        access = fun.access,
        desc = fun.desc,
    }
end

---@return boolean
function M:has_fields()
    return self.fields ~= nil and #self.fields > 0
end

---Edits fields in place
---@param f fun(field:docgen.DocItem): boolean
function M:filter_fields(f)
    if not self:has_fields() then
        return
    end

    list_filter(self.fields, f)
end

---@return integer
function M:get_max_field_name_width()
    return get_max_name_width(self.fields)
end

---@param f fun(field:docgen.DocItem)
function M:iter_fields(f)
    if not self:has_fields() then
        return
    end

    local fields = self.fields ---@type docgen.DocItem
    local len_fields = #fields
    for i = 1, len_fields do
        f(fields[i])
    end
end

---Returns a new table.
---@param help_prefix string
---@param f fun(name:string, typ:string, desc:string): string
---@return string[]
function M:map_fmt_fields(help_prefix, f)
    if not self:has_fields() then
        return {}
    end

    return map_fmt_fp(self, self:get_max_field_name_width(), help_prefix, M.iter_fields, f)
end
-- TODO: This should return ret so the caller can decide what to do with it. Applies to any other
-- list formatter in here.

-------------------------
-- MARK: Function Info --
-------------------------

---Returns true on module functions. See |is_module_fun()|
---@return boolean
function M:is_class_fun()
    return self.kind == "fun" and self.classvar ~= nil
end

---@return boolean
function M:is_uline_fun()
    local name = assert(self.name)
    return startswith_byte(name, 95) or string.find(name, "[:.]_") ~= nil
end
-- TODO: This should also work for classes.

---@return string?
function M:get_fmt_fun_name()
    assert_is_kind(self, "fun")
    return (self.classvar and not self:is_module_fun())
            and string.format("%s:%s", self.classvar, self.name)
        or self.name
end
-- TODO: Not 100% sure this is right. Some module functions should be dot functions, others
-- colon functions. Same with class member functions, like new. So either the correct name needs
-- to be stored or we do indeed need the member sep variable.
-- TODO: This feels like it should be generalized. For whatever reason, classes just get the
-- helptag name. You might also be able to create an alias name.
-- TODO: Something that's generally a problem in this code is that function name resolution is
-- handled in disconnected steps. To some degree this is necessary because we need to handle
-- class membership and module membership. But it feels like we should be able to say:
-- - When we get the initial LuaCATs result, take it as is
-- - If it's a non-module class, display with a colon
-- - Store a class fun or module fun variable to reference
-- - Never ad_hoc resolve the question again

---@param fun_name string
---@param class string
---@param classvar string
function M:set_class_fun(fun_name, class, classvar)
    assert_no_kind(self, "class function")

    self:commit_doc_lines()
    self.kind = "fun"
    self.name = fun_name
    self.class = class
    self.classvar = classvar

    self.params = self.params or {}
    table.insert(self.params, 1, {
        name = "self",
        type = class,
    })

    self.fields = nil
    self.parent = nil
end
-- LOW: Use nvim-tools list.insert_at instead of table.insert.

---@param name string
function M:set_fun_from_name(name)
    assert_no_kind(self, "function")

    self:commit_doc_lines()
    self.kind = "fun"
    self.name = name

    self.fields = nil
    self.parent = nil

    self.class = nil
    self.classvar = nil
end

--- If true, then the `.` class member should render like a module function.
--- @return boolean
function M:is_module_fun()
    return self.kind == "fun"
        and self.classvar ~= nil
        and self.modvar ~= nil
        and self.module ~= nil
        and self.classvar == self.modvar
end

---------------------
-- MARK: Overloads --
---------------------

---@param parsed nvim.luacats.grammar.Result
function M:add_overload(parsed)
    if self.kind == "brief" then
        -- TODO: emit warning
        return
    end

    self.overloads = self.overloads or {}
    local overloads = self.overloads
    overloads[#overloads + 1] = parsed.type
end

function M:has_overloads()
    return self.overloads ~= nil and #self.overloads > 0
end

---@param f fun(overload:string)
function M:iter_overloads(f)
    if not self:has_overloads() then
        return
    end

    local overloads = self.overloads ---@type string[]
    local len_overloads = #overloads
    for i = 1, len_overloads do
        f(overloads[i])
    end
end

---@return string?
function M:get_fmt_overloads()
    if not M:has_overloads() then
        return
    end

    local ret = {}
    self:iter_overloads(function(overload)
        ret[#ret + 1] = "• " .. md_to_vimdoc(overload)
    end)

    return table.concat(ret, "\n")
end

------------------
-- MARK: Params --
------------------

---@param parsed nvim.luacats.grammar.Result
function M:add_param(parsed)
    assert_no_kind(self, "param")

    self:set_last_doc_item("param", true)

    if string.byte(parsed.name, #parsed.name) == 63 then
        parsed.name = string.sub(parsed.name, 1, -2)
        parsed.type = parsed.type .. "?"
    end

    self.params = self.params or {}
    local params = self.params
    params[#params + 1] = parsed --[[@as docgen.DocItem]]
end
-- MID: The question mark move could check if the type already contains nil.

---@return boolean
function M:has_params()
    return self.params ~= nil and #self.params > 0
end

---@param f fun(param:docgen.DocItem)
function M:iter_params(f)
    if not self:has_params() then
        return
    end

    local params = self.params ---@type docgen.DocItem[]
    local len_params = #params
    for i = 1, len_params do
        f(params[i])
    end
end

---Edits params in place
---@param f fun(param:docgen.DocItem): boolean
function M:filter_params(f)
    if not self:has_params() then
        return
    end

    list_filter(self.params, f)
end

---@return integer
function M:get_max_param_name_width()
    return get_max_name_width(self.params)
end

---@param width integer If a `{name}`'s width is less than `width`, then right padding will be
---     added to assist with alignment.
---@return string[]|nil
function M:get_fmt_params(width)
    if not self:has_params() then
        return nil
    end

    local args = {}
    self:iter_params(function(param)
        local name = param.name
        if name ~= "self" then
            args[#args + 1] = fmt_fp_name(name, width)
        end
    end)

    return args
end

---Returns a new table.
---@param f fun(name:string, typ:string, desc:string): string
---@return string[]
function M:map_fmt_params(f)
    if not self:has_params() then
        return {}
    end

    return map_fmt_fp(self, self:get_max_param_name_width(), "", M.iter_params, f)
end

-------------------
-- MARK: Returns --
-------------------

---@param parsed nvim.luacats.grammar.Result
function M:add_return(parsed)
    assert_no_kind(self, "return")

    self:set_last_doc_item("return", true)

    if not self.returns then
        self.returns = {}
    end

    local returns = self.returns ---@type docgen.DocItem[]
    returns[#returns + 1] = parsed --[[@as docgen.DocItem]]
end

---@return integer
function M:get_count_returns()
    return self.returns and #self.returns or 0
end

---@return boolean
function M:has_returns()
    return self.returns ~= nil and #self.returns > 0
end
-- MAYBE: This could also validate if the underlying data is correct.

---@param f fun(ret:docgen.DocItem)
function M:iter_returns(f)
    if not self:has_returns() then
        return
    end

    local returns = self.returns ---@type docgen.DocItem[]
    local len_returns = #returns
    for i = 1, len_returns do
        f(returns[i])
    end
end

---@param f fun(x: docgen.DocItem): boolean
function M:filter_inner_returns(f)
    if not self:has_returns() then
        return
    end

    self:iter_returns(function(ret)
        list_filter(ret, f)
    end)

    list_filter(self.returns, function(ret)
        return #ret > 0
    end)
end

---@return string[]
function M:get_fmt_returns()
    if not self:has_returns() then
        return {}
    end

    local return_types = {} ---@type string[]
    local this_ret = {} ---@type string[]
    local ret = {} ---@type string[]

    self:iter_returns(function(r)
        table_clear(return_types)
        table_clear(this_ret)

        local len_r = #r
        for j = 1, len_r do
            local typ = r[j].type or ""
            return_types[#return_types + 1] = get_fmt_type(typ, true)
        end

        this_ret[#this_ret + 1] = table.concat(return_types, ", ")

        local desc = (r[len_r].name or "") .. " " .. (r.desc or "")
        if #desc > 0 and desc ~= " " then
            this_ret[#this_ret + 1] = ": "
            this_ret[#this_ret + 1] = desc
        end

        ret[#ret + 1] = md_to_vimdoc(table.concat(this_ret))
    end)

    return ret
end
-- MID: Format return names as names in some conditions:
-- - If a single return line only contains the type and name, format the name as a {name}. Use
-- subsequent doclines as the return desc.
-- - If a line with multiple returns contains multiple names, treat the names as {names}

---------------
-- MARK: See --
---------------

---@param parsed nvim.luacats.grammar.Result
function M:add_see(parsed)
    if self.kind == "brief" then
        -- TODO: emit warning
        return
    end

    self.see = self.see or {}
    local see = self.see
    see[#see + 1] = parsed.desc
end
-- MID: This could actually be supported in briefs and make sense. If you're discussing something
-- that happens across multiple modules, you could use the @see annotation to reference it in
-- an appealing formatted way.

function M:has_see()
    return self.see ~= nil and #self.see > 0
end

---@param f fun(see:string)
function M:see_iter(f)
    if not self:has_see() then
        return
    end

    local see = self.see ---@type string[]
    local len_see = #see
    for i = 1, len_see do
        f(see[i])
    end
end

---@return string?
function M:get_fmt_see()
    if not self:has_see() then
        return
    end

    local ret = {}
    self:see_iter(function(see)
        ret[#ret + 1] = "• " .. md_to_vimdoc(see)
    end)

    return table.concat(ret, "\n")
end

----------------
-- MARK: Type --
----------------

---@param parsed nvim.luacats.grammar.Result
function M:set_type(parsed)
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
    ["alias"] = M.set_alias,
    ["async"] = M.set_async,
    ["brief"] = M.set_brief,
    ["class"] = M.set_class,
    ["deprecate"] = M.set_deprecate,
    ["field"] = M.add_field,
    ["inlinedoc"] = M.set_inlinedoc,
    ["nodoc"] = M.set_nodoc,
    ["operator"] = M.add_field,
    ["overload"] = M.add_overload,
    ["package"] = M.set_package,
    ["param"] = M.add_param,
    ["private"] = M.set_private,
    ["protected"] = M.set_protected,
    ["return"] = M.add_return,
    ["see"] = M.add_see,
    ["type"] = M.set_type,
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
local function finalize_fun(self)
    assert(self.kind == "fun", "Cannot commit " .. tostring(self.kind) .. " as fun")
    if not self.name then
        local fmt_str = "fun.name is nil, check fn_xform(). fun: %s"
        error(string.format(fmt_str, vim.inspect(self)))
    end

    self:filter_params(function(param)
        return not (list_find({ "_", "self" }, param.name) or startswith_byte(param.name, 95))
    end)

    self:iter_params(function(param)
        extract_default_type_from_desc(param)
    end)

    self:filter_inner_returns(function(ret)
        return ret.type ~= nil and ret.type ~= "nil"
    end)
end

---@param self docgen.ParserObj
local function finalize_class(self)
    assert(self.kind == "class", "Cannot commit " .. tostring(self.kind) .. " as class")
    self:filter_fields(function(field)
        return not field.access
    end)

    self:iter_fields(function(field)
        extract_default_type_from_desc(field)
    end)
end

--- @param line string
--- @param classes table<string,docgen.ParserObj>
--- @param classvar_map table<string,string>
function M:finalize(line, classes, classvar_map)
    if self.access ~= nil or self.visibility == "nodoc" then
        return false
    end

    self:commit_doc_lines()

    local kind = self:get_kind()
    if kind == "brief" then
        return
    end

    if kind == "class" then
        local classvar = line:match("^local%s+([a-zA-Z0-9_]+)%s*=")
        if classvar then
            classvar_map[classvar] = self.name
            self.classvar = classvar
        end

        finalize_class(self)
        return
    end

    if
        string.match(line, "^%s+") ~= nil
        or string.find(line, "^%s*local%s+")
        or string.find(line, "^%s*return%s+")
        or string.find(line, "^%s*%-%- luacheck:")
        or string.find(line, "^%s*[a-zA-Z_.]+%(%s+")
    then
        self.kind = nil
        return
    end

    -- TODO: Underline naming still has not been checked
    local classvar, _, fun_name =
        line:match("^function%s+([a-zA-Z0-9_]+)([.:])([a-zA-Z0-9_]+)%s*%(")
    if classvar and classvar ~= self.modvar then
        local class_name = classvar_map[classvar]
        if class_name then
            local class = assert(classes[class_name], "No class for classvar " .. class_name)

            self:set_nodoc_from_obj(class)
            self:set_class_fun(fun_name, class_name, classvar)
            finalize_fun(self)

            classes[class_name]:add_field_from_fun(self)

            return
        end
    end

    ---@param this_fun_name string
    local function set_fun_from_name(this_fun_name)
        self:set_fun_from_name(this_fun_name)
        finalize_fun(self)
    end

    if classvar == self.modvar then
        return set_fun_from_name(fun_name)
    end

    local dot_fun_name = line:match("^function%s+([.a-zA-Z0-9_]+)%s*%(")
    if dot_fun_name then
        return set_fun_from_name(dot_fun_name)
    end
end
-- TODO: Why does this return a boolean? You should be able to know if it's committed based on
-- self.committed. And you should have a self:is_comitted() method
-- TODO: The function name failures I think should be in the actual setter functions. Maybe do
-- some kind of outline thing.
-- TODO: Obviously like there's the issue of, even for nodoc functions, you want the data to avoid
-- inconsistency, but it feels like @nodoc objects shouldn't even be able to commit. If it's
-- not documented, why should it be seeable?
-- - Aliases are a problem here because we might not want the Alias documented separately, but
-- we need the type info. But that to me just feels like an inlinedoc thing.

return M
