--- @class docgen.DocItem : nvim.luacats.grammar.Result
--- @field classvar? string

---@class (exact) docgen.ParserObj
---@field attrs? string[]
---@field async? boolean
---@field access? 'private'|'protected'|'package'
---@field class? string
---@field classvar? string
---@field deprecated? boolean
---@field doc_lines? string[] Uncommitted doc lines
---@field desc? string
---@field fields? docgen.DocItem[]
---@field generics? string[]
---@field inlinedoc? boolean
---@field kind? "alias"|"brief"|"class"|"fun"
---@field member_sep? '.'|':'
---@field module? string
---@field modvar? string
---@field name? string
---@field nodoc? boolean
---@field notes? docgen.DocItem[]
---@field overloads? string[]
---@field params? docgen.DocItem[]
---@field parent? string
---@field returns? docgen.DocItem[]
---@field see? docgen.DocItem[]
---@field since? string
---@field type? docgen.DocItem
---
---@field __index fun(self: docgen.ParserObj, key: any): val:any
---@field new fun(): parser_obj:docgen.ParserObj
local M = {}

---@generic T
---@param self docgen.ParserObj
---@param key T
---@return any
function M.__index(self, key)
    local val = rawget(self, key)
    return val or rawget(M, key)
end

local table_new = require("docgen.util").table_new

---@return docgen.ParserObj
function M.new()
    return setmetatable(table_new(0, 22), M)
end

function M:clear_for_alias_class()
    self.async = nil
    self.class = nil
    self.classvar = nil
    self.desc = nil
    self.fields = nil
    self.kind = nil
    self.member_sep = nil
    self.name = nil
    self.notes = nil
    self.overloads = nil
    self.params = nil
    self.parent = nil
    self.returns = nil
    self.see = nil
    self.since = nil
    self.type = nil
end

function M:clear_for_class()
    self:clear_for_alias_class()
    self.access = nil
end

function M:clear_all()
    self:clear_for_alias_class()
    self:clear_for_class()

    self.deprecated = nil
    self.generics = nil
    self.nodoc = nil
    self.inlinedoc = nil
end

----------------------
-- MARK: Alias Info --
----------------------

function M:alias_set(parsed)
    self:clear_for_alias_class()
    self.kind = "alias"
    self.desc = parsed.desc
end

----------------------
-- MARK: Brief Info --
----------------------

---@param parsed nvim.luacats.grammar.Result
function M:brief_set(parsed)
    self:clear_all()
    self.kind = "brief"
    self.desc = parsed.desc
end

----------------------
-- MARK: Class Info --
----------------------

---@param parsed nvim.luacats.grammar.Result
function M:class_set(parsed)
    assert(not self.kind, "Cannot set as class. Kind is already " .. tostring(self.kind))
    self:clear_for_class()

    self.kind = "class"
    self.name = parsed.name
    self.parent = parsed.parent
    self.access = parsed.access

    local doc_lines = self.doc_lines
    self.desc = doc_lines and table.concat(doc_lines, "\n") or nil
    self.fields = {}
end

---@param parsed nvim.luacats.grammar.Result
function M:class_add_field(parsed)
    if self.kind ~= "class" then
        -- TODO: Improve
        error("Cannot add a field to a non-class object")
    end

    parsed.desc = (parsed.desc and parsed.desc ~= "") and parsed.desc or nil
    local doc_lines = self.doc_lines
    parsed.desc = parsed.desc or doc_lines and table.concat(doc_lines, "\n") or nil
    parsed.desc = parsed.desc and vim.trim(parsed.desc) or nil

    local fields = self.fields
    fields[#fields + 1] = parsed --[[@as docgen.DocItem]]
    self.doc_lines = nil
end

--- @param fun docgen.ParserObj
function M:class_add_field_from_fun(fun)
    assert(fun.kind == "fun", "fun.kind is not 'fun' " .. fun.kind)

    local type_tbl = { "fun(" }

    local fun_params = fun.params
    if fun_params then
        local params = {} ---@type string[]
        local len_fun_params = #fun_params
        for i = 1, len_fun_params do
            local p = fun_params[i]
            params[#params + 1] = string.format("%s: %s", p.name, p.type)
        end

        type_tbl[#type_tbl + 1] = table.concat(params, ", ")
    end

    type_tbl[#type_tbl + 1] = ")"

    local fun_returns = fun.returns
    if fun_returns then
        type_tbl[#type_tbl + 1] = ": "
        local fun_ret_types = {} --- @type string[]
        local len_fun_returns = #fun_returns
        for i = 1, len_fun_returns do
            fun_ret_types[#fun_ret_types + 1] = fun_returns[i].type
            type_tbl[#type_tbl + 1] = table.concat(fun_ret_types, ", ")
        end
    end

    local fields = self.fields
    fields[#fields + 1] = {
        kind = "field",
        name = fun.name,
        type = table.concat(type_tbl, ""),
        access = fun.access,
        desc = fun.desc,
        nodoc = fun.nodoc,
        classvar = fun.classvar,
    }
end

---@param parsed nvim.luacats.grammar.Result
function M:class_add_operator(parsed)
    if self.kind ~= "class" then
        -- TODO: Improve
        error("Cannot add an operator to a non-class object")
    end

    -- MID: Why isn't desc == "" checked here like in field?
    local doc_lines = self.doc_lines
    parsed.desc = parsed.desc or doc_lines and table.concat(doc_lines, "\n") or nil
    parsed.desc = parsed.desc and vim.trim(parsed.desc) or nil

    local fields = self.fields
    fields[#fields + 1] = parsed --[[@as docgen.DocItem]]
    self.doc_lines = nil
end

-------------------------
-- MARK: Function Info --
-------------------------

function M:async_set()
    self.async = true
end

---@param fun_name string
---@param class string
---@param parent string
---@param sep string
function M:class_fun_set(fun_name, class, parent, sep)
    assert(not self.kind, "Cannot set as class function. Kind is already " .. tostring(self.kind))

    self.name = fun_name
    self.class = class
    self.classvar = parent
    self.member_sep = sep

    self.params = self.params or {}
    table.insert(self.params, 1, {
        name = "self",
        type = class,
    })

    self.kind = "fun"
end
-- TODO: Use list.insert_at instead of table.insert

---@param name string
function M:fun_set_from_name(name)
    assert(self.kind == nil, "Cannot set as function. Kind is already " .. tostring(self.kind))
    self.name = name
    self.kind = "fun"
end

function M:generic_add(parsed)
    self.generics = self.generics or {}
    local generics = self.generics
    generics[#generics + 1] = parsed.type or "any"
end

---@param parsed nvim.luacats.grammar.Result
function M:overload_add(parsed)
    self.overloads = self.overloads or {}
    local overloads = self.overloads
    overloads[#overloads + 1] = parsed.type
end

---@param doc_item docgen.DocItem
function M:param_add(doc_item)
    self.params = self.params or {}
    local params = self.params
    params[#params + 1] = doc_item
end

---@param parsed nvim.luacats.grammar.Result
function M:return_add(parsed)
    self.returns = self.returns or {}
    local returns = self.returns
    for _, t in ipairs(parsed) do
        returns[#returns + 1] = {
            name = t.name,
            type = t.type,
            desc = parsed.desc,
        }
    end
end

----------------------------
-- MARK: Access Modifiers --
----------------------------

function M:private_set()
    self.access = "private"
end

function M:package_set()
    self.access = "package"
end

function M:protected_set()
    self.access = "protected"
end

---------------------
-- MARK: Doc Style --
---------------------

function M:deprecate_set()
    self.deprecated = true
end

function M:inlinedoc_set()
    self.inlinedoc = true
end

function M:nodoc_set()
    self.nodoc = true
end

----------------
-- MARK: Misc --
----------------

---@param line string
function M:doc_lines_add(line)
    if line:match("^ ") then
        line = line:sub(2)
    end

    self.doc_lines = self.doc_lines or {}
    local doc_lines = self.doc_lines
    doc_lines[#doc_lines + 1] = line
end
-- MAYBE: Indent handling removed from here. Re-add if needed.

function M:doc_lines_clear()
    self.doc_lines = nil
end

function M:doc_lines_commit()
    local doc_lines = self.doc_lines
    if not doc_lines then
        return
    end

    local doc_lines_str = table.concat(doc_lines, "\n")
    if self.desc then
        self.desc = self.desc .. "\n" .. doc_lines_str
    else
        self.desc = doc_lines_str
    end

    self.doc_lines = nil
end

---@param doc_item docgen.DocItem
function M:note_add(doc_item)
    self.notes = self.notes or {}
    local notes = self.notes
    notes[#notes + 1] = doc_item
end
-- TODO: State also does bookkeeping here
-- TODO: Why are notes tables that then hold a key to a string. Shouldn't this just be a string[]?

---@param parsed nvim.luacats.grammar.Result
function M:see_add(parsed)
    self.see = self.see or {}
    local see = self.see
    see[#see + 1] = { desc = parsed.desc }
end

---@param modvar string?
---@param input string
function M:set_module_info(modvar, input)
    self.modvar = modvar

    --- @type string
    local module = input:match(".*/lua/([a-z_][a-z0-9_/]+)%.lua") or input
    module = module:gsub("/", ".")
    self.module = module
end

---@param parsed nvim.luacats.grammar.Result
function M:since_set(parsed)
    self.since = parsed.desc
end

---@param parsed nvim.luacats.grammar.Result
function M:type_set(parsed)
    self.desc = parsed.desc
    self.type = parsed --[[@as docgen.DocItem]]
end

return M
